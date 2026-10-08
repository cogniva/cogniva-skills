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
# Each profile also reports its structural-change policy (profile.yml
# structure-kinds, structure-detectors, structure-requires), composed root first.
# -Show <id,...> prints the effective text of the listed standards for exactly
# one target, each part (the standard, then every amendment, root first) under a
# provenance line; it is text-only (not with -Format Json).
# -Require <id,...> is the gate for an architecture-dependent change: a listed
# standard that a RESOLVED target's profile lacks, or that needs human review,
# blocks (JSON: Require.Blocked; text: REQUIRE BLOCKED). -Kinds <kind,...> adds,
# per RESOLVED target, every standard its profile's structure-requires maps those
# kinds to. Unlisted stale standards never block.
# Exit 0 = every target resolved (including MIXED / UNDECLARED); 1 = the report
# was produced but at least one target is ERROR (or -Show's target is not
# RESOLVED); 3 = a required standard is missing or needs human review;
# 2 = usage error, nothing reported. Precedence: 2 > 1 > 3 > 0.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string[]]$Target,
    [string]$Profile,
    [string]$LibraryRoot,
    [ValidateSet('Text', 'Json')][string]$Format = 'Text',
    [string[]]$Show,
    [string[]]$Require,
    [string[]]$Kinds
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'profile-lib.ps1')

function Fail([string]$Message) { [Console]::Error.WriteLine("architecture-profile: $Message"); exit 2 }

try {
    if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
    $repoFull = (Get-Item -LiteralPath $Repo).FullName.TrimEnd('\', '/')
    if (-not $LibraryRoot) { $LibraryRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'profiles' }
    if ($Profile) { Assert-ProfileId $Profile '-Profile' }

    $requested = @($Target | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().Trim("'").Trim('"') } | Where-Object { $_ })
    if (-not $requested.Count) { Fail 'no target supplied' }
    $showIds = @($Show | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ })
    if ($showIds.Count -and $Format -eq 'Json') { Fail '-Show prints text; do not combine it with -Format Json' }
    if ($showIds.Count -and $requested.Count -gt 1) { Fail '-Show takes exactly one target' }
    $requireIds = @($Require | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ })
    $kindIds = @($Kinds | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    foreach ($k in $kindIds) { if ($k -cnotmatch $script:StructureKindPattern) { Fail "-Kinds: '$k' is not a valid structure kind" } }
    $fullTargets = @()
    foreach ($raw in $requested) {
        $full = if ([System.IO.Path]::IsPathRooted($raw)) { [System.IO.Path]::GetFullPath($raw) } else { [System.IO.Path]::GetFullPath((Join-Path $repoFull $raw)) }
        if (-not (Test-PathInside $repoFull $full)) { Fail "target is outside repo: $raw" }
        $fullTargets += $full
    }
}
catch { Fail (Get-ProfileErrorText $_) }

$ctx = New-ResolutionContext $repoFull $LibraryRoot
$targets = @(foreach ($full in $fullTargets) { Resolve-TargetProfile $ctx $full $Profile })

if ($showIds.Count) {
    $t = $targets[0]
    if ($t.Status -ne 'RESOLVED') { Write-Output "architecture-profile: $($t.Target) has no resolved profile ($($t.Status))"; exit 1 }
    $result = $ctx.Results[$t.Profile]
    $picked = @()
    foreach ($wanted in $showIds) {
        $s = @($result.Standards | Where-Object { $_.Id -ieq $wanted }) | Select-Object -First 1
        if (-not $s) { Fail "standard '$wanted' is not in profile '$($t.Profile)'" }
        $picked += $s
    }
    for ($i = 0; $i -lt $picked.Count; $i++) {
        $s = $picked[$i]
        if ($i -gt 0) { Write-Output '' }
        Write-Output "SHOW $($s.Id) - profile $($t.Profile) (chain: $($result.Chain -join ' -> '))"
        if ($s.NeedsReview) { Write-Output 'NEEDS HUMAN REVIEW' }
        foreach ($part in $s.Parts) {
            $state = if ($part.State) { ", $($part.State)" } else { '' }
            Write-Output ''
            Write-Output "--- $($part.Role) from $($part.From) ($($part.Ownership)$state): $($part.Display)"
            Write-Output ([System.IO.File]::ReadAllText($part.Path).TrimEnd())
        }
    }
    exit 0
}

# -Require / -Kinds: a required standard blocks when a RESOLVED target's profile
# lacks it or it needs human review. Review items on other standards never block.
$gateRun = ($requireIds.Count -gt 0 -or $kindIds.Count -gt 0)
$gate = if ($gateRun) { Get-RequireResult $ctx $targets $requireIds $kindIds } else { $null }
# @(if ...) - an if statement's output turns an empty array into $null.
$blocked = @(if ($gate) { $gate.Blocked })

$profiles = [ordered]@{}
foreach ($id in @($targets | Where-Object Status -eq 'RESOLVED' | ForEach-Object Profile | Sort-Object -Unique)) {
    $r = $ctx.Results[$id]
    # Parts (the composition inputs) stay internal; they never reach the report.
    $profiles[$id] = [pscustomobject]@{
        Chain = $r.Chain; ChainDetail = $r.ChainDetail; Description = $r.Description
        Standards = @($r.Standards | Select-Object Id, Description, From, Overrides, Path, ReplacedBy, Amendments, AppliesTo, NeedsReview)
        Review = $r.Review
        Structure = $r.Structure
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
    Warnings = @($ctx.Warnings | Select-Object -Unique)
}
if ($gateRun) { $report | Add-Member -NotePropertyName Require -NotePropertyValue ([pscustomobject]@{ Standards = $requireIds; Kinds = $kindIds; ByTarget = @($gate.ByTarget); Blocked = $blocked }) }

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
    if (@($p.Structure.Detectors).Count) { Write-Output "  STRUCTURE DETECTORS: $(@($p.Structure.Detectors) -join ', ')" }
    foreach ($k in @($p.Structure.Requires.Keys)) {
        $mapped = @($p.Structure.Requires[$k])
        if ($mapped.Count) { Write-Output "  STRUCTURE REQUIRES $($k): $($mapped -join ', ')" }
    }
    foreach ($i in $p.Review) {
        $basisShown = if ($i.Basis) { $i.Basis } else { 'none' }
        $inheritedShown = if ($i.Inherited) { $i.Inherited } else { 'n/a' }
        Write-Output "  REVIEW: $($i.Standard) - $($i.Profile) ($($i.Ownership)) $($i.Delta) is $($i.State) (basis $basisShown -> $inheritedShown)"
    }
}
if ($gateRun) {
    if ($blocked.Count) { foreach ($b in $blocked) { Write-Output "REQUIRE BLOCKED: $($b.Target) $($b.Standard) - $($b.Reason)" } }
    else {
        $shownIds = [System.Collections.Generic.List[string]]::new()
        $source = if ($kindIds.Count) { @($gate.ByTarget | ForEach-Object { $_.Standards }) } else { $requireIds }
        foreach ($id in $source) { if ($id -and -not @($shownIds | Where-Object { $_ -ieq $id }).Count) { $shownIds.Add($id) } }
        $listed = if ($shownIds.Count) { $shownIds -join ', ' } else { 'no standards required' }
        Write-Output "REQUIRE: ok ($listed)"
        # Per target, so a caller can -Show each profile's own list (MIXED targets differ).
        foreach ($bt in @($gate.ByTarget)) {
            $own = if (@($bt.Standards).Count) { @($bt.Standards) -join ', ' } else { 'no standards required' }
            Write-Output "REQUIRE FOR $($bt.Target) ($($bt.Profile)): $own"
        }
    }
    foreach ($bt in @($gate.ByTarget)) { foreach ($k in @($bt.UnknownKinds)) { Write-Output "KIND NOT DECLARED: $($bt.Target) $k (profile $($bt.Profile))" } }
}
foreach ($w in $report.Warnings) { Write-Output "WARN: $w" }
exit $exitCode
