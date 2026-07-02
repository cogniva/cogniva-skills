#requires -Version 5.1
<#
.SYNOPSIS
  Read-only status of background Workflow runs for this repo, by scanning the
  on-disk workflow journals. No subagents, no edits, no terminal UI needed.

.DESCRIPTION
  Every Workflow run persists to disk under the orchestrating session:
    <projects>/<slug>/<session-id>/subagents/workflows/<wf-id>/journal.jsonl
        one {started|result} record per task agent (source of truth)
    .../<wf-id>/agent-<id>.jsonl   each agent's transcript (mtime = liveness)
    <projects>/<slug>/<session-id>/workflows/scripts/<name>-<wf-id>.js  the script
  This script rolls those up: per workflow it reports the name, the originating
  session, per-task DONE/BLOCKED counts, and whether an agent is RUNNING (open
  'started' + fresh mtime) or STALLED (open 'started' + stale mtime).

  For execute-feature runs it also prints a per-task breakdown - done (v) /
  running (>) / blocked (x) / pending (.) with commit SHAs. Per-task status and
  SHAs come from the JOURNAL (structured truth: each result record carries a
  status + commitSha); the feature PLAN (located from the running agent's prompt)
  supplies the full task list + titles, and state.md prose is only a SHA
  fallback. If the plan file can't be located, the breakdown degrades to a
  journal-only view instead of vanishing. Shown automatically for RUNNING
  execute-feature runs; -Detail forces it for every shown run.

.PARAMETER RepoRoot
  Repo root used to derive the Claude projects slug. Defaults to the MAIN
  checkout (resolved via git-common-dir) so it works from a worktree too.

.PARAMETER ProjectsDir
  Override the scanned project dir directly (…/.claude/projects/<slug>).

.PARAMETER All
  Include workflows whose last activity is older than -SinceHours (default off:
  only show runs touched in the last 24h).

.PARAMETER SinceHours
  Recency window for the default (non -All) view. Default 24.

.PARAMETER StallSeconds
  An open (unfinished) agent idle longer than this is flagged STALLED.
  Default 900 (15 min).

.PARAMETER Session
  Filter to one session id (full or leading prefix).

.PARAMETER Detail
  Print the per-task plan breakdown for EVERY shown run (not just RUNNING ones).

.PARAMETER Json
  Emit the raw objects instead of the formatted table. With the breakdown the
  task list is included under each object's `Tasks` property.
#>
[CmdletBinding()]
param(
  [string]$RepoRoot,
  [string]$ProjectsDir,
  [switch]$All,
  [int]$SinceHours = 24,
  [int]$StallSeconds = 900,
  [string]$Session,
  [switch]$Detail,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$now = Get-Date
$script:MainRepoRoot = $null

# Plan/state/transcript files are UTF-8; PS 5.1 defaults to the ANSI codepage on
# read AND console-out, which mangles em-dashes etc. Force UTF-8 both ways.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$Utf8 = if ($PSVersionTable.PSVersion.Major -ge 6) { 'utf8' } else { 'UTF8' }

function Resolve-ProjectsDir {
  $projectsRoot = Join-Path $env:USERPROFILE '.claude/projects'
  if (-not $RepoRoot) {
    # Resolve the MAIN checkout even when invoked from a worktree: git-common-dir
    # points at <main>/.git (possibly relative). Anchor on the CURRENT DIRECTORY
    # (the repo being inspected) — this skill ships as a plugin outside the repo,
    # so $PSScriptRoot is NOT inside the target checkout. Fall back to cwd.
    $anchor = (Get-Location).Path
    try {
      $cd = (& git -C $anchor rev-parse --git-common-dir 2>$null | Select-Object -First 1)
      if ($cd) {
        $cd = $cd.Trim()
        if (-not [System.IO.Path]::IsPathRooted($cd)) { $cd = Join-Path $anchor $cd }
        $RepoRoot = Split-Path -Parent ((Resolve-Path $cd).Path)
      }
    } catch { }
    if (-not $RepoRoot) { $RepoRoot = (Resolve-Path $anchor).Path }
  }
  $script:MainRepoRoot = $RepoRoot
  if ($ProjectsDir) { return $ProjectsDir }
  # Slug = repo path with separators -> '-', leading drive letter lowercased to
  # match Claude's project-dir naming (e.g. c--WorkingGit-CognivaNewRepo).
  $slug = ($RepoRoot.Trim() -replace '[:\\/]', '-')
  $slug = [regex]::Replace($slug, '^[A-Za-z]', { param($m) $m.Value.ToLower() })
  $candidate = Join-Path $projectsRoot $slug
  if (Test-Path $candidate) { return $candidate }
  $alt = Get-ChildItem $projectsRoot -Directory -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -ieq $slug } | Select-Object -First 1
  if ($alt) { return $alt.FullName }
  return $candidate
}

function ConvertFrom-Jsonl {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return @() }
  $out = @()
  foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try { $out += ($line | ConvertFrom-Json) } catch { }
  }
  $out
}

function Get-MessageText {
  param($Record)
  $content = $Record.message.content
  if ($content -is [string]) { return $content }
  $text = ''
  if ($content) { foreach ($c in $content) { if ($c.type -eq 'text') { $text += $c.text } } }
  $text
}

function Get-RunningTaskLabel {
  # Best-effort: pull "=== TASK N: title ===" out of an open agent's transcript.
  param([string]$AgentFile)
  if (-not (Test-Path $AgentFile)) { return $null }
  try {
    $head = (Get-Content -LiteralPath $AgentFile -TotalCount 40 -Encoding $Utf8) -join "`n"
    $m = [regex]::Match($head, '===\s*TASK\s*([0-9]+)\s*:\s*(.+?)\s*===')
    if ($m.Success) { return "task-$($m.Groups[1].Value): $($m.Groups[2].Value)" }
  } catch { }
  return $null
}

function Get-PlanInfoFromWf {
  # Extract the worktree / plan / state paths an execute-feature agent was given.
  param([string]$WfDir)
  $files = Get-ChildItem -LiteralPath $WfDir -Filter 'agent-*.jsonl' -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending
  foreach ($f in $files) {
    foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
      if ($line -notmatch 'git worktree') { continue }
      try { $o = $line | ConvertFrom-Json } catch { continue }
      $text = Get-MessageText $o
      if ($text -notmatch '===\s*TASK') { continue }
      # Accept drive-letter + EITHER slash: execute-feature has emitted both
      # 'C:\...' and 'C:/...' worktree paths. The worktree regex below was already
      # slash-agnostic ([^\r\n]+), but plan/state hardcoded a backslash and so
      # silently failed on forward-slash runs -> Get-TaskBreakdown returned null.
      $wt    = if ($text -match 'git worktree:\s*([^\r\n]+)')             { $matches[1].Trim() } else { $null }
      $plan  = if ($text -match 'edit\s+([A-Za-z]:[\\/][^\r\n]+?\.md)')    { $matches[1].Trim() } else { $null }
      $state = if ($text -match 'to\s+([A-Za-z]:[\\/][^\r\n]+?state\.md)') { $matches[1].Trim() } else { $null }
      if ($plan -or $state) {
        return [pscustomobject]@{ Worktree = $wt; PlanPath = $plan; StatePath = $state }
      }
    }
  }
  return $null
}

function Resolve-OnDisk {
  # A plan/state path lives under the worktree; if that's gone (worktree removed
  # after integration), the same relative path exists under the main checkout.
  param([string]$Path, [string]$Worktree)
  if (-not $Path) { return $null }
  if (Test-Path -LiteralPath $Path) { return $Path }
  if ($Worktree -and $script:MainRepoRoot -and $Path.StartsWith($Worktree, [System.StringComparison]::OrdinalIgnoreCase)) {
    $rel = $Path.Substring($Worktree.Length).TrimStart('\','/')
    $alt = Join-Path $script:MainRepoRoot $rel
    if (Test-Path -LiteralPath $alt) { return $alt }
  }
  return $null
}

function Get-PlanTasks {
  param([string]$PlanFile)
  if (-not $PlanFile -or -not (Test-Path -LiteralPath $PlanFile)) { return @() }
  $tasks = @(); $cur = $null
  foreach ($ln in (Get-Content -LiteralPath $PlanFile -Encoding $Utf8)) {
    if ($ln -match '^\s*#{1,4}\s*Task\s+([0-9]+)\s*:\s*(.+?)\s*$') {
      if ($cur) { $tasks += $cur }
      $cur = [pscustomobject]@{ N = [int]$matches[1]; Title = $matches[2]; Checked = 0; Unchecked = 0 }
    } elseif ($cur) {
      if     ($ln -match '^\s*-\s*\[[xX]\]') { $cur.Checked++ }
      elseif ($ln -match '^\s*-\s*\[\s\]')   { $cur.Unchecked++ }
    }
  }
  if ($cur) { $tasks += $cur }
  $tasks
}

function Get-CommitShas {
  # Map task number -> short SHA from state.md log lines ("...Task 2... Commit: abc1234").
  param([string]$StateFile)
  $map = @{}
  if (-not $StateFile -or -not (Test-Path -LiteralPath $StateFile)) { return $map }
  $raw = Get-Content -LiteralPath $StateFile -Raw -Encoding $Utf8
  # Two log shapes seen in the wild, both single-line:
  #   "...Task 2 ... Commit: abc1234"     (labelled)
  #   "- Task 2 (title) — abc1234. ..."   (dash / en- / em-dash + bare SHA)
  foreach ($m in [regex]::Matches($raw, '(?im)Task\s+([0-9]+)\b[^\r\n]*?Commit:\s*([0-9a-f]{6,40})')) {
    $map[[int]$m.Groups[1].Value] = $m.Groups[2].Value
  }
  foreach ($m in [regex]::Matches($raw, '(?im)^\s*[-*]?\s*Task\s+([0-9]+)\b[^\r\n]*?[—–-]\s*([0-9a-f]{7,40})\b')) {
    if (-not $map.ContainsKey([int]$m.Groups[1].Value)) { $map[[int]$m.Groups[1].Value] = $m.Groups[2].Value }
  }
  $map
}

function Get-TaskBreakdownFromJournal {
  # Fallback when the plan file can't be located (worktree removed before the plan
  # reached the main checkout, or path extraction failed): synthesize a breakdown
  # from the journal alone. Pending task TITLES are unknown here - we only know the
  # tasks the journal has results for, plus the one currently running.
  param($Row)
  if (-not $Row.TaskResults) { return @() }
  $nums = @($Row.TaskResults.Keys)
  if ($Row.RunTaskN -and ($nums -notcontains $Row.RunTaskN)) { $nums += $Row.RunTaskN }
  if (-not $nums) { return @() }
  $out = @()
  foreach ($n in ($nums | Sort-Object)) {
    $jr = $Row.TaskResults[$n]
    $title =
      if ($Row.RunTaskN -eq $n -and $Row.Detail -match '^task-[0-9]+:\s*(.+)$') { $matches[1].Trim() }
      elseif ($jr -and $jr.Title)                                               { $jr.Title }
      else                                                                      { '(title unavailable - plan not located)' }
    $state =
      if ($Row.RunTaskN -and $n -eq $Row.RunTaskN)  { 'running' }
      elseif ($jr -and $jr.Status -eq 'DONE')       { 'done' }
      elseif ($jr -and $jr.Status -eq 'BLOCKED')    { 'blocked' }
      else                                          { 'pending' }
    $out += [pscustomobject]@{ N = $n; Title = $title; State = $state; Sha = $(if ($jr) { $jr.Sha } else { $null }) }
  }
  ,$out
}

function Get-TaskBreakdown {
  # Returns the per-task list for a row, or @() if not an execute-feature run.
  # Status + commit SHA come from the JOURNAL first (structured truth); the plan
  # file supplies the full task list + titles, and state.md prose is a SHA
  # fallback (its log format varies between runs). If the plan can't be located,
  # degrade to a journal-only breakdown rather than collapsing to a bare count.
  param($Row)
  $info = Get-PlanInfoFromWf $Row.WfDir
  $planFile  = if ($info) { Resolve-OnDisk $info.PlanPath  $info.Worktree } else { $null }
  $stateFile = if ($info) { Resolve-OnDisk $info.StatePath $info.Worktree } else { $null }
  $tasks = Get-PlanTasks $planFile
  if (-not $tasks) {
    if ($Row.IsExec) { return (Get-TaskBreakdownFromJournal $Row) }
    return @()
  }
  $shas = Get-CommitShas $stateFile
  foreach ($t in $tasks) {
    $jr = if ($Row.TaskResults) { $Row.TaskResults[$t.N] } else { $null }
    $state =
      if ($Row.RunTaskN -and $t.N -eq $Row.RunTaskN)    { 'running' }
      elseif ($jr -and $jr.Status -eq 'DONE')           { 'done' }
      elseif ($jr -and $jr.Status -eq 'BLOCKED')        { 'blocked' }
      elseif ($t.Checked -gt 0 -and $t.Unchecked -eq 0) { 'done' }
      elseif ($t.Checked -gt 0)                         { 'partial' }
      else                                              { 'pending' }
    $sha = if ($jr -and $jr.Sha) { $jr.Sha } else { $shas[$t.N] }
    Add-Member -InputObject $t -NotePropertyName State -NotePropertyValue $state -Force
    Add-Member -InputObject $t -NotePropertyName Sha   -NotePropertyValue $sha   -Force
  }
  ,$tasks
}

# --- scan ------------------------------------------------------------------

$projDir = Resolve-ProjectsDir
if (-not (Test-Path $projDir)) {
  Write-Host "No Claude projects dir found at: $projDir" -ForegroundColor Yellow
  Write-Host "Pass -ProjectsDir <path> or -RepoRoot <path>." -ForegroundColor Yellow
  return
}

$rows = @()
foreach ($sess in (Get-ChildItem -LiteralPath $projDir -Directory -ErrorAction SilentlyContinue)) {
  if ($Session -and -not $sess.Name.StartsWith($Session)) { continue }
  $wfRoot = Join-Path $sess.FullName 'subagents/workflows'
  if (-not (Test-Path $wfRoot)) { continue }

  foreach ($wf in (Get-ChildItem -LiteralPath $wfRoot -Directory -Filter 'wf_*' -ErrorAction SilentlyContinue)) {
    $journal = Join-Path $wf.FullName 'journal.jsonl'
    $recs = ConvertFrom-Jsonl $journal
    if (-not $recs) { continue }

    $started = @($recs | Where-Object { $_.type -eq 'started' })
    $results = @($recs | Where-Object { $_.type -eq 'result' })
    $resultIds = @{}
    foreach ($r in $results) { $resultIds[$r.agentId] = $r }

    $doneCount    = @($results | Where-Object { $_.result.status -eq 'DONE' }).Count
    $blockedCount = @($results | Where-Object { $_.result.status -eq 'BLOCKED' }).Count
    $openAgents   = @($started | Where-Object { -not $resultIds.ContainsKey($_.agentId) })

    # Journal is the source of truth for per-task status + commit SHA: each result
    # record carries a status + commitSha, and its summary starts "Task N (...)".
    # (state.md prose is only a SHA fallback - its log format varies between runs.)
    $taskResults = @{}
    $ordinal = 0
    foreach ($r in $results) {
      $ordinal++
      $sum = [string]$r.result.summary
      $tn  = if ($sum -match '(?i)^\s*Task\s+([0-9]+)\b')                   { [int]$matches[1] } else { $ordinal }
      $ttl = if ($sum -match '(?i)^\s*Task\s+[0-9]+\s*[:\(]\s*([^\)\r\n:]+)') { $matches[1].Trim() } else { $null }
      $taskResults[$tn] = [pscustomobject]@{ Status = $r.result.status; Sha = $r.result.commitSha; Title = $ttl }
    }

    $agentFiles = Get-ChildItem -LiteralPath $wf.FullName -Filter 'agent-*.jsonl' -ErrorAction SilentlyContinue
    $newest = if ($agentFiles) { ($agentFiles | Sort-Object LastWriteTime -Descending)[0] } else { $null }
    $lastWrite = if ($newest) { $newest.LastWriteTime } else { (Get-Item $journal).LastWriteTime }
    $ageSec = [int]($now - $lastWrite).TotalSeconds

    $name = $wf.Name
    $scriptGlob = Join-Path $sess.FullName "workflows/scripts/*$($wf.Name).js"
    $scriptFile = Get-ChildItem -Path $scriptGlob -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($scriptFile) { $name = $scriptFile.BaseName -replace "-$([regex]::Escape($wf.Name))$", '' }

    if ($openAgents.Count -gt 0) {
      $status = if ($ageSec -gt $StallSeconds) { 'STALLED' } else { 'RUNNING' }
    } elseif ($blockedCount -gt 0) {
      $status = 'BLOCKED'
    } else {
      $status = 'idle'
    }

    # NB: avoid a local named $detail - it would collide (case-insensitively)
    # with the [switch]$Detail parameter and throw on string assignment.
    $detailLine = $null; $runTaskN = $null
    if ($openAgents.Count -gt 0) {
      $af = Join-Path $wf.FullName "agent-$($openAgents[-1].agentId).jsonl"
      $detailLine = Get-RunningTaskLabel $af
      if ($detailLine -match '^task-([0-9]+)') { $runTaskN = [int]$matches[1] }
    }
    if (-not $detailLine -and $results.Count -gt 0) { $detailLine = $results[-1].result.summary }
    $shortDetail = $detailLine
    if ($shortDetail -and $shortDetail.Length -gt 110) { $shortDetail = $shortDetail.Substring(0,107) + '...' }

    $rows += [pscustomobject]@{
      Status    = $status
      Name      = $name
      Workflow  = $wf.Name
      Session   = $sess.Name.Substring(0, 8)
      Done      = $doneCount
      Blocked   = $blockedCount
      Open      = $openAgents.Count
      AgeSec    = $ageSec
      LastWrite = $lastWrite
      Detail    = $shortDetail
      WfDir       = $wf.FullName
      IsExec      = ($name -eq 'execute-feature')
      RunTaskN    = $runTaskN
      TaskResults = $taskResults
    }
  }
}

if (-not $All) {
  $cutoff = $now.AddHours(-$SinceHours)
  $rows = @($rows | Where-Object { $_.LastWrite -ge $cutoff })
}
$rows = @($rows | Sort-Object AgeSec)

# Which rows get a per-task breakdown: all when -Detail, else RUNNING exec runs.
$detailRows = if ($Detail) { $rows } else { @($rows | Where-Object { $_.Status -eq 'RUNNING' -and $_.IsExec }) }

if ($Json) {
  foreach ($r in $rows) {
    $tb = if ($detailRows -contains $r) { Get-TaskBreakdown $r } else { @() }
    Add-Member -InputObject $r -NotePropertyName Tasks -NotePropertyValue $tb -Force
  }
  $rows | Select-Object Status,Name,Workflow,Session,Done,Blocked,Open,AgeSec,Detail,Tasks |
    ConvertTo-Json -Depth 6
  return
}

function Format-Age([int]$s) {
  if ($s -lt 90)     { return "${s}s" }
  if ($s -lt 5400)   { return "$([int]($s/60))m" }
  if ($s -lt 172800) { return "$([int]($s/3600))h" }
  return "$([int]($s/86400))d"
}

if ($rows.Count -eq 0) {
  $scope = if ($All) { 'any session' } else { "the last $SinceHours h" }
  Write-Host "No workflow runs found for this repo in $scope." -ForegroundColor DarkGray
  Write-Host "Scanned: $projDir" -ForegroundColor DarkGray
  Write-Host "(Add -All to include older runs.)" -ForegroundColor DarkGray
  return
}

Write-Host ""
Write-Host ("Workflows for this repo  ({0} shown, scanned {1})" -f $rows.Count, $projDir) -ForegroundColor Cyan
Write-Host ""
$fmt = "  {0,-8} {1,-20} {2,-16} {3,-9} {4,5} {5,7}"
Write-Host ($fmt -f 'STATUS','NAME','SESSION','LAST','TASKS','OPEN') -ForegroundColor DarkGray
foreach ($r in $rows) {
  $color = switch ($r.Status) {
    'RUNNING' { 'Green' }
    'STALLED' { 'Red' }
    'BLOCKED' { 'Yellow' }
    default   { 'Gray' }
  }
  $tasks = "$($r.Done)D" + $(if ($r.Blocked) { "/$($r.Blocked)B" } else { '' })
  $wfShort = $r.Workflow.Substring(0,[Math]::Min(6,$r.Workflow.Length))
  Write-Host ($fmt -f $r.Status, $r.Name, ($r.Session + '  ' + $wfShort), (Format-Age $r.AgeSec), $tasks, $r.Open) -ForegroundColor $color

  if ($detailRows -contains $r) {
    $breakdown = Get-TaskBreakdown $r
    if ($breakdown) {
      Write-Host ""
      foreach ($t in $breakdown) {
        switch ($t.State) {
          'done'    { $g = 'v'; $c = 'Green' }
          'running' { $g = '>'; $c = 'Cyan' }
          'partial' { $g = '~'; $c = 'Yellow' }
          'blocked' { $g = 'x'; $c = 'Red' }
          default   { $g = '.'; $c = 'DarkGray' }
        }
        $sha  = if ($t.Sha) { "  @$($t.Sha.Substring(0,[Math]::Min(7,$t.Sha.Length)))" } else { '' }
        $mark = if ($t.State -eq 'running') { '  (running now)' } else { '' }
        Write-Host ("      [{0}] Task {1}: {2}{3}{4}" -f $g, $t.N, $t.Title, $sha, $mark) -ForegroundColor $c
      }
      Write-Host ""
      continue
    }
  }
  if ($r.Detail) { Write-Host ("           - $($r.Detail)") -ForegroundColor DarkGray }
}
Write-Host ""
Write-Host "  RUNNING = open agent, fresh write   STALLED = open agent idle > ${StallSeconds}s   idle = all tasks resolved" -ForegroundColor DarkGray
Write-Host "  [v] done  [>] running  [~] partial  [x] blocked  [.] pending   -Detail = all runs, -All = older, -Json = raw." -ForegroundColor DarkGray
