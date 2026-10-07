# QuickFixStructuralChecks — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/QuickFixStructuralChecks
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** `quick-fix` checks every structural change (a unit added or
removed, a dependency between units added or removed, code moved between
units) against the architecture standards that govern it before landing.
Ordinary fixes make no profile call while scoping and give their workers
nothing extra.

**Architecture:** Profiles gain four `profile.yml` keys: `structure-kinds`,
`structure-detectors`, `structure-requires` (`"<kind> <standard id>"` pairs)
and `structure-requires-dropped`. They compose root first, and a child drops
an inherited pair by name. The keys live in `profile.yml`, not in standard
frontmatter, so they never make an amendment STALE. The resolver gains
`-Kinds` (it adds the mapped standards to the existing `-Require` gate) and a
list form of `-Show`. Its per-target logic moves into `profile-lib.ps1` so a
new `check-structural-changes.ps1` can reuse it in-process. That script
snapshots the working state as a git tree at quick-fix's start (`-Snapshot`).
Before landing (`-Since`) it runs every plugin detector that a profile
declared anywhere in the repo selects, now or at the start, because a change
in one folder can affect units below it. The first detector is
`scripts/structure-detectors/dotnet-projects.ps1` (contract 1: exit 0 plus a
JSON `facts` list; anything else is a failed check). Each fact lists every
path it governs, both ends of a dependency included. The script gates the
standards those paths' profiles require with `-Require` semantics. When the
fix touched a marker or `.cogniva/`, it adds the profiles the start tree's
markers named. Requirements always come from the profiles' current text,
and any profile edit is a `profile-changed` fact that needs the user's OK.
quick-fix stays technology-neutral. It preflights only when it expects a
structural change, one resolver call per expected kind and its own paths,
and puts each profile's full `-Show` text into the body of the tasks that
make that change. Both backends pass the body verbatim. It runs the
check after `before-integrate` and before the ADR check and green gate, and
it handles every exit code explicitly.

**Read these first:**
- `docs/adr/0042-repo-owned-profiles-change-inherited-standards-by-amendment.md`, `docs/adr/0043-amendment-records-inherited-text-it-was-reviewed-against.md`, `docs/adr/0045-architecture-dependent-changes-stop-only-on-review-items-they-depend-on.md`, `docs/adr/0039-new-scripts-target-powershell-7.md`, `docs/adr/0024-green-gate-is-last-before-integration.md`
- `plugins/cogniva-dev/docs/architecture-profiles.md`
- `plugins/cogniva-dev/scripts/profile-lib.ps1`, `plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1`
- `plugins/cogniva-dev/skills/quick-fix/SKILL.md`, `plugins/cogniva-dev/skills/quick-fix/WORKTREE.md`, `plugins/cogniva-dev/skills/execute-feature/CODEX.md`

**Decisions taken in planning (the user confirmed each):**
- An UNEXPECTED structural change found at landing waits for the user's OK, even when quick-fix judges it compliant.
- A failed check (a detector crashed, is missing or broke the contract, or a changed path's profile is in ERROR) stops landing. Only an explicit user waiver lets it land, recorded under Skipped validations.
- In .NET a unit is a project file. Moving a file between two projects of one Module counts as a move; that only triggers a standards check.
- Detector code ships in the plugin, and profiles name a detector by id. Repo-supplied detectors are out of scope.
- No glossary entries: the terms are defined in `plugins/cogniva-dev/docs/architecture-profiles.md` only.

**Constraints every task honours:**
- New scripts target PowerShell 7 (`#Requires -Version 7.0`, run with `pwsh -NoProfile -File`); existing 5.1 scripts are untouched.
- `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` runs under Windows PowerShell 5.1 and must stay ASCII-only.
- `quick-fix/SKILL.md` must not name any technology (`csproj`, `ProjectReference`, `.NET`, `pyproject`); technology knowledge lives in detectors and profiles.
- `profiles/dotnet/` must keep passing the Module-bundle leak check: no `src/Modules`, no `.Domain`/`.Application`/`.Infrastructure`/`.Client` names.
- No real repository names anywhere under `plugins/cogniva-dev/` (the profile-library leak check).

## File structure (locked)

```
plugins/cogniva-dev/scripts/profile-lib.ps1                                  # structure keys, Get-EffectiveStructure, shared target resolution + require gate
plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1                 # uses the shared resolution; -Kinds; -Show list; Structure in the report
plugins/cogniva-dev/scripts/structure-lib.ps1                                # NEW: working-tree snapshot, tree diff, tree reads, detector report helpers
plugins/cogniva-dev/scripts/structure-detectors/dotnet-projects.ps1          # NEW: the .NET structure detector (contract 1)
plugins/cogniva-dev/scripts/check-structural-changes.ps1                     # NEW: -Snapshot and the landing check
plugins/cogniva-dev/profiles/cogniva-base/profile.yml                        # the five kinds + base structure-requires
plugins/cogniva-dev/profiles/dotnet/profile.yml                              # dotnet-projects + dotnet structure-requires
plugins/cogniva-dev/skills/quick-fix/SKILL.md                                # START_TREE, Step 0.6 preflight, worker stop line, structural check
plugins/cogniva-dev/skills/quick-fix/WORKTREE.md                             # snapshot in the worktree after any staleness merge
plugins/cogniva-dev/skills/execute-feature/CODEX.md                          # quick-fix's landing under Codex includes the check
plugins/cogniva-dev/docs/architecture-profiles.md                            # Structural changes section, keys, -Kinds, -Show list, JSON
docs/strategy.md                                                             # one-line mention of quick-fix
plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1  # structure policy, -Kinds, -Show list
plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1    # NEW: snapshot, detector, check
plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1          # shipped policy + live dotnet check
plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1          # quick-fix / WORKTREE / CODEX pins
.claude/cogniva-dev/green-gate.json                                          # structural-changes suite
docs/adr/NNNN-*.md (three)                                                   # ADR-C1 (Task 2), ADR-C2 (Task 4), ADR-C3 (Task 7)
```

## Candidate ADRs

### ADR-C1: Profiles map structural change kinds to the standards they require in profile.yml
**Provenance:** Suggested by agent
A profile lists change kinds (`structure-kinds`), the detectors it selects
(`structure-detectors`) and the standards each kind requires
(`structure-requires: "<kind> <standard id>"`) in its `profile.yml`. These
lists add up down the inheritance chain, root first, and a child removes an
inherited pair with `structure-requires-dropped`. The mapping is kept out of
standard frontmatter because frontmatter is part of the text an amendment's
`basis` hashes: changing the list there would make every amendment of that
standard STALE.
**Write with:** Task 2

### ADR-C2: Structure detectors report facts; anything but a valid report is a failed check
**Provenance:** Suggested by agent
A structure detector is a plugin script that a profile names by id. It
compares two git trees, prints one JSON report and exits 0. The report holds
`contract: 1`, the detector's id, and `facts`; each fact has a kind, units,
the repo-relative paths whose profiles govern it, and one line of evidence. An empty `facts` list is the
only way to say "nothing found". Any other exit code, missing or malformed
output, or an unknown id is a failed check, never "no structural changes".
Detectors never read standards or decide whether a change is allowed.
**Write with:** Task 4

### ADR-C3: quick-fix checks structural changes before landing, against a snapshot taken at its start
**Provenance:** Suggested by agent
At its start, quick-fix records the working state as a git tree: tracked,
staged, unstaged and untracked files. Before the ADR check and green gate, it
runs the profile-selected detectors on everything since then. Task commits
and uncommitted work are attributed to the fix; work that was already dirty
is not. Each change is governed by the profile every path it touches has
now, and by the profile that path's marker named at the start, so deleting a
folder together with its marker cannot hide its standards. What those
profiles require is always read from their current text, so a repair clears
on re-check. Any change the fix makes to the profiles themselves needs the
user's OK. Expecting a structural change while scoping only moves the standards
check earlier and hands the tasks the standards' full text. Correctness rests
on the landing check:
- a change nobody expected needs the user's OK;
- a blocked required standard stops landing;
- a failed check lands only on the user's explicit waiver.

Finding a structural change never sends the fix to plan-feature by itself. A
departure from a standard, or a choice the standards leave open, does.
**Write with:** Task 7

## Task 1: Pin the structural-change policy in the resolver tests

**Files:**
- Test: `plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1`

- [x] **Step 1 (failing tests):** In `architecture-profile.tests.ps1`, insert this block directly above the line `    # --- the shipped library ---------------------------------------------------`:
  ```powershell
      # --- structural-change policy: kinds, detectors, structure-requires ---------
      $st = New-Repo 'structure'
      $stBaseYaml = "description: Base.`nstructure-kinds:`n  - unit-added`n  - dependency-added`nstructure-requires:`n  - `"unit-added architecture/owner.md`"`n  - `"dependency-added architecture/edges.md`"`n"
      Add-Profile $st 'base' $stBaseYaml @{ 'architecture/owner.md' = (Std 'Base owner.'); 'architecture/edges.md' = (Std 'Base edges.'); 'architecture/other.md' = (Std 'Base other.') }
      Add-Profile $st 'tech' "description: Tech.`ninherits: base`nstructure-detectors:`n  - tech-detector`nstructure-requires:`n  - `"unit-added tech/layout.md`"`n" @{ 'tech/layout.md' = (Std 'Tech layout.'); 'amendments/architecture/owner.md' = (Delta 'Tech owner.' (Basis @((Std 'Base owner.')))); 'amendments/architecture/other.md' = (Delta 'Tech other.' (Basis @((Std 'Base other.')))) }
      $stRepoYaml = "description: Repo.`ninherits: tech`nstructure-kinds:`n  - code-moved`nstructure-detectors:`n  - repo-detector`n  - tech-detector`nstructure-requires-dropped:`n  - `"unit-added tech/layout.md`"`nstructure-requires:`n  - `"code-moved architecture/owner.md`"`n  - `"dependency-added repo/edges.md`"`n"
      Add-Profile $st 'repo' $stRepoYaml @{ 'repo/edges.md' = (Std 'Repo edges.') }
      Write-Fixture $st '.cogniva-profile.yml' "profile: repo`n"

      $r = Resolve-Json $st @('-Target', 'src')
      $s = $r.Json.Profiles.repo.Structure
      Check 'structure policy resolves with no warnings' ($r.Code -eq 0 -and @($r.Json.Warnings).Count -eq 0)
      Check 'structure kinds add up, root first' ((@($s.Kinds) -join ',') -eq 'unit-added,dependency-added,code-moved')
      Check 'structure detectors add up, root first, without duplicates' ((@($s.Detectors) -join ',') -eq 'tech-detector,repo-detector')
      Check 'a child adds pairs to inherited and own kinds' ((@($s.Requires.'dependency-added') -join ',') -eq 'architecture/edges.md,repo/edges.md' -and (@($s.Requires.'code-moved') -join ',') -eq 'architecture/owner.md')
      Check 'a child drops one inherited pair by name' ((@($s.Requires.'unit-added') -join ',') -eq 'architecture/owner.md')
      $r = Resolve-Json $st @('-Target', 'src', '-Profile', 'tech')
      Check 'the parent keeps the pair its child dropped' ((@($r.Json.Profiles.tech.Structure.Requires.'unit-added') -join ',') -eq 'architecture/owner.md,tech/layout.md')
      $text = Invoke-Script $resolver @('-Repo', $st, '-Target', 'src', '-LibraryRoot', $library)
      Check 'text output lists the structure policy' ($text.Out -match 'STRUCTURE DETECTORS: tech-detector, repo-detector' -and $text.Out -match 'STRUCTURE REQUIRES dependency-added: architecture/edges\.md, repo/edges\.md')

      # -Kinds feeds the -Require gate
      $r = Resolve-Json $st @('-Target', 'src', '-Kinds', 'dependency-added')
      Check '-Kinds requires the standards its kinds map to' ($r.Code -eq 0 -and (@($r.Json.Require.ByTarget[0].Standards) -join ',') -eq 'architecture/edges.md,repo/edges.md' -and @($r.Json.Require.Blocked).Count -eq 0 -and (@($r.Json.Require.Kinds) -join ',') -eq 'dependency-added')
      $text = Invoke-Script $resolver @('-Repo', $st, '-Target', 'src', '-Kinds', 'dependency-added', '-LibraryRoot', $library)
      Check '-Kinds text output lists the required standards' ($text.Code -eq 0 -and $text.Out -match 'REQUIRE: ok \(architecture/edges\.md, repo/edges\.md\)')
      $r = Resolve-Json $st @('-Target', 'src', '-Kinds', 'unit-removed')
      Check 'a kind the profile does not declare requires nothing and is reported' ($r.Code -eq 0 -and @($r.Json.Require.ByTarget[0].Standards).Count -eq 0 -and (@($r.Json.Require.ByTarget[0].UnknownKinds) -join ',') -eq 'unit-removed')
      $text = Invoke-Script $resolver @('-Repo', $st, '-Target', 'src', '-Kinds', 'unit-removed', '-LibraryRoot', $library)
      Check 'an undeclared kind prints REQUIRE ok with nothing required and a KIND NOT DECLARED line' ($text.Code -eq 0 -and $text.Out -match 'REQUIRE: ok \(no standards required\)' -and $text.Out -match 'KIND NOT DECLARED: src unit-removed \(profile repo\)')
      $r = Resolve-Json $st @('-Target', 'src', '-Kinds', 'Not_A_Kind')
      Check '-Kinds rejects a malformed kind as a usage error' ($r.Code -eq 2)

      # MIXED targets: each target keeps its own profile's list, and -Show takes that list
      Write-Fixture $st 'tools/.cogniva-profile.yml' "profile: tech`n"
      $r = Resolve-Json $st @('-Target', 'src,tools', '-Kinds', 'dependency-added')
      $bySrc = @($r.Json.Require.ByTarget | Where-Object Target -eq 'src')
      $byTools = @($r.Json.Require.ByTarget | Where-Object Target -eq 'tools')
      Check '-Kinds on MIXED targets keeps each profile''s own list' ($r.Code -eq 0 -and $bySrc.Count -eq 1 -and (@($bySrc[0].Standards) -join ',') -eq 'architecture/edges.md,repo/edges.md' -and $byTools.Count -eq 1 -and $byTools[0].Profile -eq 'tech' -and (@($byTools[0].Standards) -join ',') -eq 'architecture/edges.md')
      $text = Invoke-Script $resolver @('-Repo', $st, '-Target', 'src,tools', '-Kinds', 'dependency-added', '-LibraryRoot', $library)
      Check '-Kinds text output prints one REQUIRE FOR line per target' ($text.Code -eq 0 -and $text.Out -match 'REQUIRE FOR src \(repo\): architecture/edges\.md, repo/edges\.md' -and $text.Out -match 'REQUIRE FOR tools \(tech\): architecture/edges\.md')
      $show = Invoke-Script $resolver @('-Repo', $st, '-Target', 'tools', '-Show', 'architecture/edges.md', '-LibraryRoot', $library)
      Check '-Show with a target''s own REQUIRE FOR list succeeds' ($show.Code -eq 0 -and $show.Out -match 'SHOW architecture/edges\.md - profile tech')
      $show = Invoke-Script $resolver @('-Repo', $st, '-Target', 'tools', '-Show', 'architecture/edges.md,repo/edges.md', '-LibraryRoot', $library)
      Check '-Show with another profile''s standard in the list is a usage error' ($show.Code -eq 2)
      Remove-Item -LiteralPath (Join-Path $st 'tools') -Recurse -Force

      # only the standards a kind requires can block it
      Write-Fixture $st '.cogniva/profiles/base/standards/architecture/other.md' (Std 'Base other, changed.')
      $r = Resolve-Json $st @('-Target', 'src', '-Kinds', 'unit-added')
      Check '-Kinds passes when only an unrelated standard is stale' ($r.Code -eq 0 -and $r.Json.Targets[0].NeedsReview -eq $true)
      Write-Fixture $st '.cogniva/profiles/base/standards/architecture/other.md' (Std 'Base other.')
      Write-Fixture $st '.cogniva/profiles/base/standards/architecture/owner.md' (Std 'Base owner, changed.')
      $r = Resolve-Json $st @('-Target', 'src', '-Kinds', 'unit-added')
      Check '-Kinds exits 3 when a standard the kind requires is stale' ($r.Code -eq 3 -and @($r.Json.Require.Blocked | Where-Object { $_.Standard -eq 'architecture/owner.md' -and $_.Reason -match 'needs human review' }).Count -eq 1)
      Write-Fixture $st '.cogniva/profiles/base/standards/architecture/owner.md' (Std 'Base owner.')
      Write-Fixture $st '.cogniva/profiles/repo/profile.yml' ($stRepoYaml + "  - `"code-moved repo/missing.md`"`n")
      $r = Resolve-Json $st @('-Target', 'src', '-Kinds', 'code-moved')
      Check '-Kinds exits 3 when a kind maps to a standard the profile lacks' ($r.Code -eq 3 -and @($r.Json.Require.Blocked | Where-Object { $_.Standard -eq 'repo/missing.md' -and $_.Reason -match "not in profile 'repo'" }).Count -eq 1)
      Check 'a pair naming a missing standard is warned about' (@($r.Json.Warnings | Where-Object { $_ -match 'repo/missing\.md' }).Count -ge 1)
      Write-Fixture $st '.cogniva/profiles/repo/profile.yml' $stRepoYaml

      # malformed policy is an ERROR for the profile's targets
      Write-Fixture $st '.cogniva/profiles/repo/profile.yml' ($stRepoYaml + "  - `"code-movd architecture/owner.md`"`n")
      $r = Resolve-Json $st @('-Target', 'src')
      Check 'a pair naming an undeclared kind is an ERROR' (Test-TargetError $r "structure kind 'code-movd' is not declared")
      Write-Fixture $st '.cogniva/profiles/repo/profile.yml' ($stRepoYaml + "  - `"unit-added tech/layout.md`"`n")
      $r = Resolve-Json $st @('-Target', 'src')
      Check 'requiring and dropping one pair in one profile is an ERROR' (Test-TargetError $r 'in both structure-requires and structure-requires-dropped')
      Write-Fixture $st '.cogniva/profiles/repo/profile.yml' ($stRepoYaml + "  - `"code-moved`"`n")
      $r = Resolve-Json $st @('-Target', 'src')
      Check 'a pair without a .md standard id is an ERROR' (Test-TargetError $r "must be '<kind> <standard id>'")
      Write-Fixture $st '.cogniva/profiles/repo/profile.yml' ($stRepoYaml.Replace('  - repo-detector', '  - Repo_Detector'))
      $r = Resolve-Json $st @('-Target', 'src')
      Check 'a malformed detector id is an ERROR' (Test-TargetError $r "structure detector 'Repo_Detector' is not a valid detector id")
      Write-Fixture $st '.cogniva/profiles/repo/profile.yml' ($stRepoYaml.Replace('  - "unit-added tech/layout.md"', '  - "unit-added repo/edges.md"'))
      $r = Resolve-Json $st @('-Target', 'src')
      Check 'dropping a pair the profile does not inherit is a warning' ($r.Code -eq 0 -and @($r.Json.Warnings | Where-Object { $_ -match 'drops nothing it inherits' }).Count -eq 1)
      Write-Fixture $st '.cogniva/profiles/repo/profile.yml' $stRepoYaml

      # -Show takes a list: the full composed text of each listed standard
      $show = Invoke-Script $resolver @('-Repo', $st, '-Target', 'src', '-Show', 'architecture/owner.md,repo/edges.md', '-LibraryRoot', $library)
      $iOwner = $show.Out.IndexOf('SHOW architecture/owner.md - profile repo')
      $iEdges = $show.Out.IndexOf('SHOW repo/edges.md - profile repo')
      Check '-Show prints every listed standard in full, in the order listed' ($show.Code -eq 0 -and $iOwner -ge 0 -and $iEdges -gt $iOwner -and $show.Out -match '--- amendment from tech \(repo-owned, CURRENT\)' -and $show.Out -match '# Delta body' -and ([regex]::Matches($show.Out, '# Body')).Count -eq 2)
      $show = Invoke-Script $resolver @('-Repo', $st, '-Target', 'src', '-Show', 'architecture/owner.md,architecture/nope.md', '-LibraryRoot', $library)
      Check '-Show with one unknown standard in the list is a usage error' ($show.Code -eq 2)
  ```
- [x] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → the new checks FAIL (the profile parser rejects `structure-kinds` as an unknown key, and `-Kinds` does not exist yet); every older check still PASSES.
- [x] **Step 3 (commit):** `git add plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` then `git commit -m "test(profiles): pin the structural-change policy, -Kinds and the -Show list"`

## Task 2: Profile core — structure keys, shared target resolution, `-Kinds`, `-Show` list

**Files:**
- Modify: `plugins/cogniva-dev/scripts/profile-lib.ps1`
- Modify: `plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1`
- Test: `plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` (written in Task 1)

The keys are `structure-kinds` (kind names), `structure-detectors` (detector
ids), `structure-requires` and `structure-requires-dropped` (items
`"<kind> <standard id>"`). They compose root first. Kinds and detectors are
unioned without duplicates. At each level a profile first applies its own
`structure-requires-dropped`, which can remove only inherited pairs, then
adds its own `structure-requires`. A pair whose kind no profile in the chain
(up to and including that level) declares is an ERROR. Dropping a pair that
is not inherited is a warning. A pair naming a standard the composed profile
lacks is a warning, and `-Require` later blocks on it. `profile.yml` is not
part of any `basis` hash, so none of this affects review state.

- [x] **Step 1 (header and pattern):** In `profile-lib.ps1`, change the header line `# Dot-sourced by resolve-architecture-profile.ps1 and adopt-architecture-profile.ps1.` to:
  ```powershell
  # Dot-sourced by resolve-architecture-profile.ps1, adopt-architecture-profile.ps1
  # and check-structural-changes.ps1. Also holds the structural-change policy
  # (profile.yml structure-* keys) and the per-target resolution they share.
  ```
  and directly below `$script:ProfileIdPattern = '^[a-z0-9][a-z0-9-]*$'` add:
  ```powershell
  # Structural change kinds: lowercase letters, digits and '-', starting with a letter.
  $script:StructureKindPattern = '^[a-z][a-z0-9-]*$'
  ```
- [x] **Step 2 (pair parser):** In `profile-lib.ps1`, directly above the comment `# Returns the profile entry, $null when the folder does not exist, or throws when it is malformed.`, add:
  ```powershell
  # structure-requires and structure-requires-dropped items are
  # '<kind> <standard id>': a kind, whitespace, then a .md standard id.
  function ConvertFrom-StructurePairs([string[]]$Items, [string]$Key, [string]$Display) {
      $pairs = @()
      foreach ($item in $Items) {
          if ($item -cnotmatch '^(?<kind>[a-z][a-z0-9-]*)\s+(?<id>\S.*\.(?i:md))$') { Throw-ProfileError "${Display}: $Key item '$item' must be '<kind> <standard id>' with a .md standard id" }
          $pairs += [pscustomobject]@{ Kind = $Matches['kind']; Standard = $Matches['id'].Trim().Replace('\', '/') }
      }
      return $pairs
  }
  ```
- [x] **Step 3 (profile.yml keys):** In `Get-ProfileEntry`, replace the line
  `    $data = Read-CognivaYamlFile $file @('description', 'inherits', 'detect') @('description') $display`
  with
  `    $data = Read-CognivaYamlFile $file @('description', 'inherits', 'detect', 'structure-kinds', 'structure-detectors', 'structure-requires', 'structure-requires-dropped') @('description') $display`
  then replace the whole `$entry = [pscustomobject]@{ ... }` assignment (the five lines from `    $entry = [pscustomobject]@{` to its closing `    }`) with:
  ```powershell
      $kinds = @(if ($data.Contains('structure-kinds')) { $data['structure-kinds'] })
      foreach ($k in $kinds) { if ($k -cnotmatch $script:StructureKindPattern) { Throw-ProfileError "${display}: structure kind '$k' is not valid (lowercase letters, digits and '-', starting with a letter)" } }
      $detectors = @(if ($data.Contains('structure-detectors')) { $data['structure-detectors'] })
      foreach ($d in $detectors) { if ($d -cnotmatch $script:ProfileIdPattern) { Throw-ProfileError "${display}: structure detector '$d' is not a valid detector id (lowercase letters, digits and '-')" } }
      $requires = @(ConvertFrom-StructurePairs @(if ($data.Contains('structure-requires')) { $data['structure-requires'] }) 'structure-requires' $display)
      $dropped = @(ConvertFrom-StructurePairs @(if ($data.Contains('structure-requires-dropped')) { $data['structure-requires-dropped'] }) 'structure-requires-dropped' $display)
      foreach ($p in $dropped) {
          if (@($requires | Where-Object { $_.Kind -ceq $p.Kind -and $_.Standard -ieq $p.Standard }).Count) { Throw-ProfileError "${display}: '$($p.Kind) $($p.Standard)' is in both structure-requires and structure-requires-dropped; keep one" }
      }
      $entry = [pscustomobject]@{
          Id = $Id; Path = $dir; Display = "$($Source.Display)/$Id"
          Description = $data['description']; Inherits = $inherits
          Detect = if ($data.Contains('detect')) { @($data['detect']) } else { @() }
          StructureKinds = $kinds; StructureDetectors = $detectors; StructureRequires = $requires; StructureDropped = $dropped
      }
  ```
- [x] **Step 4 (compose the policy):** In `profile-lib.ps1`, directly above the comment `# Directories from the target's nearest existing directory up to the repo root, nearest first.`, add:
  ```powershell
  # The chain's structural-change policy, root ancestor first: kinds and detectors
  # are unioned; at each level the profile's structure-requires-dropped removes
  # inherited pairs, then its structure-requires adds pairs. Every pair's kind must
  # be declared at that level or above. Returns { Kinds, Detectors, Requires }
  # where Requires maps each kind to its standard ids (root first).
  function Get-EffectiveStructure([string[]]$Chain, $Source, [object[]]$Standards, [System.Collections.Generic.List[string]]$Warnings) {
      $kinds = [System.Collections.Generic.List[string]]::new()
      $detectors = [System.Collections.Generic.List[string]]::new()
      $pairs = [System.Collections.Generic.List[object]]::new()
      for ($c = $Chain.Count - 1; $c -ge 0; $c--) {
          $entry = Get-ProfileEntry $Source $Chain[$c]
          foreach ($k in $entry.StructureKinds) { if (-not $kinds.Contains($k)) { $kinds.Add($k) } }
          foreach ($d in $entry.StructureDetectors) { if (-not $detectors.Contains($d)) { $detectors.Add($d) } }
          foreach ($p in @($entry.StructureRequires) + @($entry.StructureDropped)) {
              if (-not $kinds.Contains($p.Kind)) { Throw-ProfileError "$($entry.Display)/profile.yml: structure kind '$($p.Kind)' is not declared by structure-kinds in this profile or an ancestor" }
          }
          foreach ($p in $entry.StructureDropped) {
              $hits = @($pairs | Where-Object { $_.Kind -ceq $p.Kind -and $_.Standard -ieq $p.Standard })
              if (-not $hits.Count) { $Warnings.Add("$($entry.Display)/profile.yml: structure-requires-dropped '$($p.Kind) $($p.Standard)' drops nothing it inherits") }
              foreach ($h in $hits) { [void]$pairs.Remove($h) }
          }
          foreach ($p in $entry.StructureRequires) {
              if (@($pairs | Where-Object { $_.Kind -ceq $p.Kind -and $_.Standard -ieq $p.Standard }).Count) { continue }
              $pairs.Add([pscustomobject]@{ Kind = $p.Kind; Standard = $p.Standard; From = $entry.Id })
          }
      }
      foreach ($p in $pairs) {
          if (-not @($Standards | Where-Object { $_.Id -ieq $p.Standard }).Count) { $Warnings.Add("profile '$($Chain[0])': structure-requires '$($p.Kind) $($p.Standard)' (from $($p.From)) names a standard the profile does not provide; a $($p.Kind) change is blocked until it does") }
      }
      $requires = [ordered]@{}
      foreach ($k in $kinds) { $requires[$k] = @($pairs | Where-Object Kind -ceq $k | ForEach-Object Standard) }
      return [pscustomobject]@{ Kinds = @($kinds); Detectors = @($detectors); Requires = $requires }
  }
  ```
- [x] **Step 5 (shared resolution):** Append to the end of `profile-lib.ps1`:
  ```powershell
  # --- per-target resolution, shared by the resolver and the structural check ---

  function Get-ProfileErrorText($ErrorRecord) { return ($ErrorRecord.Exception.Message -replace '^ProfileError: ', '') }

  # One resolution run: the repo's profiles, the library, the warnings, and each
  # profile id's result, computed once and shared by every target that uses it.
  function New-ResolutionContext([string]$RepoFull, [string]$LibraryRoot) {
      return [pscustomobject]@{
          RepoFull = $RepoFull
          RepoProfiles = New-ProfileSource (Join-Path $RepoFull $script:RepoProfilesRelative) $script:RepoProfilesRelative (Join-Path $RepoFull $script:AdoptedRelative)
          Library = New-ProfileSource $LibraryRoot 'plugin-library' $null -IsLibrary
          LibraryEntries = $null
          Results = @{}
          Warnings = [System.Collections.Generic.List[string]]::new()
      }
  }

  # Chain, effective standards and structure policy for one profile id. A success
  # is cached and shared; a failure is recomputed per target so its message names
  # that target's own marker.
  function Get-ContextProfileResult($Ctx, [string]$Id, [string]$Origin) {
      if ($Ctx.Results.ContainsKey($Id)) { return $Ctx.Results[$Id] }
      try {
          $chain = Resolve-ProfileChain $Id $Ctx.RepoProfiles $Ctx.Library $Origin
          $effective = Get-EffectiveStandards $chain $Ctx.RepoProfiles $Ctx.Warnings
          $structure = Get-EffectiveStructure $chain $Ctx.RepoProfiles @($effective.Standards) $Ctx.Warnings
          $result = [pscustomobject]@{
              Error = $null; Chain = @($chain); Description = (Get-ProfileEntry $Ctx.RepoProfiles $Id).Description
              Effective = $effective; Standards = @($effective.Standards); Review = @($effective.Review); Structure = $structure
              ChainDetail = @($chain | ForEach-Object { [pscustomobject]@{ Id = $_; Ownership = (Get-ProfileOwnership $Ctx.RepoProfiles $_) } })
          }
      }
      catch { return [pscustomobject]@{ Error = (Get-ProfileErrorText $_); Chain = @(); Description = $null; Standards = @(); Review = @(); Structure = $null; ChainDetail = @() } }
      $Ctx.Results[$Id] = $result
      return $result
  }

  # One target's resolution report: Target, Status (RESOLVED | NONE | UNDECLARED |
  # ERROR), Profile, Error, Winner, Considered, Suggestion, NeedsReview, MatchedStandards.
  function Resolve-TargetProfile($Ctx, [string]$Full, [string]$ExplicitProfile) {
      $relative = Get-RelativeDisplay $Ctx.RepoFull $Full
      $considered = @()
      $winner = $null
      $suggestion = $null
      $status = 'UNDECLARED'
      $profileId = $null
      $errorText = $null
      try {
          $walk = Get-DirectoryWalk $Ctx.RepoFull $Full
          # An explicit profile beats every marker, malformed ones included: they are
          # recorded as overridden and reported as warnings, never as the target's error.
          $markers = Get-ProfileMarkers $Ctx.RepoFull $walk -Tolerant:([bool]$ExplicitProfile)
          if ($ExplicitProfile) {
              $winner = [pscustomobject]@{ Kind = 'explicit'; Source = '-Profile'; Profile = $ExplicitProfile }
              foreach ($m in $markers) {
                  $considered += [pscustomobject]@{ Kind = $m.Kind; Source = $m.Source; Profile = $m.Profile; Outcome = 'overridden-by-explicit' }
                  if ($m.Error) { $Ctx.Warnings.Add("$($m.Error) (overridden by -Profile)") }
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
              $result = Get-ContextProfileResult $Ctx $winner.Profile $winner.Source
              if ($result.Error) { $status = 'ERROR'; $errorText = $result.Error }
              else { $status = 'RESOLVED'; $profileId = $winner.Profile }
          }
          else {
              if ($null -eq $Ctx.LibraryEntries) { $Ctx.LibraryEntries = @(Get-AllProfileEntries $Ctx.Library $Ctx.Warnings) }
              $suggestion = Get-ProfileSuggestion $Ctx.RepoFull $walk $Ctx.LibraryEntries
          }
      }
      catch { $status = 'ERROR'; $errorText = Get-ProfileErrorText $_ }

      # NeedsReview: the resolved profile has any delta awaiting human review.
      # MatchedStandards: standards whose applies-to globs match this target.
      $needsReview = $false
      $matched = @()
      if ($status -eq 'RESOLVED') {
          $resolved = $Ctx.Results[$profileId]
          $needsReview = @($resolved.Review).Count -gt 0
          $matched = @($resolved.Standards | Where-Object { @($_.AppliesTo | Where-Object { Test-GlobMatch $_ $relative }).Count -gt 0 } | ForEach-Object Id)
      }
      return [pscustomobject]@{
          Target = $relative; Status = $status; Profile = $profileId; Error = $errorText
          Winner = if ($winner) { [pscustomobject]@{ Kind = $winner.Kind; Source = $winner.Source } } else { $null }
          Considered = @($considered); Suggestion = $suggestion
          NeedsReview = $needsReview; MatchedStandards = @($matched)
      }
  }

  # The -Require gate. For each RESOLVED target the required set is $Ids plus every
  # standard its profile's structure-requires maps one of $Kinds to. A required
  # standard blocks when the profile lacks it or it needs human review; review
  # items on other standards never block. UnknownKinds: listed kinds the profile
  # does not declare (they require nothing). Returns { ByTarget, Blocked }.
  function Get-RequireResult($Ctx, [object[]]$Targets, [string[]]$Ids, [string[]]$Kinds) {
      $Ids = @($Ids | Where-Object { $_ })
      $Kinds = @($Kinds | Where-Object { $_ })
      $byTarget = @()
      $blocked = @()
      foreach ($t in @($Targets | Where-Object Status -eq 'RESOLVED')) {
          $p = $Ctx.Results[$t.Profile]
          $wanted = [System.Collections.Generic.List[string]]::new()
          $candidates = @($Ids) + @($Kinds | ForEach-Object { if ($p.Structure.Requires.Contains($_)) { $p.Structure.Requires[$_] } })
          foreach ($id in $candidates) { if ($id -and -not @($wanted | Where-Object { $_ -ieq $id }).Count) { $wanted.Add($id) } }
          $byTarget += [pscustomobject]@{ Target = $t.Target; Profile = $t.Profile; Standards = @($wanted); UnknownKinds = @($Kinds | Where-Object { @($p.Structure.Kinds) -cnotcontains $_ }) }
          foreach ($id in $wanted) {
              $s = @($p.Standards | Where-Object { $_.Id -ieq $id }) | Select-Object -First 1
              $reason = if (-not $s) { "not in profile '$($t.Profile)'" }
              elseif ($s.NeedsReview) { 'needs human review: ' + (@($s.Parts | Where-Object { $_.State -and $_.State -ne 'CURRENT' } | ForEach-Object { "$($_.From) $($_.Role) $($_.State)" }) -join '; ') }
              else { $null }
              if ($reason) { $blocked += [pscustomobject]@{ Target = $t.Target; Profile = $t.Profile; Standard = $id; Reason = $reason } }
          }
      }
      return [pscustomobject]@{ ByTarget = @($byTarget); Blocked = @($blocked) }
  }
  ```
- [x] **Step 6 (resolver):** Replace the whole content of `plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1` with:
  ```powershell
  #Requires -Version 7.0
  # Resolve the architecture profile for one or more target paths, explain why it
  # won, and list the index of standards it provides. Read-only.
  # Precedence per target: -Profile, then the nearest .cogniva-profile.yml marker,
  # then the repo-root marker. Profiles are read only from <repo>/.cogniva/profiles;
  # the plugin library (-LibraryRoot) is consulted only for suggestions and hints.
  # Each target resolves independently: a broken marker or profile marks only the
  # targets that use it as ERROR.
  # Standards compose root ancestor first: standards/ adds new ids, amendments/<id>
  # layers onto the inherited text, replacements/<id> supersedes it (flagged as
  # REPLACED). Each amendment or replacement records the inherited text it was
  # reviewed against (basis:); one that is UNREVIEWED, STALE or ORPHANED still
  # applies but is listed under Review, and the target is marked NeedsReview
  # (text: NEEDS HUMAN REVIEW). Review state alone never changes the exit code.
  # Each profile also reports its structural-change policy (profile.yml
  # structure-kinds, structure-detectors, structure-requires), composed root first.
  # -Show <id,...> prints the effective text of the listed standards for exactly
  # one target, each part (the standard, then every amendment, root first) under a
  # provenance line; it is text-only (not with -Format Json).
  # -Require <id,...> is the gate for an architecture-dependent change: a listed
  # standard that a RESOLVED target's profile lacks, or that needs human review,
  # blocks (JSON: Require.Blocked; text: REQUIRE BLOCKED). -Kinds <kind,...> adds,
  # per RESOLVED target, every standard its profile's structure-requires maps those
  # kinds to. Unlisted stale standards never block.
  # Exit 0 = every target resolved (including MIXED / UNDECLARED); 1 = the report
  # was produced but at least one target is ERROR (or -Show's target is not
  # RESOLVED); 3 = a required standard is missing or needs human review;
  # 2 = usage error, nothing reported. Precedence: 2 > 1 > 3 > 0.
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)][string]$Repo,
      [Parameter(Mandatory)][string[]]$Target,
      [string]$Profile,
      [string]$LibraryRoot,
      [ValidateSet('Text', 'Json')][string]$Format = 'Text',
      [string[]]$Show,
      [string[]]$Require,
      [string[]]$Kinds
  )
  $ErrorActionPreference = 'Stop'
  . (Join-Path $PSScriptRoot 'profile-lib.ps1')

  function Fail([string]$Message) { [Console]::Error.WriteLine("architecture-profile: $Message"); exit 2 }

  try {
      if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
      $repoFull = (Get-Item -LiteralPath $Repo).FullName.TrimEnd('\', '/')
      if (-not $LibraryRoot) { $LibraryRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'profiles' }
      if ($Profile) { Assert-ProfileId $Profile '-Profile' }

      $requested = @($Target | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().Trim("'").Trim('"') } | Where-Object { $_ })
      if (-not $requested.Count) { Fail 'no target supplied' }
      $showIds = @($Show | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ })
      if ($showIds.Count -and $Format -eq 'Json') { Fail '-Show prints text; do not combine it with -Format Json' }
      if ($showIds.Count -and $requested.Count -gt 1) { Fail '-Show takes exactly one target' }
      $requireIds = @($Require | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ })
      $kindIds = @($Kinds | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
      foreach ($k in $kindIds) { if ($k -cnotmatch $script:StructureKindPattern) { Fail "-Kinds: '$k' is not a valid structure kind" } }
      $fullTargets = @()
      foreach ($raw in $requested) {
          $full = if ([System.IO.Path]::IsPathRooted($raw)) { [System.IO.Path]::GetFullPath($raw) } else { [System.IO.Path]::GetFullPath((Join-Path $repoFull $raw)) }
          if (-not (Test-PathInside $repoFull $full)) { Fail "target is outside repo: $raw" }
          $fullTargets += $full
      }
  }
  catch { Fail (Get-ProfileErrorText $_) }

  $ctx = New-ResolutionContext $repoFull $LibraryRoot
  $targets = @(foreach ($full in $fullTargets) { Resolve-TargetProfile $ctx $full $Profile })

  if ($showIds.Count) {
      $t = $targets[0]
      if ($t.Status -ne 'RESOLVED') { Write-Output "architecture-profile: $($t.Target) has no resolved profile ($($t.Status))"; exit 1 }
      $result = $ctx.Results[$t.Profile]
      $picked = @()
      foreach ($wanted in $showIds) {
          $s = @($result.Standards | Where-Object { $_.Id -ieq $wanted }) | Select-Object -First 1
          if (-not $s) { Fail "standard '$wanted' is not in profile '$($t.Profile)'" }
          $picked += $s
      }
      for ($i = 0; $i -lt $picked.Count; $i++) {
          $s = $picked[$i]
          if ($i -gt 0) { Write-Output '' }
          Write-Output "SHOW $($s.Id) - profile $($t.Profile) (chain: $($result.Chain -join ' -> '))"
          if ($s.NeedsReview) { Write-Output 'NEEDS HUMAN REVIEW' }
          foreach ($part in $s.Parts) {
              $state = if ($part.State) { ", $($part.State)" } else { '' }
              Write-Output ''
              Write-Output "--- $($part.Role) from $($part.From) ($($part.Ownership)$state): $($part.Display)"
              Write-Output ([System.IO.File]::ReadAllText($part.Path).TrimEnd())
          }
      }
      exit 0
  }

  # -Require / -Kinds: a required standard blocks when a RESOLVED target's profile
  # lacks it or it needs human review. Review items on other standards never block.
  $gateRun = ($requireIds.Count -gt 0 -or $kindIds.Count -gt 0)
  $gate = if ($gateRun) { Get-RequireResult $ctx $targets $requireIds $kindIds } else { $null }
  # @(if ...) - an if statement's output turns an empty array into $null.
  $blocked = @(if ($gate) { $gate.Blocked })

  $profiles = [ordered]@{}
  foreach ($id in @($targets | Where-Object Status -eq 'RESOLVED' | ForEach-Object Profile | Sort-Object -Unique)) {
      $r = $ctx.Results[$id]
      # Parts (the composition inputs) stay internal; they never reach the report.
      $profiles[$id] = [pscustomobject]@{
          Chain = $r.Chain; ChainDetail = $r.ChainDetail; Description = $r.Description
          Standards = @($r.Standards | Select-Object Id, Description, From, Overrides, Path, ReplacedBy, Amendments, AppliesTo, NeedsReview)
          Review = $r.Review
          Structure = $r.Structure
      }
  }

  $groups = [ordered]@{}
  foreach ($t in $targets) {
      $key = switch ($t.Status) { 'RESOLVED' { $t.Profile } 'NONE' { '(none)' } 'ERROR' { '(error)' } default { '(undeclared)' } }
      if (-not $groups.Contains($key)) { $groups[$key] = @() }
      $groups[$key] += $t.Target
  }
  $aggregate = if ($groups.Contains('(error)')) { 'ERROR' } elseif ($groups.Count -gt 1) { 'MIXED' } elseif ($groups.Contains('(undeclared)')) { 'UNDECLARED' } else { 'UNIFORM' }
  $exitCode = if ($aggregate -eq 'ERROR') { 1 } elseif ($blocked.Count) { 3 } else { 0 }

  $report = [pscustomobject]@{
      Repo = $repoFull; ReadOnly = $true; ExplicitProfile = if ($Profile) { $Profile } else { $null }
      Targets = @($targets)
      Aggregate = [pscustomobject]@{ Status = $aggregate; Groups = $groups }
      Profiles = $profiles
      Warnings = @($ctx.Warnings | Select-Object -Unique)
  }
  if ($gateRun) { $report | Add-Member -NotePropertyName Require -NotePropertyValue ([pscustomobject]@{ Standards = $requireIds; Kinds = $kindIds; ByTarget = @($gate.ByTarget); Blocked = $blocked }) }

  if ($Format -eq 'Json') { $report | ConvertTo-Json -Depth 10; exit $exitCode }

  Write-Output "architecture-profile: read-only resolution for $repoFull"
  foreach ($t in $report.Targets) {
      Write-Output ''
      Write-Output "Target: $($t.Target)"
      switch ($t.Status) {
          'RESOLVED' {
              Write-Output "  PROFILE: $($t.Profile) ($($t.Winner.Kind): $($t.Winner.Source))"
              if ($t.NeedsReview) { Write-Output '  NEEDS HUMAN REVIEW' }
          }
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
          Write-Output "  STANDARD $($s.Id) [$($s.From)] - $($s.Description)"
          Write-Output "    $($s.Path)"
          if ($s.ReplacedBy -and @($s.Overrides).Count) { Write-Output "    REPLACED - no longer receives $(@($s.Overrides)[-1]) updates" }
          foreach ($a in $s.Amendments) { Write-Output "    AMENDED BY $($a.From) ($($a.Ownership), $($a.State)): $($a.Path)" }
          if (@($s.AppliesTo).Count) { Write-Output "    APPLIES TO: $($s.AppliesTo -join ', ')" }
      }
      if (@($p.Structure.Detectors).Count) { Write-Output "  STRUCTURE DETECTORS: $(@($p.Structure.Detectors) -join ', ')" }
      foreach ($k in @($p.Structure.Requires.Keys)) {
          $mapped = @($p.Structure.Requires[$k])
          if ($mapped.Count) { Write-Output "  STRUCTURE REQUIRES $($k): $($mapped -join ', ')" }
      }
      foreach ($i in $p.Review) {
          $basisShown = if ($i.Basis) { $i.Basis } else { 'none' }
          $inheritedShown = if ($i.Inherited) { $i.Inherited } else { 'n/a' }
          Write-Output "  REVIEW: $($i.Standard) - $($i.Profile) ($($i.Ownership)) $($i.Delta) is $($i.State) (basis $basisShown -> $inheritedShown)"
      }
  }
  if ($gateRun) {
      if ($blocked.Count) { foreach ($b in $blocked) { Write-Output "REQUIRE BLOCKED: $($b.Target) $($b.Standard) - $($b.Reason)" } }
      else {
          $shownIds = [System.Collections.Generic.List[string]]::new()
          $source = if ($kindIds.Count) { @($gate.ByTarget | ForEach-Object { $_.Standards }) } else { $requireIds }
          foreach ($id in $source) { if ($id -and -not @($shownIds | Where-Object { $_ -ieq $id }).Count) { $shownIds.Add($id) } }
          $listed = if ($shownIds.Count) { $shownIds -join ', ' } else { 'no standards required' }
          Write-Output "REQUIRE: ok ($listed)"
          # Per target, so a caller can -Show each profile's own list (MIXED targets differ).
          foreach ($bt in @($gate.ByTarget)) {
              $own = if (@($bt.Standards).Count) { @($bt.Standards) -join ', ' } else { 'no standards required' }
              Write-Output "REQUIRE FOR $($bt.Target) ($($bt.Profile)): $own"
          }
      }
      foreach ($bt in @($gate.ByTarget)) { foreach ($k in @($bt.UnknownKinds)) { Write-Output "KIND NOT DECLARED: $($bt.Target) $k (profile $($bt.Profile))" } }
  }
  foreach ($w in $report.Warnings) { Write-Output "WARN: $w" }
  exit $exitCode
  ```
- [x] **Step 7 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → `All architecture-profile assertions passed.` Then confirm the refactor changed nothing for existing callers: `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` → `All profile-library assertions passed.`; `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1` → all PASS (it calls the resolver as a process and reads its JSON).
- [x] **Step 8 (write ADR):** scan `docs/adr/` for the next number and write ADR-C1 from `## Candidate ADRs` verbatim to `docs/adr/NNNN-profiles-map-structural-change-kinds-in-profile-yml.md` per the adr skill's ADR-FORMAT (heading = the title; `**Provenance:** Suggested by agent`; no Relitigation line; the body paragraph).
- [x] **Step 9 (commit):** `git add plugins/cogniva-dev/scripts/profile-lib.ps1 plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1 docs/adr/` then `git commit -m "feat(profiles): structural-change policy in profile.yml, -Kinds and a -Show list"`

## Task 3: Structure library and the `dotnet-projects` detector

**Files:**
- Create: `plugins/cogniva-dev/scripts/structure-lib.ps1`
- Create: `plugins/cogniva-dev/scripts/structure-detectors/dotnet-projects.ps1`
- Test: `plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1`

Detector contract 1: the detector runs as `pwsh -NoProfile -File <script>
-Repo <repo top level> -Base <tree> -Head <tree>`. It exits 0 and prints one
JSON object, `{ "contract": 1, "detector": "<id>", "facts": [ ... ] }`. Each
fact has `kind`, `units` (one or more strings), `paths` and `evidence` (one
non-empty line). `paths` holds one or more repo-relative `/` paths: every
path the fact is about, because the profile of each one governs it. `facts:
[]` means nothing found; any other outcome is a failure. Detectors report
facts only: they never read a profile or a standard.

In `dotnet-projects` a unit is a project file (`*.csproj`, `*.fsproj`,
`*.vbproj`). A file belongs to the project in its nearest ancestor folder
that holds one; with several project files in one folder, the first in sorted
order is used. The governing paths of each fact:

| Fact | `paths` |
|---|---|
| unit added or removed | the project file |
| reference in a project file | the project file, plus the referenced project when the `Include` is literal |
| reference in a `Directory.Build.props`/`.targets` | that file, every project file under its folder, plus the referenced project when literal |
| code moved | the old and new path of every moved file |

A move is caught in two cases:
- git pairs the delete and the add as a rename (their contents are at least half the same);
- a file is deleted from one project and a file with the same name is added to another. This is reported as a *possible* move.

A move that also renames the file *and* changes most of its content is not
caught.

- [x] **Step 1 (failing tests):** Create `plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1`:
  ```powershell
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
  ```
- [x] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1` → it stops with an error: `structure-lib.ps1` does not exist yet.
- [x] **Step 3 (implement the library):** Create `plugins/cogniva-dev/scripts/structure-lib.ps1`:
  ```powershell
  #Requires -Version 7.0
  # Structural-change core: snapshot the working state as a git tree, list the
  # changes between two trees, read files from a tree, and write a detector's
  # report. Writes git objects only - never refs, the index or the working tree.
  # Dot-sourced by check-structural-changes.ps1 and by every structure detector.
  # Every failure throws a StructureError naming what failed.

  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

  function Invoke-StructureGit([string]$Repo, [string[]]$Arguments) {
      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try {
          $out = @(& git -C $Repo -c core.safecrlf=false -c core.quotepath=false @Arguments 2>$null)
          $code = $LASTEXITCODE
      }
      finally { $ErrorActionPreference = $previous }
      if ($code -ne 0) { throw [System.InvalidOperationException]::new("StructureError: git $($Arguments -join ' ') failed (exit $code) in $Repo") }
      return $out
  }

  # The working state as a tree: tracked, staged, unstaged and untracked files
  # (.gitignore'd files left out). A copy of the index is used, so the real
  # index and the working tree are never touched.
  function Get-WorkingTreeSnapshot([string]$Repo) {
      $index = (@(Invoke-StructureGit $Repo @('rev-parse', '--git-path', 'index')) | Select-Object -First 1).Trim()
      if (-not [System.IO.Path]::IsPathRooted($index)) { $index = Join-Path $Repo $index }
      $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-structure-" + [guid]::NewGuid().ToString('N') + '.index')
      $previous = $env:GIT_INDEX_FILE
      try {
          if (Test-Path -LiteralPath $index -PathType Leaf) { Copy-Item -LiteralPath $index -Destination $tmp }
          $env:GIT_INDEX_FILE = $tmp
          Invoke-StructureGit $Repo @('add', '-A') | Out-Null
          $tree = (@(Invoke-StructureGit $Repo @('write-tree')) | Select-Object -First 1)
      }
      finally {
          if ($null -eq $previous) { Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue } else { $env:GIT_INDEX_FILE = $previous }
          Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
          Remove-Item -LiteralPath "$tmp.lock" -Force -ErrorAction SilentlyContinue
      }
      if ("$tree".Trim() -notmatch '^[0-9a-f]{40,64}$') { throw [System.InvalidOperationException]::new("StructureError: git write-tree returned no tree for $Repo") }
      return "$tree".Trim()
  }

  # The tree of a commit or tree.
  function Resolve-StructureTree([string]$Repo, [string]$Revision) {
      $tree = $null
      try { $tree = (@(Invoke-StructureGit $Repo @('rev-parse', '--verify', '--quiet', "$Revision^{tree}")) | Select-Object -First 1) }
      catch { throw [System.InvalidOperationException]::new("StructureError: '$Revision' is not a commit or tree in $Repo") }
      return "$tree".Trim()
  }

  # Every path that differs between two trees, renames paired:
  # @({ Status = 'A'|'D'|'M'|'T'|'R'; Path; OldPath }). OldPath is set only for R.
  function Get-TreeChanges([string]$Repo, [string]$Base, [string]$Head) {
      $raw = (@(Invoke-StructureGit $Repo @('diff-tree', '-r', '-M', '--name-status', '-z', $Base, $Head))) -join "`n"
      $tokens = @($raw.Split([char]0) | Where-Object { $_ -ne '' })
      $changes = @()
      for ($i = 0; $i -lt $tokens.Count; $i++) {
          $letter = $tokens[$i].Substring(0, 1)
          if ($letter -eq 'R' -or $letter -eq 'C') {
              $changes += [pscustomobject]@{ Status = $letter; OldPath = $tokens[$i + 1]; Path = $tokens[$i + 2] }
              $i += 2
          }
          else {
              $changes += [pscustomobject]@{ Status = $letter; OldPath = $null; Path = $tokens[$i + 1] }
              $i += 1
          }
      }
      return $changes
  }

  # Every file path in a tree.
  function Get-TreePaths([string]$Repo, [string]$Tree) {
      $raw = (@(Invoke-StructureGit $Repo @('ls-tree', '-r', '--name-only', '-z', $Tree))) -join "`n"
      return @($raw.Split([char]0) | Where-Object { $_ -ne '' })
  }

  # The text of $Path in $Tree, or $null when the tree has no such file.
  function Get-TreeFileText([string]$Repo, [string]$Tree, [string]$Path) {
      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try {
          $lines = @(& git -C $Repo cat-file -p "${Tree}:$Path" 2>$null)
          $code = $LASTEXITCODE
      }
      finally { $ErrorActionPreference = $previous }
      if ($code -ne 0) { return $null }
      return ($lines -join "`n")
  }

  function New-StructureFact([string]$Kind, [string[]]$Units, [string[]]$Paths, [string]$Evidence) {
      return [pscustomobject]@{ kind = $Kind; units = @($Units); paths = @($Paths); evidence = $Evidence }
  }

  # A detector's contract-1 report, facts in a stable order.
  function Write-DetectorReport([string]$Detector, [object[]]$Facts) {
      $sorted = @($Facts | Sort-Object -Property @{ Expression = { $_.kind } }, @{ Expression = { $_.units -join '|' } }, @{ Expression = { $_.paths -join '|' } })
      return ([pscustomobject]@{ contract = 1; detector = $Detector; facts = $sorted } | ConvertTo-Json -Depth 6)
  }
  ```
- [x] **Step 4 (implement the detector):** Create `plugins/cogniva-dev/scripts/structure-detectors/dotnet-projects.ps1`:
  ```powershell
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
  ```
- [x] **Step 5 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1` → `All structural-changes assertions passed.`
- [x] **Step 6 (commit):** `git add plugins/cogniva-dev/scripts/structure-lib.ps1 plugins/cogniva-dev/scripts/structure-detectors/dotnet-projects.ps1 plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1` then `git commit -m "feat(structure): working-tree snapshot and the dotnet-projects structure detector"`

## Task 4: `check-structural-changes.ps1` and the green gate

**Files:**
- Create: `plugins/cogniva-dev/scripts/check-structural-changes.ps1`
- Modify: `plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1`
- Modify: `.claude/cogniva-dev/green-gate.json`

Statuses and exits:

| Status | Exit |
|---|---|
| `NONE` | 0 |
| `NOT-CHECKED` | 0 |
| `FAILED` | 1 |
| usage error | 2 |
| `BLOCKED` | 3 |
| `FOUND` | 4 |

Precedence is 2 > 1 > 3 > 4 > 0.

Rules the script implements:
- **Detector selection.** It runs every detector selected by any profile
  that a marker in the repo declares, at the start or now, not only the
  changed paths' profiles. A change in a parent folder, such as a shared
  `Directory.Build.props`, can affect units governed by markers below it.
- **Broken profiles.** If any declared profile is in ERROR, the result is
  `FAILED`, even for an ordinary edit. The script cannot know which detectors
  that profile would select, so it cannot claim there is nothing to check.
- **Which profiles govern a fact.** A fact is governed by the profile each of
  its `paths` has now. If the fix changed any `.cogniva-profile.yml` or
  anything under `.cogniva/`, it is also governed by the profile that path's
  nearest marker named at the start, read from the start tree. That way,
  deleting a folder together with its marker cannot drop the standards that
  governed the change. When no such file changed, the markers are the same
  as at the start, so ordinary fixes pay nothing for this.
- **What those profiles require** always comes from the profiles as they are
  now, at the start as well as now: the mapping, whether each standard
  exists, and its review state. Adding a missing standard or accepting a
  reviewed amendment therefore clears the block on re-check. A profile named
  at the start that no longer exists is `FAILED`, which can be waived.
- **Profile edits.** Any change to profile files since the start becomes a
  `profile-changed` fact. It is always `UNEXPECTED` and so needs the user's
  OK. That keeps a fix from quietly weakening the standards its own changes
  are checked against; if the user made the edit as a repair, the OK is a
  formality.
- **`-Expected`.** Items are `<kind>:<path>[|<path>...]`, comma-separated. A
  fact is expected only when an item of its kind has paths containing every
  one of the fact's paths. Anything else is `UNEXPECTED`. An item without
  paths is a usage error.

- [x] **Step 1 (failing tests):** In `structural-changes.tests.ps1`, insert directly above `      # --- sections appended by later tasks go above this line ---`:
  ```powershell
      # --- check-structural-changes.ps1 -----------------------------------------
      function Add-RepoProfile([string]$Repo, [string]$Id, [string]$Yaml, [hashtable]$Files) {
          Write-Fixture $Repo ".cogniva/profiles/$Id/profile.yml" $Yaml
          foreach ($key in $Files.Keys) {
              $relative = if ($key -match '^(amendments|replacements)/') { $key } else { "standards/$key" }
              Write-Fixture $Repo ".cogniva/profiles/$Id/$relative" $Files[$key]
          }
      }
      function Std([string]$Description) { return "---`ndescription: $Description`n---`n`n# Body`n" }
      function Delta([string]$Description, [string]$Basis) { return "---`ndescription: $Description`nbasis: $Basis`n---`n`n# Delta body`n" }
      function Basis([string[]]$Texts) { return Get-TextHash ((@($Texts | ForEach-Object { Get-NormalisedText $_ })) -join "`n") }
      function Start-Tree([string]$Repo) {
          $s = Invoke-Script $checker @('-Repo', $Repo, '-Snapshot')
          if ($s.Code -ne 0 -or $s.Out -notmatch 'START_TREE: ([0-9a-f]{40,64})') { throw "snapshot failed: $($s.All)" }
          return $Matches[1]
      }
      function Check-Changes([string]$Repo, [string]$Start, [string[]]$Extra = @()) {
          $r = Invoke-Script $checker (@('-Repo', $Repo, '-Since', $Start, '-Format', 'Json') + $Extra)
          $json = $null
          if ($r.Code -in 0, 1, 3, 4) { try { $json = $r.Out | ConvertFrom-Json } catch { $json = $null } }
          [pscustomobject]@{ Code = $r.Code; Json = $json; All = $r.All }
      }
      function Check-Text([string]$Repo, [string]$Start, [string[]]$Extra = @()) { return Invoke-Script $checker (@('-Repo', $Repo, '-Since', $Start) + $Extra) }

      $c = New-GitRepo 'checker'
      $baseYaml = "description: Base.`nstructure-kinds:`n  - unit-added`n  - unit-removed`n  - dependency-added`n  - dependency-removed`n  - code-moved`nstructure-requires:`n  - `"unit-added architecture/owner.md`"`n  - `"dependency-added architecture/edges.md`"`n"
      Add-RepoProfile $c 'base' $baseYaml @{ 'architecture/owner.md' = (Std 'Base owner.'); 'architecture/edges.md' = (Std 'Base edges.'); 'architecture/other.md' = (Std 'Base other.') }
      $techYaml = "description: Tech.`ninherits: base`nstructure-detectors:`n  - dotnet-projects`nstructure-requires:`n  - `"dependency-added tech/refs.md`"`n"
      Add-RepoProfile $c 'tech' $techYaml @{ 'tech/refs.md' = (Std 'Tech refs.'); 'amendments/architecture/owner.md' = (Delta 'Tech owner.' (Basis @((Std 'Base owner.')))); 'amendments/architecture/other.md' = (Delta 'Tech other.' (Basis @((Std 'Base other.')))) }
      Add-RepoProfile $c 'nodetector' "description: No detector.`ninherits: base`n" @{}
      Write-Fixture $c '.cogniva-profile.yml' "profile: tech`n"
      Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj'))
      Write-Fixture $c 'src/B/B.csproj' (Proj @())
      Write-Fixture $c 'src/C/C.csproj' (Proj @())
      Write-Fixture $c 'src/A/Foo.cs' $foo
      Commit-All $c 'init'
      $cInit = (& git -C $c rev-parse HEAD)
      $start = Start-Tree $c

      $u = Invoke-Script $checker @('-Repo', $c)
      Check 'checker: neither -Snapshot nor -Since is a usage error (exit 2)' ($u.Code -eq 2)
      $u = Invoke-Script $checker @('-Repo', $c, '-Snapshot', '-Since', $start)
      Check 'checker: -Snapshot with -Since is a usage error (exit 2)' ($u.Code -eq 2)
      $u = Invoke-Script $checker @('-Repo', $root, '-Snapshot')
      Check 'checker: a snapshot outside a git repository fails (exit 2) and prints no START_TREE' ($u.Code -eq 2 -and $u.Out -notmatch 'START_TREE')
      $u = Invoke-Script $checker @('-Repo', $c, '-Since', $start, '-Expected', 'dependency-added')
      Check 'checker: an -Expected item without paths is a usage error (exit 2)' ($u.Code -eq 2)

      $r = Check-Changes $c $start
      Check 'checker: no changes is NONE (exit 0)' ($r.Code -eq 0 -and $r.Json.Status -eq 'NONE' -and $r.Json.Reason -match 'no changes')

      Write-Fixture $c 'src/A/Foo.cs' ($foo + "// edited`n")
      $r = Check-Changes $c $start
      $text = Check-Text $c $start
      Check 'checker: an ordinary edit in a declared repo is NONE (exit 0) after the detector ran' ($r.Code -eq 0 -and $r.Json.Status -eq 'NONE' -and @($r.Json.Facts).Count -eq 0 -and @($r.Json.Detectors | Where-Object { $_.Id -eq 'dotnet-projects' -and $_.Status -eq 'ok' }).Count -eq 1)
      Check 'checker: an ordinary edit prints one line' ($text.Code -eq 0 -and @($text.Out -split "`n" | Where-Object { $_ }).Count -eq 1 -and $text.Out -match '^STRUCTURE: NONE')
      Reset-To $c $cInit

      Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
      Commit-All $c 'task 1'
      $r = Check-Changes $c $start
      $f = @($r.Json.Facts)
      Check 'checker: a committed task change is caught (FOUND, exit 4)' ($r.Code -eq 4 -and $r.Json.Status -eq 'FOUND' -and $f.Count -eq 1 -and $f[0].Kind -eq 'dependency-added' -and $f[0].Expected -eq $false)
      Check 'checker: the fact maps to the standards its kind requires' ($f.Count -eq 1 -and $f[0].Requires[0].Profile -eq 'tech' -and (@($f[0].Requires[0].Standards) -join ',') -eq 'architecture/edges.md,tech/refs.md' -and @($f[0].Blocked).Count -eq 0)
      $text = Check-Text $c $start
      Check 'checker: text output shows the fact, its evidence and what it requires' ($text.Code -eq 4 -and $text.Out -match 'FACT 1 dependency-added UNEXPECTED \(dotnet-projects\): src/A/A\.csproj -> src/C/C\.csproj' -and $text.Out -match [regex]::Escape('EVIDENCE: src/A/A.csproj adds <ProjectReference Include="..\C\C.csproj">') -and $text.Out -match 'REQUIRES \(tech\): architecture/edges\.md, tech/refs\.md')
      $text = Check-Text $c $start @('-Expected', 'dependency-added:src/A|src/C')
      Check 'checker: an expected change (kind and paths) is not marked UNEXPECTED' ($text.Code -eq 4 -and $text.Out -notmatch 'UNEXPECTED')
      Reset-To $c $cInit

      Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
      Write-Fixture $c 'src/B/B.csproj' (Proj @('..\C\C.csproj'))
      $r = Check-Changes $c $start @('-Expected', 'dependency-added:src/A|src/C')
      $fa = @($r.Json.Facts | Where-Object { $_.Units[0] -eq 'src/A/A.csproj' })
      $fb = @($r.Json.Facts | Where-Object { $_.Units[0] -eq 'src/B/B.csproj' })
      Check 'checker: an expected kind does not cover an unrelated change of the same kind' ($r.Code -eq 4 -and $fa.Count -eq 1 -and $fa[0].Expected -eq $true -and $fb.Count -eq 1 -and $fb[0].Expected -eq $false)
      Reset-To $c $cInit

      Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
      & git -C $c add src/A/A.csproj
      $r = Check-Changes $c $start
      Check 'checker: a staged change is caught' ($r.Code -eq 4 -and @($r.Json.Facts | Where-Object Kind -eq 'dependency-added').Count -eq 1)
      Reset-To $c $cInit
      Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
      $r = Check-Changes $c $start
      Check 'checker: an unstaged change is caught' ($r.Code -eq 4 -and @($r.Json.Facts | Where-Object Kind -eq 'dependency-added').Count -eq 1)
      Reset-To $c $cInit

      Write-Fixture $c 'src/D/D.csproj' (Proj @())
      $r = Check-Changes $c $start
      $f = @($r.Json.Facts)
      Check 'checker: an untracked new project is caught' ($r.Code -eq 4 -and $f.Count -eq 1 -and $f[0].Kind -eq 'unit-added' -and $f[0].Units[0] -eq 'src/D/D.csproj')
      Check 'checker: each kind requires only what it maps to' ($f.Count -eq 1 -and (@($f[0].Requires[0].Standards) -join ',') -eq 'architecture/owner.md')
      $r = Check-Changes $c 'HEAD'
      Check 'checker: -Since also takes a commit' ($r.Code -eq 4 -and @($r.Json.Facts).Count -eq 1)
      Reset-To $c $cInit

      Write-Fixture $c 'src/E/E.csproj' (Proj @())
      Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
      $dirtyStart = Start-Tree $c
      Write-Fixture $c 'src/A/Foo.cs' ($foo + "// the fix`n")
      $r = Check-Changes $c $dirtyStart
      Check 'checker: work already dirty at the start is not attributed to the fix' ($r.Code -eq 0 -and $r.Json.Status -eq 'NONE')
      $r = Check-Changes $c $start
      Check 'checker: the same work counts against an earlier start' ($r.Code -eq 4 -and @($r.Json.Facts).Count -eq 2)
      Reset-To $c $cInit

      Write-Fixture $c 'src/D/D.csproj' (Proj @())
      & git -C $c add src/D/D.csproj
      Write-Fixture $c 'src/A/Foo.cs' ($foo + "// unstaged`n")
      $statusBefore = @(& git -C $c status --porcelain) -join "`n"
      $cachedBefore = @(& git -C $c diff --cached --name-only) -join "`n"
      Check-Changes $c $start | Out-Null
      Check 'checker: the check leaves the index and working tree unchanged' ((@(& git -C $c status --porcelain) -join "`n") -eq $statusBefore -and (@(& git -C $c diff --cached --name-only) -join "`n") -eq $cachedBefore)
      Reset-To $c $cInit

      Write-Fixture $c '.cogniva/profiles/base/standards/architecture/other.md' (Std 'Base other, changed.')
      Commit-All $c 'base other changed'
      $s2 = Start-Tree $c
      Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
      $r = Check-Changes $c $s2
      Check 'checker: an unrelated stale standard does not block (FOUND, not BLOCKED)' ($r.Code -eq 4 -and @($r.Json.Facts[0].Blocked).Count -eq 0)
      Reset-To $c $cInit

      Write-Fixture $c '.cogniva/profiles/base/standards/architecture/owner.md' (Std 'Base owner, changed.')
      Commit-All $c 'base owner changed'
      $s3 = Start-Tree $c
      Write-Fixture $c 'src/D/D.csproj' (Proj @())
      $r = Check-Changes $c $s3
      Check 'checker: a stale standard the change requires blocks (BLOCKED, exit 3)' ($r.Code -eq 3 -and $r.Json.Status -eq 'BLOCKED' -and @($r.Json.Facts[0].Blocked | Where-Object Standard -eq 'architecture/owner.md').Count -eq 1)
      Write-Fixture $c '.cogniva/profiles/tech/amendments/architecture/owner.md' (Delta 'Tech owner.' (Basis @((Std 'Base owner, changed.'))))
      $r = Check-Changes $c $s3
      Check 'checker: accepting the reviewed amendment clears the block on re-check' ($r.Code -eq 4 -and @($r.Json.Facts | Where-Object { $_.Kind -eq 'unit-added' -and @($_.Blocked).Count -eq 0 }).Count -eq 1 -and @($r.Json.Facts | Where-Object { $_.Kind -eq 'profile-changed' -and $_.Expected -eq $false }).Count -eq 1)
      Reset-To $c $cInit

      Write-Fixture $c '.cogniva/profiles/tech/profile.yml' ($techYaml + "  - `"dependency-added tech/missing.md`"`n")
      Commit-All $c 'tech maps a missing standard'
      $s4 = Start-Tree $c
      Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
      $r = Check-Changes $c $s4
      Check 'checker: a required standard the profile lacks blocks (exit 3)' ($r.Code -eq 3 -and @($r.Json.Facts[0].Blocked | Where-Object { $_.Standard -eq 'tech/missing.md' -and $_.Reason -match "not in profile 'tech'" }).Count -eq 1)
      Reset-To $c $cInit

      Write-Fixture $c '.cogniva-profile.yml' "profile: nodetector`n"
      Commit-All $c 'no detector'
      $s5 = Start-Tree $c
      Write-Fixture $c 'src/D/D.csproj' (Proj @())
      $r = Check-Changes $c $s5
      Check 'checker: a profile that selects no detector is NOT-CHECKED (exit 0)' ($r.Code -eq 0 -and $r.Json.Status -eq 'NOT-CHECKED' -and $r.Json.Reason -match 'selects no structure detector')
      Reset-To $c $cInit

      Write-Fixture $c '.cogniva-profile.yml' "profile: absent`n"
      Commit-All $c 'broken marker'
      $s6 = Start-Tree $c
      Write-Fixture $c 'src/A/Foo.cs' ($foo + "// edited`n")
      $r = Check-Changes $c $s6
      Check 'checker: a declared profile in ERROR is FAILED (exit 1), even for an ordinary edit' ($r.Code -eq 1 -and $r.Json.Status -eq 'FAILED' -and (@($r.Json.Failures) -join ' ') -match "profile 'absent'")
      Reset-To $c $cInit

      $plain = New-GitRepo 'plain'
      Write-Fixture $plain 'src/A/A.csproj' (Proj @())
      Commit-All $plain 'init'
      $ps = Start-Tree $plain
      Write-Fixture $plain 'src/B/B.csproj' (Proj @())
      $r = Check-Changes $plain $ps
      Check 'checker: a repo with no profile is NOT-CHECKED (exit 0)' ($r.Code -eq 0 -and $r.Json.Status -eq 'NOT-CHECKED' -and $r.Json.Reason -match 'no architecture profile is declared')

      # Governing profiles: both ends of a dependency, and the profiles at the start.
      $strictYaml = "description: Strict.`ninherits: base`nstructure-requires:`n  - `"dependency-added strict/missing.md`"`n  - `"unit-removed strict/missing.md`"`n"
      Add-RepoProfile $c 'strict' $strictYaml @{}
      Write-Fixture $c 'src/C/.cogniva-profile.yml' "profile: strict`n"
      Commit-All $c 'C is strict'
      $cStrict = (& git -C $c rev-parse HEAD)
      $s7 = Start-Tree $c
      Write-Fixture $c 'src/A/A.csproj' (Proj @('..\B\B.csproj', '..\C\C.csproj'))
      $r = Check-Changes $c $s7
      $f = @($r.Json.Facts | Where-Object Kind -eq 'dependency-added')
      Check 'checker: a dependency is also gated in the profile of the project it references' ($r.Code -eq 3 -and $f.Count -eq 1 -and @($f[0].Requires | Where-Object Profile -eq 'strict').Count -eq 1 -and @($f[0].Blocked | Where-Object Standard -eq 'strict/missing.md').Count -eq 1)
      Reset-To $c $cStrict
      Remove-Item -LiteralPath (Join-Path $c 'src/C') -Recurse -Force
      $r = Check-Changes $c $s7
      $f = @($r.Json.Facts | Where-Object Kind -eq 'unit-removed')
      Check 'checker: a project deleted together with its marker is gated in its starting profile' ($r.Code -eq 3 -and $f.Count -eq 1 -and @($f[0].Requires | Where-Object { $_.Profile -eq 'strict' -and $_.When -eq 'start' }).Count -eq 1 -and @($f[0].Blocked | Where-Object { $_.Standard -eq 'strict/missing.md' -and $_.When -eq 'start' }).Count -eq 1)
      $text = Check-Text $c $s7
      Check 'checker: text output says which requirement comes from the starting profile' ($text.Out -match 'REQUIRES \(strict, at start\): strict/missing\.md' -and $text.Out -match 'REQUIRE BLOCKED \(at start\): ')
      Write-Fixture $c '.cogniva/profiles/strict/standards/strict/missing.md' (Std 'Strict, now written.')
      $r = Check-Changes $c $s7
      $f = @($r.Json.Facts | Where-Object Kind -eq 'unit-removed')
      $pc = @($r.Json.Facts | Where-Object Kind -eq 'profile-changed')
      Check 'checker: adding the missing standard clears the start block on re-check' ($r.Code -eq 4 -and $f.Count -eq 1 -and @($f[0].Blocked).Count -eq 0 -and @($f[0].Requires | Where-Object { $_.Profile -eq 'strict' -and $_.When -eq 'start' }).Count -eq 1)
      Check 'checker: the profile edits are one UNEXPECTED profile-changed fact' ($pc.Count -eq 1 -and $pc[0].Expected -eq $false -and @($pc[0].Paths) -contains '.cogniva/profiles/strict/standards/strict/missing.md' -and @($pc[0].Paths) -contains 'src/C/.cogniva-profile.yml')
      Reset-To $c $cInit

      $baseStd = @{ 'architecture/owner.md' = (Std 'Base owner.'); 'architecture/edges.md' = (Std 'Base edges.'); 'architecture/other.md' = (Std 'Base other.') }
      $lo = New-GitRepo 'local-only'
      Add-RepoProfile $lo 'base' $baseYaml $baseStd
      Add-RepoProfile $lo 'tech' ($techYaml + "  - `"unit-removed tech/refs.md`"`n") @{ 'tech/refs.md' = (Std 'Tech refs.') }
      Write-Fixture $lo 'src/C/C.csproj' (Proj @())
      Write-Fixture $lo 'src/C/.cogniva-profile.yml' "profile: tech`n"
      Write-Fixture $lo 'src/D/D.csproj' (Proj @())
      Commit-All $lo 'init'
      $los = Start-Tree $lo
      Remove-Item -LiteralPath (Join-Path $lo 'src/C') -Recurse -Force
      $r = Check-Changes $lo $los
      Check 'checker: deleting the only declared folder still runs its detector (FOUND, not NOT-CHECKED)' ($r.Code -eq 4 -and @($r.Json.Facts | Where-Object { $_.Kind -eq 'unit-removed' -and @($_.Requires | Where-Object { $_.Profile -eq 'tech' -and $_.When -eq 'start' -and (@($_.Standards) -join ',') -eq 'tech/refs.md' }).Count -eq 1 }).Count -eq 1)
      $show = Invoke-Script $resolver @('-Repo', $lo, '-Target', 'src/C', '-Show', 'tech/refs.md')
      Check 'checker: the deleted path itself no longer resolves, so -Show by path fails' ($show.Code -eq 1)
      $show = Invoke-Script $resolver @('-Repo', $lo, '-Target', '.', '-Profile', 'tech', '-Show', 'tech/refs.md')
      Check 'checker: a requirement from the start is read with -Profile, though no marker names that profile now' ($show.Code -eq 0 -and $show.Out -match 'SHOW tech/refs\.md - profile tech')

      $ns = New-GitRepo 'nested'
      Add-RepoProfile $ns 'base' $baseYaml $baseStd
      Add-RepoProfile $ns 'tech' $techYaml @{ 'tech/refs.md' = (Std 'Tech refs.') }
      Write-Fixture $ns 'src/A/A.csproj' (Proj @())
      Write-Fixture $ns 'src/A/.cogniva-profile.yml' "profile: tech`n"
      Write-Fixture $ns 'src/C/C.csproj' (Proj @())
      Write-Fixture $ns 'src/C/.cogniva-profile.yml' "profile: tech`n"
      Commit-All $ns 'init'
      $nss = Start-Tree $ns
      Write-Fixture $ns 'src/Directory.Build.props' "<Project>`n  <ItemGroup>`n    <ProjectReference Include=`"C\C.csproj`" />`n  </ItemGroup>`n</Project>`n"
      $r = Check-Changes $ns $nss
      $f = @($r.Json.Facts | Where-Object Kind -eq 'dependency-added')
      Check 'checker: a shared build file above nested markers is checked by the profiles of the projects under it' ($r.Code -eq 4 -and $f.Count -eq 1 -and @($f[0].Paths) -contains 'src/A/A.csproj' -and @($f[0].Requires | Where-Object Profile -eq 'tech').Count -eq 1)

      # Detector failures are FAILED, never NONE. Fixture detectors live in -DetectorRoot.
      $fx = Join-Path $root 'detectors'
      Write-Fixture $fx 'crashes.ps1' "[Console]::Error.WriteLine('boom'); exit 1`n"
      Write-Fixture $fx 'silent.ps1' "exit 0`n"
      Write-Fixture $fx 'sloppy.ps1' "'{`"contract`":1,`"detector`":`"sloppy`",`"facts`":[{`"kind`":`"unit-added`",`"units`":[`"x`"],`"paths`":[`"x`"]}]}'`nexit 0`n"
      Write-Fixture $fx 'quiet.ps1' "'{`"contract`":1,`"detector`":`"quiet`",`"facts`":[]}'`nexit 0`n"
      foreach ($id in 'crashes', 'silent', 'sloppy', 'quiet', 'ghost') { Add-RepoProfile $c "uses-$id" "description: Uses $id.`ninherits: base`nstructure-detectors:`n  - $id`n" @{} }
      Commit-All $c 'detector fixtures'
      $cFx = (& git -C $c rev-parse HEAD)
      function Try-Detector([string]$Id) {
          Write-Fixture $c '.cogniva-profile.yml' "profile: uses-$Id`n"
          Commit-All $c "use $Id"
          $s = Start-Tree $c
          Write-Fixture $c 'src/A/Foo.cs' ($foo + "// edited`n")
          $res = Check-Changes $c $s @('-DetectorRoot', $fx)
          Reset-To $c $cFx
          return $res
      }
      $r = Try-Detector 'quiet'
      Check 'checker: a detector reporting an empty list is NONE (exit 0)' ($r.Code -eq 0 -and $r.Json.Status -eq 'NONE')
      $r = Try-Detector 'crashes'
      Check 'checker: a detector that exits non-zero is FAILED (exit 1), never NONE' ($r.Code -eq 1 -and $r.Json.Status -eq 'FAILED' -and $r.Json.Detectors[0].Status -eq 'failed' -and $r.Json.Detectors[0].Reason -match 'exited 1' -and $r.Json.Detectors[0].Reason -match 'boom')
      $r = Try-Detector 'silent'
      Check 'checker: a detector that prints no report is FAILED' ($r.Code -eq 1 -and $r.Json.Detectors[0].Reason -match 'no JSON report')
      $r = Try-Detector 'sloppy'
      Check 'checker: a fact without evidence breaks the contract (FAILED)' ($r.Code -eq 1 -and $r.Json.Detectors[0].Reason -match 'broke its contract: a unit-added fact has no evidence')
      $r = Try-Detector 'ghost'
      Check 'checker: a detector the plugin does not ship is FAILED' ($r.Code -eq 1 -and $r.Json.Detectors[0].Reason -match "detector 'ghost'.*is not in")
  ```
- [x] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1` → the detector checks PASS; it then stops on `snapshot failed` because `check-structural-changes.ps1` does not exist yet.
- [x] **Step 3 (implement):** Create `plugins/cogniva-dev/scripts/check-structural-changes.ps1`:
  ```powershell
  #Requires -Version 7.0
  # Structural-change check (contract in docs/architecture-profiles.md).
  # -Snapshot: record the working state as a git tree - tracked, staged, unstaged
  #   and untracked files, ignored files left out - and print START_TREE: <sha>.
  # -Since <tree or commit>: compare that state with the working state now and run
  #   every structure detector that a profile declared anywhere in the repository
  #   selects, now or at the start (a change in one folder can affect units below
  #   it). Each fact is gated under the -Require rule (only standards a change
  #   depends on can block it) in the profile each of its paths has now, plus the
  #   profile its marker named at the start, so deleting a folder with its marker
  #   cannot hide its standards. Requirements and review state always come from
  #   the profiles as they are now, so a repair clears on re-check; any change the
  #   fix made to profile files is a profile-changed fact that needs the user's OK.
  #   -Expected "<kind>:<path>[|<path>...],..." marks a fact expected only when an
  #   item of its kind has paths containing every path of the fact.
  # Read-only: writes git objects, never refs, the index or the working tree.
  # STRUCTURE: NONE | NOT-CHECKED -> exit 0; FAILED (a detector failed, was not
  # found or broke its contract, or a declared profile is in ERROR) -> 1;
  # usage -> 2; BLOCKED (a required standard is missing or needs human review) -> 3;
  # FOUND (structural facts, nothing blocked) -> 4. Precedence 2 > 1 > 3 > 4 > 0.
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)][string]$Repo,
      [string]$Since,
      [switch]$Snapshot,
      [string[]]$Expected,
      [ValidateSet('Text', 'Json')][string]$Format = 'Text',
      [string]$LibraryRoot,
      [string]$DetectorRoot
  )
  $ErrorActionPreference = 'Stop'
  . (Join-Path $PSScriptRoot 'profile-lib.ps1')
  . (Join-Path $PSScriptRoot 'structure-lib.ps1')

  function Fail([string]$Message) { [Console]::Error.WriteLine("structural-changes: $Message"); exit 2 }
  function Get-StructureErrorText($ErrorRecord) { return ($ErrorRecord.Exception.Message -replace '^(StructureError|ProfileError): ', '') }

  if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
  if ($Snapshot -and $Since) { Fail 'use -Snapshot or -Since, not both' }
  if (-not $Snapshot -and -not $Since) { Fail 'pass -Snapshot (at the start) or -Since <START_TREE> (before landing)' }
  $repoFull = $null
  try { $repoFull = [System.IO.Path]::GetFullPath((@(Invoke-StructureGit $Repo @('rev-parse', '--show-toplevel')) | Select-Object -First 1).Trim()) }
  catch { Fail "not a git repository: $Repo" }

  if ($Snapshot) {
      try { $tree = Get-WorkingTreeSnapshot $repoFull }
      catch { Write-Output "STRUCTURE: FAILED - could not snapshot the working tree: $(Get-StructureErrorText $_)"; exit 1 }
      Write-Output "START_TREE: $tree"
      exit 0
  }

  if (-not $LibraryRoot) { $LibraryRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'profiles' }
  if (-not $DetectorRoot) { $DetectorRoot = Join-Path $PSScriptRoot 'structure-detectors' }

  # -Expected: comma-separated "<kind>:<path>[|<path>...]" items.
  $expectations = @()
  foreach ($item in @($Expected | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
      if ($item -cnotmatch '^(?<kind>[a-z][a-z0-9-]*):(?<paths>.+)$') { Fail "-Expected: '$item' must be '<kind>:<path>[|<path>...]'" }
      $kind = $Matches['kind']
      $scopes = @($Matches['paths'] -split '\|' | ForEach-Object { $_.Trim().Replace('\', '/').Trim('/') } | Where-Object { $_ })
      if (-not $scopes.Count) { Fail "-Expected: '$item' names no path" }
      foreach ($p in $scopes) { if ([System.IO.Path]::IsPathRooted($p) -or $p -match '^[A-Za-z]:' -or @($p -split '/') -contains '..') { Fail "-Expected: '$p' must be a repo-relative path" } }
      $expectations += [pscustomobject]@{ Kind = $kind; Scopes = $scopes }
  }

  $markerPattern = '(^|/)\.cogniva-profile\.yml$'
  $governancePattern = '(^|/)\.cogniva-profile\.yml$|^\.cogniva/'
  $ctx = $null
  $startMarkers = $null
  $failures = [System.Collections.Generic.List[string]]::new()
  $report = [ordered]@{ Repo = $repoFull; Base = $null; Head = $null; Status = $null; Reason = $null; Changed = 0; Detectors = @(); Facts = @(); Failures = @(); Warnings = @() }

  function Finish([string]$Status, [string]$Reason) {
      $report.Status = $Status
      $report.Reason = $Reason
      $report.Failures = @($failures)
      $report.Warnings = if ($ctx) { @($ctx.Warnings | Select-Object -Unique) } else { @() }
      $code = switch ($Status) { 'FAILED' { 1 } 'BLOCKED' { 3 } 'FOUND' { 4 } default { 0 } }
      if ($Format -eq 'Json') { [pscustomobject]$report | ConvertTo-Json -Depth 10; exit $code }
      $line = "STRUCTURE: $Status"
      if ($Reason) { $line += " - $Reason" }
      Write-Output $line
      $n = 0
      foreach ($f in $report.Facts) {
          $n++
          $mark = if ($f.Expected) { '' } else { ' UNEXPECTED' }
          Write-Output "FACT $n $($f.Kind)$mark ($($f.Detector)): $($f.Units -join ' -> ')"
          Write-Output "  EVIDENCE: $($f.Evidence)"
          if ($f.Kind -eq 'profile-changed') { Write-Output '  REQUIRES: your OK - the fix changed the architecture profiles its changes are checked against' }
          elseif (@($f.Requires).Count) {
              foreach ($q in $f.Requires) {
                  $ids = if (@($q.Standards).Count) { @($q.Standards) -join ', ' } else { 'none mapped' }
                  $when = if ($q.When -eq 'start') { ', at start' } else { '' }
                  Write-Output "  REQUIRES ($($q.Profile)$when): $ids"
              }
          }
          else { Write-Output '  REQUIRES: none (no declared profile governs these paths)' }
          foreach ($b in $f.Blocked) {
              $when = if ($b.When -eq 'start') { ' (at start)' } else { '' }
              Write-Output "  REQUIRE BLOCKED$($when): $($b.Target) $($b.Standard) - $($b.Reason)"
          }
      }
      foreach ($x in $failures) { Write-Output "CHECK FAILED: $x" }
      foreach ($w in $report.Warnings) { Write-Output "WARN: $w" }
      exit $code
  }

  # $null when $Json is a valid contract-1 report from detector $Id, else what is wrong.
  function Test-DetectorReport($Json, [string]$Id) {
      if ($null -eq $Json) { return 'no JSON report on stdout' }
      if ($Json -isnot [System.Management.Automation.PSCustomObject]) { return 'the report is not a JSON object' }
      $names = @($Json.PSObject.Properties.Name)
      if ($names -notcontains 'contract' -or $Json.contract -ne 1) { return "'contract' must be 1" }
      if ($names -notcontains 'detector' -or $Json.detector -cne $Id) { return "'detector' must be '$Id'" }
      if ($names -notcontains 'facts' -or $Json.facts -isnot [array]) { return "'facts' must be a list" }
      foreach ($f in @($Json.facts)) {
          if ($f -isnot [System.Management.Automation.PSCustomObject]) { return 'every fact must be an object' }
          if ([string]$f.kind -cnotmatch $script:StructureKindPattern) { return "fact kind '$($f.kind)' is not a valid structure kind" }
          if (@($f.units | Where-Object { $_ -is [string] -and $_ }).Count -lt 1) { return "a $($f.kind) fact has no units" }
          $paths = @($f.paths)
          $good = @($paths | Where-Object { $_ -is [string] -and $_ -and -not [System.IO.Path]::IsPathRooted($_) -and @($_ -split '/') -notcontains '..' })
          if ($paths.Count -lt 1 -or $good.Count -ne $paths.Count) { return "a $($f.kind) fact needs one or more repo-relative paths" }
          if (-not ($f.evidence -is [string] -and $f.evidence.Trim())) { return "a $($f.kind) fact has no evidence" }
      }
      return $null
  }

  # A fact is expected when an -Expected item of its kind has paths containing every path of the fact.
  function Test-Under([string]$Path, [string]$Scope) {
      if ($Scope -eq '.') { return $true }
      return ([string]::Equals($Path, $Scope, $script:PathComparison) -or $Path.StartsWith("$Scope/", $script:PathComparison))
  }
  function Test-Expected($Fact) {
      $scopes = @($expectations | Where-Object Kind -ceq $Fact.Kind | ForEach-Object { $_.Scopes })
      if (-not $scopes.Count) { return $false }
      foreach ($p in $Fact.Paths) { if (-not @($scopes | Where-Object { Test-Under $p $_ }).Count) { return $false } }
      return $true
  }

  function Get-Folder([string]$Path) {
      if ($Path.Contains('/')) { return $Path.Substring(0, $Path.LastIndexOf('/')) }
      return '.'
  }
  # A path's profile now. A profile depends only on folders, so each folder is resolved once.
  $resolvedDirs = @{}
  function Resolve-Now([string]$Path) {
      $dir = Get-Folder $Path
      if (-not $script:resolvedDirs.ContainsKey($dir)) { $script:resolvedDirs[$dir] = Resolve-TargetProfile $script:ctx ([System.IO.Path]::GetFullPath((Join-Path $script:repoFull $dir))) $null }
      return $script:resolvedDirs[$dir]
  }
  # The profile id the nearest marker named for $Path at the start, or $null
  # (no marker, 'none', or the fix changed no profile file).
  function Get-StartProfile([string]$Path) {
      if ($null -eq $script:startMarkers) { return $null }
      $dir = Get-Folder $Path
      while ($true) {
          if ($script:startMarkers.ContainsKey($dir)) {
              $id = $script:startMarkers[$dir]
              if ($id -ceq 'none') { return $null }
              return $id
          }
          if ($dir -eq '.') { return $null }
          $dir = Get-Folder $dir
      }
  }

  try {
      $base = Resolve-StructureTree $repoFull $Since
      $head = Get-WorkingTreeSnapshot $repoFull
      $changes = @(Get-TreeChanges $repoFull $base $head)
  }
  catch { $failures.Add((Get-StructureErrorText $_)); Finish 'FAILED' 'the changes since the start could not be read' }
  $report.Base = $base
  $report.Head = $head
  $report.Changed = $changes.Count
  if (-not $changes.Count) { Finish 'NONE' 'no changes since the start' }

  $ctx = New-ResolutionContext $repoFull $LibraryRoot
  $facts = [System.Collections.Generic.List[object]]::new()

  # Profile files the fix changed are always listed, and always need the user's
  # OK: a fix may not quietly change the standards its own changes are checked
  # against. The markers as they were at the start are kept, so a folder removed
  # together with its marker is still governed by the profile that marker named.
  $profileChanges = @($changes | ForEach-Object { if ($_.Path -match $governancePattern) { $_.Path }; if ($_.OldPath -and $_.OldPath -match $governancePattern) { $_.OldPath } } | Select-Object -Unique)
  if ($profileChanges.Count) {
      $more = if ($profileChanges.Count -gt 1) { " and $($profileChanges.Count - 1) more" } else { '' }
      $facts.Add([pscustomobject]@{ Detector = 'structural-check'; Kind = 'profile-changed'; Units = @($profileChanges); Paths = @($profileChanges); Evidence = "the fix changed $($profileChanges.Count) architecture profile file(s): $($profileChanges[0])$more"; Expected = $false; Requires = @(); Blocked = @() })
      $startMarkers = @{}
      try {
          foreach ($m in @(Get-TreePaths $repoFull $base | Where-Object { $_ -match $markerPattern })) {
              $data = ConvertFrom-CognivaYaml @(([string](Get-TreeFileText $repoFull $base $m)) -split "`r?`n") "$m (at start)"
              if ($data['profile'] -isnot [string]) { Throw-ProfileError "$m (at start): 'profile' must be a single profile id" }
              Assert-ProfileId $data['profile'] "$m (at start)" -AllowNone
              $startMarkers[(Get-Folder $m)] = $data['profile']
          }
      }
      catch { $failures.Add("the profile markers at the start could not be read: $(Get-StructureErrorText $_)"); Finish 'FAILED' 'the profile markers at the start could not be read' }
  }

  # Detectors: every profile a marker declares now, plus every profile a marker
  # named at the start. A change in one folder can affect units below it.
  $declaredIds = [System.Collections.Generic.List[string]]::new()
  foreach ($m in @(Get-TreePaths $repoFull $head | Where-Object { $_ -match $markerPattern })) {
      $t = Resolve-Now $m
      if ($t.Status -eq 'ERROR') {
          $msg = "profile declared by $m could not be resolved: $($t.Error)"
          if (-not $failures.Contains($msg)) { $failures.Add($msg) }
      }
      elseif ($t.Status -eq 'RESOLVED' -and -not $declaredIds.Contains($t.Profile)) { $declaredIds.Add($t.Profile) }
  }
  if ($startMarkers) {
      foreach ($dir in @($startMarkers.Keys)) {
          $id = $startMarkers[$dir]
          if ($id -ceq 'none' -or $declaredIds.Contains($id)) { continue }
          $origin = if ($dir -eq '.') { '.cogniva-profile.yml (at start)' } else { "$dir/.cogniva-profile.yml (at start)" }
          $result = Get-ContextProfileResult $ctx $id $origin
          if ($result.Error) { $failures.Add("profile '$id', declared at the start by $origin, cannot be resolved now: $($result.Error)") }
          else { $declaredIds.Add($id) }
      }
  }
  $detectorIds = [System.Collections.Generic.List[string]]::new()
  $detectorProfiles = @{}
  foreach ($id in $declaredIds) {
      foreach ($d in $ctx.Results[$id].Structure.Detectors) {
          if (-not $detectorIds.Contains($d)) { $detectorIds.Add($d); $detectorProfiles[$d] = @() }
          if ($detectorProfiles[$d] -notcontains $id) { $detectorProfiles[$d] += $id }
      }
  }
  if (-not $detectorIds.Count) {
      if ($failures.Count) { Finish 'FAILED' 'a declared architecture profile could not be resolved' }
      $report.Facts = @($facts)
      if ($facts.Count) { Finish 'FOUND' 'the fix changed architecture profile files; no profile selects a structure detector' }
      if (-not $declaredIds.Count) { Finish 'NOT-CHECKED' 'no architecture profile is declared in the repository' }
      Finish 'NOT-CHECKED' "profile $($declaredIds -join ', ') selects no structure detector"
  }

  $pwshPath = [System.Environment]::ProcessPath
  foreach ($d in $detectorIds) {
      $entry = [ordered]@{ Id = $d; Profiles = @($detectorProfiles[$d]); Status = 'ok'; Facts = 0; Reason = $null }
      $detectorFile = Join-Path $DetectorRoot "$d.ps1"
      try {
          if (-not (Test-Path -LiteralPath $detectorFile -PathType Leaf)) { throw [System.InvalidOperationException]::new("StructureError: detector '$d' (selected by profile $($entry.Profiles -join ', ')) is not in $DetectorRoot") }
          $previous = $ErrorActionPreference
          $ErrorActionPreference = 'Continue'
          try {
              $lines = @(& $pwshPath -NoProfile -File $detectorFile -Repo $repoFull -Base $base -Head $head 2>&1)
              $code = $LASTEXITCODE
          }
          finally { $ErrorActionPreference = $previous }
          $stdout = (@($lines | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ }) -join "`n")
          $stderr = (@($lines | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ }) -join ' ').Trim()
          if ($code -ne 0) { throw [System.InvalidOperationException]::new("StructureError: detector '$d' exited $code$(if ($stderr) { ": $stderr" })") }
          $json = $null
          try { $json = $stdout | ConvertFrom-Json } catch { $json = $null }
          $problem = Test-DetectorReport $json $d
          if ($problem) { throw [System.InvalidOperationException]::new("StructureError: detector '$d' broke its contract: $problem") }
          foreach ($f in @($json.facts)) {
              $facts.Add([pscustomobject]@{ Detector = $d; Kind = $f.kind; Units = @($f.units); Paths = @($f.paths); Evidence = $f.evidence; Expected = $false; Requires = @(); Blocked = @() })
          }
          $entry.Facts = @($json.facts).Count
      }
      catch {
          $entry.Status = 'failed'
          $entry.Reason = Get-StructureErrorText $_
          $failures.Add($entry.Reason)
      }
      $report.Detectors += [pscustomobject]$entry
  }

  # Each fact is governed by the profile each of its paths has now, plus the
  # profile its marker named at the start. What those profiles require, and the
  # review state of those standards, always comes from the profiles as they are
  # now, so adding a missing standard or accepting a reviewed amendment clears a
  # block on re-check (and the profile-changed fact asks the user to OK the edit).
  foreach ($f in $facts) {
      if ($f.Kind -eq 'profile-changed') { continue }
      $f.Expected = Test-Expected $f
      $when = [ordered]@{}
      $targets = @()
      foreach ($p in $f.Paths) {
          $t = Resolve-Now $p
          if ($t.Status -eq 'RESOLVED' -and -not $when.Contains($t.Profile)) { $when[$t.Profile] = 'now'; $targets += $t }
      }
      foreach ($p in $f.Paths) {
          $id = Get-StartProfile $p
          if (-not $id -or $when.Contains($id)) { continue }
          if ((Get-ContextProfileResult $ctx $id 'a marker at the start').Error) { continue }
          $when[$id] = 'start'
          $targets += [pscustomobject]@{ Target = $p; Status = 'RESOLVED'; Profile = $id }
      }
      $gate = Get-RequireResult $ctx $targets @() @($f.Kind)
      $f.Requires = @($gate.ByTarget | ForEach-Object { [pscustomobject]@{ Profile = $_.Profile; When = $when[$_.Profile]; Standards = @($_.Standards) } })
      $f.Blocked = @($gate.Blocked | ForEach-Object { [pscustomobject]@{ Target = $_.Target; Profile = $_.Profile; Standard = $_.Standard; Reason = $_.Reason; When = $when[$_.Profile] } })
  }
  $report.Facts = @($facts)

  if ($failures.Count) { Finish 'FAILED' "$($failures.Count) part(s) of the check could not run" }
  if (@($facts | Where-Object { @($_.Blocked).Count }).Count) { Finish 'BLOCKED' 'a standard these changes require is missing or needs human review' }
  if ($facts.Count) { Finish 'FOUND' "$($facts.Count) structural change(s) since the start" }
  Finish 'NONE' "detectors ran: $($detectorIds -join ', ')"
  ```
- [x] **Step 4 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1` → `All structural-changes assertions passed.`
- [x] **Step 5 (green gate):** In `.claude/cogniva-dev/green-gate.json`, insert this line directly after the line whose `"label"` is `"profile-library"` (keep the comma rules of the JSON array):
  ```json
      { "run": "pwsh -NoProfile -File plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1", "label": "structural-changes", "note": "Pins the start snapshot, the dotnet-projects detector and the structural check's statuses and exit codes; needs PowerShell 7." },
  ```
  Then `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/validate-json.ps1 .claude/cogniva-dev/green-gate.json` → exit 0.
- [x] **Step 6 (write ADR):** scan `docs/adr/` for the next number and write ADR-C2 from `## Candidate ADRs` verbatim to `docs/adr/NNNN-structure-detectors-report-facts-and-fail-loudly.md` per the adr skill's ADR-FORMAT (`**Provenance:** Suggested by agent`; no Relitigation line).
- [x] **Step 7 (commit):** `git add plugins/cogniva-dev/scripts/check-structural-changes.ps1 plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1 .claude/cogniva-dev/green-gate.json docs/adr/` then `git commit -m "feat(structure): check-structural-changes.ps1 - start snapshot and landing check"`

## Task 5: The shipped library's structural-change policy

**Files:**
- Modify: `plugins/cogniva-dev/profiles/cogniva-base/profile.yml`
- Modify: `plugins/cogniva-dev/profiles/dotnet/profile.yml`
- Test: `plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1`

- [ ] **Step 1 (failing tests):** In `profile-library.tests.ps1`, add `$checker = Join-Path $plugin 'scripts\check-structural-changes.ps1'` directly below the `$accepter = ...` line, and insert directly above `    # --- sections appended by later sub-plans go above this line ---`:
  ```powershell
      # --- the shipped structural-change policy ----------------------------------
      $sdn = (Resolve-Json $shipped @('-Target', 'src')).Json.Profiles.dotnet.Structure
      Check 'cogniva-base declares the five technology-neutral kinds' ((@($sdn.Kinds) -join ',') -eq 'unit-added,unit-removed,dependency-added,dependency-removed,code-moved')
      Check 'dotnet selects the dotnet-projects detector' ((@($sdn.Detectors) -join ',') -eq 'dotnet-projects')
      $expectMap = [ordered]@{
          'unit-added' = 'architecture/ownership-and-placement.md,architecture/common-and-published-types.md,architecture/composition-roots.md,dotnet/project-layout.md,dotnet/projects-and-references.md,dotnet/build-settings.md'
          'unit-removed' = 'architecture/ownership-and-placement.md,dotnet/projects-and-references.md'
          'dependency-added' = 'architecture/dependency-direction.md,architecture/common-and-published-types.md,dotnet/projects-and-references.md'
          'dependency-removed' = 'architecture/dependency-direction.md,dotnet/projects-and-references.md'
          'code-moved' = 'architecture/ownership-and-placement.md,dotnet/project-layout.md'
      }
      foreach ($k in $expectMap.Keys) { Check "dotnet maps $k to exactly its standards" ((@($sdn.Requires.$k) -join ',') -eq $expectMap[$k]) }
      $detectorRoot = Join-Path $plugin 'scripts\structure-detectors'
      Check 'every detector the library names ships in scripts/structure-detectors' (@($sdn.Detectors | Where-Object { -not (Test-Path -LiteralPath (Join-Path $detectorRoot "$_.ps1") -PathType Leaf) }).Count -eq 0)

      # the shipped dotnet profile, end to end: adopt, declare, add a project with a reference
      $live = New-DotnetRepo 'structure-live'
      & git -C $live config user.email 'tests@cogniva.invalid'
      & git -C $live config user.name 'Cogniva tests'
      Write-Fixture $live 'src/Lib/Acme.Lib/Acme.Lib.csproj' "<Project Sdk=`"Microsoft.NET.Sdk`" />`n"
      & git -C $live add -A 2>$null
      & git -C $live commit -q -m init 2>$null | Out-Null
      $snap = Invoke-Script $checker @('-Repo', $live, '-Snapshot')
      $liveStart = if ($snap.Out -match 'START_TREE: ([0-9a-f]+)') { $Matches[1] } else { 'missing' }
      Write-Fixture $live 'src/Engines/Acme.Pricing/Acme.Pricing.csproj' "<Project Sdk=`"Microsoft.NET.Sdk`">`n  <ItemGroup>`n    <ProjectReference Include=`"..\..\Lib\Acme.Lib\Acme.Lib.csproj`" />`n  </ItemGroup>`n</Project>`n"
      $chk = Invoke-Script $checker @('-Repo', $live, '-Since', $liveStart, '-Format', 'Json')
      $cj = if ($chk.Code -eq 4) { $chk.Out | ConvertFrom-Json } else { $null }
      $added = @($cj.Facts | Where-Object Kind -eq 'unit-added')
      $dep = @($cj.Facts | Where-Object Kind -eq 'dependency-added')
      Check 'shipped dotnet: a new project is unit-added and requires the unit-added set' ($added.Count -eq 1 -and $added[0].Units[0] -eq 'src/Engines/Acme.Pricing/Acme.Pricing.csproj' -and (@($added[0].Requires[0].Standards) -join ',') -eq $expectMap['unit-added'])
      Check 'shipped dotnet: its new reference is dependency-added and requires the dependency-added set' ($dep.Count -eq 1 -and ($dep[0].Units -join '>') -eq 'src/Engines/Acme.Pricing/Acme.Pricing.csproj>src/Lib/Acme.Lib/Acme.Lib.csproj' -and (@($dep[0].Requires[0].Standards) -join ',') -eq $expectMap['dependency-added'])
  ```
- [ ] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` → the new policy checks FAIL (the shipped profiles declare no policy yet).
- [ ] **Step 3 (cogniva-base):** Replace the content of `plugins/cogniva-dev/profiles/cogniva-base/profile.yml` with:
  ```yaml
  description: Cogniva's technology-neutral architecture standards; the root every other profile inherits from.
  # Kinds of structural change a structure detector can report. Technology and
  # repository profiles may declare more.
  structure-kinds:
    - unit-added
    - unit-removed
    - dependency-added
    - dependency-removed
    - code-moved
  # The standards a structural change of each kind depends on. quick-fix requires
  # them (resolve-architecture-profile.ps1 -Kinds) when such a change happens.
  structure-requires:
    - "unit-added architecture/ownership-and-placement.md"
    - "unit-added architecture/common-and-published-types.md"
    - "unit-added architecture/composition-roots.md"
    - "unit-removed architecture/ownership-and-placement.md"
    - "dependency-added architecture/dependency-direction.md"
    - "dependency-added architecture/common-and-published-types.md"
    - "dependency-removed architecture/dependency-direction.md"
    - "code-moved architecture/ownership-and-placement.md"
  ```
- [ ] **Step 4 (dotnet):** Replace the content of `plugins/cogniva-dev/profiles/dotnet/profile.yml` with:
  ```yaml
  description: Cogniva's .NET architecture - shared principles and the default conventions for new repos. Inherits cogniva-base; a repository's own layout belongs in a repo-owned profile.
  inherits: cogniva-base
  detect:
    - "*.slnx"
    - "*.sln"
    - "Directory.Build.props"
  # In .NET a unit is a project. dotnet-projects reports projects added or
  # removed, project references added or removed, and files moved between projects.
  structure-detectors:
    - dotnet-projects
  structure-requires:
    - "unit-added dotnet/project-layout.md"
    - "unit-added dotnet/projects-and-references.md"
    - "unit-added dotnet/build-settings.md"
    - "unit-removed dotnet/projects-and-references.md"
    - "dependency-added dotnet/projects-and-references.md"
    - "dependency-removed dotnet/projects-and-references.md"
    - "code-moved dotnet/project-layout.md"
  ```
- [ ] **Step 5 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` → `All profile-library assertions passed.` (its leak checks also cover the new `profile.yml` text); `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → `All architecture-profile assertions passed.` (its shipped-library loop requires both profiles to resolve with no warnings, so every mapped id must exist).
- [ ] **Step 6 (commit):** `git add plugins/cogniva-dev/profiles/cogniva-base/profile.yml plugins/cogniva-dev/profiles/dotnet/profile.yml plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` then `git commit -m "feat(profiles): structural-change policy for cogniva-base and dotnet"`

## Task 6: Pin quick-fix's structural-change contract

**Files:**
- Test: `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`

This file runs under Windows PowerShell 5.1: keep every added line ASCII.

- [ ] **Step 1 (failing pins):** In `skill-semantics.tests.ps1`, insert directly above the line `if ($failures.Count -gt 0) {`:
  ```powershell
  # --- quick-fix structural checks ----------------------------------------------
  $qfFlat    = $qf -replace '\s+', ' '
  $wtQfFlat  = (ReadDoc 'skills\quick-fix\WORKTREE.md') -replace '\s+', ' '
  $codexFlat = $codex -replace '\s+', ' '
  $tpl       = ReadDoc 'templates\execute-feature.workflow.js'
  Check 'quick-fix records START_TREE with the snapshot at Step 0' ($qf -match 'check-structural-changes\.ps1" -Repo "<WORKSPACE>" -Snapshot' -and $qf -match 'START_TREE: <sha>')
  Check 'quick-fix: work already dirty is part of the start state' ($qfFlat -match 'none of that is attributed to this fix')
  Check 'quick-fix: an ordinary fix makes no profile call and adds nothing to tasks' ($qfFlat -match 'Otherwise skip this step: no profile call, nothing added to tasks')
  Check 'quick-fix: no valid START_TREE stops before dispatch' ($qfFlat -match 'Any other result \(a non-zero exit, or no `START_TREE:` line\) . stop before dispatching' -and $qfFlat -match 'without a valid `START_TREE` the structural check cannot run')
  Check 'quick-fix preflights each expected item with its own kind and paths, and stops on exit 3' ($qf -match '-Target "<that item''s paths>" -Kinds "<that item''s kind>"' -and $qfFlat -match 'Never pass one item''s kind against another item''s paths' -and $qfFlat -match 'Exit 3 . stop before dispatching')
  Check 'quick-fix reads landing requirements by profile, not by path' ($qf -match '-Target \. -Profile <the profile on that REQUIRES line> -Show' -and $qfFlat -match 'a path the fix deleted no longer resolves')
  Check 'quick-fix: a profile-changed fact always needs the user''s OK' ($qfFlat -match 'A `profile-changed` fact is always `UNEXPECTED`')
  Check 'quick-fix: expectations name paths as well as kinds' ($qf -match '<kind>:<path>\[\|<path>\.\.\.\]' -and $qfFlat -match 'A structural change outside the folders you name counts as unexpected at landing')
  Check 'quick-fix: each profile''s own standards are printed from its REQUIRE FOR line' ($qfFlat -match 'For each `REQUIRE FOR <target> \(<profile>\): <ids>` line that lists standards')
  Check 'quick-fix: a usage error never dispatches and never lands' ($qfFlat -match 'Exit 2 . the command is wrong: fix it and re-run; never dispatch on it' -and $qfFlat -match 'never treat it as no structural changes')
  Check 'quick-fix: a missing standard is fixed in the profile, a stale one is reviewed and accepted' ($qfFlat -match 'adds the standard or corrects the `structure-requires` pair' -and $qfFlat -match 'reviews (that|the) standard and runs `accept-profile-delta\.ps1`')
  Check 'quick-fix gives the full standards text only to tasks that make the change' ($qf -match '### Architecture standards for this task' -and $qfFlat -match 'Put the `-Show` output VERBATIM' -and $qfFlat -match 'Tasks that do not make the change get none of it')
  Check 'quick-fix workers stop on a structural change they were not asked for' ($qfFlat -match 'and this task does not ask for it, stop and return BLOCKED')
  $iObl    = $qf.IndexOf('### before-integrate')
  $iStruct = $qf.IndexOf('STRUCTURAL CHECK')
  $iAdr    = $qf.IndexOf('check-adrs.ps1')
  $iGate   = $qf.IndexOf('run-green-gate.ps1')
  Check 'quick-fix: the structural check runs after before-integrate, before the ADR check and green gate' ($iObl -ge 0 -and $iStruct -gt $iObl -and $iAdr -gt $iStruct -and $iGate -gt $iAdr)
  Check 'quick-fix: the landing check compares against START_TREE' ($qf -match '-Since <START_TREE>')
  Check 'quick-fix: an UNEXPECTED fact waits for the user' ($qfFlat -match 'wait for their OK before continuing')
  Check 'quick-fix: a blocked required standard stops landing' ($qfFlat -match 'BLOCKED` \| Stop landing')
  Check 'quick-fix: a failed check is never no structural changes' ($qfFlat -match 'Never treat a failed check as no structural changes')
  Check 'quick-fix: a waived check is recorded under Skipped validations' ($qfFlat -match 'land without the check; record that under Skipped validations')
  Check 'quick-fix: finding a structural change never alone leaves quick-fix' ($qfFlat -match 'Finding a structural change is never by itself a reason to leave quick-fix')
  Check 'quick-fix: a departure routes to plan-feature, never auto-run' ($qfFlat -match 'needed exception . stop landing' -and $qfFlat -match 'propose `/cogniva-dev:plan-feature` for the decision \(never auto-run it\)')
  Check 'quick-fix: no pwsh in a repo with profiles asks the user before dispatch' ($qfFlat -match 'if the repo has a `\.cogniva/profiles/` folder, say the structural check cannot run and ask the user before dispatching')
  Check 'quick-fix stays technology-neutral' ($qf -notmatch '(?i)csproj|ProjectReference|\.NET\b|pyproject')
  Check 'quick-fix does not use applicable-rules as its architecture check' ($qf -notmatch 'applicable-rules')
  Check 'worktree quick-fix snapshots after any staleness merge' ($wtQfFlat -match 'record `START_TREE` exactly as Step 0 says' -and $wtQfFlat -match 'after any staleness merge is committed')
  Check 'Codex parity: both backends pass the task body verbatim' ($codexFlat -match 'full `body` VERBATIM' -and $tpl -match 't\.body')
  Check 'Codex parity: quick-fix landing under Codex includes the structural check' ($codexFlat -match 'quick-fix also runs its structural check')
  ```
- [ ] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → the new quick-fix pins FAIL, except three that already hold (both backends pass the body verbatim, technology-neutral, no applicable-rules); every older pin still PASSES.
- [ ] **Step 3 (commit):** `git add plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` then `git commit -m "test(quick-fix): pin the structural-change contract"`

## Task 7: Wire the check into quick-fix (Claude and Codex)

**Files:**
- Modify: `plugins/cogniva-dev/skills/quick-fix/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/quick-fix/WORKTREE.md`
- Modify: `plugins/cogniva-dev/skills/execute-feature/CODEX.md`

What the skill must keep true:
- A fix that is not expected to make a structural change makes no profile
  call while scoping, and its workers get only the one-line stop instruction.
- The landing check always runs and is the safety net. Expecting a change at
  Step 0.6 only moves the standards check earlier.
- Nothing in the skill names a technology.

- [ ] **Step 1 (SKILL.md):** Replace the whole content of `plugins/cogniva-dev/skills/quick-fix/SKILL.md` with:
  ````markdown
  ---
  name: quick-fix
  description: Use for small follow-up changes (UI tweak, bug fix, copy change) without a formal feature plan. Runs the change via a background Workflow so it can be fired repeatedly without bloating context; in worktree mode the change is isolated in a git worktree and auto-integrated.
  ---

  # Quick Fix

  A planless sibling of `/cogniva-dev:execute-feature` for small changes. The
  work runs in a background Workflow, so fire it repeatedly from a control
  session and stay lean.

  Invoke: `/cogniva-dev:quick-fix "<short description of the change>"`.

  **Worktree dispatch (check first):** worktree mode is ON iff the target
  repo's `.claude/cogniva-dev.local.json` has `"worktrees": true`. ON → read
  `WORKTREE.md` beside this file NOW; it replaces the ⟦worktree⟧ steps. OFF →
  work directly on the user's checkout and current branch.

  **Host dispatch (check second):** if the Workflow tool is not available in
  this session (Codex or any non-Claude host), read
  `../execute-feature/CODEX.md` NOW — its sequential subagent loop replaces
  Step 1 (the Workflow dispatch), driven by the task list synthesized there.
  Quick-fix tasks are PLANLESS — no `planPath`, nothing ticks checkboxes, no
  plan resume — and after the loop the run lands at Step 2 BELOW, not at
  execute-feature's Step 4.
  Worktree mode requires the Claude Workflow runtime; under any other host
  only lean mode is supported — if worktree mode is ON and the Workflow tool
  is absent, STOP and say so.

  `<plugin>` = this plugin's root (parent of `skills/`) — tooling, not the
  target; the repo being fixed is the one you were invoked from.

  **Flags:** quick-fix honours `commits=` exactly as the `## Flags` section of
  `../execute-feature/SKILL.md` defines it — the same `none|task|final`
  semantics and the same defaults (lean mode → `none`, worktree mode →
  `task`), and `none|final` are just as INVALID in worktree mode, where
  integration is a fast-forward of commits: reject the combination with one
  clear line and stop, never silently ignore it. quick-fix is planless, so
  `plan=` does not apply.

  ## Step 0 — workspace

  `WORKSPACE` = the repo root; `BRANCH` = the current branch; record `START`
  = `git rev-parse HEAD`. Dirty tree → show the user what is dirty and get an
  OK before dispatching. Then record `START_TREE`, the starting state that
  Step 2's structural check compares against. It includes whatever was
  already dirty, so none of that is attributed to this fix:
  `pwsh -NoProfile -File "<plugin>/scripts/check-structural-changes.ps1" -Repo "<WORKSPACE>" -Snapshot`
  prints `START_TREE: <sha>`. Any other result (a non-zero exit, or no
  `START_TREE:` line) → stop before dispatching and show its output: without
  a valid `START_TREE` the structural check cannot run. No `pwsh`: if the
  repo has a `.cogniva/profiles/` folder, say the structural check cannot run
  and ask the user before dispatching whether to go ahead without it (yes →
  record that under Skipped validations); otherwise say so in one line and
  carry on. ⟦worktree⟧

  **Branch policy (lean mode only).** BEFORE mutating anything, read
  `.claude/cogniva-dev/policy.json`. If it exists and carries
  `requiredDevelopmentBranchPrefix`, `BRANCH` must start with that prefix.
  Mismatch → STOP with one clear line naming the current branch and the
  required prefix; NEVER create or switch a branch to satisfy the policy —
  which branch to work on is the user's call, not yours. Absent or unreadable
  file, or no such key → no policy, no behaviour change. Worktree mode needs
  no check: its generated branches are `feature/<slug>` by construction.

  ## Step 0.5 — candidate ADRs (confirm BEFORE dispatch)

  Most quick-fixes produce none. If scoping surfaces an architectural
  decision, hold it as a candidate (title, 1–3 sentences, provenance,
  relitigation if non-default — see `/adr`) and get an explicit
  yes/amend/drop BEFORE dispatching. Fold each confirmed candidate into the
  task body as a final step — "write ADR `NNNN-<slug>.md` (next number by
  scanning `docs/adr/`) with this exact content" — so it is written during
  execution and lands with the fix (committed only where the commit policy
  commits; under `commits=none|final` it stays in the tree with the fix).

  ## Step 0.6 — expected structural change (usually skipped)

  Run this step only when scoping shows the fix will add or remove a unit (a
  project, package or module), add or remove a dependency between units, or
  move code from one unit to another. Otherwise skip this step: no profile
  call, nothing added to tasks.

  1. Write down what you expect as `EXPECTED`: comma-separated
     `<kind>:<path>[|<path>...]` items, one per kind. Each lists every folder
     that change touches, both ends of a dependency included, for example
     `dependency-added:src/A|src/B`. The kinds are `unit-added`,
     `unit-removed`, `dependency-added`, `dependency-removed` and
     `code-moved`. A structural change outside the folders you name counts as
     unexpected at landing.
  2. For each `EXPECTED` item, run
     `pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo "<WORKSPACE>" -Target "<that item's paths>" -Kinds "<that item's kind>"`.
     Never pass one item's kind against another item's paths: a kind is
     checked only where that change happens. Act on every run's result:
     - Exit 3 → stop before dispatching and show the `REQUIRE BLOCKED:`
       lines. A reason `not in profile` means the profile maps that kind to a
       standard it does not have: a human adds the standard or corrects the
       `structure-requires` pair. A reason `needs human review` means a human
       reviews that standard and runs `accept-profile-delta.ps1`.
     - Exit 2 → the command is wrong: fix it and re-run; never dispatch on it.
     - Exit 1 → show the error and ask the user how to proceed.
     - `PROFILE: undeclared` or `PROFILE: none`, `REQUIRE: ok (no standards
       required)`, or no `pwsh` → carry on with nothing added to tasks.
  3. Otherwise print the standards in full, profile by profile. For each
     `REQUIRE FOR <target> (<profile>): <ids>` line that lists standards, in
     any run, run the same script with `-Target "<that target>" -Show "<those
     ids>"`. Read them. A planned change that departs from them, or needs a choice they
     leave open, is not a quick fix: stop and propose
     `/cogniva-dev:plan-feature` (never auto-run it).
  4. Put the `-Show` output VERBATIM in the body of each task that makes the
     change, using the output for the items and targets that task touches
     (each standard once per profile — one copy per (profile, standard ID),
     so a task that spans profiles gets each profile's own amended version), under
     `### Architecture standards for this task`, after this line: "Follow these standards. If the work needs a structural change
     they do not cover, or a different one from what this task describes,
     stop and return BLOCKED with what you found." Tasks that do not make the
     change get none of it.

  ## Step 1 — make the change (background Workflow)

  Run `<plugin>/templates/execute-feature.workflow.js` (copy verbatim; CRLF
  rejection → write an LF copy). One synthesized task for trivial fixes, or a
  short ordered list. Each task body: what to change, how to verify, and —
  only under a commit policy that commits — a commit step. Planless — no
  `planPath`. The agent works in `WORKSPACE` on `BRANCH`; where the policy
  commits it stages only its own files and commits, otherwise it stages
  nothing and leaves the change in the working tree.

  Every task body ends with this line, whatever the fix: "If this change
  turns out to need adding or removing a unit (a project, package or
  module), a dependency between units, or moving code from one unit to
  another, and this task does not ask for it, stop and return BLOCKED saying
  what you would change." A task BLOCKED that way → treat the change as
  expected: run Step 0.6 for it, then re-dispatch the tasks that did not
  finish.

  ## Step 2 — land it

  Same order as execute-feature's Land step, for the same reasons, plus the
  structural check:
  tree consistent with the commit policy → do-now gate (`CAPTURE-BAR.md`
  Test 3; depth-1 — a genuine second round is another
  `/cogniva-dev:quick-fix`, which is cheap and the whole point of this skill)
  → `### before-integrate` block from
  `scripts/resolve-workflow-obligations.ps1` (under Codex honour only its
  substantive gate — see `../execute-feature/CODEX.md`) → STRUCTURAL CHECK
  (below; after every step that can write code, before the gates) → ADR check
  (`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/check-adrs.ps1" -Workspace "<WORKSPACE>" -Since START` ⟦worktree⟧)
  → `git diff --check` (whitespace errors or conflict markers → fix them,
  respecting the commit policy, and re-run until clean; record the result)
  → GREEN GATE (`powershell -NoProfile -ExecutionPolicy Bypass -File
  "<plugin>/scripts/run-green-gate.ps1" -Repo "<WORKSPACE>"`; exit 0 = green or
  legitimate skip, 1 = red, 2 = config error) → under `commits=final`, NOW the single implementation commit —
  exactly one, only after the green gate; a git failure → `BLOCKED`, no
  retries → done ⟦worktree⟧. `commits=` stays the sole commit authority
  through every one of these steps, exactly as execute-feature defines it.

  In lean mode "done" IS the handoff: emit it in full per
  `../execute-feature/HANDOFF.md` as the final text of the turn. A short fix
  yields a short handoff — every section still appears, one with nothing to
  report saying `none`. Its Checks run section carries the `STRUCTURE:` line.
  Worktree mode ends by integrating, unchanged.

  ### Structural check

  `pwsh -NoProfile -File "<plugin>/scripts/check-structural-changes.ps1" -Repo "<WORKSPACE>" -Since <START_TREE> -Expected "<EXPECTED>"`
  (leave out `-Expected` when Step 0.6 was skipped). It compares everything
  since the start - task commits, staged, unstaged and untracked files - runs
  the structure detectors the repo's profiles select, and checks each change
  against the profiles of every path it touches, as they are now and as they
  were at the start.

  | Exit | `STRUCTURE:` | Then |
  |---|---|---|
  | 0 | `NONE` or `NOT-CHECKED` | Continue. |
  | 4 | `FOUND` | Read each `FACT`'s `EVIDENCE` and the standards on its `REQUIRES` lines: `resolve-architecture-profile.ps1 -Repo "<WORKSPACE>" -Target . -Profile <the profile on that REQUIRES line> -Show "<that line's ids>"` (by profile, not by path: a path the fix deleted no longer resolves). Then act as below. |
  | 3 | `BLOCKED` | Stop landing and show the `REQUIRE BLOCKED` lines. A reason `not in profile` → a human adds the standard or corrects the `structure-requires` pair; `needs human review` → a human reviews the standard and runs `accept-profile-delta.ps1`. Then re-run this check. |
  | 2 | (usage error) | Stop landing: the command is wrong. Fix it and re-run this check; never treat it as no structural changes. |
  | 1 | `FAILED` | Stop landing and show the `CHECK FAILED:` lines. Never treat a failed check as no structural changes. Land only if the user explicitly says to land without the check; record that under Skipped validations. |

  On `FOUND`:

  - A fact that complies with its standards and is not marked `UNEXPECTED`
    → continue.
  - Any `UNEXPECTED` fact → show the user the fact, its evidence and how its
    standards apply, and wait for their OK before continuing. List it under
    Deviations & surprises. A `profile-changed` fact is always `UNEXPECTED`:
    the fix changed the profiles its own changes are checked against. Name
    each changed file; a repair the user just made is theirs to OK.
  - A fact that breaks its standards but can be put right within them → fix
    it (respecting the commit policy) and re-run this check.
  - A departure from a standard, a choice the standards leave open, or a
    needed exception → stop landing, leave the work where it is, and propose
    `/cogniva-dev:plan-feature` for the decision (never auto-run it).

  Finding a structural change is never by itself a reason to leave
  quick-fix.

  No `pwsh`: Step 0 already settled it - skip this check only as agreed
  there, and say so under Skipped validations.

  ## Rules

  - Never push to a remote; never switch the user's branch uninvited.
  - Keep it small — a fix growing into a real feature → stop and suggest
    `/cogniva-dev:plan-feature`.
  - Follow-ups: the workflow returns `followups`; run the backlog gate
    exactly as execute-feature defines it (CAPTURE-BAR's route-first gate;
    write only confirmed deferrals, each with its `because:`, via
    `/cogniva-dev:backlog`). A fix that resolved a loose
    `BACKLOG.md` item: tick it and append `→ done` — a closure, not a
    capture, no gate needed.
  ````
- [ ] **Step 2 (WORKTREE.md):** In `plugins/cogniva-dev/skills/quick-fix/WORKTREE.md`, directly after the paragraph that ends `lands the fix on code the target already changed.` (end of `## Replaces Step 0`), add a new paragraph:
  ```markdown
  Then record `START_TREE` exactly as Step 0 says, in `WORKSPACE`, after any
  staleness merge is committed: the merge is not part of the fix.
  ```
- [ ] **Step 3 (CODEX.md):** In `plugins/cogniva-dev/skills/execute-feature/CODEX.md`, in `## After the loop`, replace the line `final commit AFTER the green gate), and the run finishes the same way every` with:
  ```markdown
  final commit AFTER the green gate; quick-fix also runs its structural check,
  between the repo obligations and the ADR check, exactly as its Step 2 says,
  and the architecture standards a task needs travel in its body, so both
  backends hand workers the same text), and the run finishes the same way every
  ```
- [ ] **Step 4 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`
- [ ] **Step 5 (write ADR):** scan `docs/adr/` for the next number and write ADR-C3 from `## Candidate ADRs` verbatim to `docs/adr/NNNN-quick-fix-checks-structural-changes-before-landing.md` per the adr skill's ADR-FORMAT (`**Provenance:** Suggested by agent`; no Relitigation line; keep its bullet list).
- [ ] **Step 6 (commit):** `git add plugins/cogniva-dev/skills/quick-fix/SKILL.md plugins/cogniva-dev/skills/quick-fix/WORKTREE.md plugins/cogniva-dev/skills/execute-feature/CODEX.md docs/adr/` then `git commit -m "feat(quick-fix): expected-change preflight and the structural check before landing"`

## Task 8: Document the contract and verify everything

**Files:**
- Modify: `plugins/cogniva-dev/docs/architecture-profiles.md`
- Modify: `docs/strategy.md`

- [ ] **Step 1 (profile keys):** In `plugins/cogniva-dev/docs/architecture-profiles.md`, replace
  ```markdown
  - `profile.yml` keys: `description` (required, one line), `inherits` (one
    parent profile id), `detect` (quoted file-name patterns, used only for
    suggestions). Any other key is an error.
  ```
  with
  ```markdown
  - `profile.yml` keys: `description` (required, one line), `inherits` (one
    parent profile id), `detect` (quoted file-name patterns, used only for
    suggestions), and the structural-change keys `structure-kinds`,
    `structure-detectors`, `structure-requires` and
    `structure-requires-dropped` (see [Structural changes](#structural-changes)).
    Any other key is an error.
  ```
- [ ] **Step 2 (index lines):** In the same file, replace
  ```markdown
  - `REVIEW: <id> - <profile> (<ownership>) <amendment|replacement> is <state>`:
    an item awaiting human review. A target whose profile has any review item
    is marked `NEEDS HUMAN REVIEW`.
  ```
  with
  ```markdown
  - `REVIEW: <id> - <profile> (<ownership>) <amendment|replacement> is <state>`:
    an item awaiting human review. A target whose profile has any review item
    is marked `NEEDS HUMAN REVIEW`.
  - `STRUCTURE DETECTORS:` and `STRUCTURE REQUIRES <kind>:` - the profile's
    structural-change policy, composed root first (see
    [Structural changes](#structural-changes)).
  ```
- [ ] **Step 3 (-Show list):** Replace
  ```markdown
  To read one standard's effective text, add `-Show <id>` with exactly one
  target.
  ```
  with
  ```markdown
  To read the effective text of one or more standards, add `-Show <id>` (or a
  comma-separated list of ids) with exactly one target.
  ```
- [ ] **Step 4 (JSON fields):** Replace
  ```markdown
  - per profile: `Chain`, `ChainDetail` (`Id`, `Ownership`: `library` or
    `repo-owned`), `Description`, `Standards` and `Review`;
  ```
  with
  ```markdown
  - per profile: `Chain`, `ChainDetail` (`Id`, `Ownership`: `library` or
    `repo-owned`), `Description`, `Standards`, `Review` and `Structure`
    (`Kinds`, `Detectors`, and `Requires`: each kind with its standard ids);
  ```
  and replace
  ```markdown
  - with `-Require`: `Require.Standards` and `Require.Blocked[]` (`Target`,
    `Standard`, `Reason`).
  ```
  with
  ```markdown
  - with `-Require` or `-Kinds`: `Require.Standards`, `Require.Kinds`,
    `Require.ByTarget[]` (`Target`, `Profile`, `Standards`, `UnknownKinds`)
    and `Require.Blocked[]` (`Target`, `Profile`, `Standard`, `Reason`).
  ```
- [ ] **Step 5 (new section):** Insert directly above the heading `## Where profiles are used`:
  ````markdown
  ## Structural changes

  A structural change adds or removes a unit, adds or removes a dependency
  between units, or moves code from one unit to another. What a unit is
  depends on the technology: in .NET it is a project. Which units are
  *owning* units is the repository's call
  (`architecture/ownership-and-placement.md`), so detectors report units and
  leave that judgement to the standards.

  ### Profile keys

  ```yaml
  structure-kinds:
    - unit-added
  structure-detectors:
    - dotnet-projects
  structure-requires:
    - "dependency-added architecture/dependency-direction.md"
  structure-requires-dropped:
    - "unit-added dotnet/build-settings.md"
  ```

  - `structure-kinds` names kinds of structural change. `cogniva-base`
    declares `unit-added`, `unit-removed`, `dependency-added`,
    `dependency-removed` and `code-moved`; a profile may declare more.
  - `structure-detectors` names the detectors the profile selects.
  - `structure-requires` items are `"<kind> <standard id>"`: a change of that
    kind depends on that standard. The kind must be declared by the profile
    or an ancestor.
  - All three add up down the chain, root first. A child removes a pair it
    inherits with `structure-requires-dropped`. Dropping a pair it does not
    inherit is a warning; requiring and dropping one pair in one profile is an
    error.
  - A pair naming a standard the profile does not provide is a warning, and a
    change of that kind is blocked until it is fixed.
  - The keys live in `profile.yml`, not in standard frontmatter: frontmatter
    is part of the text an amendment's `basis` hashes, so changing the mapping
    never makes an amendment STALE.
  - `-Kinds <kind,...>` on the resolver adds, per target, the standards its
    profile maps those kinds to, to the same gate as `-Require`. On success it
    prints `REQUIRE FOR <target> (<profile>): <ids>` for each target, which is
    that profile's own list to pass to `-Show`. Targets on different profiles
    can need different standards. `KIND NOT DECLARED:` names a listed kind a
    profile does not declare; it requires nothing.

  ### Detectors

  A detector is a plugin script, `scripts/structure-detectors/<id>.ps1`,
  named by id in `structure-detectors`. It runs as
  `pwsh -NoProfile -File <script> -Repo <repo> -Base <tree> -Head <tree>` and
  reports facts only: it never reads standards or decides what is allowed.
  Contract 1:

  - exit 0 and print one JSON object,
    `{ "contract": 1, "detector": "<id>", "facts": [ ... ] }`;
  - each fact has a `kind`, `units` (one or more, such as the two ends of a
    dependency), `paths` and `evidence` (one line a person can check).
    `paths` lists every repo-relative path the fact is about, because the
    profile of each one governs it: both ends of a dependency, for example;
  - `"facts": []` is the only way to say nothing was found. Any other exit
    code, missing or malformed JSON, or a missing script is a failed check.

  `dotnet-projects` (selected by `dotnet`) treats each project file
  (`*.csproj`, `*.fsproj`, `*.vbproj`) as a unit. It reports:

  - projects added or removed (a moved or renamed project file is both);
  - literal `<ProjectReference Include>` items added or removed, in project
    files and in `Directory.Build.props`/`.targets`. A reference in a
    `Directory.Build` file applies to every project under its folder, so all
    of those projects are among its paths;
  - files moved from one project's folder to another's. A file belongs to
    the project in its nearest folder that holds one, and files that move
    with their project are not reported. A move is caught when git pairs it
    as a rename (the contents are at least half the same). It is also caught,
    as a *possible* move, when a file is deleted from one project and a file
    with the same name is added to another. A move that also renames the file
    and rewrites most of it is not caught.

  It does not evaluate MSBuild. Other imported files, conditions and items
  added by targets are not followed, and an `Include` that uses a property or
  a wildcard is reported as written, marked `(unevaluated)`.

  ### The check

  ```powershell
  pwsh -NoProfile -File "<plugin>/scripts/check-structural-changes.ps1" -Repo . -Snapshot
  pwsh -NoProfile -File "<plugin>/scripts/check-structural-changes.ps1" -Repo . -Since <START_TREE> -Expected "dependency-added:src/A|src/B"
  ```

  `-Snapshot` records the working state as a git tree (tracked, staged,
  unstaged and untracked files; ignored files left out) and prints
  `START_TREE: <sha>`. It writes git objects only, never refs, the index or
  the working tree.

  `-Since` takes that tree, or any commit, and compares it with the working
  state now. Commits made since then and uncommitted work both count; work
  that was already dirty at the snapshot does not.

  - **Detectors.** The check runs every detector selected by any profile a
    marker in the repo declares, now or at the start. A change in a parent
    folder can affect units governed by markers below it.
  - **Gating.** It gates each fact with the standards its kind requires in
    the profile of each of its paths, under the same rule as `-Require`.
  - **Profiles at the start.** If the fix changed a `.cogniva-profile.yml` or
    anything under `.cogniva/`, each path is also governed by the profile its
    nearest marker named at the start, read from the start tree. Deleting a
    folder together with its marker therefore cannot hide the standards that
    governed it. Text output marks those requirements `at start`.
  - **Current text.** What every governing profile requires, and the review
    state of those standards, always comes from the profiles as they are now.
    Adding a missing standard or accepting a reviewed amendment clears a block
    on re-check. A profile named at the start that no longer exists is
    `FAILED`. Read a requirement's text by profile, not by path:
    `resolve-architecture-profile.ps1 -Target . -Profile <id> -Show "<ids>"`.
  - **Profile edits.** Any change to profile files since the start is a
    `profile-changed` fact, always `UNEXPECTED`, so it needs the user's OK.
  - **`-Expected`.** It takes `<kind>:<path>[|<path>...]` items. A fact is
    expected only when an item of its kind has paths containing every path
    of the fact; every other fact is marked `UNEXPECTED`.

  Add `-Format Json` for the machine-readable report.

  | `STRUCTURE:` | Meaning | Exit |
  |---|---|---|
  | `NONE` | no changes, or the detectors ran and found nothing | 0 |
  | `NOT-CHECKED` | no profile is declared in the repo, or the declared profiles select no detector | 0 |
  | `FOUND` | structural changes, each with `EVIDENCE` and `REQUIRES`; nothing blocked | 4 |
  | `BLOCKED` | a standard a change requires is missing (fix the profile's mapping or add the standard) or needs human review (review it, then `accept-profile-delta.ps1`) | 3 |
  | `FAILED` | a detector failed, was not found or broke the contract, or a declared profile is in `ERROR` | 1 |

  Usage errors exit 2. When several apply, `2` beats `1`, which beats `3`,
  which beats `4`. `quick-fix` snapshots at its start and runs the check
  before landing.
  ````
- [ ] **Step 6 (where used):** Directly after the bullet
  ```markdown
  - `plan-feature` resolves the profile for the paths a design touches, designs
    under its composed standards, asks before designing on standards that need
    human review, and restates the relevant standards in the plan's tasks.
    Executing agents see only what a plan's tasks restate.
  ```
  add
  ```markdown
  - `quick-fix` checks structural changes before landing (see
    [Structural changes](#structural-changes)). It gives a task the full text
    of the required standards only when the fix is expected to make such a
    change.
  ```
- [ ] **Step 7 (strategy):** In `docs/strategy.md`, replace
  ```markdown
  plan-feature designs under the resolved profile and applicable-rules reports it
  per target;
  ```
  with
  ```markdown
  plan-feature designs under the resolved profile, quick-fix checks structural
  changes against it before landing, and applicable-rules reports it per target;
  ```
- [ ] **Step 8 (verify everything):** Run each and expect it to pass:
  - `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → `All architecture-profile assertions passed.`
  - `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` → `All profile-library assertions passed.`
  - `pwsh -NoProfile -File plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1` → `All structural-changes assertions passed.`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1` → all PASS
  - `claude plugin validate .` → valid
- [ ] **Step 9 (commit):** `git add plugins/cogniva-dev/docs/architecture-profiles.md docs/strategy.md` then `git commit -m "docs(profiles): structural changes - profile keys, detector contract, the check"`
