# Dependency-free tests (no Pester) that this repository's agent instructions
# have one home: AGENTS.md holds the shared rules and the workflow phase blocks,
# CLAUDE.md only imports it, and the AGENTS.md skill roster matches the skill
# directories on disk. Each check is a function that takes a repository root and
# returns its problems, so the suite can prove on a fixture that it can fail.
# PowerShell 7. Runs against the repository this file lives in.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\..\..'))
$obligations = Join-Path $Root 'plugins\cogniva-dev\scripts\resolve-workflow-obligations.ps1'
$sharedHeadings = @('## Rules', '## Layout', '## Cross-host parity', '## Cogniva-dev workflow instructions', '## Common tasks')
$failures = @()
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

# A check passes when the function under test reported no problem.
function Check($label, [string[]]$Problems) {
    $Problems = @($Problems | Where-Object { $_ })
    if ($Problems.Count -eq 0) { Write-Host "  PASS  $label" }
    else {
        Write-Host "  FAIL  $label"
        foreach ($p in $Problems) { Write-Host "        $p" }
        $script:failures += $label
    }
}
# A self-test passes when the function under test DID report a problem.
function CheckFails($label, [string[]]$Problems) {
    if (@($Problems | Where-Object { $_ }).Count -gt 0) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label (the check reported nothing)"; $script:failures += $label }
}
function Read-Lines([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return @([System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8) | ForEach-Object { $_.TrimEnd() })
}
function Write-Text([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Text, $script:utf8NoBom)
}

# The first non-blank line of CLAUDE.md imports AGENTS.md.
function Test-ClaudeImportsAgents([string]$RepoRoot) {
    $lines = Read-Lines (Join-Path $RepoRoot 'CLAUDE.md')
    if ($null -eq $lines) { return 'CLAUDE.md is missing' }
    $first = @($lines | Where-Object { $_.Trim() }) | Select-Object -First 1
    if ($first -cne '@AGENTS.md') { return "the first non-blank line of CLAUDE.md is '$first', not '@AGENTS.md'" }
    return @()
}

# CLAUDE.md states no shared rule: none of the shared headings, and no heading
# other than '## Claude Code notes'.
function Test-ClaudeHoldsNoSharedRules([string]$RepoRoot) {
    $lines = Read-Lines (Join-Path $RepoRoot 'CLAUDE.md')
    if ($null -eq $lines) { return 'CLAUDE.md is missing' }
    $problems = @()
    foreach ($h in $script:sharedHeadings) { if ($lines -ccontains $h) { $problems += "CLAUDE.md contains '$h'" } }
    foreach ($l in @($lines | Where-Object { $_ -match '^#{1,6}\s' })) {
        if ($l -cne '## Claude Code notes') { $problems += "CLAUDE.md has the heading '$l'; only '## Claude Code notes' is allowed" }
    }
    return $problems
}

# AGENTS.md carries every shared section.
function Test-AgentsHoldsSharedRules([string]$RepoRoot) {
    $lines = Read-Lines (Join-Path $RepoRoot 'AGENTS.md')
    if ($null -eq $lines) { return 'AGENTS.md is missing' }
    return @($script:sharedHeadings | Where-Object { $lines -cnotcontains $_ } | ForEach-Object { "AGENTS.md lacks '$_'" })
}

# Both wired phases resolve from AGENTS.md with at least one non-blank line.
# resolve-workflow-obligations.ps1 is a Windows PowerShell 5.1 script.
function Test-PhaseBlocksFromAgents([string]$RepoRoot) {
    $problems = @()
    foreach ($phase in @('before-planning', 'before-integrate')) {
        $json = (& powershell -NoProfile -ExecutionPolicy Bypass -File $script:obligations -Repo $RepoRoot -Phase $phase -Format Json) -join "`n"
        if ($LASTEXITCODE -ne 0) { $problems += "resolve-workflow-obligations exited $LASTEXITCODE for $phase"; continue }
        $report = $json | ConvertFrom-Json
        if ($report.Source -ne 'AGENTS.md') { $problems += "$phase resolves from '$($report.Source)', not 'AGENTS.md'" }
        if (@($report.Lines | Where-Object { "$_".Trim() }).Count -eq 0) { $problems += "$phase block has no non-blank lines" }
    }
    return $problems
}

# The AGENTS.md roster equals the skill directories on disk, per plugin. Format:
# inside '## Layout', the plugin's bullet starts with "- `plugins/<plugin>/`", and
# a sub-bullet line starting "  - Skills:" follows it before the next top-level
# bullet; every backticked name on that ONE line is a skill.
function Get-LayoutSkills([string[]]$Lines, [string]$Plugin) {
    $start = [array]::IndexOf($Lines, '## Layout')
    if ($start -lt 0) { return $null }
    $bullet = '- `plugins/' + $Plugin + '/`'
    for ($i = $start + 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^##\s') { return $null }
        if (-not $Lines[$i].StartsWith($bullet)) { continue }
        for ($j = $i + 1; $j -lt $Lines.Count; $j++) {
            if ($Lines[$j] -match '^(- |#)') { return $null }
            if ($Lines[$j].StartsWith('  - Skills:')) {
                return @([regex]::Matches($Lines[$j], '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value })
            }
        }
        return $null
    }
    return $null
}
function Test-LayoutRoster([string]$RepoRoot) {
    $lines = Read-Lines (Join-Path $RepoRoot 'AGENTS.md')
    if ($null -eq $lines) { return 'AGENTS.md is missing' }
    $problems = @()
    $plugins = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'plugins') -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'skills') -PathType Container })
    foreach ($plugin in $plugins) {
        $onDisk = @(Get-ChildItem -LiteralPath (Join-Path $plugin.FullName 'skills') -Directory | ForEach-Object Name)
        $listed = Get-LayoutSkills $lines $plugin.Name
        if ($null -eq $listed) { $problems += "AGENTS.md ## Layout has no '  - Skills:' line under the plugins/$($plugin.Name)/ bullet"; continue }
        foreach ($s in $onDisk) { if ($listed -cnotcontains $s) { $problems += "$($plugin.Name): skills/$s is not in the AGENTS.md roster" } }
        foreach ($s in $listed) { if ($onDisk -cnotcontains $s) { $problems += "$($plugin.Name): the AGENTS.md roster names '$s', which has no skills/ directory" } }
    }
    return $problems
}

# The repo-init template's CLAUDE.md is exactly the import.
function Test-TemplateClaude([string]$RepoRoot) {
    $path = Join-Path $RepoRoot 'plugins\cogniva-dev\templates\repo\CLAUDE.md'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return 'templates/repo/CLAUDE.md is missing' }
    if ((Get-Content -Raw -LiteralPath $path).Trim() -cne '@AGENTS.md') { return 'templates/repo/CLAUDE.md is not exactly @AGENTS.md' }
    return @()
}

# --- this repository ----------------------------------------------------------
Check 'CLAUDE.md starts by importing AGENTS.md' (Test-ClaudeImportsAgents $Root)
Check 'CLAUDE.md holds no shared rule (only a ## Claude Code notes section is allowed)' (Test-ClaudeHoldsNoSharedRules $Root)
Check 'AGENTS.md holds Rules, Layout, Cross-host parity, Cogniva-dev workflow instructions and Common tasks' (Test-AgentsHoldsSharedRules $Root)
Check 'before-planning and before-integrate resolve from AGENTS.md' (Test-PhaseBlocksFromAgents $Root)
Check 'the AGENTS.md skill roster equals the skill directories of every plugin' (Test-LayoutRoster $Root)
Check 'the repo-init template CLAUDE.md is exactly @AGENTS.md' (Test-TemplateClaude $Root)

# --- the checks can fail (fixture) ----------------------------------------------
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-instruction-governance-" + [guid]::NewGuid().ToString('N'))
try {
    Write-Text (Join-Path $fixture 'CLAUDE.md') "@AGENTS.md`n`n## Rules`n`n- A rule stated in the wrong file.`n"
    Write-Text (Join-Path $fixture 'AGENTS.md') "# AGENTS.md`n`n## Layout`n`n- ``plugins/demo/`` - demo plugin`n  - Skills: ``alpha```n"
    New-Item -ItemType Directory -Path (Join-Path $fixture 'plugins\demo\skills\alpha') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $fixture 'plugins\demo\skills\beta') -Force | Out-Null
    CheckFails 'self-test: a CLAUDE.md with ## Rules is reported' @(Test-ClaudeHoldsNoSharedRules $fixture | Where-Object { $_ -match "contains '## Rules'" })
    CheckFails 'self-test: a skill directory missing from the roster is reported' @(Test-LayoutRoster $fixture | Where-Object { $_ -match 'skills/beta is not in the AGENTS\.md roster' })
    CheckFails 'self-test: an AGENTS.md without phase blocks is reported' @(Test-PhaseBlocksFromAgents $fixture)
    Write-Text (Join-Path $fixture 'CLAUDE.md') "# CLAUDE.md`n`n@AGENTS.md`n"
    CheckFails 'self-test: a CLAUDE.md that does not start with @AGENTS.md is reported' @(Test-ClaudeImportsAgents $fixture)
}
finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All instruction-governance assertions passed.'
exit 0
