#Requires -Version 7.0
# Resolve the architecture profile for one or more target paths, explain why it
# won, and list the index of standards it provides. Read-only.
# Precedence per target: -Profile, then the nearest .cogniva-profile.yml marker,
# then the repo-root marker. Profiles are read only from <repo>/.cogniva/profiles;
# the plugin library (-LibraryRoot) is consulted only for suggestions and hints.
# Each target resolves independently: a broken marker or profile marks only the
# targets that use it as ERROR.
# Exit 0 = every target resolved (including MIXED / UNDECLARED); 1 = the report
# was produced but at least one target is ERROR; 2 = usage error, nothing reported.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string[]]$Target,
    [string]$Profile,
    [string]$LibraryRoot,
    [ValidateSet('Text', 'Json')][string]$Format = 'Text'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'profile-lib.ps1')

function Fail([string]$Message) { [Console]::Error.WriteLine("architecture-profile: $Message"); exit 2 }
function Get-ProfileErrorText($ErrorRecord) { return ($ErrorRecord.Exception.Message -replace '^ProfileError: ', '') }

try {
    if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
    $repoFull = (Get-Item -LiteralPath $Repo).FullName.TrimEnd('\', '/')
    if (-not $LibraryRoot) { $LibraryRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'profiles' }
    if ($Profile) { Assert-ProfileId $Profile '-Profile' }

    $requested = @($Target | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().Trim("'").Trim('"') } | Where-Object { $_ })
    if (-not $requested.Count) { Fail 'no target supplied' }
    $fullTargets = @()
    foreach ($raw in $requested) {
        $full = if ([System.IO.Path]::IsPathRooted($raw)) { [System.IO.Path]::GetFullPath($raw) } else { [System.IO.Path]::GetFullPath((Join-Path $repoFull $raw)) }
        if (-not (Test-PathInside $repoFull $full)) { Fail "target is outside repo: $raw" }
        $fullTargets += $full
    }
}
catch { Fail (Get-ProfileErrorText $_) }

$warnings = [System.Collections.Generic.List[string]]::new()
$repoProfiles = New-ProfileSource (Join-Path $repoFull $script:RepoProfilesRelative) $script:RepoProfilesRelative
$library = New-ProfileSource $LibraryRoot 'plugin-library'
$libraryEntries = $null
$profileResults = @{}

# Chain + merged standards for one profile id. A success is computed once and
# shared by every target using it; a failure is recomputed per target so its
# message names that target's own marker.
function Get-ProfileResult([string]$Id, [string]$Origin) {
    if ($profileResults.ContainsKey($Id)) { return $profileResults[$Id] }
    try {
        $chain = Resolve-ProfileChain $Id $repoProfiles $library $Origin
        $result = [pscustomobject]@{
            Error = $null; Chain = @($chain); Description = (Get-ProfileEntry $repoProfiles $Id).Description
            Standards = @(Get-MergedStandards $chain $repoProfiles $warnings)
        }
    }
    catch { return [pscustomobject]@{ Error = (Get-ProfileErrorText $_); Chain = @(); Description = $null; Standards = @() } }
    $script:profileResults[$Id] = $result
    return $result
}

$targets = @()
foreach ($full in $fullTargets) {
    $relative = Get-RelativeDisplay $repoFull $full
    $considered = @()
    $winner = $null
    $suggestion = $null
    $status = 'UNDECLARED'
    $profileId = $null
    $errorText = $null
    try {
        $walk = Get-DirectoryWalk $repoFull $full
        # An explicit -Profile beats every marker, malformed ones included: they are
        # recorded as overridden and reported as warnings, never as the target's error.
        $markers = Get-ProfileMarkers $repoFull $walk -Tolerant:([bool]$Profile)
        if ($Profile) {
            $winner = [pscustomobject]@{ Kind = 'explicit'; Source = '-Profile'; Profile = $Profile }
            foreach ($m in $markers) {
                $considered += [pscustomobject]@{ Kind = $m.Kind; Source = $m.Source; Profile = $m.Profile; Outcome = 'overridden-by-explicit' }
                if ($m.Error) { $warnings.Add("$($m.Error) (overridden by -Profile)") }
            }
        }
        else {
            for ($i = 0; $i -lt $markers.Count; $i++) {
                $m = $markers[$i]
                $considered += [pscustomobject]@{ Kind = $m.Kind; Source = $m.Source; Profile = $m.Profile; Outcome = if ($i -eq 0) { 'won' } else { 'shadowed' } }
            }
            if ($markers.Count) { $winner = [pscustomobject]@{ Kind = $markers[0].Kind; Source = $markers[0].Source; Profile = $markers[0].Profile } }
        }
        if ($winner -and $winner.Profile -eq 'none') { $status = 'NONE' }
        elseif ($winner) {
            $result = Get-ProfileResult $winner.Profile $winner.Source
            if ($result.Error) { $status = 'ERROR'; $errorText = $result.Error }
            else { $status = 'RESOLVED'; $profileId = $winner.Profile }
        }
        else {
            if ($null -eq $libraryEntries) { $libraryEntries = @(Get-AllProfileEntries $library $warnings) }
            $suggestion = Get-ProfileSuggestion $repoFull $walk $libraryEntries
        }
    }
    catch { $status = 'ERROR'; $errorText = Get-ProfileErrorText $_ }

    $targets += [pscustomobject]@{
        Target = $relative; Status = $status; Profile = $profileId; Error = $errorText
        Winner = if ($winner) { [pscustomobject]@{ Kind = $winner.Kind; Source = $winner.Source } } else { $null }
        Considered = @($considered); Suggestion = $suggestion
    }
}

$profiles = [ordered]@{}
foreach ($id in @($targets | Where-Object Status -eq 'RESOLVED' | ForEach-Object Profile | Sort-Object -Unique)) {
    $r = $profileResults[$id]
    $profiles[$id] = [pscustomobject]@{ Chain = $r.Chain; Description = $r.Description; Standards = $r.Standards }
}

$groups = [ordered]@{}
foreach ($t in $targets) {
    $key = switch ($t.Status) { 'RESOLVED' { $t.Profile } 'NONE' { '(none)' } 'ERROR' { '(error)' } default { '(undeclared)' } }
    if (-not $groups.Contains($key)) { $groups[$key] = @() }
    $groups[$key] += $t.Target
}
$aggregate = if ($groups.Contains('(error)')) { 'ERROR' } elseif ($groups.Count -gt 1) { 'MIXED' } elseif ($groups.Contains('(undeclared)')) { 'UNDECLARED' } else { 'UNIFORM' }
$exitCode = if ($aggregate -eq 'ERROR') { 1 } else { 0 }

$report = [pscustomobject]@{
    Repo = $repoFull; ReadOnly = $true; ExplicitProfile = if ($Profile) { $Profile } else { $null }
    Targets = @($targets)
    Aggregate = [pscustomobject]@{ Status = $aggregate; Groups = $groups }
    Profiles = $profiles
    Warnings = @($warnings | Select-Object -Unique)
}

if ($Format -eq 'Json') { $report | ConvertTo-Json -Depth 10; exit $exitCode }

Write-Output "architecture-profile: read-only resolution for $repoFull"
foreach ($t in $report.Targets) {
    Write-Output ''
    Write-Output "Target: $($t.Target)"
    switch ($t.Status) {
        'RESOLVED' { Write-Output "  PROFILE: $($t.Profile) ($($t.Winner.Kind): $($t.Winner.Source))" }
        'NONE' { Write-Output "  PROFILE: none ($($t.Winner.Kind): $($t.Winner.Source))" }
        'ERROR' { Write-Output "  PROFILE: error - $($t.Error)" }
        default { Write-Output '  PROFILE: undeclared' }
    }
    foreach ($c in $t.Considered | Where-Object Outcome -ne 'won') {
        $shown = if ($null -ne $c.Profile) { $c.Profile } else { '(invalid marker)' }
        Write-Output "  $($c.Outcome.ToUpperInvariant()): $($c.Source) -> $shown"
    }
    if ($t.Suggestion) { Write-Output "  $($t.Suggestion.Status): $($t.Suggestion.Profiles -join ', ') (evidence: $($t.Suggestion.Evidence -join ', '))" }
}
Write-Output ''
Write-Output "AGGREGATE: $($report.Aggregate.Status)"
foreach ($id in $report.Profiles.Keys) {
    $p = $report.Profiles[$id]
    Write-Output ''
    Write-Output "Profile $id (chain: $($p.Chain -join ' -> ')) - $($p.Description)"
    foreach ($s in $p.Standards) {
        $over = if ($s.Overrides.Count) { " overrides $($s.Overrides -join ', ')" } else { '' }
        Write-Output "  STANDARD $($s.Id) [$($s.From)$over] - $($s.Description)"
        Write-Output "    $($s.Path)"
    }
}
foreach ($w in $report.Warnings) { Write-Output "WARN: $w" }
exit $exitCode
