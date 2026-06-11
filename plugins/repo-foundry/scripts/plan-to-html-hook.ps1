# PostToolUse hook: regenerate the HTML twin when a plan/spec markdown is written.
# Contract: NEVER block the write - exit 0 on every path, including errors.
# Watched: docs/plans/, docs/specs/, docs/superpowers/plans/, docs/superpowers/specs/
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $payload = $raw | ConvertFrom-Json
    $filePath = $payload.tool_input.file_path
    if (-not $filePath) { exit 0 }
    if ($filePath -notmatch '(?i)docs[\\/](superpowers[\\/])?(plans|specs)[\\/].+\.md$') { exit 0 }
    if (-not (Test-Path $filePath)) { exit 0 }

    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $converter = Join-Path $scriptRoot 'convert-plan.ps1'

    $cwd = $payload.cwd
    if (-not $cwd) { $cwd = (Get-Location).Path }
    $params = @{ MarkdownPath = $filePath }
    $glossary = Join-Path $cwd 'docs\glossary\README.md'
    if (Test-Path $glossary) { $params.GlossaryPath = $glossary }

    $htmlPath = (& $converter @params 3>$null | Select-Object -Last 1)
    $fileUrl = 'file:///' + (($htmlPath -replace '\\', '/') -replace ' ', '%20')
    $context = "plan-to-html hook: regenerated the HTML twin at $htmlPath. " +
        "Tell the user it is updated and END your message with this URL on its own line: $fileUrl"
    $out = @{ hookSpecificOutput = @{ hookEventName = 'PostToolUse'; additionalContext = $context } }
    $out | ConvertTo-Json -Compress -Depth 5
    exit 0
} catch {
    exit 0
}
