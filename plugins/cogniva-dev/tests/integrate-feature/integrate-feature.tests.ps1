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

    # Diverged histories stop before the target update and do not use a fallback merge.
    $diverged = New-TestRepository
    $repositories += $diverged
    Set-Content -LiteralPath (Join-Path $diverged.Root 'main.txt') -Value 'main'
    Invoke-Git $diverged.Root @('add', 'main.txt') | Out-Null
    Invoke-Git $diverged.Root @('commit', '-m', 'main divergence') | Out-Null
    Set-Content -LiteralPath (Join-Path $diverged.Feature 'feature.txt') -Value 'feature'
    Invoke-Git $diverged.Feature @('add', 'feature.txt') | Out-Null
    Invoke-Git $diverged.Feature @('commit', '-m', 'feature divergence') | Out-Null
    $mainBefore = Invoke-Git $diverged.Root @('rev-parse', 'main')
    $featureBefore = Invoke-Git $diverged.Root @('rev-parse', 'feature/test')
    $remotesBefore = Invoke-Git $diverged.Root @('remote')
    $integration = Invoke-Integration $diverged
    Assert-Equal 2 $integration.ExitCode 'Diverged integration should stop with the conflict status'
    Assert-Equal 'CONFLICT' $integration.Result.status 'Diverged integration status is incorrect'
    if ($integration.Result.detail -notmatch 'cannot fast-forward') { throw 'Diverged integration should report why fast-forward is impossible.' }
    Assert-Equal $mainBefore (Invoke-Git $diverged.Root @('rev-parse', 'main')) 'Diverged integration must not alter main'
    Assert-Equal $featureBefore (Invoke-Git $diverged.Root @('rev-parse', 'feature/test')) 'Diverged integration must not alter the feature branch'
    Assert-Equal $remotesBefore (Invoke-Git $diverged.Root @('remote')) 'Integration must not create or use a remote'
    if ((Invoke-Git $diverged.Root @('log', '--format=%P', '-1', 'main')) -match ' ') { throw 'Diverged integration must not create a merge commit.' }

    Write-Output 'integrate-feature tests passed'
}
finally {
    foreach ($repository in $repositories) {
        if (Test-Path -LiteralPath $repository.Root) {
            Remove-Item -LiteralPath $repository.Root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
