#Requires -Version 7.0
# Dependency-free suite for the shared task-agent contract (no Pester):
# - schema-parity.test.mjs: templates/task-result.schema.json equals the
#   Workflow template's TASK_RESULT schema;
# - prompt-parity.test.mjs: scripts/new-task-prompt.ps1 prints the template's
#   prompt byte-for-byte across the commits x planPath x statePath matrix;
# - scripts/test-task-result.ps1 accepts valid replies and rejects malformed ones.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8
$failures = @()

function Check($label, $condition) {
    if ($condition) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}
function Invoke-Node([string]$Test) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $lines = @(& node (Join-Path $here $Test) 2>&1 | ForEach-Object { [string]$_ }); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $previous }
    foreach ($line in $lines) { Write-Host $line }
    return $code
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Check 'node is installed (the contract parity tests need it)' $false
}
else {
    Check 'schema parity (node)' ((Invoke-Node 'schema-parity.test.mjs') -eq 0)
    Check 'prompt parity (node)' ((Invoke-Node 'prompt-parity.test.mjs') -eq 0)
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All task-contract assertions passed.'
exit 0
