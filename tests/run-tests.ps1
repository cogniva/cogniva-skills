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
Assert ($tinyHtml.Contains('"term"') -eq $false -or $tinyHtml.Contains('[]')) 'no glossary -> empty terms array'
Assert (-not ($tinyHtml -cmatch '\{\{[A-Z_]+\}\}')) 'no unreplaced placeholders (no-mermaid)'

# --- summary ---------------------------------------------------------------
Remove-Item -Recurse -Force $work
if ($script:failures -gt 0) { Write-Host "$($script:failures) test(s) FAILED" -ForegroundColor Red; exit 1 }
Write-Host 'All tests passed' -ForegroundColor Green
exit 0
