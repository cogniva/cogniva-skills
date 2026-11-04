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
    # stdout lines only (stderr arrives as ErrorRecords), so "the last line" is the runner's own last stdout line.
    $stdout = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() })
    $last = if ($stdout.Count) { $stdout[$stdout.Count - 1] } else { '' }
    [pscustomobject]@{ Code = $code; Text = ($output -join "`n"); Last = $last }
}

try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $missing = Invoke-Runner $root (Join-Path $root 'missing.json')
    Check 'absent config skips successfully' ($missing.Code -eq 0 -and $missing.Text -match 'skipping the build/test gate')
    Check 'absent config ends with GREEN-GATE-RESULT: SKIPPED' ($missing.Last -eq 'GREEN-GATE-RESULT: SKIPPED')

    $emptyConfig = Join-Path $root 'empty.json'
    Set-Content -LiteralPath $emptyConfig -Encoding UTF8 -Value '{"commands":[]}'
    $empty = Invoke-Runner $root $emptyConfig
    Check 'empty command list is an intentional no-gate' ($empty.Code -eq 0 -and $empty.Text -match "'commands' is empty - intentional no-gate")
    Check 'empty command list ends with GREEN-GATE-RESULT: SKIPPED' ($empty.Last -eq 'GREEN-GATE-RESULT: SKIPPED')

    $greenConfig = Join-Path $root 'green.json'
    Set-Content -LiteralPath $greenConfig -Encoding UTF8 -Value '{"commands":[{"run":"exit 0","label":"green"}]}'
    $green = Invoke-Runner $root $greenConfig
    Check 'green command succeeds' ($green.Code -eq 0 -and $green.Text -match 'GREEN - all 1 command')
    Check 'green run ends with GREEN-GATE-RESULT: GREEN' ($green.Last -eq 'GREEN-GATE-RESULT: GREEN')

    $redConfig = Join-Path $root 'red.json'
    Set-Content -LiteralPath $redConfig -Encoding UTF8 -Value '{"commands":[{"run":"exit 3","label":"red"}]}'
    $red = Invoke-Runner $root $redConfig
    Check 'red command fails the gate' ($red.Code -eq 1 -and $red.Text -match 'RED - \[red\] exited 3')
    Check 'red run ends with GREEN-GATE-RESULT: RED' ($red.Last -eq 'GREEN-GATE-RESULT: RED')

    $badConfig = Join-Path $root 'bad.json'
    Set-Content -LiteralPath $badConfig -Encoding UTF8 -Value '{not-json'
    $bad = Invoke-Runner $root $badConfig
    Check 'invalid config is an error' ($bad.Code -eq 2 -and $bad.Text -match 'cannot parse')
    Check 'invalid config ends with GREEN-GATE-RESULT: ERROR' ($bad.Last -eq 'GREEN-GATE-RESULT: ERROR')

    $noRunConfig = Join-Path $root 'norun.json'
    Set-Content -LiteralPath $noRunConfig -Encoding UTF8 -Value '{"commands":[{"label":"no-run"}]}'
    $noRun = Invoke-Runner $root $noRunConfig
    Check 'a command without run is an error ending with GREEN-GATE-RESULT: ERROR' ($noRun.Code -eq 2 -and $noRun.Last -eq 'GREEN-GATE-RESULT: ERROR')

    $absentRepo = Invoke-Runner (Join-Path $root 'no-such-repo') $greenConfig
    Check 'a missing repo is an error ending with GREEN-GATE-RESULT: ERROR' ($absentRepo.Code -eq 2 -and $absentRepo.Last -eq 'GREEN-GATE-RESULT: ERROR')
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { exit 1 }
Write-Host 'All run-green-gate assertions passed.'
