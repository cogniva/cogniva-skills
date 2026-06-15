# Sweep cogniva-created worktrees that are safe to discard: fully merged into the target branch
# AND clean (no uncommitted changes). Reads the checkout-local ledger written by
# new-feature-worktree.ps1, removes qualifying worktrees, and prunes the ledger.
#
# Safety: only removes worktrees whose branch is fully merged into <TargetBranch> and whose tree
# is clean — so integrated work is never lost and in-progress worktrees (any session) are left
# alone. Never deletes branches (branch deletion in a shared primary checkout is intentionally
# off-limits) and never uses --force. Stale ledger entries (worktree already gone) are pruned.
#
# Output (last line): JSON { removed:[...], kept:[{branch,worktree,reason}], pruned:[...] }
[CmdletBinding()]
param(
    [string]$RepoRoot,      # default: git toplevel of the current directory
    [string]$TargetBranch   # default: current branch of the primary checkout (the integration target)
)
$ErrorActionPreference = 'Stop'
try {
    if (-not $RepoRoot)     { $RepoRoot     = (git rev-parse --show-toplevel).Trim() }
    if (-not $TargetBranch) { $TargetBranch = (git -C $RepoRoot branch --show-current).Trim() }

    $commonDir = (git -C $RepoRoot rev-parse --git-common-dir).Trim()
    if (-not [System.IO.Path]::IsPathRooted($commonDir)) { $commonDir = Join-Path $RepoRoot $commonDir }
    $ledger = Join-Path $commonDir 'cogniva-worktrees.tsv'

    $removed = @(); $kept = @(); $pruned = @(); $remaining = @()

    if (-not (Test-Path $ledger)) {
        [pscustomobject]@{ removed = $removed; kept = $kept; pruned = $pruned } | ConvertTo-Json -Compress -Depth 5
        exit 0
    }

    # Branches fully merged into the target (clean short names).
    $merged = @{}
    foreach ($b in (git -C $RepoRoot branch --merged $TargetBranch --format='%(refname:short)')) {
        $n = $b.Trim(); if ($n) { $merged[$n] = $true }
    }

    foreach ($raw in (Get-Content -LiteralPath $ledger)) {
        $line = $raw.Trim()
        if (-not $line) { continue }
        $parts = $line -split "`t"
        $branch = $parts[0]; $wt = $parts[1]
        if (-not $wt) { continue }

        if (-not (Test-Path $wt)) { $pruned += $wt; continue }   # already gone — drop from ledger

        $isMerged = $merged.ContainsKey($branch)
        $dirty = [bool] (git -C $wt status --porcelain)
        if ($isMerged -and -not $dirty) {
            try {
                git -C $RepoRoot worktree remove $wt 2>$null
                if ($LASTEXITCODE -eq 0) { $removed += $wt }
                else { $remaining += $line; $kept += [pscustomobject]@{ branch = $branch; worktree = $wt; reason = 'worktree remove failed' } }
            } catch {
                $remaining += $line; $kept += [pscustomobject]@{ branch = $branch; worktree = $wt; reason = "remove error: $_" }
            }
        }
        else {
            $remaining += $line
            $reason = if ($dirty) { 'uncommitted changes' } else { "not merged into $TargetBranch" }
            $kept += [pscustomobject]@{ branch = $branch; worktree = $wt; reason = $reason }
        }
    }

    # Rewrite the ledger with only the entries we kept (removed + pruned are dropped).
    if ($remaining.Count -gt 0) { Set-Content -LiteralPath $ledger -Value $remaining }
    else { Remove-Item -LiteralPath $ledger -ErrorAction SilentlyContinue }

    git -C $RepoRoot worktree prune 2>$null | Out-Null

    [pscustomobject]@{ removed = $removed; kept = $kept; pruned = $pruned } | ConvertTo-Json -Compress -Depth 5
    exit 0
}
catch {
    [pscustomobject]@{ error = "$_" } | ConvertTo-Json -Compress
    exit 1
}
