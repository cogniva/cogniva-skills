#Requires -Version 7.0
# Dependency-free tests for the shipped profile library and the scaffold
# templates that must agree with it: library deltas are current, dotnet
# carries no Module bundle layout, and both repo shapes the library serves
# resolve on dotnet using standards/ and amendments/ only.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$resolver = Join-Path $plugin 'scripts\resolve-architecture-profile.ps1'
$adopter = Join-Path $plugin 'scripts\adopt-architecture-profile.ps1'
$accepter = Join-Path $plugin 'scripts\accept-profile-delta.ps1'
$library = Join-Path $plugin 'profiles'
$templates = Join-Path $plugin 'templates\repo'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-profile-library-" + [guid]::NewGuid().ToString('N'))
$failures = @()

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
function Resolve-Json([string]$Repo, [string[]]$Extra) {
    $result = Invoke-Script $resolver (@('-Repo', $Repo, '-Format', 'Json', '-LibraryRoot', $library) + $Extra)
    $json = if ($result.Code -in 0, 1, 3) { $result.Out | ConvertFrom-Json } else { $null }
    [pscustomobject]@{ Code = $result.Code; Json = $json; All = $result.All }
}
function New-Repo([string]$Name) {
    $repo = Join-Path $root $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    & git -C $repo init -q
    return $repo
}
# A repo with the shipped dotnet adopted and declared at the root.
function New-DotnetRepo([string]$Name) {
    $repo = New-Repo $Name
    $a = Invoke-Script $adopter @('-Repo', $repo, '-Profile', 'dotnet', '-LibraryRoot', $library)
    if ($a.Code -ne 0) { throw "adopt failed: $($a.All)" }
    Write-Fixture $repo '.cogniva-profile.yml' "profile: dotnet`n"
    return $repo
}

try {
    # --- the shipped library ---------------------------------------------------
    $shipped = New-DotnetRepo 'shipped'
    $r = Resolve-Json $shipped @('-Target', 'src/Hosts/Acme.Web,src/Lib/Acme.Lib')
    $dotnet = $r.Json.Profiles.dotnet
    $ids = @($dotnet.Standards.Id)
    $expected = @('architecture/architecture-exceptions.md', 'architecture/common-and-published-types.md', 'architecture/composition-roots.md', 'architecture/dependency-direction.md', 'architecture/external-integrations.md', 'architecture/ownership-and-placement.md', 'dotnet/build-settings.md', 'dotnet/project-layout.md', 'dotnet/projects-and-references.md', 'dotnet/ui.md')
    Check 'dotnet resolves with no warnings' ($r.Code -eq 0 -and @($r.Json.Warnings).Count -eq 0)
    Check 'dotnet provides exactly the expected standards' ((($ids | Sort-Object) -join ',') -eq (($expected | Sort-Object) -join ','))
    Check 'every library delta is CURRENT' (@($dotnet.Review).Count -eq 0 -and $r.Json.Targets[0].NeedsReview -eq $false)
    $amended = @($dotnet.Standards | Where-Object { @($_.Amendments | Where-Object From -eq 'dotnet').Count } | ForEach-Object Id | Sort-Object)
    Check 'dotnet amends exactly composition-roots, external-integrations and common-and-published-types' (($amended -join ',') -eq 'architecture/common-and-published-types.md,architecture/composition-roots.md,architecture/external-integrations.md')
    Check 'no library profile uses replacements/' (@(Get-ChildItem -LiteralPath $library -Recurse -Directory -Filter 'replacements').Count -eq 0)
    Check 'composition-roots applies to src/Hosts/** only' ((@($r.Json.Targets[0].MatchedStandards) -join ',') -eq 'architecture/composition-roots.md' -and @($r.Json.Targets[1].MatchedStandards).Count -eq 0)

    # --- Module-bundle leak check: dotnet carries no Module bundle layout ------
    $dotnetText = (Get-ChildItem -LiteralPath (Join-Path $library 'dotnet') -Recurse -File | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
    Check 'Module-bundle leak check: no src/Modules in dotnet' ($dotnetText -notmatch 'src/Modules')
    Check 'Module-bundle leak check: no layer project names in dotnet' ($dotnetText -cnotmatch '\.(Domain|Application|Infrastructure|Client)\b')
    Check 'Module-bundle leak check: no "Contracts ONLY" in dotnet' ($dotnetText -notmatch 'Contracts ONLY')

    # --- fixture: a kind-first repo (engines and adapters by folder, a published-types project)
    $kind = New-DotnetRepo 'kind-first'
    foreach ($p in 'src/Hosts/Acme.Web/Acme.Web.csproj', 'src/Engines/Acme.Pricing/Acme.Pricing.csproj', 'src/Adapters/Acme.Pricing.Sql/Acme.Pricing.Sql.csproj', 'src/Types/Acme.Pricing.Types/Acme.Pricing.Types.csproj') {
        Write-Fixture $kind $p "<Project Sdk=`"Microsoft.NET.Sdk`" />`n"
    }
    $r = Resolve-Json $kind @('-Target', 'src/Hosts/Acme.Web,src/Engines/Acme.Pricing,src/Types/Acme.Pricing.Types')
    Check 'a kind-first repo resolves on dotnet with no repo-owned profile' ($r.Code -eq 0 -and $r.Json.Aggregate.Status -eq 'UNIFORM' -and @($r.Json.Profiles.dotnet.ChainDetail | Where-Object Ownership -ne 'library').Count -eq 0 -and $r.Json.Targets[0].NeedsReview -eq $false)
    Check 'in a kind-first repo only the host matches a placement standard' ((@($r.Json.Targets[0].MatchedStandards) -join ',') -eq 'architecture/composition-roots.md' -and @($r.Json.Targets[1].MatchedStandards).Count -eq 0 -and @($r.Json.Targets[2].MatchedStandards).Count -eq 0)

    # --- fixture: a Module-bundle repo on dotnet through a repo-owned profile --
    $bundle = New-DotnetRepo 'module-bundle'
    Write-Fixture $bundle '.cogniva/profiles/acme/profile.yml' "description: Acme's Module bundle layout on dotnet.`ninherits: dotnet`n"
    Write-Fixture $bundle '.cogniva/profiles/acme/amendments/dotnet/project-layout.md' "---`ndescription: Acme adds a Modules kind and regions.`n---`n`n- ``src/Modules/<Name>/`` is a kind: one folder per Module, holding its layer projects.`n- Regions group Modules: ``src/Modules/<Region>/<Name>/`` is also valid.`n"
    Write-Fixture $bundle '.cogniva/profiles/acme/standards/acme/module-bundle.md' "---`ndescription: Each Module is a bundle of Contracts, Domain, Application, Infrastructure, optional Client and UI projects.`n---`n`n# Module bundle`n"
    Write-Fixture $bundle '.cogniva/profiles/acme/standards/acme/module-edges.md' "---`ndescription: Per-layer reference edges inside and between Modules.`n---`n`n# Module edges`n"
    Write-Fixture $bundle '.cogniva/profiles/acme/standards/acme/split-ui.md' "---`ndescription: A Module's UI splits into a controls project and a routes project.`n---`n`n# Split UI`n"
    Write-Fixture $bundle '.cogniva/profiles/acme/amendments/architecture/architecture-exceptions.md' "---`ndescription: Acme's recorded exception - Orders and Billing may reference each other.`n---`n`n- Allowed cycle: Orders <-> Billing (docs/architecture/allowed-cycles.txt).`n"
    Write-Fixture $bundle '.cogniva/profiles/acme/amendments/architecture/common-and-published-types.md' "---`ndescription: Acme's published types are each Module's Contracts project.`napplies-to:`n  - `"src/Modules/*/*.Contracts`"`n  - `"src/Modules/*/*.Contracts/**`"`n---`n`n- A Module's published types live in its Contracts project.`n"
    Write-Fixture $bundle '.cogniva-profile.yml' "profile: acme`n"
    $x = Invoke-Script $accepter @('-Repo', $bundle, '-Profile', 'acme', '-All')
    $r = Resolve-Json $bundle @('-Target', 'src/Modules/Orders/Orders.Contracts/IOrders.cs,src/Hosts/Acme.Web')
    Check 'the Module-bundle profile accepts cleanly' ($x.Code -eq 0)
    Check 'a Module-bundle repo resolves on dotnet with standards/ and amendments/ only' ($r.Code -eq 0 -and $r.Json.Targets[0].Status -eq 'RESOLVED' -and $r.Json.Targets[0].NeedsReview -eq $false -and -not (Test-Path (Join-Path $bundle '.cogniva/profiles/acme/replacements')) -and @($r.Json.Profiles.acme.Standards | Where-Object ReplacedBy).Count -eq 0)
    Check 'its Contracts projects match the published-types standard' (@($r.Json.Targets[0].MatchedStandards) -contains 'architecture/common-and-published-types.md')
    Check 'its hosts still match composition-roots' (@($r.Json.Targets[1].MatchedStandards) -contains 'architecture/composition-roots.md')

    # --- template drift: the template points at the profile and restates no rules ---
    $agents = Join-Path $templates 'AGENTS.md'
    $agentsText = if (Test-Path $agents) { Get-Content -Raw -LiteralPath $agents } else { '' }
    Check 'template AGENTS.md carries the profile pointer' ($agentsText -match '\.cogniva-profile\.yml' -and $agentsText -match 'resolve-architecture-profile\.ps1' -and $agentsText -match '-Show' -and $agentsText -match 'amendments/')
    Check 'template AGENTS.md states no architecture rules' ($agentsText.Length -gt 0 -and $agentsText -notmatch 'src/Modules' -and $agentsText -notmatch '->' -and $agentsText -notmatch 'references nothing' -and $agentsText -notmatch 'Contracts')
    Check 'template CLAUDE.md is exactly @AGENTS.md' ((Get-Content -Raw -LiteralPath (Join-Path $templates 'CLAUDE.md')).Trim() -ceq '@AGENTS.md')
    $glossary = Join-Path $templates 'docs\glossary\README.md'
    $glossaryText = if (Test-Path $glossary) { Get-Content -Raw -LiteralPath $glossary } else { '' }
    Check 'template glossary seeds Host and Common types' ($glossaryText -match '(?m)^## Host$' -and $glossaryText -match '(?m)^## Common types$')
    Check 'template glossary carries definitions and links only' ($glossaryText -notmatch '(?m)^\s*- ' -and $glossaryText -notmatch '->' -and $glossaryText -cnotmatch 'ONLY' -and $glossaryText -notmatch 'Module')
    $props = Join-Path $templates 'Directory.Build.props'
    $propsText = if (Test-Path $props) { Get-Content -Raw -LiteralPath $props } else { '' }
    $buildText = Get-Content -Raw -LiteralPath (Join-Path $library 'dotnet\standards\dotnet\build-settings.md')
    Check 'template Directory.Build.props sets net10.0, nullable and warnings as errors' ($propsText -match '<TargetFramework>net10\.0</TargetFramework>' -and $propsText -match '<Nullable>enable</Nullable>' -and $propsText -match '<TreatWarningsAsErrors>true</TreatWarningsAsErrors>')
    Check 'build-settings names every property the template sets' (@('TargetFramework', 'Nullable', 'TreatWarningsAsErrors' | Where-Object { $buildText -notmatch $_ }).Count -eq 0)

    # --- plugin-wide leak check: no real repository or unit names ship in the plugin ---
    # (module-deps.tests.ps1 and this file hold the lists themselves.)
    $names = @('NewCogniva', 'CognivaShell', 'CognivaNewRepo', 'C3Data', 'DocumentOrchestration', 'DocumentStore', 'GovernanceOrchestration', 'StructureInsights')
    $leaks = @(Get-ChildItem -LiteralPath $plugin -Recurse -File | Where-Object { $_.Name -notin 'module-deps.tests.ps1', 'profile-library.tests.ps1' } | ForEach-Object {
        $file = $_
        $text = Get-Content -Raw -LiteralPath $file.FullName -ErrorAction SilentlyContinue
        foreach ($n in $names) { if ($text -and $text -cmatch "\b$n\b") { "$([System.IO.Path]::GetRelativePath($plugin, $file.FullName)): $n" } }
    })
    Check "no real repository names under plugins/cogniva-dev ($($leaks -join '; '))" ($leaks.Count -eq 0)
    # This file is excluded: its own check label below names the phrase it forbids.
    $stale = @(Get-ChildItem -LiteralPath $plugin -Recurse -File | Where-Object { $_.Name -ne 'profile-library.tests.ps1' -and (Get-Content -Raw -LiteralPath $_.FullName -ErrorAction SilentlyContinue) -match '(?i)legacy Module[- ]layout' } | ForEach-Object Name)
    Check "no 'legacy Module layout' wording remains ($($stale -join ', '))" ($stale.Count -eq 0)

    # --- add-module's gate: only the standards it depends on can block it -------
    $gate = New-DotnetRepo 'add-module-gate'
    Write-Fixture $gate '.cogniva/profiles/acme/profile.yml' "description: Acme's Module bundle layout on dotnet.`ninherits: dotnet`n"
    Write-Fixture $gate '.cogniva/profiles/acme/amendments/dotnet/project-layout.md' "---`ndescription: Acme adds a Modules kind.`n---`n`n- ``src/Modules/<Name>/`` is a kind: one folder per Module.`n"
    Write-Fixture $gate '.cogniva/profiles/acme/amendments/dotnet/ui.md' "---`ndescription: Acme UI note.`n---`n`n- Acme UI.`n"
    Write-Fixture $gate '.cogniva-profile.yml' "profile: acme`n"
    Invoke-Script $accepter @('-Repo', $gate, '-Profile', 'acme', '-All') | Out-Null
    $requireSet = 'dotnet/project-layout.md,dotnet/projects-and-references.md,architecture/composition-roots.md,architecture/common-and-published-types.md'
    $r = Resolve-Json $gate @('-Target', 'src/Modules', '-Require', $requireSet)
    Check "add-module's dependency set passes on a current profile" ($r.Code -eq 0)
    $uiFile = Join-Path $gate '.cogniva/profiles/acme/amendments/dotnet/ui.md'
    Write-Fixture $gate '.cogniva/profiles/acme/amendments/dotnet/ui.md' ((Get-Content -Raw -LiteralPath $uiFile) -replace 'basis: [0-9a-f]{12}', 'basis: aaaaaaaaaaaa')
    $r = Resolve-Json $gate @('-Target', 'src/Modules', '-Require', $requireSet)
    Check "a stale standard outside add-module's dependency set does not block it" ($r.Code -eq 0 -and $r.Json.Targets[0].NeedsReview -eq $true)
    $layoutFile = Join-Path $gate '.cogniva/profiles/acme/amendments/dotnet/project-layout.md'
    Write-Fixture $gate '.cogniva/profiles/acme/amendments/dotnet/project-layout.md' ((Get-Content -Raw -LiteralPath $layoutFile) -replace 'basis: [0-9a-f]{12}', 'basis: aaaaaaaaaaaa')
    $r = Resolve-Json $gate @('-Target', 'src/Modules', '-Require', $requireSet)
    Check 'a stale standard in the dependency set blocks add-module (exit 3)' ($r.Code -eq 3 -and @($r.Json.Require.Blocked.Standard) -contains 'dotnet/project-layout.md')

    # --- sections appended by later sub-plans go above this line ---
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All profile-library assertions passed.'
exit 0
