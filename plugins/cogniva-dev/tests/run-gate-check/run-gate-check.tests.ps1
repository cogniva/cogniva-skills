# Dependency-free behavioral tests for workflow-neutral gate orchestration.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$runner = Join-Path $plugin 'scripts\run-gate-check.ps1'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-gate-check-" + [guid]::NewGuid().ToString('N'))
$failures = @()

function Check($label, $condition) {
    if ($condition) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}
function Invoke-Gate([string]$target) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Repo $root -TargetBranch $target 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    [pscustomobject]@{ Code = $code; Text = ($output -join "`n") }
}
function Get-RepositoryState {
    [pscustomobject]@{
        Head = (& git -C $root rev-parse HEAD).Trim()
        Branch = (& git -C $root branch --show-current).Trim()
        Status = ((& git -C $root status --porcelain) -join "`n")
        Refs = ((& git -C $root show-ref) -join "`n")
        Worktrees = ((& git -C $root worktree list --porcelain) -join "`n")
    }
}

try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    & git -C $root init -q
    & git -C $root config user.email 'gate-check-test@example.invalid'
    & git -C $root config user.name 'Gate Check Test'
    Set-Content -LiteralPath (Join-Path $root 'README.md') -Encoding UTF8 -Value 'fixture'
    & git -C $root add README.md
    & git -C $root commit -qm 'fixture'
    $branch = (& git -C $root branch --show-current).Trim()
    $before = Get-RepositoryState

    $green = Invoke-Gate $branch
    $afterGreen = Get-RepositoryState
    Check 'resolvable target branch produces a pass' ($green.Code -eq 0 -and $green.Text -match 'PASS: mechanical gate checks completed')
    Check 'gate orchestration leaves repository lifecycle state unchanged' (($before | ConvertTo-Json -Compress) -eq ($afterGreen | ConvertTo-Json -Compress))

    $unknown = Invoke-Gate 'does-not-exist'
    $afterUnknown = Get-RepositoryState
    Check 'unresolved target is inconclusive rather than certified' ($unknown.Code -eq 2 -and $unknown.Text -match 'INCONCLUSIVE:' -and $unknown.Text -match 'NOT CERTIFIED:' -and $unknown.Text -notmatch 'PASS: mechanical gate checks completed')
    Check 'inconclusive gate leaves repository lifecycle state unchanged' (($before | ConvertTo-Json -Compress) -eq ($afterUnknown | ConvertTo-Json -Compress))
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { exit 1 }
Write-Host 'All run-gate-check assertions passed.'
