---
name: module-deps
description: Regenerate the Module dependency graph (docs/architecture/module-dependencies.html + .md) from the .csproj ProjectReference graph. Use when the user asks for the module dependency graph/map, deployment closure, "what modules does X need", or after adding/removing/re-referencing any Module project. Pure script run - no build, no analysis required.
---

# module-deps

Regenerates two views from the `.csproj` ProjectReference graph:
- `docs/architecture/module-dependencies.html` - primary, self-contained
  (two Mermaid diagrams - dependency graph + tiered-by-depth - rendered via
  CDN + styled tables). Open in a browser.
- `docs/architecture/module-dependencies.md` - same content as Markdown.

The architecture forces every cross-Module read through `<Name>.Contracts`, so
the `.csproj` references ARE the authoritative inter-Module dependency list. The
script is the whole engine: it parses the projects, rolls them up to Modules,
computes the transitive (deployment) closure, detects cycles, and writes both
files. No build/restore, no codebase reasoning needed.

## How to run

`<plugin>` = this plugin's root (the parent of this `skills/` dir). Run this from
the root of the repo you want the graph for, and pass that repo root explicitly
as `-RepoRoot` — the plugin ships outside the target repo, so the script cannot
infer it from its own location:

```
powershell -NoProfile -File "<plugin>/skills/module-deps/module-deps.ps1" -RepoRoot "<repoRoot>"
```

By default the script **auto-commits** the two generated files (and only those
two) when they change, so a regen never leaves the working tree dirty — a dirty
primary checkout blocks unrelated feature integrations (`git push .` into the
checked-out branch needs a clean tree). The commit stages ONLY the two graph
files (never `add -A`) and is a no-op when the graph is unchanged.

Optional parameters:
- `-RepoRoot <path>` the root of the repo to analyze; pass it explicitly (when
  omitted the script falls back to inferring from its own location, which is only
  correct for a loose in-repo install, not this plugin).
- `-OutFile <path>` defaults to `docs/architecture/module-dependencies.md`.
- `-NoCommit` leaves the regenerated files uncommitted in the working tree
  (e.g. when you want to stage them yourself as part of a larger commit).

## What to report back

1. Confirm both output paths written (the script prints two `Wrote ...` lines).
   ALWAYS echo the full `file:///...` HTML URL the script prints (the line under
   "Open in a browser (copy this URL):") on its own line so the user can copy it
   straight into a browser. Pass `-Open` if they want it launched automatically.
2. Echo the `Modules:` line and any `Cycles:` line the script printed. Unless
   `-NoCommit` was passed, also relay whether it committed the regenerated graph
   or reported it unchanged.
3. If a cycle is reported, mention it is expected to be reviewed (mutually
   dependent Modules ship as one deployment unit).

Do NOT hand-edit the generated files or recompute the graph yourself — always
run the script. If the script errors, report the error verbatim; do not
substitute a manually written graph. The HTML diagram needs internet (Mermaid
loads from a CDN); the tables render offline regardless.
