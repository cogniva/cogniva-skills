#Requires -Version 7.0
# Builds a throwaway git repository for one agent-host smoke scenario
# (scenarios/<ID>/scenario.json). Layout: src/Calc/Calc.ps1 (Add-Numbers),
# tests/Calc.tests.ps1 (dependency-free, exit 1 on failure), a green gate that
# runs it, a branch policy requiring feature/, root and nested AGENTS.md (each
# with a CLAUDE.md that imports it), notes/unrelated.txt committed and then
# dirtied, and the scenario's seeded plan. QF-STRUCT adds two SDK-style projects
# and adopts and declares the shipped dotnet profile; HOOKS turns worktree mode
# on. The start state the assertions compare against goes to .smoke/ (excluded
# from git before the run): start.txt (HEAD), unrelated.sha256, exclude.before,
# untracked.before and scenario.json.
# Exit 0 = built; 2 = usage error (unknown scenario, non-empty target) or a
# failed build step.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Scenario
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))

function Fail([string]$Message) { [Console]::Error.WriteLine("new-smoke-fixture: $Message"); exit 2 }

$scenarioDir = Join-Path $here "scenarios\$Scenario"
$scenarioFile = Join-Path $scenarioDir 'scenario.json'
if ($Scenario -cnotmatch '^[A-Z]+(-[A-Z]+)*\z' -or -not (Test-Path -LiteralPath $scenarioFile -PathType Leaf)) { Fail "unknown scenario '$Scenario'" }
$data = Get-Content -Raw -LiteralPath $scenarioFile | ConvertFrom-Json
$fx = [System.IO.Path]::GetFullPath($Path)
if ((Test-Path -LiteralPath $fx) -and @(Get-ChildItem -LiteralPath $fx -Force).Count) { Fail "fixture folder is not empty: $fx" }
New-Item -ItemType Directory -Path $fx -Force | Out-Null

function Write-Text([string]$Relative, [string]$Text) {
    $target = Join-Path $fx $Relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    [System.IO.File]::WriteAllText($target, $Text.Replace("`r`n", "`n"))
}
function Invoke-Git([string[]]$GitArgs) {
    $out = @(& git -C $fx @GitArgs 2>&1)
    if ($LASTEXITCODE -ne 0) { Fail "git $($GitArgs -join ' ') failed: $($out -join ' ')" }
    return $out
}

Invoke-Git @('init', '-q') | Out-Null
Invoke-Git @('symbolic-ref', 'HEAD', "refs/heads/$($data.branch)") | Out-Null
Invoke-Git @('config', 'user.email', 'smoke@cogniva.invalid') | Out-Null
Invoke-Git @('config', 'user.name', 'Cogniva smoke') | Out-Null
Invoke-Git @('config', 'core.autocrlf', 'false') | Out-Null

Write-Text 'src/Calc/Calc.ps1' @'
# canary-7
# nested-canary-3
function Add-Numbers($a, $b) {
    return $a + $b
}
'@
Write-Text 'tests/Calc.tests.ps1' @'
# canary-7
# Dependency-free checks for src/Calc. Exit 1 on any failure.
$ErrorActionPreference = 'Stop'
$script:failures = 0
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..\src\Calc') -Filter '*.ps1') { . $file.FullName }
function Check([string]$Label, $Condition) {
    if ($Condition) { Write-Host "  PASS  $Label" }
    else { Write-Host "  FAIL  $Label"; $script:failures++ }
}

Check 'Add-Numbers adds two numbers' ((Add-Numbers 2 3) -eq 5)

if ($script:failures) { Write-Host "FAILED: $($script:failures) check(s)."; exit 1 }
Write-Host 'All calc checks passed.'
exit 0
'@
Write-Text '.claude/cogniva-dev/green-gate.json' @'
{
  "commands": [
    { "run": "pwsh -NoProfile -File tests/Calc.tests.ps1", "label": "calc", "note": "The smoke fixture's own checks." }
  ]
}
'@
Write-Text '.claude/cogniva-dev/policy.json' @'
{ "requiredDevelopmentBranchPrefix": "feature/" }
'@
Write-Text 'AGENTS.md' @'
# Smoke fixture

A throwaway repository for Cogniva agent-host smoke runs. Nothing here is real work.

## Conventions

- Every new `.ps1` file starts with the comment line `# canary-7`.
- Run the checks with `pwsh -NoProfile -File tests/Calc.tests.ps1`.

## Unattended runs

- Nobody is watching this run, so never stop to ask a question. Where a skill would wait for an answer, stop instead and say what you would have asked.
- `notes/unrelated.txt` is someone else's work in progress: never stage, commit, revert or edit it. When a skill asks whether to go ahead while it is dirty, go ahead and leave it as it is.
- When a skill proposes a name or folder for a pasted plan, accept its proposal.
'@
Write-Text 'src/Calc/AGENTS.md' @'
# src/Calc

- Functions in this folder use approved PowerShell verbs.
- Every new `.ps1` file in this folder has `# nested-canary-3` as its second line.
'@
Write-Text 'CLAUDE.md' "@AGENTS.md`n"
Write-Text 'src/Calc/CLAUDE.md' "@AGENTS.md`n"
Write-Text 'notes/unrelated.txt' "unrelated baseline`n"
if ($data.plan) { Write-Text $data.plan ([System.IO.File]::ReadAllText((Join-Path $scenarioDir 'plan.md'))) }

if ($Scenario -ceq 'QF-STRUCT') {
    $project = "<Project Sdk=`"Microsoft.NET.Sdk`">`n  <PropertyGroup>`n    <TargetFramework>net8.0</TargetFramework>`n  </PropertyGroup>`n</Project>`n"
    Write-Text 'src/A/A.csproj' $project
    Write-Text 'src/B/B.csproj' $project
    $adopt = @(& pwsh -NoProfile -File (Join-Path $plugin 'scripts\adopt-architecture-profile.ps1') -Repo $fx -Profile dotnet 2>&1)
    if ($LASTEXITCODE -ne 0) { Fail "adopting the dotnet profile failed: $($adopt -join ' ')" }
    Write-Text '.cogniva-profile.yml' "profile: dotnet`n"
}

Invoke-Git @('add', '-A') | Out-Null
Invoke-Git @('commit', '-q', '-m', "smoke fixture: $Scenario") | Out-Null

# The pre-existing, uncommitted work every scenario must leave alone.
Write-Text 'notes/unrelated.txt' "unrelated work in progress`n"
$excludeLines = @('.smoke/')
if ($data.worktreeMode) {
    Write-Text '.claude/cogniva-dev.local.json' "{ `"worktrees`": true }`n"
    $excludeLines += '.claude/cogniva-dev.local.json'
}
$exclude = Join-Path $fx ((Invoke-Git @('rev-parse', '--git-path', 'info/exclude')) | Select-Object -First 1)
New-Item -ItemType Directory -Path (Split-Path -Parent $exclude) -Force | Out-Null
$existing = if (Test-Path -LiteralPath $exclude) { [System.IO.File]::ReadAllText($exclude) } else { '' }
if ($existing -and -not $existing.EndsWith("`n")) { $existing += "`n" }
[System.IO.File]::WriteAllText($exclude, $existing + (($excludeLines -join "`n") + "`n"))

$start = (Invoke-Git @('rev-parse', 'HEAD')) | Select-Object -First 1
Write-Text '.smoke/start.txt' "$start`n"
Write-Text '.smoke/unrelated.sha256' ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $fx 'notes\unrelated.txt')).Hash + "`n")
[System.IO.File]::Copy($exclude, (Join-Path $fx '.smoke\exclude.before'))
Write-Text '.smoke/scenario.json' ([System.IO.File]::ReadAllText($scenarioFile))
Write-Text '.smoke/untracked.before' ((@(Invoke-Git @('-c', 'core.quotepath=off', 'ls-files', '--others')) -join "`n") + "`n")

Write-Output "FIXTURE: $fx"
Write-Output "SCENARIO: $Scenario"
Write-Output "BRANCH: $($data.branch)"
Write-Output "START: $start"
exit 0
