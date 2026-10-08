#Requires -Version 7.0
# Record that a human reviewed a repo-owned profile's amendments and replacement
# standards against the inherited text they change: rewrites only their `basis:`
# frontmatter lines (inserting one after `description:` when absent). Refuses an
# adopted library profile - its deltas are reviewed upstream - unless -Library is
# given, which works on the plugin's own profile library for maintainers.
# Exit 0 = accepted or already current; 1 = an ORPHANED delta in scope cannot be
# accepted; 2 = usage or profile error.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Profile,
    [string]$Repo,
    [string]$Standard,
    [switch]$All,
    [switch]$Library,
    [string]$LibraryRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'profile-lib.ps1')

function Fail([string]$Message) { [Console]::Error.WriteLine("accept-profile-delta: $Message"); exit 2 }

function Set-BasisLine([string]$Path, [string]$Basis) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $offset = if ($bom) { 3 } else { 0 }
    $body = [System.Text.UTF8Encoding]::new($false).GetString($bytes, $offset, $bytes.Length - $offset)
    $newline = if ($body.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = [System.Collections.Generic.List[string]]::new([string[]]($body -split "`r?`n"))
    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '---') { $end = $i; break } }
    $existing = -1; $description = -1
    for ($i = 1; $i -lt $end; $i++) {
        if ($lines[$i] -cmatch '^basis:') { $existing = $i }
        if ($lines[$i] -cmatch '^description:') { $description = $i }
    }
    if ($existing -ge 0) { $lines[$existing] = "basis: $Basis" } else { $lines.Insert($description + 1, "basis: $Basis") }
    [System.IO.File]::WriteAllText($Path, ($lines -join $newline), [System.Text.UTF8Encoding]::new($bom))
}

try {
    Assert-ProfileId $Profile '-Profile'
    if ([bool]$Standard -eq [bool]$All) { Fail 'pass -Standard <id> or -All' }
    $warnings = [System.Collections.Generic.List[string]]::new()
    if ($Library) {
        if (-not $LibraryRoot) { $LibraryRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'profiles' }
        $source = New-ProfileSource $LibraryRoot 'plugin-library' $null -IsLibrary
    }
    else {
        if (-not $Repo -or -not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
        $repoFull = (Get-Item -LiteralPath $Repo).FullName
        $source = New-ProfileSource (Join-Path $repoFull $script:RepoProfilesRelative) $script:RepoProfilesRelative (Join-Path $repoFull $script:AdoptedRelative)
        if ((Get-ProfileOwnership $source $Profile) -eq 'library') { Fail "'$Profile' is an adopted library profile; its deltas are reviewed upstream - put repo changes in a repo-owned profile" }
    }
    if (-not (Get-ProfileEntry $source $Profile)) { Fail "profile '$Profile' is not in $($source.Display)" }
    $chain = Resolve-ProfileChain $Profile $source $null '-Profile'
    $effective = Get-EffectiveStandards $chain $source $warnings
}
catch { Fail ($_.Exception.Message -replace '^ProfileError: ', '') }

$deltas = @($effective.Standards | ForEach-Object { $_.Parts } | Where-Object { $_.From -eq $Profile -and $_.Role -ne 'standard' })
if ($Standard) {
    $wanted = $Standard.Replace('\', '/')
    $deltas = @($deltas | Where-Object { $_.Standard -ieq $wanted })
    if (-not $deltas.Count) { Fail "'$Standard' is not an amendment or replacement standard in '$Profile'" }
}
$orphans = 0
foreach ($delta in $deltas) {
    switch ($delta.State) {
        'CURRENT' { Write-Output "UP-TO-DATE: $($delta.Display)" }
        'ORPHANED' { Write-Output "ORPHANED: $($delta.Display) cannot be accepted - the standard it changes is no longer inherited; retarget or delete it"; $orphans++ }
        default {
            Set-BasisLine $delta.Path $delta.Inherited
            $old = if ($delta.Basis) { $delta.Basis } else { 'none' }
            Write-Output "ACCEPTED: $($delta.Display) basis $old -> $($delta.Inherited)"
        }
    }
}
if ($orphans) { exit 1 }
exit 0
