#Requires -Version 7.0
# Structural-change check (contract in docs/architecture-profiles.md).
# -Snapshot: record the working state as a git tree - tracked, staged, unstaged
#   and untracked files, ignored files left out - and print START_TREE: <sha>.
# -Since <tree or commit>: compare that state with the working state now and run
#   every structure detector that a profile declared anywhere in the repository
#   selects, now or at the start (a change in one folder can affect units below
#   it). Each fact is gated under the -Require rule (only standards a change
#   depends on can block it) in the profile each of its paths has now, plus the
#   profile its marker named at the start, so deleting a folder with its marker
#   cannot hide its standards. Requirements and review state always come from
#   the profiles as they are now, so a repair clears on re-check; any change the
#   fix made to profile files is a profile-changed fact that needs the user's OK.
#   -Expected "<kind>:<path>[|<path>...],..." marks a fact expected only when an
#   item of its kind has paths containing every path of the fact.
# Read-only: writes git objects, never refs, the index or the working tree.
# STRUCTURE: NONE | NOT-CHECKED -> exit 0; FAILED (a detector failed, was not
# found or broke its contract, or a declared profile is in ERROR) -> 1;
# usage -> 2; BLOCKED (a required standard is missing or needs human review) -> 3;
# FOUND (structural facts, nothing blocked) -> 4. Precedence 2 > 1 > 3 > 4 > 0.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [string]$Since,
    [switch]$Snapshot,
    [string[]]$Expected,
    [ValidateSet('Text', 'Json')][string]$Format = 'Text',
    [string]$LibraryRoot,
    [string]$DetectorRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'profile-lib.ps1')
. (Join-Path $PSScriptRoot 'structure-lib.ps1')

function Fail([string]$Message) { [Console]::Error.WriteLine("structural-changes: $Message"); exit 2 }
function Get-StructureErrorText($ErrorRecord) { return ($ErrorRecord.Exception.Message -replace '^(StructureError|ProfileError): ', '') }

if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
if ($Snapshot -and $Since) { Fail 'use -Snapshot or -Since, not both' }
if (-not $Snapshot -and -not $Since) { Fail 'pass -Snapshot (at the start) or -Since <START_TREE> (before landing)' }
$repoFull = $null
try { $repoFull = [System.IO.Path]::GetFullPath((@(Invoke-StructureGit $Repo @('rev-parse', '--show-toplevel')) | Select-Object -First 1).Trim()) }
catch { Fail "not a git repository: $Repo" }

if ($Snapshot) {
    try { $tree = Get-WorkingTreeSnapshot $repoFull }
    catch { Write-Output "STRUCTURE: FAILED - could not snapshot the working tree: $(Get-StructureErrorText $_)"; exit 1 }
    Write-Output "START_TREE: $tree"
    exit 0
}

if (-not $LibraryRoot) { $LibraryRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'profiles' }
if (-not $DetectorRoot) { $DetectorRoot = Join-Path $PSScriptRoot 'structure-detectors' }

# -Expected: comma-separated "<kind>:<path>[|<path>...]" items.
$expectations = @()
foreach ($item in @($Expected | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    if ($item -cnotmatch '^(?<kind>[a-z][a-z0-9-]*):(?<paths>.+)$') { Fail "-Expected: '$item' must be '<kind>:<path>[|<path>...]'" }
    $kind = $Matches['kind']
    $scopes = @($Matches['paths'] -split '\|' | ForEach-Object { $_.Trim().Replace('\', '/').Trim('/') } | Where-Object { $_ })
    if (-not $scopes.Count) { Fail "-Expected: '$item' names no path" }
    foreach ($p in $scopes) { if ([System.IO.Path]::IsPathRooted($p) -or $p -match '^[A-Za-z]:' -or @($p -split '/') -contains '..') { Fail "-Expected: '$p' must be a repo-relative path" } }
    $expectations += [pscustomobject]@{ Kind = $kind; Scopes = $scopes }
}

$markerPattern = '(^|/)\.cogniva-profile\.yml$'
$governancePattern = '(^|/)\.cogniva-profile\.yml$|^\.cogniva/'
$ctx = $null
$startMarkers = $null
$failures = [System.Collections.Generic.List[string]]::new()
$report = [ordered]@{ Repo = $repoFull; Base = $null; Head = $null; Status = $null; Reason = $null; Changed = 0; Detectors = @(); Facts = @(); Failures = @(); Warnings = @() }

function Finish([string]$Status, [string]$Reason) {
    $report.Status = $Status
    $report.Reason = $Reason
    $report.Failures = @($failures)
    $report.Warnings = if ($ctx) { @($ctx.Warnings | Select-Object -Unique) } else { @() }
    $code = switch ($Status) { 'FAILED' { 1 } 'BLOCKED' { 3 } 'FOUND' { 4 } default { 0 } }
    if ($Format -eq 'Json') { [pscustomobject]$report | ConvertTo-Json -Depth 10; exit $code }
    $line = "STRUCTURE: $Status"
    if ($Reason) { $line += " - $Reason" }
    Write-Output $line
    $n = 0
    foreach ($f in $report.Facts) {
        $n++
        $mark = if ($f.Expected) { '' } else { ' UNEXPECTED' }
        Write-Output "FACT $n $($f.Kind)$mark ($($f.Detector)): $($f.Units -join ' -> ')"
        Write-Output "  EVIDENCE: $($f.Evidence)"
        if ($f.Kind -eq 'profile-changed') { Write-Output '  REQUIRES: your OK - the fix changed the architecture profiles its changes are checked against' }
        elseif (@($f.Requires).Count) {
            foreach ($q in $f.Requires) {
                $ids = if (@($q.Standards).Count) { @($q.Standards) -join ', ' } else { 'none mapped' }
                $when = if ($q.When -eq 'start') { ', at start' } else { '' }
                Write-Output "  REQUIRES ($($q.Profile)$when): $ids"
            }
        }
        else { Write-Output '  REQUIRES: none (no declared profile governs these paths)' }
        foreach ($b in $f.Blocked) {
            $when = if ($b.When -eq 'start') { ' (at start)' } else { '' }
            Write-Output "  REQUIRE BLOCKED$($when): $($b.Target) $($b.Standard) - $($b.Reason)"
        }
    }
    foreach ($x in $failures) { Write-Output "CHECK FAILED: $x" }
    foreach ($w in $report.Warnings) { Write-Output "WARN: $w" }
    exit $code
}

# $null when $Json is a valid contract-1 report from detector $Id, else what is wrong.
function Test-DetectorReport($Json, [string]$Id) {
    if ($null -eq $Json) { return 'no JSON report on stdout' }
    if ($Json -isnot [System.Management.Automation.PSCustomObject]) { return 'the report is not a JSON object' }
    $names = @($Json.PSObject.Properties.Name)
    if ($names -notcontains 'contract' -or $Json.contract -ne 1) { return "'contract' must be 1" }
    if ($names -notcontains 'detector' -or $Json.detector -cne $Id) { return "'detector' must be '$Id'" }
    if ($names -notcontains 'facts' -or $Json.facts -isnot [array]) { return "'facts' must be a list" }
    foreach ($f in @($Json.facts)) {
        if ($f -isnot [System.Management.Automation.PSCustomObject]) { return 'every fact must be an object' }
        if ([string]$f.kind -cnotmatch $script:StructureKindPattern) { return "fact kind '$($f.kind)' is not a valid structure kind" }
        if (@($f.units | Where-Object { $_ -is [string] -and $_ }).Count -lt 1) { return "a $($f.kind) fact has no units" }
        $paths = @($f.paths)
        $good = @($paths | Where-Object { $_ -is [string] -and $_ -and -not [System.IO.Path]::IsPathRooted($_) -and @($_ -split '/') -notcontains '..' })
        if ($paths.Count -lt 1 -or $good.Count -ne $paths.Count) { return "a $($f.kind) fact needs one or more repo-relative paths" }
        if (-not ($f.evidence -is [string] -and $f.evidence.Trim())) { return "a $($f.kind) fact has no evidence" }
    }
    return $null
}

# A fact is expected when an -Expected item of its kind has paths containing every path of the fact.
function Test-Under([string]$Path, [string]$Scope) {
    if ($Scope -eq '.') { return $true }
    return ([string]::Equals($Path, $Scope, $script:PathComparison) -or $Path.StartsWith("$Scope/", $script:PathComparison))
}
function Test-Expected($Fact) {
    $scopes = @($expectations | Where-Object Kind -ceq $Fact.Kind | ForEach-Object { $_.Scopes })
    if (-not $scopes.Count) { return $false }
    foreach ($p in $Fact.Paths) { if (-not @($scopes | Where-Object { Test-Under $p $_ }).Count) { return $false } }
    return $true
}

function Get-Folder([string]$Path) {
    if ($Path.Contains('/')) { return $Path.Substring(0, $Path.LastIndexOf('/')) }
    return '.'
}
# A path's profile now. A profile depends only on folders, so each folder is resolved once.
$resolvedDirs = @{}
function Resolve-Now([string]$Path) {
    $dir = Get-Folder $Path
    if (-not $script:resolvedDirs.ContainsKey($dir)) { $script:resolvedDirs[$dir] = Resolve-TargetProfile $script:ctx ([System.IO.Path]::GetFullPath((Join-Path $script:repoFull $dir))) $null }
    return $script:resolvedDirs[$dir]
}
# The profile id the nearest marker named for $Path at the start, or $null
# (no marker, 'none', or the fix changed no profile file).
function Get-StartProfile([string]$Path) {
    if ($null -eq $script:startMarkers) { return $null }
    $dir = Get-Folder $Path
    while ($true) {
        if ($script:startMarkers.ContainsKey($dir)) {
            $id = $script:startMarkers[$dir]
            if ($id -ceq 'none') { return $null }
            return $id
        }
        if ($dir -eq '.') { return $null }
        $dir = Get-Folder $dir
    }
}

try {
    $base = Resolve-StructureTree $repoFull $Since
    $head = Get-WorkingTreeSnapshot $repoFull
    $changes = @(Get-TreeChanges $repoFull $base $head)
}
catch { $failures.Add((Get-StructureErrorText $_)); Finish 'FAILED' 'the changes since the start could not be read' }
$report.Base = $base
$report.Head = $head
$report.Changed = $changes.Count
if (-not $changes.Count) { Finish 'NONE' 'no changes since the start' }

$ctx = New-ResolutionContext $repoFull $LibraryRoot
$facts = [System.Collections.Generic.List[object]]::new()

# Profile files the fix changed are always listed, and always need the user's
# OK: a fix may not quietly change the standards its own changes are checked
# against. The markers as they were at the start are kept, so a folder removed
# together with its marker is still governed by the profile that marker named.
$profileChanges = @($changes | ForEach-Object { if ($_.Path -match $governancePattern) { $_.Path }; if ($_.OldPath -and $_.OldPath -match $governancePattern) { $_.OldPath } } | Select-Object -Unique)
if ($profileChanges.Count) {
    $more = if ($profileChanges.Count -gt 1) { " and $($profileChanges.Count - 1) more" } else { '' }
    $facts.Add([pscustomobject]@{ Detector = 'structural-check'; Kind = 'profile-changed'; Units = @($profileChanges); Paths = @($profileChanges); Evidence = "the fix changed $($profileChanges.Count) architecture profile file(s): $($profileChanges[0])$more"; Expected = $false; Requires = @(); Blocked = @() })
    $startMarkers = @{}
    try {
        foreach ($m in @(Get-TreePaths $repoFull $base | Where-Object { $_ -match $markerPattern })) {
            $data = ConvertFrom-CognivaYaml @(([string](Get-TreeFileText $repoFull $base $m)) -split "`r?`n") "$m (at start)"
            if ($data['profile'] -isnot [string]) { Throw-ProfileError "$m (at start): 'profile' must be a single profile id" }
            Assert-ProfileId $data['profile'] "$m (at start)" -AllowNone
            $startMarkers[(Get-Folder $m)] = $data['profile']
        }
    }
    catch { $failures.Add("the profile markers at the start could not be read: $(Get-StructureErrorText $_)"); Finish 'FAILED' 'the profile markers at the start could not be read' }
}

# Detectors: every profile a marker declares now, plus every profile a marker
# named at the start. A change in one folder can affect units below it.
$declaredIds = [System.Collections.Generic.List[string]]::new()
foreach ($m in @(Get-TreePaths $repoFull $head | Where-Object { $_ -match $markerPattern })) {
    $t = Resolve-Now $m
    if ($t.Status -eq 'ERROR') {
        $msg = "profile declared by $m could not be resolved: $($t.Error)"
        if (-not $failures.Contains($msg)) { $failures.Add($msg) }
    }
    elseif ($t.Status -eq 'RESOLVED' -and -not $declaredIds.Contains($t.Profile)) { $declaredIds.Add($t.Profile) }
}
if ($startMarkers) {
    foreach ($dir in @($startMarkers.Keys)) {
        $id = $startMarkers[$dir]
        if ($id -ceq 'none' -or $declaredIds.Contains($id)) { continue }
        $origin = if ($dir -eq '.') { '.cogniva-profile.yml (at start)' } else { "$dir/.cogniva-profile.yml (at start)" }
        $result = Get-ContextProfileResult $ctx $id $origin
        if ($result.Error) { $failures.Add("profile '$id', declared at the start by $origin, cannot be resolved now: $($result.Error)") }
        else { $declaredIds.Add($id) }
    }
}
$detectorIds = [System.Collections.Generic.List[string]]::new()
$detectorProfiles = @{}
foreach ($id in $declaredIds) {
    foreach ($d in $ctx.Results[$id].Structure.Detectors) {
        if (-not $detectorIds.Contains($d)) { $detectorIds.Add($d); $detectorProfiles[$d] = @() }
        if ($detectorProfiles[$d] -notcontains $id) { $detectorProfiles[$d] += $id }
    }
}
if (-not $detectorIds.Count) {
    if ($failures.Count) { Finish 'FAILED' 'a declared architecture profile could not be resolved' }
    $report.Facts = @($facts)
    if ($facts.Count) { Finish 'FOUND' 'the fix changed architecture profile files; no profile selects a structure detector' }
    if (-not $declaredIds.Count) { Finish 'NOT-CHECKED' 'no architecture profile is declared in the repository' }
    Finish 'NOT-CHECKED' "profile $($declaredIds -join ', ') selects no structure detector"
}

$pwshPath = [System.Environment]::ProcessPath
foreach ($d in $detectorIds) {
    $entry = [ordered]@{ Id = $d; Profiles = @($detectorProfiles[$d]); Status = 'ok'; Facts = 0; Reason = $null }
    $detectorFile = Join-Path $DetectorRoot "$d.ps1"
    try {
        if (-not (Test-Path -LiteralPath $detectorFile -PathType Leaf)) { throw [System.InvalidOperationException]::new("StructureError: detector '$d' (selected by profile $($entry.Profiles -join ', ')) is not in $DetectorRoot") }
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $lines = @(& $pwshPath -NoProfile -File $detectorFile -Repo $repoFull -Base $base -Head $head 2>&1)
            $code = $LASTEXITCODE
        }
        finally { $ErrorActionPreference = $previous }
        $stdout = (@($lines | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ }) -join "`n")
        $stderr = (@($lines | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ }) -join ' ').Trim()
        if ($code -ne 0) { throw [System.InvalidOperationException]::new("StructureError: detector '$d' exited $code$(if ($stderr) { ": $stderr" })") }
        $json = $null
        try { $json = $stdout | ConvertFrom-Json } catch { $json = $null }
        $problem = Test-DetectorReport $json $d
        if ($problem) { throw [System.InvalidOperationException]::new("StructureError: detector '$d' broke its contract: $problem") }
        foreach ($f in @($json.facts)) {
            $facts.Add([pscustomobject]@{ Detector = $d; Kind = $f.kind; Units = @($f.units); Paths = @($f.paths); Evidence = $f.evidence; Expected = $false; Requires = @(); Blocked = @() })
        }
        $entry.Facts = @($json.facts).Count
    }
    catch {
        $entry.Status = 'failed'
        $entry.Reason = Get-StructureErrorText $_
        $failures.Add($entry.Reason)
    }
    $report.Detectors += [pscustomobject]$entry
}

# Each fact is governed by the profile each of its paths has now, plus the
# profile its marker named at the start. What those profiles require, and the
# review state of those standards, always comes from the profiles as they are
# now, so adding a missing standard or accepting a reviewed amendment clears a
# block on re-check (and the profile-changed fact asks the user to OK the edit).
foreach ($f in $facts) {
    if ($f.Kind -eq 'profile-changed') { continue }
    $f.Expected = Test-Expected $f
    $when = [ordered]@{}
    $targets = @()
    foreach ($p in $f.Paths) {
        $t = Resolve-Now $p
        if ($t.Status -eq 'RESOLVED' -and -not $when.Contains($t.Profile)) { $when[$t.Profile] = 'now'; $targets += $t }
    }
    foreach ($p in $f.Paths) {
        $id = Get-StartProfile $p
        if (-not $id -or $when.Contains($id)) { continue }
        if ((Get-ContextProfileResult $ctx $id 'a marker at the start').Error) { continue }
        $when[$id] = 'start'
        $targets += [pscustomobject]@{ Target = $p; Status = 'RESOLVED'; Profile = $id }
    }
    $gate = Get-RequireResult $ctx $targets @() @($f.Kind)
    $f.Requires = @($gate.ByTarget | ForEach-Object { [pscustomobject]@{ Profile = $_.Profile; When = $when[$_.Profile]; Standards = @($_.Standards) } })
    $f.Blocked = @($gate.Blocked | ForEach-Object { [pscustomobject]@{ Target = $_.Target; Profile = $_.Profile; Standard = $_.Standard; Reason = $_.Reason; When = $when[$_.Profile] } })
}
$report.Facts = @($facts)

if ($failures.Count) { Finish 'FAILED' "$($failures.Count) part(s) of the check could not run" }
if (@($facts | Where-Object { @($_.Blocked).Count }).Count) { Finish 'BLOCKED' 'a standard these changes require is missing or needs human review' }
if ($facts.Count) { Finish 'FOUND' "$($facts.Count) structural change(s) since the start" }
Finish 'NONE' "detectors ran: $($detectorIds -join ', ')"
