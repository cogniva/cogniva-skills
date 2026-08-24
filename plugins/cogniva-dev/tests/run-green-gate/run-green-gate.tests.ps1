# Dependency-free tests for the single green-gate implementation.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$runner = Join-Path $plugin 'scripts\run-green-gate.ps1'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-green-gate-" + [guid]::NewGuid().ToString('N'))
$failures = @()

function Check($label, $condition) {
    if ($condition) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}
function Invoke-Runner([string]$repo, [string]$configPath) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Repo $repo -ConfigPath $configPath 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    [pscustomobject]@{ Code = $code; Text = ($output -join "`n") }
}

try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $missing = Invoke-Runner $root (Join-Path $root 'missing.json')
    Check 'absent config skips successfully' ($missing.Code -eq 0 -and $missing.Text -match 'skipping the build/test gate')

    $greenConfig = Join-Path $root 'green.json'
    Set-Content -LiteralPath $greenConfig -Encoding UTF8 -Value '{"commands":[{"run":"exit 0","label":"green"}]}'
    $green = Invoke-Runner $root $greenConfig
    Check 'green command succeeds' ($green.Code -eq 0 -and $green.Text -match 'GREEN - all 1 command')

    $redConfig = Join-Path $root 'red.json'
    Set-Content -LiteralPath $redConfig -Encoding UTF8 -Value '{"commands":[{"run":"exit 3","label":"red"}]}'
    $red = Invoke-Runner $root $redConfig
    Check 'red command fails the gate' ($red.Code -eq 1 -and $red.Text -match 'RED - \[red\] exited 3')

    $badConfig = Join-Path $root 'bad.json'
    Set-Content -LiteralPath $badConfig -Encoding UTF8 -Value '{not-json'
    $bad = Invoke-Runner $root $badConfig
    Check 'invalid config is an error' ($bad.Code -eq 2 -and $bad.Text -match 'cannot parse')
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { exit 1 }
Write-Host 'All run-green-gate assertions passed.'
