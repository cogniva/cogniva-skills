<#
.SYNOPSIS
Converts a markdown plan/spec into a single self-contained HTML file.
.DESCRIPTION
Embeds the markdown as JSON inside the HTML template; rendering happens
client-side via vendored marked.js (+ mermaid.js only when needed).
Glossary terms (## headings in -GlossaryPath) become auto-links with an
in-page appendix. Output: sibling .html (or -OutputPath). Prints the path.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$MarkdownPath,
    [string]$GlossaryPath,
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'

$scriptRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$pluginRoot   = Split-Path -Parent $scriptRoot
$templatePath = Join-Path $pluginRoot 'templates\plan-html\template.html'
$markedPath   = Join-Path $pluginRoot 'vendor\marked.min.js'
$mermaidPath  = Join-Path $pluginRoot 'vendor\mermaid.min.js'

if (-not (Test-Path $MarkdownPath)) { throw "Markdown file not found: $MarkdownPath" }
$MarkdownPath = (Resolve-Path $MarkdownPath).Path
$markdown = [System.IO.File]::ReadAllText($MarkdownPath, [System.Text.Encoding]::UTF8)

# Title: first H1, else file name
$title = [System.IO.Path]::GetFileNameWithoutExtension($MarkdownPath)
$h1 = [regex]::Match($markdown, '(?m)^#\s+(.+)$')
if ($h1.Success) { $title = $h1.Groups[1].Value.Trim() }

# Glossary terms: each "## Term" heading + body becomes {term, anchor, definition}
$terms = @()
if ($GlossaryPath) {
    if (Test-Path $GlossaryPath) {
        $glossaryText = [System.IO.File]::ReadAllText((Resolve-Path $GlossaryPath).Path, [System.Text.Encoding]::UTF8)
        $sections = [regex]::Matches($glossaryText, '(?ms)^##\s+(.+?)\s*\r?$(.*?)(?=^##\s|\z)')
        foreach ($s in $sections) {
            $name = $s.Groups[1].Value.Trim()
            $defn = [regex]::Replace($s.Groups[2].Value, '(?ms)```mermaid.*?```', '').Trim()
            $anchor = [regex]::Replace($name.ToLowerInvariant(), '[^a-z0-9\s-]', '')
            $anchor = [regex]::Replace($anchor, '\s+', '-')
            $terms += [pscustomobject]@{ term = $name; anchor = $anchor; definition = $defn }
        }
    } else {
        Write-Warning "Glossary not found: $GlossaryPath - generating without glossary links"
    }
}

# JSON-encode for safe inline <script> embedding; escape </ so </script> in
# content cannot terminate the script block ("<\/" is a legal JS escape).
$markdownJson = ($markdown | ConvertTo-Json -Compress).Replace('</', '<\/')
$termsJson    = (ConvertTo-Json -InputObject @($terms) -Compress).Replace('</', '<\/')

$template = [System.IO.File]::ReadAllText($templatePath, [System.Text.Encoding]::UTF8)
$markedJs = [System.IO.File]::ReadAllText($markedPath, [System.Text.Encoding]::UTF8)
$mermaidJs = ''
if ($markdown -match '(?m)^\s*```mermaid') {
    $mermaidJs = [System.IO.File]::ReadAllText($mermaidPath, [System.Text.Encoding]::UTF8)
}

$titleHtml = [System.Net.WebUtility]::HtmlEncode($title)
$generated = Get-Date -Format 'yyyy-MM-dd HH:mm'

# Fix 1: single-pass substitution so placeholder tokens inside $markdownJson
# (e.g. when the source document quotes the template's own tokens) are not
# corrupted by later sequential .Replace calls.
$script:map = @{
    'TITLE'         = $titleHtml
    'GENERATED'     = $generated
    'MARKDOWN_JSON' = $markdownJson
    'TERMS_JSON'    = $termsJson
    'MARKED_JS'     = $markedJs
    'MERMAID_JS'    = $mermaidJs
}
$evaluator = { param($m)
    $key = $m.Groups[1].Value
    if ($script:map.ContainsKey($key)) { $script:map[$key] } else { $m.Value }
}.GetNewClosure()
$html = [regex]::Replace($template, '\{\{([A-Z_]+)\}\}', $evaluator)

# Fix 3: resolve a relative -OutputPath against the PowerShell working location
if (-not $OutputPath) {
    $OutputPath = [System.IO.Path]::ChangeExtension($MarkdownPath, '.html')
} else {
    $OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
}
[System.IO.File]::WriteAllText($OutputPath, $html, (New-Object System.Text.UTF8Encoding($false)))
Write-Output $OutputPath
