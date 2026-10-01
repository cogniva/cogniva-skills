# ArchitectureProfiles — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/ArchitectureProfiles
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** Stage 1 of architecture profiles: a deterministic, explainable way to
resolve which architecture profile applies to a target path, load its standards
progressively, and use that in planning, without changing how any existing repo
behaves.

**Architecture:** Profiles are folders (`profile.yml` plus Markdown standards
under `standards/`) with single inheritance, where a child's standard at the same
relative path replaces the parent's. The plugin ships a library
(`plugins/cogniva-dev/profiles/`: `cogniva-base`, `dotnet`); a repo adopts a
profile by copying it into `.cogniva/profiles/` (`adopt-architecture-profile.ps1`),
and tools read only that copy. A path's profile comes from an explicit
`-Profile`, else the nearest `.cogniva-profile.yml` marker, else the repo-root
marker; undeclared paths get at most a suggestion, never a profile.
`resolve-architecture-profile.ps1` (PowerShell 7, core in `profile-lib.ps1`)
reports the winner, the shadowed markers, the chain, and a standards index built
from each standard's frontmatter `description`. Each target resolves
independently and profiles load on demand, so a broken marker or profile marks
only its own targets `ERROR` (exit 1 with a full report; exit 2 is reserved for
usage errors). Every profile reference is validated as a lowercase id, repo
containment uses the platform's path-casing rules, and adoption stages and
verifies copies before swapping them in, rolling back on any failure. `plan-feature` calls it during
design; `resolve-applicable-rules.ps1` (still Windows PowerShell 5.1) runs it as a
separate `pwsh` process and reports the profile per target. Execution, quick-fix,
repo-init, add-module, module-deps and the repo templates are deliberately
untouched (Stage 2 items are in `docs/plans/FeatureLifecycle/BACKLOG.md`).

**Read these first:**
- `plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1` — the existing per-target walker this feature reports into
- `plugins/cogniva-dev/skills/plan-feature/SKILL.md` and `PLAN-FORMAT.md`
- `plugins/cogniva-dev/templates/repo/CLAUDE.md` — source of the `dotnet` standards' text
- `docs/adr/0003-wrapper-scripts-for-subagent-git-and-json.md` — commit via `git-commit.ps1`
- `docs/adr/0014-lazy-loaded-skill-companion-files.md` — the progressive-disclosure pattern standards follow

## File structure (locked)

```
plugins/cogniva-dev/scripts/profile-lib.ps1                      # NEW (pwsh 7) — YAML subset, profile loading, inheritance, marker walk, suggestions
plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1     # NEW (pwsh 7) — read-only resolver CLI (Text/Json), exit 0 / 1 / 2
plugins/cogniva-dev/scripts/adopt-architecture-profile.ps1       # NEW (pwsh 7) — copies a library profile + ancestors into <repo>/.cogniva/profiles
plugins/cogniva-dev/profiles/cogniva-base/profile.yml            # NEW — root library profile
plugins/cogniva-dev/profiles/cogniva-base/standards/architecture/ownership-and-placement.md  # NEW
plugins/cogniva-dev/profiles/cogniva-base/standards/architecture/composition-roots.md        # NEW
plugins/cogniva-dev/profiles/cogniva-base/standards/architecture/dependency-direction.md     # NEW
plugins/cogniva-dev/profiles/dotnet/profile.yml                  # NEW — inherits cogniva-base
plugins/cogniva-dev/profiles/dotnet/standards/dotnet/module-layout.md        # NEW — extracted from templates/repo/CLAUDE.md
plugins/cogniva-dev/profiles/dotnet/standards/dotnet/module-dependencies.md  # NEW — extracted from templates/repo/CLAUDE.md
plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1  # NEW (pwsh 7) — resolution, inheritance, suggestions, adoption, library lint, drift (Task 2 adds the applicable-rules case-sensitive containment check)
.claude/cogniva-dev/green-gate.json                              # MOD — registers the new test suite
plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1         # MOD — reports ArchitectureProfile per target via a pwsh subprocess
plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1  # MOD — profile, backwards-compatibility, and Windows case-variant containment assertions
plugins/cogniva-dev/skills/applicable-rules/SKILL.md             # MOD — documents ArchitectureProfile
plugins/cogniva-dev/skills/plan-feature/SKILL.md                 # MOD — architecture-profile step + plan header rule
plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md           # MOD — optional **Architecture profile:** header line; policy-neutral commit wording in the header
plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1  # MOD — pins the plan-feature / applicable-rules contract
plugins/cogniva-dev/docs/architecture-profiles.md                # NEW — how to adopt, declare, and write profiles
docs/strategy.md                                                 # MOD — Purpose paragraph fixed; Architecture profiles section
docs/glossary/README.md                                          # MOD — Architecture profile, Profile marker
CLAUDE.md                                                        # MOD — Layout line mentions the profile library
plugins/cogniva-dev/.claude-plugin/plugin.json                   # MOD — version 0.8.1 -> 0.9.0 (minor: new capability)
plugins/cogniva-dev/.codex-plugin/plugin.json                    # MOD — version 0.8.1 -> 0.9.0
.claude-plugin/marketplace.json                                  # MOD — cogniva-dev entry version 0.8.1 -> 0.9.0
docs/adr/NNNN-*.md                                               # 5 ADRs, written by Task 1 (next free numbers at execution time)
```

## Candidate ADRs

### ADR-C1: Architecture profiles are declared per path, never inferred into place
**Provenance:** Suggested by human
A path's architecture profile comes from, in order: an explicit choice for the
current run, the nearest `.cogniva-profile.yml` marker above it, then the
repo-root marker. Tools may suggest a profile when none is declared but never
apply or save one on their own, and targets that resolve to different profiles
are reported rather than merged, because architectural intent is a human decision.
**Write with:** Task 1

### ADR-C2: A standard's description lives in its own frontmatter; the standards index is derived
**Provenance:** Suggested by agent
Each standard carries a one-line `description:` in its frontmatter, and the
resolver builds the index agents read from those lines at resolve time. There is
no separately maintained index file (as in Agent OS's `index.yml`) to fall out of
step with the standards it describes.
**Write with:** Task 1

### ADR-C3: Profile files use a strict YAML subset read by our own parser
**Provenance:** Suggested by agent
`profile.yml`, `.cogniva-profile.yml` markers and standard frontmatter allow only
flat `key: value` lines and simple `- item` lists; anything else is an error
naming the file and line. We chose not to add a YAML library here, consistent
with taking no dependencies so far; that is a judgement for this case, not a
rule, and a future need that justifies a dependency should be weighed on its merits.
**Write with:** Task 1

### ADR-C4: New scripts target PowerShell 7
**Provenance:** Suggested by human
New scripts in this repo, in the plugin's `scripts/` and the repo's own, assume
PowerShell 7 (`pwsh`); existing Windows PowerShell 5.1 scripts stay as they are
until deliberately migrated. Where 5.1 code needs a new script it runs it as a
separate `pwsh` process rather than loading it, and degrades visibly when `pwsh`
is absent.
**Write with:** Task 1

### ADR-C5: Architecture profiles are copied into the repo that uses them
**Provenance:** Suggested by human
The plugin's `profiles/` folder is a library: a repo adopts a profile, and every
profile it inherits from, by copying it into `.cogniva/profiles/` with
`adopt-architecture-profile.ps1`, and every tool reads only that copy. A repo's
standards therefore change only through a deliberate re-adoption that shows up as
an ordinary diff, never silently on a plugin update.
**Write with:** Task 1

## Task 1: Profile core, library, adopt script, and tests

**Files:**
- Create: `plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1`
- Create: `plugins/cogniva-dev/scripts/profile-lib.ps1`
- Create: `plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1`
- Create: `plugins/cogniva-dev/scripts/adopt-architecture-profile.ps1`
- Create: the seven files under `plugins/cogniva-dev/profiles/` listed in Step 6
- Modify: `.claude/cogniva-dev/green-gate.json`
- Create: five ADRs under `docs/adr/`

All three scripts and the test file are PowerShell 7 (`#Requires -Version 7.0`).
Write every file below VERBATIM. Library `.yml`/`.md` files use LF line endings
(`.gitattributes` normalises them); `.ps1` files are normalised to CRLF by git.

- [x] **Step 1 (failing test):** create `plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1`:

```powershell
#Requires -Version 7.0
# Dependency-free tests for architecture-profile resolution, inheritance,
# suggestions, adoption, and the shipped profile library.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$resolver = Join-Path $plugin 'scripts\resolve-architecture-profile.ps1'
$adopter = Join-Path $plugin 'scripts\adopt-architecture-profile.ps1'
$shippedLibrary = Join-Path $plugin 'profiles'
$template = Join-Path $plugin 'templates\repo\CLAUDE.md'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-architecture-profile-" + [guid]::NewGuid().ToString('N'))
$failures = @()

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
# Exit 0 and 1 both carry a JSON report (1 = at least one target is ERROR); exit 2 carries none.
function Resolve-Json([string]$Repo, [string[]]$Extra) {
    $result = Invoke-Script $resolver (@('-Repo', $Repo, '-Format', 'Json', '-LibraryRoot', $script:library) + $Extra)
    $json = if ($result.Code -in 0, 1) { $result.Out | ConvertFrom-Json } else { $null }
    [pscustomobject]@{ Code = $result.Code; Json = $json; All = $result.All; Raw = $result.Out }
}
function Test-TargetError($Result, [string]$Pattern) {
    return ($Result.Code -eq 1 -and $Result.Json.Targets[0].Status -eq 'ERROR' -and $Result.Json.Targets[0].Error -match $Pattern -and $Result.Json.Aggregate.Status -eq 'ERROR')
}
function New-Repo([string]$Name) {
    $repo = Join-Path $root $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    & git -C $repo init -q
    return $repo
}
function Add-Profile([string]$Repo, [string]$Id, [string]$Yaml, [hashtable]$Standards) {
    Write-Fixture $Repo ".cogniva/profiles/$Id/profile.yml" $Yaml
    foreach ($key in $Standards.Keys) { Write-Fixture $Repo ".cogniva/profiles/$Id/standards/$key" $Standards[$key] }
}
function Std([string]$Description) { return "---`ndescription: $Description`n---`n`n# Body`n" }

try {
    # Fixture library: used for suggestions, hints, and adoption.
    $script:library = Join-Path $root 'library'
    Write-Fixture $library 'base/profile.yml' "description: Base fixture.`n"
    Write-Fixture $library 'base/standards/architecture/owner.md' (Std 'Base owner rule.')
    Write-Fixture $library 'python/profile.yml' "description: Python fixture.`ninherits: base`ndetect:`n  - `"pyproject.toml`"`n"
    Write-Fixture $library 'python/standards/python/layout.md' (Std 'Python layout rule.')
    Write-Fixture $library 'dotnet/profile.yml' "description: Dotnet fixture.`ninherits: base`ndetect:`n  - `"*.slnx`"`n"
    # 'none' is reserved for markers, so a library folder by that name must never be suggested.
    Write-Fixture $library 'none/profile.yml' "description: Reserved name.`ndetect:`n  - `"*.slnx`"`n"

    # --- precedence ----------------------------------------------------------
    $repo = New-Repo 'precedence'
    Add-Profile $repo 'base' "description: Base.`n" @{ 'architecture/owner.md' = (Std 'Base owner.'); 'architecture/shared.md' = (Std 'Base shared.') }
    Add-Profile $repo 'python' "description: Python.`ninherits: base`n" @{ 'Architecture/Owner.md' = (Std 'Python owner.'); 'python/layout.md' = (Std 'Python layout.') }
    Add-Profile $repo 'dotnet' "description: Dotnet.`ninherits: base`n" @{ 'dotnet/modules.md' = (Std 'Dotnet modules.') }
    Write-Fixture $repo '.cogniva-profile.yml' "profile: dotnet`n"
    Write-Fixture $repo 'tools/.cogniva-profile.yml' "# Python tooling`nprofile: python`n"
    Write-Fixture $repo 'docs/.cogniva-profile.yml' "profile: none`n"
    Write-Fixture $repo 'src/Orders/Order.cs' "class Order {}`n"
    Write-Fixture $repo 'tools/ingest/run.py' "print(1)`n"
    $before = @(& git -C $repo status --porcelain)

    $r = Resolve-Json $repo @('-Target', 'src/Orders/Order.cs')
    $t = $r.Json.Targets[0]
    Check 'root marker resolves as repo-default' ($r.Code -eq 0 -and $t.Status -eq 'RESOLVED' -and $t.Profile -eq 'dotnet' -and $t.Winner.Kind -eq 'repo-default' -and $t.Winner.Source -eq '.cogniva-profile.yml')

    $r = Resolve-Json $repo @('-Target', 'tools/ingest/run.py,src/Orders')
    $py = $r.Json.Targets[0]
    Check 'nearest marker wins as path-override' ($py.Profile -eq 'python' -and $py.Winner.Kind -eq 'path-override' -and $py.Winner.Source -eq 'tools/.cogniva-profile.yml')
    Check 'broader marker is recorded as shadowed' (@($py.Considered | Where-Object { $_.Outcome -eq 'shadowed' -and $_.Source -eq '.cogniva-profile.yml' -and $_.Profile -eq 'dotnet' }).Count -eq 1)
    Check 'sibling target falls back to the repo default' ($r.Json.Targets[1].Profile -eq 'dotnet')
    Check 'targets on different profiles aggregate as MIXED' ($r.Code -eq 0 -and $r.Json.Aggregate.Status -eq 'MIXED' -and @($r.Json.Aggregate.Groups.python) -contains 'tools/ingest/run.py' -and @($r.Json.Aggregate.Groups.dotnet) -contains 'src/Orders')

    $r = Resolve-Json $repo @('-Target', 'tools/new-tool/not-yet-created.py')
    Check 'a target that does not exist yet resolves through its nearest existing parent' ($r.Json.Targets[0].Profile -eq 'python')

    $r = Resolve-Json $repo @('-Target', 'tools/ingest/run.py', '-Profile', 'dotnet')
    $t = $r.Json.Targets[0]
    Check 'explicit -Profile beats every marker' ($t.Profile -eq 'dotnet' -and $t.Winner.Kind -eq 'explicit')
    Check 'explicit choice records the markers it overrode' (@($t.Considered | Where-Object Outcome -eq 'overridden-by-explicit').Count -eq 2)

    $r = Resolve-Json $repo @('-Target', 'docs/guide.md')
    Check "'profile: none' clears the profile for its subtree" ($r.Json.Targets[0].Status -eq 'NONE' -and $null -eq $r.Json.Targets[0].Profile)

    $r = Resolve-Json $repo @('-Target', 'src/Orders,src/Orders/Order.cs')
    Check 'targets on one profile aggregate as UNIFORM' ($r.Json.Aggregate.Status -eq 'UNIFORM')

    # --- inheritance and the standards index ---------------------------------
    $r = Resolve-Json $repo @('-Target', 'tools')
    $p = $r.Json.Profiles.python
    $owner = @($p.Standards | Where-Object { $_.Id -ieq 'architecture/owner.md' })
    Check 'chain lists child first' (($p.Chain -join '>') -eq 'python>base')
    Check 'child same-path standard overrides the parent (case-insensitive)' ($owner.Count -eq 1 -and $owner[0].From -eq 'python' -and $owner[0].Description -eq 'Python owner.' -and @($owner[0].Overrides) -contains 'base')
    Check 'parent-only standards are inherited' (@($p.Standards | Where-Object { $_.Id -eq 'architecture/shared.md' -and $_.From -eq 'base' }).Count -eq 1)
    Check 'index carries descriptions, not bodies' (-not ($r.Raw -match '# Body'))
    Check 'standards are ordered by id' ((@($p.Standards.Id) -join '|') -eq (@($p.Standards.Id | Sort-Object { $_.ToLowerInvariant() }) -join '|'))

    $again = Resolve-Json $repo @('-Target', 'tools')
    Check 'resolution is deterministic' ($again.Raw -eq $r.Raw)
    $after = @(& git -C $repo status --porcelain)
    Check 'resolver leaves the repository unchanged' (($before -join "`n") -eq ($after -join "`n"))

    $text = Invoke-Script $resolver @('-Repo', $repo, '-Target', 'tools/ingest/run.py', '-LibraryRoot', $library)
    Check 'text output explains the winner and the shadowed marker' ($text.Out -match 'PROFILE: python \(path-override: tools/\.cogniva-profile\.yml\)' -and $text.Out -match 'SHADOWED: \.cogniva-profile\.yml -> dotnet')

    # --- undeclared repos and suggestions ------------------------------------
    $bare = New-Repo 'undeclared'
    Write-Fixture $bare 'App.slnx' "<Solution />`n"
    Write-Fixture $bare 'tools/py/pyproject.toml' "[project]`n"
    $r = Resolve-Json $bare @('-Target', 'src/Anything.cs')
    $t = $r.Json.Targets[0]
    Check 'no marker leaves the target UNDECLARED with no profile' ($r.Code -eq 0 -and $t.Status -eq 'UNDECLARED' -and $null -eq $t.Profile -and $r.Json.Aggregate.Status -eq 'UNDECLARED')
    Check 'undeclared targets load no standards' (@($r.Json.Profiles.PSObject.Properties).Count -eq 0)
    Check 'suggestion comes from library detect hints' ($t.Suggestion.Status -eq 'SUGGESTED' -and @($t.Suggestion.Profiles) -contains 'dotnet' -and @($t.Suggestion.Evidence) -contains 'App.slnx')
    Check "a library folder named 'none' is never suggested" (@($t.Suggestion.Profiles) -notcontains 'none' -and ($r.Json.Warnings -join "`n") -match "plugin-library/none: 'none' is reserved")
    $r = Resolve-Json $bare @('-Target', 'tools/py/main.py')
    Check 'nearest directory with a hit decides the suggestion' ((@($r.Json.Targets[0].Suggestion.Profiles) -join ',') -eq 'python')
    Write-Fixture $bare 'tools/py/Tool.slnx' "<Solution />`n"
    $r = Resolve-Json $bare @('-Target', 'tools/py/main.py')
    Check 'two profiles detected in one directory is AMBIGUOUS, not a pick' ($r.Json.Targets[0].Suggestion.Status -eq 'AMBIGUOUS' -and @($r.Json.Targets[0].Suggestion.Profiles).Count -eq 2)
    Check 'suggestions never write a marker' (-not (Test-Path (Join-Path $bare '.cogniva-profile.yml')))

    # --- per-target errors (exit 1, the report still lists every target) ------
    $bad = New-Repo 'errors'
    Write-Fixture $bad '.cogniva-profile.yml' "profile: python`n"
    $r = Resolve-Json $bad @('-Target', 'x')
    Check 'marker naming an un-adopted profile is a target ERROR with an adopt hint' ((Test-TargetError $r "\.cogniva-profile\.yml: profile 'python' is not in \.cogniva/profiles") -and $r.Json.Targets[0].Error -match 'adopt-architecture-profile\.ps1 -Profile python')

    Add-Profile $bad 'python' "description: Python.`ninherits: base`n" @{}
    $r = Resolve-Json $bad @('-Target', 'x')
    Check 'missing parent is an ERROR naming the child profile.yml' (Test-TargetError $r "\.cogniva/profiles/python/profile\.yml: profile 'base'")

    Add-Profile $bad 'base' "description: Base.`ninherits: python`n" @{}
    $r = Resolve-Json $bad @('-Target', 'x')
    Check 'inheritance cycle is an ERROR' (Test-TargetError $r 'inheritance cycle: python -> base -> python')

    Add-Profile $bad 'base' "description: Base.`n" @{}
    Write-Fixture $bad '.cogniva/profiles/base/standards/a/Rule.md' (Std 'One.')
    Write-Fixture $bad '.cogniva/profiles/base/standards/a/rule.md' (Std 'Two.')
    $r = Resolve-Json $bad @('-Target', 'x')
    if ((Get-ChildItem -LiteralPath (Join-Path $bad '.cogniva/profiles/base/standards/a') -File).Count -eq 2) {
        Check 'case-variant standard paths inside one profile are an ERROR' (Test-TargetError $r 'collides with')
    }
    else { Write-Host '  SKIP  case-variant collision (case-insensitive file system merged the fixtures)' }
    Remove-Item -LiteralPath (Join-Path $bad '.cogniva/profiles/base/standards') -Recurse -Force

    $yamlCases = [ordered]@{
        'tab indentation'  = "description: Base.`ndetect:`n`t- `"x`"`n"
        'flow list'        = "description: Base.`ndetect: [a, b]`n"
        'nested map'       = "description: Base.`nextra:`n  key: value`n"
        'duplicate key'    = "description: Base.`ndescription: Again.`n"
        'unknown key'      = "description: Base.`nchecks: build`n"
        'missing required' = "inherits: python`n"
        'unquoted alias'   = "description: Base.`ndetect:`n  - *.slnx`n"
    }
    foreach ($case in $yamlCases.Keys) {
        Write-Fixture $bad '.cogniva/profiles/base/profile.yml' $yamlCases[$case]
        $r = Resolve-Json $bad @('-Target', 'x')
        Check "strict YAML subset rejects: $case" (Test-TargetError $r '\.cogniva/profiles/base/profile\.yml')
    }
    Write-Fixture $bad '.cogniva/profiles/base/profile.yml' "description: 'Quoted # not a comment' # trailing comment`n"
    Write-Fixture $bad '.cogniva/profiles/base/standards/extra-key.md' "---`ndescription: Has an extra key.`nowner: someone`n---`n"
    Write-Fixture $bad '.cogniva-profile.yml' "profile: base`n"
    $r = Resolve-Json $bad @('-Target', 'x')
    Check 'quoted values keep # and trailing comments are dropped' ($r.Code -eq 0 -and $r.Json.Profiles.base.Description -eq 'Quoted # not a comment')
    Check 'extra frontmatter keys are ignored with a warning' (@($r.Json.Profiles.base.Standards | Where-Object Id -eq 'extra-key.md').Count -eq 1 -and ($r.Json.Warnings -join "`n") -match "extra-key\.md: frontmatter key 'owner' is ignored")
    Write-Fixture $bad '.cogniva/profiles/base/standards/no-description.md' "# No frontmatter`n"
    $r = Resolve-Json $bad @('-Target', 'x')
    Check 'a standard without a description is an ERROR' (Test-TargetError $r "no-description\.md: missing frontmatter 'description'")
    Remove-Item -LiteralPath (Join-Path $bad '.cogniva/profiles/base/standards/no-description.md')

    $r = Resolve-Json $bad @('-Target', 'x', '-Profile', 'dotnet')
    Check 'explicit -Profile must be adopted too' (Test-TargetError $r "profile 'dotnet' is not in")
    Write-Fixture $bad '.cogniva-profile.yml' "profile: base`nextra: 1`n"
    $r = Resolve-Json $bad @('-Target', 'x')
    Check 'marker rejects unknown keys' (Test-TargetError $r "\.cogniva-profile\.yml: unknown key 'extra'")
    Write-Fixture $bad '.cogniva-profile.yml' "profile: base`n"

    # --- each target resolves independently -----------------------------------
    $split = New-Repo 'independent'
    Add-Profile $split 'good' "description: Good.`n" @{ 'rules/one.md' = (Std 'One.') }
    Add-Profile $split 'broken' "description: Broken.`nchecks: nope`n" @{}
    Write-Fixture $split 'ok/.cogniva-profile.yml' "profile: good`n"
    Write-Fixture $split 'missing/.cogniva-profile.yml' "profile: absent`n"
    Write-Fixture $split 'uses-broken/.cogniva-profile.yml' "profile: broken`n"
    $r = Resolve-Json $split @('-Target', 'ok/a.py,missing/b.py,uses-broken/c.py')
    $states = @($r.Json.Targets | ForEach-Object Status) -join ','
    Check 'one broken target does not poison the others' ($r.Code -eq 1 -and $states -eq 'RESOLVED,ERROR,ERROR' -and $r.Json.Targets[0].Profile -eq 'good' -and @($r.Json.Profiles.good.Standards).Count -eq 1)
    Check 'each ERROR carries its own reason' ($r.Json.Targets[1].Error -match "missing/\.cogniva-profile\.yml: profile 'absent'" -and $r.Json.Targets[2].Error -match "\.cogniva/profiles/broken/profile\.yml: unknown key 'checks'")
    Check 'errors are grouped in the aggregate' ($r.Json.Aggregate.Status -eq 'ERROR' -and @($r.Json.Aggregate.Groups.'(error)').Count -eq 2 -and @($r.Json.Aggregate.Groups.good) -contains 'ok/a.py')
    $r = Resolve-Json $split @('-Target', 'ok/a.py')
    Check 'a broken profile nobody uses does not affect resolution' ($r.Code -eq 0 -and $r.Json.Targets[0].Status -eq 'RESOLVED')

    # --- profile ids are validated wherever they are read ----------------------
    $ids = New-Repo 'ids'
    Add-Profile $ids 'base' "description: Base.`n" @{}
    Write-Fixture $ids 'upper/.cogniva-profile.yml' "profile: Base`n"
    Write-Fixture $ids 'bad-parent/.cogniva-profile.yml' "profile: child`n"
    Add-Profile $ids 'child' "description: Child.`ninherits: Base`n" @{}
    $r = Resolve-Json $ids @('-Target', 'upper/x,bad-parent/y')
    Check 'a mixed-case marker value is an ERROR' ($r.Json.Targets[0].Status -eq 'ERROR' -and $r.Json.Targets[0].Error -match "upper/\.cogniva-profile\.yml: 'Base' is not a valid profile id")
    Check 'a mixed-case inherits value is an ERROR' ($r.Json.Targets[1].Status -eq 'ERROR' -and $r.Json.Targets[1].Error -match "'Base' is not a valid profile id")
    $r = Resolve-Json $ids @('-Target', 'upper/x', '-Profile', 'base')
    $t = $r.Json.Targets[0]
    Check 'explicit -Profile also overrides a malformed marker' ($r.Code -eq 0 -and $t.Status -eq 'RESOLVED' -and $t.Profile -eq 'base' -and @($t.Considered | Where-Object { $_.Source -eq 'upper/.cogniva-profile.yml' -and $_.Outcome -eq 'overridden-by-explicit' }).Count -eq 1)
    Check 'the overridden malformed marker is reported as a warning' (($r.Json.Warnings -join "`n") -match "upper/\.cogniva-profile\.yml: 'Base' is not a valid profile id .*overridden by -Profile")
    $r = Resolve-Json $ids @('-Target', 'x', '-Profile', 'Base')
    Check 'a mixed-case -Profile is a usage error' ($r.Code -eq 2 -and $r.All -match "-Profile: 'Base' is not a valid profile id")
    $r = Resolve-Json $ids @('-Target', 'x', '-Profile', 'none')
    Check "'none' is only valid in a marker" ($r.Code -eq 2 -and $r.All -match "'none' is reserved")
    New-Item -ItemType Directory -Path (Join-Path $ids '.cogniva/profiles/Mixed') -Force | Out-Null
    Write-Fixture $ids '.cogniva/profiles/Mixed/profile.yml' "description: Mixed.`n"
    Write-Fixture $ids 'mixed/.cogniva-profile.yml' "profile: mixed`n"
    $r = Resolve-Json $ids @('-Target', 'mixed/x')
    Check 'a profile folder whose name is not lowercase is never used' ($r.Json.Targets[0].Status -eq 'ERROR' -and $r.Json.Targets[0].Error -match 'folder names must be lowercase|is not in')

    # --- repo containment -------------------------------------------------------
    $r = Resolve-Json $bad @('-Target', '..\outside')
    Check 'target outside the repo is a usage error' ($r.Code -eq 2 -and $r.All -match 'outside repo')
    if ($IsLinux) {
        $cased = Join-Path $root 'Cased'
        $sibling = Join-Path $root 'cased'
        New-Item -ItemType Directory -Path $cased, $sibling -Force | Out-Null
        $r = Invoke-Script $resolver @('-Repo', $cased, '-Target', (Join-Path $sibling 'x'), '-LibraryRoot', $library)
        Check 'a sibling differing only by case is outside the repo on a case-sensitive system' ($r.Code -eq 2 -and $r.All -match 'outside repo')
    }
    else { Write-Host '  SKIP  case-sensitive containment (runs on Linux only)' }

    # --- adoption --------------------------------------------------------------
    $adopt = New-Repo 'adopt'
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'adopt copies the profile and its whole chain' ($a.Code -eq 0 -and (Test-Path (Join-Path $adopt '.cogniva/profiles/python/standards/python/layout.md')) -and (Test-Path (Join-Path $adopt '.cogniva/profiles/base/profile.yml')))
    Check 'adopt never writes a marker' (-not (Test-Path (Join-Path $adopt '.cogniva-profile.yml')))
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 're-adopting an unchanged copy is UP-TO-DATE' ($a.Code -eq 0 -and $a.Out -match 'UP-TO-DATE: python' -and $a.Out -match 'UP-TO-DATE: base')
    $layout = Join-Path $adopt '.cogniva/profiles/python/standards/python/layout.md'
    [System.IO.File]::WriteAllText($layout, ([System.IO.File]::ReadAllText($layout)).Replace("`n", "`r`n"))
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'line-ending-only differences count as up to date' ($a.Code -eq 0 -and $a.Out -match 'UP-TO-DATE: python')
    Add-Content -LiteralPath $layout -Value 'Local edit.'
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'a locally edited copy blocks re-adoption and names the file' ($a.Code -eq 1 -and $a.Out -match 'DIFFERS: \.cogniva/profiles/python - standards/python/layout\.md' -and (Get-Content -Raw $layout) -match 'Local edit')
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library, '-Force')
    Check '-Force replaces the edited copy' ($a.Code -eq 0 -and $a.Out -match 'REPLACED: python' -and -not ((Get-Content -Raw $layout) -match 'Local edit'))
    Check 'a successful replacement leaves no staging or backup folders' (@(Get-ChildItem -LiteralPath (Join-Path $adopt '.cogniva/profiles') -Directory -Force | Where-Object Name -like '.*').Count -eq 0)
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'missing', '-LibraryRoot', $library)
    Check 'adopting an unknown profile fails' ($a.Code -eq 2 -and $a.All -match "profile 'missing' is not in the plugin library")
    $fresh = New-Repo 'adopt-ids'
    $a = Invoke-Script $adopter @('-Repo', $fresh, '-Profile', 'Python', '-LibraryRoot', $library)
    Check 'adopt rejects a mixed-case profile id and writes nothing' ($a.Code -eq 2 -and $a.All -match "'Python' is not a valid profile id" -and -not (Test-Path (Join-Path $fresh '.cogniva')))

    if ($IsWindows) {
        # A file held open in the second profile's copy makes its swap fail after
        # the first profile was already swapped; both must come back untouched.
        $pythonCopy = Join-Path $adopt '.cogniva/profiles/python/standards/python/layout.md'
        $baseCopy = Join-Path $adopt '.cogniva/profiles/base/standards/architecture/owner.md'
        Add-Content -LiteralPath $pythonCopy -Value 'Python local edit.'
        Add-Content -LiteralPath $baseCopy -Value 'Base local edit.'
        $lock = [System.IO.File]::Open($baseCopy, 'Open', 'Read', 'Read')
        try { $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library, '-Force') }
        finally { $lock.Dispose() }
        Check 'a failed swap exits 2 and says the copies were restored' ($a.Code -eq 2 -and $a.All -match 'copy failed, existing copies restored')
        Check 'a failed swap rolls back the profile already swapped' ((Get-Content -Raw $pythonCopy) -match 'Python local edit')
        Check 'a failed swap leaves the failing profile untouched' ((Get-Content -Raw $baseCopy) -match 'Base local edit')
        Check 'a failed swap leaves no staging or backup folders' (@(Get-ChildItem -LiteralPath (Join-Path $adopt '.cogniva/profiles') -Directory -Force | Where-Object Name -like '.*').Count -eq 0)
    }
    else { Write-Host '  SKIP  swap rollback (needs Windows file locking)' }

    # --- the shipped library ---------------------------------------------------
    $shipped = New-Repo 'shipped'
    foreach ($dir in Get-ChildItem -LiteralPath $shippedLibrary -Directory) {
        $a = Invoke-Script $adopter @('-Repo', $shipped, '-Profile', $dir.Name, '-LibraryRoot', $shippedLibrary)
        Check "shipped profile '$($dir.Name)' adopts cleanly" ($a.Code -eq 0)
        $r = Invoke-Script $resolver @('-Repo', $shipped, '-Target', '.', '-Profile', $dir.Name, '-Format', 'Json', '-LibraryRoot', $shippedLibrary)
        $json = if ($r.Code -eq 0) { $r.Out | ConvertFrom-Json } else { $null }
        Check "shipped profile '$($dir.Name)' resolves with no warnings" ($r.Code -eq 0 -and @($json.Warnings).Count -eq 0 -and @($json.Profiles.($dir.Name).Standards).Count -gt 0)
        Check "every standard in '$($dir.Name)' has a description" ($json -and @($json.Profiles.($dir.Name).Standards | Where-Object { -not $_.Description }).Count -eq 0)
    }
    Check 'the library ships cogniva-base and dotnet, and dotnet inherits cogniva-base' ((Test-Path (Join-Path $shippedLibrary 'cogniva-base/profile.yml')) -and ((Get-Content -Raw (Join-Path $shippedLibrary 'dotnet/profile.yml')) -match '(?m)^inherits: cogniva-base'))

    # --- drift: dotnet standard vs the repo template it was extracted from ---
    $ruleLines = @(Get-Content -LiteralPath $template | Where-Object { $_ -match '^\s+- `<Name>\.' } | ForEach-Object { $_.Trim() })
    $standard = Get-Content -Raw -LiteralPath (Join-Path $shippedLibrary 'dotnet/standards/dotnet/module-dependencies.md')
    Check 'template CLAUDE.md still has per-Module dependency rules to compare' ($ruleLines.Count -ge 6)
    Check 'dotnet module-dependencies standard matches the template rules verbatim' (@($ruleLines | Where-Object { -not $standard.Contains($_) }).Count -eq 0)
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All architecture-profile assertions passed.'
exit 0
```

- [x] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → exits 1 with FAIL lines (the resolver and adopt scripts do not exist yet).

- [x] **Step 3 (implement the core):** create `plugins/cogniva-dev/scripts/profile-lib.ps1`:

```powershell
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
    $actual = (Get-Item -LiteralPath $dir).Name
    if ($actual -cne $Id) { Throw-ProfileError "$($Source.Display)/${actual}: profile folder names must be lowercase ('$Id')" }
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
```

- [x] **Step 4 (implement the resolver):** create `plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1`:

```powershell
#Requires -Version 7.0
# Resolve the architecture profile for one or more target paths, explain why it
# won, and list the index of standards it provides. Read-only.
# Precedence per target: -Profile, then the nearest .cogniva-profile.yml marker,
# then the repo-root marker. Profiles are read only from <repo>/.cogniva/profiles;
# the plugin library (-LibraryRoot) is consulted only for suggestions and hints.
# Each target resolves independently: a broken marker or profile marks only the
# targets that use it as ERROR.
# Exit 0 = every target resolved (including MIXED / UNDECLARED); 1 = the report
# was produced but at least one target is ERROR; 2 = usage error, nothing reported.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string[]]$Target,
    [string]$Profile,
    [string]$LibraryRoot,
    [ValidateSet('Text', 'Json')][string]$Format = 'Text'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'profile-lib.ps1')

function Fail([string]$Message) { [Console]::Error.WriteLine("architecture-profile: $Message"); exit 2 }
function Get-ProfileErrorText($ErrorRecord) { return ($ErrorRecord.Exception.Message -replace '^ProfileError: ', '') }

try {
    if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
    $repoFull = (Get-Item -LiteralPath $Repo).FullName.TrimEnd('\', '/')
    if (-not $LibraryRoot) { $LibraryRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'profiles' }
    if ($Profile) { Assert-ProfileId $Profile '-Profile' }

    $requested = @($Target | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().Trim("'").Trim('"') } | Where-Object { $_ })
    if (-not $requested.Count) { Fail 'no target supplied' }
    $fullTargets = @()
    foreach ($raw in $requested) {
        $full = if ([System.IO.Path]::IsPathRooted($raw)) { [System.IO.Path]::GetFullPath($raw) } else { [System.IO.Path]::GetFullPath((Join-Path $repoFull $raw)) }
        if (-not (Test-PathInside $repoFull $full)) { Fail "target is outside repo: $raw" }
        $fullTargets += $full
    }
}
catch { Fail (Get-ProfileErrorText $_) }

$warnings = [System.Collections.Generic.List[string]]::new()
$repoProfiles = New-ProfileSource (Join-Path $repoFull $script:RepoProfilesRelative) $script:RepoProfilesRelative
$library = New-ProfileSource $LibraryRoot 'plugin-library'
$libraryEntries = $null
$profileResults = @{}

# Chain + merged standards for one profile id. A success is computed once and
# shared by every target using it; a failure is recomputed per target so its
# message names that target's own marker.
function Get-ProfileResult([string]$Id, [string]$Origin) {
    if ($profileResults.ContainsKey($Id)) { return $profileResults[$Id] }
    try {
        $chain = Resolve-ProfileChain $Id $repoProfiles $library $Origin
        $result = [pscustomobject]@{
            Error = $null; Chain = @($chain); Description = (Get-ProfileEntry $repoProfiles $Id).Description
            Standards = @(Get-MergedStandards $chain $repoProfiles $warnings)
        }
    }
    catch { return [pscustomobject]@{ Error = (Get-ProfileErrorText $_); Chain = @(); Description = $null; Standards = @() } }
    $script:profileResults[$Id] = $result
    return $result
}

$targets = @()
foreach ($full in $fullTargets) {
    $relative = Get-RelativeDisplay $repoFull $full
    $considered = @()
    $winner = $null
    $suggestion = $null
    $status = 'UNDECLARED'
    $profileId = $null
    $errorText = $null
    try {
        $walk = Get-DirectoryWalk $repoFull $full
        # An explicit -Profile beats every marker, malformed ones included: they are
        # recorded as overridden and reported as warnings, never as the target's error.
        $markers = Get-ProfileMarkers $repoFull $walk -Tolerant:([bool]$Profile)
        if ($Profile) {
            $winner = [pscustomobject]@{ Kind = 'explicit'; Source = '-Profile'; Profile = $Profile }
            foreach ($m in $markers) {
                $considered += [pscustomobject]@{ Kind = $m.Kind; Source = $m.Source; Profile = $m.Profile; Outcome = 'overridden-by-explicit' }
                if ($m.Error) { $warnings.Add("$($m.Error) (overridden by -Profile)") }
            }
        }
        else {
            for ($i = 0; $i -lt $markers.Count; $i++) {
                $m = $markers[$i]
                $considered += [pscustomobject]@{ Kind = $m.Kind; Source = $m.Source; Profile = $m.Profile; Outcome = if ($i -eq 0) { 'won' } else { 'shadowed' } }
            }
            if ($markers.Count) { $winner = [pscustomobject]@{ Kind = $markers[0].Kind; Source = $markers[0].Source; Profile = $markers[0].Profile } }
        }
        if ($winner -and $winner.Profile -eq 'none') { $status = 'NONE' }
        elseif ($winner) {
            $result = Get-ProfileResult $winner.Profile $winner.Source
            if ($result.Error) { $status = 'ERROR'; $errorText = $result.Error }
            else { $status = 'RESOLVED'; $profileId = $winner.Profile }
        }
        else {
            if ($null -eq $libraryEntries) { $libraryEntries = @(Get-AllProfileEntries $library $warnings) }
            $suggestion = Get-ProfileSuggestion $repoFull $walk $libraryEntries
        }
    }
    catch { $status = 'ERROR'; $errorText = Get-ProfileErrorText $_ }

    $targets += [pscustomobject]@{
        Target = $relative; Status = $status; Profile = $profileId; Error = $errorText
        Winner = if ($winner) { [pscustomobject]@{ Kind = $winner.Kind; Source = $winner.Source } } else { $null }
        Considered = @($considered); Suggestion = $suggestion
    }
}

$profiles = [ordered]@{}
foreach ($id in @($targets | Where-Object Status -eq 'RESOLVED' | ForEach-Object Profile | Sort-Object -Unique)) {
    $r = $profileResults[$id]
    $profiles[$id] = [pscustomobject]@{ Chain = $r.Chain; Description = $r.Description; Standards = $r.Standards }
}

$groups = [ordered]@{}
foreach ($t in $targets) {
    $key = switch ($t.Status) { 'RESOLVED' { $t.Profile } 'NONE' { '(none)' } 'ERROR' { '(error)' } default { '(undeclared)' } }
    if (-not $groups.Contains($key)) { $groups[$key] = @() }
    $groups[$key] += $t.Target
}
$aggregate = if ($groups.Contains('(error)')) { 'ERROR' } elseif ($groups.Count -gt 1) { 'MIXED' } elseif ($groups.Contains('(undeclared)')) { 'UNDECLARED' } else { 'UNIFORM' }
$exitCode = if ($aggregate -eq 'ERROR') { 1 } else { 0 }

$report = [pscustomobject]@{
    Repo = $repoFull; ReadOnly = $true; ExplicitProfile = if ($Profile) { $Profile } else { $null }
    Targets = @($targets)
    Aggregate = [pscustomobject]@{ Status = $aggregate; Groups = $groups }
    Profiles = $profiles
    Warnings = @($warnings | Select-Object -Unique)
}

if ($Format -eq 'Json') { $report | ConvertTo-Json -Depth 10; exit $exitCode }

Write-Output "architecture-profile: read-only resolution for $repoFull"
foreach ($t in $report.Targets) {
    Write-Output ''
    Write-Output "Target: $($t.Target)"
    switch ($t.Status) {
        'RESOLVED' { Write-Output "  PROFILE: $($t.Profile) ($($t.Winner.Kind): $($t.Winner.Source))" }
        'NONE' { Write-Output "  PROFILE: none ($($t.Winner.Kind): $($t.Winner.Source))" }
        'ERROR' { Write-Output "  PROFILE: error - $($t.Error)" }
        default { Write-Output '  PROFILE: undeclared' }
    }
    foreach ($c in $t.Considered | Where-Object Outcome -ne 'won') {
        $shown = if ($null -ne $c.Profile) { $c.Profile } else { '(invalid marker)' }
        Write-Output "  $($c.Outcome.ToUpperInvariant()): $($c.Source) -> $shown"
    }
    if ($t.Suggestion) { Write-Output "  $($t.Suggestion.Status): $($t.Suggestion.Profiles -join ', ') (evidence: $($t.Suggestion.Evidence -join ', '))" }
}
Write-Output ''
Write-Output "AGGREGATE: $($report.Aggregate.Status)"
foreach ($id in $report.Profiles.Keys) {
    $p = $report.Profiles[$id]
    Write-Output ''
    Write-Output "Profile $id (chain: $($p.Chain -join ' -> ')) - $($p.Description)"
    foreach ($s in $p.Standards) {
        $over = if ($s.Overrides.Count) { " overrides $($s.Overrides -join ', ')" } else { '' }
        Write-Output "  STANDARD $($s.Id) [$($s.From)$over] - $($s.Description)"
        Write-Output "    $($s.Path)"
    }
}
foreach ($w in $report.Warnings) { Write-Output "WARN: $w" }
exit $exitCode
```

- [x] **Step 5 (implement adoption):** create `plugins/cogniva-dev/scripts/adopt-architecture-profile.ps1`:

```powershell
#Requires -Version 7.0
# Copy a profile, and every profile it inherits from, from the plugin library
# into <repo>/.cogniva/profiles/. The repo copy is what every tool reads;
# updating is a deliberate re-run whose result shows up as an ordinary diff.
# Never writes a .cogniva-profile.yml marker - declaring stays a separate choice.
# Writes are staged: each profile is copied to a temporary sibling folder and
# verified, then swapped in with the previous copy kept as a backup until every
# swap succeeds; any failure rolls every swap back, and reports the copies as
# restored only when every restore verifiably succeeded - otherwise it names
# where each surviving previous copy is.
# Exit 0 = adopted or already up to date; 1 = a repo copy differs from the
# library (nothing written; re-run with -Force to replace it); 2 = usage,
# profile, or copy error.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Profile,
    [string]$LibraryRoot,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'profile-lib.ps1')

function Fail([string]$Message) { [Console]::Error.WriteLine("adopt-architecture-profile: $Message"); exit 2 }

# Relative path -> text with line endings normalised, so a CRLF checkout of an
# LF library file (or the reverse) is not reported as a difference.
function Get-TreeSnapshot([string]$Root) {
    $snapshot = @{}
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return $snapshot }
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File -Force) {
        $relative = Get-RelativeDisplay $Root $file.FullName
        $snapshot[$relative] = ([System.IO.File]::ReadAllText($file.FullName)) -replace "`r`n", "`n"
    }
    return $snapshot
}

function Get-SnapshotDifferences([hashtable]$Want, [hashtable]$Have) {
    return @(@($Want.Keys) + @($Have.Keys) | Select-Object -Unique | Where-Object { $Want[$_] -cne $Have[$_] } | Sort-Object)
}

try {
    if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
    Assert-ProfileId $Profile '-Profile'
    $repoFull = (Get-Item -LiteralPath $Repo).FullName
    if (-not $LibraryRoot) { $LibraryRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'profiles' }
    $library = New-ProfileSource $LibraryRoot 'plugin-library'
    if (-not (Get-ProfileEntry $library $Profile)) { Fail "profile '$Profile' is not in the plugin library ($LibraryRoot)" }
    $chain = Resolve-ProfileChain $Profile $library $null '-Profile'
    $destRoot = Join-Path $repoFull $script:RepoProfilesRelative

    $plan = @()
    $blocked = @()
    foreach ($id in $chain) {
        $source = (Get-ProfileEntry $library $id).Path
        $dest = Join-Path $destRoot $id
        $want = Get-TreeSnapshot $source
        if (-not (Test-Path -LiteralPath $dest)) { $plan += [pscustomobject]@{ Id = $id; Source = $source; Dest = $dest; Want = $want; Action = 'ADOPTED' }; continue }
        $differs = Get-SnapshotDifferences $want (Get-TreeSnapshot $dest)
        if (-not $differs.Count) { $plan += [pscustomobject]@{ Id = $id; Source = $source; Dest = $dest; Want = $want; Action = 'UP-TO-DATE' }; continue }
        $plan += [pscustomobject]@{ Id = $id; Source = $source; Dest = $dest; Want = $want; Action = 'REPLACED' }
        $blocked += [pscustomobject]@{ Id = $id; Files = $differs }
    }
}
catch { Fail ($_.Exception.Message -replace '^ProfileError: ', '') }

if ($blocked.Count -and -not $Force) {
    foreach ($b in $blocked) { Write-Output "DIFFERS: $($script:RepoProfilesRelative)/$($b.Id) - $($b.Files -join ', ')" }
    Write-Output 'Nothing written. The repo copy differs from the plugin library; review the difference, then re-run with -Force to replace it.'
    exit 1
}

$writes = @($plan | Where-Object Action -ne 'UP-TO-DATE')
$token = [guid]::NewGuid().ToString('N').Substring(0, 8)
foreach ($step in $writes) {
    $step | Add-Member -NotePropertyName Stage -NotePropertyValue (Join-Path $destRoot ".$($step.Id).adopting-$token")
    $step | Add-Member -NotePropertyName Backup -NotePropertyValue (Join-Path $destRoot ".$($step.Id).previous-$token")
}
$swapped = [System.Collections.Generic.List[object]]::new()
try {
    # 1. Stage and verify every copy before touching any existing folder.
    foreach ($step in $writes) {
        New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
        Copy-Item -LiteralPath $step.Source -Destination $step.Stage -Recurse
        $staged = Get-SnapshotDifferences $step.Want (Get-TreeSnapshot $step.Stage)
        if ($staged.Count) { throw "staged copy of '$($step.Id)' does not match the library ($($staged -join ', '))" }
    }
    # 2. Swap each staged copy in, keeping the previous copy as a backup. Directory.Move is a
    #    same-volume rename that either happens or does not; Move-Item can fall back to
    #    copy-and-delete and leave a folder half moved.
    foreach ($step in $writes) {
        if (Test-Path -LiteralPath $step.Dest) { [System.IO.Directory]::Move($step.Dest, $step.Backup) }
        $swapped.Add($step)
        [System.IO.Directory]::Move($step.Stage, $step.Dest)
    }
}
catch {
    $reason = $_.Exception.Message
    # Every rollback operation is guarded so one failure cannot stop the rest; the
    # outcome is then verified from the file system rather than assumed.
    $unrestored = @()
    for ($i = $swapped.Count - 1; $i -ge 0; $i--) {
        $step = $swapped[$i]
        # A swapped step's destination is either the new copy or missing; the backup, if any, is the old copy.
        try { if (Test-Path -LiteralPath $step.Dest) { Remove-Item -LiteralPath $step.Dest -Recurse -Force } } catch { }
        try { if ((Test-Path -LiteralPath $step.Backup) -and -not (Test-Path -LiteralPath $step.Dest)) { [System.IO.Directory]::Move($step.Backup, $step.Dest) } } catch { }
        if ($step.Action -eq 'ADOPTED') {
            if (Test-Path -LiteralPath $step.Dest) { $unrestored += "$($step.Id): new copy could not be removed from $($step.Dest)" }
        }
        elseif (Test-Path -LiteralPath $step.Backup) {
            $unrestored += "$($step.Id): previous copy is at $($step.Backup) ($($step.Dest) may hold a partial new copy)"
        }
    }
    $leftovers = @()
    foreach ($step in $writes) {
        try { if (Test-Path -LiteralPath $step.Stage) { Remove-Item -LiteralPath $step.Stage -Recurse -Force } } catch { }
        if (Test-Path -LiteralPath $step.Stage) { $leftovers += $step.Stage }
    }
    $cleanup = if ($leftovers.Count) { " Delete these staging folders by hand: $($leftovers -join '; ')." } else { '' }
    if ($unrestored.Count) { Fail "copy failed and rollback was incomplete: $reason. Restore by hand: $($unrestored -join '; ').$cleanup" }
    Fail "copy failed, existing copies restored: $reason$cleanup"
}
foreach ($step in $writes) {
    if (Test-Path -LiteralPath $step.Backup) { Remove-Item -LiteralPath $step.Backup -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $step.Backup) { Write-Output "WARN: could not remove the previous copy at $($step.Backup); delete it by hand." }
}

foreach ($step in $plan) {
    if ($step.Action -eq 'UP-TO-DATE') { Write-Output "UP-TO-DATE: $($step.Id)" }
    else { Write-Output "$($step.Action): $($step.Id) -> $($script:RepoProfilesRelative)/$($step.Id)" }
}
Write-Output "To declare it, add a $($script:MarkerName) containing 'profile: $Profile' at the repo root (default) or in a folder (override)."
exit 0
```

- [x] **Step 6 (the shipped library):** create these seven files exactly.

`plugins/cogniva-dev/profiles/cogniva-base/profile.yml`:

```yaml
description: Cogniva's technology-neutral architecture standards; the root every other profile inherits from.
```

`plugins/cogniva-dev/profiles/cogniva-base/standards/architecture/ownership-and-placement.md`:

```markdown
---
description: Every piece of substantive behaviour has one named owner; decide the owner before placing code, and stop when it is unclear.
---

# Ownership and placement

- Substantive behaviour - domain rules, persistence, evaluation, orchestration,
  and reusable logic - belongs to exactly one owning unit (a Module, package, or
  layer, as the repository defines them). Name that owner before placing code.
- A path suggested by a prompt or a plan is never enough to override a
  repository placement rule.
- When the owner is unclear, or two applicable rules disagree about it, stop and
  ask for a human architecture decision instead of choosing one.
```

`plugins/cogniva-dev/profiles/cogniva-base/standards/architecture/composition-roots.md`:

```markdown
---
description: Composition roots (hosts, entry points) wire owners together and hold no substantive behaviour of their own.
---

# Composition roots

- A composition root - a host, entry point, or startup project - assembles
  owners and registers implementations. Wiring and configuration only.
- Substantive application, domain, persistence, evaluation, or reusable
  behaviour found in a composition root belongs in its owning unit instead.
```

`plugins/cogniva-dev/profiles/cogniva-base/standards/architecture/dependency-direction.md`:

```markdown
---
description: Dependencies follow the direction the repository declares; a new dependency edge never bypasses it, and public surfaces stay pure.
---

# Dependency direction

- Follow the dependency direction the repository declares. A new dependency
  edge that bypasses it is a design departure to surface, not a detail to
  implement.
- A unit's public surface (its contracts or interface package) stays a pure
  surface: it is never where implementation lives.
```

`plugins/cogniva-dev/profiles/dotnet/profile.yml`:

```yaml
description: .NET Module (vertical-slice) architecture - Contracts, Domain, Application, Infrastructure, optional Client, and Blazor UI per Module.
inherits: cogniva-base
detect:
  - "*.slnx"
  - "*.sln"
  - "Directory.Build.props"
```

`plugins/cogniva-dev/profiles/dotnet/standards/dotnet/module-layout.md`:

```markdown
---
description: Where Modules, Hosts, UIs and tests live in a .NET Module-architecture repo.
---

# Module layout

- Vertical slices are **Modules** under `src/Modules/<Name>/`.
- Hosts (`src/Hosts/*`) are composition roots: each registers either the
  Application (in-process) or the Client (HTTP) implementation per Module.
- UIs are always Blazor. The same Module UI must run under a web host and a
  WPF (BlazorWebView) host - that works only if it depends on Contracts alone.
- Tests mirror modules under `tests/`.
```

`plugins/cogniva-dev/profiles/dotnet/standards/dotnet/module-dependencies.md`:

```markdown
---
description: Which projects may reference which - cross-Module references go through Contracts only, plus the per-Module reference rules.
---

# Module dependencies

- Cross-Module references go through `<Name>.Contracts` ONLY. Never reference
  another Module's Domain, Application, Infrastructure, Client, or UI.
- Per-Module dependency rules:
  - `<Name>.Contracts` -> references nothing
  - `<Name>.Domain` -> references nothing
  - `<Name>.Application` -> Domain, Contracts (implements Contracts in-process)
  - `<Name>.Infrastructure` -> Application, Domain
  - `<Name>.Client` (optional) -> Contracts (HTTP implementation)
  - `<Name>.UI` (Blazor RCL) -> Contracts ONLY
```

- [x] **Step 7 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → every line `PASS` except platform `SKIP` lines (on Windows: `case-variant collision` and `case-sensitive containment`; on Linux: `swap rollback`), then `All architecture-profile assertions passed.`, exit 0.

- [x] **Step 8 (register the suite in the green gate):** in `.claude/cogniva-dev/green-gate.json`, insert this line directly AFTER the line whose `"label"` is `"applicable-rules"` (that line keeps its trailing comma; this one needs one too, because the `gate-check` entry follows):

```json
    { "run": "pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1", "label": "architecture-profile", "note": "Pins profile resolution, inheritance, suggestions, adoption, and the shipped profile library; needs PowerShell 7." },
```

- [x] **Step 9 (validate the gate config):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/validate-json.ps1 .claude/cogniva-dev/green-gate.json` → exit 0.

- [x] **Step 10 (write ADRs):** scan `docs/adr/` for the highest number and write the five candidates from `## Candidate ADRs`, in order C1, C2, C3, C4, C5, as consecutive new numbers `docs/adr/NNNN-<slug>.md` per the adr skill's ADR-FORMAT: the title as the `# ` heading, the `**Provenance:**` line, a blank line, then the body paragraph verbatim. Slugs: `architecture-profiles-declared-per-path`, `standards-index-derived-from-frontmatter`, `profile-files-use-strict-yaml-subset`, `new-scripts-target-powershell-7`, `architecture-profiles-copied-into-repos`. No `ADR-C` label may appear in any written file.

- [x] **Step 11 (commit, only under `commits=task`):** stage with `git add -- plugins/cogniva-dev/scripts/profile-lib.ps1 plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1 plugins/cogniva-dev/scripts/adopt-architecture-profile.ps1 plugins/cogniva-dev/profiles plugins/cogniva-dev/tests/architecture-profile .claude/cogniva-dev/green-gate.json docs/adr`, then commit (the wrapper takes ONE `-Path` under `-File`; the commit includes everything staged) with `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/git-commit.ps1 -RepoPath . -Path docs/adr -Message "feat(cogniva-dev): architecture-profile resolver, adoption, and library"`

## Task 2: applicable-rules reports the architecture profile

**Files:**
- Modify: `plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1` (stays Windows PowerShell 5.1)
- Modify: `plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1` (stays Windows PowerShell 5.1)
- Modify: `plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` (one Linux-only check)
- Modify: `plugins/cogniva-dev/skills/applicable-rules/SKILL.md`

Requires Task 1's `plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1`.
The change is additive: every existing field and decision stays the same; each
target gains `ArchitectureProfile`. An undeclared repo, or a machine without
`pwsh`, gets the same decisions it got before, with `ArchitectureProfile`
reported as `UNDECLARED` or `UNAVAILABLE`.

- [x] **Step 1 (failing test):** replace the whole of `plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1` with:

```powershell
# Dependency-free evidence that applicable-rules is AGENTS-aware and leaves the
# checked repository unchanged.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$resolver = Join-Path $plugin 'scripts\resolve-applicable-rules.ps1'
$obligations = Join-Path $plugin 'scripts\resolve-workflow-obligations.ps1'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-applicable-rules-" + [guid]::NewGuid().ToString('N'))
$failures = @()

function Check($label, $condition) {
    if ($condition) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}

try {
    New-Item -ItemType Directory -Path (Join-Path $root 'src\Hosts\Sample') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Encoding UTF8 -Value "# Rules`n`n## Architecture`n`n- Hosts are composition roots only.`n`n## Cogniva-dev workflow instructions`n`n### before-integrate`n`n- AGENTS obligation"
    Set-Content -LiteralPath (Join-Path $root 'CLAUDE.md') -Encoding UTF8 -Value "# Architecture`n`n- Dependencies must respect Module ownership.`n`n## Cogniva-dev workflow instructions`n`n### before-planning`n`n- CLAUDE fallback planning obligation"
    $nestedAgents = Join-Path $root 'src\Hosts\AGENTS.md'
    Set-Content -LiteralPath $nestedAgents -Encoding UTF8 -Value "# Host subtree rules`n`n- Host wiring diagnostics are required here."
    & git -C $root init -q
    $before = @(& git -C $root status --porcelain)
    $json = & powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'src/Hosts/Sample/NewService.cs' -Purpose 'domain behavior' -Format Json
    $exitCode = $LASTEXITCODE
    $after = @(& git -C $root status --porcelain)
    $report = $json | ConvertFrom-Json
    $phaseJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $obligations -Repo $root -Phase 'before-planning' -Format Json
    $phaseExitCode = $LASTEXITCODE
    $phase = $phaseJson | ConvertFrom-Json

    Set-Content -LiteralPath $nestedAgents -Encoding UTF8 -Value "# Conflicting host rule`n`n- Hosts may contain domain behavior."
    $conflictJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'src/Hosts/Sample/NewService.cs' -Purpose 'wiring' -Format Json
    $conflictExitCode = $LASTEXITCODE
    $conflictReport = $conflictJson | ConvertFrom-Json
    Set-Content -LiteralPath $nestedAgents -Encoding UTF8 -Value "# Host subtree rules`n`n- Host wiring diagnostics are required here."

    Check 'resolver succeeds' ($exitCode -eq 0)
    Check 'resolver discovers root and nested AGENTS.md files' ($report.Targets[0].Agents.Count -eq 2 -and $report.Targets[0].Agents[0] -match 'AGENTS\.md$' -and $report.Targets[0].Agents[1] -match 'src[\\/]Hosts[\\/]AGENTS\.md$')
    Check 'resolver reports effective authority order and nested precedence' ($report.Targets[0].EffectiveAuthority.Count -eq 3 -and $report.Targets[0].EffectiveAuthority[1].Source -eq 'AGENTS.md' -and $report.Targets[0].EffectiveAuthority[1].Path -match 'src[\\/]Hosts[\\/]AGENTS\.md$')
    Check 'resolver retains substantive CLAUDE.md authority' ($report.Targets[0].Claude.Count -eq 1 -and $report.Targets[0].Constraints.File -match 'CLAUDE\.md$')
    Check 'resolver exposes a Host placement conflict' ($report.Targets[0].Conflicts -match 'CONFLICT:')
    Check 'phase resolution falls back to CLAUDE.md when AGENTS lacks the phase' ($phaseExitCode -eq 0 -and $phase.Source -eq 'CLAUDE.md (fallback)' -and $phase.Lines -match 'CLAUDE fallback planning obligation')
    Check 'conflicting authority produces REVIEW_REQUIRED' ($conflictExitCode -eq 0 -and $conflictReport.Targets[0].Decision -eq 'REVIEW_REQUIRED' -and -not $conflictReport.Targets[0].CanProceedAutomatically -and $conflictReport.Targets[0].ReviewReasons.Count -gt 0)
    Check 'resolver leaves repository status unchanged' (($before -join "`n") -eq ($after -join "`n"))

    # Windows paths are case-insensitive: a case-variant spelling of the repo is still the repo.
    # (The Linux counterpart lives in the pwsh 7 architecture-profile suite.)
    $variantJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target (Join-Path $root.ToUpperInvariant() 'docs\readme.md') -Purpose 'documentation' -Format Json
    $variantExitCode = $LASTEXITCODE
    Check 'a case-variant spelling of the repo path is inside the repo on Windows' ($variantExitCode -eq 0 -and ($variantJson | ConvertFrom-Json).Targets[0].Target -match '^docs[\\/]readme\.md$')

    # --- architecture profile (reported alongside, never changes an undeclared repo's decision) ---
    Check 'undeclared repo reports an UNDECLARED architecture profile' ($report.Targets[0].ArchitectureProfile.Status -eq 'UNDECLARED' -and $null -eq $report.Targets[0].ArchitectureProfile.Profile)
    $plain = (& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'docs/readme.md' -Purpose 'documentation' -Format Json) | ConvertFrom-Json
    Check 'undeclared profile adds no review reason' ($plain.Targets[0].Decision -eq 'SAFE_TO_PROCEED' -and $plain.Targets[0].ArchitectureProfile.Status -eq 'UNDECLARED')

    New-Item -ItemType Directory -Path (Join-Path $root '.cogniva\profiles\fixture') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root '.cogniva\profiles\fixture\profile.yml') -Encoding ASCII -Value 'description: Fixture profile.'
    Set-Content -LiteralPath (Join-Path $root '.cogniva-profile.yml') -Encoding ASCII -Value 'profile: fixture'
    $declared = (& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'docs/readme.md' -Purpose 'documentation' -Format Json) | ConvertFrom-Json
    Check 'declared profile is reported with where it came from' ($declared.Targets[0].ArchitectureProfile.Status -eq 'RESOLVED' -and $declared.Targets[0].ArchitectureProfile.Profile -eq 'fixture' -and $declared.Targets[0].ArchitectureProfile.Kind -eq 'repo-default' -and $declared.Targets[0].ArchitectureProfile.Source -eq '.cogniva-profile.yml')
    Check 'a resolved profile does not change the decision' ($declared.Targets[0].Decision -eq 'SAFE_TO_PROCEED')
    $declaredText = (& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'docs/readme.md' -Purpose 'documentation') -join "`n"
    Check 'text output names the architecture profile' ($declaredText -match 'ARCHITECTURE PROFILE: fixture \(repo-default: \.cogniva-profile\.yml\)')

    Set-Content -LiteralPath (Join-Path $root '.cogniva-profile.yml') -Encoding ASCII -Value 'profile: missing'
    $brokenJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'docs/readme.md' -Purpose 'documentation' -Format Json
    $brokenExitCode = $LASTEXITCODE
    $broken = $brokenJson | ConvertFrom-Json
    Check 'an unresolvable profile requires review instead of crashing' ($brokenExitCode -eq 0 -and $broken.Targets[0].ArchitectureProfile.Status -eq 'ERROR' -and $broken.Targets[0].Decision -eq 'REVIEW_REQUIRED' -and ($broken.Targets[0].ReviewReasons -join ' ') -match 'Architecture profile could not be resolved')

    Set-Content -LiteralPath (Join-Path $root '.cogniva-profile.yml') -Encoding ASCII -Value 'profile: fixture'
    New-Item -ItemType Directory -Path (Join-Path $root 'broken') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root 'broken\.cogniva-profile.yml') -Encoding ASCII -Value 'profile: absent'
    $splitJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'docs/readme.md,broken/thing.md' -Purpose 'documentation' -Format Json
    $split = $splitJson | ConvertFrom-Json
    Check 'a profile error affects only its own target' ($split.Targets[0].ArchitectureProfile.Status -eq 'RESOLVED' -and $split.Targets[0].Decision -eq 'SAFE_TO_PROCEED' -and $split.Targets[1].ArchitectureProfile.Status -eq 'ERROR' -and $split.Targets[1].Decision -eq 'REVIEW_REQUIRED' -and ($split.Targets[1].ReviewReasons -join ' ') -match "profile 'absent'")

    $savedPath = $env:PATH
    try {
        $env:PATH = (($env:PATH -split ';') | Where-Object { $_ -and -not (Test-Path -LiteralPath (Join-Path $_ 'pwsh.exe')) }) -join ';'
        $noPwsh = (& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'docs/readme.md' -Purpose 'documentation' -Format Json) | ConvertFrom-Json
    }
    finally { $env:PATH = $savedPath }
    Check 'without pwsh the profile is UNAVAILABLE and the decision is unchanged' ($noPwsh.Targets[0].ArchitectureProfile.Status -eq 'UNAVAILABLE' -and $noPwsh.Targets[0].Decision -eq 'SAFE_TO_PROCEED')
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { exit 1 }
Write-Host 'All applicable-rules assertions passed.'
```

Then, because the applicable-rules suite runs only under Windows PowerShell, add the
case-sensitive containment check to the pwsh 7 suite: in
`plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1`,
insert these two lines immediately AFTER the line that starts
`        Check 'a sibling differing only by case is outside the repo on a case-sensitive system'`
(inside the `if ($IsLinux)` block, same eight-space indent):

```powershell
        $r = Invoke-Script (Join-Path $plugin 'scripts\resolve-applicable-rules.ps1') @('-Repo', $cased, '-Target', (Join-Path $sibling 'x'))
        Check 'applicable-rules also treats a case-variant sibling as outside the repo' ($r.Code -eq 2 -and $r.All -match 'outside repo')
```

- [x] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1` → the eight original checks and the Windows case-variant containment check PASS (that one guards against over-tightening, so it passes before and after); the eight architecture-profile checks FAIL; exit 1.

- [x] **Step 3 (implement):** replace the whole of `plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1` with:

```powershell
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

# The architecture-profile resolver is a PowerShell 7 script; this script stays
# Windows PowerShell 5.1, so it runs the resolver as a separate pwsh process.
# No pwsh -> the profile is reported UNAVAILABLE and nothing else changes.
# Resolver exit 0/1 -> a per-target report (1 = some targets are ERROR);
# exit 2 -> a usage failure that applies to every target.
function Get-ArchitectureProfileReport([string]$RepoFull, [string[]]$Targets) {
    $pwsh = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pwsh) { return [pscustomobject]@{ Available = $false; Error = $null; Report = $null } }
    $resolver = Join-Path $PSScriptRoot 'resolve-architecture-profile.ps1'
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = @(& $pwsh.Source -NoProfile -File $resolver -Repo $RepoFull -Target ($Targets -join ',') -Format Json 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    $stdout = @($lines | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
    $stderr = @($lines | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
    if ($code -ne 0 -and $code -ne 1) { return [pscustomobject]@{ Available = $true; Error = (($stderr -join ' ').Trim()); Report = $null } }
    return [pscustomobject]@{ Available = $true; Error = $null; Report = (($stdout -join "`n") | ConvertFrom-Json) }
}

$repoFull = [System.IO.Path]::GetFullPath($Repo)
if (-not (Test-Path -LiteralPath $repoFull -PathType Container)) { Fail "repo not found: $Repo" }
$repoFull = (Get-Item -LiteralPath $repoFull).FullName
# Same rule as profile-lib.ps1 (and .NET): paths are case-sensitive on Linux,
# insensitive on Windows and macOS. $IsLinux is undefined, so false, in 5.1.
$pathComparison = if ($IsLinux) { [StringComparison]::Ordinal } else { [StringComparison]::OrdinalIgnoreCase }

$items = @()
$requestedTargets = @($Target | ForEach-Object {
    $_ -split ',' | ForEach-Object { $_.Trim().Trim("'").Trim('"') } | Where-Object { $_ }
})
$profileReport = Get-ArchitectureProfileReport $repoFull $requestedTargets
$targetIndex = -1
foreach ($rawTarget in $requestedTargets) {
    $targetIndex++
    $targetFull = Get-FullPath $rawTarget $repoFull
    $prefix = $repoFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ([string]::Equals($targetFull, $repoFull, $pathComparison) -or $targetFull.StartsWith($prefix, $pathComparison))) {
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
    if (-not $profileReport.Available) {
        $architectureProfile = [pscustomobject]@{ Status = 'UNAVAILABLE'; Profile = $null; Kind = $null; Source = $null; Suggestion = $null; Note = 'PowerShell 7 (pwsh) not found; architecture profile not checked.' }
    }
    elseif ($profileReport.Error) {
        $architectureProfile = [pscustomobject]@{ Status = 'ERROR'; Profile = $null; Kind = $null; Source = $null; Suggestion = $null; Note = $profileReport.Error }
        $reviewReasons += "Architecture profile could not be resolved: $($profileReport.Error)"
    }
    else {
        $resolved = $profileReport.Report.Targets[$targetIndex]
        $architectureProfile = [pscustomobject]@{
            Status = $resolved.Status; Profile = $resolved.Profile
            Kind = if ($resolved.Winner) { $resolved.Winner.Kind } else { $null }
            Source = if ($resolved.Winner) { $resolved.Winner.Source } else { $null }
            Suggestion = $resolved.Suggestion; Note = $resolved.Error
        }
        if ($resolved.Status -eq 'ERROR') { $reviewReasons += "Architecture profile could not be resolved: $($resolved.Error)" }
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
        ArchitectureProfile = $architectureProfile
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
    $ap = $item.ArchitectureProfile
    $profileText = switch ($ap.Status) {
        'RESOLVED' { "$($ap.Profile) ($($ap.Kind): $($ap.Source))" }
        'NONE' { "none ($($ap.Kind): $($ap.Source))" }
        'UNDECLARED' { if ($ap.Suggestion) { "undeclared ($($ap.Suggestion.Status.ToLowerInvariant()): $($ap.Suggestion.Profiles -join ', '))" } else { 'undeclared' } }
        default { "$($ap.Status.ToLowerInvariant()) - $($ap.Note)" }
    }
    Write-Output "  ARCHITECTURE PROFILE: $profileText"
    Write-Output "  DECISION: $($item.Decision)"
    foreach ($conflict in $item.Conflicts) { Write-Output "  PLACEMENT: $conflict" }
    foreach ($reason in $item.ReviewReasons) { Write-Output "  REVIEW_REQUIRED: $reason" }
    foreach ($constraint in $item.Constraints) { Write-Output "  RULE [$($constraint.File):$($constraint.Line)] $($constraint.Text)" }
}
exit 0
```

- [x] **Step 4 (document):** in `plugins/cogniva-dev/skills/applicable-rules/SKILL.md`, insert this paragraph immediately BEFORE the paragraph that starts `For automation, add \`-Format Json\``:

```markdown
Each target also reports `ArchitectureProfile`: the profile that applies there
and the `.cogniva-profile.yml` marker it came from, or `UNDECLARED`, `NONE`,
`UNAVAILABLE` (PowerShell 7 is not installed), or `ERROR`. An `ERROR` makes that
target's decision `REVIEW_REQUIRED`. For a resolved profile's standards index, run
`pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo "<repo>" -Target "<target-path>"`
and read the standards that bear on the change.
```

- [x] **Step 5 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1` → all 17 checks PASS, `All applicable-rules assertions passed.`, exit 0. Then `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → exit 0 (on Windows the new check is inside the Linux-only block and SKIPs with its neighbour). Then `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/run-gate-check/run-gate-check.tests.ps1` → exit 0 (gate-check is unaffected).

- [x] **Step 6 (commit, only under `commits=task`):** stage with `git add -- plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1 plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1 plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1 plugins/cogniva-dev/skills/applicable-rules/SKILL.md`, then commit (the wrapper takes ONE `-Path` under `-File`; the commit includes everything staged) with `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/git-commit.ps1 -RepoPath . -Path plugins/cogniva-dev/skills/applicable-rules/SKILL.md -Message "feat(applicable-rules): report the architecture profile per target"`

## Task 3: plan-feature designs under the architecture profile

**Files:**
- Modify: `plugins/cogniva-dev/skills/plan-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md`
- Modify: `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`

- [x] **Step 1 (failing test):** in `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`, insert this block immediately BEFORE the line `if ($failures.Count -gt 0) {` (keep it ASCII-only: Windows PowerShell 5.1 reads this file as ANSI):

```powershell
# --- architecture profiles ----------------------------------------------------
$pfFlat = $pf -replace '\s+', ' '
$fmt    = ReadDoc 'skills\plan-feature\PLAN-FORMAT.md'
Check 'plan-feature resolves the architecture profile through the shared resolver' `
    ($pf -match 'resolve-architecture-profile\.ps1')
Check 'plan-feature never adopts or declares a profile on its own' `
    ($pfFlat -match 'Adopting or declaring a profile writes files, so do it only when the user asks')
Check 'plan-feature restates standards in task bodies' `
    ($pfFlat -match 'the executing agent never sees the profile')
Check 'PLAN-FORMAT carries the Architecture profile header line' `
    ($fmt -match '\*\*Architecture profile:\*\*')
Check 'applicable-rules documents the ArchitectureProfile field' `
    ($ar -match 'ArchitectureProfile')
Check 'PLAN-FORMAT header defers committing to the commits= policy' `
    ($fmt -notmatch 'tasks commit on the branch they are already on' -and ($fmt -replace '\s+', ' ') -match 'commit step applies only when the run''s .commits=. policy commits')

```

- [x] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → the five plan-feature / PLAN-FORMAT checks FAIL (the applicable-rules check already passes after Task 2); exit 1.

- [x] **Step 3 (implement — plan-feature step):** in `plugins/cogniva-dev/skills/plan-feature/SKILL.md`, insert this paragraph immediately AFTER the paragraph ending `first with a per-phase CLAUDE.md fallback.` and BEFORE the numbered list that starts `1. Explore the repo enough to design well`:

```markdown
**Architecture profile.** As soon as you know which paths the design will
touch (directories are enough), run `pwsh -NoProfile -File
"<plugin>/scripts/resolve-architecture-profile.ps1" -Repo "<repo>" -Target
"<path>,<path>"`, adding `-Profile <id>` when the user passed `profile=<id>`.
No `pwsh` on this machine: say so in one line and plan as before. Read the
standards index it prints, open only the standards that bear on this design,
and honour them like existing ADRs: surface a departure, never work around
it. `UNDECLARED`: mention any suggestion in one line and carry on without a
profile. Adopting or declaring a profile writes files, so do it only when
the user asks (`<plugin>/scripts/adopt-architecture-profile.ps1`, then a
one-line `.cogniva-profile.yml`). `MIXED`: say which paths fall under which
profile and apply each profile to its own paths. `ERROR` for a path: show the
reason and ask the user how to proceed before designing anything there.
Re-run when the locked file structure adds paths.
```

- [x] **Step 4 (implement — plan header rule):** in the same file, under `## Emit the plan`, insert this bullet immediately AFTER the bullet that starts `- No ⛔ gates by default`:

```markdown
- Designed under an architecture profile: add the header line
  `**Architecture profile:** <id> (<kind>: <marker path>) — standards
  applied: <standard ids>` (one per profile when `MIXED`). Tasks restate
  every constraint a standard imposes, because the executing agent never
  sees the profile, and never cite an absolute path.
```

- [x] **Step 5 (implement — PLAN-FORMAT):** in `plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md`, inside the first template (the flat plan), insert these lines between the `**Architecture:** <2-4 sentences — approach, where it fits, key types>` line and the `**Read these first:** <links to spec/ADRs/related code>` line, with one blank line before and after:

```markdown
**Architecture profile:** <id> (<kind>: <marker path>) — standards applied: <standard ids>
<!-- Only when plan-feature resolved an architecture profile; one line per
     profile when targets were MIXED. Omit the line otherwise. -->
```

- [x] **Step 6 (implement — PLAN-FORMAT header):** in the same file, inside the first template (the flat plan), replace these three lines:

```markdown
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace
> and the tasks commit on the branch they are already on. Never run
> git switch/checkout/branch inside a task.
```

with these four:

```markdown
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.
```

The multi-plan manifest template's header has no commit wording and stays as it is.

- [x] **Step 7 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`, exit 0. Then `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/parse-plan-tasks/parse-plan-tasks.tests.ps1` → exit 0 (the new header line sits outside task bodies).

- [x] **Step 8 (commit, only under `commits=task`):** stage with `git add -- plugins/cogniva-dev/skills/plan-feature/SKILL.md plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`, then commit (the wrapper takes ONE `-Path` under `-File`; the commit includes everything staged) with `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/git-commit.ps1 -RepoPath . -Path plugins/cogniva-dev/skills/plan-feature/SKILL.md -Message "feat(plan-feature): design under the resolved architecture profile"`

## Task 4: Documentation, glossary, version bump, and the full gate

**Files:**
- Create: `plugins/cogniva-dev/docs/architecture-profiles.md`
- Modify: `docs/strategy.md`
- Modify: `docs/glossary/README.md`
- Modify: `CLAUDE.md`
- Modify: `plugins/cogniva-dev/.claude-plugin/plugin.json`
- Modify: `plugins/cogniva-dev/.codex-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [x] **Step 1 (user guide):** create `plugins/cogniva-dev/docs/architecture-profiles.md`:

````markdown
# Architecture profiles

An architecture profile is a named set of declarative standards for one kind
of codebase (for example `dotnet`). The plugin's `profiles/` folder is a
library to copy from; a repo uses a profile only after adopting it, and every
tool reads only the repo's copy.

## Use a profile in a repo

1. **Adopt it.** This copies the profile, and every profile it inherits from,
   into `.cogniva/profiles/`:

   ```powershell
   pwsh -NoProfile -File "<plugin>/scripts/adopt-architecture-profile.ps1" -Repo . -Profile dotnet
   ```

2. **Declare it** with a one-line `.cogniva-profile.yml`:

   ```yaml
   profile: dotnet
   ```

   At the repo root it is the default for the whole repo. In a folder it
   applies to that folder and everything below it. `profile: none` switches
   profiles off for a subtree (for example `docs/`).

3. **Commit both.** To pick up library changes later, re-run step 1. An
   unchanged copy is reported `UP-TO-DATE`; a copy you have edited is reported
   `DIFFERS` and left alone unless you add `-Force`. Either way the change
   reaches the repo as an ordinary diff. `-Force` copies to a temporary folder
   and swaps it in only once the copy is verified; if anything fails, every
   existing copy is restored, and if a restore itself fails the error says
   where each previous copy was left.

## How a path's profile is chosen

1. `-Profile <id>` (plan-feature's `profile=<id>`), for that run only. It
   overrides every marker, even a malformed one, which is reported as a warning.
2. The nearest `.cogniva-profile.yml` above the path.
3. The `.cogniva-profile.yml` at the repo root.

Nothing declared means `UNDECLARED`. The resolver may suggest a library
profile from files it sees (a `*.slnx` suggests `dotnet`), but it never applies
or saves one. When several paths land on different profiles the result is
`MIXED`, reported path by path.

```powershell
pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo . -Target "src/Orders,tools/ingest"
```

Add `-Format Json` for the machine-readable report: the winning marker, the
markers it shadowed, the inheritance chain, and the standards index (id,
description, which profile it came from, and which profile it overrides).

Each path resolves on its own. A broken marker or profile marks only the paths
that use it as `ERROR`, with the file and line at fault. Exit codes: `0` every
path resolved, `1` the report lists at least one `ERROR`, `2` a usage error
(no report).

## Writing a profile

```text
<id>/
  profile.yml
  standards/<area>/<name>.md
```

- Profile ids are lowercase letters, digits and `-` (the folder name is the
  id). `none` is reserved for markers.
- `profile.yml` keys: `description` (required, one line), `inherits` (one
  parent profile id), `detect` (quoted file-name patterns, used only for
  suggestions). Any other key is an error.
- A standard is ordinary Markdown with a one-line `description:` in its
  frontmatter; a standard without one is an error. Agents see the descriptions
  first and open only the standards they need, so make the description say when
  the standard matters. Other frontmatter keys are ignored with a warning.
- A standard's identity is its path under `standards/`, compared
  case-insensitively. A child profile's file at the same path replaces the
  parent's.
- Standards are declarative guidance. Workflow steps belong in skills.

## The YAML subset

Profile files, markers and standard frontmatter use a strict subset of YAML:
`key: value` lines, `key:` followed by indented `- item` lines, `#` comments,
and single- or double-quoted values. No nesting, flow lists (`[a, b]`),
anchors, or multi-line strings. Quote any value that starts with `*`, `[`,
`{`, `&`, `!`, `|` or `>`. Quoted values are taken literally: YAML escape
sequences (`\"`, `''`) are not currently supported, so a value cannot contain
its own quote character. Every error names the file and line.

## Where profiles are used

- `plan-feature` resolves the profile for the paths a design touches and
  restates the relevant standards in the plan's tasks.
- `applicable-rules` reports the profile for each target it checks.
- Executing agents see only what a plan's tasks restate.

The scripts need PowerShell 7 (`pwsh`). Without it, plan-feature plans without
a profile, and applicable-rules reaches the same decisions it always did and
reports the profile as `UNAVAILABLE`.
````

- [x] **Step 2 (strategy — fix the stale Purpose paragraph):** in `docs/strategy.md`, replace the paragraph under `## Purpose` (the one starting `` `cogniva` is Cogniva's Claude Code plugin marketplace `` and ending `copying files).`) with:

```markdown
`cogniva` is Cogniva's Claude Code plugin marketplace (repo:
github.com/cogniva/cogniva-skills). It ships two plugins: `cogniva-skills`
(general-purpose skills such as glossary and reference) and `cogniva-dev`
(development tooling: ADRs, the backlog, repo scaffolding with repo-init and
add-module, and the feature lifecycle), so every new repo starts identical and
improvements propagate: consuming repos update the plugins instead of copying
tooling. Architecture profiles are the deliberate exception; see below.
```

- [x] **Step 3 (strategy — new section):** in `docs/strategy.md`, insert this section immediately BEFORE the line `## Roadmap (deliberately not yet)`:

```markdown
## Architecture profiles

An [Architecture profile](glossary/README.md#architecture-profile) is a set of
declarative standards for one kind of codebase. The cogniva-dev plugin ships a
library of them (`plugins/cogniva-dev/profiles/`); a repo adopts one by copying
it into `.cogniva/profiles/` and selects it per path with a
[Profile marker](glossary/README.md#profile-marker). Tools read only the repo's
copy, so a repo's standards change only through a deliberate re-adoption.
plan-feature designs under the resolved profile and applicable-rules reports it
per target; executing agents see only what a plan's tasks restate. How to
adopt, declare, and write profiles: `plugins/cogniva-dev/docs/architecture-profiles.md`.

```

- [x] **Step 4 (glossary):** append these two entries to the end of `docs/glossary/README.md` (after the `## Status` entry, separated by one blank line):

```markdown
## Architecture profile

A named set of declarative architectural standards for one kind of codebase (e.g. `dotnet`): a folder holding a `profile.yml` and Markdown files under `standards/`. It may inherit one other profile, replacing any inherited standard that has the same path. The cogniva-dev plugin ships a library of them; a repo adopts one by copying it into `.cogniva/profiles/`, and tools read only that copy. Selected per path by a [Profile marker](#profile-marker).
_Avoid_: stack, tech profile, template

## Profile marker

A `.cogniva-profile.yml` file containing `profile: <id>` (or `profile: none`) that selects the [Architecture profile](#architecture-profile) for its folder and everything below it. The marker nearest a path wins; the one at the repo root is the repository default. Written only by a human decision, never inferred.
_Avoid_: profile config, profile declaration
```

- [x] **Step 5 (CLAUDE.md layout):** in the root `CLAUDE.md`, on the `plugins/cogniva-dev/` line under `## Layout`, replace the text `; scripts, hooks, and repo scaffolding templates` with the text `` ; the architecture-profile library (`profiles/`), scripts, hooks, and repo scaffolding templates `` (no leading or trailing space).

- [x] **Step 6 (version bump, human-approved minor 0.8.1 -> 0.9.0):** this materially expands cogniva-dev (new scripts, a profile library, and a new plan-feature step), so it is a minor bump. Change `"version": "0.8.1"` to `"version": "0.9.0"` in exactly three places and nowhere else: `plugins/cogniva-dev/.claude-plugin/plugin.json`, `plugins/cogniva-dev/.codex-plugin/plugin.json`, and the `cogniva-dev` entry in `.claude-plugin/marketplace.json` (the `cogniva-skills` entry stays `0.8.0`). Then `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-plugin-manifests.ps1` → exit 0, and `powershell -NoProfile -Command "Select-String -Path plugins/cogniva-dev/.claude-plugin/plugin.json,plugins/cogniva-dev/.codex-plugin/plugin.json,.claude-plugin/marketplace.json -Pattern 'version'"` → three `0.9.0` lines and one `0.8.0` line (cogniva-skills). When execute-feature's `before-integrate` block later offers the bump, report it as already done here.

- [x] **Step 7 (run the full gate):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → `green-gate: GREEN - all 8 command(s) exited 0.`, exit 0.

- [x] **Step 8 (commit, only under `commits=task`):** stage with `git add -- plugins/cogniva-dev/docs/architecture-profiles.md docs/strategy.md docs/glossary/README.md CLAUDE.md plugins/cogniva-dev/.claude-plugin/plugin.json plugins/cogniva-dev/.codex-plugin/plugin.json .claude-plugin/marketplace.json`, then commit (the wrapper takes ONE `-Path` under `-File`; the commit includes everything staged) with `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/git-commit.ps1 -RepoPath . -Path CLAUDE.md -Message "docs(cogniva-dev): architecture profiles guide, glossary, and 0.9.0 bump"`
