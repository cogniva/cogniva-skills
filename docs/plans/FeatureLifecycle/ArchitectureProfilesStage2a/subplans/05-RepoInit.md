# 05 RepoInit — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/ArchitectureProfilesStage2a
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** `repo-init` scaffolds the minimal skeleton the `dotnet` profile's
default conventions describe, and adopts and declares `dotnet`, instead of a
first Module on the Module bundle layout.

**Architecture:** `repo-init` is a prose skill
(`plugins/cogniva-dev/skills/repo-init/SKILL.md`) that copies
`plugins/cogniva-dev/templates/repo/` (which Sub-plan 04 gave an `AGENTS.md`,
an `@AGENTS.md` `CLAUDE.md`, a seed glossary and a `Directory.Build.props`
pinned to `net10.0`). It no longer calls `add-module`. Its textual invariants
are pinned in `tests/skill-semantics/skill-semantics.tests.ps1`, and Task 3
runs the skill end to end into a temporary folder (this replaces the proposal's
manual ⛔ gate).

**Read these first:** `plugins/cogniva-dev/skills/repo-init/SKILL.md`,
`plugins/cogniva-dev/templates/repo/` (all files),
`plugins/cogniva-dev/profiles/dotnet/standards/dotnet/project-layout.md`,
`plugins/cogniva-dev/profiles/dotnet/standards/dotnet/build-settings.md`.

**Constraints restated (from the `dotnet` profile):** the first folder under
`src/` names a project's kind and `src/Hosts/` is the one fixed kind; a project
is created only when needed (no first unit, no shared-types project); one
`.slnx` at the root; one target framework set centrally in
`Directory.Build.props`, overridden only by a platform host (`<tfm>-windows`);
tests mirror `src/`. The skill file must stay ASCII-safe for the PS 5.1
skill-semantics test (avoid relying on non-ASCII characters in pinned phrases).

## File structure (locked)

```
plugins/cogniva-dev/skills/repo-init/SKILL.md                         # rewritten
plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1   # repo-init pins
```

## Task 1: Pin the new repo-init contract

**Files:**
- Test: `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`

- [x] **Step 1 (failing tests):** Add `$ri = ReadDoc 'skills\repo-init\SKILL.md'` after the `$gc = …` line, and append before the final `if ($failures.Count -gt 0)`:
  ```powershell
  # --- repo-init scaffolds the dotnet skeleton -----------------------------------
  Check 'repo-init no longer calls add-module' ($ri -notmatch 'add-module')
  Check 'repo-init scaffolds no src/Modules' ($ri -notmatch 'src/Modules')
  Check 'repo-init carries no literal net8.0' ($ri -notmatch 'net8\.0')
  Check 'repo-init drops docs/superpowers' ($ri -notmatch 'superpowers')
  Check 'repo-init checks the SDK before writing' ($ri -match 'dotnet --list-sdks')
  Check 'repo-init checks the newest SDK can write .slnx' ($ri -match '9\.0\.200' -and $ri -match 'newest listed SDK')
  Check 'repo-init asks for .slnx explicitly' ($ri -match 'dotnet new sln -n <Repo> --format slnx')
  Check 'repo-init adopts and declares dotnet' ($ri -match 'adopt-architecture-profile\.ps1' -and $ri -match 'profile: dotnet')
  Check 'repo-init gates with -Require like other architecture-dependent skills' ($ri -match '-Require')
  Check 'repo-init template files exist' ((@('templates\repo\AGENTS.md', 'templates\repo\CLAUDE.md', 'templates\repo\Directory.Build.props', 'templates\repo\docs\glossary\README.md') | Where-Object { -not (Test-Path (Join-Path $plugin $_)) }).Count -eq 0)
  ```
- [x] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → FAIL on the repo-init pins (the template files already exist from Sub-plan 04).
- [x] **Step 3 (commit):** `git add plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` then `git commit -m "test(repo-init): pin the dotnet-skeleton contract"`

## Task 2: Rewrite `repo-init`

**Files:**
- Modify: `plugins/cogniva-dev/skills/repo-init/SKILL.md`

- [ ] **Step 1:** Replace the whole file with:
  ````markdown
  ---
  name: repo-init
  description: Use when starting a brand-new .NET repo - scaffolds git, the solution, Directory.Build.props, the chosen hosts, AGENTS.md and a seed glossary, and adopts and declares the dotnet architecture profile
  ---

  # Repo Init

  Scaffold a new .NET repo on the `dotnet` architecture profile: the minimal
  skeleton its default conventions describe, and nothing speculative. Templates
  live at `<skill-base-dir>/../../templates/` (the plugin root's `templates/`
  folder); `<plugin>` below is that plugin root.

  ## Gather first (ask the user)

  1. Repo/solution name `<Repo>` (PascalCase, e.g. `OrderHub`).
  2. Hosts to create now: Web (ASP.NET Core), Desktop (WPF + BlazorWebView), or both.
  3. Target framework: the template's default (`net10.0`, in
     `templates/repo/Directory.Build.props`) unless the user passes `tfm=<tfm>`.
  4. Say that repo-init adopts the `dotnet` architecture profile and declares it
     at the repo root, and that they can opt out.

  repo-init creates no first unit, shared-types project, engine or adapter: under
  the profile, a project is created only when it is needed.

  ## Steps

  1. Verify the target directory is empty (or contains only `.git`). If not, stop and ask.
  2. Check the SDK before writing anything: run `dotnet --list-sdks`. With no
     `global.json` (repo-init never writes one), every `dotnet` command uses the
     newest listed SDK, so check that one. It must satisfy both:
     - its major version is at least the target framework's major version (the
       `10` in `net10.0`), so it can build that framework; and
     - it is 9.0.200 or later, so it can write the `.slnx` solution the
       profile requires.

     If either fails, stop with: "The newest installed .NET SDK (<version>)
     cannot scaffold this repo: it needs SDK <major> or later to build <tfm>, and
     9.0.200 or later for a .slnx solution. Install a newer SDK." An older
     `tfm=` (e.g. `net8.0`) is fine when a newer SDK is installed: SDK 10 builds
     `net8.0`.
  3. `git init` (then `git symbolic-ref HEAD refs/heads/main` if git < 2.28).
  4. Copy the whole plugin `templates/repo/` folder into the repo root:
     `AGENTS.md` (the canonical instructions), `CLAUDE.md` (exactly `@AGENTS.md`),
     `Directory.Build.props`, `docs/glossary/README.md`, `.gitignore`,
     `.editorconfig`, `.gitattributes`, and the whole `.claude/` folder. The
     tracked `.claude/cogniva-dev/` directory is repo **config**
     (`green-gate.json`), NOT a mode switch. Lean mode is the default - skills
     work directly on the checkout. Worktree mode (isolated-worktree execution +
     the `guard-primary-edit` / `guard-primary-git` guards) is a per-clone
     opt-in: an untracked `.claude/cogniva-dev.local.json` containing
     `{ "worktrees": true }`; absent/false/unreadable means lean.
     `.claude/settings.json` carries no unconditional branch-switch denies. An
     optional `.claude/cogniva-dev/policy.json` can require a development-branch
     prefix in lean mode (see the template README); it is absent by default. The
     `.gitignore` already ignores the AI's scratch dirs (`.explore/`,
     `.plans-staging/`). (The guards require `node` on PATH; without it they fail
     open - allow.)
  5. If the user passed `tfm=`, replace the `<TargetFramework>` value in the
     copied `Directory.Build.props`.
  6. Create `docs/plans/` with a `.gitkeep` file so git tracks it.
  7. `dotnet new sln -n <Repo> --format slnx` (always ask for `.slnx` explicitly;
     the default format differs between SDKs). Every `dotnet sln` command works
     with it.
  8. Hosts, as chosen. Each lives in `src/Hosts/<Repo>.<Host>/`:
     - Web: `dotnet new web -n <Repo>.Web -o src/Hosts/<Repo>.Web`; delete the
       `<TargetFramework>` line from `src/Hosts/<Repo>.Web/<Repo>.Web.csproj` so
       `Directory.Build.props` governs; `dotnet sln add src/Hosts/<Repo>.Web`.
     - Desktop: `dotnet new wpf -n <Repo>.Desktop -o src/Hosts/<Repo>.Desktop`;
       set its `<TargetFramework>` to `<tfm>-windows` (a platform host is the one
       allowed override);
       `dotnet add src/Hosts/<Repo>.Desktop package Microsoft.AspNetCore.Components.WebView.Wpf`;
       `dotnet sln add src/Hosts/<Repo>.Desktop`.

     `tests/` mirrors `src/` as projects appear; create no test project now.
  9. Architecture profile, unless the user opted out:
     - With `pwsh` on PATH: run
       `pwsh -NoProfile -File "<plugin>/scripts/adopt-architecture-profile.ps1" -Repo . -Profile dotnet`,
       then write `.cogniva-profile.yml` at the repo root containing
       `profile: dotnet`, then confirm with
       `pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo . -Target src -Require "dotnet/project-layout.md,dotnet/build-settings.md,architecture/composition-roots.md"`:
       it must exit 0 and print `PROFILE: dotnet` with no `NEEDS HUMAN REVIEW`.
       (A fresh adoption always passes; the `-Require` call keeps repo-init
       consistent with the other skills that change architecture.)
     - Without `pwsh`: write neither. Print both commands and the one-line
       marker for the user to run once PowerShell 7 is installed. A marker
       without an adopted profile would make every path an ERROR.
  10. `dotnet build` - must succeed.
  11. Recommend the user install this plugin in the new repo:
      `/plugin marketplace add cogniva/cogniva-skills` (or the path of your local clone) then `/plugin install cogniva-skills@cogniva`.
  12. Commit everything: `git add -A && git commit -m "chore: scaffold <Repo> via cogniva-skills"`.

  ## Rules baked into the scaffold

  The architecture rules live in the adopted profile under `.cogniva/profiles/`.
  `AGENTS.md` points to them and states none itself. Do not restate them ad hoc;
  link glossary terms such as [Host](docs/glossary/README.md#host).
  ````
- [ ] **Step 2 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`
- [ ] **Step 3 (commit):** `git add plugins/cogniva-dev/skills/repo-init/SKILL.md` then `git commit -m "feat(repo-init): scaffold the minimal dotnet skeleton and declare the dotnet profile"`

## Task 3: Scaffold check (automated; replaces the proposal's ⛔ gate)

**Files:** none changed unless the check finds a defect (then fix `SKILL.md` or the templates and re-run).

Follow the new `plugins/cogniva-dev/skills/repo-init/SKILL.md` literally, as a user would, with `<Repo>` = `ScaffoldCheck`, Web host only, default target framework, profile not opted out. `<plugin>` is this checkout's `plugins/cogniva-dev` (absolute path).

- [ ] **Step 1:** `$check = Join-Path ([System.IO.Path]::GetTempPath()) ('repo-init-check-' + [guid]::NewGuid().ToString('N'))`; create it, and run SKILL steps 1-10 inside it (skip step 11; run step 12's commit).
- [ ] **Step 2 (assert the build):** step 10's `dotnet build` exits 0, and `src/Hosts/ScaffoldCheck.Web/ScaffoldCheck.Web.csproj` contains no `<TargetFramework>` line.
- [ ] **Step 3 (assert the shape):** in `$check`: `CLAUDE.md` is exactly `@AGENTS.md`; `AGENTS.md`, `Directory.Build.props` (with `net10.0`), `docs/glossary/README.md`, `docs/plans/.gitkeep`, `ScaffoldCheck.slnx` and `.cogniva-profile.yml` (`profile: dotnet`) exist; there is no `src/Modules`, no `docs/superpowers`, and no project outside `src/Hosts/`; `.cogniva/adopted/dotnet.yml` and `.cogniva/adopted/cogniva-base.yml` exist.
- [ ] **Step 4 (assert the profile):** `pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo $check -Target src -Format Json` → exit 0, `Targets[0].Status` `RESOLVED`, `Targets[0].Profile` `dotnet`, `Aggregate.Status` `UNIFORM`, `Targets[0].NeedsReview` `false`. `git -C $check status --porcelain` → empty (step 12 committed everything).
- [ ] **Step 5 (assert the SDK stop):** apply SKILL step 2 to `tfm=net99.0` against this machine's `dotnet --list-sdks` → the newest SDK's major version is below 99, so the skill must stop before writing anything. Confirm the step's wording makes that outcome unambiguous; if it does not, fix the wording in `SKILL.md`.
- [ ] **Step 6 (assert an override):** scaffold a second repo the same way into `$override = Join-Path ([System.IO.Path]::GetTempPath()) ('repo-init-override-' + [guid]::NewGuid().ToString('N'))` with `<Repo>` = `OverrideCheck`, Web host only, `tfm=net8.0`. SKILL step 2 passes (the newest SDK here is 10.x: at least 8, and at least 9.0.200). Assert: `Directory.Build.props` contains `<TargetFramework>net8.0</TargetFramework>` and no `net10.0`; `OverrideCheck.slnx` exists and no `*.sln` file does; `src/Hosts/OverrideCheck.Web/OverrideCheck.Web.csproj` has no `<TargetFramework>` line; `dotnet build` exits 0. If the build fails only because the `net8.0` reference pack cannot be downloaded (no network), say so in the task result. The shape assertions still have to pass.
- [ ] **Step 7:** `Remove-Item -LiteralPath $check, $override -Recurse -Force`.
- [ ] **Step 8 (commit, only if a fix was needed):** `git add plugins/cogniva-dev/skills/repo-init/SKILL.md plugins/cogniva-dev/templates/repo` then `git commit -m "fix(repo-init): correct what the scaffold check found"` (name the specific defect in the commit body). Re-run `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` and `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` after any fix.
