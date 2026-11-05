#Requires -Version 7.0
# Green-gate wrapper for the hook input adapter's unit tests
# (hook-input.test.mjs -> scripts/hook-input.js). Dependency-free; needs node,
# which the plugin hooks need anyway.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host '  FAIL  node is installed (the hook-input tests need it)'
    Write-Host ''
    Write-Host 'FAILED: 1 assertion(s).'
    exit 1
}
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try { & node (Join-Path $here 'hook-input.test.mjs') 2>&1 | ForEach-Object { Write-Host ([string]$_) }; $code = $LASTEXITCODE }
finally { $ErrorActionPreference = $previous }
if ($code -ne 0) { Write-Host ''; Write-Host 'FAILED: hook-input assertions (see FAIL lines above).'; exit 1 }
Write-Host ''
Write-Host 'All hook-input assertions passed.'
exit 0
