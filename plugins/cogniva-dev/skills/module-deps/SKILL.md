---
name: module-deps
description: Legacy Module-layout tool - regenerate the Module dependency graph (docs/architecture/module-dependencies.html + .md) from the .csproj ProjectReference graph of a repo laid out as src/Modules/<Name>/, or check it for cross-Module cycles with -Check. Use when the user asks for the module dependency graph/map, deployment closure, "what modules does X need", a Module cycle check, or after adding/removing/re-referencing a Module project in such a repo. Pure script run - no build, no analysis required.
---

# module-deps

**This is a legacy Module-layout tool.** It understands one layout: projects
under `src/Modules/<Name>/` named `<Name>.<Kind>` (Contracts, Domain,
Application, Infrastructure, Client, UI), the layout `add-module` scaffolds.
Qualified projects such as `<Name>.Infrastructure.<System>` or
`<Name>.UI.<Part>` roll up to their kind. Projects under `src/Hosts/` are
hosts; every other project (shared libraries, shells, kernels) is outside the
graph. It reads no architecture profile and ships no project-specific data. A
repo that does not use this layout gets nothing useful from it.

The script is the whole engine. It parses the projects, rolls them up to
Modules, computes the transitive (deployment) closure, and detects cycles.
There is no build or restore, and no codebase reasoning is needed.

`<plugin>` is this plugin's root (the parent of this `skills/` dir).

## Regenerate the graph

```
powershell -NoProfile -File "<plugin>/skills/module-deps/module-deps.ps1"
```

Run it from anywhere inside the repo: `-RepoRoot` defaults to the git top
level of the current directory (pass it explicitly to graph another repo). It
writes two views:

- `docs/architecture/module-dependencies.html` (primary): self-contained, with
  two Mermaid diagrams (dependency graph and tiered-by-depth) plus styled
  tables. Open it in a browser.
- `docs/architecture/module-dependencies.md`: the same content as Markdown.

Both are UTF-8. By default the script **auto-commits** the two generated files
(and only those two) when they change, so a regen never leaves the working tree
dirty. A dirty primary checkout blocks unrelated feature integrations. The
commit stages ONLY the two graph files (never `add -A`), and is a no-op when
the graph is unchanged.

Optional parameters:
- `-RepoRoot <path>`: the repo to analyze (default: the git top level of the
  current directory).
- `-OutFile <path>` / `-HtmlFile <path>`: override the two output paths.
- `-NoCommit`: leave the regenerated files uncommitted.
- `-Open`: launch the HTML in a browser.

## Check for cycles (`-Check`)

```
powershell -NoProfile -File "<plugin>/skills/module-deps/module-deps.ps1" -Check
```

`-Check` computes the graph and lists every cross-Module cycle that
`docs/architecture/allowed-cycles.txt` does not allow, with the project kinds
that introduce each edge inside it. A cycle is a set of Modules that can all
reach each other (a strongly connected component), reported once as a whole:
`A -> B -> C -> A` is the one cycle `A <-> B <-> C`, not three pairs. It exits `0` when there are none and `1` when there
are. It writes nothing, commits nothing, and never reads the glossary. Any
caller can use it: a git hook, CI, a green gate, or you.

`docs/architecture/allowed-cycles.txt` is optional and repo-owned. It holds one
cycle per line, its Modules joined by `<->` in any order: `A <-> B`, or
`A <-> B <-> C`. A line allows exactly that set of Modules, so a cycle that
grows or shrinks needs a new line, and pairs never add up to approve a larger
cycle. `#` starts a comment; a trailing `# reason` is encouraged. Blank lines
are ignored. A line with fewer than two Modules, an empty name, or a repeated
Module is reported and allows nothing. Adding a line is a deliberate, reviewed
act.

## Module descriptions

The "Modules" table shows the first paragraph under each `## <Name> (Module)`
heading in the repo's `docs/glossary/README.md` (the entries `add-module`
writes). They are display-only. A missing glossary or a missing entry shows a
placeholder and never changes the graph or `-Check`. To describe a Module, add
or fix its glossary entry; never edit the generated files.

## Edit-time feedback hook (opt-in, Claude Code)

The plugin registers a `PostToolUse` hook that runs `-Check` after Claude edits
a `.csproj`. When the edit leaves a disallowed cycle, the hook hands Claude the
report and asks it to correct the reference. It cannot prevent the edit: a
`PostToolUse` hook runs after the file has already changed, so the edit stays
on disk until Claude fixes it. It acts only in repos whose tracked
`.claude/cogniva-dev/policy.json` contains `"moduleDepsCheck": true`.
Everywhere else it does nothing, and it fails open on any error.

The hook is feedback, not enforcement. Where cycles must never land, run
`-Check` in a completion gate (the repo's green gate, CI, or a git hook); that
is also the route under other hosts.

## What to report back

1. After a regeneration:
   - Confirm both output paths were written (the script prints two `Wrote ...`
     lines).
   - ALWAYS echo the full `file:///...` HTML URL the script prints (the line
     under "Open in a browser (copy this URL):") on its own line, so the user
     can copy it straight into a browser.
   - Pass `-Open` if they want it launched automatically.
2. Echo the `Modules:` line and any `Cycles:` line. Unless `-NoCommit` was
   passed, relay whether it committed the regenerated graph or reported it
   unchanged.
3. After `-Check`: relay `OK`, or the listed cycles and the kinds that
   introduce them.
4. If a cycle is reported, mention it should be reviewed: mutually dependent
   Modules ship as one deployment unit. Fix a reference, or allow the whole
   cycle deliberately.

Do NOT hand-edit the generated files or recompute the graph yourself; always
run the script. If the script errors, report the error verbatim, and do not
substitute a manually written graph. The HTML diagram needs internet (Mermaid
loads from a CDN); the tables render offline regardless.
