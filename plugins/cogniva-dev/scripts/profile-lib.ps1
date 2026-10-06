#Requires -Version 7.0
# Architecture-profile core: strict YAML-subset reader, on-demand profile
# loading, inheritance, standards merging, marker walk, and suggestions.
# Dot-sourced by resolve-architecture-profile.ps1 and adopt-architecture-profile.ps1.
# Every failure throws a ProfileError whose message names the file (and line).

$script:MarkerName = '.cogniva-profile.yml'
$script:RepoProfilesRelative = '.cogniva/profiles'
$script:MaxChainDepth = 8
$script:ProfileIdPattern = '^[a-z0-9][a-z0-9-]*$'
# Same rule .NET uses for paths: case-sensitive on Linux, insensitive on Windows and macOS.
$script:PathComparison = if ($IsLinux) { [StringComparison]::Ordinal } else { [StringComparison]::OrdinalIgnoreCase }

function Throw-ProfileError([string]$Message) { throw [System.InvalidOperationException]::new("ProfileError: $Message") }

# Every profile reference - folder name, marker value, inherits, -Profile - must
# be a lowercase id. 'none' is only meaningful in a marker.
function Assert-ProfileId([string]$Id, [string]$Where, [switch]$AllowNone) {
    if ($AllowNone -and $Id -ceq 'none') { return }
    if ($Id -ceq 'none') { Throw-ProfileError "${Where}: 'none' is reserved for .cogniva-profile.yml markers" }
    if ($Id -cnotmatch $script:ProfileIdPattern) { Throw-ProfileError "${Where}: '$Id' is not a valid profile id (lowercase letters, digits and '-', starting with a letter or digit)" }
}

function Test-SamePath([string]$A, [string]$B) {
    return [string]::Equals($A.TrimEnd('\', '/'), $B.TrimEnd('\', '/'), $script:PathComparison)
}

# True when $Full is $Root or below it, using the platform's path casing rules.
function Test-PathInside([string]$Root, [string]$Full) {
    $relative = [System.IO.Path]::GetRelativePath($Root, $Full)
    if ($relative -eq '.') { return $true }
    if ([System.IO.Path]::IsPathRooted($relative)) { return $false }
    return -not ($relative -eq '..' -or $relative.StartsWith('..\') -or $relative.StartsWith('../'))
}

function ConvertFrom-ScalarText([string]$Raw, [string]$Where) {
    $text = $Raw.Trim()
    if ($text.Length -eq 0) { Throw-ProfileError "${Where}: empty value" }
    $quote = $text[0]
    # Quoted values are taken literally. YAML escape sequences (\" or '') are not
    # currently supported, so a value cannot contain its own quote character.
    if ($quote -eq '"' -or $quote -eq "'") {
        $close = $text.IndexOf($quote, 1)
        if ($close -lt 0) { Throw-ProfileError "${Where}: unterminated quoted value" }
        $rest = $text.Substring($close + 1).Trim()
        if ($rest.Length -gt 0 -and -not $rest.StartsWith('#')) { Throw-ProfileError "${Where}: unexpected text after quoted value" }
        return $text.Substring(1, $close - 1)
    }
    $hash = $text.IndexOf(' #')
    if ($hash -ge 0) { $text = $text.Substring(0, $hash).TrimEnd() }
    if ($text -match '^[\[\{&*!|>]') { Throw-ProfileError "${Where}: unsupported YAML construct '$($text[0])'" }
    return $text
}

# Strict subset: blank lines, '#' comment lines, top-level `key: scalar`, and
# `key:` followed by indented `- scalar` items. Anything else is an error.
function ConvertFrom-CognivaYaml([string[]]$Lines, [string]$Source, [int]$LineOffset = 0) {
    $result = [ordered]@{}
    $listKey = $null
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        $where = "${Source}:$($i + 1 + $LineOffset)"
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }
        if ($line -match '^ *\t') { Throw-ProfileError "${where}: tab indentation is not allowed" }
        if ($line -match '^\s+-\s+(?<item>.*)$') {
            if (-not $listKey) { Throw-ProfileError "${where}: list item without a list key" }
            $result[$listKey] += @(ConvertFrom-ScalarText $Matches['item'] $where)
            continue
        }
        if ($line -match '^(?<key>[a-z][a-z0-9-]*):(?<value>.*)$') {
            $key = $Matches['key']
            $value = $Matches['value']
            if ($result.Contains($key)) { Throw-ProfileError "${where}: duplicate key '$key'" }
            if ($value.Trim().Length -eq 0 -or $value.Trim().StartsWith('#')) {
                $result[$key] = @()
                $listKey = $key
            }
            else {
                if ($value -notmatch '^\s') { Throw-ProfileError "${where}: expected a space after ':'" }
                $result[$key] = ConvertFrom-ScalarText $value $where
                $listKey = $null
            }
            continue
        }
        Throw-ProfileError "${where}: unsupported line (only 'key: value' and '- item' lists are allowed)"
    }
    foreach ($key in @($result.Keys)) {
        if ($result[$key] -is [array] -and $result[$key].Count -eq 0) { Throw-ProfileError "${Source}: key '$key' has no value" }
    }
    return $result
}

function Read-TextLines([string]$Path) {
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    return @($text -split "`r?`n")
}

function Read-CognivaYamlFile([string]$Path, [string[]]$AllowedKeys, [string[]]$RequiredKeys, [string]$Display) {
    $data = ConvertFrom-CognivaYaml (Read-TextLines $Path) $Display
    foreach ($key in $data.Keys) {
        if ($AllowedKeys -notcontains $key) { Throw-ProfileError "${Display}: unknown key '$key' (allowed: $($AllowedKeys -join ', '))" }
    }
    foreach ($key in $RequiredKeys) {
        if (-not $data.Contains($key)) { Throw-ProfileError "${Display}: missing required key '$key'" }
    }
    return $data
}

# Returns the frontmatter `description`, or $null when the file has none.
function Read-StandardDescription([string]$Path, [string]$Display, [System.Collections.Generic.List[string]]$Warnings) {
    $lines = Read-TextLines $Path
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $null }
    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '---') { $end = $i; break } }
    if ($end -lt 0) { Throw-ProfileError "${Display}: frontmatter is not closed with '---'" }
    $body = if ($end -gt 1) { $lines[1..($end - 1)] } else { @() }
    $data = ConvertFrom-CognivaYaml $body $Display 1
    foreach ($key in $data.Keys) {
        if ($key -ne 'description') { $Warnings.Add("${Display}: frontmatter key '$key' is ignored") }
    }
    if ($data.Contains('description') -and $data['description'] -is [string]) { return $data['description'] }
    return $null
}

function Get-RelativeDisplay([string]$Root, [string]$Path) {
    return [System.IO.Path]::GetRelativePath($Root, $Path).Replace('\', '/')
}

# A folder of profiles (the repo's .cogniva/profiles or the plugin library),
# loaded one profile at a time so a broken profile only affects its users.
function New-ProfileSource([string]$Root, [string]$DisplayRoot) {
    return [pscustomobject]@{ Root = $Root; Display = $DisplayRoot; Cache = @{} }
}

# Returns the profile entry, $null when the folder does not exist, or throws when it is malformed.
function Get-ProfileEntry($Source, [string]$Id) {
    if ($Source.Cache.ContainsKey($Id)) { return $Source.Cache[$Id] }
    $dir = Join-Path $Source.Root $Id
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return $null }
    # Read the on-disk casing from the parent's listing: Get-Item echoes the
    # typed casing on some hosts (Windows PowerShell 5.1, older pwsh), which
    # would let 'mixed' resolve to a 'Mixed' folder.
    $onDisk = @(Get-ChildItem -LiteralPath $Source.Root -Directory | Where-Object { $_.Name -eq $Id } | ForEach-Object { $_.Name })
    if ($onDisk -cnotcontains $Id) { Throw-ProfileError "$($Source.Display)/$($onDisk[0]): profile folder names must be lowercase ('$Id')" }
    $display = "$($Source.Display)/$Id/profile.yml"
    $file = Join-Path $dir 'profile.yml'
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { Throw-ProfileError "${display}: missing" }
    $data = Read-CognivaYamlFile $file @('description', 'inherits', 'detect') @('description') $display
    if ($data['description'] -isnot [string]) { Throw-ProfileError "${display}: 'description' must be a single value" }
    $inherits = $null
    if ($data.Contains('inherits')) {
        if ($data['inherits'] -isnot [string]) { Throw-ProfileError "${display}: 'inherits' must be a single profile id" }
        Assert-ProfileId $data['inherits'] "$display inherits"
        $inherits = $data['inherits']
    }
    $entry = [pscustomobject]@{
        Id = $Id; Path = $dir; Display = "$($Source.Display)/$Id"
        Description = $data['description']; Inherits = $inherits
        Detect = if ($data.Contains('detect')) { @($data['detect']) } else { @() }
    }
    $Source.Cache[$Id] = $entry
    return $entry
}

# Every loadable profile in a source, for suggestions. Broken or badly named
# folders are skipped with a warning rather than failing the caller.
function Get-AllProfileEntries($Source, [System.Collections.Generic.List[string]]$Warnings) {
    $entries = @()
    if (-not (Test-Path -LiteralPath $Source.Root -PathType Container)) { return $entries }
    foreach ($dir in Get-ChildItem -LiteralPath $Source.Root -Directory | Sort-Object Name) {
        if ($dir.Name -cnotmatch $script:ProfileIdPattern) {
            if (-not $dir.Name.StartsWith('.')) { $Warnings.Add("$($Source.Display)/$($dir.Name): not a valid profile id (skipped for suggestions)") }
            continue
        }
        if ($dir.Name -ceq 'none') { $Warnings.Add("$($Source.Display)/none: 'none' is reserved for .cogniva-profile.yml markers (skipped for suggestions)"); continue }
        try { $entries += Get-ProfileEntry $Source $dir.Name }
        catch { $Warnings.Add(($_.Exception.Message -replace '^ProfileError: ', '') + ' (skipped for suggestions)') }
    }
    return $entries
}

# Child first: @('python', 'cogniva-base').
function Resolve-ProfileChain([string]$Id, $Source, $Library, [string]$Origin) {
    $chain = [System.Collections.Generic.List[string]]::new()
    $cursor = $Id
    $from = $Origin
    while ($cursor) {
        if ($chain.Contains($cursor)) { Throw-ProfileError "inheritance cycle: $(($chain + $cursor) -join ' -> ')" }
        if ($chain.Count -ge $script:MaxChainDepth) { Throw-ProfileError "inheritance deeper than $($script:MaxChainDepth) from '$Id'" }
        $entry = Get-ProfileEntry $Source $cursor
        if (-not $entry) {
            $hint = ''
            if ($Library) {
                try { if (Get-ProfileEntry $Library $cursor) { $hint = " It exists in the plugin library; adopt it with adopt-architecture-profile.ps1 -Profile $cursor." } } catch { }
            }
            Throw-ProfileError "${from}: profile '$cursor' is not in $($Source.Display).$hint"
        }
        $chain.Add($cursor)
        $from = "$($entry.Display)/profile.yml"
        $cursor = $entry.Inherits
    }
    return @($chain)
}

# Merges standards from the root ancestor down; a child's same relative path
# (compared case-insensitively) replaces the parent's and records the override.
function Get-MergedStandards([string[]]$Chain, $Source, [System.Collections.Generic.List[string]]$Warnings) {
    $merged = [ordered]@{}
    for ($c = $Chain.Count - 1; $c -ge 0; $c--) {
        $entry = Get-ProfileEntry $Source $Chain[$c]
        $standardsRoot = Join-Path $entry.Path 'standards'
        if (-not (Test-Path -LiteralPath $standardsRoot -PathType Container)) { continue }
        $seen = @{}
        foreach ($file in Get-ChildItem -LiteralPath $standardsRoot -Recurse -File -Filter '*.md' | Sort-Object FullName) {
            $id = Get-RelativeDisplay $standardsRoot $file.FullName
            $key = $id.ToLowerInvariant()
            $display = "$($entry.Display)/standards/$id"
            if ($seen.ContainsKey($key)) { Throw-ProfileError "${display}: collides with $($seen[$key]) (standard paths are compared case-insensitively)" }
            $seen[$key] = $display
            $description = Read-StandardDescription $file.FullName $display $Warnings
            # Descriptions are what agents choose standards by, so a standard without one is unusable.
            if (-not $description) { Throw-ProfileError "${display}: missing frontmatter 'description' (agents choose which standards to open from it)" }
            $overrides = @()
            if ($merged.Contains($key)) { $overrides = @($merged[$key].Overrides) + @($merged[$key].From) }
            $merged[$key] = [pscustomobject]@{
                Id = $id; Description = $description; From = $entry.Id
                Overrides = @($overrides); Path = $file.FullName
            }
        }
    }
    return @($merged.Values | Sort-Object { $_.Id.ToLowerInvariant() })
}

# Directories from the target's nearest existing directory up to the repo root, nearest first.
function Get-DirectoryWalk([string]$RepoRoot, [string]$TargetFull) {
    $cursor = $TargetFull
    if (Test-Path -LiteralPath $cursor -PathType Leaf) { $cursor = Split-Path -Parent $cursor }
    while (-not (Test-Path -LiteralPath $cursor -PathType Container)) { $cursor = Split-Path -Parent $cursor }
    $dirs = [System.Collections.Generic.List[string]]::new()
    while ($true) {
        $dirs.Add($cursor)
        if (Test-SamePath $cursor $RepoRoot) { break }
        $parent = Split-Path -Parent $cursor
        if (-not $parent -or $parent -eq $cursor) { break }
        $cursor = $parent
    }
    return @($dirs)
}

# Nearest first: @({ Source, Profile, Kind, Error }). A malformed marker throws,
# unless -Tolerant (an explicit -Profile overrides every marker anyway): then it
# is returned with Profile $null and its Error so the caller can report it.
function Get-ProfileMarkers([string]$RepoRoot, [string[]]$Walk, [switch]$Tolerant) {
    $markers = @()
    foreach ($dir in $Walk) {
        $file = Join-Path $dir $script:MarkerName
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
        $display = Get-RelativeDisplay $RepoRoot $file
        $kind = if (Test-SamePath $dir $RepoRoot) { 'repo-default' } else { 'path-override' }
        try {
            $data = Read-CognivaYamlFile $file @('profile') @('profile') $display
            if ($data['profile'] -isnot [string]) { Throw-ProfileError "${display}: 'profile' must be a single profile id" }
            Assert-ProfileId $data['profile'] $display -AllowNone
            $markers += [pscustomobject]@{ Source = $display; Profile = $data['profile']; Kind = $kind; Error = $null }
        }
        catch {
            if (-not $Tolerant) { throw }
            $markers += [pscustomobject]@{ Source = $display; Profile = $null; Kind = $kind; Error = ($_.Exception.Message -replace '^ProfileError: ', '') }
        }
    }
    return @($markers)
}

# First directory (nearest first) with any detect hit decides: one profile -> SUGGESTED, several -> AMBIGUOUS.
function Get-ProfileSuggestion([string]$RepoRoot, [string[]]$Walk, [object[]]$LibraryEntries) {
    if (-not $LibraryEntries -or $LibraryEntries.Count -eq 0) { return $null }
    foreach ($dir in $Walk) {
        $hits = [ordered]@{}
        foreach ($entry in $LibraryEntries | Sort-Object Id) {
            foreach ($pattern in $entry.Detect) {
                foreach ($file in Get-ChildItem -LiteralPath $dir -File -Filter $pattern -Force -ErrorAction SilentlyContinue | Sort-Object Name) {
                    if (-not $hits.Contains($entry.Id)) { $hits[$entry.Id] = @() }
                    $hits[$entry.Id] += @(Get-RelativeDisplay $RepoRoot $file.FullName)
                }
            }
        }
        if ($hits.Count -eq 0) { continue }
        return [pscustomobject]@{
            Status = if ($hits.Count -eq 1) { 'SUGGESTED' } else { 'AMBIGUOUS' }
            Profiles = @($hits.Keys)
            Evidence = @($hits.Values | ForEach-Object { $_ } | Select-Object -Unique)
        }
    }
    return $null
}
