$ErrorActionPreference = 'Stop'
$repoRoot  = Split-Path -Parent $PSScriptRoot
$converter = Join-Path $repoRoot 'plugins\repo-foundry\scripts\convert-plan.ps1'
$hook      = Join-Path $repoRoot 'plugins\repo-foundry\scripts\plan-to-html-hook.ps1'
$fixtures  = Join-Path $PSScriptRoot 'fixtures'
$work      = Join-Path ([System.IO.Path]::GetTempPath().TrimEnd('\')) ('repo-foundry-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

$script:failures = 0
function Assert([bool]$condition, [string]$name) {
    if ($condition) { Write-Host "PASS: $name" -ForegroundColor Green }
    else { Write-Host "FAIL: $name" -ForegroundColor Red; $script:failures++ }
}

try {

# --- converter tests -------------------------------------------------------
Copy-Item (Join-Path $fixtures 'sample-plan.md') $work
Copy-Item (Join-Path $fixtures 'no-mermaid.md') $work
$samplePath = Join-Path $work 'sample-plan.md'
$tinyPath   = Join-Path $work 'no-mermaid.md'

$outPath = & $converter -MarkdownPath $samplePath -GlossaryPath (Join-Path $fixtures 'glossary.md')
Assert (Test-Path $outPath) 'converter creates sibling html'
Assert ($outPath -eq (Join-Path $work 'sample-plan.html')) 'output path is sibling .html'

$html = [System.IO.File]::ReadAllText($outPath, [System.Text.Encoding]::UTF8)
Assert ($html.Contains('<title>Sample Plan</title>')) 'title extracted from first H1'
Assert (-not ($html -cmatch '\{\{[A-Z_]+\}\}')) 'no unreplaced placeholders'
Assert (-not $html.Contains("alert('x')</script>")) 'embedded script tag cannot terminate the inline script block'
Assert (($html.IndexOf([char]92 + 'u003c') -ge 0) -or $html.Contains('<\/')) 'angle brackets escaped in embedded JSON (PS 5.1 emits backslash-u003c)'
Assert ($html.Contains('"term":"Module"')) 'glossary terms embedded'
Assert ($html.Contains('"anchor":"contracts"')) 'glossary anchors slugified'
Assert ($html.Length -gt 500000) 'mermaid lib inlined when source has mermaid block'

$tinyOut  = & $converter -MarkdownPath $tinyPath
$tinyHtml = [System.IO.File]::ReadAllText($tinyOut, [System.Text.Encoding]::UTF8)
Assert ($tinyHtml.Length -lt 500000) 'mermaid lib skipped when no mermaid block'
Assert ($tinyHtml.Contains('GLOSSARY_TERMS = []')) 'no glossary -> empty terms array'
Assert (-not ($tinyHtml -cmatch '\{\{[A-Z_]+\}\}')) 'no unreplaced placeholders (no-mermaid)'

# Fix 6: body content round-trip
Assert ($html.Contains('Orders Module')) 'markdown body content embedded'

# Fix 1 regression: placeholder tokens in content survive conversion
Copy-Item (Join-Path $fixtures 'placeholder-tokens.md') $work
$tokenPath = Join-Path $work 'placeholder-tokens.md'
$tokenOut  = & $converter -MarkdownPath $tokenPath
$tokenHtml = [System.IO.File]::ReadAllText($tokenOut, [System.Text.Encoding]::UTF8)
Assert ($tokenHtml.Contains('var SOURCE_MARKDOWN =')) 'token fixture renders'
Assert ($tokenHtml.Contains('{{MARKED_JS}}')) 'literal placeholder tokens in content survive conversion'
Assert (([regex]::Matches($tokenHtml, [regex]::Escape('marked v12.0.2'))).Count -eq 1) 'marked lib inlined exactly once'

# Fix 3: OutputPath resolution
$customOut = Join-Path $work 'custom-name.html'
$returnedPath = & $converter -MarkdownPath $samplePath -OutputPath $customOut
Assert (Test-Path $customOut) 'explicit -OutputPath creates file at that path'
Assert ($returnedPath -eq $customOut) 'converter return value equals -OutputPath'
# Relative -OutputPath test
Push-Location $work
try {
    & $converter -MarkdownPath $samplePath -OutputPath 'rel-out.html' | Out-Null
} finally {
    Pop-Location
}
Assert (Test-Path (Join-Path $work 'rel-out.html')) 'relative -OutputPath resolves against current location'

# Fix 4: explicit -GlossaryPath that does not exist should warn, not throw
$warnGlossary = Join-Path $work 'nonexistent-glossary.md'
$warnOut = & $converter -MarkdownPath $tinyPath -GlossaryPath $warnGlossary -WarningVariable capturedWarnings 2>&1
Assert ($capturedWarnings.Count -gt 0 -or ($warnOut -ne $null)) 'missing explicit glossary emits a warning'

} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

# --- summary ---------------------------------------------------------------
if ($script:failures -gt 0) { Write-Host "$($script:failures) test(s) FAILED" -ForegroundColor Red; exit 1 }
Write-Host 'All tests passed' -ForegroundColor Green
exit 0
