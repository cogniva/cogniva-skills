# Create (or reuse) an isolated git worktree on feature/<slug> for an execute-feature/quick-fix run.
# Isolation model: a worktree-on-a-branch never touches the primary checkout's HEAD, so concurrent
# runs cannot interfere. We never switch branches in the primary checkout.
# Output (last line): JSON { worktree, branch, base, reused, repoRoot }
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Slug,
    [string]$BaseBranch,   # default: current branch of the primary checkout (the user's integration target)
    [string]$RepoRoot      # default: git toplevel of the current directory
)
$ErrorActionPreference = 'Stop'
try {
    if (-not $RepoRoot)   { $RepoRoot   = (git rev-parse --show-toplevel).Trim() }
    if (-not $BaseBranch) { $BaseBranch = (git -C $RepoRoot branch --show-current).Trim() }
    if (-not $BaseBranch) { throw "primary checkout is in detached HEAD; check out a branch first" }

    $branch = "feature/$Slug"
    $parent = Split-Path -Parent $RepoRoot
    $leaf   = Split-Path -Leaf   $RepoRoot
    $wt     = Join-Path $parent "$leaf-$Slug"

    $reused = $false
    if (Test-Path $wt) {
        $reused = $true                      # resume: reuse the existing worktree as-is
    }
    else {
        $branchExists = (git -C $RepoRoot branch --list $branch)
        if ($branchExists) {
            git -C $RepoRoot worktree add $wt $branch | Out-Null        # resume a branch with no worktree
        } else {
            git -C $RepoRoot worktree add $wt -b $branch $BaseBranch | Out-Null
        }
    }

    # Record this worktree in a checkout-local ledger (in the shared git common dir, so every
    # worktree created from this checkout is tracked in one place) so complete-feature can later
    # sweep worktrees that have been integrated. Best-effort: a ledger failure must never fail
    # worktree creation.
    try {
        $commonDir = (git -C $RepoRoot rev-parse --git-common-dir).Trim()
        if (-not [System.IO.Path]::IsPathRooted($commonDir)) { $commonDir = Join-Path $RepoRoot $commonDir }
        $ledger = Join-Path $commonDir 'cogniva-worktrees.tsv'
        $already = (Test-Path $ledger) -and (Select-String -LiteralPath $ledger -SimpleMatch "`t$wt`t" -Quiet)
        if (-not $already) { Add-Content -LiteralPath $ledger -Value "$branch`t$wt`t$BaseBranch" }
    } catch { }

    [pscustomobject]@{ worktree = $wt; branch = $branch; base = $BaseBranch; reused = $reused; repoRoot = $RepoRoot } |
        ConvertTo-Json -Compress
    exit 0
}
catch {
    [pscustomobject]@{ error = "$_" } | ConvertTo-Json -Compress
    exit 1
}
