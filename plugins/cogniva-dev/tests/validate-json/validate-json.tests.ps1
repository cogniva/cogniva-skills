# Dependency-free regression test for validate-json.ps1 (no Pester).
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\scripts\validate-json.ps1'))

$failures = @()
function Check($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("vj-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $good = Join-Path $tmp 'good.json'
    $bad  = Join-Path $tmp 'bad.json'
    Set-Content -LiteralPath $good -Value '{ "a": 1, "b": [2, 3] }'
    Set-Content -LiteralPath $bad  -Value '{ this is : not json'

    & powershell -NoProfile -ExecutionPolicy Bypass -File $script $good 2>$null
    Check 'exit 0 for a single valid file' ($LASTEXITCODE -eq 0)

    & powershell -NoProfile -ExecutionPolicy Bypass -File $script $bad 2>$null
    Check 'exit 1 for an invalid file' ($LASTEXITCODE -eq 1)

    & powershell -NoProfile -ExecutionPolicy Bypass -File $script $good $bad 2>$null
    Check 'exit 1 when any file is invalid' ($LASTEXITCODE -eq 1)

    & powershell -NoProfile -ExecutionPolicy Bypass -File $script (Join-Path $tmp 'missing.json') 2>$null
    Check 'exit 1 for a missing file' ($LASTEXITCODE -eq 1)
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED: $($failures.Count) assertion(s)."
    exit 1
}
Write-Host ""
Write-Host "All validate-json assertions passed."
exit 0
