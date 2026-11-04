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

# --- scripts/test-task-result.ps1 --------------------------------------------
$validator = Join-Path $plugin 'scripts\test-task-result.ps1'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-task-result-" + [guid]::NewGuid().ToString('N'))
function Invoke-Validator([string]$Reply) {
    $file = Join-Path $root ("reply-" + [guid]::NewGuid().ToString('N') + '.md')
    [System.IO.File]::WriteAllText($file, $Reply, $script:utf8)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $lines = @(& pwsh -NoProfile -File $validator -ReplyFile $file 2>&1 | ForEach-Object { [string]$_ }); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $previous }
    [pscustomobject]@{ Code = $code; Out = (($lines -join "`n").Trim()) }
}
$fence = '```'
try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $r = Invoke-Validator "Done.`n`n${fence}json`n{ `"status`": `"DONE`", `"summary`": `"Added the parser.`", `"commitSha`": `"abc1234`" }`n${fence}`n"
    Check 'valid DONE: exit 0 and normalised JSON' ($r.Code -eq 0 -and $r.Out -eq '{"status":"DONE","summary":"Added the parser.","commitSha":"abc1234"}')

    $r = Invoke-Validator "${fence}json`n{ `"status`": `"BLOCKED`", `"summary`": `"`", `"note`": `"The plan never defines IExportPort.`" }`n${fence}"
    Check 'valid BLOCKED with note: exit 0' ($r.Code -eq 0 -and ($r.Out | ConvertFrom-Json).note -eq 'The plan never defines IExportPort.')

    $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"ok`", `"followups`": [ { `"description`": `"Same off-by-one in the exporter`", `"receipt`": `"exporter.ts:88`", `"strength`": `"clear`", `"size`": `"S`" }, { `"description`": `"Retry policy`", `"receipt`": `"client.ts:12 has none`", `"strength`": `"ambiguous`", `"because`": `"after FeatureX`" } ] }`n${fence}"
    Check 'valid followups: exit 0' ($r.Code -eq 0 -and @(($r.Out | ConvertFrom-Json).followups).Count -eq 2)

    $r = Invoke-Validator "${fence}json`n{ `"summary`": `"no status`" }`n${fence}"
    Check 'missing status: MALFORMED' ($r.Code -eq 1 -and $r.Out -match "^MALFORMED: .*missing required property 'status'")

    $r = Invoke-Validator "${fence}json`n{ `"status`": `"FINISHED`", `"summary`": `"x`" }`n${fence}"
    Check 'bad status enum: MALFORMED' ($r.Code -eq 1 -and $r.Out -match '^MALFORMED: result\.status is "FINISHED"')

    $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"x`", `"extra`": 1 }`n${fence}"
    Check 'extra top-level property: MALFORMED' ($r.Code -eq 1 -and $r.Out -match "^MALFORMED: .*'extra'")

    $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"x`", `"followups`": [ { `"description`": `"d`", `"receipt`": `"r`", `"strength`": `"clear`", `"owner`": `"me`" } ] }`n${fence}"
    Check 'extra followups item property: MALFORMED' ($r.Code -eq 1 -and $r.Out -match "^MALFORMED: result\.followups\[0\] has a property .*'owner'")

    $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"x`", `"followups`": [ { `"description`": `"d`", `"strength`": `"clear`" } ] }`n${fence}"
    Check 'followups item missing receipt: MALFORMED' ($r.Code -eq 1 -and $r.Out -match "^MALFORMED: result\.followups\[0\] is missing required property 'receipt'")

    $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": 5 }`n${fence}"
    Check 'wrong type: MALFORMED' ($r.Code -eq 1 -and $r.Out -match '^MALFORMED: result\.summary must be a string')

    $r = Invoke-Validator "DONE`nsummary: added the parser`n"
    Check 'no fenced block: MALFORMED' ($r.Code -eq 1 -and $r.Out -match '^MALFORMED: no fenced')

    $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"x`", }`n${fence}"
    Check 'invalid JSON: MALFORMED' ($r.Code -eq 1 -and $r.Out -match '^MALFORMED: the last json block is not valid JSON')

    $r = Invoke-Validator "First try:`n${fence}json`n{ `"status`": `"BLOCKED`", `"summary`": `"first`", `"note`": `"n`" }`n${fence}`nThen:`n${fence}json`n{ `"status`": `"DONE`", `"summary`": `"second`" }`n${fence}`n"
    Check 'two blocks: the last one wins' ($r.Code -eq 0 -and ($r.Out | ConvertFrom-Json).summary -eq 'second')

    $r = Invoke-Validator "I changed two files.`r`n`r`nHere is the result:`r`n${fence}JSON`r`n{`r`n  `"status`": `"DONE`",`r`n  `"summary`": `"caf$([char]0xE9) prose around the block`"`r`n}`r`n${fence}`r`nThanks.`r`n"
    Check 'prose around the block, CRLF and non-ASCII: exit 0' ($r.Code -eq 0 -and ($r.Out | ConvertFrom-Json).summary -eq "caf$([char]0xE9) prose around the block")

    $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"x`" }`n"
    Check 'an unclosed block is not a result: MALFORMED' ($r.Code -eq 1 -and $r.Out -match '^MALFORMED: no fenced')

    $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"2026-10-09T10:00:00`" }`n${fence}"
    Check 'a date-like summary stays a string' ($r.Code -eq 0 -and $r.Out -eq '{"status":"DONE","summary":"2026-10-09T10:00:00"}')

    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & pwsh -NoProfile -File $validator -ReplyFile (Join-Path $root 'missing.md') 2>&1 | Out-Null; $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $previous }
    Check 'a missing reply file is a usage error (exit 2)' ($code -eq 2)
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All task-contract assertions passed.'
exit 0
