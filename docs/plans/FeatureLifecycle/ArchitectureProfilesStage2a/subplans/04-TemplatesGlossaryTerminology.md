# 04 TemplatesGlossaryTerminology — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/ArchitectureProfilesStage2a
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** One owner per fact: the repo template points at the adopted profile
instead of restating rules, the glossaries define the new profile vocabulary,
and "legacy Module layout" becomes **Module bundle layout** everywhere.

**Architecture:** The template's canonical instructions move to
`templates/repo/AGENTS.md`, with `templates/repo/CLAUDE.md` reduced to exactly
`@AGENTS.md`; the template gains a seed glossary and a `Directory.Build.props`.
Drift between those templates and the `dotnet` profile is pinned by new
sections in `tests/profile-library/profile-library.tests.ps1` (created in
Sub-plan 02; it has a line `# --- sections appended by later sub-plans go above
this line ---` inside its `try` block — insert new sections directly above it).

**Read these first:** `plugins/cogniva-dev/templates/repo/CLAUDE.md`,
`docs/glossary/README.md`, `plugins/cogniva-skills/skills/glossary/GLOSSARY-FORMAT.md`,
`docs/strategy.md`, `README.md`, `plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1`.

**Constraints restated:** Glossary entries are `## Term` headings with tight
what-it-is definitions and an optional `_Avoid_:` line; general programming
concepts (Port, Adapter, composition root as Seemann's term) are not entries.
No real repository names (NewCogniva, CognivaShell, CognivaNewRepo, C3Data, …)
anywhere under `plugins/` except the two test files that hold the leak lists.

## File structure (locked)

```
plugins/cogniva-dev/templates/repo/AGENTS.md                     # NEW: canonical template instructions + profile pointer, no rules
plugins/cogniva-dev/templates/repo/CLAUDE.md                     # exactly @AGENTS.md
plugins/cogniva-dev/templates/repo/docs/glossary/README.md       # NEW: seed glossary (Host, Common types)
plugins/cogniva-dev/templates/repo/Directory.Build.props         # NEW: net10.0, nullable, warnings as errors
plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md # "Module bundle layout"
plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1  # template drift + plugin-wide leak sections
docs/glossary/README.md                                          # new entries, rewrites, relabels, Plan/Spec
docs/strategy.md                                                 # Conventions + Architecture profiles sections
README.md                                                        # cogniva-dev rows
plugins/cogniva-dev/skills/module-deps/SKILL.md                  # Module bundle layout wording
plugins/cogniva-dev/skills/module-deps/module-deps.ps1           # Module bundle layout wording (3 lines)
plugins/cogniva-dev/tests/module-deps/module-deps.tests.ps1      # wording + pinned phrase
.claude/cogniva-dev/green-gate.json                              # module-deps note wording
docs/adr/0041-module-deps-is-a-data-free-module-bundle-layout-tool.md  # renamed from ...-legacy-module-layout-tool.md; wording
plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md             # invented example names
plugins/cogniva-dev/skills/workflow-status/SKILL.md              # invented example name
plugins/cogniva-dev/skills/workflow-status/workflow-status.ps1   # invented example name (comment)
```

## Task 1: Templates and their drift tests

**Files:**
- Create: `plugins/cogniva-dev/templates/repo/AGENTS.md`, `plugins/cogniva-dev/templates/repo/docs/glossary/README.md`, `plugins/cogniva-dev/templates/repo/Directory.Build.props`
- Modify: `plugins/cogniva-dev/templates/repo/CLAUDE.md`, `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md`
- Test: `plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1`

- [x] **Step 1 (failing tests):** In `profile-library.tests.ps1`, add `$templates = Join-Path $plugin 'templates\repo'` below `$library = …`, and insert directly above `# --- sections appended by later sub-plans go above this line ---`:
  ```powershell
      # --- template drift: the template points at the profile and restates no rules ---
      $agents = Join-Path $templates 'AGENTS.md'
      $agentsText = if (Test-Path $agents) { Get-Content -Raw -LiteralPath $agents } else { '' }
      Check 'template AGENTS.md carries the profile pointer' ($agentsText -match '\.cogniva-profile\.yml' -and $agentsText -match 'resolve-architecture-profile\.ps1' -and $agentsText -match '-Show' -and $agentsText -match 'amendments/')
      Check 'template AGENTS.md states no architecture rules' ($agentsText.Length -gt 0 -and $agentsText -notmatch 'src/Modules' -and $agentsText -notmatch '->' -and $agentsText -notmatch 'references nothing' -and $agentsText -notmatch 'Contracts')
      Check 'template CLAUDE.md is exactly @AGENTS.md' ((Get-Content -Raw -LiteralPath (Join-Path $templates 'CLAUDE.md')).Trim() -ceq '@AGENTS.md')
      $glossary = Join-Path $templates 'docs\glossary\README.md'
      $glossaryText = if (Test-Path $glossary) { Get-Content -Raw -LiteralPath $glossary } else { '' }
      Check 'template glossary seeds Host and Common types' ($glossaryText -match '(?m)^## Host$' -and $glossaryText -match '(?m)^## Common types$')
      Check 'template glossary carries definitions and links only' ($glossaryText -notmatch '(?m)^\s*- ' -and $glossaryText -notmatch '->' -and $glossaryText -cnotmatch 'ONLY' -and $glossaryText -notmatch 'Module')
      $props = Join-Path $templates 'Directory.Build.props'
      $propsText = if (Test-Path $props) { Get-Content -Raw -LiteralPath $props } else { '' }
      $buildText = Get-Content -Raw -LiteralPath (Join-Path $library 'dotnet\standards\dotnet\build-settings.md')
      Check 'template Directory.Build.props sets net10.0, nullable and warnings as errors' ($propsText -match '<TargetFramework>net10\.0</TargetFramework>' -and $propsText -match '<Nullable>enable</Nullable>' -and $propsText -match '<TreatWarningsAsErrors>true</TreatWarningsAsErrors>')
      Check 'build-settings names every property the template sets' (@('TargetFramework', 'Nullable', 'TreatWarningsAsErrors' | Where-Object { $buildText -notmatch $_ }).Count -eq 0)
  ```
- [x] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` → FAIL on the template checks.
- [x] **Step 3:** Create `plugins/cogniva-dev/templates/repo/AGENTS.md`:
  ````markdown
  # Project conventions

  Definitions: docs/glossary/README.md.

  ## Architecture

  This repo's architecture standards are its adopted architecture profile, not
  this file. The root `.cogniva-profile.yml` names the profile, and its standards
  are plain Markdown under `.cogniva/profiles/<profile>/`. A repo-owned profile
  changes an inherited standard with a file under `amendments/` (or, rarely,
  replaces it under `replacements/`).

  Before adding a project or a project reference, read the standards that apply
  to the paths you will touch. With the cogniva-dev plugin installed:

  ```powershell
  pwsh -NoProfile -File "<cogniva-dev plugin>/scripts/resolve-architecture-profile.ps1" -Repo . -Target "<path>"
  ```

  Add `-Show <standard id>` to print one standard with its amendments composed
  in. Without the plugin, read the files under `.cogniva/profiles/` directly.

  ## Glossary protocol

  - `docs/glossary/README.md` is the shared glossary. Use its terms in every
    discussion and link them, e.g. [Host](docs/glossary/README.md#host).
  - New/changed domain terms: propose the entry, get confirmation, then write it.

  ## Plans

  - Plans: `docs/plans/`.

  ## Git / worktree workflow

  **Lean mode is the default**: the `cogniva-dev` skills work directly on your
  checkout and current branch. A clone opts into **worktree mode** — the
  **pristine-primary** model (isolated-worktree execution + primary-checkout
  guards) — by creating an untracked `.claude/cogniva-dev.local.json` containing
  `{ "worktrees": true }`. Absent/false/unreadable means lean. The tracked
  `.claude/cogniva-dev/` directory is repo config (the green gate), NOT the mode
  switch.

  In worktree mode, nothing Claude does lands on your checked-out branch outside
  a git worktree:

  - Claude does not edit the primary checkout directly, and does not
    `git switch`/`checkout` or move branches there. The plugin's guards enforce
    this; the only directly-editable paths here are gitignored scratch
    (`.explore/**`, `.plans-staging/**`) and tier-1 backlog files
    (`docs/plans/BACKLOG.md`, `docs/plans/<Module>/BACKLOG.md`).
  - All work - including plan/`state.md` files - is authored in a git worktree
    (created by `/cogniva-dev:plan-feature` / `execute-feature` / `quick-fix`) and
    fast-forward-merges into your branch.
  ````
  (This last section is the current `templates/repo/CLAUDE.md` section moved verbatim.) `<cogniva-dev plugin>` stays as written: it is a deliberate placeholder in the template, because the plugin's install path differs per machine.
- [x] **Step 4:** Overwrite `plugins/cogniva-dev/templates/repo/CLAUDE.md` with exactly one line: `@AGENTS.md` (plus the final newline).
- [x] **Step 5:** Create `plugins/cogniva-dev/templates/repo/docs/glossary/README.md`:
  ```markdown
  # Glossary

  One agreed meaning per domain term. Reference these in every discussion; propose new entries as terms emerge.

  ## Host

  A runnable project under `src/Hosts/` (a web app, or a WPF app with BlazorWebView), and the place where the application is wired together: its composition root. A Host composes libraries by calling their registration entry points (`Add<Name>()`) and holds no behaviour of its own; see [composition roots](../../.cogniva/profiles/cogniva-base/standards/architecture/composition-roots.md).
  _Avoid_: app shell, launcher

  ## Common types

  A small, slow-changing project of types used across the codebase. It references no project that owns behaviour, so anything may depend on it. It is an ordinary referenced project, not a Visual Studio Shared Project (`.shproj`) or linked source; see [common and published types](../../.cogniva/profiles/cogniva-base/standards/architecture/common-and-published-types.md).
  _Avoid_: shared types, shared project, utilities
  ```
- [x] **Step 6:** Create `plugins/cogniva-dev/templates/repo/Directory.Build.props`:
  ```xml
  <Project>
    <PropertyGroup>
      <TargetFramework>net10.0</TargetFramework>
      <Nullable>enable</Nullable>
      <ImplicitUsings>enable</ImplicitUsings>
      <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    </PropertyGroup>
  </Project>
  ```
- [x] **Step 7:** In `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md`, change "For repos on the legacy Module layout" to "For repos on the Module bundle layout".
- [x] **Step 8 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` → `All profile-library assertions passed.`
- [x] **Step 9 (commit):** `git add plugins/cogniva-dev/templates/repo plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` then `git commit -m "feat(templates): AGENTS.md is canonical and points at the profile; seed glossary and Directory.Build.props"`

## Task 2: This repo's glossary, strategy and README

**Files:**
- Modify: `docs/glossary/README.md`, `docs/strategy.md`, `README.md`

- [x] **Step 1 (glossary — relabel):** In `docs/glossary/README.md`, prefix the definition paragraph of each of **Module**, **Contracts**, **Domain**, **Application**, **Infrastructure**, **Client** and **Module UI** with `Part of the [Module bundle layout](#module-bundle-layout). ` (same paragraph, before the existing first word). Change nothing else in those entries.
- [x] **Step 2 (glossary — new entry before `## Module`):**
  ```markdown
  ## Module bundle layout

  The layout in which each [Module](#module) lives under `src/Modules/<Name>/` as a bundle of layer projects: [Contracts](#contracts), [Domain](#domain), [Application](#application), [Infrastructure](#infrastructure), an optional [Client](#client), and [Module UI](#module-ui). The `add-module` and `module-deps` skills support it for repos that use it. It is not the default for new repos, which follow the `dotnet` profile's default conventions.
  _Avoid_: legacy layout, Module architecture

  ```
- [x] **Step 3 (glossary — rewrite Host, add Common types after it):** Replace the `## Host` entry's definition and keep its `_Avoid_` line:
  ```markdown
  ## Host

  A runnable project under `src/Hosts/` (a web app, or a WPF app with BlazorWebView), and the only place an application is wired together: its composition root. A Host composes libraries by calling their registration entry points (`Add<Name>()` in .NET) and holds no behaviour of its own. In the [Module bundle layout](#module-bundle-layout), it registers each Module's [Application](#application) or [Client](#client).
  _Avoid_: app shell, launcher

  ## Common types

  A small, slow-changing project of types used across the codebase. It references no project that owns behaviour, so anything may depend on it. It is an ordinary referenced project, not a Visual Studio Shared Project (`.shproj`) or linked source.
  _Avoid_: shared types, shared project, utilities
  ```
- [x] **Step 4 (glossary — rewrite Vertical Slice):**
  ```markdown
  ## Vertical Slice

  The style of dividing a system by business capability rather than technical layer. In the [Module bundle layout](#module-bundle-layout), each slice is a [Module](#module).
  ```
- [x] **Step 5 (glossary — Plan and Spec):**
  ```markdown
  ## Plan

  An implementation plan under `docs/plans/<Module>/<Feature>/`, produced by `plan-feature` and executed by `execute-feature`.

  ## Spec

  A validated design document in `docs/specs/`, written before a [Plan](#plan).
  ```
- [x] **Step 6 (glossary — rewrite Architecture profile):**
  ```markdown
  ## Architecture profile

  A named set of declarative architectural standards for one kind of codebase (e.g. `dotnet`): a folder holding a `profile.yml` and Markdown files under `standards/`. It may inherit one other profile. It adds new standards under `standards/`, changes inherited ones with [Amendments](#amendment), or, rarely, supersedes them with a [Replacement standard](#replacement-standard); a same-name file in `standards/` is an error. A profile is either a [Library profile](#library-profile) or a [Repo-owned profile](#repo-owned-profile), and tools read only the repo's copies. Selected per path by a [Profile marker](#profile-marker).
  _Avoid_: stack, tech profile, template
  ```
- [x] **Step 7 (glossary — four new entries after `## Profile marker`):**
  ```markdown
  ## Amendment

  A file at `amendments/<id>.md` in an [Architecture profile](#architecture-profile) that adds to a standard the profile inherits. Amendments stack on the inherited text from the root profile down; they can add or narrow, never delete, and the standard keeps receiving updates from its parent. When the parent's text changes, the amendment is flagged for human review instead of being dropped.
  _Avoid_: override, patch

  ## Replacement standard

  A file at `replacements/<id>.md` that supersedes an inherited standard outright, along with every amendment above it. It stops receiving updates from its parent, and every resolver output says so. Rare by design; prefer an [Amendment](#amendment).
  _Avoid_: override, fork

  ## Library profile

  An [Architecture profile](#architecture-profile) shipped by the cogniva-dev plugin (`cogniva-base`, `dotnet`). A repo holds an adopted copy under `.cogniva/profiles/`; only the adopt script writes that copy, and a local edit blocks refresh. Changes specific to one repo belong in a [Repo-owned profile](#repo-owned-profile).
  _Avoid_: managed profile, built-in profile

  ## Repo-owned profile

  An [Architecture profile](#architecture-profile) a repository writes for itself under `.cogniva/profiles/`. It usually inherits a [Library profile](#library-profile) and adds the repo's own standards, amendments and exceptions. Adopt and refresh never touch it.
  _Avoid_: child profile, custom profile
  ```
- [x] **Step 8 (strategy):** In `docs/strategy.md`, replace the bullets of `## Conventions (canonical definitions: docs/glossary/README.md)` with:
  ```markdown
  - New .NET repos follow the `dotnet` [Architecture profile](glossary/README.md#architecture-profile):
    Cogniva's shared .NET principles plus default conventions - the first folder
    under `src/` names a project's kind, [Hosts](glossary/README.md#host) under
    `src/Hosts/` are the only composition roots, and UI is host-neutral Blazor
    libraries. `repo-init` adopts and declares it.
  - A repo's own layout and exceptions live in its
    [Repo-owned profile](glossary/README.md#repo-owned-profile). The
    [Module bundle layout](glossary/README.md#module-bundle-layout) is one such
    layout, supported by `add-module` and `module-deps`.
  - Every repo keeps a glossary at `docs/glossary/README.md` (seeded by repo-init)
    and grows it propose-then-confirm.
  - Plans in `docs/plans/`.
  ```
  In `## Architecture profiles`, after the first sentence, add: "Library profiles are copied in with an adoption record (`.cogniva/adopted/<id>.yml`) so a refresh can tell a library update from a local edit; a repo's own rules go in a [Repo-owned profile](glossary/README.md#repo-owned-profile) that amends or adds to them."
- [x] **Step 9 (README):** In `README.md`: the cogniva-dev row's "Development-specific skills for the Module architecture" → "Development-specific skills: the feature lifecycle, ADRs, backlog, .NET scaffolding and architecture profiles"; the `repo-init` row → "Scaffold a brand-new .NET repo on the `dotnet` architecture profile"; the `add-module` row → "Add a Module to a repo on the Module bundle layout"; the `module-deps` row's "Legacy Module layout:" → "Module bundle layout:"; "Then run the `repo-init` skill in an empty repo, or `add-module` in an existing one." → "Then run the `repo-init` skill in an empty repo (or `add-module` in a repo on the Module bundle layout)."
- [x] **Step 10 (check):** `grep -n "Module bundle layout" docs/glossary/README.md docs/strategy.md README.md` → hits in all three; `grep -n "superpowers" docs/glossary/README.md docs/strategy.md` → none.
- [x] **Step 11 (commit):** `git add docs/glossary/README.md docs/strategy.md README.md` then `git commit -m "docs: glossary gains the profile vocabulary and Module bundle layout; strategy follows dotnet"`

## Task 3: Module bundle layout rename and the plugin-wide leak check

**Files:**
- Modify: the module-deps, gate, ADR 0041, backlog-format and workflow-status files in the locked structure
- Test: `plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1`, `plugins/cogniva-dev/tests/module-deps/module-deps.tests.ps1`

- [x] **Step 1 (failing test):** In `profile-library.tests.ps1`, insert directly above `# --- sections appended by later sub-plans go above this line ---`:
  ```powershell
      # --- plugin-wide leak check: no real repository or unit names ship in the plugin ---
      # (module-deps.tests.ps1 and this file hold the lists themselves.)
      $names = @('NewCogniva', 'CognivaShell', 'CognivaNewRepo', 'C3Data', 'DocumentOrchestration', 'DocumentStore', 'GovernanceOrchestration', 'StructureInsights')
      $leaks = @(Get-ChildItem -LiteralPath $plugin -Recurse -File | Where-Object { $_.Name -notin 'module-deps.tests.ps1', 'profile-library.tests.ps1' } | ForEach-Object {
          $file = $_
          $text = Get-Content -Raw -LiteralPath $file.FullName -ErrorAction SilentlyContinue
          foreach ($n in $names) { if ($text -and $text -cmatch "\b$n\b") { "$([System.IO.Path]::GetRelativePath($plugin, $file.FullName)): $n" } }
      })
      Check "no real repository names under plugins/cogniva-dev ($($leaks -join '; '))" ($leaks.Count -eq 0)
      # This file is excluded: its own check label below names the phrase it forbids.
      $stale = @(Get-ChildItem -LiteralPath $plugin -Recurse -File | Where-Object { $_.Name -ne 'profile-library.tests.ps1' -and (Get-Content -Raw -LiteralPath $_.FullName -ErrorAction SilentlyContinue) -match '(?i)legacy Module[- ]layout' } | ForEach-Object Name)
      Check "no 'legacy Module layout' wording remains ($($stale -join ', '))" ($stale.Count -eq 0)
  ```
  In `module-deps.tests.ps1`, change line 1's "the module-deps legacy Module-layout tool" to "the module-deps Module bundle layout tool", and the check `'SKILL.md calls it the legacy Module-layout tool' ($skillText -match 'legacy Module-layout tool')` to `'SKILL.md calls it the Module bundle layout tool' ($skillText -match 'Module bundle layout tool')`.
- [x] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` → FAIL naming `BACKLOG-FORMAT.md: C3Data`, `workflow-status` files, and the module-deps files.
- [x] **Step 3 (rename):**
  - `plugins/cogniva-dev/skills/module-deps/SKILL.md`: the description's leading "Legacy Module-layout tool - " → "Module bundle layout tool - "; "**This is a legacy Module-layout tool.**" → "**This is the Module bundle layout tool.**".
  - `plugins/cogniva-dev/skills/module-deps/module-deps.ps1`: line 2 "# Legacy Module-layout tool." → "# Module bundle layout tool."; the two generated-output strings "(legacy Module-layout tool)" → "(Module bundle layout tool)".
  - `.claude/cogniva-dev/green-gate.json`: the `module-deps` note "Pins the legacy Module-layout tool:" → "Pins the Module bundle layout tool:".
  - `git mv docs/adr/0041-module-deps-is-a-data-free-legacy-module-layout-tool.md docs/adr/0041-module-deps-is-a-data-free-module-bundle-layout-tool.md`; in it, the heading → `# module-deps is a data-free Module bundle layout tool with an opt-in cycle check` and "graphs only the legacy `src/Modules/<Name>/` layout that" → "graphs only the Module bundle layout (`src/Modules/<Name>/`) that". This is terminology only; the decision and its provenance do not change.
- [x] **Step 4 (invented example names):**
  - `plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md`: `C3Data/ModelUiFoundation` → `Billing/InvoiceUiFoundation`; `C3Data/BulkExport` (both occurrences) → `Billing/BulkExport`; "(like the C3Data Backlog A/B/C stubs)" → "(like a Module's Backlog A/B/C stubs)".
  - `plugins/cogniva-dev/skills/workflow-status/SKILL.md` and `plugins/cogniva-dev/skills/workflow-status/workflow-status.ps1`: `c--WorkingGit-CognivaNewRepo` → `c--dev-MyRepo`.
- [x] **Step 5 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` → `All profile-library assertions passed.`; `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/module-deps/module-deps.tests.ps1` → passes; `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/check-adrs.ps1 -Workspace .` → exit 0; `grep -rn -i "legacy module" README.md .claude docs/adr docs/glossary docs/strategy.md` → no output.
- [x] **Step 6 (commit):** `git add -A plugins/cogniva-dev/skills/module-deps plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md plugins/cogniva-dev/skills/workflow-status plugins/cogniva-dev/tests .claude/cogniva-dev/green-gate.json docs/adr` then `git commit -m "chore: 'Module bundle layout' replaces 'legacy Module layout'; no real repo names in the plugin"`
