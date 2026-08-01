# Create (or reuse) an isolated git worktree on feature/<slug> for any work
# (ad-hoc prompt, quick change, or an execute-feature run). Isolation model: a
# worktree-on-a-branch never touches the primary checkout's HEAD, so concurrent
# runs cannot interfere. We never switch branches in the primary checkout.
#
# Records the worktree in the shared JSON ledger (state 'in-progress') so it is
# tracked and self-cleaning: cleanup-work / cleanup-allwork can later close it out.
# Best-effort ledger writes never fail worktree creation.
#
# A REUSED worktree (or a branch resumed without one) sits at whatever commit it
# was created from, which may be well behind the integration target by the time
# work resumes. That is not cosmetic: the plan file in a stale tree can be an
# older revision than the one the caller parsed, so tasks implement a decision
# the target has already replaced. This script therefore MEASURES the gap and
# either closes it safely or reports it loudly - it never leaves the caller to
# assume a reused worktree is current.
#
# Output (last line): JSON { worktree, branch, base, reused, ahead, behind,
#                            resynced, stale, staleReason }
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

    # How does this branch stand against the integration target? A freshly
    # created worktree is current by construction; a reused or resumed one is
    # not, and the caller cannot tell the difference from the outside.
    $ahead = 0; $behind = 0; $resynced = $false; $stale = $false; $staleReason = $null
    try {
        $behind = [int]((git -C $RepoRoot rev-list --count "$branch..$BaseBranch") | Out-String).Trim()
        $ahead  = [int]((git -C $RepoRoot rev-list --count "$BaseBranch..$branch") | Out-String).Trim()
    } catch { $staleReason = "could not compare $branch against $BaseBranch : $_" }

    if ($behind -gt 0) {
        $dirty = @(git -C $wt status --porcelain | Where-Object { $_ })
        if ($ahead -eq 0 -and $dirty.Count -eq 0) {
            # Nothing of its own and nothing uncommitted, so catching up is a
            # fast-forward: it cannot conflict and cannot lose work.
            git -C $wt merge --ff-only $BaseBranch | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $resynced = $true
                $staleReason = "was $behind commit(s) behind $BaseBranch; fast-forwarded to its tip"
                $behind = 0
            } else {
                $stale = $true
                $staleReason = "is $behind commit(s) behind $BaseBranch and the fast-forward failed"
            }
        } else {
            # Divergent, or dirty. Merging here would be a decision this script
            # has no standing to make, so it reports and lets the caller choose.
            $stale = $true
            $why = if ($ahead -gt 0) { "has $ahead commit(s) of its own" } else { "has uncommitted changes" }
            $staleReason = "is $behind commit(s) behind $BaseBranch and $why - merge $BaseBranch into $branch before running any task, or the work will be based on a stale tree"
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
                    worktree  = (Get-CanonicalPath $wt)      # store canonical so mark-cleanupable finds THIS record, no matter the slash direction
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

    [pscustomobject]@{ worktree = $wt; branch = $branch; base = $BaseBranch; reused = $reused
                       ahead = $ahead; behind = $behind; resynced = $resynced
                       stale = $stale; staleReason = $staleReason } |
        ConvertTo-Json -Compress
    exit 0
}
catch {
    [pscustomobject]@{ error = "$_" } | ConvertTo-Json -Compress
    exit 1
}
