# Resolves one repository workflow phase block without executing it.
# AGENTS.md is preferred; CLAUDE.md is a per-phase transitional fallback.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Phase,
    [ValidateSet('Text', 'Json')][string]$Format = 'Text'
)
$ErrorActionPreference = 'Stop'

function Fail($Message) { [Console]::Error.WriteLine("workflow-obligations: $Message"); exit 2 }
function Get-PhaseBlock([string]$Path, [string]$RequestedPhase) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $lines = @(Get-Content -LiteralPath $Path)
    $section = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^##\s+Cogniva-dev workflow instructions\s*$') { $section = $true; continue }
        if ($section -and $line -match '^##\s+') { break }
        if ($section -and $line -match ('^###\s+' + [regex]::Escape($RequestedPhase) + '\s*$')) {
            $body = @()
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match '^#{1,3}\s+') { break }
                $body += $lines[$j]
            }
            return [pscustomobject]@{ File = $Path; Phase = $RequestedPhase; Lines = @($body) }
        }
    }
    return $null
}

if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
$repoFull = (Get-Item -LiteralPath $Repo).FullName
$agentsPath = Join-Path $repoFull 'AGENTS.md'
$claudePath = Join-Path $repoFull 'CLAUDE.md'
$block = Get-PhaseBlock $agentsPath $Phase
$source = 'none'
if ($block) { $source = 'AGENTS.md' }
else {
    $block = Get-PhaseBlock $claudePath $Phase
    if ($block) { $source = 'CLAUDE.md (fallback)' }
}
$report = [pscustomobject]@{
    Repo = $repoFull
    Phase = $Phase
    Source = $source
    Lines = if ($block) { @($block.Lines) } else { @() }
    ReadOnly = $true
}

if ($Format -eq 'Json') { $report | ConvertTo-Json -Depth 4; exit 0 }
if (-not $block) {
    Write-Output "workflow-obligations: no ### $Phase block in AGENTS.md or CLAUDE.md."
    exit 0
}
Write-Output "workflow-obligations: ### $Phase from $source ($($block.File))"
foreach ($line in $block.Lines) { Write-Output $line }
exit 0
