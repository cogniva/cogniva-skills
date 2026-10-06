 ModuleDepsLegacyTool — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/ModuleDepsLegacyTool
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

> **Status: implemented** on `feature/module-deps-legacy-tool` (PR #15). This
> plan is now the implementation record. The file contents in the tasks below
> have been updated to match the shipped files, including these changes made
> in review after the tasks first ran:
> - `module-deps.ps1` treats a cycle as a strongly connected component (a set
>   of mutually reachable Modules): `-Check` reports `A -> B -> C -> A` once,
>   as `A <-> B <-> C`, and an `allowed-cycles.txt` line allows exactly the set
>   of Modules it lists. Every Module in a cycle shares one tier.
> - `guard-module-cycles.js` strips a BOM from stdin as well as from
>   `policy.json` (written as the ASCII escape `\uFEFF`), resolves the git
>   root with `execFileSync` (never through a shell), and describes `block` as
>   feedback.
> - `SKILL.md`, the policy README template and ADR 0041 describe the hook as
>   edit-time feedback that cannot prevent an edit; hard enforcement is
>   `-Check` in a completion gate.
> - The test suites gained 3-Module cycle, shared-tier and shell-significant
>   repo path cases.
>
> The step narration (what each step expected to print, which assertions
> failed first) still describes the original run.

**Goal:** Stage 2a.0 of architecture profiles: make the plugin's `module-deps`
a reusable, data-free **legacy Module-layout tool** with a `-Check` cycle gate,
cycle-safe deterministic rendering, display-only glossary descriptions, and an
opt-in Claude Code edit-time feedback hook, so NewCogniva can later retire its
fork.

**Architecture:** `module-deps.ps1` stays one Windows PowerShell 5.1-compatible,
ASCII-only script. It gains `-Check`, which computes the cross-Module graph,
reports cycles not listed in `docs/architecture/allowed-cycles.txt`, exits 0/1
and writes nothing. A cycle is a strongly connected component (a set of
mutually reachable Modules), reported and allowed as a whole: one
`allowed-cycles.txt` line per cycle, Modules in any order. Every Module in a
cycle shares one tier (the fork's back-edge skip, which Task 1 first ported,
invented a hierarchy inside a cycle). Every sort is made ordinal, because PowerShell 7
randomises string hash codes and would otherwise change the output order from
run to run. The NewCogniva-specific `$moduleDesc` table, the `Shell` bucket and
the DocumentStore prose are removed; descriptions come only from the repo
glossary's `## <Name> (Module)` entries and are read after `-Check` has exited.
Output becomes UTF-8 without a BOM so glossary text survives. A new
`scripts/guard-module-cycles.js` `PostToolUse` hook runs `-Check` after a
`.csproj` edit, only in repos whose `.claude/cogniva-dev/policy.json` sets
`"moduleDepsCheck": true`. It fails open on everything except a confirmed
cycle. Because `PostToolUse` runs after the file has changed, its `block`
decision is feedback asking Claude to correct the edit; it cannot prevent one.
Hard enforcement is `-Check` in a completion gate. The tool reads no architecture profile, does no region graphing and no
layer enforcement, and does not support the CognivaShell layout.

**Read these first:**
- `docs/plans/FeatureLifecycle/ArchitectureProfiles/Stage2a-proposal.md` §4.0 — the approved scope
- `plugins/cogniva-dev/skills/module-deps/module-deps.ps1` — the script being replaced
- `plugins/cogniva-dev/scripts/nudge-backlog-commit.js` — the house style for plugin hooks (fail open, silent unless it must speak)
- `plugins/cogniva-dev/hooks/hooks.json` — where plugin hooks are registered
- `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md` — where `policy.json` keys are documented
- `docs/adr/0039-new-scripts-target-powershell-7.md` — why this script stays 5.1 (an existing script; hooks call `powershell.exe`)

## File structure (locked)

```
plugins/cogniva-dev/skills/module-deps/module-deps.ps1             # MOD — rewrite: -Check, cycle-safe ordinal-deterministic depth, no project data, glossary descriptions, git-top-level RepoRoot, UTF-8 output, distinct kind labels
plugins/cogniva-dev/skills/module-deps/SKILL.md                    # MOD — rewrite: legacy Module-layout tool, -Check, allowed cycles, descriptions, opt-in hook
plugins/cogniva-dev/tests/module-deps/module-deps.tests.ps1        # NEW (5.1) — script behaviour, determinism, leak and SKILL pins
plugins/cogniva-dev/scripts/guard-module-cycles.js                 # NEW — opt-in PostToolUse adapter around -Check
plugins/cogniva-dev/hooks/hooks.json                               # MOD — registers guard-module-cycles.js
plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1  # NEW (5.1) — hook behaviour and registration
plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md   # MOD — documents the moduleDepsCheck policy key
.claude/cogniva-dev/green-gate.json                                # MOD — registers both new suites
README.md                                                          # MOD — module-deps row says legacy Module layout + -Check
docs/adr/NNNN-module-deps-is-a-data-free-legacy-module-layout-tool.md  # NEW — written by Task 3 from ADR-C1
```

## Candidate ADRs

### ADR-C1: module-deps is a data-free legacy Module-layout tool with an opt-in cycle check
**Provenance:** Suggested by human
`module-deps` graphs only the legacy `src/Modules/<Name>/` layout that
`add-module` scaffolds, and ships no repository-specific data. Module
descriptions are display-only and come from the repo glossary's
`## <Name> (Module)` entries; allowed cycles come from the repo's
`docs/architecture/allowed-cycles.txt`. `-Check` is always callable on its own.
Edit-time feedback is a Claude Code `PostToolUse` adapter that acts only where
a repo opts in with `"moduleDepsCheck": true` in `.claude/cogniva-dev/policy.json`;
it runs after the edit, so it asks for a correction rather than preventing one.
Hard enforcement runs `-Check` in a completion gate.
**Write with:** Task 3 (written as ADR 0041)

## Task 1: module-deps.ps1 — -Check, determinism, no project data

**Files:**
- Test: `plugins/cogniva-dev/tests/module-deps/module-deps.tests.ps1` (create)
- Modify: `plugins/cogniva-dev/skills/module-deps/module-deps.ps1` (full replacement)

Constraints this task must honour:
- The script stays ASCII-only, because Windows PowerShell 5.1 mis-tokenises
  non-ASCII `.ps1` source that has no BOM.
- It stays runnable under both `powershell` (5.1) and `pwsh` (7).
- It contains no Module names, descriptions or other project data.
- `-Check` must never read the glossary and must never write or commit.
- The SKILL.md pins in this test fail until Task 3 rewrites SKILL.md. That is
  expected: Task 1 is done when every other assertion passes.

- [x] **Step 1 (failing test):** create `plugins/cogniva-dev/tests/module-deps/module-deps.tests.ps1` with exactly this content:

```powershell
 Dependency-free tests for the module-deps legacy Module-layout tool: -Check,
# allowed cycles, cycle-safe deterministic rendering, display-only glossary
# descriptions, kind labels, RepoRoot default, auto-commit, and no project data.
# Windows PowerShell 5.1. ASCII-only source.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$script = Join-Path $plugin 'skills\module-deps\module-deps.ps1'
$skill = Join-Path $plugin 'skills\module-deps\SKILL.md'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-module-deps-" + [guid]::NewGuid().ToString('N'))
$failures = @()
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Check($label, $condition) {
    if ($condition) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}
function Write-Text([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Text, $script:utf8NoBom)
}
# A project at <Repo>\<Folder>\<Name>\<Name>.csproj. module-deps resolves a
# ProjectReference by its file name, so the relative Include path is cosmetic.
function Add-Project([string]$Repo, [string]$Folder, [string]$Name, [string[]]$Refs) {
    $items = @($Refs | Where-Object { $_ } | ForEach-Object { "    <ProjectReference Include=`"..\$_\$_.csproj`" />" }) -join "`r`n"
    Write-Text (Join-Path $Repo "$Folder\$Name\$Name.csproj") "<Project Sdk=`"Microsoft.NET.Sdk`">`r`n  <ItemGroup>`r`n$items`r`n  </ItemGroup>`r`n</Project>`r`n"
}
function New-Repo([string]$Name) {
    $repo = Join-Path $root $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    & git -C $repo init -q
    & git -C $repo config user.email 'tests@cogniva.invalid'
    & git -C $repo config user.name 'Cogniva Tests'
    & git -C $repo config commit.gpgsign false
    & git -C $repo config core.autocrlf false
    return $repo
}
# Two Modules (A, B), a host, a Shell project and a BuildingBlocks project.
# A reaches B through four different kinds, one of them a qualified project.
function New-Fixture([string]$Name, [switch]$Cyclic) {
    $repo = New-Repo $Name
    Add-Project $repo 'src\Modules\A' 'A.Contracts' @('B.Contracts')
    Add-Project $repo 'src\Modules\A' 'A.Domain' @('App.Common')
    Add-Project $repo 'src\Modules\A' 'A.Application' @('A.Domain', 'A.Contracts', 'B.Contracts')
    Add-Project $repo 'src\Modules\A' 'A.Infrastructure.Store' @('A.Application', 'B.Contracts')
    Add-Project $repo 'src\Modules\A' 'A.Client' @('A.Contracts', 'B.Contracts')
    Add-Project $repo 'src\Modules\A' 'A.UI' @('A.Contracts', 'B.Contracts', 'App.Shell')
    Add-Project $repo 'src\Modules\B' 'B.Contracts' @()
    if ($Cyclic) { Add-Project $repo 'src\Modules\B' 'B.Application' @('B.Contracts', 'A.Contracts') }
    else { Add-Project $repo 'src\Modules\B' 'B.Application' @('B.Contracts') }
    Add-Project $repo 'src\Hosts' 'App.Host' @('A.Application', 'B.Application')
    Add-Project $repo 'src\Shell' 'App.Shell' @()
    Add-Project $repo 'src\BuildingBlocks' 'App.Common' @()
    return $repo
}
function Invoke-ModuleDeps([string[]]$Arguments, [string]$Shell = 'powershell', [string]$WorkingDirectory = $null) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if ($WorkingDirectory) { Push-Location -LiteralPath $WorkingDirectory }
    try {
        $lines = @(& $Shell -NoProfile -ExecutionPolicy Bypass -File $script @Arguments 2>&1)
        $code = $LASTEXITCODE
    }
    finally {
        if ($WorkingDirectory) { Pop-Location }
        $ErrorActionPreference = $previous
    }
    [pscustomobject]@{ Code = $code; Out = (@($lines | ForEach-Object { [string]$_ }) -join "`n") }
}
function Read-Utf8([string]$Path) { return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) }
function Get-CommitCount([string]$Repo) { return [int]((& git -C $Repo rev-list --count HEAD) | Select-Object -First 1) }
# Module -> tier number, read from the tiered Mermaid view of the Markdown.
function Get-Tiers([string]$MdText) {
    $tiers = @{}
    $tier = $null
    foreach ($line in ($MdText -split "`r?`n")) {
        if ($line -match '^\s*subgraph L(\d+)\[') { $tier = [int]$matches[1]; continue }
        if ($line -match '^\s*end\s*$') { $tier = $null; continue }
        if ($null -ne $tier -and $line -match '^\s{4}(\S+)\s*$') { $tiers[$matches[1]] = $tier }
    }
    return $tiers
}

try {
    # --- -Check -------------------------------------------------------------
    $acyclic = New-Fixture 'acyclic'
    $r = Invoke-ModuleDeps @('-RepoRoot', $acyclic, '-Check')
    Check '-Check on an acyclic graph exits 0' ($r.Code -eq 0 -and $r.Out -match 'module-deps check OK')
    Check '-Check writes nothing' (-not (Test-Path (Join-Path $acyclic 'docs\architecture')))

    $cyclic = New-Fixture 'cyclic' -Cyclic
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-Check')
    Check '-Check on a cycle exits 1 and names the pair' ($r.Code -eq 1 -and $r.Out -match 'A <-> B')
    Check '-Check names the kinds that introduce each edge' ($r.Out -match 'B -> A \(introduced by role\(s\): Application\)' -and $r.Out -match 'A -> B \(introduced by role\(s\): Application, Client, Contracts, Infrastructure, UI\)')
    Check '-Check on a cycle still writes nothing' (-not (Test-Path (Join-Path $cyclic 'docs\architecture')))

    $allowFile = Join-Path $cyclic 'docs\architecture\allowed-cycles.txt'
    Write-Text $allowFile "# Approved cycles.`r`nB <-> A   # reviewed: test fixture`r`n"
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-Check')
    Check 'an allowed pair passes in either order, with a trailing comment' ($r.Code -eq 0)
    Write-Text $allowFile "A - B`r`n"
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-Check')
    Check 'a malformed allowed-cycles line allows nothing and is reported' ($r.Code -eq 1 -and $r.Out -match "WARN: allowed-cycles\.txt line 1")
    Remove-Item -LiteralPath (Join-Path $cyclic 'docs') -Recurse -Force

    # A -> B -> C -> A is ONE cycle (one set of mutually reachable Modules),
    # reported and approved as a whole, never as three pairs.
    $tri = New-Repo 'three-cycle'
    Add-Project $tri 'src\Modules\A' 'A.Contracts' @()
    Add-Project $tri 'src\Modules\A' 'A.Application' @('A.Contracts', 'B.Contracts')
    Add-Project $tri 'src\Modules\B' 'B.Contracts' @()
    Add-Project $tri 'src\Modules\B' 'B.Application' @('B.Contracts', 'C.Contracts')
    Add-Project $tri 'src\Modules\C' 'C.Contracts' @()
    Add-Project $tri 'src\Modules\C' 'C.Application' @('C.Contracts', 'A.Contracts')
    $r = Invoke-ModuleDeps @('-RepoRoot', $tri, '-Check')
    Check 'a 3-Module cycle is reported once, as the whole cycle' ($r.Code -eq 1 -and $r.Out -match '(?m)^  A <-> B <-> C\s*$' -and $r.Out -notmatch '(?m)^  A <-> C\s*$' -and $r.Out -match 'C -> A \(introduced by role\(s\): Application\)')
    $triAllow = Join-Path $tri 'docs\architecture\allowed-cycles.txt'
    Write-Text $triAllow "A <-> B`nB <-> C`nA <-> C`n"
    $r = Invoke-ModuleDeps @('-RepoRoot', $tri, '-Check')
    Check 'pairs do not approve a larger cycle' ($r.Code -eq 1)
    Write-Text $triAllow "C <-> A <-> B   # reviewed: test fixture`n"
    $r = Invoke-ModuleDeps @('-RepoRoot', $tri, '-Check')
    Check 'a whole-cycle line approves it, members in any order' ($r.Code -eq 0)
    Write-Text $triAllow "A <-> A`n"
    $r = Invoke-ModuleDeps @('-RepoRoot', $tri, '-Check')
    Check 'a line repeating a Module is malformed' ($r.Code -eq 1 -and $r.Out -match 'WARN: allowed-cycles\.txt line 1')
    Remove-Item -LiteralPath (Join-Path $tri 'docs') -Recurse -Force
    $r = Invoke-ModuleDeps @('-RepoRoot', $tri, '-NoCommit')
    $triMd = Read-Utf8 (Join-Path $tri 'docs\architecture\module-dependencies.md')
    Check 'the Cycles section lists the 3-Module cycle once' ($triMd -match '(?m)^- A <-> B <-> C\s*$' -and $triMd -notmatch '(?m)^- A <-> C\s*$')

    # Descriptions are display-only: an unreadable glossary changes nothing in -Check.
    $glossaryPath = Join-Path $cyclic 'docs\glossary\README.md'
    New-Item -ItemType Directory -Path $glossaryPath -Force | Out-Null   # a directory where the file should be
    $r2 = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-Check')
    Check '-Check never reads the glossary' ($r2.Code -eq 1 -and $r2.Out -notmatch 'glossary')
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-NoCommit')
    Check 'an unreadable glossary only warns during generation' ($r.Code -eq 0 -and $r.Out -match 'WARN: could not read Module descriptions')
    Remove-Item -LiteralPath (Join-Path $cyclic 'docs') -Recurse -Force

    # --- generation on a cyclic graph ---------------------------------------
    $md = Join-Path $cyclic 'docs\architecture\module-dependencies.md'
    $html = Join-Path $cyclic 'docs\architecture\module-dependencies.html'
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-NoCommit')
    Check 'a cyclic graph renders instead of overflowing' ($r.Code -eq 0 -and (Test-Path $md) -and (Test-Path $html))
    $mdText = Read-Utf8 $md
    Check 'the cycle is listed in the Cycles section' ($mdText -match '(?m)^- A <-> B\s*$')
    Check 'Shell and BuildingBlocks projects are outside the graph' ($r.Out -match '(?m)^Modules: A, B\s*$' -and $mdText -notmatch 'App\.Shell' -and $mdText -notmatch '\*\*Shell\*\*')
    Check 'qualified projects roll up to their kind' ($mdText -match '\| Infrastructure \| B \|')
    Check 'Contracts and Client get distinct labels' ($mdText -match 'A -->\|A,Cl,Co,I,U\| B' -and $mdText -match '\*\*Cl\*\* = \.Client' -and $mdText -match '\*\*Co\*\* = \.Contracts')
    $firstMd = [System.IO.File]::ReadAllBytes($md)
    $firstHtml = [System.IO.File]::ReadAllBytes($html)
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-NoCommit')
    Check 'output is byte-identical across runs' (([Convert]::ToBase64String($firstMd) -eq [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($md))) -and ([Convert]::ToBase64String($firstHtml) -eq [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($html))))
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-NoCommit') 'pwsh'
        Check 'PowerShell 7 produces the same bytes as 5.1' ($r.Code -eq 0 -and ([Convert]::ToBase64String($firstMd) -eq [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($md))) -and ([Convert]::ToBase64String($firstHtml) -eq [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($html))))
    }
    else { Write-Host '  SKIP  cross-host determinism (pwsh not installed)' }

    # A <-> B is a cycle, B also uses the leaf C, and D uses A. A cycle is one
    # deployment unit, so its Modules share a tier: C=0, A=B=1, D=2.
    $tiered = New-Repo 'tiers'
    Add-Project $tiered 'src\Modules\A' 'A.Contracts' @()
    Add-Project $tiered 'src\Modules\A' 'A.Application' @('A.Contracts', 'B.Contracts')
    Add-Project $tiered 'src\Modules\B' 'B.Contracts' @()
    Add-Project $tiered 'src\Modules\B' 'B.Application' @('B.Contracts', 'A.Contracts', 'C.Contracts')
    Add-Project $tiered 'src\Modules\C' 'C.Contracts' @()
    Add-Project $tiered 'src\Modules\D' 'D.Application' @('A.Contracts')
    $r = Invoke-ModuleDeps @('-RepoRoot', $tiered, '-NoCommit')
    $tiers = Get-Tiers (Read-Utf8 (Join-Path $tiered 'docs\architecture\module-dependencies.md'))
    Check 'Modules in one cycle share a tier, and depth is measured from that tier' ($r.Code -eq 0 -and $tiers['C'] -eq 0 -and $tiers['A'] -eq 1 -and $tiers['B'] -eq 1 -and $tiers['D'] -eq 2)

    # --- descriptions from the glossary -------------------------------------
    $e = [string][char]0x00E9
    Write-Text (Join-Path $cyclic 'docs\glossary\README.md') "# Glossary`n`n## A (Module)`n`nOwns [things](#thing) | pipes, caf$e.`nSecond line.`n`nNot part of it.`n`n## Other`n`nText.`n"
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-NoCommit')
    $mdText = Read-Utf8 $md
    Check 'a glossary entry becomes the description, links reduced to text' ($mdText.Contains("| **A** | Owns things \| pipes, caf$e. Second line. |"))
    Check 'a Module without an entry gets the glossary placeholder' ($mdText.Contains('add a `## B (Module)` entry to docs/glossary/README.md'))
    $bytes = [System.IO.File]::ReadAllBytes($html)
    Check 'output is UTF-8 without a BOM and keeps non-ASCII text' (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) -and (Read-Utf8 $html).Contains("caf$e"))

    # --- RepoRoot default ---------------------------------------------------
    $nested = New-Fixture 'repo-root-default'
    $r = Invoke-ModuleDeps @('-NoCommit') 'powershell' (Join-Path $nested 'src\Modules')
    Check 'RepoRoot defaults to the git top level of the current directory' ($r.Code -eq 0 -and (Test-Path (Join-Path $nested 'docs\architecture\module-dependencies.md')))
    $outside = Join-Path $root 'not-a-repo'
    New-Item -ItemType Directory -Path $outside -Force | Out-Null
    $r = Invoke-ModuleDeps @('-NoCommit') 'powershell' $outside
    Check 'outside a git repo it stops and asks for -RepoRoot' ($r.Code -ne 0 -and $r.Out -match 'pass -RepoRoot')

    # --- commit behaviour ---------------------------------------------------
    $commit = New-Fixture 'commit'
    & git -C $commit add -A
    & git -C $commit commit -q -m 'fixture'
    $before = Get-CommitCount $commit
    $r = Invoke-ModuleDeps @('-RepoRoot', $commit, '-NoCommit')
    Check '-NoCommit creates no commit' ((Get-CommitCount $commit) -eq $before)
    $r = Invoke-ModuleDeps @('-RepoRoot', $commit)
    $subject = (& git -C $commit log -1 --format=%s) | Select-Object -First 1
    Check 'the default run commits only the two graph files' ((Get-CommitCount $commit) -eq ($before + 1) -and $subject -eq 'docs: regenerate module dependency graph' -and @(& git -C $commit show --name-only --format= HEAD | Where-Object { $_ }).Count -eq 2)
    $r = Invoke-ModuleDeps @('-RepoRoot', $commit)
    Check 'an unchanged graph is not committed again' ((Get-CommitCount $commit) -eq ($before + 1) -and $r.Out -match 'Graph unchanged')

    # --- no project data, ASCII source, SKILL contract ----------------------
    $source = [System.IO.File]::ReadAllText($script)
    $leaks = @('NewCogniva', 'CognivaShell', 'Analysis', 'C3Data', 'Connectivity', 'Crawling', 'Destinations', 'DocumentOrchestration', 'DocumentStore', 'GovernanceOrchestration', 'Import', 'Jobs', 'Mapping', 'Migration', 'Reasoning', 'Selections', 'StructureInsights') | Where-Object { $source -cmatch "\b$_\b" }
    Check 'the script carries no project names or data' (@($leaks).Count -eq 0 -and $source -cnotmatch "'Shell'")
    Check 'the script source is ASCII-only' (@([System.IO.File]::ReadAllBytes($script) | Where-Object { $_ -gt 127 }).Count -eq 0)
    $skillText = [System.IO.File]::ReadAllText($skill)
    Check 'SKILL.md calls it the legacy Module-layout tool' ($skillText -match 'legacy Module-layout tool')
    Check 'SKILL.md documents -Check and allowed cycles' ($skillText -match '-Check' -and $skillText -match 'allowed-cycles\.txt')
    Check 'SKILL.md documents glossary descriptions and the opt-in hook' ($skillText -match '## <Name> \(Module\)' -and $skillText -match 'moduleDepsCheck')
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All module-deps assertions passed.'
exit 0
```

- [x] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/module-deps/module-deps.tests.ps1` → exits 1 with FAIL lines (no `-Check` parameter yet, and a cyclic graph overflows the call stack).

- [x] **Step 3 (implement):** replace the whole of `plugins/cogniva-dev/skills/module-deps/module-deps.ps1` with exactly this content (ASCII only):

```powershell
 module-deps.ps1
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

# Cycles are strongly connected components: sets of Modules that can all
# reach each other. Each component is keyed by its ordinally-first member; one
# with two or more members is a cycle, written "A <-> B <-> C" with its members
# in ordinal order. A cycle is one deployment unit, reported and approved as a
# whole, never as the pairs inside it.
$component        = @{}   # module -> component key
$componentMembers = @{}   # component key -> its members, ordinal order
foreach ($m in $realModules) {
    $members = @(Sort-Ordinal (@($m) + @($realModules | Where-Object { $_ -ne $m -and $closure[$m].Contains($_) -and $closure[$_].Contains($m) })))
    $component[$m] = $members[0]
    $componentMembers[$members[0]] = $members
}
$cycles = New-Object 'System.Collections.Generic.List[string]'
foreach ($k in @(Sort-Ordinal $componentMembers.Keys)) {
    if ($componentMembers[$k].Count -ge 2) { $cycles.Add(($componentMembers[$k] -join ' <-> ')) | Out-Null }
}

# ---- 3b. gate mode (-Check): report and exit, write nothing ----------------
# Cycles listed in docs/architecture/allowed-cycles.txt are tolerated: one
# cycle per line, its Modules joined by "<->" in any order ("A <-> B",
# "A <-> B <-> C"). A line allows exactly that set of Modules: when a cycle
# grows or shrinks, it needs a new line. '#' starts a comment (a trailing
# "# reason" is encouraged), blank lines are ignored. Adding a line is a
# deliberate, reviewed act. -Check never reads the glossary.
if ($Check) {
    $allowFile = Join-Path $RepoRoot 'docs\architecture\allowed-cycles.txt'
    $allowed = New-Object 'System.Collections.Generic.HashSet[string]'
    if (Test-Path -LiteralPath $allowFile -PathType Leaf) {
        $lineNo = 0
        foreach ($ln in [System.IO.File]::ReadAllLines($allowFile, [System.Text.Encoding]::UTF8)) {
            $lineNo++
            $t = ($ln -split '#', 2)[0].Trim()
            if (-not $t) { continue }
            $parts = @($t -split '<->' | ForEach-Object { $_.Trim() })
            $names = @(Sort-Ordinal ($parts | Select-Object -Unique))
            if ($parts.Count -lt 2 -or @($parts | Where-Object { -not $_ }).Count -gt 0 -or $names.Count -ne $parts.Count) {
                Write-Host ("WARN: allowed-cycles.txt line {0} is not 'A <-> B [<-> C ...]' with distinct Modules, and allows nothing: {1}" -f $lineNo, $t)
                continue
            }
            [void]$allowed.Add(($names -join ' <-> '))
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
        $members = $c -split ' <-> '
        foreach ($k in @(Sort-Ordinal $edgeRoles.Keys)) {
            $p = $k -split '\|'
            if ($members -ccontains $p[0] -and $members -ccontains $p[1]) {
                Write-Host ("    {0} -> {1} (introduced by role(s): {2})" -f $p[0], $p[1], (@(Sort-Ordinal $edgeRoles[$k]) -join ', '))
            }
        }
    }
    Write-Host 'Cross-Module references must stay acyclic.'
    Write-Host 'Fix a ProjectReference, or - deliberate and reviewed only - add the whole cycle as one line to docs/architecture/allowed-cycles.txt (Modules in any order; a trailing "# reason" is encouraged).'
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
# Modules in one cycle (one strongly connected component, section 3) are one
# deployment unit and share a tier. Depth is the longest path to a leaf in the
# graph of components, which is acyclic, so the recursion always terminates.
# Components and their targets are visited in ordinal order, so tiers are the
# same on every run.
$componentDeps = @{}   # component key -> other component keys it depends on
foreach ($m in $realModules) {
    $c = $component[$m]
    if (-not $componentDeps.ContainsKey($c)) { $componentDeps[$c] = New-Object 'System.Collections.Generic.HashSet[string]' }
    if ($moduleDirect.ContainsKey($m)) {
        foreach ($t in $moduleDirect[$m]) {
            if ($component[$t] -ne $c) { [void]$componentDeps[$c].Add($component[$t]) }
        }
    }
}
$componentDepth = @{}
function Get-ComponentDepth([string]$c) {
    if ($script:componentDepth.ContainsKey($c)) { return $script:componentDepth[$c] }
    $d = 0
    foreach ($t in @(Sort-Ordinal $script:componentDeps[$c])) {
        $td = (Get-ComponentDepth $t) + 1
        if ($td -gt $d) { $d = $td }
    }
    $script:componentDepth[$c] = $d
    return $d
}
$depth = @{}
foreach ($m in $realModules) { $depth[$m] = Get-ComponentDepth $component[$m] }
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
W 'Tiers are dependency depth (longest path to a leaf), not functional role: a Module sits higher only because it composes more layers beneath it. Modules in a cycle share a tier.'
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
    W 'Each line is one cycle: its Modules are mutually reachable and form a single deployment unit.'
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
WH '<p class="note">Tiers are dependency depth (longest path to a leaf), not functional role &mdash; a Module sits higher only because it composes more layers beneath it (the most composite Module lands on top). Modules in a cycle share a tier.</p>'
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
    WH '<p>Each line is one cycle: its Modules are mutually reachable and form a single deployment unit.</p>'
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
```

- [x] **Step 4 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/module-deps/module-deps.tests.ps1` → every assertion PASSES except the three `SKILL.md ...` pins (Task 3 makes those pass). If anything else fails, fix the script, not the test. (The suite's `the script source is ASCII-only` assertion is the ASCII check.)

- [x] **Step 5 (commit):** `git add plugins/cogniva-dev/skills/module-deps/module-deps.ps1 plugins/cogniva-dev/tests/module-deps/module-deps.tests.ps1` then `git commit -m "feat(module-deps): -Check, cycle-safe deterministic graph, no project data"`

## Task 2: Opt-in PostToolUse cycle hook

**Files:**
- Test: `plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1` (create)
- Create: `plugins/cogniva-dev/scripts/guard-module-cycles.js`
- Modify: `plugins/cogniva-dev/hooks/hooks.json`

Constraints this task must honour:
- The hook only ever returns a `block` decision on a confirmed cycle:
  `module-deps.ps1 -Check` exits 1 and prints a report. `PostToolUse` runs
  after the file has changed, so that decision is feedback asking Claude to
  correct the edit; it cannot prevent the edit.
- In every other case it exits 0 silently: not a `.csproj`, no git, no opt-in,
  no PowerShell, a timeout, or a script error.
- It acts only when the edited file's repo has
  `.claude/cogniva-dev/policy.json` with `"moduleDepsCheck": true`. Absent,
  unreadable, `false` or any other value means off.
- It finds `module-deps.ps1` relative to itself (inside the plugin), never
  inside the target repo.
- `-Check` stays independently callable; the hook is only an adapter around it.

- [x] **Step 1 (failing test):** create `plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1` with exactly this content:

```powershell
 Dependency-free tests for the opt-in module-deps PostToolUse hook
# (scripts/guard-module-cycles.js): it returns block feedback only for a confirmed cycle in a repo
# that opted in, and is silent everywhere else. Windows PowerShell 5.1.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$hook = Join-Path $plugin 'scripts\guard-module-cycles.js'
$hooksJson = Join-Path $plugin 'hooks\hooks.json'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-module-cycles-hook-" + [guid]::NewGuid().ToString('N'))
$failures = @()
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Check($label, $condition) {
    if ($condition) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}
function Write-Text([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Text, $script:utf8NoBom)
}
function Add-Project([string]$Repo, [string]$Folder, [string]$Name, [string[]]$Refs) {
    $items = @($Refs | Where-Object { $_ } | ForEach-Object { "    <ProjectReference Include=`"..\$_\$_.csproj`" />" }) -join "`r`n"
    Write-Text (Join-Path $Repo "$Folder\$Name\$Name.csproj") "<Project Sdk=`"Microsoft.NET.Sdk`">`r`n  <ItemGroup>`r`n$items`r`n  </ItemGroup>`r`n</Project>`r`n"
}
function Invoke-Hook([string]$FilePath) {
    $payload = @{ tool_name = 'Edit'; tool_input = @{ file_path = $FilePath } } | ConvertTo-Json -Compress
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = @($payload | & node $hook 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    [pscustomobject]@{ Code = $code; Out = ((@($lines | ForEach-Object { [string]$_ }) -join "`n").Trim()) }
}

# Registration is checked even without node.
$registered = Get-Content -Raw -LiteralPath $hooksJson | ConvertFrom-Json
$post = @($registered.hooks.PostToolUse | Where-Object { $_.matcher -eq 'Write|Edit' } | ForEach-Object { $_.hooks } | Where-Object { $_.command -match 'guard-module-cycles\.js' })
Check 'hooks.json registers guard-module-cycles.js as a Write|Edit PostToolUse hook' ($post.Count -eq 1 -and $post[0].command -match '\$\{CLAUDE_PLUGIN_ROOT\}/scripts/guard-module-cycles\.js')

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host '  SKIP  hook behaviour (node not installed)'
}
else {
    try {
        $repo = Join-Path $root 'repo'
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        & git -C $repo init -q
        Add-Project $repo 'src\Modules\A' 'A.Contracts' @()
        Add-Project $repo 'src\Modules\A' 'A.Application' @('A.Contracts', 'B.Contracts')
        Add-Project $repo 'src\Modules\B' 'B.Contracts' @()
        Add-Project $repo 'src\Modules\B' 'B.Application' @('B.Contracts', 'A.Contracts')
        $csproj = Join-Path $repo 'src\Modules\B\B.Application\B.Application.csproj'
        $policy = Join-Path $repo '.claude\cogniva-dev\policy.json'

        $r = Invoke-Hook (Join-Path $repo 'README.md')
        Check 'a non-.csproj edit is silent' ($r.Code -eq 0 -and -not $r.Out)
        $r = Invoke-Hook $csproj
        Check 'a repo without policy.json is silent, even with a cycle' ($r.Code -eq 0 -and -not $r.Out)
        Write-Text $policy '{ "moduleDepsCheck": false }'
        $r = Invoke-Hook $csproj
        Check 'moduleDepsCheck false is silent' ($r.Code -eq 0 -and -not $r.Out)
        Write-Text $policy '{ "moduleDepsCheck": "yes" }'
        $r = Invoke-Hook $csproj
        Check 'a non-boolean moduleDepsCheck is silent' ($r.Code -eq 0 -and -not $r.Out)
        Write-Text $policy '{ "requiredDevelopmentBranchPrefix": "feature/", "moduleDepsCheck": true }'
        $r = Invoke-Hook $csproj
        $decision = $null
        try { $decision = $r.Out | ConvertFrom-Json } catch { }
        Check 'an opted-in repo with a cycle is blocked with the -Check report' ($r.Code -eq 0 -and $decision -and $decision.decision -eq 'block' -and $decision.reason -match 'A <-> B')
        Write-Text (Join-Path $repo 'docs\architecture\allowed-cycles.txt') "B <-> A  # reviewed`n"
        $r = Invoke-Hook $csproj
        Check 'an allowed cycle is not blocked' ($r.Code -eq 0 -and -not $r.Out)
        Remove-Item -LiteralPath (Join-Path $repo 'docs') -Recurse -Force
        Add-Project $repo 'src\Modules\B' 'B.Application' @('B.Contracts')
        $r = Invoke-Hook $csproj
        Check 'an opted-in repo without a cycle is silent' ($r.Code -eq 0 -and -not $r.Out)

        # The edited path must never pass through a shell: cmd.exe expands
        # %OS% even inside quotes, and /bin/sh runs $(...).
        $odd = Join-Path $root 'sh & %OS% $(echo x) ;q'
        New-Item -ItemType Directory -Path $odd -Force | Out-Null
        & git -C $odd init -q
        Add-Project $odd 'src\Modules\A' 'A.Contracts' @()
        Add-Project $odd 'src\Modules\A' 'A.Application' @('A.Contracts', 'B.Contracts')
        Add-Project $odd 'src\Modules\B' 'B.Contracts' @()
        Add-Project $odd 'src\Modules\B' 'B.Application' @('B.Contracts', 'A.Contracts')
        Write-Text (Join-Path $odd '.claude\cogniva-dev\policy.json') '{ "moduleDepsCheck": true }'
        $r = Invoke-Hook (Join-Path $odd 'src\Modules\B\B.Application\B.Application.csproj')
        $decision = $null
        try { $decision = $r.Out | ConvertFrom-Json } catch { }
        Check 'a repo path with shell-significant characters still gets the -Check report' ($r.Code -eq 0 -and $decision -and $decision.decision -eq 'block' -and $decision.reason -match 'A <-> B')

        $loose = Join-Path $root 'loose\X.csproj'
        Write-Text $loose '<Project />'
        $r = Invoke-Hook $loose
        Check 'a .csproj outside any git repo is silent' ($r.Code -eq 0 -and -not $r.Out)
        $r = Invoke-Hook (Join-Path $repo 'src\Modules\Z\Z.Missing\Z.Missing.csproj')
        Check 'a path whose folder does not exist is silent' ($r.Code -eq 0 -and -not $r.Out)
    }
    finally {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All guard-module-cycles assertions passed.'
exit 0
```

- [x] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1` → exits 1. The registration check FAILs, and so does the opted-in block case (the hook script does not exist yet).

- [x] **Step 3 (implement the hook):** create `plugins/cogniva-dev/scripts/guard-module-cycles.js` with exactly this content:

```javascript
/ PostToolUse (Write|Edit) adapter for `module-deps -Check`: after a .csproj
// edit, return decision "block" - feedback asking Claude to correct it - when
// the edit leaves a cross-Module dependency cycle that
// docs/architecture/allowed-cycles.txt does not allow. PostToolUse runs after
// the file has changed, so this cannot prevent the edit; hard enforcement is
// -Check in a completion gate.
//
// OPT-IN per repo: acts only when the edited file's repo has
// .claude/cogniva-dev/policy.json with "moduleDepsCheck": true. Every other
// repo is untouched. `module-deps.ps1 -Check` stays callable on its own (git
// hooks, CI, by hand); this hook is only the Claude Code adapter around it.
//
// Contract: only ever return "block" on a confirmed cycle (-Check exit 1 with a report).
// On any uncertainty or error - not a .csproj, no git, no opt-in, no
// PowerShell, timeout, script error - exit 0 silently.
const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const SCRIPT = path.join(__dirname, '..', 'skills', 'module-deps', 'module-deps.ps1');

function allow() { process.exit(0); }

function optedIn(top) {
  try {
    const text = fs.readFileSync(path.join(top, '.claude', 'cogniva-dev', 'policy.json'), 'utf8');
    const policy = JSON.parse(text.replace(/^\uFEFF/, ''));
    return !!policy && policy.moduleDepsCheck === true;
  } catch (e) { return false; }
}

// Returns the -Check report when a disallowed cycle is confirmed, else null.
function runCheck(top) {
  for (const shell of ['powershell.exe', 'pwsh']) {
    try {
      execFileSync(shell,
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', SCRIPT, '-Check', '-RepoRoot', top],
        { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 90000 });
      return null; // exit 0: no disallowed cycle
    } catch (e) {
      if (e.code === 'ENOENT') continue; // this shell is not installed: try the next
      if (e.status === 1 && e.stdout) return String(e.stdout);
      return null; // timeout, script error, ... -> never hard-fail
    }
  }
  return null;
}

let raw = '';
process.stdin.on('data', d => (raw += d)).on('end', () => {
  try {
    // Windows PowerShell 5.1 can prefix piped stdin with a UTF-8 BOM.
    const input = JSON.parse((raw || '{}').replace(/^\uFEFF/, ''));
    const fp = (input.tool_input || {}).file_path;
    if (!fp || !/\.csproj$/i.test(fp)) return allow();

    const dir = path.dirname(path.resolve(fp));
    if (!fs.existsSync(dir)) return allow();

    let top;
    try {
      // execFileSync, not execSync: the edited path must never pass through a shell.
      top = execFileSync('git', ['-C', dir, 'rev-parse', '--show-toplevel'], {
        encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
      }).trim();
    } catch (e) { return allow(); } // not a git repo
    if (!top || !optedIn(top) || !fs.existsSync(SCRIPT)) return allow();

    const report = runCheck(top);
    if (!report) return allow();
    process.stdout.write(JSON.stringify({
      decision: 'block',
      reason: 'This .csproj edit leaves a cross-Module dependency cycle (module-deps -Check). ' +
        'Revert or change the ProjectReference so cross-Module references stay acyclic, or - ' +
        'deliberate and reviewed only - add the whole cycle as one line to docs/architecture/allowed-cycles.txt.\n\n' +
        report,
    }));
    process.exit(0);
  } catch (e) { return allow(); }
});
```

- [x] **Step 4 (register the hook):** replace the whole of `plugins/cogniva-dev/hooks/hooks.json` with exactly this content (the existing three hooks are unchanged; the new one joins the `Write|Edit` PostToolUse entry):

```json

  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/guard-primary-edit.js\"",
            "timeout": 20,
            "statusMessage": "Guarding primary checkout (edits must use a worktree)"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/guard-primary-git.js\"",
            "timeout": 15,
            "statusMessage": "Checking git command against shared-checkout branch guard"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/nudge-backlog-commit.js\"",
            "timeout": 15,
            "statusMessage": "Checking for an uncommitted backlog capture in the primary checkout"
          },
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/guard-module-cycles.js\"",
            "timeout": 100,
            "statusMessage": "Checking the Module graph for cycles (repos that opt in only)"
          }
        ]
      }
    ]
  }
}
```

- [x] **Step 5 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1` → `All guard-module-cycles assertions passed.` Then `claude plugin validate .` → passes.

- [x] **Step 6 (commit):** `git add plugins/cogniva-dev/scripts/guard-module-cycles.js plugins/cogniva-dev/hooks/hooks.json plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1` then `git commit -m "feat(module-deps): opt-in PostToolUse cycle hook"`

## Task 3: Documentation, green gate, ADR

**Files:**
- Modify: `plugins/cogniva-dev/skills/module-deps/SKILL.md` (full replacement)
- Modify: `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md`
- Modify: `.claude/cogniva-dev/green-gate.json`
- Modify: `README.md`
- Create: `docs/adr/NNNN-module-deps-is-a-data-free-legacy-module-layout-tool.md`

Constraints this task must honour:
- Describe `module-deps` as a **legacy Module-layout tool** everywhere.
- Do not claim it reads architecture profiles, graphs regions, enforces layer
  rules, or supports a non-Module layout.
- Do not change any plugin `version` field. The version bump is offered at
  integration, not made here.

- [x] **Step 1 (SKILL.md):** replace the whole of `plugins/cogniva-dev/skills/module-deps/SKILL.md` with exactly this content:

````markdown
--
name: module-deps
description: Legacy Module-layout tool - regenerate the Module dependency graph (docs/architecture/module-dependencies.html + .md) from the .csproj ProjectReference graph of a repo laid out as src/Modules/<Name>/, or check it for cross-Module cycles with -Check. Use when the user asks for the module dependency graph/map, deployment closure, "what modules does X need", a Module cycle check, or after adding/removing/re-referencing a Module project in such a repo. Pure script run - no build, no analysis required.
---

# module-deps

**This is a legacy Module-layout tool.** It understands one layout: projects
under `src/Modules/<Name>/` named `<Name>.<Kind>` (Contracts, Domain,
Application, Infrastructure, Client, UI), the layout `add-module` scaffolds.
Qualified projects such as `<Name>.Infrastructure.<System>` or
`<Name>.UI.<Part>` roll up to their kind. Projects under `src/Hosts/` are
hosts; every other project (shared libraries, shells, kernels) is outside the
graph. It reads no architecture profile and ships no project-specific data. A
repo that does not use this layout gets nothing useful from it.

The script is the whole engine. It parses the projects, rolls them up to
Modules, computes the transitive (deployment) closure, and detects cycles.
There is no build or restore, and no codebase reasoning is needed.

`<plugin>` is this plugin's root (the parent of this `skills/` dir).

## Regenerate the graph

```
powershell -NoProfile -File "<plugin>/skills/module-deps/module-deps.ps1"
```

Run it from anywhere inside the repo: `-RepoRoot` defaults to the git top
level of the current directory (pass it explicitly to graph another repo). It
writes two views:

- `docs/architecture/module-dependencies.html` (primary): self-contained, with
  two Mermaid diagrams (dependency graph and tiered-by-depth) plus styled
  tables. Open it in a browser.
- `docs/architecture/module-dependencies.md`: the same content as Markdown.

Both are UTF-8. By default the script **auto-commits** the two generated files
(and only those two) when they change, so a regen never leaves the working tree
dirty. A dirty primary checkout blocks unrelated feature integrations. The
commit stages ONLY the two graph files (never `add -A`), and is a no-op when
the graph is unchanged.

Optional parameters:
- `-RepoRoot <path>`: the repo to analyze (default: the git top level of the
  current directory).
- `-OutFile <path>` / `-HtmlFile <path>`: override the two output paths.
- `-NoCommit`: leave the regenerated files uncommitted.
- `-Open`: launch the HTML in a browser.

## Check for cycles (`-Check`)

```
powershell -NoProfile -File "<plugin>/skills/module-deps/module-deps.ps1" -Check
```

`-Check` computes the graph and lists every cross-Module cycle that
`docs/architecture/allowed-cycles.txt` does not allow, with the project kinds
that introduce each edge inside it. A cycle is a set of Modules that can all
reach each other (a strongly connected component), reported once as a whole:
`A -> B -> C -> A` is the one cycle `A <-> B <-> C`, not three pairs. It exits `0` when there are none and `1` when there
are. It writes nothing, commits nothing, and never reads the glossary. Any
caller can use it: a git hook, CI, a green gate, or you.

`docs/architecture/allowed-cycles.txt` is optional and repo-owned. It holds one
cycle per line, its Modules joined by `<->` in any order: `A <-> B`, or
`A <-> B <-> C`. A line allows exactly that set of Modules, so a cycle that
grows or shrinks needs a new line, and pairs never add up to approve a larger
cycle. `#` starts a comment; a trailing `# reason` is encouraged. Blank lines
are ignored. A line with fewer than two Modules, an empty name, or a repeated
Module is reported and allows nothing. Adding a line is a deliberate, reviewed
act.

## Module descriptions

The "Modules" table shows the first paragraph under each `## <Name> (Module)`
heading in the repo's `docs/glossary/README.md` (the entries `add-module`
writes). They are display-only. A missing glossary or a missing entry shows a
placeholder and never changes the graph or `-Check`. To describe a Module, add
or fix its glossary entry; never edit the generated files.

## Edit-time feedback hook (opt-in, Claude Code)

The plugin registers a `PostToolUse` hook that runs `-Check` after Claude edits
a `.csproj`. When the edit leaves a disallowed cycle, the hook hands Claude the
report and asks it to correct the reference. It cannot prevent the edit: a
`PostToolUse` hook runs after the file has already changed, so the edit stays
on disk until Claude fixes it. It acts only in repos whose tracked
`.claude/cogniva-dev/policy.json` contains `"moduleDepsCheck": true`.
Everywhere else it does nothing, and it fails open on any error.

The hook is feedback, not enforcement. Where cycles must never land, run
`-Check` in a completion gate (the repo's green gate, CI, or a git hook); that
is also the route under other hosts.

## What to report back

1. After a regeneration:
   - Confirm both output paths were written (the script prints two `Wrote ...`
     lines).
   - ALWAYS echo the full `file:///...` HTML URL the script prints (the line
     under "Open in a browser (copy this URL):") on its own line, so the user
     can copy it straight into a browser.
   - Pass `-Open` if they want it launched automatically.
2. Echo the `Modules:` line and any `Cycles:` line. Unless `-NoCommit` was
   passed, relay whether it committed the regenerated graph or reported it
   unchanged.
3. After `-Check`: relay `OK`, or the listed cycles and the kinds that
   introduce them.
4. If a cycle is reported, mention it should be reviewed: mutually dependent
   Modules ship as one deployment unit. Fix a reference, or allow the whole
   cycle deliberately.

Do NOT hand-edit the generated files or recompute the graph yourself; always
run the script. If the script errors, report the error verbatim, and do not
substitute a manually written graph. The HTML diagram needs internet (Mermaid
loads from a CDN); the tables render offline regardless.
````

- [x] **Step 2 (policy key docs):** in `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md`, insert this section immediately before the line `## Green gate config — `.claude/cogniva-dev/green-gate.json`` (keep one blank line before and after it):

```markdown
## Module cycle check — `moduleDepsCheck` in `policy.json`

Optional, and off by default. For repos on the legacy Module layout
(`src/Modules/<Name>/`), the same `policy.json` can turn on the plugin's
edit-time cycle check:

```json
{ "moduleDepsCheck": true }
```

When it is `true`, every `.csproj` edit Claude makes runs
`module-deps.ps1 -Check`. If the edit leaves a cross-Module cycle not listed
in `docs/architecture/allowed-cycles.txt`, Claude gets the report and is asked
to correct it. The hook runs after the edit, so it cannot prevent one; for hard
enforcement, run `-Check` in a completion gate such as `green-gate.json` below.
Absent, unreadable, or anything but `true` means no check. The hook fails open
on any error. `-Check` itself can always be run directly (see the `module-deps`
skill).
```

- [x] **Step 3 (green gate):** in `.claude/cogniva-dev/green-gate.json`, insert these two entries immediately after the `"label": "architecture-profile"` entry (keep the array valid JSON):

```json
    { "run": "powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/module-deps/module-deps.tests.ps1", "label": "module-deps", "note": "Pins the legacy Module-layout tool: -Check, allowed cycles, cycle-safe deterministic output, display-only glossary descriptions, no project data." },
    { "run": "powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1", "label": "module-deps-hook", "note": "Pins the opt-in PostToolUse cycle hook: returns block feedback only for a confirmed cycle in a repo with moduleDepsCheck true." },
```

Then verify that it parses: `powershell -NoProfile -Command "(Get-Content -Raw .claude/cogniva-dev/green-gate.json | ConvertFrom-Json).commands.label -join ','"` → the list includes `module-deps,module-deps-hook`.

- [x] **Step 4 (README row):** in `README.md`, replace the line
`| `plugins/cogniva-dev/skills/module-deps` | Regenerate the Module dependency graph from .csproj references |`
with
`| `plugins/cogniva-dev/skills/module-deps` | Legacy Module layout: regenerate the Module dependency graph from .csproj references, or check it for cycles (`-Check`) |`

- [x] **Step 5 (run until green):** run both suites and the plugin validation:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/module-deps/module-deps.tests.ps1` → `All module-deps assertions passed.`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1` → `All guard-module-cycles assertions passed.`
  - `claude plugin validate .` → passes.

- [x] **Step 6 (write ADR):** scan `docs/adr/` for the next free number `NNNN`, then write `docs/adr/NNNN-module-deps-is-a-data-free-legacy-module-layout-tool.md` with exactly this content (substitute only `NNNN` in the filename):

```markdown
 module-deps is a data-free legacy Module-layout tool with an opt-in cycle check

**Provenance:** Suggested by human

`module-deps` graphs only the legacy `src/Modules/<Name>/` layout that
`add-module` scaffolds, and ships no repository-specific data. Module
descriptions are display-only and come from the repo glossary's
`## <Name> (Module)` entries; allowed cycles come from the repo's
`docs/architecture/allowed-cycles.txt`. `-Check` is always callable on its own.
Edit-time feedback is a Claude Code `PostToolUse` adapter that acts only where
a repo opts in with `"moduleDepsCheck": true` in `.claude/cogniva-dev/policy.json`;
it runs after the edit, so it asks for a correction rather than preventing one.
Hard enforcement runs `-Check` in a completion gate.
```

  Then run `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/check-adrs.ps1 -Workspace . -Since HEAD` → no errors.

- [x] **Step 7 (commit):** `git add plugins/cogniva-dev/skills/module-deps/SKILL.md plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md .claude/cogniva-dev/green-gate.json README.md docs/adr/` then `git commit -m "docs(module-deps): legacy Module-layout tool, -Check, opt-in hook; gate the new suites"`
