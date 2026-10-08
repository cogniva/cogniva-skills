# Architecture profiles

An architecture profile is a named set of declarative standards for one kind
of codebase. There are two kinds:

- **Library profiles** ship in the plugin's `profiles/` folder:
  `cogniva-base` (technology-neutral) and `dotnet` (Cogniva's shared .NET
  principles plus the default conventions for new repos). A repo uses one only
  after adopting it, and every tool reads only the repo's copy.
- **Repo-owned profiles** are written by a repo for itself under
  `.cogniva/profiles/`: its own layout, its extra standards, and its recorded
  exceptions.

Profiles form one inheritance chain, `cogniva-base -> dotnet -> <repo-owned>`:
each level adds to or narrows what it inherits.

## Use a profile in a repo

1. **Adopt it.** This copies the library profile, and every profile it inherits
   from, into `.cogniva/profiles/`:

   ```powershell
   pwsh -NoProfile -File "<plugin>/scripts/adopt-architecture-profile.ps1" -Repo . -Profile dotnet
   ```

   Each copy is recorded in `.cogniva/adopted/<id>.yml` with its source, the
   plugin version and a content hash. A profile with a record is a library
   copy; a profile folder without one is repo-owned, and adopt never writes it.

2. **Declare it** with a one-line `.cogniva-profile.yml`:

   ```yaml
   profile: dotnet
   ```

   At the repo root it is the default for the whole repo. In a folder it
   applies to that folder and everything below it. `profile: none` switches
   profiles off for a subtree (for example `docs/`). A repo with its own
   profile declares that one instead (`profile: <repo-owned id>`).

3. **Commit** the copies, the records and the marker.

To pick up library changes later, run adopt with `-Refresh` (every profile with
a record) or re-run it with `-Profile <id>`. The change reaches the repo as an
ordinary diff. Per profile the outcome is:

| Outcome | When | Written? |
|---|---|---|
| `ADOPTED` | no copy yet | copy and record |
| `UP-TO-DATE` | the copy equals the library | only a missing or out-of-date record |
| `REFRESHED` | the copy equals its record and the library is newer | copy and record |
| `LOCALLY-EDITED` | the copy differs from its record | nothing (exit 1) |
| `DIFFERS` | no record, and the copy is not a library copy | nothing (exit 1) |
| `REPLACED` | `LOCALLY-EDITED` or `DIFFERS`, re-run with `-Force` | copy and record |

A locally edited library copy belongs in a repo-owned profile instead: move
the change into its `amendments/` (or, rarely, `replacements/`), then refresh.
A Stage 1 adoption, which has no record, refreshes cleanly (`-Refresh` also
picks up a record-less copy that equals a current or Stage 1 library copy). A
refresh prints
`REMOVED: <id>/<file>` for every file it dropped.

`-Force` and every other write copy to a temporary folder and swap the copy in
only once it is verified; if anything fails, every existing copy is restored,
and if a restore itself fails the error says where each previous copy was left.

After writing, adopt prints a `REVIEW:` line for every amendment or replacement
standard in a repo-owned profile whose inherited text changed or was never
reviewed (see [Review state](#review-state)). Exit codes: `0` adopted,
refreshed or up to date; `1` blocked; `2` usage, profile or copy error.

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

Each path resolves on its own. A broken marker or profile marks only the paths
that use it as `ERROR`, with the file and line at fault. Exit codes are listed
under [Resolution vs permission to change](#resolution-vs-permission-to-change).

## Reading the standards

The resolver's report ends with the standards index of each resolved profile:
one entry per standard, id and description first, so an agent reads the
descriptions and opens only the standards it needs.

```text
Profile <id> (chain: <id> -> dotnet -> cogniva-base) - <description>
  STANDARD architecture/composition-roots.md [cogniva-base] - <description>
    <path of the base text>
    AMENDED BY dotnet (library, CURRENT): <path>
    APPLIES TO: src/Hosts/**
```

- `AMENDED BY <profile> (<ownership>, <state>)` - one line per amendment, root
  first.
- `REPLACED - no longer receives <parent> updates` - a replacement standard
  superseded the inherited text.
- `APPLIES TO:` - the globs that place the standard on paths.
- `REVIEW: <id> - <profile> (<ownership>) <amendment|replacement> is <state>`:
  an item awaiting human review. A target whose profile has any review item
  is marked `NEEDS HUMAN REVIEW`.
- `STRUCTURE DETECTORS:` and `STRUCTURE REQUIRES <kind>:` - the profile's
  structural-change policy, composed root first (see
  [Structural changes](#structural-changes)).

To read the effective text of one or more standards, add `-Show <id>` (or a
comma-separated list of ids) with exactly one target. It prints the standard (or the replacement standard that superseded it) and
then every amendment that applies, root first, each under a provenance line
naming the part, the
profile it came from, its ownership and its review state:

```powershell
pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo . -Target src -Show dotnet/project-layout.md
```

`-Show` is text only. Add `-Format Json` instead for the machine-readable
report:

- per target: `Status`, `Profile`, `Winner` and the `Considered` markers it
  shadowed, `Suggestion`, `NeedsReview` (its profile has a review item) and
  `MatchedStandards` (ids whose `applies-to` globs match the target);
- per profile: `Chain`, `ChainDetail` (`Id`, `Ownership`: `library` or
  `repo-owned`), `Description`, `Standards`, `Review` and `Structure`
  (`Kinds`, `Detectors`, and `Requires`: each kind with its standard ids);
- per standard: `Id`, `Description`, `From`, `Path`, `Overrides`, `ReplacedBy`
  (the profile whose replacement standard won, or null), `Amendments[]`
  (`From`, `Ownership`, `Path`, `Description`, `State`), `AppliesTo` and
  `NeedsReview`;
- per review item: `Standard`, `Profile`, `Ownership`, `Delta`, `State`,
  `Basis`, `Inherited`, `Path`;
- with `-Require` or `-Kinds`: `Require.Standards`, `Require.Kinds`,
  `Require.ByTarget[]` (`Target`, `Profile`, `Standards`, `UnknownKinds`)
  and `Require.Blocked[]` (`Target`, `Profile`, `Standard`, `Reason`).

## Writing a profile

```text
<id>/
  profile.yml
  standards/<area>/<name>.md       new standards
  amendments/<area>/<name>.md      additions to an inherited standard
  replacements/<area>/<name>.md    a whole inherited standard superseded (rare)
```

- Profile ids are lowercase letters, digits and `-` (the folder name is the
  id). `none` is reserved for markers.
- `profile.yml` keys: `description` (required, one line), `inherits` (one
  parent profile id), `detect` (quoted file-name patterns, used only for
  suggestions), and the structural-change keys `structure-kinds`,
  `structure-detectors`, `structure-requires` and
  `structure-requires-dropped` (see [Structural changes](#structural-changes)).
  Any other key is an error.
- A standard's id is its path under `standards/`, `amendments/` or
  `replacements/`, compared case-insensitively.
- `standards/` takes new ids only. A file there whose id the profile inherits
  is an ERROR: put a narrow change in `amendments/<id>` instead.
- Amendments stack on the inherited text from the root profile down. Every
  level can amend, library profiles included (`dotnet` amends `cogniva-base`).
  An amended standard keeps receiving its parent's updates.
- A replacement standard supersedes the inherited text and every ancestor
  amendment, and stops receiving the parent's updates. Replacements are rare;
  prefer an amendment.
- One profile may not both amend and replace one id, nor amend or replace an
  id from its own `standards/`.
- Frontmatter keys:
  - `description` (required in every standard, amendment and replacement
    standard): one line saying when the standard matters.
  - `basis` (amendments and replacement standards only): written by
    `accept-profile-delta.ps1`, see [Review state](#review-state). Elsewhere it
    is ignored with a warning.
  - `applies-to`: a block list of quoted, repo-relative globs that place the
    standard on paths. `*` matches within one path segment, `**` matches any
    number of whole segments. The most-derived declaration wins: an amendment
    that declares `applies-to` replaces the inherited globs, and a replacement
    standard uses only its own.

    ```yaml
    applies-to:
      - "src/Hosts/**"
    ```

  Any other key is ignored with a warning.
- Standards are declarative guidance. Workflow steps belong in skills.

## The YAML subset

Profile files, markers and standard frontmatter use a strict subset of YAML:
`key: value` lines, `key:` followed by indented `- item` lines, `#` comments,
and single- or double-quoted values. `applies-to` is always such a block list.
No nesting, flow lists (`[a, b]`), anchors, or multi-line strings. Quote any
value that starts with `*`, `[`, `{`, `&`, `!`, `|` or `>`. Quoted values are
taken literally: YAML escape sequences (`\"`, `''`) are not currently
supported, so a value cannot contain its own quote character. Every error
names the file and line.

## Review state

Each amendment and replacement standard records, in `basis:`, a hash of the
inherited text a human reviewed it against. That text is the base standard or
the nearest replacement standard, then each ancestor amendment, in chain
order, each file normalised and joined with line feeds; `basis` is the first
12 lowercase hex characters of its SHA-256. Normalisation strips a BOM, turns
every line ending into LF, drops every `basis:` line (so accepting an ancestor
never makes its descendants stale), trims trailing whitespace from each line
and drops trailing blank lines. Frontmatter is part of the text, so a changed
parent description counts as a change.

| State | Meaning |
|---|---|
| `CURRENT` | `basis` matches the inherited text |
| `STALE` | the inherited text changed since the review |
| `UNREVIEWED` | no `basis` yet |
| `ORPHANED` | nothing is inherited under that id any more (the parent removed or renamed it) |

All four still resolve: the delta applies and an orphaned one still appears as
a standard. Anything but `CURRENT` is a review item.

After a human has reviewed the change, record it:

```powershell
pwsh -NoProfile -File "<plugin>/scripts/accept-profile-delta.ps1" -Repo . -Profile <repo-owned id> -Standard <id>
pwsh -NoProfile -File "<plugin>/scripts/accept-profile-delta.ps1" -Repo . -Profile <repo-owned id> -All
```

It rewrites only `basis:` lines (inserting one after `description:` when
absent) and reports `ACCEPTED`, `UP-TO-DATE` or `ORPHANED` per delta. An
orphaned delta cannot be accepted (exit 1): retarget or delete it. It refuses
an adopted library profile, whose deltas are reviewed upstream; plugin
maintainers accept the library's own deltas with `-Library -Profile <id>`.

`basis` detects that a parent changed, not that it now contradicts something.

## Resolution vs permission to change

Resolution never stops on review state: a stale or unreviewed delta still
applies, and the report says so. Permission to change is separate. A skill
that makes an architecture-dependent change passes the standards it depends on
to `-Require`:

```powershell
pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo . -Target src/Modules -Require "dotnet/project-layout.md,dotnet/projects-and-references.md"
```

A listed standard blocks when a resolved target's profile lacks it or it needs
review (`REQUIRE BLOCKED: <target> <id> - <reason>`); the skill stops on exit
3. Review items on other standards never block it.

Exit codes: `0` every path resolved (including `MIXED` and `UNDECLARED`); `1`
the report lists at least one `ERROR` target (or `-Show`'s target did not
resolve); `2` a usage error (no report); `3` a standard named by `-Require` is
missing or needs human review. When several apply, `2` beats `1`, which beats
`3`.

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
  profile of each one governs it: both ends of a dependency, for example.
  A `kind` that no profile selecting the detector declares in
  `structure-kinds` breaks the contract, so a typo cannot slip past the
  standards that kind requires;
- `"facts": []` is the only way to say nothing was found. Any other exit
  code, missing or malformed JSON, or a missing script is a failed check.

`dotnet-projects` (selected by `dotnet`) treats each project file
(`*.csproj`, `*.fsproj`, `*.vbproj`) as a unit. It reports:

- projects added or removed (a moved or renamed project file is both);
- literal `<ProjectReference Include>` items a project gains or loses, from
  its own project file or from the `Directory.Build.props`/`.targets` it
  imports. As in MSBuild, a project imports only the nearest of each in its
  folder or above, so a new, nearer one replaces what a parent gave; and an
  `Include` resolves from the project's folder (from the imported file's
  with `$(MSBuildThisFileDirectory)`). The projects that get a reference
  from a `Directory.Build` file are among its paths;
- files moved from one project's folder to another's. A file belongs to
  the project in its nearest folder that holds one, and files that move
  with their project are not reported. A move is caught when git pairs it
  as a rename (the contents are at least half the same). It is also caught,
  as a *possible* move, when a file is deleted from one project and a file
  with the same name is added to another. A move that also renames the file
  and rewrites most of it is not caught.

It does not evaluate MSBuild. Other imported files (including a parent
`Directory.Build` file that a nearer one imports), conditions and items
added by targets are not followed, and an `Include` that uses any other
property or a wildcard is reported as written, marked `(unevaluated)`.

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

## Where profiles are used

- `plan-feature` resolves the profile for the paths a design touches, designs
  under its composed standards, asks before designing on standards that need
  human review, and restates the relevant standards in the plan's tasks.
  Executing agents see only what a plan's tasks restate.
- `quick-fix` checks structural changes before landing (see
  [Structural changes](#structural-changes)). It gives a task the full text
  of the required standards only when the fix is expected to make such a
  change.
- `applicable-rules` reports the profile for each target, takes its placement
  messages from `MatchedStandards`, and returns `REVIEW_REQUIRED` only for a
  review item on a standard the target matches; other review items are listed
  as `REVIEW:` notes.
- `repo-init` adopts and declares `dotnet` in a new repo.
- `add-module` gates with `-Require` in a declared repo on the Module bundle
  layout.

The scripts need PowerShell 7 (`pwsh`). Without it, plan-feature plans without
a profile, and applicable-rules reaches the same decisions it always did and
reports the profile as `UNAVAILABLE`.

A repo laid out as `src/Modules/<Name>/` (the Module bundle layout) moves onto
`dotnet` through a repo-owned profile: see
[module-bundle-migration.md](module-bundle-migration.md).
