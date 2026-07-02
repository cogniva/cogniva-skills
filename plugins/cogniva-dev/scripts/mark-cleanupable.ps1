# Flip a worktree's ledger record to state 'cleanupable' and attach its
# self-contained close-out recipe. Call this the moment a worktree's work is
# committed + fast-forward integrated + green and the ONLY thing left is the
# user's validation. After this, ANY session can finish the worktree via
# cleanup-work (this session) or cleanup-allwork (safety net) using the recipe
# alone - no original-session context required.
#
# If no ledger record exists yet for this worktree (e.g. it was created outside
# new-feature-worktree.ps1), one is created.
#
# Output (last line): JSON { status: OK|ERROR, worktree, state, detail }
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Worktree,   # absolute worktree path (record key)
    [string]$Branch,
    [string]$Base,
    [string]$RepoRoot,
    [string]$StatePath,                          # optional: docs/.../state.md to flip at close-out
    [string]$TargetStatus = 'done',             # Status value to write into StatePath at close-out
    [string]$Summary,                            # one line: what this work was
    [string]$Followups                           # freeform: backlog / manual follow-ups to surface at close-out
)
$ErrorActionPreference = 'Stop'
try {
    if (-not $RepoRoot) { $RepoRoot = (git rev-parse --show-toplevel).Trim() }
    . (Join-Path $PSScriptRoot 'ledger-lib.ps1')
    $commonDir = Get-CommonDir $RepoRoot
    $ledger = Get-LedgerPath $commonDir

    # Guard: the close-out recipe flips a 'Status:' line in a plan state.md and
    # appends a close-out line to it. Pointing it at any OTHER file (e.g. a .cs
    # source) corrupts that file - the close-out line lands after the last brace and
    # breaks compilation, and the sweep would then commit/FF it to the branch. So
    # only ever record a path whose leaf is literally 'state.md'; drop anything else.
    $statePathDropped = $false
    if ($StatePath -and ((Split-Path $StatePath -Leaf) -ine 'state.md')) {
        $StatePath = $null
        $statePathDropped = $true
    }

    $recipe = [pscustomobject]@{
        statePath    = $StatePath
        targetStatus = $TargetStatus
        summary      = $Summary
        followups    = $Followups
    }

    $lock = Lock-Ledger $commonDir
    try {
        $records = @(Read-Ledger $ledger)
        $found = $false
        foreach ($r in $records) {
            if (Test-SamePath $r.worktree $Worktree) {
                $r.state  = 'cleanupable'
                $r.recipe = $recipe
                if ($Branch -and -not $r.branch) { $r.branch = $Branch }
                $found = $true
            }
        }
        if (-not $found) {
            $rec = [pscustomobject]@{
                branch    = $Branch
                worktree  = $Worktree
                base      = $Base
                owner     = $Branch
                createdAt = (Get-Date).ToString('o')
                state     = 'cleanupable'
                recipe    = $recipe
            }
            $records = @($records) + $rec
        }
        Write-Ledger $ledger $records
    } finally { Unlock-Ledger $lock }

    $detail = if ($statePathDropped) { 'recipe attached (ignored non-state.md StatePath - no Status flip at close-out)' } else { 'recipe attached' }
    [pscustomobject]@{ status = 'OK'; worktree = $Worktree; state = 'cleanupable'; detail = $detail } |
        ConvertTo-Json -Compress
    exit 0
}
catch {
    [pscustomobject]@{ status = 'ERROR'; detail = "$_" } | ConvertTo-Json -Compress
    exit 1
}
