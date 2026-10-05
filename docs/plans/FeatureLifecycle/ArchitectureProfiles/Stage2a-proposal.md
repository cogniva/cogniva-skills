# Architecture profiles — Stage 2a proposal (rev 3)

> Status: **proposal for review**. Not an executable plan; nothing has been
> implemented. Once approved, it becomes two `plan-feature` plans: Stage 2a.0
> (`module-deps`) and Stage 2a.
>
> - Rev 2 recorded D1–D8 and gave CognivaShell more evidentiary weight.
> - Rev 3.1 records D11 (option a), D12 and the softer shared-code wording.
> - Rev 3 drops `dotnet-modules` (D9) and refines the `cogniva-base` / `dotnet`
>   split (D10).
> - Because of D9, rev 3 also treats the old Module bundle as *legacy* rather
>   than something the library preserves, and re-scopes `repo-init` and
>   `add-module` accordingly.

**Stage 2a goal:**
- Put Cogniva's shared .NET principles, and the defaults we want future repos
  to follow, into the `dotnet` profile.
- Make repo-owned child profiles a tested contract.
- Point new repos at the future-facing `dotnet` conventions.
- Leave NewCogniva's production topology to its own child profile in Stage 2b.
- Repos that declare no profile see no change in behaviour.

---

## 0. Evidence and how it is weighed

| Source | Weight | Used for |
|---|---|---|
| `C:\dev\CognivaShell` (read-only) | **Highest** for common and future-facing conventions | A deliberate rethink after NewCogniva. Ports and adapters. The owning unit is an *engine*. A project's kind is its folder (`src/<Kind>/Cogniva.<Name>`). There is no `src/Modules/` and no layer bundle. Numbered rules in `docs/rules.md`. |
| `C:\dev\NewCogniva` (read-only) | Production reality, migration constraints, exceptions | `src/Modules/<Name>/` with a layered bundle and variants; regions; the `module-deps` fork. |
| This repo's template and the Stage 1 `dotnet` profile | What we ship today | NewCogniva-shaped. Treated as legacy from now on. |

The rule: a principle goes into the common profile when CognivaShell holds it,
or when both repos do. A convention goes into the common profile as a
*default for new repos* when it is the direction we want (CognivaShell)
and NewCogniva does not contradict it. Neither repo's current references set
policy on their own (§8).

| Principle or convention | CognivaShell | NewCogniva | Goes to |
|---|---|---|---|
| Dependencies point one way; no cycles between owning units | `docs/rules.md` R1 | AGENTS.md rule 1, plus the `allowed-cycles` list | `cogniva-base` |
| Hosts are the only composition roots, under `src/Hosts/` | R11 | `src/Hosts/AGENTS.md` | `cogniva-base` + `dotnet` |
| Composition-time registration is owned by the library, as `Add<Name>()` | R12 | `Add<Name>()` throughout (checked by grep); ADR-0010 | `dotnet` (D10.1 wording) |
| Outside systems sit behind ports owned by the unit, in separate projects | R3, R4, R8 | `<Name>.Infrastructure[.<System>]` | principle in `cogniva-base`; .NET expression in `dotnet`; naming per repo |
| Shared and published types have one clear owner | R2 | Contracts per Module; BuildingBlocks never reference Modules | `cogniva-base` + `dotnet` |
| Exceptions are narrow, named and recorded | R-numbered exceptions | ADRs, `allowed-cycles` | `cogniva-base` |
| The first folder under `src/` names a project's kind (or region); the repo defines the set | AGENTS.md: "A project's kind is its folder" | `src/Modules`, `src/Shell`, `src/BuildingBlocks`, `src/Hosts`, … | `dotnet` default convention |
| A project is created only when needed; no speculative shared projects | overview L71-72; AGENTS rule 8 | (not stated) | `dotnet` default convention |
| One target framework set centrally; nullable on; warnings are errors; tests mirror `src/` | yes (`net10.0`) | yes (`net10.0`) | `dotnet` |
| UI is Blazor libraries that do not depend on a particular host | glossary: "the layer of Blazor libraries" (not built yet) | rule 11 | `dotnet` default convention (D11) |
| `AGENTS.md` is canonical; `CLAUDE.md` contains only `@AGENTS.md` | yes | yes | repo-init template |
| `src/Modules/<Name>/` with a Contracts/Domain/Application/Infrastructure/Client/UI bundle | **no** | yes | **legacy**: NewCogniva's child profile (2b); the `add-module` scaffold |
| `Infrastructure.<System>`, `.UI.Controls`/`.UI.Routes`, foundation Modules, regions | no | yes | NewCogniva child profile (2b) |
| One project per engine, engine-owned steps, `<Engine>.Types`, `Ports/` folder | yes | no | a CognivaShell child profile, if it ever adopts |

---

## 1. Findings

| # | Finding | Consequence |
|---|---------|-------------|
| F1 | In Stage 1, a child-profile file at the same path as a parent standard **silently replaces** it. | Becomes an error (§3). |
| F2 | Refresh cannot tell a library update from a local edit. | Adoption records (§3.5). |
| F3 | `repo-init` copies a glossary template that does not exist. | §4.5. |
| F4 | Layer rules appear in six places, and the drift test enforces the duplication. | §4.4. |
| F5 | `applicable-rules` checks Hosts/Contracts with regexes that fire in every repo. | §4.3. |
| F6 | Three items are already in the backlog. | 2a closes them. |
| F7 | Neither `module-deps` nor its fork has region logic. | No region configuration (§4.0). |
| F8 | The Stage 1 `dotnet` profile *is* the legacy Module topology. | Reframed (§2). |
| F9 | **`repo-init` and `add-module` scaffold the legacy topology.** repo-init calls add-module for a first Module, and add-module only knows the bundle. | New repos must stop getting the legacy topology. add-module becomes a legacy-layout tool (§4.5, §4.6). |
| F10 | **`module-deps` is a legacy-layout tool.** It rolls projects up by `src/Modules/<Name>/` and has nothing to show for a CognivaShell-style repo. MSBuild already refuses project-level cycles, and CognivaShell has its own diagram tool. | 2a.0 still pays off for repos on the legacy layout (§4.0). Its long-term home is D12. |

---

## 2. The profile library

```text
cogniva-base                      technology-neutral principles
  └─ dotnet                       shared Cogniva .NET principles + future-facing default conventions
       ├─ newcogniva              (2b, repo-owned) legacy Module topology, regions, exceptions
       └─ <any repo>              (repo-owned, only where needed)
```

There is no managed topology profile: `dotnet-modules` is withdrawn (D9).

### 2.1 `cogniva-base` (technology-neutral)

| Standard | Status | Content |
|---|---|---|
| `architecture/ownership-and-placement.md` | reword | One owner per piece of behaviour ("owning unit as the repository defines it"). |
| `architecture/composition-roots.md` | keep | Composition roots wire things together and hold no behaviour. |
| `architecture/dependency-direction.md` | extend | Follow the declared direction. The graph between owning units is acyclic. The "public surface" bullet moves to the next row. |
| `architecture/shared-and-published-types.md` | **new** | A type published for others is owned by its publisher and changes with it. Types shared by everyone live in a small, slow-changing unit that references no owning unit. A published surface holds no implementation. |
| `architecture/external-integrations.md` | **new** | An outside system is reached only through a boundary (port) declared by the owning unit. Code specific to that system is isolated, normally in its own unit when warranted, and depends only on its owner and on what it needs to reach the system. |
| `architecture/exceptions.md` | **new** | Exceptions are narrow and named, and recorded with their reason where the rule lives (a child-profile amendment or a decision record). Existing code never justifies itself. |

### 2.2 `dotnet` (principles + default conventions)

New `profile.yml` description: "Cogniva's .NET architecture: shared principles
and the default conventions for new repos. Inherits cogniva-base. Repo-specific
topology belongs in a repo-owned child profile."

| File | Kind | Content |
|---|---|---|
| `standards/dotnet/projects-and-references.md` | principle | Projects are the unit of compile-time dependency. **The `ProjectReference` graph is the canonical internal project-to-project compile-time graph, and the one dependency tooling reads.** It is not the whole architecture graph. Other coupling (linked source via `<Compile Include … Link>`, which CognivaShell's jobs-store tests use; internal packages; reflection or assembly scanning; shared files; runtime protocol contracts) must be explicit where it exists, and may need separate analysis. References point downward according to the declared layering. Nothing references a runnable host except that host's tests. |
| `standards/dotnet/project-layout.md` | **default convention** | No project shape or bundle is mandatory, and a project is created only when it is needed. Shared code is extracted only when there is demonstrated reuse and a clear shared ownership boundary: a second occurrence is evidence to consider extraction, not an automatic trigger. Avoid speculative shared projects. The first folder under `src/` names a project's kind. `src/Hosts/` is the one fixed kind; the repo's glossary or child profile defines the rest. Tests mirror `src/`. One solution (`.slnx`) at the root. |
| `standards/dotnet/build-settings.md` | principle | One target framework, set centrally in `Directory.Build.props`. Nullable on, warnings as errors. A project overrides the target framework only for a platform host (e.g. `-windows`). The *value* lives in the repo-init template (D6). |
| `standards/dotnet/ui.md` | **default convention** (D11) | UI is Blazor component libraries that do not depend on a particular host, so the same UI can run in a web host and a desktop (BlazorWebView) host. What a UI may reference is the repo's decision (see §8). |
| `amendments/architecture/composition-roots.md` | principle | A composition root is a runnable host project under `src/Hosts/` (`applies-to: src/Hosts/**`). Hosts may reference wiring libraries next to them. **A library or capability that requires composition-time registration owns that registration entry point. In .NET, the conventional public entry point is named `Add<Name>()`. Libraries that require no registration do not need to provide one.** Hosts compose by calling those entry points. |
| `amendments/architecture/external-integrations.md` | principle | In .NET the isolated unit is a separate project. It references only the owning unit's projects and the system's SDK. Naming and placement belong to the repo (`Infrastructure.<System>`, `Connectors.<System>` and `.Store.File` are all valid local conventions). |
| `amendments/architecture/shared-and-published-types.md` | principle | In .NET these are projects. A shared-types project references no owning project. Published types live in a project owned by the publishing unit. No `applies-to` here, because where published surfaces live is the repo's decision. |

What leaves the library entirely (it moves to NewCogniva's child profile in 2b):
- `src/Modules/<Name>/`
- the six layer names and the per-layer edges
- `UI -> Contracts ONLY`
- "Hosts register Application or Client"
- the Module UI web/WPF host rule, as written for Modules

### 2.3 Architectural test of the level

T8 adds two fixtures, using invented names:
- **CognivaShell-shaped:** engines and adapters by folder, a published-types
  project.
- **NewCogniva-shaped:** a child that amends `dotnet/project-layout.md` to
  declare a Modules kind and regions, plus new standards for the layer bundle
  and its edges, a split UI, and an allowed cycle recorded as an exception.

Both must resolve on `dotnet` using `standards/` and `amendments/` only, with
**no `replacements/`**. Measured against the real repo, CognivaShell needs no
amendments to `dotnet` at all.

---

## 3. Child profiles: final semantics (D1, with refinements)

### 3.1 Files

```text
.cogniva/
  profiles/
    cogniva-base/ dotnet/            # managed: copies of the library
    newcogniva/                      # repo-owned: refresh never touches it
      profile.yml                    #   description + inherits (format unchanged)
      standards/<id>.md              #   NEW standards only
      amendments/<inherited id>.md   #   narrow change to an inherited standard
      replacements/<inherited id>.md #   whole-standard replacement (rare, conspicuous)
  managed/<id>.yml                   # adoption records (written by adopt only)
.cogniva-profile.yml                 # profile: <id>
<subtree>/.cogniva-profile.yml       # narrower declarations, unchanged from Stage 1
```

`profile.yml` does not change. The only additions are two optional frontmatter
keys (`basis`, `applies-to`) and the adoption records, all in the existing
YAML subset.

### 3.2 Rules

- `standards/` takes **new ids only**. A same-id file there is an **ERROR
  (ambiguous)**, and the message points to `amendments/` or `replacements/`.
- `amendments/` are composed on top of the inherited text, root first. Every
  level can amend, including library profiles: `dotnet` amends `cogniva-base`.
- `replacements/` supersede the inherited text and every ancestor amendment.
  Every output reports them as `REPLACED - no longer receives <parent> updates`.
- One profile may not both amend and replace the same id (ERROR).

### 3.3 `basis` and normalisation

`basis` is the first 12 hex characters of SHA-256 over the **normalised
inherited text**: the base (or nearest replacement) plus ancestor amendments,
in chain order, frontmatter included.

Normalisation:
- strip the BOM;
- CRLF and CR become LF;
- trim trailing whitespace on each line;
- drop trailing blank lines;
- **drop every `basis:` line**, so that re-acknowledging an ancestor does not
  make its descendants stale.

Adoption-record hashes use the same normalisation.

### 3.4 States: resolution vs permission to mutate

| Delta state | Meaning |
|---|---|
| `CURRENT` | basis matches |
| `STALE` | the inherited text changed since review |
| `UNREVIEWED` | no basis yet |
| `ORPHANED` | the amended id no longer exists upstream |

**Resolution.**
- Any non-`CURRENT` delta leaves the target **`RESOLVED`**, with
  `NeedsReview: true` on the target and on the affected standard. A `Review[]`
  entry gives the profile, its ownership, and the old and new basis.
- The amendment still applies.
- Text output prints `NEEDS HUMAN REVIEW` under the `PROFILE:` line.
- `applicable-rules` reports `REVIEW_REQUIRED`.
- ERROR is reserved for the cases where resolution can't produce an answer:
  - malformed YAML or frontmatter;
  - a missing description;
  - an ambiguous same-id standard;
  - amend and replace of the same id in one profile;
  - a missing or cyclic parent.

**Permission to mutate (D10.3).**
- A skill that makes an architecture-dependent change must stop if **a
  standard it actually depends on** needs review. A stale standard it does not
  depend on never blocks it.
- Mechanism: the resolver takes `-Require <id,…>`. If any listed standard (or
  its deltas) needs review, it reports which and **exits 3**. Exit 0/1/2 keep
  their meanings.
- The dependency set is
  1. the fixed library ids the skill declares, plus
  2. any further standard the skill opens because the effective text pointed it
     there.

  It requires (1) up front, and re-checks with (1)+(2) before writing anything.

Which Stage 2a operations this applies to:

| Operation | Depends on | Gate |
|---|---|---|
| `add-module` on a declared repo (§4.6) | `dotnet/project-layout.md`, `dotnet/projects-and-references.md`, `architecture/composition-roots.md`, `architecture/shared-and-published-types.md`, plus the repo standards the effective layout names for its Module kind | **Yes** |
| `repo-init` | `dotnet/project-layout.md`, `dotnet/build-settings.md`, `architecture/composition-roots.md` | Calls `-Require` for consistency. It always passes, because it adopts fresh copies into an empty repo. |
| `plan-feature` (writes plans, not code) | the standards it applies | No hard stop. It lists the review items and asks before designing on them (one-sentence SKILL change). |
| `adopt` / `accept-profile-delta` | — | No gate: these are the operations that create and clear review state. |
| `module-deps` auto-commit | no standards | No gate. |
| Future profile-aware execute-feature / quick-fix | the standards their tasks apply | The same rule. Recorded in their existing backlog lines. |

`basis` detects that a parent changed, not that it now contradicts something.
There is deliberately no machine-readable rule language.

`accept-profile-delta.ps1 -Repo . -Profile <repo-owned> [-Standard <id> | -All]`
rewrites only `basis:` lines, and refuses managed profiles.

### 3.5 Managed profiles and refresh

`.cogniva/managed/<id>.yml` records `source`, `plugin-version` and the
normalised `content` hash.

| Repo copy | Record | Result |
|---|---|---|
| absent | — | `ADOPTED` + record |
| equals library | any | `UP-TO-DATE` (a missing record is written, which migrates Stage 1 adoptions) |
| equals the record, library newer | present | `REFRESHED`, no `-Force` |
| differs from the record | present | `LOCALLY-EDITED`, blocked. The message says to move the edit into a child profile; `-Force` replaces. |
| differs, no record | absent | `DIFFERS`, blocked; `-Force` replaces |

- `-Refresh` refreshes every managed profile.
- After writing, adopt prints a `REVIEW:` line for each repo-owned delta that
  went stale.
- The staged swap and rollback are unchanged.

### 3.6 Provenance

The resolver JSON adds:
- `ChainDetail` (`Id`, `Ownership`);
- for each standard: `Kind`, `ReplacedBy`, `Amendments[]` (`From`,
  `Ownership`, `Path`, `Description`, `State`), `AppliesTo`, `NeedsReview`;
- for each profile: `Review[]`;
- for each target: `NeedsReview` and `MatchedStandards`.

Existing fields stay. The new read-only `-Show <id>` prints the effective text
with a provenance line before each part. `applies-to` globs are
repo-relative, with `*` matching within a path segment and `**` across
segments.

---

## 4. Work items

### 4.0 Stage 2a.0 — `module-deps` (separate PR, first)

Still worth doing first (F10). It is independent, fixes real defects (the
plugin hangs forever on any cycle; Contracts and Client share the abbreviation
`C`), removes NewCogniva data from the plugin, and lets NewCogniva retire its
fork. Its scope is the **legacy Module layout**. It does not read profiles,
has no region configuration, and checks cycles only.

- **Change:**
  1. Port `-Check` and the cycle-safe depth from the fork. Make tiers
     deterministic (ordinal sorts).
  2. Remove `$moduleDesc`, the `Shell` bucket (Shell becomes `Other`) and the
     DocumentStore prose.
  3. Descriptions are display-only and come from the glossary's
     `## <Name> (Module)` entries. Missing or malformed entries show a
     placeholder and a warning. `-Check` never reads the glossary.
  4. `docs/architecture/allowed-cycles.txt`: same format as the fork; pair
     order is ignored.
  5. `-RepoRoot` defaults to the git top level.
  6. Opt-in `PostToolUse` hook for `.csproj` edits. It acts only when
     `.claude/cogniva-dev/policy.json` has `"moduleDepsCheck": true` (D8), and
     fails open.
  7. Stays compatible with Windows PowerShell 5.1.
  8. SKILL.md says plainly that this is the Module-layout tool.
- **Not in scope:**
  - how scripts outside Claude find the plugin (D7, deferred to 2b);
  - layer-rule checking;
  - region graphing;
  - unifying with CognivaShell's diagram tool.
- **Verify:**
  - `-Check` exits 0/1 and names the edge roles;
  - an allowed pair passes in either order;
  - a cyclic graph renders the same output on every run;
  - qualified projects roll up to their layer;
  - descriptions come from the glossary;
  - a malformed glossary changes neither the graph nor `-Check`;
  - the hook passes when the repo hasn't opted in or the file isn't a
    `.csproj`, and blocks when it has;
  - the leak test passes.
- **Compatibility:**
  - Output is unchanged, minus the NewCogniva descriptions.
  - The `allowed-cycles.txt` format is a superset of the fork's.
  - The fork keeps working until 2b.

### 4.1 Profile core (T1)

- **Files:** `profile-lib.ps1`, `resolve-architecture-profile.ps1`
  (including `-Show` and `-Require`, exit 3), `adopt-architecture-profile.ps1`,
  new `accept-profile-delta.ps1` (pwsh 7), and their tests.
- **Change:** all of §3.
- **Depends on:** nothing.
- **Verify:**
  - composition and the replacement cascade;
  - each ERROR case;
  - each delta state; STALE and ORPHANED stay `RESOLVED`;
  - `-Require` exits 3 only when a *required* standard needs review, and
    exits 0 when the stale standard is an unrelated one;
  - normalisation (CRLF, BOM, trailing whitespace, ancestor `basis:` edits);
  - each refresh outcome;
  - a repo-owned profile is byte-identical after `-Refresh`;
  - Stage 1 migration;
  - `accept` scope;
  - `-Show` provenance;
  - glob matching;
  - a three-level chain plus a subtree marker;
  - the resolver stays read-only and deterministic.
- **Compatibility:**
  - Existing JSON fields are unchanged.
  - The only break is F1, which nothing shipped or adopted relies on.

### 4.2 Library reframe (T2)

- **Files:** `profiles/cogniva-base/**` and `profiles/dotnet/**` per §2.
  The Stage 1 `dotnet/module-layout.md` and `dotnet/module-dependencies.md`
  are **deleted**. Their text is kept in the 2b migration guide (§4.7) as the
  starting point for NewCogniva's child.
- **Depends on:** T1.
- **Verify:**
  - every shipped profile resolves with no warnings;
  - every library delta is `CURRENT`;
  - the **legacy-topology leak check** passes: `dotnet` contains no
    `src/Modules`, no `<Name>.Domain` / `.Application` / `.Infrastructure` /
    `.Client` layer names, and no `Contracts ONLY`;
  - the §2.3 fixtures pass.
- **Compatibility:**
  - A Stage 1 adoption of `dotnet` refreshes cleanly and loses the Module
    standards; the refresh output points at the migration guide.
  - No real repo has adopted yet.

### 4.3 `applicable-rules` (T3)

| Target status | Placement checks |
|---|---|
| `RESOLVED` | The Host message fires iff the target matches `architecture/composition-roots.md` in `MatchedStandards`. The published-surface message fires iff it matches `architecture/shared-and-published-types.md`, i.e. only where a repo child supplies `applies-to` (NewCogniva's will, for `*.Contracts`). Prints `STANDARD:` lines and review reasons. |
| `NONE` | none |
| `UNDECLARED` / `UNAVAILABLE` / `ERROR` | today's regexes, unchanged |

- **Depends on:** T1, T2.
- **Verify:**
  - `dotnet` gives the Host message only;
  - a child with Contracts `applies-to` gives both messages;
  - `none` gives no messages;
  - legacy assertions are unchanged;
  - a stale delta gives `REVIEW_REQUIRED`.

### 4.4 One owner per fact; cross-host context (T4)

| Knowledge | Owner |
|---|---|
| Principles and default conventions | `cogniva-base` / `dotnet` |
| Legacy Module layout | the `add-module` skill (scaffold mechanics); NewCogniva's child profile (its rules, 2b) |
| What terms mean | glossary, with a link to the standard |
| Scaffold mechanics, the default TFM | `repo-init` and its templates |
| Repo topology and exceptions | that repo's child profile |

**Cross-host (D5).**
- Adopted standards are plain files in the repo.
- The template `AGENTS.md` is canonical and carries a short pointer with no
  rules in it: which profile, where the standards are, how deltas modify
  them, `-Show`, and to read them before adding a project or a reference.
- The template `CLAUDE.md` is exactly `@AGENTS.md`.
- The skills that need architecture context call the resolver. Codex ships
  the same `skills/` tree.
- No standards are `@`-imported.

**Drift, parity and leak tests:**
1. Template `AGENTS.md` contains the pointer and no rule lines.
2. Template `CLAUDE.md` is exactly `@AGENTS.md`.
3. Template glossary terms carry definitions and links only.
4. The legacy-topology leak check on `dotnet` (from T2).
5. Template `Directory.Build.props` sets what `dotnet/build-settings.md` names.
6. Skill-semantics pins: every context-needing skill resolves the profile, and
   `add-module` uses `-Require`.
7. Nothing under `plugins/` contains `NewCogniva`, `CognivaShell`, or either
   repo's distinctive unit names.

**Files:**
- `templates/repo/`: new `AGENTS.md`, `CLAUDE.md` shim, new
  `docs/glossary/README.md`, new `Directory.Build.props`.
- This repo's `docs/glossary/README.md`: Module, Contracts, Domain,
  Application, Infrastructure, Client and Module UI are re-labelled as
  *legacy Module layout (add-module)*. New dotnet-vocabulary terms are
  proposed, not yet written.
- `docs/strategy.md`: Conventions rewritten to the `dotnet` direction.
- `README.md`.

### 4.5 `repo-init` (T5): scaffold the future-facing shape

Today repo-init creates hosts plus a first legacy Module via add-module (F9).
Rev 3: it creates a repo aligned with `dotnet`. **The shape is D11 option (a)**, as follows;
the recommended default is below.

```text
<Repo>.slnx
Directory.Build.props          # from template: net10.0 (override tfm=), nullable, warnings-as-errors
AGENTS.md  CLAUDE.md           # canonical + @AGENTS.md
.cogniva-profile.yml           # profile: dotnet
.cogniva/profiles/{cogniva-base,dotnet}/  .cogniva/managed/
docs/glossary/README.md        # seed terms: Host, Composition root, Port, Adapter, Shared types, Published types
docs/plans/
src/Hosts/<Repo>.<Host>/       # chosen hosts: Web (ASP.NET Core) and/or Desktop (WPF + BlazorWebView)
tests/                         # mirrors src/ as projects appear
.editorconfig .gitattributes .gitignore .claude/
```

- **No first unit and no shared-types project.** "A project is created only
  when it is needed" (D11 option a).
- It no longer calls `add-module`.
- `docs/superpowers/*` is dropped from the scaffold.
- TFM:
  - the default comes from the template file;
  - `tfm=` overrides it;
  - `dotnet --list-sdks` must show an SDK able to build that TFM, or
    repo-init stops with a clear message;
  - no `global.json`;
  - the WPF host gets `<tfm>-windows`.
- Adopt and declare `dotnet`. Gather states this and lets you opt out. Without
  `pwsh`, print the commands.
- **Depends on:** T1, T2, T4, and **D11**.
- **Verify:**
  - skill-semantics pins: no `add-module` call, no `src/Modules`, no literal
    `net8.0`, and the template paths exist;
  - ⛔ manual gate: scaffold into a temp folder; `dotnet build` passes; the
    resolver reports `dotnet`, `UNIFORM`, with no review items; a missing SDK
    stops cleanly.
- **Compatibility:** affects new repos only.
- **Size:** moderate. It is a prose skill plus four template files. It fits
  in 2a once D11 is settled. If D11 cannot be settled, see §5 for the
  fallback.

### 4.6 `add-module` (T6): legacy-layout scaffolder

It stays in the plugin for repos on the legacy layout (D12). It is not
promoted to a profile, and it gets no new topology.

| Situation | Behaviour |
|---|---|
| `UNDECLARED` / no pwsh | Today's steps, unchanged (the migration promise). SKILL.md says it scaffolds the legacy Module layout. |
| Declared, and the effective `dotnet/project-layout.md` (with repo amendments) declares a Modules kind | This is NewCogniva after 2b. `-Require` the dependency set (§3.4); **stop if any of it needs review**. Read the effective text with `-Show`. Offer the layer kinds; the full set is a default scaffold, not a requirement. Wire edges per the repo's own standards. Offer variants only if the effective text names them; stop and ask if they are ambiguous. |
| Declared, and no Modules kind (a new-style repo) | Stop: "this repo does not use the legacy Module layout. Add projects per `dotnet/project-layout.md`." |
| `NONE` / `ERROR` | Stop with the reason. |

- **Depends on:** T1, T2.
- **Verify:** skill-semantics pins for each row and for `-Require`; a fixture
  where an unrelated stale standard does not block.
- **New-style repos get no scaffolding skill in 2a.** An `add-project` skill
  for kind-first repos is deferred (§9), because it needs the kind
  conventions to settle first.

### 4.7 Docs, ADRs, version (T8)

- `docs/architecture-profiles.md`:
  - hierarchy, delta folders, basis and review;
  - resolution vs mutation;
  - managed vs repo-owned;
  - `-Refresh`, `-Show`, `-Require`, `applies-to`.
- **Migration guide for 2b:** moving a legacy-layout repo onto `dotnet` with a
  child profile. It includes the retired Stage 1 Module standards as a
  starting point.
- The §2.3 fixtures and the acceptance test: one plugin tree serves a
  repo-init-shaped repo and a NewCogniva-shaped repo, with no leaks.
- Glossary proposals: Amendment, Replacement, Managed profile, Repo-owned
  profile, Port, Adapter, Shared types, Published types. Update *Architecture
  profile*. These are confirmed with you before anything is written.
- Offer a minor bump to `0.10.0`, across all three version files. 2a.0 gets
  its own bump offer.

---

## 5. Sequence

```text
2a.0  module-deps ─────────────────────────────── PR 1 (independent)

2a    T1 profile core
        └─ T2 library reframe
             ├─ T3 applicable-rules
             ├─ T4 single source, templates, cross-host
             │    └─ T5 repo-init
             └─ T6 add-module (legacy, gated)
                  └─ T8 docs, ADRs, fixtures, bump ─ PR 2
```

**Sequencing risk (resolved: D11 = a):** T5 waited on D11. Kept for the record: if D11 had not been settled by the time T4
lands, split T5 into its own follow-up PR (2a.1).
- 2a then ships with repo-init only lightly changed: the glossary-template fix
  and the TFM handling, still scaffolding the legacy layout, and **not**
  declaring `dotnet`, because declaring a profile its own scaffold
  contradicts would be worse than declaring none.
- No `dotnet-modules` is introduced to bridge the gap.

---

## 6. Candidate ADRs

- **C1** Child profiles change inherited standards by amendment. Replacement is
  explicit. A same-id file in `standards/` is invalid.
- **C2** A delta pins its normalised inherited text. A changed parent marks it
  as needing review; resolution continues. Contradiction is never inferred.
- **C3** Managed profiles carry an adoption record. Refresh is clean unless the
  managed copy was edited. Repo-owned profiles are never written by adopt.
  (Amends ADR 0040.)
- **C4** `dotnet` holds shared Cogniva .NET principles and the default
  conventions for new repos. Repo topology lives in repo-owned child profiles.
  The library ships no topology profile.
- **C5** Placement heuristics come from the resolved profile. Undeclared paths
  keep the legacy heuristics.
- **C6** An architecture-dependent mutation requires the standards it depends
  on to be free of review items. Unrelated review items never block it.
- **C7** (2a.0) `module-deps` ships no project data. Descriptions are
  display-only. Blocking enforcement is opt-in.

---

## 7. Decisions

**Settled:**

| | Decision |
|---|---|
| D1 | Delta design approved, with refinements (§3). |
| D2 | `Infrastructure.<System>` is not a convention. |
| D3 | No kind is mandatory; scaffold defaults are not requirements. |
| D4 | Descriptions are display-only, from the glossary. |
| D5 | `@AGENTS.md` only; the cross-host path is adopted files plus skills. |
| D6 | `net10.0` in the template; override with `tfm=`; check the SDK. |
| D7 | Deferred to 2b. |
| D8 | The blocking hook is opt-in. |
| D9 | No `dotnet-modules`. Legacy topology goes to the repo's child profile. |
| D10 | Split approved, with registration ownership, the `ProjectReference` scope, and mutation gating (§2.2, §3.4). |
| D11 | Option (a): a new repo is the minimal skeleton in §4.5, with no speculative unit, shared-types project, engine, Module or adapter. Both default conventions are confirmed: kind-first `src/<Kind>/` with `src/Hosts/` as the fixed composition-root kind, and host-neutral Blazor UI libraries when UI is present. The shared-code wording is softened (§2.2). |
| D12 | `add-module` and `module-deps` stay in cogniva-dev through 2a and 2b, documented as legacy Module-layout tools. After 2b, a backlog decision on whether they move into NewCogniva. Not resolved now. |

The proposal is approved in principle. Next step: the executable plan for
2a.0, at `docs/plans/FeatureLifecycle/ModuleDepsLegacyTool/`.

---

## 8. Production questions kept open (not policy)

Nothing in 2a states policy on any of these. `dotnet` is silent on what UI and
published-types projects may reference. 2b records the outcomes in NewCogniva's
child profile. The CognivaShell evidence is noted for your decision.

| Question | NewCogniva | CognivaShell |
|---|---|---|
| UI → Shell | ADR-0010, ADR-0070 | none ("Shell" means the repo itself) |
| UI → UI | ADR-0118, 0119, 0232; ADR-0226 conflicts | screens may reference controls, never another screen (the same split as ADR-0119) |
| UI → BuildingBlock | no ADR; conflicts with AGENTS.md rule 1 | UI may reference shared types and engines |
| Contracts/Domain → BuildingBlock | implied by ADR-0076 | `Model.Types → Common` (published types reference shared types) |
| `C3Data.Infrastructure → Shell.Abstractions` | no ADR | no analogue |
| `DocumentOrchestration.Contracts → DocumentStore.Contracts` | no ADR | no published-types → published-types edge |

---

## 9. Split, defer, or change

- **Split:**
  - 2a.0 (`module-deps`) goes first.
  - T5 can split into 2a.1 if D11 lags.
- **Defer:**
  - an `add-project` skill for kind-first repos (new backlog item, after D11
    and real use);
  - where `add-module` and `module-deps` live (D12, after 2b);
  - region graphing and layer-rule checking;
  - a CognivaShell profile;
  - execute-feature / quick-fix profile-awareness, which will follow C6 when
    built;
  - `python`;
  - D7.
- **Changed from rev 2:**
  - `dotnet-modules` is withdrawn;
  - `dotnet` gains `project-layout` and `ui` as default conventions;
  - `ProjectReference` is scoped as the compile-time graph, not the whole
    architecture graph;
  - registration wording is updated;
  - `-Require` and exit 3 are added for mutation gating;
  - repo-init scaffolds a future-facing skeleton;
  - add-module and module-deps are labelled legacy-layout tools;
  - the published-surface `applies-to` moves to repo children.

## 10. Stage 2b runway (now larger)

1. Adopt `dotnet`.
2. Create a repo-owned `newcogniva` profile (starting from the migration guide):
   - an **amendment to `dotnet/project-layout.md`** declaring the Modules kind
     and the regions;
   - **new standards** for the Module bundle, its per-layer edges, the Module
     UI rule, foundation Modules and the jobs layer;
   - a published-types amendment with `applies-to: *.Contracts`;
   - exceptions: `allowed-cycles` plus whatever Q1/Q2 decide;
   - `accept -All`.
3. Root marker `profile: newcogniva`, plus subtree markers for non-.NET trees.
4. Glossary `## <Name> (Module)` entries for the descriptions.
5. Set `moduleDepsCheck: true`; retire the fork and its hook script; decide D7.
6. AGENTS.md rule 1 becomes a pointer to the profile.
7. Decide D12.

## 11. Stage 1 design: what the evidence makes problematic

1. `dotnet` encodes the legacy topology, and the drift test pins it to the
   template (F8). Fixed by T2 and T4.
2. The glossary and `docs/strategy.md` present the Module bundle as *the*
   Cogniva convention. Fixed by T4.
3. Silent same-path replacement (F1). Fixed by T1.
4. Refresh cannot tell an update from an edit (F2). Fixed by T1.
5. **repo-init and add-module scaffold the legacy topology (F9)**, so Stage 1's
   "leave them untouched" assumption no longer holds. Fixed by T5 and T6.
6. No change needed: single inheritance, path markers, `MIXED`, the minimal
   `profile.yml`, and `detect` on `dotnet`.

## 12. Completion checklist

**2a.0**
- [ ] `-Check`, cycle-safe deterministic depth, either-order allowed cycles,
      display-only glossary descriptions, no project data, abbreviation fix,
      git-top-level `RepoRoot`, opt-in hook, SKILL marks it the Module-layout
      tool.
- [ ] Suite green and in the gate.
- [ ] Bump offered.
- [ ] Backlog item closed.

**2a**
- [x] D11 answered: option (a).
- [ ] T1: deltas, normalised basis, states, `NeedsReview`, ERROR cases,
      records, `-Refresh`, `-Show`, `-Require`/exit 3, `applies-to`,
      `accept`; Stage 1 migration; suite green.
- [ ] T2: `cogniva-base` +3; `dotnet` = principles + `project-layout` +
      `ui` + `build-settings` + 3 amendments; Stage 1 Module standards
      deleted; legacy-topology leak check and fixtures green.
- [ ] T3: placement checks come from the profile; legacy paths unchanged.
- [ ] T4: templates (`AGENTS.md`, `CLAUDE.md` shim, glossary,
      `Directory.Build.props`); this repo's glossary and strategy updated;
      tests 1–7 green.
- [ ] T5: repo-init scaffolds the D11 shape and declares `dotnet`; ⛔ gate passed.
- [ ] T6: add-module is legacy and gated with `-Require`; an unrelated stale
      standard does not block; new-style repos are stopped with guidance.
- [ ] T8: docs, migration guide, ADRs C1–C6, glossary confirmed, acceptance
      fixture green.
- [ ] Green gate, `claude plugin validate .` and manifest parity pass.
- [ ] Minor bump offered across all three files.
- [ ] Backlog: repo-init and applicable-rules items closed; add `add-project`
      and D12 items.
