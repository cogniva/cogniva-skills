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

To read one standard's effective text, add `-Show <id>` with exactly one
target. It prints the standard (or the replacement standard that superseded it) and
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
  `repo-owned`), `Description`, `Standards` and `Review`;
- per standard: `Id`, `Description`, `From`, `Path`, `Overrides`, `ReplacedBy`
  (the profile whose replacement standard won, or null), `Amendments[]`
  (`From`, `Ownership`, `Path`, `Description`, `State`), `AppliesTo` and
  `NeedsReview`;
- per review item: `Standard`, `Profile`, `Ownership`, `Delta`, `State`,
  `Basis`, `Inherited`, `Path`;
- with `-Require`: `Require.Standards` and `Require.Blocked[]` (`Target`,
  `Standard`, `Reason`).

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
  suggestions). Any other key is an error.
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

## Where profiles are used

- `plan-feature` resolves the profile for the paths a design touches, designs
  under its composed standards, asks before designing on standards that need
  human review, and restates the relevant standards in the plan's tasks.
  Executing agents see only what a plan's tasks restate.
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
