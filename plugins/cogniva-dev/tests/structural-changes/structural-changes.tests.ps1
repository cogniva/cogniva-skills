#Requires -Version 7.0
# Dependency-free tests for structural-change detection: the working-tree
# snapshot, the dotnet-projects detector, and check-structural-changes.ps1.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$detector = Join-Path $plugin 'scripts\structure-detectors\dotnet-projects.ps1'
$checker = Join-Path $plugin 'scripts\check-structural-changes.ps1'
$resolver = Join-Path $plugin 'scripts\resolve-architecture-profile.ps1'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-structural-changes-" + [guid]::NewGuid().ToString('N'))
$failures = @()
. (Join-Path $plugin 'scripts\profile-lib.ps1')
. (Join-Path $plugin 'scripts\structure-lib.ps1')

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
function New-GitRepo([string]$Name) {
    $repo = Join-Path $root $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    & git -C $repo init -q
    & git -C $repo config user.email 'tests@cogniva.invalid'
    & git -C $repo config user.name 'Cogniva tests'
    & git -C $repo config core.autocrlf false
    return $repo
}
function Commit-All([string]$Repo, [string]$Message) {
    & git -C $Repo add -A 2>$null
    & git -C $Repo commit -q -m $Message 2>$null | Out-Null
}
function Reset-To([string]$Repo, [string]$Sha) {
    & git -C $Repo reset -q --hard $Sha 2>$null
    & git -C $Repo clean -fdq 2>$null
}
# A project file with the given ProjectReference Include values.
function Proj([string[]]$Refs) {
    $items = (@($Refs) | ForEach-Object { "    <ProjectReference Include=`"$_`" />" }) -join "`n"
    return "<Project Sdk=`"Microsoft.NET.Sdk`">`n  <ItemGroup>`n$items`n  </ItemGroup>`n</Project>`n"
}
function Detect([string]$Repo, [string]$Base, [string]$Head) {
    $r = Invoke-Script $detector @('-Repo', $Repo, '-Base', $Base, '-Head', $Head)
    $json = $null
    if ($r.Code -eq 0) { try { $json = $r.Out | ConvertFrom-Json } catch { $json = $null } }
    [pscustomobject]@{ Code = $r.Code; Json = $json; Facts = @(if ($json) { $json.facts }); Raw = $r.Out; All = $r.All }
}
function Facts($Result, [string]$Kind) { return @($Result.Facts | Where-Object kind -eq $Kind) }
# Big enough for git rename detection to pair a moved copy with its original.
$foo = "class Foo {`n" + ((1..30 | ForEach-Object { "    // line $_" }) -join "`n") + "`n}`n"
$bar = "class Bar {`n" + ((1..30 | ForEach-Object { "    // bar line $_" }) -join "`n") + "`n}`n"

try {
    # --- the snapshot ----------------------------------------------------------
    $sn = New-GitRepo 'snapshot'
    Write-Fixture $sn 'a.txt' "a`n"
    Commit-All $sn 'init'
    Write-Fixture $sn 'b.txt' "untracked`n"
    Write-Fixture $sn 'c.txt' "staged`n"
    & git -C $sn add c.txt
    $statusBefore = @(& git -C $sn status --porcelain) -join "`n"
    $tree = Get-WorkingTreeSnapshot $sn
    $statusAfter = @(& git -C $sn status --porcelain) -join "`n"
    $names = @(& git -C $sn ls-tree -r --name-only $tree)
    Check 'snapshot: a tree holding tracked, staged and untracked files' ($tree -match '^[0-9a-f]{40,64}$' -and ($names -join ',') -eq 'a.txt,b.txt,c.txt')
    Check 'snapshot: the index and working tree are left unchanged' ($statusBefore -eq $statusAfter)

    # --- the dotnet-projects detector -----------------------------------------
    $d = New-GitRepo 'detector'
    Write-Fixture $d 'src/A/A.csproj' (Proj @('..\B\B.csproj'))
    Write-Fixture $d 'src/B/B.csproj' (Proj @())
    Write-Fixture $d 'src/B/Bar.cs' $bar
    Write-Fixture $d 'src/C/C.csproj' (Proj @())
    Write-Fixture $d 'src/A/Foo.cs' $foo
    Write-Fixture $d 'src/A/Tiny.cs' "namespace A;`nclass Tiny {}`n"
    Write-Fixture $d 'docs/readme.md' "# Readme`n"
    Commit-All $d 'init'
    $dInit = (& git -C $d rev-parse HEAD)
    $t0 = Get-WorkingTreeSnapshot $d

    $r = Detect $d $t0 $t0
    Check 'detector: no change, no facts' ($r.Code -eq 0 -and $r.Json.contract -eq 1 -and $r.Json.detector -eq 'dotnet-projects' -and $r.Facts.Count -eq 0)
    Check 'detector: an empty report is an explicit empty list' ($r.Raw -match '"facts":\s*\[\s*\]')

    Write-Fixture $d 'src/A/Foo.cs' ($foo + "// edited`n")
    Write-Fixture $d 'docs/readme.md' "# Readme, reworded`n"
    $r = Detect $d $t0 (Get-WorkingTreeSnapshot $d)
    Check 'detector: an ordinary source and docs edit reports no facts' ($r.Code -eq 0 -and $r.Facts.Count -eq 0)
    Reset-To $d $dInit

    Write-Fixture $d 'src/A/A.csproj' ((Proj @('..\B\B.csproj')).Replace('</Project>', "  <PropertyGroup><Nullable>enable</Nullable></PropertyGroup>`n</Project>"))
    $r = Detect $d $t0 (Get-WorkingTreeSnapshot $d)
    Check 'detector: a project edit that changes no reference reports nothing' ($r.Code -eq 0 -and $r.Facts.Count -eq 0)
    Reset-To $d $dInit

    Write-Fixture $d 'src/D/D.csproj' (Proj @())
    $r = Detect $d $t0 (Get-WorkingTreeSnapshot $d)
    $f = Facts $r 'unit-added'
    Check 'detector: a new project file is unit-added' ($r.Facts.Count -eq 1 -and $f.Count -eq 1 -and $f[0].units[0] -eq 'src/D/D.csproj' -and $f[0].paths[0] -eq 'src/D/D.csproj' -and $f[0].evidence -match 'was added')
    Reset-To $d $dInit

    Remove-Item -LiteralPath (Join-Path $d 'src/C') -Recurse -Force
    $r = Detect $d $t0 (Get-WorkingTreeSnapshot $d)
    $f = Facts $r 'unit-removed'
    Check 'detector: a deleted project file is unit-removed' ($r.Facts.Count -eq 1 -and $f.Count -eq 1 -and $f[0].units[0] -eq 'src/C/C.csproj')
    Reset-To $d $dInit

    Write-Fixture $d 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
    $r = Detect $d $t0 (Get-WorkingTreeSnapshot $d)
    $f = Facts $r 'dependency-added'
    Check 'detector: a new ProjectReference is dependency-added from A to C' ($r.Facts.Count -eq 1 -and $f.Count -eq 1 -and ($f[0].units -join '>') -eq 'src/A/A.csproj>src/C/C.csproj')
    Check 'detector: a dependency names both ends as governing paths' ($f.Count -eq 1 -and (@($f[0].paths) -join ',') -eq 'src/A/A.csproj,src/C/C.csproj')
    Check 'detector: the evidence quotes the reference as written' ($f.Count -eq 1 -and $f[0].evidence -match [regex]::Escape('src/A/A.csproj adds <ProjectReference Include="..\C\C.csproj">'))
    Reset-To $d $dInit

    Write-Fixture $d 'src/A/A.csproj' (Proj @())
    $r = Detect $d $t0 (Get-WorkingTreeSnapshot $d)
    $f = Facts $r 'dependency-removed'
    Check 'detector: a dropped ProjectReference is dependency-removed' ($r.Facts.Count -eq 1 -and $f.Count -eq 1 -and ($f[0].units -join '>') -eq 'src/A/A.csproj>src/B/B.csproj')
    Reset-To $d $dInit

    Write-Fixture $d 'src/A/A.csproj' ((Proj @('..\B\B.csproj')).Replace('<ItemGroup>', "<ItemGroup>`n    <!-- <ProjectReference Include=`"..\C\C.csproj`" /> -->"))
    $r = Detect $d $t0 (Get-WorkingTreeSnapshot $d)
    Check 'detector: a commented-out ProjectReference is ignored' ($r.Code -eq 0 -and $r.Facts.Count -eq 0)
    Reset-To $d $dInit

    Write-Fixture $d 'src/A/A.csproj' (Proj @('..\B\B.csproj', '$(RepoRoot)src\C\C.csproj'))
    $r = Detect $d $t0 (Get-WorkingTreeSnapshot $d)
    $f = Facts $r 'dependency-added'
    Check 'detector: an Include it cannot evaluate is reported as written, marked (unevaluated)' ($f.Count -eq 1 -and $f[0].units[1] -eq '(unevaluated) $(RepoRoot)src\C\C.csproj')
    Reset-To $d $dInit

    Write-Fixture $d 'src/Directory.Build.props' "<Project>`n  <ItemGroup>`n    <ProjectReference Include=`"C\C.csproj`" />`n  </ItemGroup>`n</Project>`n"
    $r = Detect $d $t0 (Get-WorkingTreeSnapshot $d)
    $f = Facts $r 'dependency-added'
    Check 'detector: a ProjectReference in Directory.Build.props is a dependency of every project under it' ($r.Facts.Count -eq 1 -and $f.Count -eq 1 -and ($f[0].units -join '>') -eq 'src/Directory.Build.props>src/C/C.csproj' -and $f[0].evidence -match 'applies to every project under src')
    Check 'detector: a Directory.Build reference is governed by every project under its folder' ($f.Count -eq 1 -and @($f[0].paths) -contains 'src/Directory.Build.props' -and @($f[0].paths) -contains 'src/A/A.csproj' -and @($f[0].paths) -contains 'src/B/B.csproj' -and @($f[0].paths) -contains 'src/C/C.csproj')
    Reset-To $d $dInit

    & git -C $d mv src/A/Foo.cs src/B/Foo.cs
    $r = Detect $d $t0 (Get-WorkingTreeSnapshot $d)
    $f = Facts $r 'code-moved'
    Check 'detector: a file moved from project A to project B is code-moved' ($r.Facts.Count -eq 1 -and $f.Count -eq 1 -and ($f[0].units -join '>') -eq 'src/A/A.csproj>src/B/B.csproj' -and @($f[0].paths) -contains 'src/A/Foo.cs' -and @($f[0].paths) -contains 'src/B/Foo.cs')
    Reset-To $d $dInit

    New-Item -ItemType Directory -Path (Join-Path $d 'src/A/Sub') -Force | Out-Null
    & git -C $d mv src/A/Foo.cs src/A/Sub/Bar2.cs
    $r = Detect $d $t0 (Get-WorkingTreeSnapshot $d)
    Check 'detector: a rename within one project reports nothing' ($r.Code -eq 0 -and $r.Facts.Count -eq 0)
    Reset-To $d $dInit

    # A small file moved AND rewritten: git sees an unrelated delete and add.
    Remove-Item -LiteralPath (Join-Path $d 'src/A/Tiny.cs')
    Write-Fixture $d 'src/B/Tiny.cs' "namespace B.Moved.Here;`n`npublic sealed partial class Tiny`n{`n}`n"
    $r = Detect $d $t0 (Get-WorkingTreeSnapshot $d)
    $f = Facts $r 'code-moved'
    Check 'detector: a small file moved and edited is still reported, as a possible move' ($r.Facts.Count -eq 1 -and $f.Count -eq 1 -and ($f[0].units -join '>') -eq 'src/A/A.csproj>src/B/B.csproj' -and $f[0].evidence -match 'possible move')
    Reset-To $d $dInit

    New-Item -ItemType Directory -Path (Join-Path $d 'src/Lib') -Force | Out-Null
    & git -C $d mv src/B src/Lib/B
    Write-Fixture $d 'src/A/A.csproj' (Proj @('..\Lib\B\B.csproj'))
    $r = Detect $d $t0 (Get-WorkingTreeSnapshot $d)
    Check 'detector: a moved project is unit-removed plus unit-added' ((Facts $r 'unit-removed')[0].units[0] -eq 'src/B/B.csproj' -and (Facts $r 'unit-added')[0].units[0] -eq 'src/Lib/B/B.csproj')
    Check 'detector: files that move with their project are not code-moved' ((Facts $r 'code-moved').Count -eq 0 -and (Facts $r 'dependency-added').Count -eq 1 -and (Facts $r 'dependency-removed').Count -eq 1 -and $r.Facts.Count -eq 4)
    Reset-To $d $dInit

    $r = Detect $d 'deadbeef' $t0
    Check 'detector: an unreadable tree is a failure (exit 1), not an empty report' ($r.Code -eq 1 -and $null -eq $r.Json)

    # --- check-structural-changes.ps1 -----------------------------------------
    function Add-RepoProfile([string]$Repo, [string]$Id, [string]$Yaml, [hashtable]$Files) {
        Write-Fixture $Repo ".cogniva/profiles/$Id/profile.yml" $Yaml
        foreach ($key in $Files.Keys) {
            $relative = if ($key -match '^(amendments|replacements)/') { $key } else { "standards/$key" }
            Write-Fixture $Repo ".cogniva/profiles/$Id/$relative" $Files[$key]
        }
    }
    function Std([string]$Description) { return "---`ndescription: $Description`n---`n`n# Body`n" }
    function Delta([string]$Description, [string]$Basis) { return "---`ndescription: $Description`nbasis: $Basis`n---`n`n# Delta body`n" }
    function Basis([string[]]$Texts) { return Get-TextHash ((@($Texts | ForEach-Object { Get-NormalisedText $_ })) -join "`n") }
    function Start-Tree([string]$Repo) {
        $s = Invoke-Script $checker @('-Repo', $Repo, '-Snapshot')
        if ($s.Code -ne 0 -or $s.Out -notmatch 'START_TREE: ([0-9a-f]{40,64})') { throw "snapshot failed: $($s.All)" }
        return $Matches[1]
    }
    function Check-Changes([string]$Repo, [string]$Start, [string[]]$Extra = @()) {
        $r = Invoke-Script $checker (@('-Repo', $Repo, '-Since', $Start, '-Format', 'Json') + $Extra)
        $json = $null
        if ($r.Code -in 0, 1, 3, 4) { try { $json = $r.Out | ConvertFrom-Json } catch { $json = $null } }
        [pscustomobject]@{ Code = $r.Code; Json = $json; All = $r.All }
    }
    function Check-Text([string]$Repo, [string]$Start, [string[]]$Extra = @()) { return Invoke-Script $checker (@('-Repo', $Repo, '-Since', $Start) + $Extra) }

    $c = New-GitRepo 'checker'
    $baseYaml = "description: Base.`nstructure-kinds:`n  - unit-added`n  - unit-removed`n  - dependency-added`n  - dependency-removed`n  - code-moved`nstructure-requires:`n  - `"unit-added architecture/owner.md`"`n  - `"dependency-added architecture/edges.md`"`n"
    Add-RepoProfile $c 'base' $baseYaml @{ 'architecture/owner.md' = (Std 'Base owner.'); 'architecture/edges.md' = (Std 'Base edges.'); 'architecture/other.md' = (Std 'Base other.') }
    $techYaml = "description: Tech.`ninherits: base`nstructure-detectors:`n  - dotnet-projects`nstructure-requires:`n  - `"dependency-added tech/refs.md`"`n"
    Add-RepoProfile $c 'tech' $techYaml @{ 'tech/refs.md' = (Std 'Tech refs.'); 'amendments/architecture/owner.md' = (Delta 'Tech owner.' (Basis @((Std 'Base owner.')))); 'amendments/architecture/other.md' = (Delta 'Tech other.' (Basis @((Std 'Base other.')))) }
    Add-RepoProfile $c 'nodetector' "description: No detector.`ninherits: base`n" @{}
    Write-Fixture $c '.cogniva-profile.yml' "profile: tech`n"
    Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj'))
    Write-Fixture $c 'src/B/B.csproj' (Proj @())
    Write-Fixture $c 'src/C/C.csproj' (Proj @())
    Write-Fixture $c 'src/A/Foo.cs' $foo
    Commit-All $c 'init'
    $cInit = (& git -C $c rev-parse HEAD)
    $start = Start-Tree $c

    $u = Invoke-Script $checker @('-Repo', $c)
    Check 'checker: neither -Snapshot nor -Since is a usage error (exit 2)' ($u.Code -eq 2)
    $u = Invoke-Script $checker @('-Repo', $c, '-Snapshot', '-Since', $start)
    Check 'checker: -Snapshot with -Since is a usage error (exit 2)' ($u.Code -eq 2)
    $u = Invoke-Script $checker @('-Repo', $root, '-Snapshot')
    Check 'checker: a snapshot outside a git repository fails (exit 2) and prints no START_TREE' ($u.Code -eq 2 -and $u.Out -notmatch 'START_TREE')
    $u = Invoke-Script $checker @('-Repo', $c, '-Since', $start, '-Expected', 'dependency-added')
    Check 'checker: an -Expected item without paths is a usage error (exit 2)' ($u.Code -eq 2)

    $r = Check-Changes $c $start
    Check 'checker: no changes is NONE (exit 0)' ($r.Code -eq 0 -and $r.Json.Status -eq 'NONE' -and $r.Json.Reason -match 'no changes')

    Write-Fixture $c 'src/A/Foo.cs' ($foo + "// edited`n")
    $r = Check-Changes $c $start
    $text = Check-Text $c $start
    Check 'checker: an ordinary edit in a declared repo is NONE (exit 0) after the detector ran' ($r.Code -eq 0 -and $r.Json.Status -eq 'NONE' -and @($r.Json.Facts).Count -eq 0 -and @($r.Json.Detectors | Where-Object { $_.Id -eq 'dotnet-projects' -and $_.Status -eq 'ok' }).Count -eq 1)
    Check 'checker: an ordinary edit prints one line' ($text.Code -eq 0 -and @($text.Out -split "`n" | Where-Object { $_ }).Count -eq 1 -and $text.Out -match '^STRUCTURE: NONE')
    Reset-To $c $cInit

    Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
    Commit-All $c 'task 1'
    $r = Check-Changes $c $start
    $f = @($r.Json.Facts)
    Check 'checker: a committed task change is caught (FOUND, exit 4)' ($r.Code -eq 4 -and $r.Json.Status -eq 'FOUND' -and $f.Count -eq 1 -and $f[0].Kind -eq 'dependency-added' -and $f[0].Expected -eq $false)
    Check 'checker: the fact maps to the standards its kind requires' ($f.Count -eq 1 -and $f[0].Requires[0].Profile -eq 'tech' -and (@($f[0].Requires[0].Standards) -join ',') -eq 'architecture/edges.md,tech/refs.md' -and @($f[0].Blocked).Count -eq 0)
    $text = Check-Text $c $start
    Check 'checker: text output shows the fact, its evidence and what it requires' ($text.Code -eq 4 -and $text.Out -match 'FACT 1 dependency-added UNEXPECTED \(dotnet-projects\): src/A/A\.csproj -> src/C/C\.csproj' -and $text.Out -match [regex]::Escape('EVIDENCE: src/A/A.csproj adds <ProjectReference Include="..\C\C.csproj">') -and $text.Out -match 'REQUIRES \(tech\): architecture/edges\.md, tech/refs\.md')
    $text = Check-Text $c $start @('-Expected', 'dependency-added:src/A|src/C')
    Check 'checker: an expected change (kind and paths) is not marked UNEXPECTED' ($text.Code -eq 4 -and $text.Out -notmatch 'UNEXPECTED')
    Reset-To $c $cInit

    Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
    Write-Fixture $c 'src/B/B.csproj' (Proj @('..\C\C.csproj'))
    $r = Check-Changes $c $start @('-Expected', 'dependency-added:src/A|src/C')
    $fa = @($r.Json.Facts | Where-Object { $_.Units[0] -eq 'src/A/A.csproj' })
    $fb = @($r.Json.Facts | Where-Object { $_.Units[0] -eq 'src/B/B.csproj' })
    Check 'checker: an expected kind does not cover an unrelated change of the same kind' ($r.Code -eq 4 -and $fa.Count -eq 1 -and $fa[0].Expected -eq $true -and $fb.Count -eq 1 -and $fb[0].Expected -eq $false)
    Reset-To $c $cInit

    Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
    & git -C $c add src/A/A.csproj
    $r = Check-Changes $c $start
    Check 'checker: a staged change is caught' ($r.Code -eq 4 -and @($r.Json.Facts | Where-Object Kind -eq 'dependency-added').Count -eq 1)
    Reset-To $c $cInit
    Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
    $r = Check-Changes $c $start
    Check 'checker: an unstaged change is caught' ($r.Code -eq 4 -and @($r.Json.Facts | Where-Object Kind -eq 'dependency-added').Count -eq 1)
    Reset-To $c $cInit

    Write-Fixture $c 'src/D/D.csproj' (Proj @())
    $r = Check-Changes $c $start
    $f = @($r.Json.Facts)
    Check 'checker: an untracked new project is caught' ($r.Code -eq 4 -and $f.Count -eq 1 -and $f[0].Kind -eq 'unit-added' -and $f[0].Units[0] -eq 'src/D/D.csproj')
    Check 'checker: each kind requires only what it maps to' ($f.Count -eq 1 -and (@($f[0].Requires[0].Standards) -join ',') -eq 'architecture/owner.md')
    $r = Check-Changes $c 'HEAD'
    Check 'checker: -Since also takes a commit' ($r.Code -eq 4 -and @($r.Json.Facts).Count -eq 1)
    Reset-To $c $cInit

    Write-Fixture $c 'src/E/E.csproj' (Proj @())
    Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
    $dirtyStart = Start-Tree $c
    Write-Fixture $c 'src/A/Foo.cs' ($foo + "// the fix`n")
    $r = Check-Changes $c $dirtyStart
    Check 'checker: work already dirty at the start is not attributed to the fix' ($r.Code -eq 0 -and $r.Json.Status -eq 'NONE')
    $r = Check-Changes $c $start
    Check 'checker: the same work counts against an earlier start' ($r.Code -eq 4 -and @($r.Json.Facts).Count -eq 2)
    Reset-To $c $cInit

    Write-Fixture $c 'src/D/D.csproj' (Proj @())
    & git -C $c add src/D/D.csproj
    Write-Fixture $c 'src/A/Foo.cs' ($foo + "// unstaged`n")
    $statusBefore = @(& git -C $c status --porcelain) -join "`n"
    $cachedBefore = @(& git -C $c diff --cached --name-only) -join "`n"
    Check-Changes $c $start | Out-Null
    Check 'checker: the check leaves the index and working tree unchanged' ((@(& git -C $c status --porcelain) -join "`n") -eq $statusBefore -and (@(& git -C $c diff --cached --name-only) -join "`n") -eq $cachedBefore)
    Reset-To $c $cInit

    Write-Fixture $c '.cogniva/profiles/base/standards/architecture/other.md' (Std 'Base other, changed.')
    Commit-All $c 'base other changed'
    $s2 = Start-Tree $c
    Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
    $r = Check-Changes $c $s2
    Check 'checker: an unrelated stale standard does not block (FOUND, not BLOCKED)' ($r.Code -eq 4 -and @($r.Json.Facts[0].Blocked).Count -eq 0)
    Reset-To $c $cInit

    Write-Fixture $c '.cogniva/profiles/base/standards/architecture/owner.md' (Std 'Base owner, changed.')
    Commit-All $c 'base owner changed'
    $s3 = Start-Tree $c
    Write-Fixture $c 'src/D/D.csproj' (Proj @())
    $r = Check-Changes $c $s3
    Check 'checker: a stale standard the change requires blocks (BLOCKED, exit 3)' ($r.Code -eq 3 -and $r.Json.Status -eq 'BLOCKED' -and @($r.Json.Facts[0].Blocked | Where-Object Standard -eq 'architecture/owner.md').Count -eq 1)
    Write-Fixture $c '.cogniva/profiles/tech/amendments/architecture/owner.md' (Delta 'Tech owner.' (Basis @((Std 'Base owner, changed.'))))
    $r = Check-Changes $c $s3
    Check 'checker: accepting the reviewed amendment clears the block on re-check' ($r.Code -eq 4 -and @($r.Json.Facts | Where-Object { $_.Kind -eq 'unit-added' -and @($_.Blocked).Count -eq 0 }).Count -eq 1 -and @($r.Json.Facts | Where-Object { $_.Kind -eq 'profile-changed' -and $_.Expected -eq $false }).Count -eq 1)
    Reset-To $c $cInit

    Write-Fixture $c '.cogniva/profiles/tech/profile.yml' ($techYaml + "  - `"dependency-added tech/missing.md`"`n")
    Commit-All $c 'tech maps a missing standard'
    $s4 = Start-Tree $c
    Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
    $r = Check-Changes $c $s4
    Check 'checker: a required standard the profile lacks blocks (exit 3)' ($r.Code -eq 3 -and @($r.Json.Facts[0].Blocked | Where-Object { $_.Standard -eq 'tech/missing.md' -and $_.Reason -match "not in profile 'tech'" }).Count -eq 1)
    Reset-To $c $cInit

    Write-Fixture $c '.cogniva-profile.yml' "profile: nodetector`n"
    Commit-All $c 'no detector'
    $s5 = Start-Tree $c
    Write-Fixture $c 'src/D/D.csproj' (Proj @())
    $r = Check-Changes $c $s5
    Check 'checker: a profile that selects no detector is NOT-CHECKED (exit 0)' ($r.Code -eq 0 -and $r.Json.Status -eq 'NOT-CHECKED' -and $r.Json.Reason -match 'selects no structure detector')
    Reset-To $c $cInit

    Write-Fixture $c '.cogniva-profile.yml' "profile: absent`n"
    Commit-All $c 'broken marker'
    $s6 = Start-Tree $c
    Write-Fixture $c 'src/A/Foo.cs' ($foo + "// edited`n")
    $r = Check-Changes $c $s6
    Check 'checker: a declared profile in ERROR is FAILED (exit 1), even for an ordinary edit' ($r.Code -eq 1 -and $r.Json.Status -eq 'FAILED' -and (@($r.Json.Failures) -join ' ') -match "profile 'absent'")
    Reset-To $c $cInit

    $plain = New-GitRepo 'plain'
    Write-Fixture $plain 'src/A/A.csproj' (Proj @())
    Commit-All $plain 'init'
    $ps = Start-Tree $plain
    Write-Fixture $plain 'src/B/B.csproj' (Proj @())
    $r = Check-Changes $plain $ps
    Check 'checker: a repo with no profile is NOT-CHECKED (exit 0)' ($r.Code -eq 0 -and $r.Json.Status -eq 'NOT-CHECKED' -and $r.Json.Reason -match 'no architecture profile is declared')

    # Governing profiles: both ends of a dependency, and the profiles at the start.
    $strictYaml = "description: Strict.`ninherits: base`nstructure-requires:`n  - `"dependency-added strict/missing.md`"`n  - `"unit-removed strict/missing.md`"`n"
    Add-RepoProfile $c 'strict' $strictYaml @{}
    Write-Fixture $c 'src/C/.cogniva-profile.yml' "profile: strict`n"
    Commit-All $c 'C is strict'
    $cStrict = (& git -C $c rev-parse HEAD)
    $s7 = Start-Tree $c
    Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
    $r = Check-Changes $c $s7
    $f = @($r.Json.Facts | Where-Object Kind -eq 'dependency-added')
    Check 'checker: a dependency is also gated in the profile of the project it references' ($r.Code -eq 3 -and $f.Count -eq 1 -and @($f[0].Requires | Where-Object Profile -eq 'strict').Count -eq 1 -and @($f[0].Blocked | Where-Object Standard -eq 'strict/missing.md').Count -eq 1)
    Reset-To $c $cStrict
    Remove-Item -LiteralPath (Join-Path $c 'src/C') -Recurse -Force
    $r = Check-Changes $c $s7
    $f = @($r.Json.Facts | Where-Object Kind -eq 'unit-removed')
    Check 'checker: a project deleted together with its marker is gated in its starting profile' ($r.Code -eq 3 -and $f.Count -eq 1 -and @($f[0].Requires | Where-Object { $_.Profile -eq 'strict' -and $_.When -eq 'start' }).Count -eq 1 -and @($f[0].Blocked | Where-Object { $_.Standard -eq 'strict/missing.md' -and $_.When -eq 'start' }).Count -eq 1)
    $text = Check-Text $c $s7
    Check 'checker: text output says which requirement comes from the starting profile' ($text.Out -match 'REQUIRES \(strict, at start\): strict/missing\.md' -and $text.Out -match 'REQUIRE BLOCKED \(at start\): ')
    Write-Fixture $c '.cogniva/profiles/strict/standards/strict/missing.md' (Std 'Strict, now written.')
    $r = Check-Changes $c $s7
    $f = @($r.Json.Facts | Where-Object Kind -eq 'unit-removed')
    $pc = @($r.Json.Facts | Where-Object Kind -eq 'profile-changed')
    Check 'checker: adding the missing standard clears the start block on re-check' ($r.Code -eq 4 -and $f.Count -eq 1 -and @($f[0].Blocked).Count -eq 0 -and @($f[0].Requires | Where-Object { $_.Profile -eq 'strict' -and $_.When -eq 'start' }).Count -eq 1)
    Check 'checker: the profile edits are one UNEXPECTED profile-changed fact' ($pc.Count -eq 1 -and $pc[0].Expected -eq $false -and @($pc[0].Paths) -contains '.cogniva/profiles/strict/standards/strict/missing.md' -and @($pc[0].Paths) -contains 'src/C/.cogniva-profile.yml')
    Reset-To $c $cInit

    $baseStd = @{ 'architecture/owner.md' = (Std 'Base owner.'); 'architecture/edges.md' = (Std 'Base edges.'); 'architecture/other.md' = (Std 'Base other.') }
    $lo = New-GitRepo 'local-only'
    Add-RepoProfile $lo 'base' $baseYaml $baseStd
    Add-RepoProfile $lo 'tech' ($techYaml + "  - `"unit-removed tech/refs.md`"`n") @{ 'tech/refs.md' = (Std 'Tech refs.') }
    Write-Fixture $lo 'src/C/C.csproj' (Proj @())
    Write-Fixture $lo 'src/C/.cogniva-profile.yml' "profile: tech`n"
    Write-Fixture $lo 'src/D/D.csproj' (Proj @())
    Commit-All $lo 'init'
    $los = Start-Tree $lo
    Remove-Item -LiteralPath (Join-Path $lo 'src/C') -Recurse -Force
    $r = Check-Changes $lo $los
    Check 'checker: deleting the only declared folder still runs its detector (FOUND, not NOT-CHECKED)' ($r.Code -eq 4 -and @($r.Json.Facts | Where-Object { $_.Kind -eq 'unit-removed' -and @($_.Requires | Where-Object { $_.Profile -eq 'tech' -and $_.When -eq 'start' -and (@($_.Standards) -join ',') -eq 'tech/refs.md' }).Count -eq 1 }).Count -eq 1)
    $show = Invoke-Script $resolver @('-Repo', $lo, '-Target', 'src/C', '-Show', 'tech/refs.md')
    Check 'checker: the deleted path itself no longer resolves, so -Show by path fails' ($show.Code -eq 1)
    $show = Invoke-Script $resolver @('-Repo', $lo, '-Target', '.', '-Profile', 'tech', '-Show', 'tech/refs.md')
    Check 'checker: a requirement from the start is read with -Profile, though no marker names that profile now' ($show.Code -eq 0 -and $show.Out -match 'SHOW tech/refs\.md - profile tech')

    $ns = New-GitRepo 'nested'
    Add-RepoProfile $ns 'base' $baseYaml $baseStd
    Add-RepoProfile $ns 'tech' $techYaml @{ 'tech/refs.md' = (Std 'Tech refs.') }
    Write-Fixture $ns 'src/A/A.csproj' (Proj @())
    Write-Fixture $ns 'src/A/.cogniva-profile.yml' "profile: tech`n"
    Write-Fixture $ns 'src/C/C.csproj' (Proj @())
    Write-Fixture $ns 'src/C/.cogniva-profile.yml' "profile: tech`n"
    Commit-All $ns 'init'
    $nss = Start-Tree $ns
    Write-Fixture $ns 'src/Directory.Build.props' "<Project>`n  <ItemGroup>`n    <ProjectReference Include=`"C\C.csproj`" />`n  </ItemGroup>`n</Project>`n"
    $r = Check-Changes $ns $nss
    $f = @($r.Json.Facts | Where-Object Kind -eq 'dependency-added')
    Check 'checker: a shared build file above nested markers is checked by the profiles of the projects under it' ($r.Code -eq 4 -and $f.Count -eq 1 -and @($f[0].Paths) -contains 'src/A/A.csproj' -and @($f[0].Requires | Where-Object Profile -eq 'tech').Count -eq 1)

    # Detector failures are FAILED, never NONE. Fixture detectors live in -DetectorRoot.
    $fx = Join-Path $root 'detectors'
    Write-Fixture $fx 'crashes.ps1' "[Console]::Error.WriteLine('boom'); exit 1`n"
    Write-Fixture $fx 'silent.ps1' "exit 0`n"
    Write-Fixture $fx 'sloppy.ps1' "'{`"contract`":1,`"detector`":`"sloppy`",`"facts`":[{`"kind`":`"unit-added`",`"units`":[`"x`"],`"paths`":[`"x`"]}]}'`nexit 0`n"
    Write-Fixture $fx 'quiet.ps1' "'{`"contract`":1,`"detector`":`"quiet`",`"facts`":[]}'`nexit 0`n"
    foreach ($id in 'crashes', 'silent', 'sloppy', 'quiet', 'ghost') { Add-RepoProfile $c "uses-$id" "description: Uses $id.`ninherits: base`nstructure-detectors:`n  - $id`n" @{} }
    Commit-All $c 'detector fixtures'
    $cFx = (& git -C $c rev-parse HEAD)
    function Try-Detector([string]$Id) {
        Write-Fixture $c '.cogniva-profile.yml' "profile: uses-$Id`n"
        Commit-All $c "use $Id"
        $s = Start-Tree $c
        Write-Fixture $c 'src/A/Foo.cs' ($foo + "// edited`n")
        $res = Check-Changes $c $s @('-DetectorRoot', $fx)
        Reset-To $c $cFx
        return $res
    }
    $r = Try-Detector 'quiet'
    Check 'checker: a detector reporting an empty list is NONE (exit 0)' ($r.Code -eq 0 -and $r.Json.Status -eq 'NONE')
    $r = Try-Detector 'crashes'
    Check 'checker: a detector that exits non-zero is FAILED (exit 1), never NONE' ($r.Code -eq 1 -and $r.Json.Status -eq 'FAILED' -and $r.Json.Detectors[0].Status -eq 'failed' -and $r.Json.Detectors[0].Reason -match 'exited 1' -and $r.Json.Detectors[0].Reason -match 'boom')
    $r = Try-Detector 'silent'
    Check 'checker: a detector that prints no report is FAILED' ($r.Code -eq 1 -and $r.Json.Detectors[0].Reason -match 'no JSON report')
    $r = Try-Detector 'sloppy'
    Check 'checker: a fact without evidence breaks the contract (FAILED)' ($r.Code -eq 1 -and $r.Json.Detectors[0].Reason -match 'broke its contract: a unit-added fact has no evidence')
    $r = Try-Detector 'ghost'
    Check 'checker: a detector the plugin does not ship is FAILED' ($r.Code -eq 1 -and $r.Json.Detectors[0].Reason -match "detector 'ghost'.*is not in")

    # --- sections appended by later tasks go above this line ---
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All structural-changes assertions passed.'
exit 0
