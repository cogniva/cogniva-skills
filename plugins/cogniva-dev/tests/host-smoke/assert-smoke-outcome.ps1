#Requires -Version 7.0
# Checks a smoke fixture (built by new-smoke-fixture.ps1) after an agent-host
# run against its scenario's expectations: "expect" in .smoke/scenario.json, or
# "resumeExpect" with -Resume. Deterministic: git and file state plus the saved
# final message - never the agent's own account of what it did.
# Keys: commitsSinceStart, branch, changedPaths, unchangedPaths,
# unrelatedPreserved, planTicked, planUnticked, finalMessageContains,
# finalMessageNotContains, handoffSections, noNewFiles, gitInfoExcludeUnchanged,
# fileStartsWith. Boolean keys take only true.
# Prints "PASS|FAIL <key>: <detail>" per key, then "SMOKE <ID>: PASS|FAIL"
# (-Json: one JSON object instead). Exit 0 = pass, 1 = fail, 2 = usage error.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Fixture,
    [Parameter(Mandatory)][string]$Scenario,
    [string]$FinalMessage,
    [switch]$Resume,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$known = @('commitsSinceStart', 'branch', 'changedPaths', 'unchangedPaths', 'unrelatedPreserved', 'planTicked', 'planUnticked', 'finalMessageContains', 'finalMessageNotContains', 'handoffSections', 'noNewFiles', 'gitInfoExcludeUnchanged', 'fileStartsWith')
$booleanKeys = @('unrelatedPreserved', 'handoffSections', 'noNewFiles', 'gitInfoExcludeUnchanged')

function Fail([string]$Message) { [Console]::Error.WriteLine("assert-smoke-outcome: $Message"); exit 2 }
function Invoke-Git([string[]]$GitArgs) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $out = @(& git -C $script:fx @GitArgs 2>$null); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ Code = $code; Out = @($out | ForEach-Object { [string]$_ }) }
}
function Read-Lf([string]$Path) { return ([System.IO.File]::ReadAllText($Path)).TrimStart([char]0xFEFF).Replace("`r`n", "`n") }

if (-not (Test-Path -LiteralPath $Fixture -PathType Container)) { Fail "fixture not found: $Fixture" }
$fx = [System.IO.Path]::GetFullPath($Fixture)
$smoke = Join-Path $fx '.smoke'
$scenarioFile = Join-Path $smoke 'scenario.json'
if (-not (Test-Path -LiteralPath $scenarioFile -PathType Leaf)) { Fail "not a smoke fixture (no .smoke/scenario.json): $fx" }
$data = Get-Content -Raw -LiteralPath $scenarioFile | ConvertFrom-Json -AsHashtable
if ($data['id'] -cne $Scenario) { Fail "the fixture is scenario '$($data['id'])', not '$Scenario'" }
$expect = if ($Resume) { $data['resumeExpect'] } else { $data['expect'] }
if ($Resume -and $null -eq $expect) { Fail "scenario $Scenario has no resumeExpect" }
if ($null -eq $expect) { $expect = @{} }
foreach ($key in @($expect.Keys)) {
    if ($known -cnotcontains $key) { Fail "unknown expect key '$key' in scenario $Scenario" }
    if ($booleanKeys -ccontains $key -and $expect[$key] -ne $true) { Fail "expect key '$key' takes only true" }
}
$start = (Read-Lf (Join-Path $smoke 'start.txt')).Trim()
$message = $null
if ($FinalMessage -and (Test-Path -LiteralPath $FinalMessage -PathType Leaf)) { $message = Read-Lf $FinalMessage }

$results = [System.Collections.Generic.List[object]]::new()
function Add-Result([string]$Key, [bool]$Pass, [string]$Detail) { $script:results.Add([pscustomobject]@{ key = $Key; pass = $Pass; detail = $Detail }) }

# Git blob id of a path in the working tree now / at START; $null when absent.
function Get-NowBlob([string]$Relative) {
    if (-not (Test-Path -LiteralPath (Join-Path $fx $Relative) -PathType Leaf)) { return $null }
    return (Invoke-Git @('hash-object', '--no-filters', '--', $Relative)).Out | Select-Object -First 1
}
function Get-StartBlob([string]$Relative) {
    $r = Invoke-Git @('rev-parse', '--verify', '--quiet', "$($start):$Relative")
    if ($r.Code -ne 0) { return $null }
    return $r.Out | Select-Object -First 1
}
# Per task number: how many ticked and unticked checkboxes it has outside fenced code.
function Get-TaskBoxes([string]$Text) {
    $boxes = @{}
    $current = $null; $inFence = $false; $fenceChar = ''; $fenceLen = 0
    $heading = '^##\s+(?:' + [char]0x26D4 + '\s*)?Task\s+(?<n>\d+):'
    foreach ($line in ($Text -split "`n")) {
        $m = [regex]::Match($line, $heading)
        if ($m.Success) { $current = [int]$m.Groups['n'].Value; $boxes[$current] = [pscustomobject]@{ Checked = 0; Unchecked = 0 }; $inFence = $false; continue }
        if ($null -eq $current) { continue }
        $trimmed = $line.TrimStart()
        $fm = [regex]::Match($trimmed, '^(?<f>`{3,}|~{3,})')
        if ($fm.Success) {
            $marker = $fm.Groups['f'].Value
            if (-not $inFence) { $inFence = $true; $fenceChar = $marker[0]; $fenceLen = $marker.Length }
            elseif ($marker[0] -eq $fenceChar -and $marker.Length -ge $fenceLen) { $inFence = $false }
            continue
        }
        if ($inFence) { continue }
        if ($trimmed -match '^- \[[xX]\]') { $boxes[$current].Checked++ }
        elseif ($trimmed -match '^- \[ \]') { $boxes[$current].Unchecked++ }
    }
    return $boxes
}
function Test-PlanBoxes([string]$Key, $Spec, [bool]$Ticked) {
    $planFile = Join-Path $fx ([string]$Spec['path'])
    if (-not (Test-Path -LiteralPath $planFile -PathType Leaf)) { Add-Result $Key $false "plan not found: $($Spec['path'])"; return }
    $boxes = Get-TaskBoxes (Read-Lf $planFile)
    $bad = @()
    foreach ($n in @($Spec['tasks'])) {
        $b = $boxes[[int]$n]
        if ($null -eq $b) { $bad += "task $n (no such task)"; continue }
        $ok = if ($Ticked) { $b.Checked -ge 1 -and $b.Unchecked -eq 0 } else { $b.Unchecked -ge 1 -and $b.Checked -eq 0 }
        if (-not $ok) { $bad += "task $n ($($b.Checked) ticked, $($b.Unchecked) unticked)" }
    }
    $state = if ($Ticked) { 'ticked' } else { 'unticked' }
    if ($bad.Count) { Add-Result $Key $false "not all $($state): $($bad -join ', ')" }
    else { Add-Result $Key $true "tasks $(@($Spec['tasks']) -join ', ') all $state in $($Spec['path'])" }
}
function Get-HandoffSections {
    $text = Read-Lf (Join-Path $plugin 'skills\execute-feature\HANDOFF.md')
    $names = @(); $inside = $false
    foreach ($line in ($text -split "`n")) {
        if ($line.StartsWith('## ')) { $inside = ($line -ceq '## Required sections'); continue }
        if ($inside -and $line -match '^- \*\*(?<name>[^*]+)\*\*') { $names += $Matches['name'].Replace('`', '') }
    }
    return $names
}

foreach ($key in $known) {
    if (-not $expect.ContainsKey($key)) { continue }
    $want = $expect[$key]
    switch ($key) {
        'commitsSinceStart' {
            $got = [int]((Invoke-Git @('rev-list', '--count', "$start..HEAD")).Out | Select-Object -First 1)
            Add-Result $key ($got -eq [int]$want) "expected $want new commit(s), found $got"
        }
        'branch' {
            $r = Invoke-Git @('symbolic-ref', '--quiet', '--short', 'HEAD')
            $got = if ($r.Code -eq 0) { $r.Out | Select-Object -First 1 } else { '(detached HEAD)' }
            Add-Result $key ($got -ceq [string]$want) "expected $want, on $got"
        }
        'changedPaths' {
            $same = @(@($want) | Where-Object { (Get-NowBlob $_) -eq (Get-StartBlob $_) })
            if ($same.Count) { Add-Result $key $false "unchanged since START: $($same -join ', ')" }
            else { Add-Result $key $true "changed: $(@($want) -join ', ')" }
        }
        'unchangedPaths' {
            $moved = @(@($want) | Where-Object { (Get-NowBlob $_) -ne (Get-StartBlob $_) })
            if ($moved.Count) { Add-Result $key $false "changed since START: $($moved -join ', ')" }
            else { Add-Result $key $true "byte-identical to START: $(@($want) -join ', ')" }
        }
        'unrelatedPreserved' {
            $file = Join-Path $fx 'notes\unrelated.txt'
            $hash = if (Test-Path -LiteralPath $file) { (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash } else { '(missing)' }
            $seeded = (Read-Lf (Join-Path $smoke 'unrelated.sha256')).Trim()
            $commits = @((Invoke-Git @('log', '--format=%h', "$start..HEAD", '--', 'notes/unrelated.txt')).Out | Where-Object { $_ })
            if ($hash -ne $seeded) { Add-Result $key $false 'notes/unrelated.txt no longer holds the seeded work in progress' }
            elseif ($commits.Count) { Add-Result $key $false "notes/unrelated.txt is in new commit(s): $($commits -join ', ')" }
            else { Add-Result $key $true 'notes/unrelated.txt keeps its content and is in no new commit' }
        }
        'planTicked' { Test-PlanBoxes $key $want $true }
        'planUnticked' { Test-PlanBoxes $key $want $false }
        'finalMessageContains' {
            if ($null -eq $message) { Add-Result $key $false 'no final message file'; break }
            $missing = @(@($want) | Where-Object { -not $message.Contains([string]$_, [System.StringComparison]::Ordinal) })
            if ($missing.Count) { Add-Result $key $false "missing: $($missing -join ' | ')" }
            else { Add-Result $key $true "contains: $(@($want) -join ' | ')" }
        }
        'finalMessageNotContains' {
            if ($null -eq $message) { Add-Result $key $false 'no final message file'; break }
            $present = @(@($want) | Where-Object { $message.Contains([string]$_, [System.StringComparison]::Ordinal) })
            if ($present.Count) { Add-Result $key $false "present: $($present -join ' | ')" }
            else { Add-Result $key $true "absent: $(@($want) -join ' | ')" }
        }
        'handoffSections' {
            if ($null -eq $message) { Add-Result $key $false 'no final message file'; break }
            $plain = $message.Replace('`', '').Replace('*', '')
            $missing = @(Get-HandoffSections | Where-Object { $plain.IndexOf($_, [System.StringComparison]::OrdinalIgnoreCase) -lt 0 })
            if (-not $message.Contains('READY FOR REVIEW', [System.StringComparison]::Ordinal)) { $missing += 'READY FOR REVIEW' }
            if ($missing.Count) { Add-Result $key $false "missing: $($missing -join ' | ')" }
            else { Add-Result $key $true 'every HANDOFF.md section and READY FOR REVIEW are present' }
        }
        'noNewFiles' {
            $before = @((Read-Lf (Join-Path $smoke 'untracked.before')) -split "`n" | Where-Object { $_ })
            $now = @((Invoke-Git @('-c', 'core.quotepath=off', 'ls-files', '--others')).Out | Where-Object { $_ })
            $new = @($now | Where-Object { -not $_.StartsWith('.smoke/') -and $before -cnotcontains $_ })
            if ($new.Count) { Add-Result $key $false "new untracked or ignored file(s): $($new -join ', ')" }
            else { Add-Result $key $true 'no new files, ignored ones included' }
        }
        'gitInfoExcludeUnchanged' {
            $exclude = Join-Path $fx ((Invoke-Git @('rev-parse', '--git-path', 'info/exclude')).Out | Select-Object -First 1)
            $now = if (Test-Path -LiteralPath $exclude) { [System.IO.File]::ReadAllText($exclude) } else { '' }
            $was = [System.IO.File]::ReadAllText((Join-Path $smoke 'exclude.before'))
            Add-Result $key ($now -ceq $was) $(if ($now -ceq $was) { '.git/info/exclude is unchanged' } else { '.git/info/exclude changed during the run' })
        }
        'fileStartsWith' {
            $bad = @()
            foreach ($entry in $want.GetEnumerator()) {
                $file = Join-Path $fx $entry.Key
                $prefix = ([string]$entry.Value).Replace("`r`n", "`n")
                if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { $bad += "$($entry.Key) (missing)"; continue }
                $text = Read-Lf $file
                if (-not $text.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
                    $head = (@($text -split "`n" | Select-Object -First 2) -join '\n')
                    $bad += "$($entry.Key) starts with '$head'"
                }
            }
            if ($bad.Count) { Add-Result $key $false ($bad -join '; ') }
            else { Add-Result $key $true "$(@($want.Keys) -join ', ') start(s) as expected" }
        }
    }
}

$pass = -not @($results | Where-Object { -not $_.pass }).Count
if ($Json) {
    [pscustomobject]@{ scenario = $Scenario; resume = [bool]$Resume; pass = $pass; results = @($results) } | ConvertTo-Json -Depth 5
}
else {
    foreach ($r in $results) { Write-Output ("{0} {1}: {2}" -f $(if ($r.pass) { 'PASS' } else { 'FAIL' }), $r.key, $r.detail) }
    Write-Output ("SMOKE {0}: {1}" -f $Scenario, $(if ($pass) { 'PASS' } else { 'FAIL' }))
}
exit $(if ($pass) { 0 } else { 1 })
