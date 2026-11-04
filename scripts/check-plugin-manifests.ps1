# check-plugin-manifests.ps1 — repo green-gate manifest parity checker.
# For every plugin under plugins/ with a .claude-plugin/plugin.json:
#   - its marketplace entry must exist and match the version;
#   - it must ship a .codex-plugin/plugin.json whose version, description, and
#     keywords (element-wise, order-sensitive) equal the .claude-plugin
#     manifest's, and whose "skills" value resolves to the plugin's skills/
#     directory;
#   - every skills/<dir>/ must hold a SKILL.md whose frontmatter name: is <dir>.
# Exits 1 with one line per failure; exits 0 with a summary when clean.
# Windows PowerShell 5.1-compatible. -Root defaults to the repo this script
# lives in (the parent of scripts/); tests pass a fixture root.
[CmdletBinding()]
param([string]$Root)
$ErrorActionPreference = 'Stop'

if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$repoRoot = [System.IO.Path]::GetFullPath($Root)
$failures = @()
$checked = 0

function Get-FrontmatterName([string]$Path) {
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $null }
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { return $null }
        if ($lines[$i] -match '^name:\s*(.+)') { return $Matches[1].Trim().Trim('"').Trim("'") }
    }
    return $null
}

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

    # Codex manifest: required; version, description, keywords must match; skills must resolve.
    $codexPath = Join-Path $dir.FullName '.codex-plugin\plugin.json'
    if (-not (Test-Path -LiteralPath $codexPath)) {
        $failures += "${name}: missing .codex-plugin/plugin.json (every plugin ships both manifests)"
    }
    else {
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

        $skillsDir = [System.IO.Path]::GetFullPath((Join-Path $dir.FullName 'skills')).TrimEnd('\', '/')
        if (-not ($codex.skills -is [string]) -or -not $codex.skills) {
            $failures += "${name}: .codex-plugin/plugin.json has no ""skills"" path"
        }
        else {
            $resolved = [System.IO.Path]::GetFullPath((Join-Path $dir.FullName $codex.skills)).TrimEnd('\', '/')
            if (-not [string]::Equals($resolved, $skillsDir, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $skillsDir -PathType Container)) {
                $failures += "${name}: .codex-plugin/plugin.json ""skills"" is '$($codex.skills)', which does not resolve to the plugin's skills/ directory"
            }
        }
    }

    # Skills: each skills/<dir>/ holds a SKILL.md whose frontmatter name: is <dir>.
    $skillsRoot = Join-Path $dir.FullName 'skills'
    if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
        foreach ($skill in @(Get-ChildItem -LiteralPath $skillsRoot -Directory)) {
            $skillFile = Join-Path $skill.FullName 'SKILL.md'
            if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
                $failures += "${name}: skills/$($skill.Name)/ has no SKILL.md"
                continue
            }
            $skillName = Get-FrontmatterName $skillFile
            if ($skillName -cne $skill.Name) {
                $failures += "${name}: skills/$($skill.Name)/SKILL.md frontmatter name is '$skillName', expected '$($skill.Name)'"
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
