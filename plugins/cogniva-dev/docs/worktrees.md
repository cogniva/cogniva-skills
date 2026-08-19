# Worktree mode — the per-clone switch

cogniva-dev's workflow skills run in one of two modes, decided PER CLONE by an
untracked config file:

- **Lean (default)** — no file, or `"worktrees": false`. Skills work directly on
  your current checkout and branch: no worktrees, no ledger, no `state.md`
  lifecycle. The quality steps still run — ADR discipline (`/adr`), the ADR
  check, and the repo's `green-gate.json`.
- **Worktree** — `.claude/cogniva-dev.local.json` at the repo root contains
  `{ "worktrees": true }`. Every workflow skill isolates its work in a git
  worktree that fast-forward merges into your checked-out branch, and the guard
  hooks enforce that nothing edits the primary checkout directly.

## Turning it on

```json
{ "worktrees": true }
```

in `.claude/cogniva-dev.local.json`, which must be listed in the repo's
`.gitignore`. The file is a personal, per-clone choice and is never committed —
committing it would flip the mode for everyone.

## What reads the switch

- **Skills** — plan-feature, execute-feature and quick-fix read their sibling
  `WORKTREE.md` overlay only when the switch is on. cleanup-work /
  cleanup-allwork short-circuit when it is off — they clean only what the
  worktree ledger tracks, and lean mode writes no ledger records. Branches you
  create yourself in lean mode are your own to prune.
- **Hooks** — `guard-primary-edit.js`, `guard-primary-git.js`, and
  `nudge-backlog-commit.js` allow everything when the switch is off or absent.
  All three read the switch through the shared `scripts/worktree-mode.js`
  predicate, so the mode check cannot drift between hooks.

## What `.claude/cogniva-dev/` means now

The tracked `.claude/cogniva-dev/` directory is NOT a mode switch. It is the
home of tracked whole-repo config: `green-gate.json` (runs in BOTH modes) and
the README. A repo can have a green gate without anyone using worktrees.
