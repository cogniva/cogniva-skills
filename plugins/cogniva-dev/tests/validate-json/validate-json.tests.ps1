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

# Windows PowerShell 5.1 turns ANY native-command stderr write into a terminating
# NativeCommandError while $ErrorActionPreference is 'Stop' - and 2>$null does not
# prevent it. validate-json.ps1 reports failures on stderr by design, so every
# negative case killed this suite before its Check ever ran. Drop to 'Continue'
# for the duration of the child call and report the exit code instead.
function Invoke-ValidateJson {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Files)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $script @Files 2>$null | Out-Null
        return $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("vj-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $good = Join-Path $tmp 'good.json'
    $bad  = Join-Path $tmp 'bad.json'
    Set-Content -LiteralPath $good -Value '{ "a": 1, "b": [2, 3] }'
    Set-Content -LiteralPath $bad  -Value '{ this is : not json'

    $code = Invoke-ValidateJson $good
    Check 'exit 0 for a single valid file' ($code -eq 0)

    $code = Invoke-ValidateJson $bad
    Check 'exit 1 for an invalid file' ($code -eq 1)

    $code = Invoke-ValidateJson $good $bad
    Check 'exit 1 when any file is invalid' ($code -eq 1)

    $code = Invoke-ValidateJson (Join-Path $tmp 'missing.json')
    Check 'exit 1 for a missing file' ($code -eq 1)
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
