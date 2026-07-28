# Close out cogniva worktrees from the shared JSON ledger. The engine behind both
# cleanup-work (Scope 'list' = this session's worktrees) and cleanup-allwork
# (Scope 'all' = every cleanupable record, any session).
#
# INVARIANT: this script NEVER writes to or commits in the PRIMARY checkout's
# working tree. The ONLY way anything lands on the user's branch is a committed
# fast-forward merge from a worktree (integrate-feature.ps1). The close-out
# Status flip is therefore made IN THE WORKTREE, committed on the feature branch,
# and merged in - it is never written into the primary tree (that is the bug this
# design exists to prevent; user decision 2026-06-18: nothing the AI does may
# write the primary checkout outside a committed worktree merge).
#
# Only ever acts on records whose state is 'cleanupable' (work committed +
# integrated + green, awaiting validation). 'in-progress' records are NEVER
# touched. For each in-scope cleanupable record:
#   1. If the worktree path is gone -> prune the stale record.
#   2. If the worktree is clean: flip its OWN state.md Status (recipe) + commit on
#      the feature branch, fast-forward integrate (lands the flip AND any commits
#      still queued from an earlier QUEUED_DIRTY), re-check, then remove the
#      worktree, delete the merged feature branch (`branch -d` ONLY - git refuses
#      unless fully merged, so nothing can be destroyed; never -D), and prune.
#   3. If the worktree is dirty, or it still will not merge -> keep it (branch
#      included), with a reason. Never --force, never push to a remote, never
#      touch the primary working tree.
#   4. If the worktree directory exists but is GUTTED (contents + .git file gone -
#      the leftover of a `worktree remove` that deleted the contents and then
#      failed on the directory), FINISH the job: prune the metadata, delete the
#      merged branch (-d), remove the empty directory, and only then drop the
#      record. See the gutted block below for why pruning it outright was wrong.
#
# Stale records (worktree path missing) are pruned regardless of state.
#
# Output (last line): JSON { closed:[...], kept:[...], pruned:[...] }
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$TargetBranch,
    [ValidateSet('all','list')][string]$Scope = 'all',
    [string[]]$Worktrees = @()    # required when Scope = 'list' (this session's worktree paths)
)
$ErrorActionPreference = 'Stop'

# Run a git command resiliently under $ErrorActionPreference='Stop'. git writes
# benign warnings to stderr - most commonly "warning: LF will be replaced by CRLF"
# when an autocrlf/.gitattributes repo stages a LF file. Under 'Stop', PowerShell
# 5.1 turns that stderr line into a TERMINATING NativeCommandError (even with
# 2>&1 | Out-Null), which a surrounding try/catch then mistakes for a git FAILURE.
# exactly how the close-out commit was being silently dropped - the flip stayed
# uncommitted and the worktree was kept forever. So localize the preference to
# 'Continue' for the native call and judge success by the exit code alone.
# Returns $true iff git exited 0.
#
# ALWAYS go through these wrappers - a bare `& git` under the script's top-level
# 'Stop' is the landmine they exist to defuse, and inside a try/catch that returns
# a bare $false it fails INVISIBLY.
#
# Two PowerShell parser traps when calling them (both are advanced functions, so
# PowerShell binds arguments before git ever sees them):
#   * a bare `--` is the end-of-parameters token and is SWALLOWED - it never
#     reaches git, so pathspecs arrive unseparated from revisions. Quote it: '--'.
#   * a bare `-d` prefix-binds to the common -Debug parameter. Quote it: '-d'.
function Invoke-Git {
    param([string]$Worktree, [Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git -C $Worktree @GitArgs 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } finally { $ErrorActionPreference = $old }
}

# Output-returning sibling of Invoke-Git, for callers that need git's stdout, not
# just success/failure. Same rationale: a bare `git -C` under 'Stop' turns benign
# stderr into a terminating error that only the OUTER catch sees - one such call
# mid-sweep aborted the ENTIRE sweep for every record. Localize the preference,
# suppress stderr, and return the stdout lines - an EMPTY array on failure, so
# callers can treat "git failed" like "no output" and the sweep keeps going.
function Invoke-GitOut {
    param([string]$Worktree, [Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = @(& git -C $Worktree @GitArgs 2>$null)
        if ($LASTEXITCODE -ne 0) { return @() }
        return $out
    } finally { $ErrorActionPreference = $old }
}

# stderr-CAPTURING sibling of Invoke-Git, for the calls whose failure MESSAGE is
# the diagnosis. `worktree remove` failing on Windows says exactly which path it
# could not delete and why ("Permission denied" / "The process cannot access the
# file because it is being used by another process"); `branch -d` explains its
# refusal. Reporting a bare 'worktree remove failed' threw all of that away and
# made the failure un-self-diagnosable. Same $ErrorActionPreference dance as
# Invoke-Git; merges stderr into stdout. Returns { ok, text }.
function Invoke-GitCapture {
    param([string]$Worktree, [Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = @(& git -C $Worktree @GitArgs 2>&1 | ForEach-Object { "$_" })
        return [pscustomobject]@{ ok = ($LASTEXITCODE -eq 0); text = ($out -join "`n") }
    } finally { $ErrorActionPreference = $old }
}

# Condense a (possibly multi-line) git message into ONE short line fit for a
# `kept` reason, which the skills echo verbatim to the user.
function Format-GitError([string]$Text, [int]$Max = 300) {
    if (-not $Text) { return '(no output)' }
    $lines = @(($Text -split "`r?`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($lines.Count -eq 0) { return '(no output)' }
    $msg = ($lines -join '; ')
    if ($msg.Length -gt $Max) { $msg = $msg.Substring(0, $Max - 3) + '...' }
    return $msg
}

# Flip the Status line IN THE WORKTREE copy of state.md and commit it on the
# feature branch. $StatePath is the recipe's reference path (rooted in the PRIMARY
# checkout); we map it into $Worktree and only ever edit/commit THERE. Returns
# a result object { committed; error } - `committed` $true only if a commit was
# actually made, `error` carrying git's own words when one was attempted and
# failed. The caller reports `error` verbatim: a close-out commit that dies
# silently is indistinguishable from user WIP, which is the bug this shape fixes.
# Never writes the primary tree.
function Set-StateStatusInWorktree([string]$StatePath, [string]$TargetStatus, [string]$Worktree, [string]$RepoRoot) {
    $result = [pscustomobject]@{ committed = $false; error = $null }
    if (-not $StatePath -or -not $TargetStatus -or -not $Worktree) {
        $result.error = 'close-out recipe incomplete (missing statePath / targetStatus / worktree)'; return $result
    }
    # Defense-in-depth against a legacy/bad ledger record: the flip+append is only
    # ever valid on a plan state.md. Refuse any other target (e.g. a .cs source) so
    # a stale recipe can never corrupt and FF a broken source file onto the branch.
    if ((Split-Path $StatePath -Leaf) -ine 'state.md') {
        $result.error = "close-out recipe statePath is not a state.md: $StatePath"; return $result
    }
    try {
        $root = ($RepoRoot -replace '/','\').TrimEnd('\')
        $sp   = ($StatePath -replace '/','\')
        if (-not $sp.ToLowerInvariant().StartsWith($root.ToLowerInvariant() + '\')) {
            $result.error = "close-out recipe statePath is outside the repo: $StatePath"; return $result
        }
        $rel = $sp.Substring($root.Length).TrimStart('\')
        $wtState = Join-Path $Worktree $rel
        if (-not (Test-Path -LiteralPath $wtState)) {
            $result.error = "close-out state.md not found in worktree: $wtState"; return $result
        }
        $text = Get-Content -Raw -LiteralPath $wtState
        # Idempotent: only rewrite when something actually changes. A re-run over an
        # already-closed-out worktree must leave the tree CLEAN - otherwise the
        # re-appended line re-dirties it, the commit then trips the dirty-check, and
        # the worktree is kept forever (self-blocking loop). So flip Status only if
        # not already at target, and append the close-out line only if absent.
        $statusOk   = [regex]::IsMatch($text, "(?m)^Status:\s*$([regex]::Escape($TargetStatus))\s*$")
        $closeoutOk = [regex]::IsMatch($text, '(?m)^- Closed out \(')
        $new = $text
        if (-not $statusOk)   { $new = [regex]::Replace($new, '(?m)^Status:.*$', "Status: $TargetStatus", 1) }
        if (-not $closeoutOk) {
            $stamp = (Get-Date).ToString('yyyy-MM-dd')
            $new = $new.TrimEnd() + "`n- Closed out ($stamp): validated, worktree removed.`n"
        }
        if ($new -ne $text) { Set-Content -LiteralPath $wtState -Value $new }
        # Commit if (and only if) this state.md is now dirty in git. This covers the
        # case where a PRIOR sweep already flipped Status in the working tree but its
        # commit was interrupted - the content can be fully at target ($new -eq $text)
        # yet the tree is dirty. Early-returning here would leave that flip
        # uncommitted, the dirty-check would keep the worktree forever. So decide on
        # git's view of the file, not on whether THIS call rewrote it. Nothing dirty
        # is the normal no-op path, NOT an error.
        if (@(Invoke-GitOut $Worktree status --porcelain '--' $wtState).Count -eq 0) { return $result }
        $add = Invoke-GitCapture $Worktree add '--' $wtState
        if (-not $add.ok) { $result.error = "close-out `git add` failed: $(Format-GitError $add.text)"; return $result }
        # Retry the commit ONCE. This commit has been observed to fail and then
        # succeed immediately afterwards (a transient the discarded error text made
        # un-diagnosable), and every failure costs the user a whole extra sweep. A
        # second attempt is free when the first worked and is the whole fix when it
        # did not. Between attempts, re-check dirt: if the file is already clean the
        # commit DID land and only its reporting failed - treat that as success.
        $msg = "chore: close out feature (Status: $TargetStatus)"
        for ($attempt = 1; $attempt -le 2; $attempt++) {
            $c = Invoke-GitCapture $Worktree commit -m $msg '--' $wtState
            if ($c.ok) { $result.committed = $true; $result.error = $null; return $result }
            if (@(Invoke-GitOut $Worktree status --porcelain '--' $wtState).Count -eq 0) {
                $result.committed = $true; $result.error = $null; return $result
            }
            $result.error = "close-out commit failed: $(Format-GitError $c.text)"
            if ($attempt -lt 2) { Start-Sleep -Milliseconds 400 }
        }
        return $result
    } catch { $result.error = "close-out flip threw: $_"; return $result }
}

# Map the recipe's statePath (rooted in the PRIMARY checkout) to a repo-relative,
# forward-slash path - the form `git status --porcelain` emits. Returns $null for a
# missing/non-state.md/out-of-tree path. Used to tell the recipe's own close-out
# flip apart from genuine user WIP in the dirty-guard.
function Get-RecipeStateRel([string]$StatePath, [string]$RepoRoot) {
    if (-not $StatePath) { return $null }
    if ((Split-Path $StatePath -Leaf) -ine 'state.md') { return $null }
    $root = ($RepoRoot -replace '/','\').TrimEnd('\')
    $sp   = ($StatePath -replace '/','\')
    if (-not $sp.ToLowerInvariant().StartsWith($root.ToLowerInvariant() + '\')) { return $null }
    return ($sp.Substring($root.Length).TrimStart('\') -replace '\\','/')
}

# Parse `git status --porcelain` lines into the set of repo-relative paths they
# touch (handles quoted paths and "old -> new" rename entries by taking the
# destination). Used to classify worktree dirt.
function Get-DirtyPaths([string]$Worktree) {
    $out = @()
    foreach ($line in @(Invoke-GitOut $Worktree status --porcelain)) {
        if (-not $line) { continue }
        $p = $line.Substring(3).Trim()
        if ($p -match ' -> ') { $p = ($p -split ' -> ')[-1].Trim() }
        $out += $p.Trim('"')
    }
    return $out
}

# Strip the Status line and any close-out marker lines and normalize EOL, so two
# state.md versions can be compared for whether they differ ONLY in the parts the
# close-out recipe is allowed to touch.
function Get-StateCanonical([string]$Text) {
    if (-not $Text) { return '' }
    $lines = ($Text -replace "`r`n","`n" -replace "`r","`n") -split "`n"
    $kept = foreach ($l in $lines) {
        if ($l -match '^\s*Status:')          { continue }
        if ($l -match '^\s*- Closed out \(')  { continue }
        $l
    }
    return (($kept -join "`n").TrimEnd())
}

# True only if the worktree's uncommitted change to its state.md is confined to the
# recipe's OWN close-out flip: the Status set to the target status (or still at the
# committed value) plus an optional "- Closed out (...)" line - nothing else. A
# deliberate manual edit (Status moved to in-progress/blocked/deferred, or body text
# added) returns $false, so the sweep KEEPS the worktree instead of auto-committing +
# closing over real work and clobbering the status. Compares the working tree against
# the COMMITTED (HEAD) state.md; EOL differences are ignored.
function Test-CloseoutOnlyChange([string]$Worktree, [string]$RecipeRel, [string]$TargetStatus) {
    try {
        if (-not $RecipeRel) { return $false }
        # Via the wrapper, never a bare `& git` (see Invoke-Git). Invoke-GitOut is
        # stdout-only, so no stderr warning can pollute the canonical comparison and
        # misreport a clean close-out flip as a manual edit. Empty output means the
        # file is missing or unreadable at HEAD - fail closed and keep the worktree.
        $headLines = @(Invoke-GitOut $Worktree show "HEAD:$RecipeRel")
        if ($headLines.Count -eq 0) { return $false }
        $headText = ($headLines -join "`n")
        $wtPath = Join-Path $Worktree ($RecipeRel -replace '/','\')
        if (-not (Test-Path -LiteralPath $wtPath)) { return $false }
        $wtText = Get-Content -Raw -LiteralPath $wtPath
        # The working-tree Status must be the close-out target or unchanged from the
        # committed value - never some OTHER state the user deliberately set.
        $headStatus = [regex]::Match($headText, '(?m)^\s*Status:\s*(.+?)\s*$').Groups[1].Value
        $wtStatus   = [regex]::Match($wtText,   '(?m)^\s*Status:\s*(.+?)\s*$').Groups[1].Value
        if ($wtStatus -and ($wtStatus -ine $TargetStatus) -and ($wtStatus -ine $headStatus)) { return $false }
        # Everything outside the Status / close-out lines must be byte-identical to HEAD.
        return ((Get-StateCanonical $headText) -eq (Get-StateCanonical $wtText))
    } catch { return $false }
}

# Remove a STALE per-worktree index.lock left by an interrupted git process - the
# second half of the "kept forever" failure: even once the dirty-guard lets the
# recipe run, its commit dies on `Unable to create .git/worktrees/<wt>/index.lock`
# and the flip stays uncommitted. We only delete a lock older than $MinAgeSeconds: a
# live git operation holds its index.lock for a fraction of a second (a one-file doc
# commit), so a lock older than two minutes is leftover, not in-flight. Sweeps are
# serialized by the ledger lock, so no concurrent sweep can own it either. Never
# touches MERGE_HEAD/ORIG_HEAD (a real in-progress merge is meaningful). Returns
# $true if a stale lock was cleared.
function Clear-StaleGitLock([string]$Worktree, [int]$MinAgeSeconds = 120) {
    try {
        $gd = (git -C $Worktree rev-parse --absolute-git-dir 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $gd) { return $false }
        $lock = Join-Path $gd 'index.lock'
        if (-not (Test-Path -LiteralPath $lock)) { return $false }
        $age = ((Get-Date) - (Get-Item -LiteralPath $lock).LastWriteTime).TotalSeconds
        if ($age -lt $MinAgeSeconds) { return $false }   # possibly in-flight - leave it
        Remove-Item -LiteralPath $lock -Force -ErrorAction Stop
        return $true
    } catch { return $false }
}

function Invoke-Integrate([string]$Worktree, [string]$Branch, [string]$TargetBranch, [string]$RepoRoot) {
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'integrate-feature.ps1') `
            -WorktreePath $Worktree -FeatureBranch $Branch -TargetBranch $TargetBranch -RepoRoot $RepoRoot 2>$null | Out-Null
    } catch { }
}

function Get-MergedSet([string]$RepoRoot, [string]$TargetBranch) {
    $m = @{}
    foreach ($b in @(Invoke-GitOut $RepoRoot branch --merged $TargetBranch --format='%(refname:short)')) {
        $n = $b.Trim(); if ($n) { $m[$n] = $true }
    }
    return $m
}

try {
    if (-not $RepoRoot) {
        # Anchor the default root to the PRIMARY checkout, never to wherever the
        # caller happens to be standing. `--show-toplevel` resolves to the CURRENT
        # worktree - invoked from inside a feature worktree it made the sweep
        # target ITSELF ($TargetBranch became the feature branch, the branch was
        # "integrated" into itself, and `worktree remove` gutted the very worktree
        # the sweep was rooted in). The common dir is <primary>/.git no matter
        # which worktree we run from, so its parent IS the primary root.
        $commonGitDir = (@(Invoke-GitOut '.' rev-parse --path-format=absolute --git-common-dir) -join '').Trim()
        if (-not $commonGitDir) { throw 'not inside a git repository (cannot locate the primary checkout)' }
        $RepoRoot = Split-Path -Parent $commonGitDir
    }
    # Stand in the PRIMARY checkout, never in a worktree we are about to remove.
    # This process inherits its cwd from the calling shell, and the green gate runs
    # with the worktree root as cwd - so cleanup is routinely launched from inside
    # the very directory it must delete. Windows refuses to remove a directory that
    # is a live process's cwd: git deletes the CONTENTS, fails on the directory
    # itself, and leaves a gutted husk behind. Moving out takes this process (and
    # the integrate-feature child that inherits from it) out of that equation.
    # A *parent* shell parked in the worktree still locks it - which is why the
    # cleanup skills tell the agent to cd out first, and why the gutted-worktree
    # recovery below exists as the backstop when both of those fail.
    try { Set-Location -LiteralPath $RepoRoot } catch {}
    if (-not $TargetBranch) { $TargetBranch = (@(Invoke-GitOut $RepoRoot branch --show-current) -join '').Trim() }
    . (Join-Path $PSScriptRoot 'ledger-lib.ps1')
    $commonDir = Get-CommonDir $RepoRoot
    $ledger = Get-LedgerPath $commonDir

    $closed = @(); $kept = @(); $pruned = @()

    $lock = Lock-Ledger $commonDir
    try {
        $records = @(Read-Ledger $ledger)
        if ($records.Count -eq 0) {
            [pscustomobject]@{ closed = $closed; kept = $kept; pruned = $pruned } | ConvertTo-Json -Compress -Depth 8
            exit 0
        }

        # Selector for Scope = 'list'. Flatten/split the incoming paths first:
        # invoked as `-Worktrees "a","b","c"` through `powershell -File` from a
        # NON-PowerShell parent (the Bash tool / Git Bash), the comma-joined token
        # arrives as a SINGLE string element "a,b,c" rather than a 3-element array,
        # so the selector would build one bogus key and match nothing (all-empty,
        # silent no-op). Splitting on commas makes the documented comma form work
        # regardless of how the parent shell tokenizes it, and is a no-op for a real
        # multi-element array.
        $Worktrees = @($Worktrees | ForEach-Object { $_ -split ',' } |
                       ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $wanted = @{}
        foreach ($w in $Worktrees) { if ($w) { $wanted[(Get-CanonicalPath $w)] = $true } }

        $merged = Get-MergedSet $RepoRoot $TargetBranch

        $remaining = @()
        foreach ($r in $records) {
            $wt = $r.worktree; $branch = $r.branch
            $key = if ($wt) { Get-CanonicalPath $wt } else { '' }
            # Per-record isolation: any unexpected throw below costs only THIS record.
            # Before this wrap, one poisoned record (a gutted worktree, one git stderr
            # line promoted to a terminating error) escaped to the OUTER catch and
            # aborted the whole sweep for every other worktree. Keep the record, with
            # the error as the reason, and move on.
            try {

                # Stale: worktree gone -> prune regardless of state.
                if (-not $wt -or -not (Test-Path $wt)) { $pruned += $wt; continue }

                $inScope = ($Scope -eq 'all') -or $wanted.ContainsKey($key)
                $sp = $null; $ts = $null; $sum = $null; $fu = $null
                if ($r.recipe) { $sp = $r.recipe.statePath; $ts = $r.recipe.targetStatus; $sum = $r.recipe.summary; $fu = $r.recipe.followups }

                # GUTTED worktree: the directory survives but its contents and .git
                # file are gone, so every git call inside it dies with "not a git
                # repository". It must be handled HERE, before the git calls below.
                #
                # This is the signature of a FAILED `git worktree remove`: git deletes
                # the contents bottom-up, then cannot rmdir the root because a live
                # process has it as its cwd (Windows locks it). What is left behind is
                # NOT a cleaned-up worktree - the merged feature branch is still
                # undeleted and the empty directory is still there, and this ledger
                # record is the only thing that still knows about either. Pruning it
                # (the old behaviour) reported success and orphaned both. So finish
                # the job instead: prune metadata, delete the merged branch, remove
                # the husk - and if any of that cannot be done, KEEP the record with a
                # reason rather than dropping it.
                if (-not (Invoke-Git $wt rev-parse --is-inside-work-tree)) {
                    if ($r.state -ne 'cleanupable' -or -not $inScope) {
                        # Not ours to finish. A gutted 'in-progress' worktree means work
                        # may have been lost, and its branch is probably unmerged - keep
                        # the record (and the branch) visible for a human either way.
                        $remaining += $r
                        if ($inScope) {
                            $kept += [pscustomobject]@{ branch = $branch; worktree = $wt
                                reason = "worktree directory exists but is not a git worktree, and the record is '$($r.state)' - left for inspection" }
                        }
                        continue
                    }
                    # Only an empty HUSK may be finished automatically. If any file
                    # survives under it this is not the leftover of a failed remove -
                    # keep it untouched; deleting real content is never this script's call.
                    $leftover = @()
                    try { $leftover = @(Get-ChildItem -LiteralPath $wt -Recurse -Force -File -ErrorAction SilentlyContinue) } catch {}
                    if ($leftover.Count -gt 0) {
                        $remaining += $r
                        $kept += [pscustomobject]@{ branch = $branch; worktree = $wt
                            reason = "worktree is not a git worktree but still holds $($leftover.Count) file(s) - left for inspection" }
                        continue
                    }
                    # Drop the stale worktree metadata FIRST: while git still believes
                    # the branch is checked out in a worktree, `branch -d` refuses it.
                    Invoke-Git $RepoRoot worktree prune | Out-Null
                    $branchDeleted = $false
                    if (Invoke-Git $RepoRoot rev-parse --verify --quiet "refs/heads/$branch") {
                        $merged = Get-MergedSet $RepoRoot $TargetBranch
                        if (-not $merged.ContainsKey($branch)) {
                            # Unmerged commits behind a vanished worktree. -d would refuse
                            # anyway and -D is forbidden - so keep the branch AND the
                            # record, loudly. This is the one case that must never be
                            # tidied away silently.
                            $remaining += $r
                            $kept += [pscustomobject]@{ branch = $branch; worktree = $wt
                                reason = "worktree gutted (contents gone - likely a failed remove) and '$branch' is NOT merged into $TargetBranch; branch and record kept for inspection" }
                            continue
                        }
                        $del = Invoke-GitCapture $RepoRoot branch '-d' $branch
                        $branchDeleted = $del.ok
                        if (-not $branchDeleted) {
                            $remaining += $r
                            $kept += [pscustomobject]@{ branch = $branch; worktree = $wt
                                reason = "worktree gutted; deleting merged branch '$branch' failed: $(Format-GitError $del.text)" }
                            continue
                        }
                    }
                    # Remove the husk. -Recurse only ever walks EMPTY directories here
                    # (verified above), so this is a plain rmdir, not a force-remove.
                    $dirErr = ''
                    try { Remove-Item -LiteralPath $wt -Recurse -Force -ErrorAction Stop } catch { $dirErr = "$_" }
                    if ($dirErr -or (Test-Path -LiteralPath $wt)) {
                        # Still locked - most likely a shell still cd'd into it. Keep the
                        # record so a later sweep finishes it; the branch is already gone,
                        # so a re-run only retries this one rmdir. Converges.
                        $remaining += $r
                        $kept += [pscustomobject]@{ branch = $branch; worktree = $wt
                            reason = "worktree gutted; branch handled, but the leftover empty directory could not be removed (a shell may still be cd'd into it): $(if ($dirErr) { $dirErr } else { 'directory still present' })" }
                        continue
                    }
                    $closed += [pscustomobject]@{ branch = $branch; worktree = $wt; branchDeleted = $branchDeleted
                        statusUpdated = $false; summary = $sum; followups = $fu
                        note = "recovered a worktree gutted by an earlier failed remove; the state.md flip could not be re-checked (no worktree left to check)" }
                    continue
                }

                # Never touch in-progress, and skip anything out of scope.
                if ($r.state -ne 'cleanupable' -or -not $inScope) { $remaining += $r; continue }

                # Dirty worktree -> classify the dirt before deciding. We never close out
                # over genuine user WIP, but the recipe's OWN close-out flip (state.md
                # Status -> done, left uncommitted by a prior interrupted sweep) is NOT
                # user work - it is exactly what we are here to commit. So keep the
                # worktree only when something OTHER than the recipe's state.md is dirty;
                # if the sole dirt is that one file, fall through and let the (idempotent)
                # recipe commit it. This is what stops the "uncommitted state.md flip ->
                # kept forever" loop.
                $recipeRel = Get-RecipeStateRel $sp $RepoRoot
                $dirtyPaths = Get-DirtyPaths $wt
                if ($dirtyPaths.Count -gt 0) {
                    $otherDirt = @($dirtyPaths | Where-Object { -not $recipeRel -or ($_ -ine $recipeRel) })
                    if ($otherDirt.Count -gt 0) {
                        $remaining += $r
                        $kept += [pscustomobject]@{ branch = $branch; worktree = $wt; reason = 'uncommitted changes in worktree' }
                        continue
                    }
                    # Only the recipe's own state.md is dirty - but is the change just the
                    # close-out flip, or a deliberate manual edit (Status -> in-progress,
                    # body notes)? Verify the CONTENT before committing + closing over it,
                    # so we never clobber a status the user purposely set or lose real
                    # edits. Anything that is not a pure close-out flip is kept as WIP.
                    if (-not (Test-CloseoutOnlyChange $wt $recipeRel $ts)) {
                        $remaining += $r
                        $kept += [pscustomobject]@{ branch = $branch; worktree = $wt; reason = 'uncommitted manual edit to state.md (not a close-out flip)' }
                        continue
                    }
                }

                # Clean (or recipe-state.md-only dirt) + cleanupable: flip Status IN THE
                # WORKTREE + commit, then FF integrate (carries the flip and any commits
                # queued from an earlier QUEUED_DIRTY). The primary tree is only ever
                # updated by that merge. First clear any STALE index.lock so the recipe's
                # commit and the integrate can actually write the worktree index.
                Clear-StaleGitLock $wt | Out-Null
                $flip = Set-StateStatusInWorktree $sp $ts $wt $RepoRoot
                $statusUpdated = $flip.committed

                Invoke-Integrate $wt $branch $TargetBranch $RepoRoot
                $merged = Get-MergedSet $RepoRoot $TargetBranch

                $isMerged = $merged.ContainsKey($branch)
                $dirtyAfter = (@(Invoke-GitOut $wt status --porcelain).Count -gt 0)

                if ($isMerged -and -not $dirtyAfter) {
                    # Last-ditch guard: NEVER remove the primary checkout itself. If a
                    # poisoned $RepoRoot/record ever makes $wt the primary root again
                    # (the incident this hardening exists for), removing it guts the
                    # user's checkout - refuse and keep, whatever upstream says.
                    if ((Get-CanonicalPath $wt) -eq (Get-CanonicalPath $RepoRoot)) {
                        $remaining += $r
                        $kept += [pscustomobject]@{ branch = $branch; worktree = $wt; reason = 'refusing to remove primary checkout' }
                        continue
                    }
                    $rm = Invoke-GitCapture $RepoRoot worktree remove $wt
                    if ($rm.ok) {
                        # Tidy up the now-merged feature branch. Plain -d ONLY (never
                        # -D): git refuses unless the branch is fully merged into HEAD,
                        # so this cannot destroy work even if the merged-set check above
                        # was somehow stale. Failure is non-fatal - the close-out stands.
                        # '-d' must be QUOTED: bare -d prefix-binds to Invoke-Git's common
                        # -Debug parameter (advanced function) and never reaches git.
                        $branchDeleted = Invoke-Git $RepoRoot branch '-d' $branch
                        $closed += [pscustomobject]@{ branch = $branch; worktree = $wt; branchDeleted = $branchDeleted; statusUpdated = $statusUpdated; summary = $sum; followups = $fu }
                        # pruned by omission from $remaining
                    } else {
                        # Surface git's own words - on Windows they name the locked path
                        # and the offending process, which is the whole diagnosis. Also
                        # say so when the failed remove already gutted the worktree, so
                        # the leftover state is expected rather than alarming.
                        $remaining += $r
                        $gutted = (Test-Path -LiteralPath $wt) -and
                                  -not (Invoke-Git $wt rev-parse --is-inside-work-tree)
                        $hint = if ($gutted) {
                            " -- the worktree is now GUTTED (its contents were deleted before the failure); the branch and the empty directory are still there. Make sure no shell is cd'd into it, then re-run cleanup and it will finish both."
                        } else { '' }
                        $kept += [pscustomobject]@{ branch = $branch; worktree = $wt
                            reason = "worktree remove failed: $(Format-GitError $rm.text)$hint" }
                    }
                }
                else {
                    $remaining += $r
                    # A still-dirty worktree here is NOT automatically user WIP: the
                    # close-out commit itself may have failed, and reporting that as
                    # 'uncommitted changes' sent the user hunting for WIP that was
                    # never there. Prefer the flip's own error - it carries git's words.
                    $reason = if ($dirtyAfter) {
                        if ($flip -and $flip.error) { $flip.error } else { 'uncommitted changes in worktree' }
                    } else { "not merged into $TargetBranch (queued - target dirty or conflict)" }
                    $kept += [pscustomobject]@{ branch = $branch; worktree = $wt; reason = $reason }
                }
            } catch {
                $remaining += $r
                $kept += [pscustomobject]@{ branch = $branch; worktree = $wt; reason = "error: $_" }
            }
        }

        Write-Ledger $ledger $remaining
    } finally { Unlock-Ledger $lock }

    Invoke-Git $RepoRoot worktree prune | Out-Null

    [pscustomobject]@{ closed = $closed; kept = $kept; pruned = $pruned } | ConvertTo-Json -Compress -Depth 8
    exit 0
}
catch {
    [pscustomobject]@{ error = "$_" } | ConvertTo-Json -Compress
    exit 1
}
