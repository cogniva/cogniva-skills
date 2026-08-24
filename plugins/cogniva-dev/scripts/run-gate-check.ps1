# Runs the mechanical, read-only checks shared by workflow-neutral readiness
# checks and heavyweight lifecycle skills. Repository-configured green-gate
# commands are the only commands this script delegates to.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [string]$TargetBranch = 'main'
)
$ErrorActionPreference = 'Stop'

function Fail($Message) { [Console]::Error.WriteLine("gate-check: $Message"); exit 2 }
function Invoke-Native([string]$Label, [scriptblock]$Action) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = @(& $Action 2>&1 | ForEach-Object { [string]$_ })
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    foreach ($line in $lines) { Write-Host $line }
    [pscustomobject]@{ Label = $Label; Code = $code; Lines = $lines }
}

if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
$repoFull = (Get-Item -LiteralPath $Repo).FullName
$plugin = Split-Path -Parent $PSScriptRoot
$failures = @()
$warnings = @()
$inconclusive = @()

Write-Output "gate-check: mechanical checks for $repoFull (target: $TargetBranch)"
$status = Invoke-Native 'tree status' { git -C $repoFull status --porcelain }
if ($status.Code -ne 0) { $failures += 'tree status could not be read' }
elseif ($status.Lines.Count -gt 0) { $warnings += 'working tree is dirty; this is a preview, not a merge certificate' }

$obligations = Invoke-Native 'repository obligations' { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $plugin 'scripts/resolve-workflow-obligations.ps1') -Repo $repoFull -Phase 'before-integrate' }
if ($obligations.Code -ne 0) { $failures += "repository-obligation resolution exited $($obligations.Code)" }

$target = Invoke-Native 'target branch' { git -C $repoFull rev-parse --verify --quiet "$TargetBranch^{commit}" }
if ($target.Code -ne 0) {
    $inconclusive += "target branch '$TargetBranch' cannot be resolved; ADR comparison-dependent checks were not evaluated"
}
else {
    $adr = Invoke-Native 'ADR check' { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $plugin 'scripts/check-adrs.ps1') -Worktree $repoFull -TargetBranch $TargetBranch }
    if ($adr.Code -ne 0) { $failures += "ADR check exited $($adr.Code)" }
}

$unstaged = Invoke-Native 'git diff --check' { git -C $repoFull diff --check }
if ($unstaged.Code -ne 0) { $failures += 'git diff --check failed' }
$staged = Invoke-Native 'git diff --cached --check' { git -C $repoFull diff --cached --check }
if ($staged.Code -ne 0) { $failures += 'git diff --cached --check failed' }

$green = Invoke-Native 'green gate' { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $plugin 'scripts/run-green-gate.ps1') -Repo $repoFull }
if ($green.Code -ne 0) { $failures += "green gate exited $($green.Code)" }

foreach ($warning in $warnings) { Write-Output "WARN: $warning" }
if ($failures.Count) {
    foreach ($failure in $failures) { Write-Output "FAIL: $failure" }
    exit 1
}
if ($inconclusive.Count) {
    foreach ($reason in $inconclusive) { Write-Output "INCONCLUSIVE: $reason" }
    Write-Output 'NOT CERTIFIED: commit readiness cannot be certified until the target branch is resolvable or explicitly supplied.'
    exit 2
}
Write-Output 'PASS: mechanical gate checks completed.'
exit 0
