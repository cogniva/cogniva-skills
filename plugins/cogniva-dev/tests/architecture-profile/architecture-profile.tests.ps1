#Requires -Version 7.0
# Dependency-free tests for architecture-profile resolution, inheritance,
# suggestions, adoption, and the shipped profile library.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$resolver = Join-Path $plugin 'scripts\resolve-architecture-profile.ps1'
$adopter = Join-Path $plugin 'scripts\adopt-architecture-profile.ps1'
$accepter = Join-Path $plugin 'scripts\accept-profile-delta.ps1'
$shippedLibrary = Join-Path $plugin 'profiles'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-architecture-profile-" + [guid]::NewGuid().ToString('N'))
$failures = @()
. (Join-Path $plugin 'scripts\profile-lib.ps1')

function Check($label, $condition) {
    if ($condition) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}
function Write-Fixture([string]$Base, [string]$Relative, [string]$Text) {
    $path = Join-Path $Base $Relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    [System.IO.File]::WriteAllText($path, $Text.Replace("`r`n", "`n"))
}
function Invoke-Script([string]$Script, [string[]]$Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = @(& pwsh -NoProfile -File $Script @Arguments 2>&1)
        $code = $LASTEXITCODE
        $stdout = @($lines | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
        $all = @($lines | ForEach-Object { [string]$_ })
    }
    finally { $ErrorActionPreference = $previous }
    [pscustomobject]@{ Code = $code; Out = ($stdout -join "`n"); All = ($all -join "`n") }
}
# Exit 0, 1 and 3 carry a JSON report (1 = some target is ERROR, 3 = a -Require standard is blocked); exit 2 carries none.
function Resolve-Json([string]$Repo, [string[]]$Extra) {
    $result = Invoke-Script $resolver (@('-Repo', $Repo, '-Format', 'Json', '-LibraryRoot', $script:library) + $Extra)
    $json = if ($result.Code -in 0, 1, 3) { $result.Out | ConvertFrom-Json } else { $null }
    [pscustomobject]@{ Code = $result.Code; Json = $json; All = $result.All; Raw = $result.Out }
}
function Test-TargetError($Result, [string]$Pattern) {
    return ($Result.Code -eq 1 -and $Result.Json.Targets[0].Status -eq 'ERROR' -and $Result.Json.Targets[0].Error -match $Pattern -and $Result.Json.Aggregate.Status -eq 'ERROR')
}
function New-Repo([string]$Name) {
    $repo = Join-Path $root $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    & git -C $repo init -q
    return $repo
}
function Add-Profile([string]$Repo, [string]$Id, [string]$Yaml, [hashtable]$Standards) {
    Write-Fixture $Repo ".cogniva/profiles/$Id/profile.yml" $Yaml
    foreach ($key in $Standards.Keys) {
        $relative = if ($key -match '^(amendments|replacements)/') { $key } else { "standards/$key" }
        Write-Fixture $Repo ".cogniva/profiles/$Id/$relative" $Standards[$key]
    }
}
function Std([string]$Description) { return "---`ndescription: $Description`n---`n`n# Body`n" }
function Delta([string]$Description, [string]$Basis, [string[]]$AppliesTo, [string]$Body = '# Delta body') {
    $fm = "---`ndescription: $Description`n"
    if ($Basis) { $fm += "basis: $Basis`n" }
    if ($AppliesTo) { $fm += "applies-to:`n" + (($AppliesTo | ForEach-Object { "  - `"$_`"" }) -join "`n") + "`n" }
    return "$fm---`n`n$Body`n"
}
function Basis([string[]]$Texts) { return Get-TextHash ((@($Texts | ForEach-Object { Get-NormalisedText $_ })) -join "`n") }

try {
    # Fixture library: used for suggestions, hints, and adoption.
    $script:library = Join-Path $root 'library'
    Write-Fixture $library 'base/profile.yml' "description: Base fixture.`n"
    Write-Fixture $library 'base/standards/architecture/owner.md' (Std 'Base owner rule.')
    Write-Fixture $library 'python/profile.yml' "description: Python fixture.`ninherits: base`ndetect:`n  - `"pyproject.toml`"`n"
    Write-Fixture $library 'python/standards/python/layout.md' (Std 'Python layout rule.')
    Write-Fixture $library 'dotnet/profile.yml' "description: Dotnet fixture.`ninherits: base`ndetect:`n  - `"*.slnx`"`n"
    # 'none' is reserved for markers, so a library folder by that name must never be suggested.
    Write-Fixture $library 'none/profile.yml' "description: Reserved name.`ndetect:`n  - `"*.slnx`"`n"

    # --- precedence ----------------------------------------------------------
    $repo = New-Repo 'precedence'
    Add-Profile $repo 'base' "description: Base.`n" @{ 'architecture/owner.md' = (Std 'Base owner.'); 'architecture/shared.md' = (Std 'Base shared.') }
    Add-Profile $repo 'python' "description: Python.`ninherits: base`n" @{ 'amendments/architecture/owner.md' = (Delta 'Python owner.' (Basis @((Std 'Base owner.')))); 'python/layout.md' = (Std 'Python layout.') }
    Add-Profile $repo 'dotnet' "description: Dotnet.`ninherits: base`n" @{ 'dotnet/modules.md' = (Std 'Dotnet modules.') }
    Write-Fixture $repo '.cogniva-profile.yml' "profile: dotnet`n"
    Write-Fixture $repo 'tools/.cogniva-profile.yml' "# Python tooling`nprofile: python`n"
    Write-Fixture $repo 'docs/.cogniva-profile.yml' "profile: none`n"
    Write-Fixture $repo 'src/Orders/Order.cs' "class Order {}`n"
    Write-Fixture $repo 'tools/ingest/run.py' "print(1)`n"
    $before = @(& git -C $repo status --porcelain)

    $r = Resolve-Json $repo @('-Target', 'src/Orders/Order.cs')
    $t = $r.Json.Targets[0]
    Check 'root marker resolves as repo-default' ($r.Code -eq 0 -and $t.Status -eq 'RESOLVED' -and $t.Profile -eq 'dotnet' -and $t.Winner.Kind -eq 'repo-default' -and $t.Winner.Source -eq '.cogniva-profile.yml')

    $r = Resolve-Json $repo @('-Target', 'tools/ingest/run.py,src/Orders')
    $py = $r.Json.Targets[0]
    Check 'nearest marker wins as path-override' ($py.Profile -eq 'python' -and $py.Winner.Kind -eq 'path-override' -and $py.Winner.Source -eq 'tools/.cogniva-profile.yml')
    Check 'broader marker is recorded as shadowed' (@($py.Considered | Where-Object { $_.Outcome -eq 'shadowed' -and $_.Source -eq '.cogniva-profile.yml' -and $_.Profile -eq 'dotnet' }).Count -eq 1)
    Check 'sibling target falls back to the repo default' ($r.Json.Targets[1].Profile -eq 'dotnet')
    Check 'targets on different profiles aggregate as MIXED' ($r.Code -eq 0 -and $r.Json.Aggregate.Status -eq 'MIXED' -and @($r.Json.Aggregate.Groups.python) -contains 'tools/ingest/run.py' -and @($r.Json.Aggregate.Groups.dotnet) -contains 'src/Orders')

    $r = Resolve-Json $repo @('-Target', 'tools/new-tool/not-yet-created.py')
    Check 'a target that does not exist yet resolves through its nearest existing parent' ($r.Json.Targets[0].Profile -eq 'python')

    $r = Resolve-Json $repo @('-Target', 'tools/ingest/run.py', '-Profile', 'dotnet')
    $t = $r.Json.Targets[0]
    Check 'explicit -Profile beats every marker' ($t.Profile -eq 'dotnet' -and $t.Winner.Kind -eq 'explicit')
    Check 'explicit choice records the markers it overrode' (@($t.Considered | Where-Object Outcome -eq 'overridden-by-explicit').Count -eq 2)

    $r = Resolve-Json $repo @('-Target', 'docs/guide.md')
    Check "'profile: none' clears the profile for its subtree" ($r.Json.Targets[0].Status -eq 'NONE' -and $null -eq $r.Json.Targets[0].Profile)

    $r = Resolve-Json $repo @('-Target', 'src/Orders,src/Orders/Order.cs')
    Check 'targets on one profile aggregate as UNIFORM' ($r.Json.Aggregate.Status -eq 'UNIFORM')

    # --- inheritance and the standards index ---------------------------------
    $r = Resolve-Json $repo @('-Target', 'tools')
    $p = $r.Json.Profiles.python
    $owner = @($p.Standards | Where-Object { $_.Id -ieq 'architecture/owner.md' })
    Check 'chain lists child first' (($p.Chain -join '>') -eq 'python>base')
    Check 'an amendment composes onto the inherited standard' ($owner.Count -eq 1 -and $owner[0].From -eq 'base' -and @($owner[0].Amendments).Count -eq 1 -and $owner[0].Amendments[0].From -eq 'python' -and $owner[0].Amendments[0].State -eq 'CURRENT')
    Check 'parent-only standards are inherited' (@($p.Standards | Where-Object { $_.Id -eq 'architecture/shared.md' -and $_.From -eq 'base' }).Count -eq 1)
    Check 'index carries descriptions, not bodies' (-not ($r.Raw -match '# Body'))
    Check 'standards are ordered by id' ((@($p.Standards.Id) -join '|') -eq (@($p.Standards.Id | Sort-Object { $_.ToLowerInvariant() }) -join '|'))

    $again = Resolve-Json $repo @('-Target', 'tools')
    Check 'resolution is deterministic' ($again.Raw -eq $r.Raw)
    $after = @(& git -C $repo status --porcelain)
    Check 'resolver leaves the repository unchanged' (($before -join "`n") -eq ($after -join "`n"))

    $text = Invoke-Script $resolver @('-Repo', $repo, '-Target', 'tools/ingest/run.py', '-LibraryRoot', $library)
    Check 'text output explains the winner and the shadowed marker' ($text.Out -match 'PROFILE: python \(path-override: tools/\.cogniva-profile\.yml\)' -and $text.Out -match 'SHADOWED: \.cogniva-profile\.yml -> dotnet')

    # --- deltas: amendments, replacements, basis and review state -------------
    Check 'normalisation: CRLF, trailing whitespace, trailing blank lines' ((Get-NormalisedText "a  `r`nb`r`n`r`n") -ceq "a`nb")
    Check 'normalisation: BOM and lone CR' ((Get-NormalisedText ([string][char]0xFEFF + "a`rb")) -ceq "a`nb")
    Check 'normalisation drops basis: lines' ((Get-NormalisedText "description: x`nbasis: 0123456789ab`ny") -ceq "description: x`ny")
    Check 'basis is 12 lowercase hex characters' ((Get-TextHash 'x') -cmatch '^[0-9a-f]{12}$')
    Check 'glob ** matches zero segments' (Test-GlobMatch 'src/Hosts/**' 'src/Hosts')
    Check 'glob ** matches several segments' (Test-GlobMatch 'src/Hosts/**' 'src/Hosts/Web/Program.cs')
    Check 'glob * stays within one segment' (-not (Test-GlobMatch 'src/*/x' 'src/a/b/x'))
    Check 'glob segment patterns match' (Test-GlobMatch 'src/Modules/*/*.Contracts/**' 'src/Modules/Orders/Orders.Contracts/IOrders.cs')
    Check 'glob does not match a longer segment name' (-not (Test-GlobMatch 'src/Hosts/**' 'src/HostsX/a.cs'))

    $d = New-Repo 'deltas'
    $baseOwner = Std 'Base owner.'
    $baseEdges = Std 'Base edges.'
    Add-Profile $d 'base' "description: Base.`n" @{ 'architecture/owner.md' = $baseOwner; 'architecture/edges.md' = $baseEdges }
    $midOwner = Delta 'Mid narrows owner.' (Basis @($baseOwner)) @('src/Hosts/**')
    $midEdges = Delta 'Mid edges.' (Basis @($baseEdges))
    Add-Profile $d 'mid' "description: Mid.`ninherits: base`n" @{ 'amendments/architecture/owner.md' = $midOwner; 'replacements/architecture/edges.md' = $midEdges }
    $leafOwner = Delta 'Leaf adds to owner.' (Basis @($baseOwner, $midOwner))
    Add-Profile $d 'leaf' "description: Leaf.`ninherits: mid`n" @{ 'amendments/architecture/owner.md' = $leafOwner; 'amendments/architecture/edges.md' = (Delta 'Leaf on mid edges.' (Basis @($midEdges))); 'leaf/own.md' = (Std 'Leaf own.') }
    Write-Fixture $d '.cogniva-profile.yml' "profile: leaf`n"
    Write-Fixture $d 'tools/.cogniva-profile.yml' "profile: base`n"
    $dBefore = @(& git -C $d status --porcelain)

    $r = Resolve-Json $d @('-Target', 'src/Hosts/Web/Program.cs,src/Lib/x.cs,tools/t.py')
    $leaf = $r.Json.Profiles.leaf
    $owner = @($leaf.Standards | Where-Object Id -eq 'architecture/owner.md')[0]
    $edges = @($leaf.Standards | Where-Object Id -eq 'architecture/edges.md')[0]
    Check 'three-level amendments compose root first' ($r.Code -eq 0 -and $owner.From -eq 'base' -and (@($owner.Amendments.From) -join '>') -eq 'mid>leaf' -and @($owner.Amendments | Where-Object State -ne 'CURRENT').Count -eq 0)
    Check 'the most-derived applies-to wins' ((@($owner.AppliesTo) -join ',') -eq 'src/Hosts/**')
    Check 'a replacement supersedes the inherited standard' ($edges.From -eq 'mid' -and $edges.ReplacedBy -eq 'mid' -and @($edges.Overrides) -contains 'base' -and @($edges.Amendments).Count -eq 1 -and $edges.Amendments[0].State -eq 'CURRENT')
    Check 'a current profile needs no review' ($r.Json.Targets[0].NeedsReview -eq $false -and @($leaf.Review).Count -eq 0)
    Check 'MatchedStandards lists only applies-to matches' ((@($r.Json.Targets[0].MatchedStandards) -join ',') -eq 'architecture/owner.md' -and @($r.Json.Targets[1].MatchedStandards).Count -eq 0)
    Check 'ChainDetail carries ownership' ((@($leaf.ChainDetail | ForEach-Object { "$($_.Id)=$($_.Ownership)" }) -join ',') -eq 'leaf=repo-owned,mid=repo-owned,base=repo-owned')
    Check 'a subtree marker resolves its own chain' ($r.Json.Targets[2].Profile -eq 'base' -and @(@($r.Json.Profiles.base.Standards | Where-Object Id -eq 'architecture/owner.md')[0].Amendments).Count -eq 0)
    $text = Invoke-Script $resolver @('-Repo', $d, '-Target', 'src/Hosts/Web/Program.cs', '-LibraryRoot', $library)
    Check 'text output flags a replacement' ($text.Out -match 'REPLACED - no longer receives base updates')
    Check 'text output lists amendments with ownership and state' ($text.Out -match 'AMENDED BY mid \(repo-owned, CURRENT\)' -and $text.Out -match 'AMENDED BY leaf \(repo-owned, CURRENT\)')
    Check 'index still carries descriptions, not bodies' (-not ($r.Raw -match '# Delta body'))
    $again = Resolve-Json $d @('-Target', 'src/Hosts/Web/Program.cs,src/Lib/x.cs,tools/t.py')
    Check 'delta resolution is deterministic' ($again.Raw -eq $r.Raw)

    Write-Fixture $d '.cogniva/profiles/mid/amendments/architecture/owner.md' ([string][char]0xFEFF + $midOwner.Replace("`n", "  `r`n"))
    $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs')
    Check 'BOM, CRLF and trailing whitespace keep a delta CURRENT' (@(@($r.Json.Profiles.leaf.Standards | Where-Object Id -eq 'architecture/owner.md')[0].Amendments | Where-Object State -ne 'CURRENT').Count -eq 0)

    Write-Fixture $d '.cogniva/profiles/base/standards/architecture/owner.md' (Std 'Base owner, changed.')
    $r = Resolve-Json $d @('-Target', 'src/Hosts/Web/Program.cs')
    $owner = @($r.Json.Profiles.leaf.Standards | Where-Object Id -eq 'architecture/owner.md')[0]
    Check 'a changed parent makes every delta below it STALE' ((@($owner.Amendments.State) -join ',') -eq 'STALE,STALE')
    Check 'STALE stays RESOLVED and marks the target and standard' ($r.Code -eq 0 -and $r.Json.Targets[0].Status -eq 'RESOLVED' -and $r.Json.Targets[0].NeedsReview -eq $true -and $owner.NeedsReview -eq $true)
    $item = @($r.Json.Profiles.leaf.Review | Where-Object Profile -eq 'mid')[0]
    Check 'a Review entry names profile, ownership, delta and both bases' ($item.Standard -eq 'architecture/owner.md' -and $item.Ownership -eq 'repo-owned' -and $item.Delta -eq 'amendment' -and $item.State -eq 'STALE' -and $item.Basis -eq (Basis @($baseOwner)) -and $item.Inherited -eq (Basis @((Std 'Base owner, changed.'))))
    $text = Invoke-Script $resolver @('-Repo', $d, '-Target', 'src/Hosts/Web/Program.cs', '-LibraryRoot', $library)
    Check 'text output says NEEDS HUMAN REVIEW under the profile line' ($text.Out -match "PROFILE: leaf[^`n]*`n  NEEDS HUMAN REVIEW" -and $text.Out -match 'REVIEW: architecture/owner\.md - mid \(repo-owned\) amendment is STALE')
    Write-Fixture $d '.cogniva/profiles/base/standards/architecture/owner.md' $baseOwner

    Write-Fixture $d '.cogniva/profiles/mid/amendments/architecture/owner.md' ($midOwner -replace 'basis: [0-9a-f]{12}', 'basis: ffffffffffff')
    $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs')
    $owner = @($r.Json.Profiles.leaf.Standards | Where-Object Id -eq 'architecture/owner.md')[0]
    Check "editing an ancestor's basis line does not make descendants STALE" ((@($owner.Amendments.State) -join ',') -eq 'STALE,CURRENT')
    Write-Fixture $d '.cogniva/profiles/mid/amendments/architecture/owner.md' $midOwner

    Write-Fixture $d '.cogniva/profiles/leaf/amendments/architecture/owner.md' (Delta 'Leaf adds to owner.' $null)
    Write-Fixture $d '.cogniva/profiles/leaf/amendments/architecture/missing.md' (Delta 'Amends nothing.' 'aaaaaaaaaaaa')
    $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs')
    $states = @($r.Json.Profiles.leaf.Review | ForEach-Object { "$($_.Standard)=$($_.State)" }) -join ','
    Check 'no basis is UNREVIEWED and a vanished target is ORPHANED; both stay RESOLVED' ($r.Code -eq 0 -and $r.Json.Targets[0].Status -eq 'RESOLVED' -and $states -match 'architecture/owner\.md=UNREVIEWED' -and $states -match 'architecture/missing\.md=ORPHANED')
    Check 'an ORPHANED amendment still appears as a standard' (@($r.Json.Profiles.leaf.Standards | Where-Object Id -eq 'architecture/missing.md').Count -eq 1)
    Remove-Item -LiteralPath (Join-Path $d '.cogniva/profiles/leaf/amendments/architecture/missing.md')
    Write-Fixture $d '.cogniva/profiles/leaf/amendments/architecture/owner.md' $leafOwner

    Write-Fixture $d '.cogniva/adopted/base.yml' "source: plugin-library/base`nplugin-version: 0.0.0`ncontent: aaaaaaaaaaaa`n"
    $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs')
    Check 'an adoption record makes a profile library-owned' ((@($r.Json.Profiles.leaf.ChainDetail | Where-Object Id -eq 'base')[0].Ownership) -eq 'library')
    Remove-Item -LiteralPath (Join-Path $d '.cogniva/adopted') -Recurse -Force

    $dAfter = @(& git -C $d status --porcelain)
    Check 'delta resolution leaves the repository unchanged' (($dBefore -join "`n") -eq ($dAfter -join "`n"))

    Write-Fixture $d '.cogniva/profiles/leaf/standards/architecture/owner.md' (Std 'Same id.')
    $r = Resolve-Json $d @('-Target', 'x')
    Check 'a same-id file in standards/ is an ambiguous ERROR pointing at amendments/ and replacements/' (Test-TargetError $r 'ambiguous.*amendments/architecture/owner\.md.*replacements/architecture/owner\.md')
    Remove-Item -LiteralPath (Join-Path $d '.cogniva/profiles/leaf/standards/architecture/owner.md')
    Write-Fixture $d '.cogniva/profiles/leaf/replacements/architecture/owner.md' (Delta 'Also replaces.' 'aaaaaaaaaaaa')
    $r = Resolve-Json $d @('-Target', 'x')
    Check 'amending and replacing one id in one profile is an ERROR' (Test-TargetError $r 'both amends and replaces')
    Remove-Item -LiteralPath (Join-Path $d '.cogniva/profiles/leaf/replacements') -Recurse -Force
    Write-Fixture $d '.cogniva/profiles/leaf/amendments/leaf/own.md' (Delta 'Own.' 'aaaaaaaaaaaa')
    $r = Resolve-Json $d @('-Target', 'x')
    Check "amending the profile's own standard is an ERROR" (Test-TargetError $r 'edit it there')
    Remove-Item -LiteralPath (Join-Path $d '.cogniva/profiles/leaf/amendments/leaf') -Recurse -Force
    Write-Fixture $d '.cogniva/profiles/leaf/amendments/architecture/edges.md' "# no frontmatter`n"
    $r = Resolve-Json $d @('-Target', 'x')
    Check 'an amendment without a description is an ERROR' (Test-TargetError $r "amendments/architecture/edges\.md: missing frontmatter 'description'")
    Write-Fixture $d '.cogniva/profiles/leaf/amendments/architecture/edges.md' (Delta 'Bad basis.' 'XYZ')
    $r = Resolve-Json $d @('-Target', 'x')
    Check 'a malformed basis is an ERROR' (Test-TargetError $r "'basis' must be 12 lowercase hex characters")
    Write-Fixture $d '.cogniva/profiles/leaf/amendments/architecture/edges.md' (Delta 'Leaf on mid edges.' (Basis @($midEdges)))

    # --- -Show and -Require ----------------------------------------------------
    $show = Invoke-Script $resolver @('-Repo', $d, '-Target', 'src/Lib/x.cs', '-Show', 'architecture/owner.md', '-LibraryRoot', $library)
    $iBase = $show.Out.IndexOf('--- standard from base (repo-owned): .cogniva/profiles/base/standards/architecture/owner.md')
    $iMid = $show.Out.IndexOf('--- amendment from mid (repo-owned, CURRENT): .cogniva/profiles/mid/amendments/architecture/owner.md')
    $iLeaf = $show.Out.IndexOf('--- amendment from leaf (repo-owned, CURRENT): .cogniva/profiles/leaf/amendments/architecture/owner.md')
    Check '-Show prints each part with provenance, root first' ($show.Code -eq 0 -and $iBase -ge 0 -and $iMid -gt $iBase -and $iLeaf -gt $iMid -and $show.Out -match '# Delta body')
    $show = Invoke-Script $resolver @('-Repo', $d, '-Target', 'src/Lib/x.cs', '-Show', 'architecture/nope.md', '-LibraryRoot', $library)
    Check '-Show of an unknown standard is a usage error' ($show.Code -eq 2)
    $show = Invoke-Script $resolver @('-Repo', $d, '-Target', 'src/Lib/x.cs', '-Show', 'architecture/owner.md', '-Format', 'Json', '-LibraryRoot', $library)
    Check '-Show does not combine with -Format Json' ($show.Code -eq 2)

    Write-Fixture $d '.cogniva/profiles/base/standards/architecture/owner.md' (Std 'Base owner, changed again.')
    $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs', '-Require', 'architecture/edges.md')
    Check '-Require passes when only an unrelated standard is stale' ($r.Code -eq 0 -and @($r.Json.Require.Blocked).Count -eq 0)
    $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs', '-Require', 'architecture/edges.md,architecture/owner.md')
    Check '-Require exits 3 naming the required standard that needs review' ($r.Code -eq 3 -and @($r.Json.Require.Blocked).Count -eq 1 -and $r.Json.Require.Blocked[0].Standard -eq 'architecture/owner.md' -and $r.Json.Require.Blocked[0].Reason -match 'needs human review')
    $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs', '-Require', 'architecture/nope.md')
    Check '-Require exits 3 for a standard the profile lacks' ($r.Code -eq 3 -and $r.Json.Require.Blocked[0].Reason -match "not in profile 'leaf'")
    $text = Invoke-Script $resolver @('-Repo', $d, '-Target', 'src/Lib/x.cs', '-Require', 'architecture/owner.md', '-LibraryRoot', $library)
    Check '-Require text output names the blocked standard' ($text.Code -eq 3 -and $text.Out -match 'REQUIRE BLOCKED: src/Lib/x\.cs architecture/owner\.md')
    Write-Fixture $d '.cogniva/profiles/base/standards/architecture/owner.md' $baseOwner

    # --- accept-profile-delta --------------------------------------------------
    $acc = New-Repo 'accept'
    $accBase = Std 'Acc base.'
    Add-Profile $acc 'base' "description: Base.`n" @{ 'architecture/a.md' = $accBase; 'architecture/b.md' = (Std 'Acc b.') }
    Add-Profile $acc 'kid' "description: Kid.`ninherits: base`n" @{ 'amendments/architecture/a.md' = (Delta 'Kid a.' (Basis @($accBase))); 'amendments/architecture/b.md' = (Delta 'Kid b.' $null) }
    $kidA = Join-Path $acc '.cogniva/profiles/kid/amendments/architecture/a.md'
    $kidB = Join-Path $acc '.cogniva/profiles/kid/amendments/architecture/b.md'
    [System.IO.File]::WriteAllText($kidA, ([System.IO.File]::ReadAllText($kidA)).Replace("`n", "`r`n"))
    Write-Fixture $acc '.cogniva/profiles/base/standards/architecture/a.md' (Std 'Acc base, changed.')
    $linesBefore = @([System.IO.File]::ReadAllLines($kidA) | Where-Object { $_ -notmatch '^basis:' })
    $x = Invoke-Script $accepter @('-Repo', $acc, '-Profile', 'kid', '-Standard', 'architecture/a.md')
    Check 'accept -Standard rewrites only that basis line' ($x.Code -eq 0 -and $x.Out -match 'ACCEPTED: \.cogniva/profiles/kid/amendments/architecture/a\.md basis [0-9a-f]{12} -> ' -and (($linesBefore -join '|') -eq ((@([System.IO.File]::ReadAllLines($kidA) | Where-Object { $_ -notmatch '^basis:' })) -join '|')))
    Check 'accept preserves CRLF line endings' (([System.IO.File]::ReadAllText($kidA)).Contains("`r`n"))
    Check 'accept -Standard leaves other deltas alone' (-not ((Get-Content -Raw $kidB) -match 'basis:'))
    Write-Fixture $acc '.cogniva-profile.yml' "profile: kid`n"
    $r = Resolve-Json $acc @('-Target', 'x')
    Check 'an accepted delta is CURRENT' ((@($r.Json.Profiles.kid.Review | Where-Object Standard -eq 'architecture/a.md')).Count -eq 0)
    $x = Invoke-Script $accepter @('-Repo', $acc, '-Profile', 'kid', '-All')
    Check 'accept -All inserts a missing basis after description' ($x.Code -eq 0 -and $x.Out -match 'UP-TO-DATE: .*architecture/a\.md' -and (Get-Content $kidB)[2] -match '^basis: [0-9a-f]{12}$')
    $r = Resolve-Json $acc @('-Target', 'x')
    Check 'after accept -All nothing needs review' ($r.Json.Targets[0].NeedsReview -eq $false)
    Write-Fixture $acc '.cogniva/profiles/kid/amendments/architecture/gone.md' (Delta 'Gone.' 'aaaaaaaaaaaa')
    $x = Invoke-Script $accepter @('-Repo', $acc, '-Profile', 'kid', '-All')
    Check 'an ORPHANED delta cannot be accepted' ($x.Code -eq 1 -and $x.Out -match 'ORPHANED: .*architecture/gone\.md')
    Remove-Item -LiteralPath (Join-Path $acc '.cogniva/profiles/kid/amendments/architecture/gone.md')
    $x = Invoke-Script $accepter @('-Repo', $acc, '-Profile', 'kid', '-Standard', 'architecture/zzz.md')
    Check 'accepting an id that is not a delta of the profile is a usage error' ($x.Code -eq 2)
    $x = Invoke-Script $accepter @('-Repo', $acc, '-Profile', 'kid')
    Check 'accept needs -Standard or -All' ($x.Code -eq 2)
    Write-Fixture $acc '.cogniva/adopted/kid.yml' "content: aaaaaaaaaaaa`n"
    $x = Invoke-Script $accepter @('-Repo', $acc, '-Profile', 'kid', '-All')
    Check 'accept refuses an adopted library profile' ($x.Code -eq 2 -and $x.All -match 'library profile')
    Write-Fixture $library 'python/amendments/architecture/owner.md' (Delta 'Library python owner.' $null)
    $x = Invoke-Script $accepter @('-Library', '-LibraryRoot', $library, '-Profile', 'python', '-All')
    Check 'accept -Library updates a plugin library profile for maintainers' ($x.Code -eq 0 -and (Get-Content -Raw (Join-Path $library 'python/amendments/architecture/owner.md')) -match 'basis: [0-9a-f]{12}')
    Remove-Item -LiteralPath (Join-Path $library 'python/amendments') -Recurse -Force

    # --- undeclared repos and suggestions ------------------------------------
    $bare = New-Repo 'undeclared'
    Write-Fixture $bare 'App.slnx' "<Solution />`n"
    Write-Fixture $bare 'tools/py/pyproject.toml' "[project]`n"
    $r = Resolve-Json $bare @('-Target', 'src/Anything.cs')
    $t = $r.Json.Targets[0]
    Check 'no marker leaves the target UNDECLARED with no profile' ($r.Code -eq 0 -and $t.Status -eq 'UNDECLARED' -and $null -eq $t.Profile -and $r.Json.Aggregate.Status -eq 'UNDECLARED')
    Check 'undeclared targets load no standards' (@($r.Json.Profiles.PSObject.Properties).Count -eq 0)
    Check 'suggestion comes from library detect hints' ($t.Suggestion.Status -eq 'SUGGESTED' -and @($t.Suggestion.Profiles) -contains 'dotnet' -and @($t.Suggestion.Evidence) -contains 'App.slnx')
    Check "a library folder named 'none' is never suggested" (@($t.Suggestion.Profiles) -notcontains 'none' -and ($r.Json.Warnings -join "`n") -match "plugin-library/none: 'none' is reserved")
    $r = Resolve-Json $bare @('-Target', 'tools/py/main.py')
    Check 'nearest directory with a hit decides the suggestion' ((@($r.Json.Targets[0].Suggestion.Profiles) -join ',') -eq 'python')
    Write-Fixture $bare 'tools/py/Tool.slnx' "<Solution />`n"
    $r = Resolve-Json $bare @('-Target', 'tools/py/main.py')
    Check 'two profiles detected in one directory is AMBIGUOUS, not a pick' ($r.Json.Targets[0].Suggestion.Status -eq 'AMBIGUOUS' -and @($r.Json.Targets[0].Suggestion.Profiles).Count -eq 2)
    Check 'suggestions never write a marker' (-not (Test-Path (Join-Path $bare '.cogniva-profile.yml')))

    # --- per-target errors (exit 1, the report still lists every target) ------
    $bad = New-Repo 'errors'
    Write-Fixture $bad '.cogniva-profile.yml' "profile: python`n"
    $r = Resolve-Json $bad @('-Target', 'x')
    Check 'marker naming an un-adopted profile is a target ERROR with an adopt hint' ((Test-TargetError $r "\.cogniva-profile\.yml: profile 'python' is not in \.cogniva/profiles") -and $r.Json.Targets[0].Error -match 'adopt-architecture-profile\.ps1 -Profile python')

    Add-Profile $bad 'python' "description: Python.`ninherits: base`n" @{}
    $r = Resolve-Json $bad @('-Target', 'x')
    Check 'missing parent is an ERROR naming the child profile.yml' (Test-TargetError $r "\.cogniva/profiles/python/profile\.yml: profile 'base'")

    Add-Profile $bad 'base' "description: Base.`ninherits: python`n" @{}
    $r = Resolve-Json $bad @('-Target', 'x')
    Check 'inheritance cycle is an ERROR' (Test-TargetError $r 'inheritance cycle: python -> base -> python')

    Add-Profile $bad 'base' "description: Base.`n" @{}
    Write-Fixture $bad '.cogniva/profiles/base/standards/a/Rule.md' (Std 'One.')
    Write-Fixture $bad '.cogniva/profiles/base/standards/a/rule.md' (Std 'Two.')
    $r = Resolve-Json $bad @('-Target', 'x')
    if ((Get-ChildItem -LiteralPath (Join-Path $bad '.cogniva/profiles/base/standards/a') -File).Count -eq 2) {
        Check 'case-variant standard paths inside one profile are an ERROR' (Test-TargetError $r 'collides with')
    }
    else { Write-Host '  SKIP  case-variant collision (case-insensitive file system merged the fixtures)' }
    Remove-Item -LiteralPath (Join-Path $bad '.cogniva/profiles/base/standards') -Recurse -Force

    $yamlCases = [ordered]@{
        'tab indentation'  = "description: Base.`ndetect:`n`t- `"x`"`n"
        'flow list'        = "description: Base.`ndetect: [a, b]`n"
        'nested map'       = "description: Base.`nextra:`n  key: value`n"
        'duplicate key'    = "description: Base.`ndescription: Again.`n"
        'unknown key'      = "description: Base.`nchecks: build`n"
        'missing required' = "inherits: python`n"
        'unquoted alias'   = "description: Base.`ndetect:`n  - *.slnx`n"
    }
    foreach ($case in $yamlCases.Keys) {
        Write-Fixture $bad '.cogniva/profiles/base/profile.yml' $yamlCases[$case]
        $r = Resolve-Json $bad @('-Target', 'x')
        Check "strict YAML subset rejects: $case" (Test-TargetError $r '\.cogniva/profiles/base/profile\.yml')
    }
    Write-Fixture $bad '.cogniva/profiles/base/profile.yml' "description: 'Quoted # not a comment' # trailing comment`n"
    Write-Fixture $bad '.cogniva/profiles/base/standards/extra-key.md' "---`ndescription: Has an extra key.`nowner: someone`n---`n"
    Write-Fixture $bad '.cogniva-profile.yml' "profile: base`n"
    $r = Resolve-Json $bad @('-Target', 'x')
    Check 'quoted values keep # and trailing comments are dropped' ($r.Code -eq 0 -and $r.Json.Profiles.base.Description -eq 'Quoted # not a comment')
    Check 'extra frontmatter keys are ignored with a warning' (@($r.Json.Profiles.base.Standards | Where-Object Id -eq 'extra-key.md').Count -eq 1 -and ($r.Json.Warnings -join "`n") -match "extra-key\.md: frontmatter key 'owner' is ignored")
    Write-Fixture $bad '.cogniva/profiles/base/standards/no-description.md' "# No frontmatter`n"
    $r = Resolve-Json $bad @('-Target', 'x')
    Check 'a standard without a description is an ERROR' (Test-TargetError $r "no-description\.md: missing frontmatter 'description'")
    Remove-Item -LiteralPath (Join-Path $bad '.cogniva/profiles/base/standards/no-description.md')

    $r = Resolve-Json $bad @('-Target', 'x', '-Profile', 'dotnet')
    Check 'explicit -Profile must be adopted too' (Test-TargetError $r "profile 'dotnet' is not in")
    Write-Fixture $bad '.cogniva-profile.yml' "profile: base`nextra: 1`n"
    $r = Resolve-Json $bad @('-Target', 'x')
    Check 'marker rejects unknown keys' (Test-TargetError $r "\.cogniva-profile\.yml: unknown key 'extra'")
    Write-Fixture $bad '.cogniva-profile.yml' "profile: base`n"

    # --- each target resolves independently -----------------------------------
    $split = New-Repo 'independent'
    Add-Profile $split 'good' "description: Good.`n" @{ 'rules/one.md' = (Std 'One.') }
    Add-Profile $split 'broken' "description: Broken.`nchecks: nope`n" @{}
    Write-Fixture $split 'ok/.cogniva-profile.yml' "profile: good`n"
    Write-Fixture $split 'missing/.cogniva-profile.yml' "profile: absent`n"
    Write-Fixture $split 'uses-broken/.cogniva-profile.yml' "profile: broken`n"
    $r = Resolve-Json $split @('-Target', 'ok/a.py,missing/b.py,uses-broken/c.py')
    $states = @($r.Json.Targets | ForEach-Object Status) -join ','
    Check 'one broken target does not poison the others' ($r.Code -eq 1 -and $states -eq 'RESOLVED,ERROR,ERROR' -and $r.Json.Targets[0].Profile -eq 'good' -and @($r.Json.Profiles.good.Standards).Count -eq 1)
    Check 'each ERROR carries its own reason' ($r.Json.Targets[1].Error -match "missing/\.cogniva-profile\.yml: profile 'absent'" -and $r.Json.Targets[2].Error -match "\.cogniva/profiles/broken/profile\.yml: unknown key 'checks'")
    Check 'errors are grouped in the aggregate' ($r.Json.Aggregate.Status -eq 'ERROR' -and @($r.Json.Aggregate.Groups.'(error)').Count -eq 2 -and @($r.Json.Aggregate.Groups.good) -contains 'ok/a.py')
    $r = Resolve-Json $split @('-Target', 'ok/a.py,missing/b.py', '-Require', 'rules/one.md')
    Check '-Require with an ERROR target exits 1, not 3' ($r.Code -eq 1)
    $r = Resolve-Json $split @('-Target', 'ok/a.py')
    Check 'a broken profile nobody uses does not affect resolution' ($r.Code -eq 0 -and $r.Json.Targets[0].Status -eq 'RESOLVED')

    # --- profile ids are validated wherever they are read ----------------------
    $ids = New-Repo 'ids'
    Add-Profile $ids 'base' "description: Base.`n" @{}
    Write-Fixture $ids 'upper/.cogniva-profile.yml' "profile: Base`n"
    Write-Fixture $ids 'bad-parent/.cogniva-profile.yml' "profile: child`n"
    Add-Profile $ids 'child' "description: Child.`ninherits: Base`n" @{}
    $r = Resolve-Json $ids @('-Target', 'upper/x,bad-parent/y')
    Check 'a mixed-case marker value is an ERROR' ($r.Json.Targets[0].Status -eq 'ERROR' -and $r.Json.Targets[0].Error -match "upper/\.cogniva-profile\.yml: 'Base' is not a valid profile id")
    Check 'a mixed-case inherits value is an ERROR' ($r.Json.Targets[1].Status -eq 'ERROR' -and $r.Json.Targets[1].Error -match "'Base' is not a valid profile id")
    $r = Resolve-Json $ids @('-Target', 'upper/x', '-Profile', 'base')
    $t = $r.Json.Targets[0]
    Check 'explicit -Profile also overrides a malformed marker' ($r.Code -eq 0 -and $t.Status -eq 'RESOLVED' -and $t.Profile -eq 'base' -and @($t.Considered | Where-Object { $_.Source -eq 'upper/.cogniva-profile.yml' -and $_.Outcome -eq 'overridden-by-explicit' }).Count -eq 1)
    Check 'the overridden malformed marker is reported as a warning' (($r.Json.Warnings -join "`n") -match "upper/\.cogniva-profile\.yml: 'Base' is not a valid profile id .*overridden by -Profile")
    $r = Resolve-Json $ids @('-Target', 'x', '-Profile', 'Base')
    Check 'a mixed-case -Profile is a usage error' ($r.Code -eq 2 -and $r.All -match "-Profile: 'Base' is not a valid profile id")
    $r = Resolve-Json $ids @('-Target', 'x', '-Profile', 'none')
    Check "'none' is only valid in a marker" ($r.Code -eq 2 -and $r.All -match "'none' is reserved")
    New-Item -ItemType Directory -Path (Join-Path $ids '.cogniva/profiles/Mixed') -Force | Out-Null
    Write-Fixture $ids '.cogniva/profiles/Mixed/profile.yml' "description: Mixed.`n"
    Write-Fixture $ids 'mixed/.cogniva-profile.yml' "profile: mixed`n"
    $r = Resolve-Json $ids @('-Target', 'mixed/x')
    Check 'a profile folder whose name is not lowercase is never used' ($r.Json.Targets[0].Status -eq 'ERROR' -and $r.Json.Targets[0].Error -match 'folder names must be lowercase|is not in')

    # --- repo containment -------------------------------------------------------
    $r = Resolve-Json $bad @('-Target', '..\outside')
    Check 'target outside the repo is a usage error' ($r.Code -eq 2 -and $r.All -match 'outside repo')
    if ($IsLinux) {
        $cased = Join-Path $root 'Cased'
        $sibling = Join-Path $root 'cased'
        New-Item -ItemType Directory -Path $cased, $sibling -Force | Out-Null
        $r = Invoke-Script $resolver @('-Repo', $cased, '-Target', (Join-Path $sibling 'x'), '-LibraryRoot', $library)
        Check 'a sibling differing only by case is outside the repo on a case-sensitive system' ($r.Code -eq 2 -and $r.All -match 'outside repo')
        $r = Invoke-Script (Join-Path $plugin 'scripts\resolve-applicable-rules.ps1') @('-Repo', $cased, '-Target', (Join-Path $sibling 'x'))
        Check 'applicable-rules also treats a case-variant sibling as outside the repo' ($r.Code -eq 2 -and $r.All -match 'outside repo')
    }
    else { Write-Host '  SKIP  case-sensitive containment (runs on Linux only)' }

    # --- adoption --------------------------------------------------------------
    $adopt = New-Repo 'adopt'
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'adopt copies the profile and its whole chain' ($a.Code -eq 0 -and (Test-Path (Join-Path $adopt '.cogniva/profiles/python/standards/python/layout.md')) -and (Test-Path (Join-Path $adopt '.cogniva/profiles/base/profile.yml')))
    Check 'adopt never writes a marker' (-not (Test-Path (Join-Path $adopt '.cogniva-profile.yml')))
    $rec = Join-Path $adopt '.cogniva/adopted/python.yml'
    Check 'adopt writes an adoption record per adopted profile' ((Test-Path $rec) -and (Test-Path (Join-Path $adopt '.cogniva/adopted/base.yml')) -and (Get-Content -Raw $rec) -match '(?m)^source: plugin-library/python$' -and (Get-Content -Raw $rec) -match '(?m)^content: [0-9a-f]{12}$' -and (Get-Content -Raw $rec) -match '(?m)^plugin-version: ')
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 're-adopting an unchanged copy is UP-TO-DATE' ($a.Code -eq 0 -and $a.Out -match 'UP-TO-DATE: python' -and $a.Out -match 'UP-TO-DATE: base')
    $layout = Join-Path $adopt '.cogniva/profiles/python/standards/python/layout.md'
    [System.IO.File]::WriteAllText($layout, ([System.IO.File]::ReadAllText($layout)).Replace("`n", "`r`n"))
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'line-ending-only differences count as up to date' ($a.Code -eq 0 -and $a.Out -match 'UP-TO-DATE: python')
    Add-Content -LiteralPath $layout -Value 'Local edit.'
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'a locally edited copy is LOCALLY-EDITED, blocked, and names the file' ($a.Code -eq 1 -and $a.Out -match 'LOCALLY-EDITED: \.cogniva/profiles/python - standards/python/layout\.md' -and $a.Out -match 'repo-owned profile' -and (Get-Content -Raw $layout) -match 'Local edit')
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library, '-Force')
    Check '-Force replaces the edited copy' ($a.Code -eq 0 -and $a.Out -match 'REPLACED: python' -and -not ((Get-Content -Raw $layout) -match 'Local edit'))
    Check 'a successful replacement leaves no staging or backup folders' (@(Get-ChildItem -LiteralPath (Join-Path $adopt '.cogniva/profiles') -Directory -Force | Where-Object Name -like '.*').Count -eq 0)
    Write-Fixture $library 'python/standards/python/layout.md' (Std 'Python layout rule, revised.')
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'a library update over an unedited copy is REFRESHED without -Force' ($a.Code -eq 0 -and $a.Out -match 'REFRESHED: python' -and (Get-Content -Raw $layout) -match 'revised' -and (Get-Content -Raw $rec) -match ('content: ' + (Get-TreeHash (Join-Path $library 'python'))))
    Remove-Item -LiteralPath $rec
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'a copy equal to the library with no record is UP-TO-DATE and gains a record' ($a.Code -eq 0 -and $a.Out -match 'UP-TO-DATE: python' -and (Test-Path $rec))
    Remove-Item -LiteralPath $rec
    Add-Content -LiteralPath $layout -Value 'Unrecorded edit.'
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'a differing copy with no record is DIFFERS and blocked' ($a.Code -eq 1 -and $a.Out -match 'DIFFERS: \.cogniva/profiles/python' -and -not (Test-Path $rec))
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library, '-Force')
    Check '-Force replaces an unrecorded copy and records it' ($a.Code -eq 0 -and $a.Out -match 'REPLACED: python' -and (Test-Path $rec))

    # -Refresh: library profiles refresh, repo-owned profiles are byte-identical and get REVIEW lines.
    Add-Profile $adopt 'acme' "description: Acme.`ninherits: python`n" @{ 'amendments/python/layout.md' = (Delta 'Acme layout.' (Basis @((Std 'Python layout rule, revised.')))) }
    $acmeBefore = @(Get-ChildItem -LiteralPath (Join-Path $adopt '.cogniva/profiles/acme') -Recurse -File | Get-FileHash | ForEach-Object Hash) -join ','
    Write-Fixture $library 'python/standards/python/layout.md' (Std 'Python layout rule, third.')
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Refresh', '-LibraryRoot', $library)
    $acmeAfter = @(Get-ChildItem -LiteralPath (Join-Path $adopt '.cogniva/profiles/acme') -Recurse -File | Get-FileHash | ForEach-Object Hash) -join ','
    Check '-Refresh refreshes every adopted library profile' ($a.Code -eq 0 -and $a.Out -match 'REFRESHED: python' -and $a.Out -match 'UP-TO-DATE: base')
    Check '-Refresh leaves a repo-owned profile byte-identical' ($acmeBefore -eq $acmeAfter -and -not (Test-Path (Join-Path $adopt '.cogniva/adopted/acme.yml')))
    Check 'adopt prints REVIEW for a repo-owned delta that went stale' ($a.Out -match 'REVIEW: acme amendment python/layout\.md is STALE')
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Refresh', '-Profile', 'python', '-LibraryRoot', $library)
    Check '-Refresh and -Profile together are a usage error' ($a.Code -eq 2)
    Remove-Item -LiteralPath (Join-Path $adopt '.cogniva/profiles/acme') -Recurse -Force

    # Stage 1 migration: a record-less copy of the Stage 1 library refreshes cleanly.
    $stage1 = Join-Path $here 'fixtures\stage1'
    $migrate = New-Repo 'stage1'
    $newLibrary = Join-Path $root 'library-next'
    New-Item -ItemType Directory -Path (Join-Path $migrate '.cogniva/profiles'), $newLibrary -Force | Out-Null
    foreach ($id in 'cogniva-base', 'dotnet') { Copy-Item -LiteralPath (Join-Path $stage1 $id) -Destination (Join-Path $migrate ".cogniva/profiles/$id") -Recurse -Force }
    foreach ($id in 'cogniva-base', 'dotnet') { Copy-Item -LiteralPath (Join-Path $stage1 $id) -Destination (Join-Path $newLibrary $id) -Recurse -Force }
    Remove-Item -LiteralPath (Join-Path $newLibrary 'dotnet/standards/dotnet/module-layout.md')
    Write-Fixture $newLibrary 'dotnet/standards/dotnet/project-layout.md' (Std 'Next layout.')
    $a = Invoke-Script $adopter @('-Repo', $migrate, '-Profile', 'dotnet', '-LibraryRoot', $newLibrary)
    Check 'a Stage 1 adoption with no record refreshes without -Force' ($a.Code -eq 0 -and $a.Out -match 'REFRESHED: dotnet' -and $a.Out -match 'UP-TO-DATE: cogniva-base' -and (Test-Path (Join-Path $migrate '.cogniva/adopted/dotnet.yml')))
    Check 'a dropped Stage 1 standard is reported with the migration guide' ($a.Out -match 'REMOVED: dotnet/standards/dotnet/module-layout\.md' -and $a.Out -match 'module-bundle-migration\.md')
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'missing', '-LibraryRoot', $library)
    Check 'adopting an unknown profile fails' ($a.Code -eq 2 -and $a.All -match "profile 'missing' is not in the plugin library")
    $fresh = New-Repo 'adopt-ids'
    $a = Invoke-Script $adopter @('-Repo', $fresh, '-Profile', 'Python', '-LibraryRoot', $library)
    Check 'adopt rejects a mixed-case profile id and writes nothing' ($a.Code -eq 2 -and $a.All -match "'Python' is not a valid profile id" -and -not (Test-Path (Join-Path $fresh '.cogniva')))

    if ($IsWindows) {
        # A file held open in the second profile's copy makes its swap fail after
        # the first profile was already swapped; both must come back untouched.
        $pythonCopy = Join-Path $adopt '.cogniva/profiles/python/standards/python/layout.md'
        $baseCopy = Join-Path $adopt '.cogniva/profiles/base/standards/architecture/owner.md'
        Add-Content -LiteralPath $pythonCopy -Value 'Python local edit.'
        Add-Content -LiteralPath $baseCopy -Value 'Base local edit.'
        $lock = [System.IO.File]::Open($baseCopy, 'Open', 'Read', 'Read')
        try { $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library, '-Force') }
        finally { $lock.Dispose() }
        Check 'a failed swap exits 2 and says the copies were restored' ($a.Code -eq 2 -and $a.All -match 'copy failed, existing copies restored')
        Check 'a failed swap rolls back the profile already swapped' ((Get-Content -Raw $pythonCopy) -match 'Python local edit')
        Check 'a failed swap leaves the failing profile untouched' ((Get-Content -Raw $baseCopy) -match 'Base local edit')
        Check 'a failed swap leaves no staging or backup folders' (@(Get-ChildItem -LiteralPath (Join-Path $adopt '.cogniva/profiles') -Directory -Force | Where-Object Name -like '.*').Count -eq 0)
    }
    else { Write-Host '  SKIP  swap rollback (needs Windows file locking)' }

    # --- structural-change policy: kinds, detectors, structure-requires ---------
    $st = New-Repo 'structure'
    $stBaseYaml = "description: Base.`nstructure-kinds:`n  - unit-added`n  - dependency-added`nstructure-requires:`n  - `"unit-added architecture/owner.md`"`n  - `"dependency-added architecture/edges.md`"`n"
    Add-Profile $st 'base' $stBaseYaml @{ 'architecture/owner.md' = (Std 'Base owner.'); 'architecture/edges.md' = (Std 'Base edges.'); 'architecture/other.md' = (Std 'Base other.') }
    Add-Profile $st 'tech' "description: Tech.`ninherits: base`nstructure-detectors:`n  - tech-detector`nstructure-requires:`n  - `"unit-added tech/layout.md`"`n" @{ 'tech/layout.md' = (Std 'Tech layout.'); 'amendments/architecture/owner.md' = (Delta 'Tech owner.' (Basis @((Std 'Base owner.')))); 'amendments/architecture/other.md' = (Delta 'Tech other.' (Basis @((Std 'Base other.')))) }
    $stRepoYaml = "description: Repo.`ninherits: tech`nstructure-kinds:`n  - code-moved`nstructure-detectors:`n  - repo-detector`n  - tech-detector`nstructure-requires-dropped:`n  - `"unit-added tech/layout.md`"`nstructure-requires:`n  - `"code-moved architecture/owner.md`"`n  - `"dependency-added repo/edges.md`"`n"
    Add-Profile $st 'repo' $stRepoYaml @{ 'repo/edges.md' = (Std 'Repo edges.') }
    Write-Fixture $st '.cogniva-profile.yml' "profile: repo`n"

    $r = Resolve-Json $st @('-Target', 'src')
    $s = $r.Json.Profiles.repo.Structure
    Check 'structure policy resolves with no warnings' ($r.Code -eq 0 -and @($r.Json.Warnings).Count -eq 0)
    Check 'structure kinds add up, root first' ((@($s.Kinds) -join ',') -eq 'unit-added,dependency-added,code-moved')
    Check 'structure detectors add up, root first, without duplicates' ((@($s.Detectors) -join ',') -eq 'tech-detector,repo-detector')
    Check 'a child adds pairs to inherited and own kinds' ((@($s.Requires.'dependency-added') -join ',') -eq 'architecture/edges.md,repo/edges.md' -and (@($s.Requires.'code-moved') -join ',') -eq 'architecture/owner.md')
    Check 'a child drops one inherited pair by name' ((@($s.Requires.'unit-added') -join ',') -eq 'architecture/owner.md')
    $r = Resolve-Json $st @('-Target', 'src', '-Profile', 'tech')
    Check 'the parent keeps the pair its child dropped' ((@($r.Json.Profiles.tech.Structure.Requires.'unit-added') -join ',') -eq 'architecture/owner.md,tech/layout.md')
    $text = Invoke-Script $resolver @('-Repo', $st, '-Target', 'src', '-LibraryRoot', $library)
    Check 'text output lists the structure policy' ($text.Out -match 'STRUCTURE DETECTORS: tech-detector, repo-detector' -and $text.Out -match 'STRUCTURE REQUIRES dependency-added: architecture/edges\.md, repo/edges\.md')

    # -Kinds feeds the -Require gate
    $r = Resolve-Json $st @('-Target', 'src', '-Kinds', 'dependency-added')
    Check '-Kinds requires the standards its kinds map to' ($r.Code -eq 0 -and (@($r.Json.Require.ByTarget[0].Standards) -join ',') -eq 'architecture/edges.md,repo/edges.md' -and @($r.Json.Require.Blocked).Count -eq 0 -and (@($r.Json.Require.Kinds) -join ',') -eq 'dependency-added')
    $text = Invoke-Script $resolver @('-Repo', $st, '-Target', 'src', '-Kinds', 'dependency-added', '-LibraryRoot', $library)
    Check '-Kinds text output lists the required standards' ($text.Code -eq 0 -and $text.Out -match 'REQUIRE: ok \(architecture/edges\.md, repo/edges\.md\)')
    $r = Resolve-Json $st @('-Target', 'src', '-Kinds', 'unit-removed')
    Check 'a kind the profile does not declare requires nothing and is reported' ($r.Code -eq 0 -and @($r.Json.Require.ByTarget[0].Standards).Count -eq 0 -and (@($r.Json.Require.ByTarget[0].UnknownKinds) -join ',') -eq 'unit-removed')
    $text = Invoke-Script $resolver @('-Repo', $st, '-Target', 'src', '-Kinds', 'unit-removed', '-LibraryRoot', $library)
    Check 'an undeclared kind prints REQUIRE ok with nothing required and a KIND NOT DECLARED line' ($text.Code -eq 0 -and $text.Out -match 'REQUIRE: ok \(no standards required\)' -and $text.Out -match 'KIND NOT DECLARED: src unit-removed \(profile repo\)')
    $r = Resolve-Json $st @('-Target', 'src', '-Kinds', 'Not_A_Kind')
    Check '-Kinds rejects a malformed kind as a usage error' ($r.Code -eq 2)

    # MIXED targets: each target keeps its own profile's list, and -Show takes that list
    Write-Fixture $st 'tools/.cogniva-profile.yml' "profile: tech`n"
    $r = Resolve-Json $st @('-Target', 'src,tools', '-Kinds', 'dependency-added')
    $bySrc = @($r.Json.Require.ByTarget | Where-Object Target -eq 'src')
    $byTools = @($r.Json.Require.ByTarget | Where-Object Target -eq 'tools')
    Check '-Kinds on MIXED targets keeps each profile''s own list' ($r.Code -eq 0 -and $bySrc.Count -eq 1 -and (@($bySrc[0].Standards) -join ',') -eq 'architecture/edges.md,repo/edges.md' -and $byTools.Count -eq 1 -and $byTools[0].Profile -eq 'tech' -and (@($byTools[0].Standards) -join ',') -eq 'architecture/edges.md')
    $text = Invoke-Script $resolver @('-Repo', $st, '-Target', 'src,tools', '-Kinds', 'dependency-added', '-LibraryRoot', $library)
    Check '-Kinds text output prints one REQUIRE FOR line per target' ($text.Code -eq 0 -and $text.Out -match 'REQUIRE FOR src \(repo\): architecture/edges\.md, repo/edges\.md' -and $text.Out -match 'REQUIRE FOR tools \(tech\): architecture/edges\.md')
    $show = Invoke-Script $resolver @('-Repo', $st, '-Target', 'tools', '-Show', 'architecture/edges.md', '-LibraryRoot', $library)
    Check '-Show with a target''s own REQUIRE FOR list succeeds' ($show.Code -eq 0 -and $show.Out -match 'SHOW architecture/edges\.md - profile tech')
    $show = Invoke-Script $resolver @('-Repo', $st, '-Target', 'tools', '-Show', 'architecture/edges.md,repo/edges.md', '-LibraryRoot', $library)
    Check '-Show with another profile''s standard in the list is a usage error' ($show.Code -eq 2)
    Remove-Item -LiteralPath (Join-Path $st 'tools') -Recurse -Force

    # only the standards a kind requires can block it
    Write-Fixture $st '.cogniva/profiles/base/standards/architecture/other.md' (Std 'Base other, changed.')
    $r = Resolve-Json $st @('-Target', 'src', '-Kinds', 'unit-added')
    Check '-Kinds passes when only an unrelated standard is stale' ($r.Code -eq 0 -and $r.Json.Targets[0].NeedsReview -eq $true)
    Write-Fixture $st '.cogniva/profiles/base/standards/architecture/other.md' (Std 'Base other.')
    Write-Fixture $st '.cogniva/profiles/base/standards/architecture/owner.md' (Std 'Base owner, changed.')
    $r = Resolve-Json $st @('-Target', 'src', '-Kinds', 'unit-added')
    Check '-Kinds exits 3 when a standard the kind requires is stale' ($r.Code -eq 3 -and @($r.Json.Require.Blocked | Where-Object { $_.Standard -eq 'architecture/owner.md' -and $_.Reason -match 'needs human review' }).Count -eq 1)
    Write-Fixture $st '.cogniva/profiles/base/standards/architecture/owner.md' (Std 'Base owner.')
    Write-Fixture $st '.cogniva/profiles/repo/profile.yml' ($stRepoYaml + "  - `"code-moved repo/missing.md`"`n")
    $r = Resolve-Json $st @('-Target', 'src', '-Kinds', 'code-moved')
    Check '-Kinds exits 3 when a kind maps to a standard the profile lacks' ($r.Code -eq 3 -and @($r.Json.Require.Blocked | Where-Object { $_.Standard -eq 'repo/missing.md' -and $_.Reason -match "not in profile 'repo'" }).Count -eq 1)
    Check 'a pair naming a missing standard is warned about' (@($r.Json.Warnings | Where-Object { $_ -match 'repo/missing\.md' }).Count -ge 1)
    Write-Fixture $st '.cogniva/profiles/repo/profile.yml' $stRepoYaml

    # malformed policy is an ERROR for the profile's targets
    Write-Fixture $st '.cogniva/profiles/repo/profile.yml' ($stRepoYaml + "  - `"code-movd architecture/owner.md`"`n")
    $r = Resolve-Json $st @('-Target', 'src')
    Check 'a pair naming an undeclared kind is an ERROR' (Test-TargetError $r "structure kind 'code-movd' is not declared")
    Write-Fixture $st '.cogniva/profiles/repo/profile.yml' ($stRepoYaml + "  - `"unit-added tech/layout.md`"`n")
    $r = Resolve-Json $st @('-Target', 'src')
    Check 'requiring and dropping one pair in one profile is an ERROR' (Test-TargetError $r 'in both structure-requires and structure-requires-dropped')
    Write-Fixture $st '.cogniva/profiles/repo/profile.yml' ($stRepoYaml + "  - `"code-moved`"`n")
    $r = Resolve-Json $st @('-Target', 'src')
    Check 'a pair without a .md standard id is an ERROR' (Test-TargetError $r "must be '<kind> <standard id>'")
    Write-Fixture $st '.cogniva/profiles/repo/profile.yml' ($stRepoYaml.Replace('  - repo-detector', '  - Repo_Detector'))
    $r = Resolve-Json $st @('-Target', 'src')
    Check 'a malformed detector id is an ERROR' (Test-TargetError $r "structure detector 'Repo_Detector' is not a valid detector id")
    Write-Fixture $st '.cogniva/profiles/repo/profile.yml' ($stRepoYaml.Replace('  - "unit-added tech/layout.md"', '  - "unit-added repo/edges.md"'))
    $r = Resolve-Json $st @('-Target', 'src')
    Check 'dropping a pair the profile does not inherit is a warning' ($r.Code -eq 0 -and @($r.Json.Warnings | Where-Object { $_ -match 'drops nothing it inherits' }).Count -eq 1)
    Write-Fixture $st '.cogniva/profiles/repo/profile.yml' $stRepoYaml

    # -Show takes a list: the full composed text of each listed standard
    $show = Invoke-Script $resolver @('-Repo', $st, '-Target', 'src', '-Show', 'architecture/owner.md,repo/edges.md', '-LibraryRoot', $library)
    $iOwner = $show.Out.IndexOf('SHOW architecture/owner.md - profile repo')
    $iEdges = $show.Out.IndexOf('SHOW repo/edges.md - profile repo')
    Check '-Show prints every listed standard in full, in the order listed' ($show.Code -eq 0 -and $iOwner -ge 0 -and $iEdges -gt $iOwner -and $show.Out -match '--- amendment from tech \(repo-owned, CURRENT\)' -and $show.Out -match '# Delta body' -and ([regex]::Matches($show.Out, '# Body')).Count -eq 2)
    $show = Invoke-Script $resolver @('-Repo', $st, '-Target', 'src', '-Show', 'architecture/owner.md,architecture/nope.md', '-LibraryRoot', $library)
    Check '-Show with one unknown standard in the list is a usage error' ($show.Code -eq 2)

    # --- the shipped library ---------------------------------------------------
    $shipped = New-Repo 'shipped'
    foreach ($dir in Get-ChildItem -LiteralPath $shippedLibrary -Directory) {
        $a = Invoke-Script $adopter @('-Repo', $shipped, '-Profile', $dir.Name, '-LibraryRoot', $shippedLibrary)
        Check "shipped profile '$($dir.Name)' adopts cleanly" ($a.Code -eq 0)
        $r = Invoke-Script $resolver @('-Repo', $shipped, '-Target', '.', '-Profile', $dir.Name, '-Format', 'Json', '-LibraryRoot', $shippedLibrary)
        $json = if ($r.Code -eq 0) { $r.Out | ConvertFrom-Json } else { $null }
        Check "shipped profile '$($dir.Name)' resolves with no warnings" ($r.Code -eq 0 -and @($json.Warnings).Count -eq 0 -and @($json.Profiles.($dir.Name).Standards).Count -gt 0)
        Check "every standard in '$($dir.Name)' has a description" ($json -and @($json.Profiles.($dir.Name).Standards | Where-Object { -not $_.Description }).Count -eq 0)
    }
    Check 'the library ships cogniva-base and dotnet, and dotnet inherits cogniva-base' ((Test-Path (Join-Path $shippedLibrary 'cogniva-base/profile.yml')) -and ((Get-Content -Raw (Join-Path $shippedLibrary 'dotnet/profile.yml')) -match '(?m)^inherits: cogniva-base'))
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All architecture-profile assertions passed.'
exit 0
