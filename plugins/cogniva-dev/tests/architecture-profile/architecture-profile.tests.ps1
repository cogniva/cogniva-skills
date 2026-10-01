#Requires -Version 7.0
# Dependency-free tests for architecture-profile resolution, inheritance,
# suggestions, adoption, and the shipped profile library.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$resolver = Join-Path $plugin 'scripts\resolve-architecture-profile.ps1'
$adopter = Join-Path $plugin 'scripts\adopt-architecture-profile.ps1'
$shippedLibrary = Join-Path $plugin 'profiles'
$template = Join-Path $plugin 'templates\repo\CLAUDE.md'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-architecture-profile-" + [guid]::NewGuid().ToString('N'))
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
# Exit 0 and 1 both carry a JSON report (1 = at least one target is ERROR); exit 2 carries none.
function Resolve-Json([string]$Repo, [string[]]$Extra) {
    $result = Invoke-Script $resolver (@('-Repo', $Repo, '-Format', 'Json', '-LibraryRoot', $script:library) + $Extra)
    $json = if ($result.Code -in 0, 1) { $result.Out | ConvertFrom-Json } else { $null }
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
    foreach ($key in $Standards.Keys) { Write-Fixture $Repo ".cogniva/profiles/$Id/standards/$key" $Standards[$key] }
}
function Std([string]$Description) { return "---`ndescription: $Description`n---`n`n# Body`n" }

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
    Add-Profile $repo 'python' "description: Python.`ninherits: base`n" @{ 'Architecture/Owner.md' = (Std 'Python owner.'); 'python/layout.md' = (Std 'Python layout.') }
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
    Check 'child same-path standard overrides the parent (case-insensitive)' ($owner.Count -eq 1 -and $owner[0].From -eq 'python' -and $owner[0].Description -eq 'Python owner.' -and @($owner[0].Overrides) -contains 'base')
    Check 'parent-only standards are inherited' (@($p.Standards | Where-Object { $_.Id -eq 'architecture/shared.md' -and $_.From -eq 'base' }).Count -eq 1)
    Check 'index carries descriptions, not bodies' (-not ($r.Raw -match '# Body'))
    Check 'standards are ordered by id' ((@($p.Standards.Id) -join '|') -eq (@($p.Standards.Id | Sort-Object { $_.ToLowerInvariant() }) -join '|'))

    $again = Resolve-Json $repo @('-Target', 'tools')
    Check 'resolution is deterministic' ($again.Raw -eq $r.Raw)
    $after = @(& git -C $repo status --porcelain)
    Check 'resolver leaves the repository unchanged' (($before -join "`n") -eq ($after -join "`n"))

    $text = Invoke-Script $resolver @('-Repo', $repo, '-Target', 'tools/ingest/run.py', '-LibraryRoot', $library)
    Check 'text output explains the winner and the shadowed marker' ($text.Out -match 'PROFILE: python \(path-override: tools/\.cogniva-profile\.yml\)' -and $text.Out -match 'SHADOWED: \.cogniva-profile\.yml -> dotnet')

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
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 're-adopting an unchanged copy is UP-TO-DATE' ($a.Code -eq 0 -and $a.Out -match 'UP-TO-DATE: python' -and $a.Out -match 'UP-TO-DATE: base')
    $layout = Join-Path $adopt '.cogniva/profiles/python/standards/python/layout.md'
    [System.IO.File]::WriteAllText($layout, ([System.IO.File]::ReadAllText($layout)).Replace("`n", "`r`n"))
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'line-ending-only differences count as up to date' ($a.Code -eq 0 -and $a.Out -match 'UP-TO-DATE: python')
    Add-Content -LiteralPath $layout -Value 'Local edit.'
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'a locally edited copy blocks re-adoption and names the file' ($a.Code -eq 1 -and $a.Out -match 'DIFFERS: \.cogniva/profiles/python - standards/python/layout\.md' -and (Get-Content -Raw $layout) -match 'Local edit')
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library, '-Force')
    Check '-Force replaces the edited copy' ($a.Code -eq 0 -and $a.Out -match 'REPLACED: python' -and -not ((Get-Content -Raw $layout) -match 'Local edit'))
    Check 'a successful replacement leaves no staging or backup folders' (@(Get-ChildItem -LiteralPath (Join-Path $adopt '.cogniva/profiles') -Directory -Force | Where-Object Name -like '.*').Count -eq 0)
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

    # --- drift: dotnet standard vs the repo template it was extracted from ---
    $ruleLines = @(Get-Content -LiteralPath $template | Where-Object { $_ -match '^\s+- `<Name>\.' } | ForEach-Object { $_.Trim() })
    $standard = Get-Content -Raw -LiteralPath (Join-Path $shippedLibrary 'dotnet/standards/dotnet/module-dependencies.md')
    Check 'template CLAUDE.md still has per-Module dependency rules to compare' ($ruleLines.Count -ge 6)
    Check 'dotnet module-dependencies standard matches the template rules verbatim' (@($ruleLines | Where-Object { -not $standard.Contains($_) }).Count -eq 0)
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All architecture-profile assertions passed.'
exit 0
