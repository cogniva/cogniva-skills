# 02 LibraryReframe — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/ArchitectureProfilesStage2a
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** Reframe the plugin's profile library: `cogniva-base` holds
technology-neutral principles, `dotnet` holds Cogniva's shared .NET principles
plus the default conventions for new repos, and neither carries the Module
bundle layout.

**Architecture:** Content-only changes under `plugins/cogniva-dev/profiles/`,
using the delta contract from Sub-plan 01 (`standards/` for new ids,
`amendments/` for changes to inherited ones, a `basis:` per amendment written
by `accept-profile-delta.ps1 -Library`). A new pwsh 7 suite,
`tests/profile-library/profile-library.tests.ps1`, pins the library and proves
both repo shapes it must serve resolve on `dotnet` without `replacements/`.

**Read these first:** `plugins/cogniva-dev/profiles/**` (Stage 1 content),
`plugins/cogniva-dev/scripts/accept-profile-delta.ps1`,
`plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1`,
`.claude/cogniva-dev/green-gate.json`.

**Constraints restated:** No real repository names (NewCogniva, CognivaShell,
or their unit names) anywhere under `plugins/`; fixtures use invented names
(`Acme`, `Orders`, `Billing`, `Pricing`). `dotnet` must contain no
`src/Modules`, no `.Domain` / `.Application` / `.Infrastructure` / `.Client`
layer names, and no `Contracts ONLY` (the **Module-bundle leak check**).
Standard frontmatter uses the strict YAML subset: `key: value` lines and block
lists of quoted values (`applies-to:` then `  - "src/Hosts/**"`); never a flow
list.

## File structure (locked)

```
plugins/cogniva-dev/profiles/cogniva-base/standards/architecture/ownership-and-placement.md   # reworded: owning unit as the repo defines it
plugins/cogniva-dev/profiles/cogniva-base/standards/architecture/composition-roots.md         # unchanged
plugins/cogniva-dev/profiles/cogniva-base/standards/architecture/dependency-direction.md      # extended: acyclic graph; public-surface bullet moves out
plugins/cogniva-dev/profiles/cogniva-base/standards/architecture/common-and-published-types.md # NEW
plugins/cogniva-dev/profiles/cogniva-base/standards/architecture/external-integrations.md     # NEW
plugins/cogniva-dev/profiles/cogniva-base/standards/architecture/architecture-exceptions.md   # NEW
plugins/cogniva-dev/profiles/dotnet/profile.yml                                              # new description
plugins/cogniva-dev/profiles/dotnet/standards/dotnet/projects-and-references.md              # NEW (principle)
plugins/cogniva-dev/profiles/dotnet/standards/dotnet/project-layout.md                       # NEW (default convention)
plugins/cogniva-dev/profiles/dotnet/standards/dotnet/build-settings.md                       # NEW (principle)
plugins/cogniva-dev/profiles/dotnet/standards/dotnet/ui.md                                   # NEW (default convention)
plugins/cogniva-dev/profiles/dotnet/amendments/architecture/composition-roots.md             # NEW
plugins/cogniva-dev/profiles/dotnet/amendments/architecture/external-integrations.md         # NEW
plugins/cogniva-dev/profiles/dotnet/amendments/architecture/common-and-published-types.md    # NEW
plugins/cogniva-dev/profiles/dotnet/standards/dotnet/module-layout.md                        # DELETE
plugins/cogniva-dev/profiles/dotnet/standards/dotnet/module-dependencies.md                  # DELETE
plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1                # drop the template drift check
plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1                          # NEW suite
.claude/cogniva-dev/green-gate.json                                                          # register the suite
docs/adr/NNNN-*.md                                                                           # ADR C4
```

## Candidate ADRs

### ADR-C4: dotnet holds shared principles and default conventions; repo layout lives in repo-owned profiles
**Provenance:** Suggested by human
**Relitigation:** Open to discussion
The `dotnet` library profile holds Cogniva's shared .NET principles and the
default conventions for new repos. A repository's own layout - the Module
bundle layout included - and its exceptions live in its repo-owned profile, and
the library ships no layout-specific profile.
**Write with:** Task 2

## Task 1: Rewrite `cogniva-base` and `dotnet`

**Files:**
- Modify/Create/Delete: the profile files in the locked structure above
- Modify: `plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1`

Write every file below exactly (LF line endings, a final newline).

- [ ] **Step 1:** `plugins/cogniva-dev/profiles/cogniva-base/standards/architecture/ownership-and-placement.md`:
  ```markdown
  ---
  description: Every piece of substantive behaviour has one owning unit, as the repository defines its units; name the owner before placing code, and stop when it is unclear.
  ---

  # Ownership and placement

  - Substantive behaviour - domain rules, persistence, evaluation, orchestration,
    and reusable logic - belongs to exactly one owning unit, as the repository
    defines its units (its glossary or its own profile names them). Name that
    owner before placing code.
  - A path suggested by a prompt or a plan is never enough to override a
    repository placement rule.
  - When the owner is unclear, or two applicable rules disagree about it, stop and
    ask for a human architecture decision instead of choosing one.
  ```
- [ ] **Step 2:** `.../cogniva-base/standards/architecture/dependency-direction.md`:
  ```markdown
  ---
  description: Dependencies follow the direction the repository declares, a new edge never bypasses it, and the graph between owning units has no cycles.
  ---

  # Dependency direction

  - Follow the dependency direction the repository declares. A new dependency
    edge that bypasses it is a design departure to surface, not a detail to
    implement.
  - The dependency graph between owning units is acyclic. A cycle is allowed only
    as a recorded exception (`architecture/architecture-exceptions.md`).
  ```
- [ ] **Step 3:** `.../cogniva-base/standards/architecture/common-and-published-types.md`:
  ```markdown
  ---
  description: Who owns the types other units use - published types belong to their publisher, common types to a small unit that depends on no owning unit; neither holds implementation.
  ---

  # Common and published types

  - Types a unit publishes for others to use are owned by that unit and change
    with it. Consumers depend on the published types, never on the unit's
    implementation.
  - Types every unit may use live in a small, slow-changing common unit that
    references no owning unit.
  - A published or common surface holds no implementation: no persistence,
    orchestration, or domain behaviour lives there.
  ```
- [ ] **Step 4:** `.../cogniva-base/standards/architecture/external-integrations.md`:
  ```markdown
  ---
  description: Outside systems are reached only through a port the owning unit declares; code specific to one system is isolated and depends only on its owner and that system.
  ---

  # External integrations

  - An outside system (a database, an API, a file store, a message bus) is
    reached only through a boundary - a port - that the owning unit declares in
    its own terms. The owner depends on the port, never on the outside system.
  - Code specific to one outside system - the adapter that implements the port -
    is isolated from the owner, normally in its own unit when the system warrants
    it. It depends only on its owner and on what it needs to reach the system.
  ```
- [ ] **Step 5:** `.../cogniva-base/standards/architecture/architecture-exceptions.md`:
  ```markdown
  ---
  description: An exception to an architecture rule is narrow, named, and recorded with its reason where the rule lives; existing code never justifies itself.
  ---

  # Architecture exceptions

  - An exception to an architecture rule names exactly what it allows (these two
    units, this one edge) and nothing wider.
  - It is recorded with its reason where the rule lives: an amendment in the
    repository's own profile, or a decision record that profile points to.
  - Existing code is never its own justification. Code that breaks a rule without
    a recorded exception is a departure to surface, not a precedent.
  ```
  Leave `composition-roots.md` and `cogniva-base/profile.yml` unchanged.
- [ ] **Step 6:** `plugins/cogniva-dev/profiles/dotnet/profile.yml`:
  ```yaml
  description: Cogniva's .NET architecture - shared principles and the default conventions for new repos. Inherits cogniva-base; a repository's own layout belongs in a repo-owned profile.
  inherits: cogniva-base
  detect:
    - "*.slnx"
    - "*.sln"
    - "Directory.Build.props"
  ```
- [ ] **Step 7:** `.../dotnet/standards/dotnet/projects-and-references.md`:
  ```markdown
  ---
  description: Projects are the unit of compile-time dependency; the ProjectReference graph is the one internal dependency graph tooling reads, and any other coupling must be explicit.
  ---

  # Projects and references

  _Principle: applies to every repository on this profile._

  - A project is the unit of compile-time dependency. The `ProjectReference`
    graph is the canonical graph of internal project-to-project compile-time
    dependencies, and the one dependency tooling reads.
  - It is not the whole architecture graph. Other coupling - linked source
    (`<Compile Include="..." Link="..." />`), internal packages, reflection or
    assembly scanning, shared files, runtime protocol contracts - must be explicit
    where it exists, and may need separate analysis.
  - References point in the direction the repository declares.
  - Nothing references a runnable host project except that host's own tests.
  ```
- [ ] **Step 8:** `.../dotnet/standards/dotnet/project-layout.md`:
  ```markdown
  ---
  description: Default layout for new repos - the first folder under src/ names a project's kind, src/Hosts/ is the one fixed kind, and projects and shared code appear only when needed.
  ---

  # Project layout

  _Default convention for new repositories. A repository may change it with an amendment in its own profile._

  - No project shape or bundle of projects is mandatory. A project is created
    only when it is needed.
  - Shared code is extracted only when there is demonstrated reuse and a clear
    shared owner. A second occurrence is evidence to consider extraction, not an
    automatic trigger. Avoid speculative shared projects.
  - The first folder under `src/` names a project's kind: `src/<Kind>/<Project>/`.
    `src/Hosts/` is the one fixed kind; the repository's glossary or its own
    profile defines the rest.
  - Tests mirror `src/` under `tests/`.
  - One solution file (`.slnx`) at the repository root.
  ```
- [ ] **Step 9:** `.../dotnet/standards/dotnet/build-settings.md`:
  ```markdown
  ---
  description: One target framework set centrally in Directory.Build.props, nullable on, warnings as errors; only a platform host overrides the target framework.
  ---

  # Build settings

  _Principle: applies to every repository on this profile._

  - One target framework for the repository, set centrally in
    `Directory.Build.props` (`TargetFramework`). Projects do not repeat it.
  - Nullable reference types are on (`Nullable` is `enable`) and warnings are
    errors (`TreatWarningsAsErrors` is `true`).
  - A project overrides the target framework only when its platform requires it,
    such as a Windows desktop host (`<tfm>-windows`).
  - The framework value itself is chosen when the repository is created; this
    standard does not fix it.
  ```
- [ ] **Step 10:** `.../dotnet/standards/dotnet/ui.md`:
  ```markdown
  ---
  description: Default for new repos with UI - UI is Blazor component libraries that do not depend on a particular host, so one UI runs in web and desktop hosts.
  ---

  # UI

  _Default convention for new repositories. A repository may change it with an amendment in its own profile._

  - UI is built as Blazor component libraries (Razor class libraries) that do not
    depend on a particular host, so the same UI can run in a web host and in a
    desktop (BlazorWebView) host.
  - What a UI library may reference is the repository's decision, recorded in its
    own profile.
  ```
- [ ] **Step 11:** `.../dotnet/amendments/architecture/composition-roots.md`:
  ```markdown
  ---
  description: In .NET a composition root is a runnable host project under src/Hosts/; a library that needs registration owns its Add<Name>() entry point, and hosts call it.
  applies-to:
    - "src/Hosts/**"
  ---

  - In .NET a composition root is a runnable host project under `src/Hosts/`.
    Hosts may reference wiring libraries next to them.
  - A library or capability that requires composition-time registration owns that
    registration entry point. In .NET the conventional public entry point is named
    `Add<Name>()`. Libraries that require no registration do not need one.
  - Hosts compose by calling those entry points.
  ```
- [ ] **Step 12:** `.../dotnet/amendments/architecture/external-integrations.md`:
  ```markdown
  ---
  description: In .NET the adapter for an outside system is a separate project that references only its owner's projects and that system's SDK; naming is the repository's choice.
  ---

  - In .NET the isolated unit is a separate project. It references only the
    owning unit's projects and the outside system's SDK.
  - Its name and location are the repository's choice (for example
    `<Owner>.<System>` or `Connectors.<System>`).
  ```
- [ ] **Step 13:** `.../dotnet/amendments/architecture/common-and-published-types.md`:
  ```markdown
  ---
  description: In .NET common and published types are projects; a common-types project references no owning project, and published types live in a project the publisher owns.
  ---

  - In .NET common types and published types are projects.
  - A common-types project references no project that belongs to an owning unit.
  - Published types live in a project owned by the publishing unit. Where those
    projects sit is the repository's decision, so this standard declares no
    `applies-to`; a repository's own profile can add one.
  ```
- [ ] **Step 14:** Delete `plugins/cogniva-dev/profiles/dotnet/standards/dotnet/module-layout.md` and `.../module-dependencies.md` (`git rm`).
- [ ] **Step 15 (record the bases):** `pwsh -NoProfile -File plugins/cogniva-dev/scripts/accept-profile-delta.ps1 -Library -Profile dotnet -All` → three `ACCEPTED:` lines (one per amendment), exit 0. Each amendment now has a `basis:` line after `description:`.
- [ ] **Step 16 (drop the Stage 1 drift check):** In `plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` delete the `$template = …` line and the whole `# --- drift: dotnet standard vs the repo template it was extracted from ---` block (its three lines through the second `Check`). The Stage 1 rule text it compared no longer exists in the library.
- [ ] **Step 17 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → `All architecture-profile assertions passed.` (the shipped-library section adopts and resolves the new content with no warnings).
- [ ] **Step 18 (commit):** `git add -A plugins/cogniva-dev/profiles plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` then `git commit -m "feat(profiles): dotnet is shared principles plus default conventions; cogniva-base gains three standards"`

## Task 2: `profile-library` suite, gate registration, ADR C4

**Files:**
- Create: `plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1`
- Modify: `.claude/cogniva-dev/green-gate.json`
- Create: ADR C4 under `docs/adr/`

- [ ] **Step 1 (write the suite):** Create `plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1`:
  ```powershell
  #Requires -Version 7.0
  # Dependency-free tests for the shipped profile library and the scaffold
  # templates that must agree with it: library deltas are current, dotnet
  # carries no Module bundle layout, and both repo shapes the library serves
  # resolve on dotnet using standards/ and amendments/ only.
  $ErrorActionPreference = 'Stop'
  $here = Split-Path -Parent $MyInvocation.MyCommand.Path
  $plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
  $resolver = Join-Path $plugin 'scripts\resolve-architecture-profile.ps1'
  $adopter = Join-Path $plugin 'scripts\adopt-architecture-profile.ps1'
  $accepter = Join-Path $plugin 'scripts\accept-profile-delta.ps1'
  $library = Join-Path $plugin 'profiles'
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-profile-library-" + [guid]::NewGuid().ToString('N'))
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
  function Resolve-Json([string]$Repo, [string[]]$Extra) {
      $result = Invoke-Script $resolver (@('-Repo', $Repo, '-Format', 'Json', '-LibraryRoot', $library) + $Extra)
      $json = if ($result.Code -in 0, 1, 3) { $result.Out | ConvertFrom-Json } else { $null }
      [pscustomobject]@{ Code = $result.Code; Json = $json; All = $result.All }
  }
  function New-Repo([string]$Name) {
      $repo = Join-Path $root $Name
      New-Item -ItemType Directory -Path $repo -Force | Out-Null
      & git -C $repo init -q
      return $repo
  }
  # A repo with the shipped dotnet adopted and declared at the root.
  function New-DotnetRepo([string]$Name) {
      $repo = New-Repo $Name
      $a = Invoke-Script $adopter @('-Repo', $repo, '-Profile', 'dotnet', '-LibraryRoot', $library)
      if ($a.Code -ne 0) { throw "adopt failed: $($a.All)" }
      Write-Fixture $repo '.cogniva-profile.yml' "profile: dotnet`n"
      return $repo
  }

  try {
      # --- the shipped library ---------------------------------------------------
      $shipped = New-DotnetRepo 'shipped'
      $r = Resolve-Json $shipped @('-Target', 'src/Hosts/Acme.Web,src/Lib/Acme.Lib')
      $dotnet = $r.Json.Profiles.dotnet
      $ids = @($dotnet.Standards.Id)
      $expected = @('architecture/architecture-exceptions.md', 'architecture/common-and-published-types.md', 'architecture/composition-roots.md', 'architecture/dependency-direction.md', 'architecture/external-integrations.md', 'architecture/ownership-and-placement.md', 'dotnet/build-settings.md', 'dotnet/project-layout.md', 'dotnet/projects-and-references.md', 'dotnet/ui.md')
      Check 'dotnet resolves with no warnings' ($r.Code -eq 0 -and @($r.Json.Warnings).Count -eq 0)
      Check 'dotnet provides exactly the expected standards' ((($ids | Sort-Object) -join ',') -eq (($expected | Sort-Object) -join ','))
      Check 'every library delta is CURRENT' (@($dotnet.Review).Count -eq 0 -and $r.Json.Targets[0].NeedsReview -eq $false)
      $amended = @($dotnet.Standards | Where-Object { @($_.Amendments | Where-Object From -eq 'dotnet').Count } | ForEach-Object Id | Sort-Object)
      Check 'dotnet amends exactly composition-roots, external-integrations and common-and-published-types' (($amended -join ',') -eq 'architecture/common-and-published-types.md,architecture/composition-roots.md,architecture/external-integrations.md')
      Check 'no library profile uses replacements/' (@(Get-ChildItem -LiteralPath $library -Recurse -Directory -Filter 'replacements').Count -eq 0)
      Check 'composition-roots applies to src/Hosts/** only' ((@($r.Json.Targets[0].MatchedStandards) -join ',') -eq 'architecture/composition-roots.md' -and @($r.Json.Targets[1].MatchedStandards).Count -eq 0)

      # --- Module-bundle leak check: dotnet carries no Module bundle layout ------
      $dotnetText = (Get-ChildItem -LiteralPath (Join-Path $library 'dotnet') -Recurse -File | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
      Check 'Module-bundle leak check: no src/Modules in dotnet' ($dotnetText -notmatch 'src/Modules')
      Check 'Module-bundle leak check: no layer project names in dotnet' ($dotnetText -cnotmatch '\.(Domain|Application|Infrastructure|Client)\b')
      Check 'Module-bundle leak check: no "Contracts ONLY" in dotnet' ($dotnetText -notmatch 'Contracts ONLY')

      # --- fixture: a kind-first repo (engines and adapters by folder, a published-types project)
      $kind = New-DotnetRepo 'kind-first'
      foreach ($p in 'src/Hosts/Acme.Web/Acme.Web.csproj', 'src/Engines/Acme.Pricing/Acme.Pricing.csproj', 'src/Adapters/Acme.Pricing.Sql/Acme.Pricing.Sql.csproj', 'src/Types/Acme.Pricing.Types/Acme.Pricing.Types.csproj') {
          Write-Fixture $kind $p "<Project Sdk=`"Microsoft.NET.Sdk`" />`n"
      }
      $r = Resolve-Json $kind @('-Target', 'src/Hosts/Acme.Web,src/Engines/Acme.Pricing,src/Types/Acme.Pricing.Types')
      Check 'a kind-first repo resolves on dotnet with no repo-owned profile' ($r.Code -eq 0 -and $r.Json.Aggregate.Status -eq 'UNIFORM' -and @($r.Json.Profiles.dotnet.ChainDetail | Where-Object Ownership -ne 'library').Count -eq 0 -and $r.Json.Targets[0].NeedsReview -eq $false)
      Check 'in a kind-first repo only the host matches a placement standard' ((@($r.Json.Targets[0].MatchedStandards) -join ',') -eq 'architecture/composition-roots.md' -and @($r.Json.Targets[1].MatchedStandards).Count -eq 0 -and @($r.Json.Targets[2].MatchedStandards).Count -eq 0)

      # --- fixture: a Module-bundle repo on dotnet through a repo-owned profile --
      $bundle = New-DotnetRepo 'module-bundle'
      Write-Fixture $bundle '.cogniva/profiles/acme/profile.yml' "description: Acme's Module bundle layout on dotnet.`ninherits: dotnet`n"
      Write-Fixture $bundle '.cogniva/profiles/acme/amendments/dotnet/project-layout.md' "---`ndescription: Acme adds a Modules kind and regions.`n---`n`n- ``src/Modules/<Name>/`` is a kind: one folder per Module, holding its layer projects.`n- Regions group Modules: ``src/Modules/<Region>/<Name>/`` is also valid.`n"
      Write-Fixture $bundle '.cogniva/profiles/acme/standards/acme/module-bundle.md' "---`ndescription: Each Module is a bundle of Contracts, Domain, Application, Infrastructure, optional Client and UI projects.`n---`n`n# Module bundle`n"
      Write-Fixture $bundle '.cogniva/profiles/acme/standards/acme/module-edges.md' "---`ndescription: Per-layer reference edges inside and between Modules.`n---`n`n# Module edges`n"
      Write-Fixture $bundle '.cogniva/profiles/acme/standards/acme/split-ui.md' "---`ndescription: A Module's UI splits into a controls project and a routes project.`n---`n`n# Split UI`n"
      Write-Fixture $bundle '.cogniva/profiles/acme/amendments/architecture/architecture-exceptions.md' "---`ndescription: Acme's recorded exception - Orders and Billing may reference each other.`n---`n`n- Allowed cycle: Orders <-> Billing (docs/architecture/allowed-cycles.txt).`n"
      Write-Fixture $bundle '.cogniva/profiles/acme/amendments/architecture/common-and-published-types.md' "---`ndescription: Acme's published types are each Module's Contracts project.`napplies-to:`n  - `"src/Modules/*/*.Contracts`"`n  - `"src/Modules/*/*.Contracts/**`"`n---`n`n- A Module's published types live in its Contracts project.`n"
      Write-Fixture $bundle '.cogniva-profile.yml' "profile: acme`n"
      $x = Invoke-Script $accepter @('-Repo', $bundle, '-Profile', 'acme', '-All')
      $r = Resolve-Json $bundle @('-Target', 'src/Modules/Orders/Orders.Contracts/IOrders.cs,src/Hosts/Acme.Web')
      Check 'the Module-bundle profile accepts cleanly' ($x.Code -eq 0)
      Check 'a Module-bundle repo resolves on dotnet with standards/ and amendments/ only' ($r.Code -eq 0 -and $r.Json.Targets[0].Status -eq 'RESOLVED' -and $r.Json.Targets[0].NeedsReview -eq $false -and -not (Test-Path (Join-Path $bundle '.cogniva/profiles/acme/replacements')) -and @($r.Json.Profiles.acme.Standards | Where-Object ReplacedBy).Count -eq 0)
      Check 'its Contracts projects match the published-types standard' (@($r.Json.Targets[0].MatchedStandards) -contains 'architecture/common-and-published-types.md')
      Check 'its hosts still match composition-roots' (@($r.Json.Targets[1].MatchedStandards) -contains 'architecture/composition-roots.md')

      # --- sections appended by later sub-plans go above this line ---
  }
  finally {
      if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
  }

  if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
  Write-Host ''
  Write-Host 'All profile-library assertions passed.'
  exit 0
  ```
- [ ] **Step 2 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` → `All profile-library assertions passed.` A failure here is a defect in Task 1's content or in Sub-plan 01's scripts — fix it, do not weaken the check.
- [ ] **Step 3 (register in the gate):** In `.claude/cogniva-dev/green-gate.json`, insert after the `architecture-profile` entry:
  ```json
  { "run": "pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1", "label": "profile-library", "note": "Pins the shipped library (deltas current, Module-bundle leak check, kind-first and Module-bundle fixtures) and the scaffold templates that must agree with it; needs PowerShell 7." },
  ```
  Then `pwsh -NoProfile -Command "Get-Content -Raw .claude/cogniva-dev/green-gate.json | ConvertFrom-Json | Out-Null"` → no error.
- [ ] **Step 4 (write ADR):** scan `docs/adr/` for the next number and write ADR-C4 from this sub-plan's `## Candidate ADRs` verbatim (heading without the `ADR-C4:` label; keep `**Provenance:** Suggested by human` and `**Relitigation:** Open to discussion`) to `docs/adr/NNNN-dotnet-holds-shared-principles-and-default-conventions.md` per `plugins/cogniva-dev/skills/adr/ADR-FORMAT.md`. Run `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/check-adrs.ps1 -Workspace .` → exit 0.
- [ ] **Step 5 (commit):** `git add plugins/cogniva-dev/tests/profile-library .claude/cogniva-dev/green-gate.json docs/adr` then `git commit -m "test(profiles): profile-library suite with Module-bundle leak check and shape fixtures"`
