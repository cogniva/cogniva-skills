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

    # --- sections appended by later tasks go above this line ---
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All structural-changes assertions passed.'
exit 0
