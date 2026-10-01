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
