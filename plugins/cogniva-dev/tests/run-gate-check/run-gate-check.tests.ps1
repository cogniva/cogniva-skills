# Dependency-free behavioral tests for workflow-neutral gate orchestration.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$runner = Join-Path $plugin 'scripts\run-gate-check.ps1'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-gate-check-" + [guid]::NewGuid().ToString('N'))
$bare = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-gate-check-bare-" + [guid]::NewGuid().ToString('N'))
$failures = @()

function Check($label, $condition) {
    if ($condition) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}
function Invoke-Gate([string]$target, [string]$repo = $root) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Repo $repo -TargetBranch $target 2>&1)
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
function New-Fixture([string]$Path, [bool]$WithGreenGate) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    & git -C $Path init -q
    & git -C $Path config user.email 'gate-check-test@example.invalid'
    & git -C $Path config user.name 'Gate Check Test'
    & git -C $Path config core.autocrlf false
    Set-Content -LiteralPath (Join-Path $Path 'README.md') -Encoding UTF8 -Value 'fixture'
    if ($WithGreenGate) {
        New-Item -ItemType Directory -Path (Join-Path $Path '.claude\cogniva-dev') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $Path '.claude\cogniva-dev\green-gate.json') -Encoding UTF8 -Value '{"commands":[{"run":"exit 0","label":"ok"}]}'
    }
    & git -C $Path add -A
    & git -C $Path commit -qm 'fixture'
}

try {
    New-Fixture $root $true
    $branch = (& git -C $root branch --show-current).Trim()
    $before = Get-RepositoryState

    $green = Invoke-Gate $branch
    $afterGreen = Get-RepositoryState
    Check 'resolvable target branch produces a pass' ($green.Code -eq 0 -and $green.Text -match 'PASS: mechanical gate checks completed')
    Check 'a configured green gate reports no SKIPPED line' ($green.Text -notmatch 'SKIPPED:')
    Check 'gate orchestration leaves repository lifecycle state unchanged' (($before | ConvertTo-Json -Compress) -eq ($afterGreen | ConvertTo-Json -Compress))

    $unknown = Invoke-Gate 'does-not-exist'
    $afterUnknown = Get-RepositoryState
    Check 'unresolved target is inconclusive rather than certified' ($unknown.Code -eq 2 -and $unknown.Text -match 'INCONCLUSIVE:' -and $unknown.Text -match 'NOT CERTIFIED:' -and $unknown.Text -notmatch 'PASS: mechanical gate checks completed')
    Check 'inconclusive gate leaves repository lifecycle state unchanged' (($before | ConvertTo-Json -Compress) -eq ($afterUnknown | ConvertTo-Json -Compress))

    New-Fixture $bare $false
    $bareBranch = (& git -C $bare branch --show-current).Trim()
    $skipped = Invoke-Gate $bareBranch $bare
    Check 'an unconfigured green gate is reported as SKIPPED, not passed' ($skipped.Code -eq 0 -and $skipped.Text -match 'SKIPPED: green gate not configured' -and $skipped.Text -notmatch 'PASS: mechanical gate checks completed' -and $skipped.Text -match 'PASS WITH SKIPS:')
}
finally {
    foreach ($dir in @($root, $bare)) { if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force } }
}

if ($failures.Count) { exit 1 }
Write-Host 'All run-gate-check assertions passed.'
