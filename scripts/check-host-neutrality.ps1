# check-host-neutrality.ps1 - ratchet on agent-host-specific references in
# shared plugin files. Counts literal, case-sensitive tokens (Claude Code or
# Codex tool names, invocation syntax, paths) in plugins/*/skills/**/*.md
# (except the CODEX.md, WORKTREE.md and WORKFLOW-NOTES.md overlays and the
# workflow-status skill, which are agent-host-specific by design) and in
# plugins/*/scripts/*.ps1, and compares each file's counts with
# scripts/host-neutrality-baseline.json. A count above the baseline, or a
# file/token pair the baseline lacks, fails; a count below it prints an INFO
# line asking for the baseline to be lowered. -Update rewrites the baseline
# from the current tree. Exit 0 = OK or updated, 1 = increase. PowerShell 7.
[CmdletBinding()]
param(
    [string]$Root,
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$Root = [System.IO.Path]::GetFullPath($Root)
$baselinePath = Join-Path $Root 'scripts\host-neutrality-baseline.json'

$tokens = @('AskUserQuestion', 'Workflow(', 'subagent_type', 'general-purpose', '`Explore`', 'CLAUDE_PLUGIN_ROOT', '~/.claude', 'spawn_agent', 'request_user_input', 'apply_patch', '/cogniva-dev:', '/cogniva-skills:')
$overlayNames = @('CODEX.md', 'WORKTREE.md', 'WORKFLOW-NOTES.md')
$hostSpecificSkills = @('workflow-status')

function Measure-Token([string]$Text, [string]$Token) {
    $n = 0; $i = 0
    while (($i = $Text.IndexOf($Token, $i, [System.StringComparison]::Ordinal)) -ge 0) { $n++; $i += $Token.Length }
    return $n
}
function Get-RelativePath([string]$Path) { return [System.IO.Path]::GetRelativePath($script:Root, $Path).Replace('\', '/') }

# --- current counts ------------------------------------------------------------
$files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
$pluginsDir = Join-Path $Root 'plugins'
if (Test-Path -LiteralPath $pluginsDir) {
    foreach ($p in Get-ChildItem -LiteralPath $pluginsDir -Directory) {
        $skills = Join-Path $p.FullName 'skills'
        if (Test-Path -LiteralPath $skills) {
            foreach ($f in Get-ChildItem -LiteralPath $skills -Recurse -File) {
                if ($f.Extension -ne '.md' -or $overlayNames -ccontains $f.Name) { continue }
                $skillDir = [System.IO.Path]::GetRelativePath($skills, $f.FullName).Split([System.IO.Path]::DirectorySeparatorChar)[0]
                if ($hostSpecificSkills -ccontains $skillDir) { continue }
                $files.Add($f)
            }
        }
        $scripts = Join-Path $p.FullName 'scripts'
        if (Test-Path -LiteralPath $scripts) {
            foreach ($f in Get-ChildItem -LiteralPath $scripts -File) { if ($f.Extension -eq '.ps1') { $files.Add($f) } }
        }
    }
}
$current = @{}
foreach ($f in $files) {
    $text = [System.IO.File]::ReadAllText($f.FullName)
    $counts = @{}
    foreach ($t in $tokens) { $n = Measure-Token $text $t; if ($n -gt 0) { $counts[$t] = $n } }
    if ($counts.Count -gt 0) { $current[(Get-RelativePath $f.FullName)] = $counts }
}
$total = 0
foreach ($k in $current.Keys) { foreach ($v in $current[$k].Values) { $total += $v } }

if ($Update) {
    $paths = [string[]]@($current.Keys); [Array]::Sort($paths, [System.StringComparer]::Ordinal)
    $out = [ordered]@{}
    foreach ($path in $paths) {
        $names = [string[]]@($current[$path].Keys); [Array]::Sort($names, [System.StringComparer]::Ordinal)
        $entry = [ordered]@{}
        foreach ($n in $names) { $entry[$n] = $current[$path][$n] }
        $out[$path] = $entry
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $baselinePath) -Force | Out-Null
    [System.IO.File]::WriteAllText($baselinePath, (($out | ConvertTo-Json -Depth 5) + "`n"), [System.Text.UTF8Encoding]::new($false))
    Write-Output "host-neutrality: baseline updated - $total references in $($current.Count) files"
    exit 0
}

# --- compare with the baseline -------------------------------------------------
$baseline = @{}
if (Test-Path -LiteralPath $baselinePath) { $baseline = Get-Content -Raw -LiteralPath $baselinePath | ConvertFrom-Json -AsHashtable }
else { Write-Output 'INFO no scripts/host-neutrality-baseline.json - every reference counts as new; create it with -Update' }
if ($null -eq $baseline) { $baseline = @{} }

$failures = [System.Collections.Generic.List[string]]::new()
$infos = [System.Collections.Generic.List[string]]::new()
$paths = [string[]]@(@($current.Keys) + @($baseline.Keys) | Select-Object -Unique); [Array]::Sort($paths, [System.StringComparer]::Ordinal)
foreach ($path in $paths) {
    $now = if ($current.ContainsKey($path)) { $current[$path] } else { @{} }
    $was = if ($baseline.ContainsKey($path)) { $baseline[$path] } else { @{} }
    foreach ($t in $tokens) {
        $c = if ($now.ContainsKey($t)) { [int]$now[$t] } else { 0 }
        $b = if ($was.ContainsKey($t)) { [int]$was[$t] } else { 0 }
        if ($c -gt $b -and $b -eq 0) { $failures.Add("FAIL host-token-new: $path '$t' now $c (not in the baseline)") }
        elseif ($c -gt $b) { $failures.Add("FAIL host-token-increase: $path '$t' baseline $b, now $c") }
        elseif ($c -lt $b) { $infos.Add("INFO lower the baseline: $path '$t' baseline $b, now $c - run check-host-neutrality.ps1 -Update") }
    }
}
foreach ($i in $infos) { Write-Output $i }
if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Output $f }
    Write-Output "host-neutrality: FAILED - $($failures.Count) increase(s). Write agent-host-neutral text, or move the agent-host-specific part into an overlay or agent-host metadata; run -Update only for a deliberate addition and say why in the commit."
    exit 1
}
Write-Output "host-neutrality: OK - $total host-specific references in $($current.Count) files (baseline)"
exit 0
