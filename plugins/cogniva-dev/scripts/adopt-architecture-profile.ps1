#Requires -Version 7.0
# Copy a profile, and every profile it inherits from, from the plugin library
# into <repo>/.cogniva/profiles/. The repo copy is what every tool reads;
# updating is a deliberate re-run whose result shows up as an ordinary diff.
# Never writes a .cogniva-profile.yml marker - declaring stays a separate choice.
# Writes are staged: each profile is copied to a temporary sibling folder and
# verified, then swapped in with the previous copy kept as a backup until every
# swap succeeds; any failure rolls every swap back, and reports the copies as
# restored only when every restore verifiably succeeded - otherwise it names
# where each surviving previous copy is.
# Exit 0 = adopted or already up to date; 1 = a repo copy differs from the
# library (nothing written; re-run with -Force to replace it); 2 = usage,
# profile, or copy error.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Profile,
    [string]$LibraryRoot,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'profile-lib.ps1')

function Fail([string]$Message) { [Console]::Error.WriteLine("adopt-architecture-profile: $Message"); exit 2 }

# Relative path -> text with line endings normalised, so a CRLF checkout of an
# LF library file (or the reverse) is not reported as a difference.
function Get-TreeSnapshot([string]$Root) {
    $snapshot = @{}
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return $snapshot }
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File -Force) {
        $relative = Get-RelativeDisplay $Root $file.FullName
        $snapshot[$relative] = ([System.IO.File]::ReadAllText($file.FullName)) -replace "`r`n", "`n"
    }
    return $snapshot
}

function Get-SnapshotDifferences([hashtable]$Want, [hashtable]$Have) {
    return @(@($Want.Keys) + @($Have.Keys) | Select-Object -Unique | Where-Object { $Want[$_] -cne $Have[$_] } | Sort-Object)
}

try {
    if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
    Assert-ProfileId $Profile '-Profile'
    $repoFull = (Get-Item -LiteralPath $Repo).FullName
    if (-not $LibraryRoot) { $LibraryRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'profiles' }
    $library = New-ProfileSource $LibraryRoot 'plugin-library'
    if (-not (Get-ProfileEntry $library $Profile)) { Fail "profile '$Profile' is not in the plugin library ($LibraryRoot)" }
    $chain = Resolve-ProfileChain $Profile $library $null '-Profile'
    $destRoot = Join-Path $repoFull $script:RepoProfilesRelative

    $plan = @()
    $blocked = @()
    foreach ($id in $chain) {
        $source = (Get-ProfileEntry $library $id).Path
        $dest = Join-Path $destRoot $id
        $want = Get-TreeSnapshot $source
        if (-not (Test-Path -LiteralPath $dest)) { $plan += [pscustomobject]@{ Id = $id; Source = $source; Dest = $dest; Want = $want; Action = 'ADOPTED' }; continue }
        $differs = Get-SnapshotDifferences $want (Get-TreeSnapshot $dest)
        if (-not $differs.Count) { $plan += [pscustomobject]@{ Id = $id; Source = $source; Dest = $dest; Want = $want; Action = 'UP-TO-DATE' }; continue }
        $plan += [pscustomobject]@{ Id = $id; Source = $source; Dest = $dest; Want = $want; Action = 'REPLACED' }
        $blocked += [pscustomobject]@{ Id = $id; Files = $differs }
    }
}
catch { Fail ($_.Exception.Message -replace '^ProfileError: ', '') }

if ($blocked.Count -and -not $Force) {
    foreach ($b in $blocked) { Write-Output "DIFFERS: $($script:RepoProfilesRelative)/$($b.Id) - $($b.Files -join ', ')" }
    Write-Output 'Nothing written. The repo copy differs from the plugin library; review the difference, then re-run with -Force to replace it.'
    exit 1
}

$writes = @($plan | Where-Object Action -ne 'UP-TO-DATE')
$token = [guid]::NewGuid().ToString('N').Substring(0, 8)
foreach ($step in $writes) {
    $step | Add-Member -NotePropertyName Stage -NotePropertyValue (Join-Path $destRoot ".$($step.Id).adopting-$token")
    $step | Add-Member -NotePropertyName Backup -NotePropertyValue (Join-Path $destRoot ".$($step.Id).previous-$token")
}
$swapped = [System.Collections.Generic.List[object]]::new()
try {
    # 1. Stage and verify every copy before touching any existing folder.
    foreach ($step in $writes) {
        New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
        Copy-Item -LiteralPath $step.Source -Destination $step.Stage -Recurse
        $staged = Get-SnapshotDifferences $step.Want (Get-TreeSnapshot $step.Stage)
        if ($staged.Count) { throw "staged copy of '$($step.Id)' does not match the library ($($staged -join ', '))" }
    }
    # 2. Swap each staged copy in, keeping the previous copy as a backup. Directory.Move is a
    #    same-volume rename that either happens or does not; Move-Item can fall back to
    #    copy-and-delete and leave a folder half moved.
    foreach ($step in $writes) {
        if (Test-Path -LiteralPath $step.Dest) { [System.IO.Directory]::Move($step.Dest, $step.Backup) }
        $swapped.Add($step)
        [System.IO.Directory]::Move($step.Stage, $step.Dest)
    }
}
catch {
    $reason = $_.Exception.Message
    # Every rollback operation is guarded so one failure cannot stop the rest; the
    # outcome is then verified from the file system rather than assumed.
    $unrestored = @()
    for ($i = $swapped.Count - 1; $i -ge 0; $i--) {
        $step = $swapped[$i]
        # A swapped step's destination is either the new copy or missing; the backup, if any, is the old copy.
        try { if (Test-Path -LiteralPath $step.Dest) { Remove-Item -LiteralPath $step.Dest -Recurse -Force } } catch { }
        try { if ((Test-Path -LiteralPath $step.Backup) -and -not (Test-Path -LiteralPath $step.Dest)) { [System.IO.Directory]::Move($step.Backup, $step.Dest) } } catch { }
        if ($step.Action -eq 'ADOPTED') {
            if (Test-Path -LiteralPath $step.Dest) { $unrestored += "$($step.Id): new copy could not be removed from $($step.Dest)" }
        }
        elseif (Test-Path -LiteralPath $step.Backup) {
            $unrestored += "$($step.Id): previous copy is at $($step.Backup) ($($step.Dest) may hold a partial new copy)"
        }
    }
    $leftovers = @()
    foreach ($step in $writes) {
        try { if (Test-Path -LiteralPath $step.Stage) { Remove-Item -LiteralPath $step.Stage -Recurse -Force } } catch { }
        if (Test-Path -LiteralPath $step.Stage) { $leftovers += $step.Stage }
    }
    $cleanup = if ($leftovers.Count) { " Delete these staging folders by hand: $($leftovers -join '; ')." } else { '' }
    if ($unrestored.Count) { Fail "copy failed and rollback was incomplete: $reason. Restore by hand: $($unrestored -join '; ').$cleanup" }
    Fail "copy failed, existing copies restored: $reason$cleanup"
}
foreach ($step in $writes) {
    if (Test-Path -LiteralPath $step.Backup) { Remove-Item -LiteralPath $step.Backup -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $step.Backup) { Write-Output "WARN: could not remove the previous copy at $($step.Backup); delete it by hand." }
}

foreach ($step in $plan) {
    if ($step.Action -eq 'UP-TO-DATE') { Write-Output "UP-TO-DATE: $($step.Id)" }
    else { Write-Output "$($step.Action): $($step.Id) -> $($script:RepoProfilesRelative)/$($step.Id)" }
}
Write-Output "To declare it, add a $($script:MarkerName) containing 'profile: $Profile' at the repo root (default) or in a folder (override)."
exit 0
