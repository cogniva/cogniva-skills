# Integrate feature/<slug> into the user's current branch via a fast-forward LOCAL push.
# Safety model:
#   1. Pre-merge the target INTO the feature (inside the feature worktree) so the push is a fast-forward.
#      Any conflict is resolved in the sandbox, never in the user's working tree.
#   2. Serialize all integrations with a lockfile so concurrent runs cannot corrupt each other.
#   3. Push FF-only into the target branch. With receive.denyCurrentBranch=updateInstead this updates the
#      target's working tree IFF it is clean; if the user has uncommitted changes git refuses -> QUEUED_DIRTY
#      (their WIP is never clobbered). They commit/stash and re-run to land it.
# Run build/tests in the worktree BEFORE calling this; only integrate when green.
# Output (last line): JSON { status: INTEGRATED|QUEUED_DIRTY|CONFLICT|ERROR, detail }
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorktreePath,
    [Parameter(Mandatory)][string]$FeatureBranch,
    [Parameter(Mandatory)][string]$TargetBranch,
    [string]$RepoRoot
)
$ErrorActionPreference = 'Stop'
$lock = $null
try {
    if (-not $RepoRoot) { $RepoRoot = (git -C $WorktreePath rev-parse --show-toplevel).Trim() }
    $gitDir = (git -C $RepoRoot rev-parse --git-common-dir).Trim()
    if (-not [System.IO.Path]::IsPathRooted($gitDir)) { $gitDir = Join-Path $RepoRoot $gitDir }

    # 1. Pre-merge target into the feature (sandbox). FF the feature up to target first.
    git -C $WorktreePath merge --no-edit $TargetBranch *>$null
    if ($LASTEXITCODE -ne 0) {
        git -C $WorktreePath merge --abort *>$null
        [pscustomobject]@{ status = 'CONFLICT'; detail = "merging $TargetBranch into $FeatureBranch conflicts; resolve in $WorktreePath then re-run" } | ConvertTo-Json -Compress
        exit 2
    }

    # 2. Serialize.
    $lock = Join-Path $gitDir 'cogniva-integration.lock'
    $deadline = (Get-Date).AddMinutes(10)
    while (Test-Path $lock) {
        if ((Get-Date) -gt $deadline) { throw "integration lock held > 10 min: $lock" }
        Start-Sleep -Milliseconds 500
    }
    Set-Content -Path $lock -Value "$FeatureBranch $(Get-Date -Format o)" -NoNewline

    # 3. Fast-forward local push into the target branch.
    $push = (git -C $WorktreePath push . "$($FeatureBranch):$($TargetBranch)" 2>&1) -join "`n"
    if ($LASTEXITCODE -eq 0) {
        $result = [pscustomobject]@{ status = 'INTEGRATED'; detail = "$FeatureBranch -> $TargetBranch (fast-forward)" }
    }
    elseif ($push -match 'denyCurrentBranch|working tree|not a fast.?forward|would be overwritten|fetch first|up.to.date.*rejected|changes.*staged|untracked') {
        $result = [pscustomobject]@{ status = 'QUEUED_DIRTY'; detail = "target '$TargetBranch' not clean/FF; commit or stash there, then re-run integrate. git: $push" }
    }
    else {
        $result = [pscustomobject]@{ status = 'ERROR'; detail = $push }
    }
    $result | ConvertTo-Json -Compress
    switch ($result.status) { 'INTEGRATED' { exit 0 } 'QUEUED_DIRTY' { exit 3 } default { exit 1 } }
}
catch {
    [pscustomobject]@{ status = 'ERROR'; detail = "$_" } | ConvertTo-Json -Compress
    exit 1
}
finally {
    if ($lock -and (Test-Path $lock)) { Remove-Item $lock -Force -ErrorAction SilentlyContinue }
}
