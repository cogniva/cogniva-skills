# Dependency-free tests for scripts/check-plugin-manifests.ps1 (no Pester).
# Builds fixture marketplaces under TEMP and runs the checker against each with
# -Root, under Windows PowerShell 5.1 (the shell the green gate runs it in).
# PowerShell 7.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\..\..'))
$checker = Join-Path $repoRoot 'scripts\check-plugin-manifests.ps1'
$base = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-manifests-" + [guid]::NewGuid().ToString('N'))
$failures = @()
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Check($label, $condition) {
    if ($condition) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}
function Write-Text([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Text, $script:utf8NoBom)
}
# A clean one-plugin marketplace: both manifests, a matching marketplace entry, one skill.
function New-Fixture([string]$Name) {
    $root = Join-Path $script:base $Name
    Write-Text (Join-Path $root '.claude-plugin\marketplace.json') '{ "name": "fixture", "plugins": [ { "name": "demo", "source": "./plugins/demo", "version": "1.2.0" } ] }'
    Write-Text (Join-Path $root 'plugins\demo\.claude-plugin\plugin.json') '{ "name": "demo", "version": "1.2.0", "description": "Demo plugin.", "keywords": ["a", "b"] }'
    Write-Text (Join-Path $root 'plugins\demo\.codex-plugin\plugin.json') '{ "name": "demo", "version": "1.2.0", "description": "Demo plugin.", "keywords": ["a", "b"], "skills": "./skills/" }'
    Write-Text (Join-Path $root 'plugins\demo\skills\hello\SKILL.md') "---`nname: hello`ndescription: Says hello.`n---`n`n# Hello`n"
    return $root
}
function Invoke-Checker([string]$Root) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $script:checker -Root $Root 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    [pscustomobject]@{ Code = $code; Out = ((@($lines | ForEach-Object { [string]$_ }) -join "`n").Trim()) }
}

try {
    $r = Invoke-Checker (New-Fixture 'clean')
    Check 'a clean fixture passes' ($r.Code -eq 0 -and $r.Out -match 'manifest parity OK: 1 plugin\(s\) checked')

    $root = New-Fixture 'no-codex'
    Remove-Item -LiteralPath (Join-Path $root 'plugins\demo\.codex-plugin') -Recurse -Force
    $r = Invoke-Checker $root
    Check 'a missing Codex manifest fails' ($r.Code -eq 1 -and $r.Out -match 'demo: missing \.codex-plugin/plugin\.json')

    $root = New-Fixture 'bad-skills-path'
    Write-Text (Join-Path $root 'plugins\demo\.codex-plugin\plugin.json') '{ "name": "demo", "version": "1.2.0", "description": "Demo plugin.", "keywords": ["a", "b"], "skills": "./skill/" }'
    $r = Invoke-Checker $root
    Check 'a Codex skills path that misses skills/ fails' ($r.Code -eq 1 -and $r.Out -match 'does not resolve to the plugin''s skills/ directory')

    $root = New-Fixture 'no-skills-key'
    Write-Text (Join-Path $root 'plugins\demo\.codex-plugin\plugin.json') '{ "name": "demo", "version": "1.2.0", "description": "Demo plugin.", "keywords": ["a", "b"] }'
    $r = Invoke-Checker $root
    Check 'a Codex manifest without skills fails' ($r.Code -eq 1 -and $r.Out -match 'has no "skills" path')

    $root = New-Fixture 'name-mismatch'
    Write-Text (Join-Path $root 'plugins\demo\skills\hello\SKILL.md') "---`nname: hello-world`ndescription: Says hello.`n---`n"
    $r = Invoke-Checker $root
    Check 'a skill whose frontmatter name differs from its folder fails' ($r.Code -eq 1 -and $r.Out -match "skills/hello/SKILL\.md frontmatter name is 'hello-world', expected 'hello'")

    $root = New-Fixture 'no-skill-file'
    New-Item -ItemType Directory -Path (Join-Path $root 'plugins\demo\skills\empty') -Force | Out-Null
    $r = Invoke-Checker $root
    Check 'a skill folder without SKILL.md fails' ($r.Code -eq 1 -and $r.Out -match 'skills/empty/ has no SKILL\.md')

    $root = New-Fixture 'version-mismatch'
    Write-Text (Join-Path $root 'plugins\demo\.codex-plugin\plugin.json') '{ "name": "demo", "version": "1.3.0", "description": "Demo plugin.", "keywords": ["a", "b"], "skills": "./skills/" }'
    $r = Invoke-Checker $root
    Check 'a version mismatch still fails' ($r.Code -eq 1 -and $r.Out -match 'demo: version mismatch')

    $r = Invoke-Checker $repoRoot
    Check 'this repository passes' ($r.Code -eq 0)
}
finally {
    if (Test-Path -LiteralPath $base) { Remove-Item -LiteralPath $base -Recurse -Force }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All manifest-checker assertions passed.'
exit 0
