# Create (or reuse) an isolated git worktree on feature/<slug> for any work
# (ad-hoc prompt, quick change, or an execute-feature run). Isolation model: a
# worktree-on-a-branch never touches the primary checkout's HEAD, so concurrent
# runs cannot interfere. We never switch branches in the primary checkout.
#
# Records the worktree in the shared JSON ledger (state 'in-progress') so it is
# tracked and self-cleaning: cleanup-work / cleanup-allwork can later close it out.
# Best-effort ledger writes never fail worktree creation.
#
# Output (last line): JSON { worktree, branch, base, reused }
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Slug,
    [string]$BaseBranch,   # default: current branch of the primary checkout (the user's integration target)
    [string]$RepoRoot,     # default: git toplevel of the current directory
    [string]$Owner         # informational label (slug or session token)
)
$ErrorActionPreference = 'Stop'
try {
    if (-not $RepoRoot)   { $RepoRoot   = (git rev-parse --show-toplevel).Trim() }
    if (-not $BaseBranch) { $BaseBranch = (git -C $RepoRoot branch --show-current).Trim() }
    if (-not $BaseBranch) { throw "primary checkout is in detached HEAD; check out a branch first" }
    if (-not $Owner)      { $Owner = $Slug }

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

    # Record in the shared JSON ledger (best-effort).
    try {
        . (Join-Path $PSScriptRoot 'ledger-lib.ps1')
        $commonDir = Get-CommonDir $RepoRoot
        $ledger = Get-LedgerPath $commonDir
        $lock = Lock-Ledger $commonDir
        try {
            $records = @(Read-Ledger $ledger)
            $existing = $records | Where-Object { Test-SamePath $_.worktree $wt }
            if (-not $existing) {
                $rec = [pscustomobject]@{
                    branch    = $branch
                    worktree  = $wt
                    base      = $BaseBranch
                    owner     = $Owner
                    createdAt = (Get-Date).ToString('o')
                    state     = 'in-progress'
                    recipe    = $null
                }
                $records = @($records) + $rec
                Write-Ledger $ledger $records
            }
        } finally { Unlock-Ledger $lock }
    } catch { }

    [pscustomobject]@{ worktree = $wt; branch = $branch; base = $BaseBranch; reused = $reused } |
        ConvertTo-Json -Compress
    exit 0
}
catch {
    [pscustomobject]@{ error = "$_" } | ConvertTo-Json -Compress
    exit 1
}
