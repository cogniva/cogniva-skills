# check-host-parity.ps1 - green-gate check of the agent host parity record.
# Derives the inventory from the repo (skill directories of every plugin, hook
# scripts named in plugins/*/hooks/hooks.json, overlay files that skills name,
# invocation metadata) and checks it against the `## Capabilities` table of
# docs/host-parity.md and the smoke records in docs/host-parity/smoke/.
# Prints one `FAIL <rule>: <detail>` line per problem; `WARN` lines never fail.
# Exit 0 = OK, 1 = at least one FAIL. PowerShell 7 (ADR 0039).
[CmdletBinding()]
param([string]$Root)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$Root = [System.IO.Path]::GetFullPath($Root)

$dash = [string][char]0x2014
$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
function Fail([string]$Rule, [string]$Detail) { $script:failures.Add("FAIL ${Rule}: $Detail") }
function Warn([string]$Detail) { $script:warnings.Add("WARN $Detail") }
function Read-Text([string]$Path) { return [System.IO.File]::ReadAllText($Path) }
function Test-None([string]$Cell) { $t = $Cell.Trim(); return ($t -eq '' -or $t -eq $dash -or $t -eq '-') }
function Split-List([string]$Cell) {
    if (Test-None $Cell) { return @() }
    return @($Cell.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
function Split-Row([string]$Line) {
    $t = $Line.Trim()
    if ($t.StartsWith('|')) { $t = $t.Substring(1) }
    if ($t.EndsWith('|')) { $t = $t.Substring(0, $t.Length - 1) }
    return @($t.Split('|') | ForEach-Object { $_.Trim() })
}

$expectedColumns = @('ID', 'Capability', 'Kind', 'Covers', 'Claude Code', 'Codex', 'Evidence', 'Notes')
$statuses = @('verified', 'scripts-tested', 'untested', 'partial', 'unsupported', 'n/a')
$kinds = @('packaging', 'workflow', 'enforcement', 'tooling')
$modes = @('worktree', 'lean')
$hostColumns = @('Claude Code', 'Codex')
$overlayPattern = '(?<![\w./-])(?:\.\./(?<skill>[a-z0-9-]+)/)?(?<file>CODEX|WORKTREE|HANDOFF|WORKFLOW-NOTES)\.md'

# --- derived inventory -------------------------------------------------------
$pluginsDir = Join-Path $Root 'plugins'
$plugins = @(if (Test-Path -LiteralPath $pluginsDir) { Get-ChildItem -LiteralPath $pluginsDir -Directory | Sort-Object Name })
$skillDirs = [ordered]@{}
foreach ($p in $plugins) {
    $sd = Join-Path $p.FullName 'skills'
    if (-not (Test-Path -LiteralPath $sd)) { continue }
    foreach ($s in Get-ChildItem -LiteralPath $sd -Directory | Sort-Object Name) {
        $skillDirs["skill:$($p.Name)/$($s.Name)"] = $s.FullName
    }
}
$hookItems = [System.Collections.Generic.List[string]]::new()
foreach ($p in $plugins) {
    $hj = Join-Path $p.FullName 'hooks\hooks.json'
    if (-not (Test-Path -LiteralPath $hj)) { continue }
    foreach ($m in [regex]::Matches((Read-Text $hj), '"command"\s*:\s*"(?<cmd>(?:[^"\\]|\\.)*)"')) {
        foreach ($s in [regex]::Matches($m.Groups['cmd'].Value, 'scripts/(?<name>[A-Za-z0-9_.-]+\.js)')) {
            $id = "hook:$($s.Groups['name'].Value)"
            if (-not $hookItems.Contains($id)) { $hookItems.Add($id) }
        }
    }
}
$gatePath = Join-Path $Root '.claude\cogniva-dev\green-gate.json'
$gateLabels = @()
if (Test-Path -LiteralPath $gatePath) {
    $gateLabels = @((Read-Text $gatePath | ConvertFrom-Json).commands | ForEach-Object { [string]$_.label })
}
$currentMinor = ''
$devManifest = Join-Path $Root 'plugins\cogniva-dev\.claude-plugin\plugin.json'
if (Test-Path -LiteralPath $devManifest) {
    $v = [regex]::Match([string](Read-Text $devManifest | ConvertFrom-Json).version, '^(?<maj>\d+)\.(?<min>\d+)')
    if ($v.Success) { $currentMinor = "$($v.Groups['maj'].Value).$($v.Groups['min'].Value)" }
}

# --- (h) overlay existence and (i) invocation metadata, per skill directory ----
foreach ($id in $skillDirs.Keys) {
    $dir = $skillDirs[$id]
    $name = $id.Substring('skill:'.Length)
    foreach ($md in @(Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Extension -eq '.md' })) {
        foreach ($m in [regex]::Matches((Read-Text $md.FullName), $overlayPattern)) {
            $file = "$($m.Groups['file'].Value).md"
            $target = if ($m.Groups['skill'].Success) { Join-Path (Join-Path (Split-Path -Parent $dir) $m.Groups['skill'].Value) $file } else { Join-Path $dir $file }
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                Fail 'missing-overlay' "$name/$($md.Name) names $($m.Value), which does not exist"
            }
        }
    }
    $claudeFlag = $false
    $skillMd = Join-Path $dir 'SKILL.md'
    if (Test-Path -LiteralPath $skillMd) {
        $fm = [regex]::Match((Read-Text $skillMd), '\A﻿?---\r?\n(?<fm>[\s\S]*?)\r?\n---')
        if ($fm.Success -and $fm.Groups['fm'].Value -match '(?m)^disable-model-invocation:[ \t]*true\b') { $claudeFlag = $true }
    }
    $codexFlag = $false
    $yaml = Join-Path $dir 'agents\openai.yaml'
    if (Test-Path -LiteralPath $yaml) {
        $inPolicy = $false
        foreach ($line in ((Read-Text $yaml) -split '\r?\n')) {
            if ($line -match '^\S') { $inPolicy = ($line -match '^policy:') }
            elseif ($inPolicy -and $line -match '^\s+allow_implicit_invocation:[ \t]*false\b') { $codexFlag = $true }
        }
    }
    if ($claudeFlag -and -not $codexFlag) {
        Fail 'invocation-metadata' "$name has disable-model-invocation: true without agents/openai.yaml allow_implicit_invocation: false"
    }
    elseif ($codexFlag -and -not $claudeFlag) {
        Fail 'invocation-metadata' "$name has agents/openai.yaml allow_implicit_invocation: false without disable-model-invocation: true"
    }
}

# --- smoke records -----------------------------------------------------------
$smokeDir = Join-Path $Root 'docs\host-parity\smoke'
$smokeCache = @{}
function Get-SmokeRecord([string]$Id) {
    if ($script:smokeCache.ContainsKey($Id)) { return $script:smokeCache[$Id] }
    $path = Join-Path $script:smokeDir "$Id.md"
    $record = $null
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $text = Read-Text $path
        $fields = @{}
        foreach ($line in ($text -split '\r?\n')) {
            $m = [regex]::Match($line, '^(?<k>Agent host|Plugin versions|Covers):\s*(?<v>.+)')
            if ($m.Success -and -not $fields.ContainsKey($m.Groups['k'].Value)) { $fields[$m.Groups['k'].Value] = $m.Groups['v'].Value.Trim() }
        }
        $ver = [regex]::Match([string]$fields['Plugin versions'], 'cogniva-dev\s+(?<maj>\d+)\.(?<min>\d+)')
        $record = [pscustomobject]@{
            Id       = $Id
            Host     = [string]$fields['Agent host']
            Covers   = @(Split-List ([string]$fields['Covers']))
            HasFail  = [regex]::IsMatch($text, '(?m)^\s*\|.*\|\s*fail\s*\|')
            DevMinor = $(if ($ver.Success) { "$($ver.Groups['maj'].Value).$($ver.Groups['min'].Value)" } else { '' })
        }
    }
    $script:smokeCache[$Id] = $record
    return $record
}

# --- the Capabilities table ----------------------------------------------------
$rows = [System.Collections.Generic.List[object]]::new()
$tableOk = $false
$recordPath = Join-Path $Root 'docs\host-parity.md'
if (-not (Test-Path -LiteralPath $recordPath)) { Fail 'table-format' 'docs/host-parity.md not found' }
else {
    $lines = (Read-Text $recordPath) -split '\r?\n'
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '## Capabilities') { $start = $i; break } }
    if ($start -lt 0) { Fail 'table-format' 'docs/host-parity.md has no ## Capabilities section' }
    else {
        $i = $start + 1
        while ($i -lt $lines.Count -and -not $lines[$i].TrimStart().StartsWith('|') -and -not $lines[$i].StartsWith('## ')) { $i++ }
        if ($i -ge $lines.Count -or -not $lines[$i].TrimStart().StartsWith('|')) { Fail 'table-format' 'the ## Capabilities section has no table' }
        else {
            $header = @(Split-Row $lines[$i])
            if (($header -join '|') -cne ($expectedColumns -join '|')) {
                Fail 'table-format' "Capabilities columns are '$($header -join ' | ')', expected '$($expectedColumns -join ' | ')'"
            }
            else {
                $tableOk = $true
                $col = @{}
                for ($c = 0; $c -lt $header.Count; $c++) { $col[$header[$c]] = $c }
                $i += 2
                while ($i -lt $lines.Count -and $lines[$i].TrimStart().StartsWith('|')) {
                    $cells = @(Split-Row $lines[$i])
                    if ($cells.Count -ne $expectedColumns.Count) {
                        Fail 'table-format' "Capabilities line $($i + 1) has $($cells.Count) cells, expected $($expectedColumns.Count)"
                    }
                    else {
                        $rows.Add([pscustomobject]@{
                            Id = $cells[$col['ID']]; Kind = $cells[$col['Kind']]; Covers = $cells[$col['Covers']]
                            'Claude Code' = $cells[$col['Claude Code']]; Codex = $cells[$col['Codex']]
                            Evidence = $cells[$col['Evidence']]; Notes = $cells[$col['Notes']]
                        })
                    }
                    $i++
                }
            }
        }
    }
}

# --- per-row rules -------------------------------------------------------------
$coverage = [ordered]@{}
$seenIds = @{}
foreach ($row in $rows) {
    $rid = $row.Id
    if ($rid -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*\z') { Fail 'bad-id' "'$rid' is not a kebab-case row ID" }
    if ($seenIds.ContainsKey($rid)) { Fail 'duplicate-id' "row ID '$rid' appears more than once" }
    $seenIds[$rid] = $true
    if ($kinds -cnotcontains $row.Kind) { Fail 'bad-kind' "$rid has Kind '$($row.Kind)'; expected one of $($kinds -join ', ')" }

    # (a)(b)(c) coverage and resolution
    $items = @(Split-List $row.Covers)
    if ($items.Count -eq 0) { Fail 'no-covers' "$rid covers no item" }
    foreach ($item in $items) {
        if (-not $coverage.Contains($item)) { $coverage[$item] = [System.Collections.Generic.List[string]]::new() }
        $coverage[$item].Add($rid)
        $ok = $false
        if ($item -cmatch '^skill:') { $ok = $skillDirs.Contains($item) }
        elseif ($item -cmatch '^hook:') { $ok = $hookItems.Contains($item) }
        elseif ($item -cmatch '^manifest:(?<p>[A-Za-z0-9_.-]+)\z') { $ok = Test-Path -LiteralPath (Join-Path $pluginsDir $Matches['p']) -PathType Container }
        elseif ($item -cmatch '^mode:(?<m>.+)\z') { $ok = $modes -ccontains $Matches['m'] }
        if (-not $ok) { Fail 'stale-item' "$rid covers $item, which does not resolve to anything in the repo" }
    }

    # evidence (f)(j)
    $gates = @(); $smokes = @()
    foreach ($e in @(Split-List $row.Evidence)) {
        if ($e -cmatch '^gate:(?<l>.+)\z') { $gates += $Matches['l'] }
        elseif ($e -cmatch '^smoke:(?<s>.+)\z') { $smokes += $Matches['s'] }
        else { Fail 'bad-evidence' "$rid evidence '$e' is neither gate:<label> nor smoke:<record-id>" }
    }
    foreach ($g in $gates) {
        if ($gateLabels -cnotcontains $g) { Fail 'unknown-gate-label' "$rid cites gate:$g, which is not a label in .claude/cogniva-dev/green-gate.json" }
    }
    foreach ($s in $smokes) {
        if (-not (Get-SmokeRecord $s)) { Fail 'missing-smoke-record' "$rid cites smoke:$s, but docs/host-parity/smoke/$s.md does not exist" }
    }

    # (d)(e)(f)(g) per agent host column
    foreach ($h in $hostColumns) {
        $status = ([regex]::Split($row.$h, '\s+' + $dash + '\s+', 2)[0]).Trim()
        if ($statuses -cnotcontains $status) { Fail 'bad-status' "$rid $h status '$status' is not one of $($statuses -join ', ')"; continue }
        switch ($status) {
            'verified' {
                if ($smokes.Count -eq 0) { Fail 'verified-no-smoke' "$rid is verified on $h with no smoke: evidence"; break }
                $qualifying = @(); $reasons = @()
                foreach ($s in $smokes) {
                    $r = Get-SmokeRecord $s
                    if (-not $r) { continue }
                    if ($r.Host -cne $h) { $reasons += @{ Rule = 'smoke-host-mismatch'; Detail = "$rid is verified on $h but smoke:$s was recorded on '$($r.Host)'" } }
                    elseif ($r.Covers -cnotcontains $rid) { $reasons += @{ Rule = 'smoke-not-covering'; Detail = "$rid is verified on $h but smoke:$s does not list $rid in Covers:" } }
                    elseif ($r.HasFail) { $reasons += @{ Rule = 'smoke-failed'; Detail = "$rid is verified on $h but smoke:$s has a fail result" } }
                    else { $qualifying += $r }
                }
                if ($qualifying.Count -eq 0) { foreach ($x in $reasons) { Fail $x.Rule $x.Detail } }
                elseif (-not @($qualifying | Where-Object { $_.DevMinor -and $_.DevMinor -eq $currentMinor })) { Warn "stale evidence: $rid $h" }
            }
            'scripts-tested' {
                if ($gates.Count -eq 0) { Fail 'scripts-tested-no-gate' "$rid is scripts-tested on $h with no gate: evidence" }
            }
            default {
                if ($status -in @('partial', 'unsupported', 'n/a') -and (Test-None $row.Notes)) {
                    Fail 'notes-required' "$rid is $status on $h with no Notes"
                }
            }
        }
    }
    if ($row.Kind -ceq 'enforcement' -and (Test-None $row.Notes)) { Fail 'notes-required' "$rid is enforcement with no Notes (state its limits)" }
}

# --- (a)(b) every derived item covered exactly once (only when the table parsed) ---
if ($tableOk) {
    foreach ($id in $skillDirs.Keys) { if (-not $coverage.Contains($id)) { Fail 'uncovered-skill' "$id has no row in docs/host-parity.md" } }
    foreach ($id in $hookItems) { if (-not $coverage.Contains($id)) { Fail 'uncovered-hook' "$id has no row in docs/host-parity.md" } }
}
foreach ($item in $coverage.Keys) {
    if ($coverage[$item].Count -gt 1) { Fail 'duplicate-coverage' "$item is covered by rows $($coverage[$item] -join ', ')" }
}

foreach ($w in $warnings) { Write-Output $w }
if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Output $f }
    Write-Output "host-parity: FAILED - $($failures.Count) problem(s)"
    exit 1
}
Write-Output "host-parity: OK - $($rows.Count) rows, $($coverage.Count) items covered"
exit 0
