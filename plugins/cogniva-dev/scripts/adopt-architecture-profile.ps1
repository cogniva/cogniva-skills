#Requires -Version 7.0
# Copy a library profile, and every profile it inherits from, from the plugin
# library into <repo>/.cogniva/profiles/, and record each copy in
# <repo>/.cogniva/adopted/<id>.yml (source, plugin version, content hash). The
# repo copy is what every tool reads; updating is a deliberate re-run whose
# result shows up as an ordinary diff. A profile folder without a record is
# repo-owned and -Refresh never writes it. Never writes a .cogniva-profile.yml
# marker - declaring stays a separate choice.
#
#   -Profile <id>   adopt or refresh that profile and its chain.
#   -Refresh        refresh every profile with a record, plus any record-less
#                   copy equal to its library profile or to a Stage 1 library copy.
#
# Outcomes per profile (repo copy vs library, compared with Get-TreeHash):
#   copy absent                                   -> ADOPTED + record
#   copy equals library                           -> UP-TO-DATE (a missing or out-of-date record is written)
#   copy equals its record, library newer         -> REFRESHED + record
#   copy differs from its record                  -> LOCALLY-EDITED, blocked; -Force -> REPLACED
#   no record, copy equals a Stage 1 library copy -> REFRESHED + record
#   no record, copy differs                       -> DIFFERS, blocked; -Force -> REPLACED
# After writing it prints REMOVED: <id>/<file> for every file a refresh dropped
# and a REVIEW: line for every non-CURRENT delta of every repo-owned profile.
#
# Writes are staged: each profile is copied to a temporary sibling folder and
# verified, then swapped in with the previous copy kept as a backup until every
# swap succeeds; any failure rolls every swap back, and reports the copies as
# restored only when every restore verifiably succeeded - otherwise it names
# where each surviving previous copy is. Records are written only after every
# swap succeeded.
# Exit 0 = adopted, refreshed or already up to date; 1 = blocked (LOCALLY-EDITED
# or DIFFERS; nothing written; re-run with -Force to replace the copy);
# 2 = usage, profile, or copy error.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [string]$Profile,
    [switch]$Refresh,
    [string]$LibraryRoot,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'profile-lib.ps1')

function Fail([string]$Message) { [Console]::Error.WriteLine("adopt-architecture-profile: $Message"); exit 2 }

# Tree hashes of the Stage 1 library profiles (frozen in tests/architecture-profile/fixtures/stage1),
# so a Stage 1 adoption, which has no record, refreshes cleanly instead of reading as a local edit.
$script:Stage1Hashes = @{ 'cogniva-base' = @('ae8f8cbe9d33'); 'dotnet' = @('d38faa90eaf1') }
# Stage 1 standards that left the library; their text lives in the migration guide.
$script:RetiredStandards = @{ 'dotnet' = @('standards/dotnet/module-layout.md', 'standards/dotnet/module-dependencies.md') }

# Relative path -> normalised text (the normalisation Get-TreeHash uses), so the
# differing-files list agrees with the hash comparison.
function Get-TreeSnapshot([string]$Root) {
    $snapshot = @{}
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return $snapshot }
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File -Force) {
        $relative = Get-RelativeDisplay $Root $file.FullName
        $snapshot[$relative] = Read-NormalisedFile $file.FullName
    }
    return $snapshot
}

function Get-SnapshotDifferences([hashtable]$Want, [hashtable]$Have) {
    return @(@($Want.Keys) + @($Have.Keys) | Select-Object -Unique | Where-Object { $Want[$_] -cne $Have[$_] } | Sort-Object)
}

# The adoption record for $Id, or $null when there is none. A malformed record throws.
function Read-AdoptionRecord([string]$RecordsRoot, [string]$Id) {
    $file = Join-Path $RecordsRoot "$Id.yml"
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return $null }
    $display = "$($script:AdoptedRelative)/$Id.yml"
    $data = Read-CognivaYamlFile $file @('source', 'plugin-version', 'content') @('content') $display
    if ($data['content'] -isnot [string] -or $data['content'] -cnotmatch $script:BasisPattern) { Throw-ProfileError "${display}: 'content' must be 12 lowercase hex characters" }
    return $data
}

# The cogniva-dev plugin's version for the record, or 'unknown'.
function Get-PluginVersion {
    try {
        $version = [string](Get-Content -Raw -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) '.claude-plugin/plugin.json') | ConvertFrom-Json).version
        if ($version -match '^[0-9A-Za-z][0-9A-Za-z.+-]*$') { return $version }
    }
    catch { }
    return 'unknown'
}

if ([bool]$Profile -eq [bool]$Refresh) { Fail 'pass -Profile <id> or -Refresh' }

try {
    if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
    if ($Profile) { Assert-ProfileId $Profile '-Profile' }
    $repoFull = (Get-Item -LiteralPath $Repo).FullName
    if (-not $LibraryRoot) { $LibraryRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'profiles' }
    $library = New-ProfileSource $LibraryRoot 'plugin-library'
    $destRoot = Join-Path $repoFull $script:RepoProfilesRelative
    $recordsRoot = Join-Path $repoFull $script:AdoptedRelative

    # Ids to adopt, de-duplicated in first-seen order.
    $ids = [System.Collections.Generic.List[string]]::new()
    if ($Profile) {
        if (-not (Get-ProfileEntry $library $Profile)) { Fail "profile '$Profile' is not in the plugin library ($LibraryRoot)" }
        foreach ($id in Resolve-ProfileChain $Profile $library $null '-Profile') { $ids.Add($id) }
    }
    else {
        $roots = [System.Collections.Generic.List[string]]::new()
        if (Test-Path -LiteralPath $recordsRoot -PathType Container) {
            foreach ($file in Get-ChildItem -LiteralPath $recordsRoot -File -Filter '*.yml' | Sort-Object Name) {
                $id = $file.BaseName
                Assert-ProfileId $id "$($script:AdoptedRelative)/$($file.Name)"
                if (-not (Get-ProfileEntry $library $id)) { Fail "$($script:AdoptedRelative)/$($file.Name): profile '$id' is no longer in the plugin library ($LibraryRoot)" }
                $roots.Add($id)
            }
        }
        # A record-less copy is refreshed only when it is unmistakably a library copy:
        # equal to the library profile, or to a Stage 1 library profile.
        if (Test-Path -LiteralPath $destRoot -PathType Container) {
            foreach ($dir in Get-ChildItem -LiteralPath $destRoot -Directory | Sort-Object Name) {
                $id = $dir.Name
                if ($id -cnotmatch $script:ProfileIdPattern -or $id -ceq 'none' -or $roots.Contains($id)) { continue }
                if (Test-Path -LiteralPath (Join-Path $recordsRoot "$id.yml") -PathType Leaf) { continue }
                $entry = Get-ProfileEntry $library $id
                if (-not $entry) { continue }
                $copyHash = Get-TreeHash $dir.FullName
                if ($copyHash -eq (Get-TreeHash $entry.Path) -or @($script:Stage1Hashes[$id]) -contains $copyHash) { $roots.Add($id) }
            }
        }
        foreach ($rootId in $roots) {
            foreach ($id in Resolve-ProfileChain $rootId $library $null "-Refresh ($rootId)") { if (-not $ids.Contains($id)) { $ids.Add($id) } }
        }
        if (-not $ids.Count) { Write-Output 'Nothing to refresh: no adopted library profiles.'; exit 0 }
    }

    $plan = @()
    $blocked = @()
    foreach ($id in $ids) {
        $source = (Get-ProfileEntry $library $id).Path
        $dest = Join-Path $destRoot $id
        $step = [pscustomobject]@{
            Id = $id; Source = $source; Dest = $dest; Want = (Get-TreeSnapshot $source); LibHash = (Get-TreeHash $source)
            Record = (Read-AdoptionRecord $recordsRoot $id); Previous = $null; Action = $null
        }
        $plan += $step
        if (-not (Test-Path -LiteralPath $dest)) { $step.Action = 'ADOPTED'; continue }
        $copyHash = Get-TreeHash $dest
        if ($copyHash -eq $step.LibHash) { $step.Action = 'UP-TO-DATE'; continue }
        $step.Previous = Get-TreeSnapshot $dest
        if ($step.Record) { $step.Action = if ($copyHash -eq $step.Record['content']) { 'REFRESHED' } else { 'LOCALLY-EDITED' } }
        else { $step.Action = if (@($script:Stage1Hashes[$id]) -contains $copyHash) { 'REFRESHED' } else { 'DIFFERS' } }
        if ($step.Action -in 'LOCALLY-EDITED', 'DIFFERS') {
            $blocked += [pscustomobject]@{ Id = $id; Action = $step.Action; Files = (Get-SnapshotDifferences $step.Want $step.Previous) }
            $step.Action = 'REPLACED'
        }
    }
}
catch { Fail ($_.Exception.Message -replace '^ProfileError: ', '') }

if ($blocked.Count -and -not $Force) {
    foreach ($b in $blocked) { Write-Output "$($b.Action): $($script:RepoProfilesRelative)/$($b.Id) - $($b.Files -join ', ')" }
    Write-Output 'Nothing written. A locally edited library copy belongs in a repo-owned profile (amendments/ or replacements/); re-run with -Force to replace the copy.'
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
        if ((Get-TreeHash $step.Stage) -ne $step.LibHash) {
            $staged = Get-SnapshotDifferences $step.Want (Get-TreeSnapshot $step.Stage)
            throw "staged copy of '$($step.Id)' does not match the library ($($staged -join ', '))"
        }
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

# Records, only now that every swap succeeded: every written profile, plus an
# up-to-date copy whose record is missing (a Stage 1 adoption) or out of date.
$pluginVersion = Get-PluginVersion
try {
    foreach ($step in $plan) {
        if ($step.Action -eq 'UP-TO-DATE' -and $step.Record -and $step.Record['content'] -ceq $step.LibHash) { continue }
        New-Item -ItemType Directory -Path $recordsRoot -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $recordsRoot "$($step.Id).yml"), "source: plugin-library/$($step.Id)`nplugin-version: $pluginVersion`ncontent: $($step.LibHash)`n")
    }
}
catch { Fail "the profiles were copied, but an adoption record could not be written: $($_.Exception.Message)" }

$retired = $false
foreach ($step in $writes) {
    if (-not $step.Previous) { continue }
    foreach ($file in @($step.Previous.Keys | Where-Object { -not $step.Want.ContainsKey($_) } | Sort-Object)) {
        Write-Output "REMOVED: $($step.Id)/$file"
        if (@($script:RetiredStandards[$step.Id]) -contains $file) { $retired = $true }
    }
}
if ($retired) { Write-Output 'NOTE: these standards left the library; their text is in the Module bundle layout migration guide (docs/module-bundle-migration.md in the cogniva-dev plugin).' }

foreach ($step in $plan) {
    if ($step.Action -eq 'UP-TO-DATE') { Write-Output "UP-TO-DATE: $($step.Id)" }
    else { Write-Output "$($step.Action): $($step.Id) -> $($script:RepoProfilesRelative)/$($step.Id)" }
}

# Repo-owned deltas whose inherited text changed, or was never reviewed, need a human look.
# A resolution error here is reported but does not change the exit code.
$repoSource = New-ProfileSource $destRoot $script:RepoProfilesRelative $recordsRoot
if (Test-Path -LiteralPath $destRoot -PathType Container) {
    foreach ($dir in Get-ChildItem -LiteralPath $destRoot -Directory | Sort-Object Name) {
        $id = $dir.Name
        if ($id -cnotmatch $script:ProfileIdPattern -or $id -ceq 'none') { continue }
        if ((Get-ProfileOwnership $repoSource $id) -ne 'repo-owned') { continue }
        try {
            $warnings = [System.Collections.Generic.List[string]]::new()
            $ownChain = Resolve-ProfileChain $id $repoSource $null "$($script:RepoProfilesRelative)/$id"
            $effective = Get-EffectiveStandards $ownChain $repoSource $warnings
            foreach ($item in @($effective.Review | Where-Object Profile -eq $id)) {
                Write-Output "REVIEW: $id $($item.Delta) $($item.Standard) is $($item.State) - review it, then run accept-profile-delta.ps1 -Profile $id -Standard $($item.Standard)"
            }
        }
        catch { Write-Output "WARN: $($_.Exception.Message -replace '^ProfileError: ', '')" }
    }
}
if ($Profile) { Write-Output "To declare it, add a $($script:MarkerName) containing 'profile: $Profile' at the repo root (default) or in a folder (override)." }
exit 0
