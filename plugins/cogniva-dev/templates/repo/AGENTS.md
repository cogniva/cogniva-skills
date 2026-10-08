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
