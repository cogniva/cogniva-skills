# module-deps.ps1
# Generates docs/architecture/module-dependencies.md from the .csproj graph.
# Source of truth: ProjectReference entries. The architecture forces every
# cross-Module read through <Name>.Contracts, so the .csproj graph IS the
# authoritative inter-Module dependency list. No build/restore required.
#
# ASCII-only on purpose (PS 5.1 mis-tokenizes non-ASCII .ps1 source).

[CmdletBinding()]
param(
    [string]$RepoRoot = $null,
    [string]$OutFile  = $null,
    [string]$HtmlFile = $null,
    [switch]$Open,
    [switch]$NoCommit   # by default the two generated files are auto-committed; pass -NoCommit to leave them dirty in the working tree
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    $RepoRoot = (Resolve-Path (Join-Path $here '..\..\..')).Path
}
if (-not $OutFile) {
    $OutFile = Join-Path $RepoRoot 'docs\architecture\module-dependencies.md'
}
if (-not $HtmlFile) {
    $HtmlFile = Join-Path $RepoRoot 'docs\architecture\module-dependencies.html'
}

$srcRoot = Join-Path $RepoRoot 'src'
if (-not (Test-Path $srcRoot)) { throw "src not found under $RepoRoot" }

# ---- 1. discover projects -------------------------------------------------
function Get-ModuleName([string]$rel) {
    if ($rel -match 'src[\\/]+Modules[\\/]+([^\\/]+)[\\/]+') { return $matches[1] }
    if ($rel -match 'src[\\/]+Shell[\\/]+')                  { return 'Shell' }
    if ($rel -match 'src[\\/]+Hosts[\\/]+')                  { return 'Host'  }
    return 'Other'
}
function Get-Role([string]$proj, [string]$module) {
    if ($proj -like "$module.*") {
        $rest = $proj.Substring($module.Length + 1)
        return ($rest -split '\.')[0]
    }
    return $proj
}

$projFiles = Get-ChildItem -Path $srcRoot -Recurse -Filter *.csproj
$projects  = @{}   # projName -> object

foreach ($f in $projFiles) {
    $rel  = $f.FullName.Substring($RepoRoot.Length).TrimStart('\','/')
    $name = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $mod  = Get-ModuleName $rel
    [xml]$xml = Get-Content -Raw -LiteralPath $f.FullName
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

$realModules = $projects.Values | Where-Object { $_.Module -notin @('Shell','Host','Other') } |
    Select-Object -ExpandProperty Module -Unique | Sort-Object

# ---- 1b. per-Module descriptions (hand-maintained) ------------------------
# One or two plain sentences per Module, for the human-facing "Modules" section.
# This is the ONLY hand-maintained data in this generator; everything else is
# derived from the .csproj graph. ASCII only (PS 5.1 mis-tokenizes non-ASCII).
# When a NEW Module appears without an entry here, the emitted section flags it
# so it does not silently go undocumented.
$moduleDesc = @{
    'Analysis' = 'Runs composable classifiers over a Document Set and stores their provenanced Claims. Owns the classifier and agent catalog, the analysis runner and results store, and the "analysis" job handler - it proposes claims but never promotes them to a document''s current properties.'
    'C3Data' = 'Owns the shared model: the Facet taxonomy and its node trees, the thesaurus (cultures and translations), and the relationships layered over them - Product algebra, RM policies, and Contexts. The model-management core that other Modules consume through C3Data.Contracts.'
    'Connectivity' = 'Owns Connections, Connectors, and canonical addressing (ResourceAddress), exposing crawl / structure / write capabilities per external system. The transport layer only - what to crawl and where things go is decided by consuming Modules.'
    'Crawling' = 'Discovers and ingests documents from external systems into the DocumentStore, running as Crawl jobs on the Jobs kernel over Connectivity connections.'
    'Destinations' = 'Mirrors an external system''s structure into a C3 Facet''s node tree and records, per synced node, the external location needed to route or migrate there. SharePoint-first.'
    'DocumentOrchestration' = 'The orchestration pipeline that takes a Selections outcome and acts on a document through Connectivity - classifying it in place (writing the resolved properties onto the item where it lives) and routing it (writing content and metadata to a destination). Owns no store of its own.'
    'DocumentStore' = 'Persists crawled documents so other Modules can read and update them: each is keyed by a source address, carries three property layers (Original / Current / Proposed), and has separable, lazily-loaded text and structure content.'
    'Jobs' = 'Owns the generic long-running-job lifecycle - the Job entity, its Status/Phase state machine, JSON config, checkpoint/resume, crash recovery, and the background runner. Other Modules plug work in via handlers keyed by job type; the kernel knows nothing about crawl, analysis, or migration specifics.'
    'Mapping' = 'Owns mappings between local identifiers and external ones; its first capability is Property Name Mapping (local name to repo name through a scope hierarchy). These mappings are first-class C3Data entities keyed by FacetId - they cascade-delete with their facet and bump the model version when written.'
    'Migration' = 'Copies crawled documents from their source system to destination locations as three chained job stages - PreMigration, Migration, then Validation - running on the Jobs kernel. Owns a per-item migration report store.'
    'Reasoning' = 'The LLM/model-assisted decision layer (not yet built): turns document text, evidence, and symbolic context into a classification candidate via structured prompts, behind a Contracts-only surface with replaceable, local-first model adapters. General LLM integration - cascading a Selection is one such case. Proposes; never decides or writes.'
    'Selections' = 'Computes the consequences of a tentative Selection: the valid values per Product algebra, pinches and auto-selects, the active Contexts, and the applicable RM policy. Consumed in-loop by classification.'
}

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
        if ($tgt.Module -eq 'Shell') { continue }            # Shell is UI infra, not a Module
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

$cycles = New-Object 'System.Collections.Generic.List[string]'
for ($i = 0; $i -lt $realModules.Count; $i++) {
    for ($j = $i + 1; $j -lt $realModules.Count; $j++) {
        $a = $realModules[$i]; $b = $realModules[$j]
        if ($closure[$a].Contains($b) -and $closure[$b].Contains($a)) {
            $cycles.Add("$a <-> $b") | Out-Null
        }
    }
}

# ---- 4. hosts -------------------------------------------------------------
# $hosts[name]  = Modules the host DIRECTLY references (the "composed" set).
# $hostClosure[name] = EXACT Module assemblies that ship in the host, computed by
#   walking the host's actual .csproj ProjectReferences transitively project-by-
#   project (NOT by rolling each composed Module up to its full Module closure).
#   A host that references only the DocumentStore-free projects of a Module does
#   NOT inherit DocumentStore - so this matches what is actually emitted to the bin.
$hosts = @{}
foreach ($p in $projects.Values | Where-Object { $_.Module -eq 'Host' }) {
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($r in $p.Refs) {
        if ($projects.ContainsKey($r)) {
            $m = $projects[$r].Module
            if ($m -notin @('Shell','Host','Other')) { [void]$set.Add($m) }
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
        if ($m -notin @('Shell','Host','Other')) { [void]$mods.Add($m) }
        foreach ($r in $projects[$cur].Refs) { $stack.Push($r) }
    }
    return ,$mods   # leading comma: return the HashSet itself, do not enumerate it
}
$hostClosure = @{}
foreach ($p in $projects.Values | Where-Object { $_.Module -eq 'Host' }) {
    $hostClosure[$p.Name] = Get-HostModuleClosure $p.Name
}

# ---- 4b. shared graph rendering (two Mermaid views) -----------------------
$roleAbbr = @{ 'Application' = 'A'; 'Infrastructure' = 'I'; 'UI' = 'U'; 'Client' = 'C' }
function Abbr-Label($roleSet) {
    $a = @()
    foreach ($r in $roleSet) {
        if ($roleAbbr.ContainsKey($r)) { $a += $roleAbbr[$r] } else { $a += $r.Substring(0, 1) }
    }
    return (($a | Sort-Object -Unique) -join ',')
}

# edge lines shared by both views (abbreviated role labels)
$edgeLines = New-Object 'System.Collections.Generic.List[string]'
foreach ($k in ($edgeRoles.Keys | Sort-Object)) {
    $parts = $k -split '\|'
    $edgeLines.Add("  $($parts[0]) -->|$(Abbr-Label $edgeRoles[$k])| $($parts[1])") | Out-Null
}

# dependency depth (longest path to a leaf) -> tiers
$depth = @{}
function Get-Depth([string]$m) {
    if ($script:depth.ContainsKey($m)) { return $script:depth[$m] }
    $d = 0
    if ($moduleDirect.ContainsKey($m)) {
        foreach ($t in $moduleDirect[$m]) {
            $td = (Get-Depth $t) + 1
            if ($td -gt $d) { $d = $td }
        }
    }
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
    foreach ($m in ($byTier[$t] | Sort-Object)) { $viewTiered.Add("    $m") | Out-Null }
    $viewTiered.Add('  end') | Out-Null
}
foreach ($e in $edgeLines) { $viewTiered.Add($e) | Out-Null }

# ---- 5. emit markdown -----------------------------------------------------
$L = New-Object 'System.Collections.Generic.List[string]'
function W([string]$s) { $script:L.Add($s) | Out-Null }

function Join-Set($set) {
    if (-not $set -or $set.Count -eq 0) { return '-' }
    return (($set | Sort-Object) -join ', ')
}

W '# Module dependency graph'
W ''
W '> GENERATED by the `module-deps` skill (module-deps.ps1) from the `.csproj`'
W '> ProjectReference graph. Do not edit by hand. Regenerate with the'
W '> `module-deps` skill (or run the script directly).'
W ''
W 'Cross-Module references go through `<Name>.Contracts` only, so a "depends on"'
W 'edge means: to host the consumer you MUST also register an implementation of'
W 'the target Module (its `.Application` in-process, or `.Client` over HTTP).'
W 'The **transitive closure** is therefore the Module set a host must compose.'
W ''

W '## Modules'
W ''
W 'A one-line description of what each Module is responsible for.'
W ''
W '| Module | What it does |'
W '|---|---|'
foreach ($m in $realModules) {
    $d = if ($moduleDesc.ContainsKey($m)) { $moduleDesc[$m] } else { '_(no description yet - add one to `$moduleDesc` in module-deps.ps1)_' }
    W "| **$m** | $d |"
}
W ''

W '## Module graph'
W ''
W 'Edge labels abbreviate the consuming project role: **A** = .Application, **I** = .Infrastructure, **U** = .UI, **C** = .Client.'
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
W 'Which role introduces each cross-Module dependency. This is the deployment-'
W 'critical view: a host that ships only some roles of a Module inherits only'
W 'those rows (e.g. an engine-only host that omits `.UI`).'
W ''
W '| Module | Role | Depends on |'
W '|---|---|---|'
foreach ($m in $realModules) {
    if (-not $roleDeps.ContainsKey($m)) {
        W "| **$m** | - | - |"
        continue
    }
    $roles = $roleDeps[$m].Keys | Sort-Object
    $first = $true
    foreach ($role in $roles) {
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
W 'references only the DocumentStore-free projects of a Module does not inherit'
W 'DocumentStore - so this column matches what is emitted to the host''s `bin`.'
W ''
W '| Host | Modules composed | Implied closure (ships in bin) |'
W '|---|---|---|'
foreach ($hn in ($hosts.Keys | Sort-Object)) {
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
WH '<p class="note">Generated by the <code>module-deps</code> skill (module-deps.ps1) from the <code>.csproj</code> ProjectReference graph. Do not edit by hand &mdash; regenerate with the <code>module-deps</code> skill.</p>'
WH '<p>Cross-Module references go through <code>&lt;Name&gt;.Contracts</code> only, so a "depends on" edge means: to host the consumer you may need to register an implementation of the target Module (its <code>.Application</code> in-process, or <code>.Client</code> over HTTP). The <strong>transitive closure</strong> is the Module set a host must compose. This is an <em>upper bound</em>: a Contracts reference used only for DTO/enum types needs no implementation registered.</p>'

WH '<h2>Modules</h2>'
WH '<p class="muted">A one-line description of what each Module is responsible for.</p>'
WH '<table><thead><tr><th>Module</th><th>What it does</th></tr></thead><tbody>'
foreach ($m in $realModules) {
    if ($moduleDesc.ContainsKey($m)) {
        WH "<tr><td><strong>$(He $m)</strong></td><td>$(He $moduleDesc[$m])</td></tr>"
    } else {
        WH "<tr><td><strong>$(He $m)</strong></td><td class=""muted"">(no description yet - add one to <code>`$moduleDesc</code> in module-deps.ps1)</td></tr>"
    }
}
WH '</tbody></table>'

WH '<h2>Module graph</h2>'
WH '<p class="muted">Edge labels abbreviate the consuming project role: <strong>A</strong> = .Application, <strong>I</strong> = .Infrastructure, <strong>U</strong> = .UI, <strong>C</strong> = .Client.</p>'
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
WH '<p class="muted">Which role introduces each cross-Module dependency. A host that ships only some roles of a Module inherits only those rows (e.g. an engine-only host that omits <code>.UI</code>).</p>'
WH '<table><thead><tr><th>Module</th><th>Role</th><th>Depends on</th></tr></thead><tbody>'
foreach ($m in $realModules) {
    if (-not $roleDeps.ContainsKey($m)) {
        WH "<tr><td><strong>$(He $m)</strong></td><td class=""muted"">-</td><td class=""muted"">-</td></tr>"
        continue
    }
    $roles = @($roleDeps[$m].Keys | Sort-Object)
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
WH '<p class="muted">The <strong>implied closure</strong> is the exact set of Module assemblies that ship in the host, computed by walking the host''s actual <code>.csproj</code> references transitively, project by project (not by rolling each composed Module up to its full closure). A host that references only the DocumentStore-free projects of a Module does not inherit DocumentStore &mdash; so this column matches what is emitted to the host''s <code>bin</code>.</p>'
WH '<table><thead><tr><th>Host</th><th>Modules composed</th><th>Implied closure (ships in bin)</th></tr></thead><tbody>'
foreach ($hn in ($hosts.Keys | Sort-Object)) {
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
$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
Set-Content -LiteralPath $OutFile  -Value ($L -join "`r`n") -Encoding ASCII
Set-Content -LiteralPath $HtmlFile -Value ($H -join "`r`n") -Encoding ASCII

$htmlUri = ([System.Uri]((Resolve-Path $HtmlFile).Path)).AbsoluteUri
$mdUri   = ([System.Uri]((Resolve-Path $OutFile).Path)).AbsoluteUri

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
if (-not $NoCommit) {
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
}

if ($Open) {
    # Launch a real browser explicitly. Start-Process on the .html alone honors
    # the file association, which on this machine is an editor (Notepad++), not
    # a browser. App-Paths names (msedge/chrome) resolve via Start-Process even
    # when not on PATH.
    $opened = $null
    foreach ($b in 'msedge','chrome','firefox') {
        try { Start-Process $b $htmlUri -ErrorAction Stop; $opened = $b; break } catch { }
    }
    if ($opened) { Write-Host ("Opened in {0}" -f $opened) }
    else { Write-Host "No browser found; open the URL above manually." }
}
