#Requires -Version 7.0
# Resolve the architecture profile for one or more target paths, explain why it
# won, and list the index of standards it provides. Read-only.
# Precedence per target: -Profile, then the nearest .cogniva-profile.yml marker,
# then the repo-root marker. Profiles are read only from <repo>/.cogniva/profiles;
# the plugin library (-LibraryRoot) is consulted only for suggestions and hints.
# Each target resolves independently: a broken marker or profile marks only the
# targets that use it as ERROR.
# Standards compose root ancestor first: standards/ adds new ids, amendments/<id>
# layers onto the inherited text, replacements/<id> supersedes it (flagged as
# REPLACED). Each amendment or replacement records the inherited text it was
# reviewed against (basis:); one that is UNREVIEWED, STALE or ORPHANED still
# applies but is listed under Review, and the target is marked NeedsReview
# (text: NEEDS HUMAN REVIEW). Review state alone never changes the exit code.
# -Show <id> prints the effective text of one standard for exactly one target,
# each part (the standard, then every amendment, root first) under a provenance
# line; it is text-only (not with -Format Json).
# -Require <id,...> is the gate for an architecture-dependent change: a listed
# standard that a RESOLVED target's profile lacks, or that needs human review,
# blocks (JSON: Require.Blocked; text: REQUIRE BLOCKED). Unlisted stale standards
# never block.
# Exit 0 = every target resolved (including MIXED / UNDECLARED); 1 = the report
# was produced but at least one target is ERROR (or -Show's target is not
# RESOLVED); 3 = a standard named by -Require is missing or needs human review;
# 2 = usage error, nothing reported. Precedence: 2 > 1 > 3 > 0.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string[]]$Target,
    [string]$Profile,
    [string]$LibraryRoot,
    [ValidateSet('Text', 'Json')][string]$Format = 'Text',
    [string]$Show,
    [string[]]$Require
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
    if ($Show -and $Format -eq 'Json') { Fail '-Show prints text; do not combine it with -Format Json' }
    if ($Show -and $requested.Count -gt 1) { Fail '-Show takes exactly one target' }
    $requireIds = @($Require | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ })
    $fullTargets = @()
    foreach ($raw in $requested) {
        $full = if ([System.IO.Path]::IsPathRooted($raw)) { [System.IO.Path]::GetFullPath($raw) } else { [System.IO.Path]::GetFullPath((Join-Path $repoFull $raw)) }
        if (-not (Test-PathInside $repoFull $full)) { Fail "target is outside repo: $raw" }
        $fullTargets += $full
    }
}
catch { Fail (Get-ProfileErrorText $_) }

$warnings = [System.Collections.Generic.List[string]]::new()
$repoProfiles = New-ProfileSource (Join-Path $repoFull $script:RepoProfilesRelative) $script:RepoProfilesRelative (Join-Path $repoFull $script:AdoptedRelative)
$library = New-ProfileSource $LibraryRoot 'plugin-library' $null -IsLibrary
$libraryEntries = $null
$profileResults = @{}

# Chain + effective standards for one profile id. A success is computed once and
# shared by every target using it; a failure is recomputed per target so its
# message names that target's own marker.
function Get-ProfileResult([string]$Id, [string]$Origin) {
    if ($profileResults.ContainsKey($Id)) { return $profileResults[$Id] }
    try {
        $chain = Resolve-ProfileChain $Id $repoProfiles $library $Origin
        $effective = Get-EffectiveStandards $chain $repoProfiles $warnings
        $result = [pscustomobject]@{
            Error = $null; Chain = @($chain); Description = (Get-ProfileEntry $repoProfiles $Id).Description
            Effective = $effective; Standards = @($effective.Standards); Review = @($effective.Review)
            ChainDetail = @($chain | ForEach-Object { [pscustomobject]@{ Id = $_; Ownership = (Get-ProfileOwnership $repoProfiles $_) } })
        }
    }
    catch { return [pscustomobject]@{ Error = (Get-ProfileErrorText $_); Chain = @(); Description = $null; Standards = @(); Review = @(); ChainDetail = @() } }
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

    # NeedsReview: the resolved profile has any delta awaiting human review.
    # MatchedStandards: standards whose applies-to globs match this target.
    $needsReview = $false
    $matched = @()
    if ($status -eq 'RESOLVED') {
        $resolved = $profileResults[$profileId]
        $needsReview = @($resolved.Review).Count -gt 0
        $matched = @($resolved.Standards | Where-Object { @($_.AppliesTo | Where-Object { Test-GlobMatch $_ $relative }).Count -gt 0 } | ForEach-Object Id)
    }

    $targets += [pscustomobject]@{
        Target = $relative; Status = $status; Profile = $profileId; Error = $errorText
        Winner = if ($winner) { [pscustomobject]@{ Kind = $winner.Kind; Source = $winner.Source } } else { $null }
        Considered = @($considered); Suggestion = $suggestion
        NeedsReview = $needsReview; MatchedStandards = @($matched)
    }
}

if ($Show) {
    $t = $targets[0]
    if ($t.Status -ne 'RESOLVED') { Write-Output "architecture-profile: $($t.Target) has no resolved profile ($($t.Status))"; exit 1 }
    $wanted = $Show.Replace('\', '/')
    $s = @($profileResults[$t.Profile].Standards | Where-Object { $_.Id -ieq $wanted }) | Select-Object -First 1
    if (-not $s) { Fail "standard '$Show' is not in profile '$($t.Profile)'" }
    Write-Output "SHOW $($s.Id) - profile $($t.Profile) (chain: $($profileResults[$t.Profile].Chain -join ' -> '))"
    if ($s.NeedsReview) { Write-Output 'NEEDS HUMAN REVIEW' }
    foreach ($part in $s.Parts) {
        $state = if ($part.State) { ", $($part.State)" } else { '' }
        Write-Output ''
        Write-Output "--- $($part.Role) from $($part.From) ($($part.Ownership)$state): $($part.Display)"
        Write-Output ([System.IO.File]::ReadAllText($part.Path).TrimEnd())
    }
    exit 0
}

# -Require: a listed standard blocks when a RESOLVED target's profile lacks it or
# it needs human review. Review items on unlisted standards never block.
$blocked = [System.Collections.Generic.List[object]]::new()
if ($requireIds.Count) {
    foreach ($t in @($targets | Where-Object Status -eq 'RESOLVED')) {
        foreach ($id in $requireIds) {
            $s = @($profileResults[$t.Profile].Standards | Where-Object { $_.Id -ieq $id }) | Select-Object -First 1
            $reason = if (-not $s) { "not in profile '$($t.Profile)'" }
            elseif ($s.NeedsReview) { 'needs human review: ' + (@($s.Parts | Where-Object { $_.State -and $_.State -ne 'CURRENT' } | ForEach-Object { "$($_.From) $($_.Role) $($_.State)" }) -join '; ') }
            else { $null }
            if ($reason) { $blocked.Add([pscustomobject]@{ Target = $t.Target; Standard = $id; Reason = $reason }) }
        }
    }
}

$profiles = [ordered]@{}
foreach ($id in @($targets | Where-Object Status -eq 'RESOLVED' | ForEach-Object Profile | Sort-Object -Unique)) {
    $r = $profileResults[$id]
    # Parts (the composition inputs) stay internal; they never reach the report.
    $profiles[$id] = [pscustomobject]@{
        Chain = $r.Chain; ChainDetail = $r.ChainDetail; Description = $r.Description
        Standards = @($r.Standards | Select-Object Id, Description, From, Overrides, Path, ReplacedBy, Amendments, AppliesTo, NeedsReview)
        Review = $r.Review
    }
}

$groups = [ordered]@{}
foreach ($t in $targets) {
    $key = switch ($t.Status) { 'RESOLVED' { $t.Profile } 'NONE' { '(none)' } 'ERROR' { '(error)' } default { '(undeclared)' } }
    if (-not $groups.Contains($key)) { $groups[$key] = @() }
    $groups[$key] += $t.Target
}
$aggregate = if ($groups.Contains('(error)')) { 'ERROR' } elseif ($groups.Count -gt 1) { 'MIXED' } elseif ($groups.Contains('(undeclared)')) { 'UNDECLARED' } else { 'UNIFORM' }
$exitCode = if ($aggregate -eq 'ERROR') { 1 } elseif ($blocked.Count) { 3 } else { 0 }

$report = [pscustomobject]@{
    Repo = $repoFull; ReadOnly = $true; ExplicitProfile = if ($Profile) { $Profile } else { $null }
    Targets = @($targets)
    Aggregate = [pscustomobject]@{ Status = $aggregate; Groups = $groups }
    Profiles = $profiles
    Warnings = @($warnings | Select-Object -Unique)
}
if ($requireIds.Count) { $report | Add-Member -NotePropertyName Require -NotePropertyValue ([pscustomobject]@{ Standards = $requireIds; Blocked = @($blocked) }) }

if ($Format -eq 'Json') { $report | ConvertTo-Json -Depth 10; exit $exitCode }

Write-Output "architecture-profile: read-only resolution for $repoFull"
foreach ($t in $report.Targets) {
    Write-Output ''
    Write-Output "Target: $($t.Target)"
    switch ($t.Status) {
        'RESOLVED' {
            Write-Output "  PROFILE: $($t.Profile) ($($t.Winner.Kind): $($t.Winner.Source))"
            if ($t.NeedsReview) { Write-Output '  NEEDS HUMAN REVIEW' }
        }
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
        Write-Output "  STANDARD $($s.Id) [$($s.From)] - $($s.Description)"
        Write-Output "    $($s.Path)"
        if ($s.ReplacedBy -and @($s.Overrides).Count) { Write-Output "    REPLACED - no longer receives $(@($s.Overrides)[-1]) updates" }
        foreach ($a in $s.Amendments) { Write-Output "    AMENDED BY $($a.From) ($($a.Ownership), $($a.State)): $($a.Path)" }
        if (@($s.AppliesTo).Count) { Write-Output "    APPLIES TO: $($s.AppliesTo -join ', ')" }
    }
    foreach ($i in $p.Review) {
        $basisShown = if ($i.Basis) { $i.Basis } else { 'none' }
        $inheritedShown = if ($i.Inherited) { $i.Inherited } else { 'n/a' }
        Write-Output "  REVIEW: $($i.Standard) - $($i.Profile) ($($i.Ownership)) $($i.Delta) is $($i.State) (basis $basisShown -> $inheritedShown)"
    }
}
if ($requireIds.Count) {
    if ($blocked.Count) { foreach ($b in $blocked) { Write-Output "REQUIRE BLOCKED: $($b.Target) $($b.Standard) - $($b.Reason)" } }
    else { Write-Output "REQUIRE: ok ($($requireIds -join ', '))" }
}
foreach ($w in $report.Warnings) { Write-Output "WARN: $w" }
exit $exitCode
