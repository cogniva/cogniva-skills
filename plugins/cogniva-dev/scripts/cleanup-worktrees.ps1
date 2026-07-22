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
# 2>$null), which a surrounding try/catch then mistakes for a git FAILURE. That is
# exactly how the close-out commit was being silently dropped - the flip stayed
# uncommitted and the worktree was kept forever. So localize the preference to
# 'Continue' for the native call and judge success by the exit code alone.
# Returns $true iff git exited 0.
function Invoke-Git {
    param([string]$Worktree, [Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git -C $Worktree @GitArgs 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } finally { $ErrorActionPreference = $old }
}

# Flip the Status line IN THE WORKTREE copy of state.md and commit it on the
# feature branch. $StatePath is the recipe's reference path (rooted in the PRIMARY
# checkout); we map it into $Worktree and only ever edit/commit THERE. Returns
# $true only if a commit was actually made. Never writes the primary tree.
function Set-StateStatusInWorktree([string]$StatePath, [string]$TargetStatus, [string]$Worktree, [string]$RepoRoot) {
    if (-not $StatePath -or -not $TargetStatus -or -not $Worktree) { return $false }
    # Defense-in-depth against a legacy/bad ledger record: the flip+append is only
    # ever valid on a plan state.md. Refuse any other target (e.g. a .cs source) so
    # a stale recipe can never corrupt and FF a broken source file onto the branch.
    if ((Split-Path $StatePath -Leaf) -ine 'state.md') { return $false }
    try {
        $root = ($RepoRoot -replace '/','\').TrimEnd('\')
        $sp   = ($StatePath -replace '/','\')
        if (-not $sp.ToLowerInvariant().StartsWith($root.ToLowerInvariant() + '\')) { return $false }
        $rel = $sp.Substring($root.Length).TrimStart('\')
        $wtState = Join-Path $Worktree $rel
        if (-not (Test-Path -LiteralPath $wtState)) { return $false }
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
        # git's view of the file, not on whether THIS call rewrote it.
        if (-not [bool] (git -C $Worktree status --porcelain -- "$wtState" 2>$null)) { return $false }
        if (-not (Invoke-Git $Worktree add -- "$wtState")) { return $false }
        if (-not (Invoke-Git $Worktree commit -m "chore: close out feature (Status: $TargetStatus)" -- "$wtState")) { return $false }
        return $true
    } catch { return $false }
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
    foreach ($line in @(git -C $Worktree status --porcelain 2>$null)) {
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
        $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $headText = (& git -C $Worktree show "HEAD:$RecipeRel" 2>$null | Out-String) }
        finally { $ErrorActionPreference = $old }
        if ($LASTEXITCODE -ne 0) { return $false }
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
    foreach ($b in (git -C $RepoRoot branch --merged $TargetBranch --format='%(refname:short)')) {
        $n = $b.Trim(); if ($n) { $m[$n] = $true }
    }
    return $m
}

try {
    if (-not $RepoRoot)     { $RepoRoot     = (git rev-parse --show-toplevel).Trim() }
    if (-not $TargetBranch) { $TargetBranch = (git -C $RepoRoot branch --show-current).Trim() }
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

            # Stale: worktree gone -> prune regardless of state.
            if (-not $wt -or -not (Test-Path $wt)) { $pruned += $wt; continue }

            $inScope = ($Scope -eq 'all') -or $wanted.ContainsKey($key)
            # Never touch in-progress, and skip anything out of scope.
            if ($r.state -ne 'cleanupable' -or -not $inScope) { $remaining += $r; continue }

            $sp = $null; $ts = $null; $sum = $null; $fu = $null
            if ($r.recipe) { $sp = $r.recipe.statePath; $ts = $r.recipe.targetStatus; $sum = $r.recipe.summary; $fu = $r.recipe.followups }

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
            $statusUpdated = Set-StateStatusInWorktree $sp $ts $wt $RepoRoot

            Invoke-Integrate $wt $branch $TargetBranch $RepoRoot
            $merged = Get-MergedSet $RepoRoot $TargetBranch

            $isMerged = $merged.ContainsKey($branch)
            $dirtyAfter = [bool] (git -C $wt status --porcelain)

            if ($isMerged -and -not $dirtyAfter) {
                $removeOk = $false
                try {
                    git -C $RepoRoot worktree remove $wt 2>$null
                    if ($LASTEXITCODE -eq 0) { $removeOk = $true }
                } catch { }
                if ($removeOk) {
                    # Tidy up the now-merged feature branch. Plain -d ONLY (never
                    # -D): git refuses unless the branch is fully merged into HEAD,
                    # so this cannot destroy work even if the merged-set check above
                    # was somehow stale. Failure is non-fatal - the close-out stands.
                    $branchDeleted = $false
                    try {
                        git -C $RepoRoot branch -d $branch 2>$null | Out-Null
                        if ($LASTEXITCODE -eq 0) { $branchDeleted = $true }
                    } catch { }
                    $closed += [pscustomobject]@{ branch = $branch; worktree = $wt; branchDeleted = $branchDeleted; statusUpdated = $statusUpdated; summary = $sum; followups = $fu }
                    # pruned by omission from $remaining
                } else {
                    $remaining += $r
                    $kept += [pscustomobject]@{ branch = $branch; worktree = $wt; reason = 'worktree remove failed' }
                }
            }
            else {
                $remaining += $r
                $reason = if ($dirtyAfter) { 'uncommitted changes in worktree' } else { "not merged into $TargetBranch (queued - target dirty or conflict)" }
                $kept += [pscustomobject]@{ branch = $branch; worktree = $wt; reason = $reason }
            }
        }

        Write-Ledger $ledger $remaining
    } finally { Unlock-Ledger $lock }

    git -C $RepoRoot worktree prune 2>$null | Out-Null

    [pscustomobject]@{ closed = $closed; kept = $kept; pruned = $pruned } | ConvertTo-Json -Compress -Depth 8
    exit 0
}
catch {
    [pscustomobject]@{ error = "$_" } | ConvertTo-Json -Compress
    exit 1
}
