# 06 AddModule — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/ArchitectureProfilesStage2a
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** `add-module` is the scaffolder for the Module bundle layout: unchanged
in undeclared repos, gated on the standards it depends on in declared
Module-bundle repos, and a clear stop in repos that follow the `dotnet`
profile's default layout.

**Architecture:** A prose-skill change to
`plugins/cogniva-dev/skills/add-module/SKILL.md`. In a declared repo it reads
the effective `dotnet/project-layout.md` with the resolver's `-Show`, and gates
with `-Require` (exit 3 = a standard it depends on needs human review; review
items on other standards never block it — ADR C6, written in Sub-plan 01). The
gate's behaviour is proven by a fixture in `tests/profile-library`; the skill's
wording is pinned in `tests/skill-semantics`.

**Read these first:** `plugins/cogniva-dev/skills/add-module/SKILL.md`,
`plugins/cogniva-dev/docs/architecture-profiles.md`,
`plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` (append
sections directly above its `# --- sections appended by later sub-plans go
above this line ---` line), `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`.

**Dependency set (the `-Require` list):** `dotnet/project-layout.md`,
`dotnet/projects-and-references.md`, `architecture/composition-roots.md`,
`architecture/common-and-published-types.md`, plus the repo standards the
effective layout text names for its Module kind. The skill file must stay
ASCII-safe for the PS 5.1 skill-semantics test.

## File structure (locked)

```
plugins/cogniva-dev/skills/add-module/SKILL.md                        # layout check, declared-repo gate
plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1   # add-module pins
plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1   # -Require fixture: unrelated stale standard does not block
```

## Task 1: Pins and the gate fixture

**Files:**
- Test: `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`
- Test: `plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1`

- [x] **Step 1 (skill pins):** Add `$am = ReadDoc 'skills\add-module\SKILL.md'` after the `$gc = …` line, and append before the final `if ($failures.Count -gt 0)`:
  ```powershell
  # --- add-module is the Module bundle layout scaffolder -------------------------
  Check 'add-module keeps the undeclared steps' ($am -match 'undeclared' -and $am -match 'dotnet new classlib -n <M>\.Contracts')
  Check 'add-module reads the effective layout with -Show' ($am -match '-Show dotnet/project-layout\.md')
  Check 'add-module gates a declared repo with -Require on its dependency set' ($am -match '-Require' -and $am -match 'dotnet/projects-and-references\.md' -and $am -match 'architecture/common-and-published-types\.md')
  Check 'add-module stops on exit 3' ($am -match 'Exit 3')
  Check 'add-module stops in a repo without a Modules kind' ($am -match 'does not use the Module bundle layout')
  Check 'add-module stops on none or error' ($am -match 'PROFILE: none')
  Check 'add-module scaffolds only the selected projects in a declared repo' ($am -match 'selected projects only' -and $am -match 'Application was chosen')
  ```
- [x] **Step 2 (gate fixture):** In `profile-library.tests.ps1`, insert directly above `# --- sections appended by later sub-plans go above this line ---`:
  ```powershell
      # --- add-module's gate: only the standards it depends on can block it -------
      $gate = New-DotnetRepo 'add-module-gate'
      Write-Fixture $gate '.cogniva/profiles/acme/profile.yml' "description: Acme's Module bundle layout on dotnet.`ninherits: dotnet`n"
      Write-Fixture $gate '.cogniva/profiles/acme/amendments/dotnet/project-layout.md' "---`ndescription: Acme adds a Modules kind.`n---`n`n- ``src/Modules/<Name>/`` is a kind: one folder per Module.`n"
      Write-Fixture $gate '.cogniva/profiles/acme/amendments/dotnet/ui.md' "---`ndescription: Acme UI note.`n---`n`n- Acme UI.`n"
      Write-Fixture $gate '.cogniva-profile.yml' "profile: acme`n"
      Invoke-Script $accepter @('-Repo', $gate, '-Profile', 'acme', '-All') | Out-Null
      $requireSet = 'dotnet/project-layout.md,dotnet/projects-and-references.md,architecture/composition-roots.md,architecture/common-and-published-types.md'
      $r = Resolve-Json $gate @('-Target', 'src/Modules', '-Require', $requireSet)
      Check "add-module's dependency set passes on a current profile" ($r.Code -eq 0)
      $uiFile = Join-Path $gate '.cogniva/profiles/acme/amendments/dotnet/ui.md'
      Write-Fixture $gate '.cogniva/profiles/acme/amendments/dotnet/ui.md' ((Get-Content -Raw -LiteralPath $uiFile) -replace 'basis: [0-9a-f]{12}', 'basis: aaaaaaaaaaaa')
      $r = Resolve-Json $gate @('-Target', 'src/Modules', '-Require', $requireSet)
      Check "a stale standard outside add-module's dependency set does not block it" ($r.Code -eq 0 -and $r.Json.Targets[0].NeedsReview -eq $true)
      $layoutFile = Join-Path $gate '.cogniva/profiles/acme/amendments/dotnet/project-layout.md'
      Write-Fixture $gate '.cogniva/profiles/acme/amendments/dotnet/project-layout.md' ((Get-Content -Raw -LiteralPath $layoutFile) -replace 'basis: [0-9a-f]{12}', 'basis: aaaaaaaaaaaa')
      $r = Resolve-Json $gate @('-Target', 'src/Modules', '-Require', $requireSet)
      Check 'a stale standard in the dependency set blocks add-module (exit 3)' ($r.Code -eq 3 -and @($r.Json.Require.Blocked.Standard) -contains 'dotnet/project-layout.md')
  ```
- [x] **Step 3 (run them):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → FAIL on the add-module pins (expected until Task 2). `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` → the three gate checks PASS already (they exercise Sub-plan 01's resolver); a failure there is a Sub-plan 01 defect to fix now.
- [x] **Step 4 (commit):** `git add plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1 plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` then `git commit -m "test(add-module): pin the layout check and prove its -Require gate"`

## Task 2: Rewrite the top of `add-module`

**Files:**
- Modify: `plugins/cogniva-dev/skills/add-module/SKILL.md`

- [x] **Step 1:** Replace the frontmatter and everything above `## Gather first (ask the user)` with:
  ````markdown
  ---
  name: add-module
  description: Use when adding a new Module to a repo on the Module bundle layout (src/Modules/<Name>/ with Contracts/Domain/Application/Infrastructure/UI projects, optional Client) - scaffolds the projects, wires references and tests, updates the glossary. Not for repos that follow the dotnet profile's default kind-first layout.
  ---

  # Add Module

  Add one Module named `<M>` (PascalCase, e.g. `Orders`) to a repo on the
  Module bundle layout. This skill scaffolds that layout only; it is not how
  projects are added to a repo that follows the `dotnet` profile's default
  layout. `<plugin>` is this plugin's root (the parent of `skills/`).

  ## First: which layout does this repo use?

  Run `pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo . -Target src/Modules`.

  | Result | What to do |
  |---|---|
  | No `pwsh`, or `PROFILE: undeclared` | Use the steps below unchanged. |
  | `PROFILE: none` or `PROFILE: error - ...` | Stop and report the reason. |
  | A resolved profile | Run the same command with `-Show dotnet/project-layout.md`. If the effective text declares a `src/Modules/` kind, follow **Declared repos** below. If it does not, stop: "This repo does not use the Module bundle layout. Add projects per `dotnet/project-layout.md`." |

  ### Declared repos

  1. Gate on the standards this change depends on:
     `pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo . -Target src/Modules -Require "dotnet/project-layout.md,dotnet/projects-and-references.md,architecture/composition-roots.md,architecture/common-and-published-types.md"`.
     Exit 3 means one of them needs human review: stop, show the
     `REQUIRE BLOCKED:` lines, and say that a human must review those standards
     and then run `accept-profile-delta.ps1` for the repo's own profile. Review
     items on other standards do not block this skill.
  2. Read the effective layout text and every repo standard it names for the
     Module kind (the bundle, its edges, its UI). Re-run the `-Require` call with
     those standard ids added before writing any file; exit 3 means stop, as above.
  3. Offer the layer projects the repo's standards name. The full set in the
     steps below is the default scaffold, not a requirement: the user may skip
     layers. Offer variants (for example a split UI) only if the effective text
     names them; if it is ambiguous about a variant, stop and ask.
  4. Run the steps below for the selected projects only. Steps 1, 2 and 4
     create, clean up and add to the solution just the projects the user chose;
     step 3 wires only edges between chosen projects, following the repo's own
     edge standards (where they differ from the list there, the repo's
     standards win); step 5 creates `<M>.Application.Tests` only if
     Application was chosen - otherwise ask which chosen project the tests
     target, or skip tests if the user says so; step 8 names only the
     registration the chosen projects allow. In an undeclared repo the
     selected projects are always the full set.
  ````
- [x] **Step 2:** In the existing steps: change step 1's first line to "Create the selected projects (in an undeclared repo, all of these) from repo root:"; change step 3's "Wire references (these ARE the dependency rules - no others allowed):" to "Wire references between the selected projects (in an undeclared repo these ARE the dependency rules - no others allowed; in a declared repo, wire per the repo's edge standards instead):"; in step 4, after "Add each new project to the solution explicitly", insert " (only the projects you created)". Leave every other existing step unchanged; Declared repos step 4 already says how steps 2, 5 and 8 follow the selection.
- [x] **Step 3 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`; `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` → `All profile-library assertions passed.` (its "no 'legacy Module layout' wording" check also covers this file).
- [x] **Step 4 (commit):** `git add plugins/cogniva-dev/skills/add-module/SKILL.md` then `git commit -m "feat(add-module): Module bundle layout scaffolder, gated on its standards in declared repos"`
