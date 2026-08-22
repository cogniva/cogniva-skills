# Runs a repo's configured green gate: .claude/cogniva-dev/green-gate.json.
#
# This is the single implementation of green-gate command semantics. Consumers
# include gate-check and the heavyweight lifecycle skills.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [string]$ConfigPath
)
$ErrorActionPreference = 'Stop'

function Fail($Message) { [Console]::Error.WriteLine("green-gate: $Message"); exit 2 }

if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
if (-not $ConfigPath) { $ConfigPath = Join-Path $Repo '.claude/cogniva-dev/green-gate.json' }

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    Write-Output 'green-gate: no .claude/cogniva-dev/green-gate.json in this repo - skipping the build/test gate.'
    exit 0
}

try { $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json }
catch { Fail "cannot parse $ConfigPath as JSON: $($_.Exception.Message)" }

if ($null -eq $config.commands) { Fail "config $ConfigPath has no 'commands' array" }
$commands = @($config.commands)
if ($commands.Count -eq 0) {
    Write-Output "green-gate: 'commands' is empty - intentional no-gate."
    exit 0
}

$number = 0
Push-Location -LiteralPath $Repo
try {
    foreach ($command in $commands) {
        $number++
        if (-not $command.run) { Fail "commands[$($number - 1)] has no 'run'" }
        $label = if ($command.label) { $command.label } else { "command $number" }
        Write-Output ""
        Write-Output "green-gate: [$label] $($command.run)"
        if ($command.note) { Write-Output "green-gate:   note: $($command.note)" }
        $priorPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & powershell -NoProfile -Command $command.run 2>&1 | ForEach-Object { Write-Output ([string]$_) }
            $exitCode = $LASTEXITCODE
        }
        finally { $ErrorActionPreference = $priorPreference }
        if ($exitCode -ne 0) {
            Write-Output ""
            Write-Output "green-gate: RED - [$label] exited $exitCode. Do NOT integrate until this passes."
            exit 1
        }
    }
}
finally { Pop-Location }

Write-Output ""
Write-Output "green-gate: GREEN - all $number command(s) exited 0."
exit 0
