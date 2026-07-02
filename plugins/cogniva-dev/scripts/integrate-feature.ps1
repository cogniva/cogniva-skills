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
    # NOTE: do NOT decide success by parsing git's stderr. With receive.denyCurrentBranch=updateInstead,
    # git writes progress ("To .", the update line) to stderr, and PowerShell's native `2>&1` capture
    # keeps only the first line ("To .") while $LASTEXITCODE can misreport — producing a false ERROR on
    # a push that actually succeeded. Instead, compare refs afterward: the target ref moving to the
    # feature tip is the authoritative signal of integration.
    $featureSha = (git -C $WorktreePath rev-parse "$FeatureBranch").Trim()
    # --no-verify: skip the Git LFS pre-push hook. This is a LOCAL push (remote ".", same
    # object store), so there are no LFS objects to transfer, and 'git lfs pre-push .' errors
    # on "." as a remote. The hook still runs on real remote pushes (e.g. user -> origin).
    $push = (git -C $WorktreePath push --no-verify --porcelain . "$($FeatureBranch):$($TargetBranch)" 2>&1) -join "`n"
    $pushExit = $LASTEXITCODE
    $targetSha = (git -C $WorktreePath rev-parse "$TargetBranch").Trim()

    if ($targetSha -eq $featureSha) {
        # Source of truth: target now points at the feature tip (covers a clean push AND an idempotent re-run).
        $result = [pscustomobject]@{ status = 'INTEGRATED'; detail = "$FeatureBranch -> $TargetBranch (fast-forward)" }
    }
    elseif ($push -match 'denyCurrentBranch|working tree|working directory|not a fast.?forward|would be overwritten|fetch first|up.to.date.*rejected|staged changes|unstaged|untracked|currently checked out') {
        $result = [pscustomobject]@{ status = 'QUEUED_DIRTY'; detail = "target '$TargetBranch' not clean/FF; commit or stash there, then re-run integrate. git: $push" }
    }
    else {
        $result = [pscustomobject]@{ status = 'ERROR'; detail = "push exit ${pushExit}: $push" }
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
