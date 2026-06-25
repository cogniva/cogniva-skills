# Validate that each given file parses as JSON. Exit 0 if all valid, 1 if any
# invalid or missing. Replaces inline `Get-Content ... | ConvertFrom-Json` checks
# (each a unique, un-allowlistable string) with one fixed allowlistable command.
[CmdletBinding()]
param(
    [Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Path
)
$ErrorActionPreference = 'Stop'

$bad = @()
foreach ($p in $Path) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        [Console]::Error.WriteLine("validate-json: not found: $p"); $bad += $p; continue
    }
    try {
        Get-Content -LiteralPath $p -Raw | ConvertFrom-Json -ErrorAction Stop | Out-Null
        Write-Output "OK   $p"
    } catch {
        [Console]::Error.WriteLine("validate-json: invalid JSON: $p"); $bad += $p
    }
}
if ($bad.Count -gt 0) { exit 1 }
exit 0
