# module-deps.ps1
# Legacy Module-layout tool. Graphs the cross-Module dependencies of a repo laid
# out as src/Modules/<Name>/<Name>.<Kind> projects (the layout add-module
# scaffolds) from the .csproj ProjectReference graph, and writes
# docs/architecture/module-dependencies.md + .html. -Check instead reports the
# cross-Module cycles not listed in docs/architecture/allowed-cycles.txt and
# exits 0 (none) or 1, writing nothing.
# It reads no architecture profile and ships no project-specific data: Module
# descriptions are display-only and come from the repo glossary's
# "## <Name> (Module)" entries. No build/restore required.
#
# ASCII-only on purpose (PS 5.1 mis-tokenizes non-ASCII .ps1 source).
# Windows PowerShell 5.1 compatible: hooks call powershell.exe.

[CmdletBinding()]
param(
    [string]$RepoRoot = $null,
    [string]$OutFile  = $null,
    [string]$HtmlFile = $null,
    [switch]$Check,     # report disallowed cross-Module cycles and exit 0/1; writes nothing, reads no glossary
    [switch]$Open,
    [switch]$NoCommit   # by default the two generated files are auto-committed; pass -NoCommit to leave them dirty in the working tree
)

$ErrorActionPreference = 'Stop'

# Ordinal sort: the same order on every machine, culture and PowerShell host
# (PowerShell 7 randomizes string hash codes, so hashtable and hashset
# enumeration order is not stable between runs).
function Sort-Ordinal($items) {
    $arr = [string[]]@($items | Where-Object { $null -ne $_ })
    [System.Array]::Sort($arr, [System.StringComparer]::Ordinal)
    $arr
}

function Get-FullPath([string]$path) {
    if ([System.IO.Path]::IsPathRooted($path)) { return [System.IO.Path]::GetFullPath($path) }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $path))
}

if (-not $RepoRoot) {
    $top = $null
    try { $top = (& git rev-parse --show-toplevel 2>$null) | Select-Object -First 1 } catch { $top = $null }
    if (-not $top) { throw 'module-deps: not inside a git repository - run it from the repo, or pass -RepoRoot <path>.' }
    $RepoRoot = [string]$top
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path.TrimEnd('\', '/')
if (-not $OutFile)  { $OutFile  = Join-Path $RepoRoot 'docs\architecture\module-dependencies.md' }
if (-not $HtmlFile) { $HtmlFile = Join-Path $RepoRoot 'docs\architecture\module-dependencies.html' }
$OutFile  = Get-FullPath $OutFile
$HtmlFile = Get-FullPath $HtmlFile

$srcRoot = Join-Path $RepoRoot 'src'
if (-not (Test-Path -LiteralPath $srcRoot)) { throw "src not found under $RepoRoot" }

# ---- 1. discover projects -------------------------------------------------
# src/Modules/<Name>/... is a Module; src/Hosts/... is a host; everything else
# (shared libraries, shells, kernels, ...) is outside the graph.
function Get-ModuleName([string]$rel) {
    if ($rel -match '^src[\\/]+Modules[\\/]+([^\\/]+)[\\/]+') { return $matches[1] }
    if ($rel -match '^src[\\/]+Hosts[\\/]+')                  { return 'Host'  }
    return 'Other'
}
# The kind is the first dot-segment after the Module name, so qualified
# projects (<Name>.Infrastructure.<System>, <Name>.UI.<Part>) roll up to it.
function Get-Role([string]$proj, [string]$module) {
    if ($proj -like "$module.*") {
        $rest = $proj.Substring($module.Length + 1)
        return ($rest -split '\.')[0]
    }
    return $proj
}

$projFiles = @(Sort-Ordinal (Get-ChildItem -LiteralPath $srcRoot -Recurse -Filter *.csproj | ForEach-Object { $_.FullName }))
$projects  = @{}   # projName -> object

foreach ($full in $projFiles) {
    $rel  = $full.Substring($RepoRoot.Length).TrimStart('\','/')
    $name = [System.IO.Path]::GetFileNameWithoutExtension($full)
    $mod  = Get-ModuleName $rel
    [xml]$xml = Get-Content -Raw -LiteralPath $full
    $refs = @()
    foreach ($n in $xml.SelectNodes('//ProjectReference')) {
        $inc = $n.GetAttribute('Include')
        if ($inc) { $refs += [System.IO.Path]::GetFileNameWithoutExtension($inc) }
    }
    $projects[$name] = [pscustomobject]@{
        Name   = $name
        Module = $mod
        Role   = (Get-Role $name $mod)
        Rel    = $rel
        Refs   = $refs
    }
}

$realModules = @(Sort-Ordinal ($projects.Values | Where-Object { $_.Module -notin @('Host','Other') } |
    ForEach-Object { $_.Module } | Select-Object -Unique))

# ---- 2. cross-Module edges ------------------------------------------------
# moduleDirect[src] = hashset of target modules
# roleDeps[src][role] = hashset of target modules
# edgeRoles["src|dst"] = hashset of roles
$moduleDirect = @{}
$roleDeps     = @{}
$edgeRoles    = @{}

function Add-Set([hashtable]$h, [string]$k, [string]$v) {
    if (-not $h.ContainsKey($k)) { $h[$k] = New-Object 'System.Collections.Generic.HashSet[string]' }
    [void]$h[$k].Add($v)
}

foreach ($p in $projects.Values) {
    if ($p.Module -in @('Host','Other')) { continue }
    foreach ($r in $p.Refs) {
        if (-not $projects.ContainsKey($r)) { continue }
        $tgt = $projects[$r]
        if ($tgt.Module -eq $p.Module) { continue }          # intra-Module
        if ($tgt.Module -in @('Host','Other')) { continue }
        Add-Set $moduleDirect $p.Module $tgt.Module
        Add-Set $edgeRoles "$($p.Module)|$($tgt.Module)" $p.Role
        if (-not $roleDeps.ContainsKey($p.Module)) { $roleDeps[$p.Module] = @{} }
        Add-Set $roleDeps[$p.Module] $p.Role $tgt.Module
    }
}

# ---- 3. transitive closure + cycle detection ------------------------------
function Get-Closure([string]$mod) {
    $seen  = New-Object 'System.Collections.Generic.HashSet[string]'
    $stack = New-Object 'System.Collections.Generic.Stack[string]'
    if ($moduleDirect.ContainsKey($mod)) { foreach ($d in $moduleDirect[$mod]) { $stack.Push($d) } }
    while ($stack.Count -gt 0) {
        $cur = $stack.Pop()
        if ($seen.Add($cur)) {
            if ($moduleDirect.ContainsKey($cur)) { foreach ($d in $moduleDirect[$cur]) { $stack.Push($d) } }
        }
    }
    return ,$seen   # leading comma: return the HashSet itself, do not enumerate it
}

$closure = @{}
foreach ($m in $realModules) { $closure[$m] = Get-Closure $m }

# Every mutually reachable pair, written "A <-> B" with A before B ordinally.
$cycles = New-Object 'System.Collections.Generic.List[string]'
for ($i = 0; $i -lt $realModules.Count; $i++) {
    for ($j = $i + 1; $j -lt $realModules.Count; $j++) {
        $a = $realModules[$i]; $b = $realModules[$j]
        if ($closure[$a].Contains($b) -and $closure[$b].Contains($a)) {
            $cycles.Add("$a <-> $b") | Out-Null
        }
    }
}

# ---- 3b. gate mode (-Check): report and exit, write nothing ----------------
# Cycles listed in docs/architecture/allowed-cycles.txt are tolerated: one
# "A <-> B" per line in either order, '#' starts a comment (a trailing
# "# reason" is encouraged), blank lines ignored. Adding a pair is a
# deliberate, reviewed act. -Check never reads the glossary.
function Get-CyclePairKey([string]$a, [string]$b) {
    $pair = @(Sort-Ordinal @($a.Trim(), $b.Trim()))
    return "$($pair[0]) <-> $($pair[1])"
}

if ($Check) {
    $allowFile = Join-Path $RepoRoot 'docs\architecture\allowed-cycles.txt'
    $allowed = New-Object 'System.Collections.Generic.HashSet[string]'
    if (Test-Path -LiteralPath $allowFile -PathType Leaf) {
        $lineNo = 0
        foreach ($ln in [System.IO.File]::ReadAllLines($allowFile, [System.Text.Encoding]::UTF8)) {
            $lineNo++
            $t = ($ln -split '#', 2)[0].Trim()
            if (-not $t) { continue }
            $parts = @($t -split '<->')
            if ($parts.Count -ne 2 -or -not $parts[0].Trim() -or -not $parts[1].Trim()) {
                Write-Host ("WARN: allowed-cycles.txt line {0} is not 'A <-> B' and allows nothing: {1}" -f $lineNo, $t)
                continue
            }
            [void]$allowed.Add((Get-CyclePairKey $parts[0] $parts[1]))
        }
    }
    $bad = @($cycles | Where-Object { -not $allowed.Contains($_) })
    if ($bad.Count -eq 0) {
        Write-Host 'module-deps check OK: no disallowed cross-Module cycles.'
        exit 0
    }
    Write-Host 'module-deps check FAILED: cross-Module dependency cycle(s) detected:'
    foreach ($c in $bad) {
        Write-Host "  $c"
        $pair = $c -split ' <-> '
        foreach ($k in @("$($pair[0])|$($pair[1])", "$($pair[1])|$($pair[0])")) {
            if ($edgeRoles.ContainsKey($k)) {
                $p = $k -split '\|'
                Write-Host ("    {0} -> {1} (introduced by role(s): {2})" -f $p[0], $p[1], (@(Sort-Ordinal $edgeRoles[$k]) -join ', '))
            }
        }
    }
    Write-Host 'Cross-Module references must stay acyclic.'
    Write-Host 'Fix the ProjectReference, or - deliberate and reviewed only - add the pair to docs/architecture/allowed-cycles.txt (either order; a trailing "# reason" is encouraged).'
    exit 1
}

# ---- 4. hosts -------------------------------------------------------------
# $hosts[name]  = Modules the host DIRECTLY references (the "composed" set).
# $hostClosure[name] = EXACT Module assemblies that ship in the host, computed by
#   walking the host's actual .csproj ProjectReferences transitively project-by-
#   project (NOT by rolling each composed Module up to its full Module closure),
#   so a host that references only some projects of a Module inherits only the
#   Modules those projects reach.
$hosts = @{}
foreach ($p in $projects.Values | Where-Object { $_.Module -eq 'Host' }) {
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($r in $p.Refs) {
        if ($projects.ContainsKey($r)) {
            $m = $projects[$r].Module
            if ($m -notin @('Host','Other')) { [void]$set.Add($m) }
        }
    }
    $hosts[$p.Name] = $set
}

function Get-HostModuleClosure([string]$hostProjName) {
    $mods     = New-Object 'System.Collections.Generic.HashSet[string]'
    $seenProj = New-Object 'System.Collections.Generic.HashSet[string]'
    $stack    = New-Object 'System.Collections.Generic.Stack[string]'
    if ($projects.ContainsKey($hostProjName)) {
        foreach ($r in $projects[$hostProjName].Refs) { $stack.Push($r) }
    }
    while ($stack.Count -gt 0) {
        $cur = $stack.Pop()
        if (-not $seenProj.Add($cur)) { continue }
        if (-not $projects.ContainsKey($cur)) { continue }   # external/package ref - ignore
        $m = $projects[$cur].Module
        if ($m -notin @('Host','Other')) { [void]$mods.Add($m) }
        foreach ($r in $projects[$cur].Refs) { $stack.Push($r) }
    }
    return ,$mods   # leading comma: return the HashSet itself, do not enumerate it
}
$hostClosure = @{}
foreach ($p in $projects.Values | Where-Object { $_.Module -eq 'Host' }) {
    $hostClosure[$p.Name] = Get-HostModuleClosure $p.Name
}

# ---- 4b. Module descriptions (display only) ---------------------------------
# The first paragraph under each "## <Name> (Module)" heading in the repo
# glossary, with Markdown links reduced to their text. Display only: a missing
# or unreadable glossary, or a missing entry, shows a placeholder and never
# affects the graph (-Check has already exited by this point).
$moduleDesc = @{}
$glossaryFile = Join-Path $RepoRoot 'docs\glossary\README.md'
if (Test-Path -LiteralPath $glossaryFile) {
    try {
        $gl = [System.IO.File]::ReadAllLines($glossaryFile, [System.Text.Encoding]::UTF8)
        for ($i = 0; $i -lt $gl.Count; $i++) {
            if ($gl[$i] -notmatch '^##\s+(\S+)\s+\(Module\)\s*$') { continue }
            $name = $matches[1]
            $para = @()
            for ($j = $i + 1; $j -lt $gl.Count; $j++) {
                $line = $gl[$j].Trim()
                if ($line -match '^#') { break }
                if (-not $line) { if ($para.Count) { break } else { continue } }
                $para += $line
            }
            if ($para.Count -and -not $moduleDesc.ContainsKey($name)) {
                $moduleDesc[$name] = (($para -join ' ') -replace '\[([^\]]*)\]\([^)]*\)', '$1')
            }
        }
    }
    catch { Write-Host ("WARN: could not read Module descriptions from docs/glossary/README.md: {0}" -f $_.Exception.Message) }
}
else { Write-Host 'NOTE: docs/glossary/README.md not found; Module descriptions are left blank.' }

# ---- 4c. shared graph rendering (two Mermaid views) -----------------------
# Short labels for the common kinds; any other kind is shown in full, so two
# kinds can never share a label.
$roleAbbr = @{ 'Application' = 'A'; 'Infrastructure' = 'I'; 'UI' = 'U'; 'Client' = 'Cl'; 'Contracts' = 'Co'; 'Domain' = 'D' }
function Abbr-Label($roleSet) {
    $a = @()
    foreach ($r in $roleSet) {
        if ($roleAbbr.ContainsKey($r)) { $a += $roleAbbr[$r] } else { $a += $r }
    }
    return (@(Sort-Ordinal ($a | Select-Object -Unique)) -join ',')
}

# edge lines shared by both views (abbreviated role labels)
$edgeLines = New-Object 'System.Collections.Generic.List[string]'
foreach ($k in @(Sort-Ordinal $edgeRoles.Keys)) {
    $parts = $k -split '\|'
    $edgeLines.Add("  $($parts[0]) -->|$(Abbr-Label $edgeRoles[$k])| $($parts[1])") | Out-Null
}

# dependency depth (longest path to a leaf) -> tiers
# Cycle-safe: a back-edge into a module already on the current recursion stack is
# ignored for depth purposes (it would otherwise recurse forever). Cycles are
# still surfaced separately in the "Cycles" section. Modules and their targets
# are visited in ordinal order, so tiers are the same on every run.
$depth = @{}
$depthInProgress = New-Object 'System.Collections.Generic.HashSet[string]'
function Get-Depth([string]$m) {
    if ($script:depth.ContainsKey($m)) { return $script:depth[$m] }
    if (-not $script:depthInProgress.Add($m)) { return 0 }   # on the stack -> cycle back-edge, skip
    $d = 0
    if ($moduleDirect.ContainsKey($m)) {
        foreach ($t in @(Sort-Ordinal $moduleDirect[$m])) {
            $td = (Get-Depth $t) + 1
            if ($td -gt $d) { $d = $td }
        }
    }
    [void]$script:depthInProgress.Remove($m)
    $script:depth[$m] = $d
    return $d
}
foreach ($m in $realModules) { [void](Get-Depth $m) }
$maxDepth = 0
foreach ($m in $realModules) { if ($depth[$m] -gt $maxDepth) { $maxDepth = $depth[$m] } }
$byTier = @{}
foreach ($m in $realModules) {
    if (-not $byTier.ContainsKey($depth[$m])) { $byTier[$depth[$m]] = New-Object 'System.Collections.Generic.List[string]' }
    $byTier[$depth[$m]].Add($m) | Out-Null
}
function Tier-Title([int]$t) {
    if ($t -eq $script:maxDepth) { return "Tier $t - top consumers" }
    if ($t -eq 0) { return "Tier $t - foundation (leaves)" }
    return "Tier $t"
}

# View 1: dependency graph (ELK renderer, abbreviated labels)
$viewFlat = New-Object 'System.Collections.Generic.List[string]'
$viewFlat.Add("%%{init: {'flowchart': {'defaultRenderer': 'elk'}}}%%") | Out-Null
$viewFlat.Add('graph TD') | Out-Null
foreach ($m in $realModules) {
    if (-not $moduleDirect.ContainsKey($m) -or $moduleDirect[$m].Count -eq 0) { $viewFlat.Add("  $m") | Out-Null }
}
foreach ($e in $edgeLines) { $viewFlat.Add($e) | Out-Null }

# View 2: tiered by dependency depth (top consumers on top, leaves at bottom)
$viewTiered = New-Object 'System.Collections.Generic.List[string]'
$viewTiered.Add("%%{init: {'flowchart': {'rankSpacing': 65, 'nodeSpacing': 40}}}%%") | Out-Null
$viewTiered.Add('graph TD') | Out-Null
for ($t = $maxDepth; $t -ge 0; $t--) {
    if (-not $byTier.ContainsKey($t)) { continue }
    $viewTiered.Add("  subgraph L$t[`"$(Tier-Title $t)`"]") | Out-Null
    foreach ($m in @(Sort-Ordinal $byTier[$t])) { $viewTiered.Add("    $m") | Out-Null }
    $viewTiered.Add('  end') | Out-Null
}
foreach ($e in $edgeLines) { $viewTiered.Add($e) | Out-Null }

# ---- 5. emit markdown -----------------------------------------------------
$L = New-Object 'System.Collections.Generic.List[string]'
function W([string]$s) { $script:L.Add($s) | Out-Null }

function Join-Set($set) {
    if (-not $set -or $set.Count -eq 0) { return '-' }
    return (@(Sort-Ordinal $set) -join ', ')
}

$legend = 'Edge labels abbreviate the consuming project kind: **A** = .Application, **I** = .Infrastructure, **U** = .UI, **Cl** = .Client, **Co** = .Contracts, **D** = .Domain; any other kind is shown in full.'

W '# Module dependency graph'
W ''
W '> GENERATED by the `module-deps` skill (legacy Module-layout tool) from the'
W '> `.csproj` ProjectReference graph. Do not edit by hand. Regenerate with the'
W '> `module-deps` skill (or run the script directly).'
W ''
W 'Modules are the folders under `src/Modules/`. Cross-Module references go'
W 'through `<Name>.Contracts`, so a "depends on" edge means: to host the consumer'
W 'you may need to register an implementation of the target Module. The'
W '**transitive closure** is the Module set a host must compose (an upper bound).'
W ''

W '## Modules'
W ''
W 'Descriptions come from the `## <Name> (Module)` entries in `docs/glossary/README.md`.'
W ''
W '| Module | What it does |'
W '|---|---|'
foreach ($m in $realModules) {
    if ($moduleDesc.ContainsKey($m)) { $d = $moduleDesc[$m].Replace('|', '\|') }
    else { $d = '_(no description - add a `## ' + $m + ' (Module)` entry to docs/glossary/README.md)_' }
    W "| **$m** | $d |"
}
W ''

W '## Module graph'
W ''
W $legend
W ''
W '### View 1 - dependency graph'
W ''
W '```mermaid'
foreach ($ln in $viewFlat) { W $ln }
W '```'
W ''
W '### View 2 - tiered by dependency depth'
W ''
W 'Tiers are dependency depth (longest path to a leaf), not functional role: a Module sits higher only because it composes more layers beneath it.'
W ''
W '```mermaid'
foreach ($ln in $viewTiered) { W $ln }
W '```'
W ''

W '## Deployment closure (per Module)'
W ''
W '| Module | Direct deps (via Contracts) | Full transitive closure | Standalone? |'
W '|---|---|---|---|'
foreach ($m in $realModules) {
    $direct = if ($moduleDirect.ContainsKey($m)) { $moduleDirect[$m] } else { $null }
    $clo    = $closure[$m]
    $stand  = if ($clo.Count -eq 0) { 'yes (leaf)' } else { 'no' }
    W "| **$m** | $(Join-Set $direct) | $(Join-Set $clo) | $stand |"
}
W ''

W '## Dependency by project role'
W ''
W 'Which project kind introduces each cross-Module dependency. This is the'
W 'deployment-critical view: a host that ships only some kinds of a Module'
W 'inherits only those rows (e.g. a host that omits `.UI`).'
W ''
W '| Module | Role | Depends on |'
W '|---|---|---|'
foreach ($m in $realModules) {
    if (-not $roleDeps.ContainsKey($m)) {
        W "| **$m** | - | - |"
        continue
    }
    $first = $true
    foreach ($role in @(Sort-Ordinal $roleDeps[$m].Keys)) {
        $cell = if ($first) { "**$m**" } else { '' }
        W "| $cell | $role | $(Join-Set $roleDeps[$m][$role]) |"
        $first = $false
    }
}
W ''

W '## Cycles'
W ''
if ($cycles.Count -eq 0) {
    W 'None.'
} else {
    W 'These Modules are mutually reachable and form a single deployment unit:'
    W ''
    foreach ($c in $cycles) { W "- $c" }
}
W ''

W '## Hosts (composition roots)'
W ''
W 'The **implied closure** is the EXACT set of Module assemblies that ship in the host,'
W 'computed by walking the host''s actual `.csproj` references transitively, project by'
W 'project (not by rolling each composed Module up to its full closure). A host that'
W 'references only some projects of a Module inherits only the Modules those projects'
W 'reach, so this column matches what is emitted to the host''s `bin`.'
W ''
W '| Host | Modules composed | Implied closure (ships in bin) |'
W '|---|---|---|'
foreach ($hn in @(Sort-Ordinal $hosts.Keys)) {
    W "| $hn | $(Join-Set $hosts[$hn]) | $(Join-Set $hostClosure[$hn]) |"
}
W ''

# ---- 6. emit HTML (self-contained, Mermaid via CDN) -----------------------
$cycleSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($c in $cycles) { foreach ($n in ($c -split ' <-> ')) { [void]$cycleSet.Add($n.Trim()) } }

function He([string]$s) {
    if ($null -eq $s) { return '' }
    return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;')
}

$H = New-Object 'System.Collections.Generic.List[string]'
function WH([string]$s) { $script:H.Add($s) | Out-Null }

$head = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Module dependency graph</title>
<style>
:root { --line:#d0d7de; --head:#f3f6f9; --zebra:#fafbfc; --ink:#1f2328; --muted:#57606a; --accent:#0969da; --ok:#1a7f37; --warn:#9a6700; --warnbg:#fff8c5; --okbg:#dafbe1; }
* { box-sizing:border-box; }
body { font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; color:var(--ink); margin:0; padding:2rem 2.5rem 4rem; max-width:1040px; }
h1 { font-size:1.7rem; margin:0 0 .25rem; }
h2 { font-size:1.2rem; margin:2.2rem 0 .6rem; padding-bottom:.3rem; border-bottom:1px solid var(--line); }
h3 { font-size:1rem; margin:1.3rem 0 .2rem; color:var(--ink); }
p { line-height:1.5; color:var(--ink); }
p.note { color:var(--muted); font-size:.9rem; }
code { background:var(--head); padding:.1rem .35rem; border-radius:4px; font-size:.85em; }
table { border-collapse:collapse; width:100%; margin:.5rem 0 1rem; font-size:.92rem; }
th,td { border:1px solid var(--line); padding:.5rem .65rem; text-align:left; vertical-align:top; }
th { background:var(--head); font-weight:600; }
tbody tr:nth-child(even) { background:var(--zebra); }
.badge { display:inline-block; font-size:.78rem; font-weight:600; padding:.08rem .5rem; border-radius:999px; }
.badge.ok { background:var(--okbg); color:var(--ok); }
.badge.warn { background:var(--warnbg); color:var(--warn); }
.mermaid { background:var(--zebra); border:1px solid var(--line); border-radius:8px; padding:1rem; margin:.5rem 0 1rem; }
.cycles li { color:var(--warn); font-weight:600; }
.muted { color:var(--muted); }
</style>
</head>
<body>
'@
WH $head

WH '<h1>Module dependency graph</h1>'
WH '<p class="note">Generated by the <code>module-deps</code> skill (legacy Module-layout tool) from the <code>.csproj</code> ProjectReference graph. Do not edit by hand &mdash; regenerate with the <code>module-deps</code> skill.</p>'
WH '<p>Modules are the folders under <code>src/Modules/</code>. Cross-Module references go through <code>&lt;Name&gt;.Contracts</code>, so a "depends on" edge means: to host the consumer you may need to register an implementation of the target Module. The <strong>transitive closure</strong> is the Module set a host must compose. This is an <em>upper bound</em>: a Contracts reference used only for DTO/enum types needs no implementation registered.</p>'

WH '<h2>Modules</h2>'
WH '<p class="muted">Descriptions come from the <code>## &lt;Name&gt; (Module)</code> entries in <code>docs/glossary/README.md</code>.</p>'
WH '<table><thead><tr><th>Module</th><th>What it does</th></tr></thead><tbody>'
foreach ($m in $realModules) {
    if ($moduleDesc.ContainsKey($m)) {
        WH "<tr><td><strong>$(He $m)</strong></td><td>$(He $moduleDesc[$m])</td></tr>"
    } else {
        WH "<tr><td><strong>$(He $m)</strong></td><td class=""muted"">(no description - add a <code>## $(He $m) (Module)</code> entry to docs/glossary/README.md)</td></tr>"
    }
}
WH '</tbody></table>'

WH '<h2>Module graph</h2>'
WH '<p class="muted">Edge labels abbreviate the consuming project kind: <strong>A</strong> = .Application, <strong>I</strong> = .Infrastructure, <strong>U</strong> = .UI, <strong>Cl</strong> = .Client, <strong>Co</strong> = .Contracts, <strong>D</strong> = .Domain; any other kind is shown in full.</p>'
WH '<h3>View 1 &middot; Dependency graph</h3>'
WH '<pre class="mermaid">'
foreach ($ln in $viewFlat) { WH $ln }
WH '</pre>'
WH '<h3>View 2 &middot; Tiered by dependency depth</h3>'
WH '<p class="note">Tiers are dependency depth (longest path to a leaf), not functional role &mdash; a Module sits higher only because it composes more layers beneath it (the most composite Module lands on top).</p>'
WH '<pre class="mermaid">'
foreach ($ln in $viewTiered) { WH $ln }
WH '</pre>'

WH '<h2>Deployment closure (per Module)</h2>'
WH '<table><thead><tr><th>Module</th><th>Direct deps (via Contracts)</th><th>Full transitive closure</th><th>Status</th></tr></thead><tbody>'
foreach ($m in $realModules) {
    $direct = if ($moduleDirect.ContainsKey($m)) { $moduleDirect[$m] } else { $null }
    $clo    = $closure[$m]
    if ($clo.Count -eq 0) {
        $status = '<span class="badge ok">leaf</span>'
    } elseif ($cycleSet.Contains($m)) {
        $status = '<span class="badge warn">in cycle</span>'
    } else {
        $status = '<span class="muted">-</span>'
    }
    WH "<tr><td><strong>$(He $m)</strong></td><td>$(He (Join-Set $direct))</td><td>$(He (Join-Set $clo))</td><td>$status</td></tr>"
}
WH '</tbody></table>'

WH '<h2>Dependency by project role</h2>'
WH '<p class="muted">Which project kind introduces each cross-Module dependency. A host that ships only some kinds of a Module inherits only those rows (e.g. a host that omits <code>.UI</code>).</p>'
WH '<table><thead><tr><th>Module</th><th>Role</th><th>Depends on</th></tr></thead><tbody>'
foreach ($m in $realModules) {
    if (-not $roleDeps.ContainsKey($m)) {
        WH "<tr><td><strong>$(He $m)</strong></td><td class=""muted"">-</td><td class=""muted"">-</td></tr>"
        continue
    }
    $roles = @(Sort-Ordinal $roleDeps[$m].Keys)
    $first = $true
    foreach ($role in $roles) {
        if ($first) {
            WH "<tr><td rowspan=""$($roles.Count)""><strong>$(He $m)</strong></td><td>$(He $role)</td><td>$(He (Join-Set $roleDeps[$m][$role]))</td></tr>"
            $first = $false
        } else {
            WH "<tr><td>$(He $role)</td><td>$(He (Join-Set $roleDeps[$m][$role]))</td></tr>"
        }
    }
}
WH '</tbody></table>'

WH '<h2>Cycles</h2>'
if ($cycles.Count -eq 0) {
    WH '<p><span class="badge ok">none</span></p>'
} else {
    WH '<p>These Modules are mutually reachable and form a single deployment unit:</p>'
    WH '<ul class="cycles">'
    foreach ($c in $cycles) { WH "<li>$(He $c)</li>" }
    WH '</ul>'
}

WH '<h2>Hosts (composition roots)</h2>'
WH '<p class="muted">The <strong>implied closure</strong> is the exact set of Module assemblies that ship in the host, computed by walking the host''s actual <code>.csproj</code> references transitively, project by project (not by rolling each composed Module up to its full closure). A host that references only some projects of a Module inherits only the Modules those projects reach &mdash; so this column matches what is emitted to the host''s <code>bin</code>.</p>'
WH '<table><thead><tr><th>Host</th><th>Modules composed</th><th>Implied closure (ships in bin)</th></tr></thead><tbody>'
foreach ($hn in @(Sort-Ordinal $hosts.Keys)) {
    WH "<tr><td><code>$(He $hn)</code></td><td>$(He (Join-Set $hosts[$hn]))</td><td>$(He (Join-Set $hostClosure[$hn]))</td></tr>"
}
WH '</tbody></table>'

$foot = @'
<script type="module">
import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
mermaid.initialize({ startOnLoad: true, securityLevel: 'loose', theme: 'default' });
</script>
</body>
</html>
'@
WH $foot

# ---- 7. write -------------------------------------------------------------
# UTF-8 without a BOM, so glossary descriptions keep their accents.
$utf8 = New-Object System.Text.UTF8Encoding $false
foreach ($target in @($OutFile, $HtmlFile)) {
    $dir = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
}
[System.IO.File]::WriteAllText($OutFile,  (($L -join "`r`n") + "`r`n"), $utf8)
[System.IO.File]::WriteAllText($HtmlFile, (($H -join "`r`n") + "`r`n"), $utf8)

$htmlUri = ([System.Uri]$HtmlFile).AbsoluteUri
$mdUri   = ([System.Uri]$OutFile).AbsoluteUri

Write-Host "Wrote $OutFile"
Write-Host "Wrote $HtmlFile"
Write-Host ("Modules: {0}" -f ($realModules -join ', '))
if ($cycles.Count -gt 0) { Write-Host ("Cycles: {0}" -f ($cycles -join '; ')) }
Write-Host ""
Write-Host "Open in a browser (copy this URL):"
Write-Host "  $htmlUri"
Write-Host "Markdown: $mdUri"

# ---- 7b. auto-commit the two generated files (opt out with -NoCommit) ------
# The graph is a generated artifact; leaving it dirty in the primary checkout
# blocks unrelated feature integrations (git push . into the checked-out branch
# needs a clean tree under receive.denyCurrentBranch=updateInstead). So by
# default commit ONLY these two paths, ONLY when they changed. Never stages
# anything else (no add -A). Best-effort: a git failure is reported, not fatal.
# Git calls run with ErrorActionPreference Continue: under Windows PowerShell
# 5.1 a harmless stderr line (e.g. a line-ending warning) would otherwise throw.
if (-not $NoCommit) {
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git -C $RepoRoot add -- $OutFile $HtmlFile 2>$null
        & git -C $RepoRoot diff --cached --quiet -- $OutFile $HtmlFile 2>$null
        if ($LASTEXITCODE -ne 0) {
            & git -C $RepoRoot commit -m "docs: regenerate module dependency graph" -- $OutFile $HtmlFile 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Host "Committed the regenerated graph (module-dependencies.md + .html)." }
            else { Write-Host "Auto-commit skipped: git commit failed (files left staged)." }
        }
        else {
            Write-Host "Graph unchanged; nothing to commit."
        }
    }
    catch {
        Write-Host ("Auto-commit skipped: {0}" -f $_.Exception.Message)
    }
    finally { $ErrorActionPreference = $previousEap }
}

if ($Open) {
    # Launch a real browser explicitly. Start-Process on the .html alone honors
    # the file association, which may be an editor rather than a browser.
    # App-Paths names (msedge/chrome) resolve via Start-Process even when not
    # on PATH.
    $opened = $null
    foreach ($b in 'msedge','chrome','firefox') {
        try { Start-Process $b $htmlUri -ErrorAction Stop; $opened = $b; break } catch { }
    }
    if ($opened) { Write-Host ("Opened in {0}" -f $opened) }
    else { Write-Host "No browser found; open the URL above manually." }
}
