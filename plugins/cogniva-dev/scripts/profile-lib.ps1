#Requires -Version 7.0
# Architecture-profile core: strict YAML-subset reader, on-demand profile
# loading, inheritance, delta composition (amendments and replacement standards
# with their basis and review state), text normalisation and hashing, globs,
# ownership, marker walk, and suggestions.
# Dot-sourced by resolve-architecture-profile.ps1 and adopt-architecture-profile.ps1.
# Every failure throws a ProfileError whose message names the file (and line).

$script:MarkerName = '.cogniva-profile.yml'
$script:RepoProfilesRelative = '.cogniva/profiles'
# Adoption records: .cogniva/adopted/<id>.yml marks a library profile's adopted copy.
$script:AdoptedRelative = '.cogniva/adopted'
# basis: the first 12 lowercase hex characters of a SHA-256.
$script:BasisPattern = '^[0-9a-f]{12}$'
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

# Frontmatter of a standard, amendment or replacement standard. Description is
# $null when absent; Basis is $null when absent; AppliesTo is @() when absent.
# -Delta: the file is in amendments/ or replacements/, where `basis` belongs.
function Read-StandardFrontmatter([string]$Path, [string]$Display, [System.Collections.Generic.List[string]]$Warnings, [switch]$Delta) {
    $result = [pscustomobject]@{ Description = $null; Basis = $null; AppliesTo = @() }
    $lines = Read-TextLines $Path
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $result }
    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '---') { $end = $i; break } }
    if ($end -lt 0) { Throw-ProfileError "${Display}: frontmatter is not closed with '---'" }
    $body = if ($end -gt 1) { $lines[1..($end - 1)] } else { @() }
    $data = ConvertFrom-CognivaYaml $body $Display 1
    foreach ($key in $data.Keys) {
        $value = $data[$key]
        if ($key -eq 'description') {
            if ($value -is [string]) { $result.Description = $value }
        }
        elseif ($key -eq 'basis') {
            if (-not $Delta) { $Warnings.Add("${Display}: frontmatter key 'basis' is ignored outside amendments/ and replacements/") }
            elseif ($value -isnot [string] -or $value -cnotmatch $script:BasisPattern) { Throw-ProfileError "${Display}: 'basis' must be 12 lowercase hex characters" }
            else { $result.Basis = $value }
        }
        elseif ($key -eq 'applies-to') {
            # Globs are repo-relative: a rooted glob or a '..' segment could match outside the repo.
            $globs = @($value)
            foreach ($glob in $globs) {
                if ([System.IO.Path]::IsPathRooted($glob) -or $glob.StartsWith('/') -or $glob.StartsWith('\') -or @($glob -split '[\\/]') -contains '..') {
                    Throw-ProfileError "${Display}: applies-to globs are repo-relative"
                }
            }
            $result.AppliesTo = $globs
        }
        else { $Warnings.Add("${Display}: frontmatter key '$key' is ignored") }
    }
    return $result
}

# Normalised text, the input to every basis and adoption hash: no BOM, LF line
# endings, no `basis:` lines (so re-acknowledging an ancestor never makes its
# descendants stale), no trailing whitespace, no trailing blank lines.
function Get-NormalisedText([string]$Text) {
    if ($Text.Length -gt 0 -and $Text[0] -eq [char]0xFEFF) { $Text = $Text.Substring(1) }
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (($Text -replace "`r`n", "`n") -replace "`r", "`n") -split "`n") {
        if ($line -cmatch '^basis:') { continue }
        $lines.Add($line.TrimEnd())
    }
    while ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Length -eq 0) { $lines.RemoveAt($lines.Count - 1) }
    return ($lines -join "`n")
}

# basis / content hash: first 12 lowercase hex characters of SHA-256 over UTF-8.
function Get-TextHash([string]$Text) {
    $hash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($Text))
    return [System.Convert]::ToHexString($hash).ToLowerInvariant().Substring(0, 12)
}

function Read-NormalisedFile([string]$Path) {
    return Get-NormalisedText ([System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false)))
}

# One hash for a whole profile folder: every file, ordinal path order.
function Get-TreeHash([string]$Root) {
    $files = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File -Force) { $files[(Get-RelativeDisplay $Root $file.FullName)] = $file.FullName }
    $names = [string[]]@($files.Keys)
    [System.Array]::Sort($names, [System.StringComparer]::Ordinal)
    return Get-TextHash ((@($names | ForEach-Object { "$_`n$(Read-NormalisedFile $files[$_])" })) -join "`n`0`n")
}

# Repo-relative glob: '*' within one segment, '**' zero or more whole segments.
# Case follows the platform path rule (as $script:PathComparison).
function Test-GlobMatch([string]$Glob, [string]$Path) {
    $g = @($Glob.Replace('\', '/').Trim('/') -split '/' | Where-Object { $_ })
    $p = @($Path.Replace('\', '/').Trim('/') -split '/' | Where-Object { $_ -and $_ -ne '.' })
    return (Test-GlobSegments $g 0 $p 0)
}
function Test-GlobSegments([string[]]$G, [int]$GIndex, [string[]]$P, [int]$PIndex) {
    if ($GIndex -eq $G.Count) { return $PIndex -eq $P.Count }
    if ($G[$GIndex] -eq '**') {
        for ($k = $PIndex; $k -le $P.Count; $k++) { if (Test-GlobSegments $G ($GIndex + 1) $P $k) { return $true } }
        return $false
    }
    if ($PIndex -eq $P.Count) { return $false }
    $pattern = '^' + ([regex]::Escape($G[$GIndex]) -replace '\\\*', '[^/]*') + '$'
    $options = if ($IsLinux) { [System.Text.RegularExpressions.RegexOptions]::None } else { [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
    if (-not [regex]::IsMatch($P[$PIndex], $pattern, $options)) { return $false }
    return (Test-GlobSegments $G ($GIndex + 1) $P ($PIndex + 1))
}

# 'library' for the plugin library and for an adopted copy (it has an adoption
# record in .cogniva/adopted); every other profile in a repo is 'repo-owned'.
function Get-ProfileOwnership($Source, [string]$Id) {
    if ($Source.IsLibrary) { return 'library' }
    if ($Source.RecordsRoot -and (Test-Path -LiteralPath (Join-Path $Source.RecordsRoot "$Id.yml") -PathType Leaf)) { return 'library' }
    return 'repo-owned'
}

function Get-RelativeDisplay([string]$Root, [string]$Path) {
    return [System.IO.Path]::GetRelativePath($Root, $Path).Replace('\', '/')
}

# A folder of profiles (the repo's .cogniva/profiles or the plugin library),
# loaded one profile at a time so a broken profile only affects its users.
# RecordsRoot is the repo's .cogniva/adopted folder (ownership); -IsLibrary marks the plugin library.
function New-ProfileSource([string]$Root, [string]$DisplayRoot, [string]$RecordsRoot, [switch]$IsLibrary) {
    return [pscustomobject]@{ Root = $Root; Display = $DisplayRoot; RecordsRoot = $RecordsRoot; IsLibrary = [bool]$IsLibrary; Cache = @{} }
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

# The *.md files under <profile>/<Folder>, keyed by lowercased id (the path
# relative to that folder): ids are compared case-insensitively.
function Get-ProfileFiles($Entry, [string]$Folder, [System.Collections.Generic.List[string]]$Warnings) {
    $files = [ordered]@{}
    $folderRoot = Join-Path $Entry.Path $Folder
    if (-not (Test-Path -LiteralPath $folderRoot -PathType Container)) { return $files }
    foreach ($file in Get-ChildItem -LiteralPath $folderRoot -Recurse -File -Filter '*.md' | Sort-Object FullName) {
        $id = Get-RelativeDisplay $folderRoot $file.FullName
        $key = $id.ToLowerInvariant()
        $display = "$($Entry.Display)/$Folder/$id"
        if ($files.Contains($key)) { Throw-ProfileError "${display}: collides with $($files[$key].Display) (standard paths are compared case-insensitively)" }
        $files[$key] = [pscustomobject]@{ Id = $id; Path = $file.FullName; Display = $display }
    }
    return $files
}

# Composes the chain's standards, root ancestor first. A profile folder holds
# profile.yml, standards/, amendments/ and replacements/; a standard's id is its
# path relative to that folder, compared case-insensitively.
# - standards/ takes new ids only: a file whose id an ancestor already provides
#   is ambiguous (silently replacing it would hide the parent's rule).
# - replacements/<id> supersedes the inherited text and every ancestor
#   amendment; amendments/<id> is appended to the inherited text. Every level
#   can amend, library profiles included.
# - A profile may not both amend and replace one id, nor target an id in its own standards/.
# - A delta's basis is checked against the hash of the normalised inherited parts
#   (base standard or nearest replacement, then each ancestor amendment, in chain
#   order, joined with LF). ORPHANED (nothing inherited) wins, then UNREVIEWED
#   (no basis), CURRENT (match) or STALE. A non-CURRENT delta still applies and
#   is listed for human review; an ORPHANED one still appears as a standard.
# - applies-to: the most-derived part that declares it wins; a replacement uses only its own.
# Returns { Standards (sorted by id), Review (sorted by Standard, then Profile) }.
function Get-EffectiveStandards([string[]]$Chain, $Source, [System.Collections.Generic.List[string]]$Warnings) {
    $merged = [ordered]@{}
    $missingDescription = "missing frontmatter 'description' (agents choose which standards to open from it)"
    for ($c = $Chain.Count - 1; $c -ge 0; $c--) {
        $entry = Get-ProfileEntry $Source $Chain[$c]
        $ownership = Get-ProfileOwnership $Source $entry.Id
        $standards = Get-ProfileFiles $entry 'standards' $Warnings
        $amendments = Get-ProfileFiles $entry 'amendments' $Warnings
        $replacements = Get-ProfileFiles $entry 'replacements' $Warnings

        foreach ($key in $amendments.Keys) {
            if ($replacements.Contains($key)) { Throw-ProfileError "$($amendments[$key].Display): $($entry.Display) both amends and replaces '$($amendments[$key].Id)'; keep one" }
        }
        # An inherited id in standards/ is reported as ambiguous ahead of the
        # own-standard check: that file, not the delta beside it, is the mistake.
        foreach ($key in $standards.Keys) {
            $file = $standards[$key]
            if ($merged.Contains($key)) { Throw-ProfileError "$($file.Display): ambiguous - '$($file.Id)' is inherited from $($merged[$key].From); put a narrow change in amendments/$($file.Id) or a whole-standard replacement in replacements/$($file.Id)" }
        }
        foreach ($deltas in @($replacements, $amendments)) {
            foreach ($key in $deltas.Keys) {
                if ($standards.Contains($key)) { Throw-ProfileError "$($deltas[$key].Display): '$($deltas[$key].Id)' is defined in this profile's own standards/; edit it there" }
            }
        }

        foreach ($key in $standards.Keys) {
            $file = $standards[$key]
            $fm = Read-StandardFrontmatter $file.Path $file.Display $Warnings
            # Descriptions are what agents choose standards by, so a standard without one is unusable.
            if (-not $fm.Description) { Throw-ProfileError "$($file.Display): $missingDescription" }
            $part = [pscustomobject]@{
                Role = 'standard'; Standard = $file.Id; From = $entry.Id; Ownership = $ownership
                Path = $file.Path; Display = $file.Display; Description = $fm.Description
                State = $null; Basis = $null; Inherited = $null
            }
            $merged[$key] = [pscustomobject]@{
                Id = $file.Id; Description = $fm.Description; From = $entry.Id; Path = $file.Path
                Overrides = @(); ReplacedBy = $null; Amendments = @(); AppliesTo = @($fm.AppliesTo)
                NeedsReview = $false; Parts = @($part)
            }
        }

        foreach ($role in @('replacement', 'amendment')) {
            $deltas = if ($role -eq 'replacement') { $replacements } else { $amendments }
            foreach ($key in $deltas.Keys) {
                $file = $deltas[$key]
                $fm = Read-StandardFrontmatter $file.Path $file.Display $Warnings -Delta
                if (-not $fm.Description) { Throw-ProfileError "$($file.Display): $missingDescription" }
                $inherited = if ($merged.Contains($key)) { @($merged[$key].Parts) } else { @() }
                $computed = if ($inherited.Count) { Get-TextHash ((@($inherited | ForEach-Object { Read-NormalisedFile $_.Path })) -join "`n") } else { $null }
                $state = if (-not $inherited.Count) { 'ORPHANED' } elseif (-not $fm.Basis) { 'UNREVIEWED' } elseif ($fm.Basis -ceq $computed) { 'CURRENT' } else { 'STALE' }
                $part = [pscustomobject]@{
                    Role = $role; Standard = $file.Id; From = $entry.Id; Ownership = $ownership
                    Path = $file.Path; Display = $file.Display; Description = $fm.Description
                    State = $state; Basis = $fm.Basis; Inherited = $computed
                }
                $amendment = [pscustomobject]@{ From = $entry.Id; Ownership = $ownership; Path = $file.Path; Description = $fm.Description; State = $state }
                if ($merged.Contains($key)) {
                    $target = $merged[$key]
                    if ($role -eq 'replacement') {
                        $target.Overrides = @($target.Overrides) + @($target.From)
                        $target.From = $entry.Id
                        $target.ReplacedBy = $entry.Id
                        $target.Path = $file.Path
                        $target.Description = $fm.Description
                        $target.AppliesTo = @($fm.AppliesTo)
                        $target.Amendments = @()
                        $target.Parts = @($part)
                    }
                    else {
                        $target.Amendments = @($target.Amendments) + @($amendment)
                        $target.Parts = @($target.Parts) + @($part)
                        if (@($fm.AppliesTo).Count) { $target.AppliesTo = @($fm.AppliesTo) }
                    }
                }
                else {
                    # ORPHANED: the id no longer exists upstream; keep its guidance visible.
                    $merged[$key] = [pscustomobject]@{
                        Id = $file.Id; Description = $fm.Description; From = $entry.Id; Path = $file.Path
                        Overrides = @(); ReplacedBy = if ($role -eq 'replacement') { $entry.Id } else { $null }
                        Amendments = if ($role -eq 'amendment') { @($amendment) } else { @() }
                        AppliesTo = @($fm.AppliesTo); NeedsReview = $false; Parts = @($part)
                    }
                }
            }
        }
    }

    $review = @()
    foreach ($standard in $merged.Values) {
        # Base standard parts have a $null State; every delta part carries one.
        $pending = @($standard.Parts | Where-Object { $null -ne $_.State -and $_.State -ne 'CURRENT' })
        $standard.NeedsReview = $pending.Count -gt 0
        foreach ($part in $pending) {
            $review += [pscustomobject]@{
                Standard = $standard.Id; Profile = $part.From; Ownership = $part.Ownership; Delta = $part.Role
                State = $part.State; Basis = $part.Basis; Inherited = $part.Inherited; Path = $part.Display
            }
        }
    }
    return [pscustomobject]@{
        Standards = @($merged.Values | Sort-Object { $_.Id.ToLowerInvariant() })
        Review = @($review | Sort-Object { $_.Standard.ToLowerInvariant() }, Profile)
    }
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
