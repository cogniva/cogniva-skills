#Requires -Version 7.0
# Structure detector for .NET (contract 1; see docs/architecture-profiles.md).
# A unit is a project file (*.csproj, *.fsproj, *.vbproj). Between two git trees
# it reports:
# - unit-added / unit-removed: a project file appears or disappears (a renamed
#   or moved project file is both);
# - dependency-added / dependency-removed: a literal <ProjectReference Include>
#   appears or disappears in a project file, or in a Directory.Build.props or
#   .targets file (which applies to every project under its folder);
# - code-moved: files renamed from one project's folder into another's, and -
#   as a possible move - a file deleted from one project while a file with the
#   same name is added to another. A file belongs to the project in its nearest
#   folder that holds one; files that move with their project are not reported.
# Each fact's paths are every path whose profile governs it: both ends of a
# reference, and every project under a Directory.Build file's folder.
# Facts only: it never reads a profile or decides what is allowed. It does not
# evaluate MSBuild: other imported files, conditions and items added by targets
# are not followed, and an Include that uses a property or wildcard is reported
# as written, marked (unevaluated).
# Exit 0 with the JSON report on stdout; any failure exits 1 with the reason on stderr.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Base,
    [Parameter(Mandatory)][string]$Head
)
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'structure-lib.ps1')

$projectPattern = '(?i)\.(cs|fs|vb)proj$'
$buildFilePattern = '(?i)(^|/)Directory\.Build\.(props|targets)$'

function Get-Dir([string]$Path) {
    $i = $Path.LastIndexOf('/')
    if ($i -lt 0) { return '' }
    return $Path.Substring(0, $i)
}
function Get-Leaf([string]$Path) { return $Path.Substring($Path.LastIndexOf('/') + 1) }
function Test-ReferenceFile([string]$Path) { return [bool]($Path -and ($Path -match $projectPattern -or $Path -match $buildFilePattern)) }

# Every file path in a tree, read once per tree.
$treePaths = @{}
function Get-PathsOf([string]$Tree) {
    if (-not $script:treePaths.ContainsKey($Tree)) { $script:treePaths[$Tree] = @(Get-TreePaths $Repo $Tree) }
    return $script:treePaths[$Tree]
}
# Project files at or below $Dir in $Tree ('' = the repository root).
function Get-ProjectsUnder([string]$Tree, [string]$Dir) {
    $prefix = if ($Dir) { "$Dir/" } else { '' }
    return @(Get-PathsOf $Tree | Where-Object { $_ -match $projectPattern -and $_.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) })
}
# The paths whose profiles govern one reference: the file declaring it, every
# project a Directory.Build file applies to, and the referenced project when literal.
function Get-ReferencePaths([string]$Tree, [string]$File, $Ref) {
    $paths = @($File)
    if ($File -match $buildFilePattern) { $paths += @(Get-ProjectsUnder $Tree (Get-Dir $File)) }
    if (-not $Ref.Target.StartsWith('(unevaluated)')) { $paths += $Ref.Target }
    return @($paths | Select-Object -Unique)
}

# Repo-relative '/' path of $Relative joined to $Dir, or $null when it is rooted
# or climbs above the repository.
function Join-RepoPath([string]$Dir, [string]$Relative) {
    if ([System.IO.Path]::IsPathRooted($Relative) -or $Relative -match '^[A-Za-z]:') { return $null }
    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($seg in (($Dir + '/' + $Relative).Replace('\', '/') -split '/')) {
        if ($seg -eq '' -or $seg -eq '.') { continue }
        if ($seg -eq '..') {
            if ($parts.Count -eq 0) { return $null }
            $parts.RemoveAt($parts.Count - 1)
            continue
        }
        $parts.Add($seg)
    }
    return ($parts -join '/')
}

# The ProjectReference targets a file declares, keyed case-insensitively: the
# repo-relative project path, or "(unevaluated) <Include>" when the Include is not
# a literal relative path. XML comments are ignored.
function Get-ProjectReferences([string]$Text, [string]$FilePath) {
    $refs = [ordered]@{}
    if ($null -eq $Text) { return $refs }
    $clean = [regex]::Replace($Text, '<!--.*?-->', '', 'Singleline')
    foreach ($m in [regex]::Matches($clean, '<ProjectReference\b[^>]*?\bInclude\s*=\s*("([^"]*)"|''([^'']*)'')', 'IgnoreCase')) {
        $include = if ($m.Groups[2].Success) { $m.Groups[2].Value } else { $m.Groups[3].Value }
        foreach ($one in @($include -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
            $target = if ($one -match '[$*?%@]') { $null } else { Join-RepoPath (Get-Dir $FilePath) $one }
            $key = if ($target) { $target } else { "(unevaluated) $one" }
            if (-not $refs.Contains($key.ToLowerInvariant())) { $refs[$key.ToLowerInvariant()] = [pscustomobject]@{ Target = $key; Include = $one } }
        }
    }
    return $refs
}

# Folder (lowercase) -> the project file it holds (first in sorted order).
function Get-ProjectDirs([string[]]$Paths) {
    $dirs = @{}
    foreach ($p in @($Paths | Where-Object { $_ -match $projectPattern } | Sort-Object)) {
        $key = (Get-Dir $p).ToLowerInvariant()
        if (-not $dirs.ContainsKey($key)) { $dirs[$key] = $p }
    }
    return $dirs
}
function Get-OwningProject([hashtable]$Dirs, [string]$Path) {
    $dir = Get-Dir $Path
    while ($true) {
        if ($Dirs.ContainsKey($dir.ToLowerInvariant())) { return $Dirs[$dir.ToLowerInvariant()] }
        if ($dir -eq '') { return $null }
        $dir = Get-Dir $dir
    }
}

try {
    $changes = @(Get-TreeChanges $Repo $Base $Head)
    $facts = [System.Collections.Generic.List[object]]::new()

    # Units added and removed.
    $projectRenames = @{}
    foreach ($c in $changes) {
        $old = if ($c.Status -eq 'R') { $c.OldPath } elseif ($c.Status -eq 'D') { $c.Path } else { $null }
        $new = if ($c.Status -in 'A', 'R') { $c.Path } else { $null }
        if ($old -and $old -match $projectPattern) {
            $why = if ($c.Status -eq 'R') { "project file $old was renamed to $new" } else { "project file $old was removed" }
            $facts.Add((New-StructureFact 'unit-removed' @($old) @($old) $why))
        }
        if ($new -and $new -match $projectPattern) {
            $why = if ($c.Status -eq 'R') { "project file $new was renamed from $old" } else { "project file $new was added" }
            $facts.Add((New-StructureFact 'unit-added' @($new) @($new) $why))
        }
        if ($c.Status -eq 'R' -and $old -match $projectPattern -and $new -match $projectPattern) { $projectRenames[$old.ToLowerInvariant()] = $new }
    }

    # Dependencies. A removed project's own references go with it (its
    # unit-removed fact covers them); an added project's references are all new;
    # a removed Directory.Build file removes its references from every project under it.
    foreach ($c in $changes) {
        if ($c.Status -eq 'D') {
            if ($c.Path -match $buildFilePattern) {
                $gone = Get-ProjectReferences (Get-TreeFileText $Repo $Base $c.Path) $c.Path
                $scope = " (applied to every project under $(if (Get-Dir $c.Path) { Get-Dir $c.Path } else { 'the repository root' }))"
                foreach ($t in $gone.Values) { $facts.Add((New-StructureFact 'dependency-removed' @($c.Path, $t.Target) (Get-ReferencePaths $Base $c.Path $t) "$($c.Path) was removed with <ProjectReference Include=`"$($t.Include)`">$scope")) }
            }
            continue
        }
        $newPath = $c.Path
        if (-not (Test-ReferenceFile $newPath)) { continue }
        $oldPath = if ($c.Status -eq 'R') { $c.OldPath } elseif ($c.Status -in 'M', 'T') { $c.Path } else { $null }
        $before = if (Test-ReferenceFile $oldPath) { Get-ProjectReferences (Get-TreeFileText $Repo $Base $oldPath) $oldPath } else { [ordered]@{} }
        $after = Get-ProjectReferences (Get-TreeFileText $Repo $Head $newPath) $newPath
        $scope = if ($newPath -match $buildFilePattern) { " (applies to every project under $(if (Get-Dir $newPath) { Get-Dir $newPath } else { 'the repository root' }))" } else { '' }
        foreach ($k in @($after.Keys)) {
            if ($before.Contains($k)) { continue }
            $t = $after[$k]
            $facts.Add((New-StructureFact 'dependency-added' @($newPath, $t.Target) (Get-ReferencePaths $Head $newPath $t) "$newPath adds <ProjectReference Include=`"$($t.Include)`">$scope"))
        }
        foreach ($k in @($before.Keys)) {
            if ($after.Contains($k)) { continue }
            $t = $before[$k]
            $facts.Add((New-StructureFact 'dependency-removed' @($newPath, $t.Target) (Get-ReferencePaths $Head $newPath $t) "$newPath removes <ProjectReference Include=`"$($t.Include)`">$scope"))
        }
    }

    # Code moved between projects: renamed files whose owning project differs,
    # plus possible moves git did not pair as renames because the file was also
    # rewritten - a file deleted from one project while a file with the same
    # name is added to another. One fact per pair of projects.
    $moves = @($changes | Where-Object { $_.Status -eq 'R' -and -not (Test-ReferenceFile $_.Path) -and -not (Test-ReferenceFile $_.OldPath) } | ForEach-Object { [pscustomobject]@{ OldPath = $_.OldPath; Path = $_.Path; Possible = $false } })
    $deleted = @($changes | Where-Object { $_.Status -eq 'D' -and -not (Test-ReferenceFile $_.Path) })
    $added = @($changes | Where-Object { $_.Status -eq 'A' -and -not (Test-ReferenceFile $_.Path) })
    foreach ($del in $deleted) {
        $name = Get-Leaf $del.Path
        foreach ($add in @($added | Where-Object { (Get-Leaf $_.Path) -ieq $name })) { $moves += [pscustomobject]@{ OldPath = $del.Path; Path = $add.Path; Possible = $true } }
    }
    if ($moves.Count) {
        $baseDirs = Get-ProjectDirs @(Get-PathsOf $Base)
        $headDirs = Get-ProjectDirs @(Get-PathsOf $Head)
        $groups = [ordered]@{}
        foreach ($c in $moves) {
            $from = Get-OwningProject $baseDirs $c.OldPath
            $to = Get-OwningProject $headDirs $c.Path
            if (-not $from -or -not $to -or $from -ieq $to) { continue }
            if ($projectRenames.ContainsKey($from.ToLowerInvariant()) -and $projectRenames[$from.ToLowerInvariant()] -ieq $to) { continue }
            $key = "$from|$to".ToLowerInvariant()
            if (-not $groups.Contains($key)) { $groups[$key] = [pscustomobject]@{ From = $from; To = $to; Moves = [System.Collections.Generic.List[object]]::new() } }
            $groups[$key].Moves.Add($c)
        }
        foreach ($g in $groups.Values) {
            $paths = @($g.Moves | ForEach-Object { $_.OldPath; $_.Path })
            $first = $g.Moves[0]
            $more = if ($g.Moves.Count -gt 1) { " and $($g.Moves.Count - 1) more" } else { '' }
            $possible = @($g.Moves | Where-Object Possible).Count
            $note = if ($possible) { " ($possible possible move(s): a file deleted from one project and a file with the same name added to the other, not paired by git as a rename)" } else { '' }
            $facts.Add((New-StructureFact 'code-moved' @($g.From, $g.To) $paths "$($g.Moves.Count) file(s) moved from $($g.From) to $($g.To): $($first.OldPath) -> $($first.Path)$more$note"))
        }
    }

    Write-DetectorReport 'dotnet-projects' @($facts)
    exit 0
}
catch {
    [Console]::Error.WriteLine("dotnet-projects: $($_.Exception.Message -replace '^StructureError: ', '')")
    exit 1
}
