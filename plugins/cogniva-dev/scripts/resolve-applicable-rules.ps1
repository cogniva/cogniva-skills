# Resolve the repository instructions that apply to one or more intended paths.
#
# This is deliberately read-only. It makes repository-local authority visible
# before implementation without prescribing a workflow or changing git state.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string[]]$Target,
    [string]$Purpose,
    [ValidateSet('Text', 'Json')][string]$Format = 'Text'
)
$ErrorActionPreference = 'Stop'

function Fail($Message) { [Console]::Error.WriteLine("applicable-rules: $Message"); exit 2 }

function Get-FullPath([string]$Path, [string]$Base) {
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $Base $Path))
}

function Get-ExistingDirectory([string]$Path) {
    $candidate = $Path
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return (Split-Path -Parent $candidate) }
    while (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
        $parent = Split-Path -Parent $candidate
        if (-not $parent -or $parent -eq $candidate) { return $null }
        $candidate = $parent
    }
    return $candidate
}

function Get-AuthorityChain([string]$Root, [string]$Directory, [string]$Name) {
    $result = @()
    $cursor = $Directory
    while ($true) {
        $candidate = Join-Path $cursor $Name
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $result += $candidate }
        if ($cursor -eq $Root) { break }
        $cursor = Split-Path -Parent $cursor
        if (-not $cursor) { break }
    }
    [array]::Reverse($result)
    return $result
}

function Get-RelevantLines([string[]]$Files) {
    $pattern = '(?i)architecture|placement|owner|module|host|composition|contract|dependenc|projectreference|validation|green gate|test|build|adr|before-(planning|integrate)'
    $lines = @()
    $errors = @()
    foreach ($file in $Files) {
        try {
            $lineNumber = 0
            foreach ($line in [System.IO.File]::ReadLines($file)) {
                $lineNumber++
                if ($line -match $pattern) {
                    $lines += [pscustomobject]@{ File = $file; Line = $lineNumber; Text = $line.Trim() }
                }
            }
        }
        catch { $errors += "Cannot read authority file ${file}: $($_.Exception.Message)" }
    }
    return [pscustomobject]@{ Lines = @($lines); Errors = @($errors) }
}

function Get-DirectivePolarity([string]$Text) {
    if ($Text -match '(?i)never|must not|do not|only|composition root') { return 'restrictive' }
    if ($Text -match '(?i)\bmay\b|\bcan\b|allowed|must contain|place substantive') { return 'permissive' }
    return 'neutral'
}

function Get-DirectiveTopics([string]$Text) {
    $topics = @()
    if ($Text -match '(?i)host|composition') { $topics += 'host-composition' }
    if ($Text -match '(?i)contract') { $topics += 'contracts' }
    if ($Text -match '(?i)dependenc|projectreference') { $topics += 'dependencies' }
    if ($Text -match '(?i)module|owner|placement') { $topics += 'ownership' }
    return @($topics)
}

$repoFull = [System.IO.Path]::GetFullPath($Repo)
if (-not (Test-Path -LiteralPath $repoFull -PathType Container)) { Fail "repo not found: $Repo" }
$repoFull = (Get-Item -LiteralPath $repoFull).FullName

$items = @()
$requestedTargets = @($Target | ForEach-Object {
    $_ -split ',' | ForEach-Object { $_.Trim().Trim("'").Trim('"') } | Where-Object { $_ }
})
foreach ($rawTarget in $requestedTargets) {
    $targetFull = Get-FullPath $rawTarget $repoFull
    $prefix = $repoFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($targetFull -eq $repoFull -or $targetFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase))) {
        Fail "target is outside repo: $rawTarget"
    }
    $directory = Get-ExistingDirectory $targetFull
    if (-not $directory) { Fail "cannot resolve an existing parent for target: $rawTarget" }

    $agents = Get-AuthorityChain $repoFull $directory 'AGENTS.md'
    $claudes = Get-AuthorityChain $repoFull $directory 'CLAUDE.md'
    $authorityFiles = @($agents) + @($claudes)
    $authorityRead = Get-RelevantLines $authorityFiles
    $constraints = @($authorityRead.Lines)
    $relative = $targetFull.Substring($repoFull.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $conflicts = @()
    $reviewReasons = @($authorityRead.Errors)
    if ($relative -match '^(src[\\/])?Hosts?[\\/]') {
        $message = 'Target is under a Host. Confirm that it is composition/wiring only; substantive application, domain, persistence, evaluation, or reusable behavior belongs in its owning Module.'
        if ($Purpose -match '(?i)domain|persistence|evaluation|orchestrat|business|reusable') { $message = "CONFLICT: $message" }
        $conflicts += $message
    }
    if ($relative -match 'Contracts?[\\/]') {
        $message = 'Target is under Contracts. Confirm that it remains a pure public surface rather than an implementation owner.'
        if ($Purpose -match '(?i)implementation|persistence|business|domain') { $message = "CONFLICT: $message" }
        $conflicts += $message
    }
    $directiveLines = @($constraints | Where-Object { (Get-DirectivePolarity $_.Text) -ne 'neutral' })
    for ($left = 0; $left -lt $directiveLines.Count; $left++) {
        for ($right = $left + 1; $right -lt $directiveLines.Count; $right++) {
            $a = $directiveLines[$left]
            $b = $directiveLines[$right]
            if ($a.File -eq $b.File) { continue }
            if ((Get-DirectivePolarity $a.Text) -eq (Get-DirectivePolarity $b.Text)) { continue }
            $sharedTopics = @((Get-DirectiveTopics $a.Text) | Where-Object { (Get-DirectiveTopics $b.Text) -contains $_ })
            if ($sharedTopics.Count) {
                $reviewReasons += "Potentially incompatible $($sharedTopics -join ', ') directives: $($a.File):$($a.Line) and $($b.File):$($b.Line)."
            }
        }
    }
    foreach ($conflict in $conflicts) {
        if ($conflict -like 'CONFLICT:*') { $reviewReasons += $conflict }
    }
    $effectiveAuthority = @()
    for ($index = 0; $index -lt $agents.Count; $index++) {
        $effectiveAuthority += [pscustomobject]@{
            Source = 'AGENTS.md'; Path = $agents[$index]; Order = $index + 1
            Role = 'tool-neutral repository authority; later, more-specific AGENTS.md adds to or explicitly overrides earlier instructions'
        }
    }
    for ($index = 0; $index -lt $claudes.Count; $index++) {
        $effectiveAuthority += [pscustomobject]@{
            Source = 'CLAUDE.md'; Path = $claudes[$index]; Order = $agents.Count + $index + 1
            Role = 'substantive repository authority and transitional workflow-phase fallback; Claude-specific execution mechanics are not inherited automatically'
        }
    }
    $decision = if ($reviewReasons.Count) { 'REVIEW_REQUIRED' } else { 'SAFE_TO_PROCEED' }
    $items += [pscustomobject]@{
        Target = $relative
        ExistingParent = $directory
        Agents = @($agents)
        Claude = @($claudes)
        EffectiveAuthority = @($effectiveAuthority)
        PrecedenceRule = 'More-specific applicable AGENTS.md adds to or overrides broader AGENTS.md only where the narrower text explicitly conflicts or overrides. A narrower file must not silently weaken broader safety or architecture guardrails. Substantive CLAUDE.md constraints remain applicable.'
        Constraints = @($constraints)
        Conflicts = @($conflicts)
        ReviewReasons = @($reviewReasons | Select-Object -Unique)
        Decision = $decision
        CanProceedAutomatically = ($decision -eq 'SAFE_TO_PROCEED')
    }
}

$report = [pscustomobject]@{
    Repo = $repoFull
    Purpose = $Purpose
    ReadOnly = $true
    Targets = @($items)
}

if ($Format -eq 'Json') {
    $report | ConvertTo-Json -Depth 8
    exit 0
}

Write-Output "applicable-rules: read-only preflight for $repoFull"
foreach ($item in $items) {
    Write-Output ""
    Write-Output "Target: $($item.Target)"
    $agentsText = if ($item.Agents.Count) { $item.Agents -join '; ' } else { '(none)' }
    $claudeText = if ($item.Claude.Count) { $item.Claude -join '; ' } else { '(none)' }
    Write-Output "  AGENTS.md: $agentsText"
    Write-Output "  CLAUDE.md: $claudeText"
    $authorityText = ($item.EffectiveAuthority | ForEach-Object { "[$($_.Order)] $($_.Source): $($_.Path)" }) -join '; '
    Write-Output "  EFFECTIVE AUTHORITY: $authorityText"
    Write-Output "  DECISION: $($item.Decision)"
    foreach ($conflict in $item.Conflicts) { Write-Output "  PLACEMENT: $conflict" }
    foreach ($reason in $item.ReviewReasons) { Write-Output "  REVIEW_REQUIRED: $reason" }
    foreach ($constraint in $item.Constraints) { Write-Output "  RULE [$($constraint.File):$($constraint.Line)] $($constraint.Text)" }
}
exit 0
