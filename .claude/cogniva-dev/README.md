# cogniva-dev repo config

This directory holds this repository's TRACKED cogniva-dev configuration —
today that is `green-gate.json` (below). It is NOT a mode switch: its presence
turns nothing on.

**Worktree mode** (isolated-worktree execution + primary-checkout guards) is a
per-clone, personal opt-in: an untracked `.claude/cogniva-dev.local.json`
containing `{ "worktrees": true }`. Default is lean — skills work directly on
your checkout. Worktree mode currently requires Claude Code; under Codex, work
in lean mode. See `plugins/cogniva-dev/docs/worktrees.md`.

## Where this repo differs from the template

- There is no `policy.json`: no branch-prefix policy and no Module cycle check.

## Green gate config — `green-gate.json`

The gate is everything a change to this repo must pass before it lands: plugin
validation, manifest parity, and the plugin test suites. Each `commands[]`
entry has a `run` (executed in order from the repo root; each must exit 0), a
`label`, and a `note` saying what the command pins. Add a suite by appending
one entry in the same style. Run the whole gate with
`powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .`;
it ends `green-gate: GREEN - all N command(s) exited 0.` when everything passes.

The full semantics (what a missing file or an empty `commands` list means, and
the optional `policy.json`) are in the copy of this README that `repo-init`
ships: `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md`.
