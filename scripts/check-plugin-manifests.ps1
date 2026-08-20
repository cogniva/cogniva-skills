# check-plugin-manifests.ps1 — repo green-gate manifest parity checker.
# For every plugin under plugins/ with a .claude-plugin/plugin.json:
#   - its marketplace entry must exist and match the version;
#   - if a .codex-plugin/plugin.json exists, its version, description, and
#     keywords (element-wise, order-sensitive) must equal the .claude-plugin
#     manifest's. (The Codex manifest's extra "skills" key is expected and
#     not compared.)
# Exits 1 with one line per failure; exits 0 with a summary when clean.
# Windows PowerShell 5.1-compatible; paths resolved from the script location.

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = @()
$checked = 0

$marketplacePath = Join-Path $repoRoot '.claude-plugin\marketplace.json'
$marketplace = Get-Content -Raw -LiteralPath $marketplacePath | ConvertFrom-Json

$pluginsDir = Join-Path $repoRoot 'plugins'
$pluginDirs = Get-ChildItem -LiteralPath $pluginsDir -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName '.claude-plugin\plugin.json') }

foreach ($dir in $pluginDirs) {
    $checked++
    $claude = Get-Content -Raw -LiteralPath (Join-Path $dir.FullName '.claude-plugin\plugin.json') | ConvertFrom-Json
    $name = $claude.name

    # Marketplace entry: must exist, version must match.
    $entry = $marketplace.plugins | Where-Object { $_.name -eq $name }
    if (-not $entry) {
        $failures += "${name}: missing marketplace entry in .claude-plugin/marketplace.json"
    }
    elseif ($entry.version -ne $claude.version) {
        $failures += "${name}: version mismatch — claude=$($claude.version) codex/marketplace=$($entry.version)"
    }

    # Codex manifest (optional): version, description, keywords must match.
    $codexPath = Join-Path $dir.FullName '.codex-plugin\plugin.json'
    if (Test-Path -LiteralPath $codexPath) {
        $codex = Get-Content -Raw -LiteralPath $codexPath | ConvertFrom-Json

        if ($codex.version -ne $claude.version) {
            $failures += "${name}: version mismatch — claude=$($claude.version) codex/marketplace=$($codex.version)"
        }
        if ($codex.description -ne $claude.description) {
            $failures += "${name}: description mismatch — claude=$($claude.description) codex/marketplace=$($codex.description)"
        }

        $claudeKeywords = @($claude.keywords)
        $codexKeywords = @($codex.keywords)
        if ($claudeKeywords.Count -ne $codexKeywords.Count) {
            $failures += "${name}: keywords mismatch — claude=$($claudeKeywords -join ',') codex/marketplace=$($codexKeywords -join ',')"
        }
        else {
            for ($i = 0; $i -lt $claudeKeywords.Count; $i++) {
                if ($claudeKeywords[$i] -cne $codexKeywords[$i]) {
                    $failures += "${name}: keywords mismatch — claude=$($claudeKeywords -join ',') codex/marketplace=$($codexKeywords -join ',')"
                    break
                }
            }
        }
    }
}

if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Output $f }
    exit 1
}

Write-Output "manifest parity OK: $checked plugin(s) checked"
exit 0
