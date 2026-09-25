$ErrorActionPreference = 'Stop'

$scriptUnderTest = Join-Path $PSScriptRoot '../../scripts/integrate-feature.ps1'

function Invoke-Git {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $output = (& git -C $Directory @Arguments 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed in '$Directory': $output"
    }

    return $output
}

function New-TestRepository {
    $root = Join-Path ([IO.Path]::GetTempPath()) "cogniva-integrate-feature-$([guid]::NewGuid())"
    $feature = Join-Path $root 'feature-worktree'
    New-Item -ItemType Directory -Path $root | Out-Null
    Invoke-Git $root @('init', '--initial-branch=main') | Out-Null
    Invoke-Git $root @('config', 'user.name', 'Cogniva Test') | Out-Null
    Invoke-Git $root @('config', 'user.email', 'cogniva-test@example.invalid') | Out-Null
    Invoke-Git $root @('config', 'receive.denyCurrentBranch', 'updateInstead') | Out-Null
    Set-Content -LiteralPath (Join-Path $root 'base.txt') -Value 'base'
    Invoke-Git $root @('add', 'base.txt') | Out-Null
    Invoke-Git $root @('commit', '-m', 'base') | Out-Null
    Invoke-Git $root @('branch', 'feature/test') | Out-Null
    Invoke-Git $root @('worktree', 'add', '--quiet', $feature, 'feature/test') | Out-Null

    [pscustomobject]@{ Root = $root; Feature = $feature }
}

function Invoke-Integration {
    param([Parameter(Mandatory)]$Repository)

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptUnderTest `
        -WorktreePath $Repository.Feature `
        -FeatureBranch 'feature/test' `
        -TargetBranch 'main' `
        -RepoRoot $Repository.Root 2>&1

    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = ($output -join "`n")
        Result = ($output | Select-Object -Last 1 | ConvertFrom-Json)
    }
}

function Assert-Equal {
    param([object]$Expected, [object]$Actual, [string]$Message)
    if ($Expected -ne $Actual) { throw "$Message. Expected '$Expected', actual '$Actual'." }
}

$repositories = @()
try {
    # A feature directly ahead of main integrates without creating a merge commit.
    $fastForward = New-TestRepository
    $repositories += $fastForward
    Set-Content -LiteralPath (Join-Path $fastForward.Feature 'feature.txt') -Value 'feature'
    Invoke-Git $fastForward.Feature @('add', 'feature.txt') | Out-Null
    Invoke-Git $fastForward.Feature @('commit', '-m', 'feature') | Out-Null
    $featureTip = Invoke-Git $fastForward.Root @('rev-parse', 'feature/test')
    $integration = Invoke-Integration $fastForward
    Assert-Equal 0 $integration.ExitCode 'Fast-forward integration should succeed'
    Assert-Equal 'INTEGRATED' $integration.Result.status 'Fast-forward integration status is incorrect'
    Assert-Equal $featureTip (Invoke-Git $fastForward.Root @('rev-parse', 'main')) 'main should point at the feature tip'
    if ((Invoke-Git $fastForward.Root @('log', '--format=%P', '-1', 'main')) -match ' ') { throw 'Fast-forward integration must not create a merge commit.' }
    Invoke-Git $fastForward.Root @('show-ref', '--verify', '--quiet', 'refs/heads/feature/test') | Out-Null

    # Diverged histories with independent changes merge in the feature worktree,
    # then fast-forward main to that merged feature tip.
    $merged = New-TestRepository
    $repositories += $merged
    Set-Content -LiteralPath (Join-Path $merged.Root 'main.txt') -Value 'main'
    Invoke-Git $merged.Root @('add', 'main.txt') | Out-Null
    Invoke-Git $merged.Root @('commit', '-m', 'main divergence') | Out-Null
    $mainCommit = Invoke-Git $merged.Root @('rev-parse', 'main')
    Set-Content -LiteralPath (Join-Path $merged.Feature 'feature.txt') -Value 'feature'
    Invoke-Git $merged.Feature @('add', 'feature.txt') | Out-Null
    Invoke-Git $merged.Feature @('commit', '-m', 'feature divergence') | Out-Null
    $featureCommit = Invoke-Git $merged.Root @('rev-parse', 'feature/test')
    $integration = Invoke-Integration $merged
    Assert-Equal 0 $integration.ExitCode 'Cleanly diverged integration should succeed'
    Assert-Equal 'INTEGRATED' $integration.Result.status 'Cleanly diverged integration status is incorrect'
    $mergedTip = Invoke-Git $merged.Root @('rev-parse', 'feature/test')
    Assert-Equal $mergedTip (Invoke-Git $merged.Root @('rev-parse', 'main')) 'main should fast-forward to the merged feature tip'
    if ((Invoke-Git $merged.Root @('log', '--format=%P', '-1', 'feature/test')) -notmatch ' ') { throw 'Cleanly diverged integration must create its merge commit in the feature worktree.' }
    Invoke-Git $merged.Root @('merge-base', '--is-ancestor', $mainCommit, $mergedTip) | Out-Null
    Invoke-Git $merged.Root @('merge-base', '--is-ancestor', $featureCommit, $mergedTip) | Out-Null
    Assert-Equal '' (Invoke-Git $merged.Root @('remote')) 'Integration must not create or use a remote'
    Invoke-Git $merged.Root @('show-ref', '--verify', '--quiet', 'refs/heads/feature/test') | Out-Null

    # A real merge conflict aborts in the feature worktree before any local push.
    $conflicted = New-TestRepository
    $repositories += $conflicted
    Set-Content -LiteralPath (Join-Path $conflicted.Root 'shared.txt') -Value 'main'
    Invoke-Git $conflicted.Root @('add', 'shared.txt') | Out-Null
    Invoke-Git $conflicted.Root @('commit', '-m', 'main conflict') | Out-Null
    Set-Content -LiteralPath (Join-Path $conflicted.Feature 'shared.txt') -Value 'feature'
    Invoke-Git $conflicted.Feature @('add', 'shared.txt') | Out-Null
    Invoke-Git $conflicted.Feature @('commit', '-m', 'feature conflict') | Out-Null
    $mainBefore = Invoke-Git $conflicted.Root @('rev-parse', 'main')
    $featureBefore = Invoke-Git $conflicted.Root @('rev-parse', 'feature/test')
    $remotesBefore = Invoke-Git $conflicted.Root @('remote')
    $integration = Invoke-Integration $conflicted
    Assert-Equal 2 $integration.ExitCode 'Conflicted integration should stop with the conflict status'
    Assert-Equal 'CONFLICT' $integration.Result.status 'Conflicted integration status is incorrect'
    if ($integration.Result.detail -notmatch 'merging main into feature/test conflicts') { throw 'Conflicted integration should report the pre-merge conflict.' }
    Assert-Equal $mainBefore (Invoke-Git $conflicted.Root @('rev-parse', 'main')) 'Conflicted integration must not alter main'
    Assert-Equal $featureBefore (Invoke-Git $conflicted.Root @('rev-parse', 'feature/test')) 'Conflicted integration must restore the feature branch'
    Assert-Equal $remotesBefore (Invoke-Git $conflicted.Root @('remote')) 'Conflicted integration must not create or use a remote'
    Assert-Equal '' (Invoke-Git $conflicted.Feature @('status', '--porcelain')) 'Conflicted integration must abort the worktree merge'

    Write-Output 'integrate-feature tests passed'
}
finally {
    foreach ($repository in $repositories) {
        if (Test-Path -LiteralPath $repository.Root) {
            Remove-Item -LiteralPath $repository.Root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
