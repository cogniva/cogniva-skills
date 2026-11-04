# Dependency-free tests for scripts/check-host-neutrality.ps1 (no Pester): the
# ratchet passes at its baseline, fails when a count rises or a new file/token
# pair appears, asks for a lower baseline when a count falls, and -Update
# rewrites the baseline. Fixtures live in a temp directory removed in
# `finally`. PowerShell 7.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\..\..'))
$checker = Join-Path $repoRoot 'scripts\check-host-neutrality.ps1'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$failures = @()
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-host-neutrality-" + [guid]::NewGuid().ToString('N'))

function Check($label, $condition) {
    if ($condition) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}
function Write-Text([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Text, $script:utf8NoBom)
}
function Invoke-Checker([switch]$Update) {
    $extra = @(); if ($Update) { $extra = @('-Update') }
    $lines = @(& pwsh -NoProfile -File $checker -Root $root @extra 2>&1)
    [pscustomobject]@{ Code = $LASTEXITCODE; Lines = @($lines | ForEach-Object { [string]$_ }) }
}
function Read-Baseline {
    $path = "$root\scripts\host-neutrality-baseline.json"
    if (-not (Test-Path -LiteralPath $path)) { return @{} }
    return (Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -AsHashtable)
}
function Get-Count($Baseline, [string]$Path, [string]$Token) {
    if ($Baseline.ContainsKey($Path) -and $Baseline[$Path].ContainsKey($Token)) { return [int]$Baseline[$Path][$Token] }
    return 0
}

try {
    $skill = "$root\plugins\p1\skills\s1\SKILL.md"
    Write-Text $skill "Ask with AskUserQuestion. Then AskUserQuestion again; askuserquestion is not counted. Run /cogniva-dev:quick-fix.`n"
    Write-Text "$root\plugins\p1\skills\s1\CODEX.md" "spawn_agent and apply_patch live in the overlay.`n"
    Write-Text "$root\plugins\p1\skills\workflow-status\SKILL.md" "Reads ~/.claude/projects.`n"
    Write-Text "$root\plugins\p1\scripts\a.ps1" "# uses `$env:CLAUDE_PLUGIN_ROOT`n"
    Write-Text "$root\plugins\p1\scripts\sub\b.ps1" "# AskUserQuestion in a nested script is out of scope`n"
    Write-Text "$root\plugins\p1\docs\guide.md" "AskUserQuestion in plugin docs is out of scope`n"

    $r = Invoke-Checker -Update
    Check '-Update writes the baseline and reports its totals' ($r.Code -eq 0 -and ($r.Lines -contains 'host-neutrality: baseline updated - 4 references in 2 files'))
    $b = Read-Baseline
    Check 'baseline holds the shared files with their counts' ((Get-Count $b 'plugins/p1/skills/s1/SKILL.md' 'AskUserQuestion') -eq 2 -and (Get-Count $b 'plugins/p1/skills/s1/SKILL.md' '/cogniva-dev:') -eq 1 -and (Get-Count $b 'plugins/p1/scripts/a.ps1' 'CLAUDE_PLUGIN_ROOT') -eq 1)
    Check 'baseline leaves out overlays, workflow-status, nested scripts and docs' ($b.Count -eq 2)

    $r = Invoke-Checker
    Check 'the tree at its baseline passes' ($r.Code -eq 0 -and ($r.Lines -contains 'host-neutrality: OK - 4 host-specific references in 2 files (baseline)'))

    Write-Text "$root\plugins\p1\skills\s1\CODEX.md" "spawn_agent, spawn_agent, apply_patch, request_user_input.`n"
    $r = Invoke-Checker
    Check 'tokens added to an overlay are not counted' ($r.Code -eq 0)

    Write-Text $skill "Ask with AskUserQuestion. Then AskUserQuestion again, and AskUserQuestion once more. Run /cogniva-dev:quick-fix.`n"
    $r = Invoke-Checker
    Check 'a higher count fails' ($r.Code -eq 1 -and ($r.Lines -contains "FAIL host-token-increase: plugins/p1/skills/s1/SKILL.md 'AskUserQuestion' baseline 2, now 3"))

    Write-Text $skill "Ask with AskUserQuestion. Then AskUserQuestion again. Run /cogniva-dev:quick-fix with subagent_type set.`n"
    $r = Invoke-Checker
    Check 'a new token in a known file fails' ($r.Code -eq 1 -and ($r.Lines -contains "FAIL host-token-new: plugins/p1/skills/s1/SKILL.md 'subagent_type' now 1 (not in the baseline)"))

    Write-Text $skill "Ask with AskUserQuestion. Then AskUserQuestion again. Run /cogniva-dev:quick-fix.`n"
    Write-Text "$root\plugins\p1\skills\s1\NOTES.md" "Patch with apply_patch.`n"
    $r = Invoke-Checker
    Check 'a new file with a token fails' ($r.Code -eq 1 -and ($r.Lines -contains "FAIL host-token-new: plugins/p1/skills/s1/NOTES.md 'apply_patch' now 1 (not in the baseline)"))
    Remove-Item -LiteralPath "$root\plugins\p1\skills\s1\NOTES.md"

    Write-Text $skill "Ask with the agent host's question tool, then AskUserQuestion. Run /cogniva-dev:quick-fix.`n"
    $r = Invoke-Checker
    Check 'a lower count passes and asks for a lower baseline' ($r.Code -eq 0 -and ($r.Lines -contains "INFO lower the baseline: plugins/p1/skills/s1/SKILL.md 'AskUserQuestion' baseline 2, now 1 - run check-host-neutrality.ps1 -Update"))

    $r = Invoke-Checker -Update
    $b = Read-Baseline
    Check '-Update lowers the baseline' ($r.Code -eq 0 -and (Get-Count $b 'plugins/p1/skills/s1/SKILL.md' 'AskUserQuestion') -eq 1)
    $r = Invoke-Checker
    Check 'after -Update the INFO line is gone' ($r.Code -eq 0 -and -not ($r.Lines | Where-Object { $_ -like 'INFO *' }))
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED: $($failures.Count) assertion(s)."
    exit 1
}
Write-Host ""
Write-Host "All host-neutrality assertions passed."
exit 0
