# cogniva-dev repo config

This directory holds this repository's TRACKED cogniva-dev configuration —
today that is `green-gate.json` (below). It is NOT a mode switch.

**Worktree mode** (isolated-worktree execution + primary-checkout guards) is a
per-clone, personal opt-in: an untracked `.claude/cogniva-dev.local.json`
containing `{ "worktrees": true }`. Default is lean — skills work directly on
your checkout. See the plugin's `docs/worktrees.md`.

`.claude/settings.json` carries NO unconditional branch-switch denies: lean is
the default and those denies block legitimate lean work — primary-checkout
branch protection is the job of the mode-aware `guard-primary-git` hook, which
the cogniva-dev plugin registers itself and which allows everything in lean mode.

## Branch policy — `.claude/cogniva-dev/policy.json`

Optional, tracked, and absent by default. It lets a repo require that lean-mode
work happens on a development branch rather than on `main`:

```json
{ "requiredDevelopmentBranchPrefix": "feature/" }
```

Semantics:

- **Lean mode only.** `/cogniva-dev:execute-feature` and `/cogniva-dev:quick-fix`
  check the current branch against the prefix BEFORE mutating anything. Worktree
  mode needs no check — its generated branches are `feature/<slug>` by
  construction.
- **Stop, never switch.** A branch that does not start with the prefix stops the
  run with one clear line naming the branch and the required prefix. The skills
  never create a branch, and never switch to one, to satisfy the policy —
  choosing the branch stays with the user.
- **Absent = no policy.** No file, an unreadable file, or a file without
  `requiredDevelopmentBranchPrefix` means no check and no behaviour change.

## Green gate config — `.claude/cogniva-dev/green-gate.json`

`/cogniva-dev:execute-feature` and `/cogniva-dev:quick-fix` run a **green gate** in the
worktree before integrating a change into your branch. What the gate runs is this
repo's decision, declared here:

```json
{
  "commands": [
    { "run": "<shell command>", "label": "<short label, optional>",
      "note": "<optional reasoning, shown in reports>" }
  ]
}
```

Every `commands[].run` runs **in order, in the worktree**; each must exit 0. The first
non-zero exit fails the gate — the change is reported and NOT integrated.

The plugin's shared `scripts/run-green-gate.ps1` is the canonical runner. Any
agent can run the complete read-only readiness set through `gate-check`; it
does not take branch, commit, integration, or cleanup authority.

- **No `green-gate.json`** → the gate is **skipped** (with a one-line note) and the
  change integrates anyway. This is expected for docs-only or early-stage repos; a
  missing gate is never a nuisance. Add the file when you have something to gate.
- **`"commands": []`** → an intentional no-gate; the gate is skipped silently.

### Example — a .NET Module repo

```json
{
  "commands": [
    { "run": "dotnet build MyApp.slnx", "label": "build",
      "note": "Whole-solution build — catches cross-module test consumers that scoped per-project builds miss." },
    { "run": "dotnet test MyApp.slnx", "label": "test",
      "note": "Full suite; suspended UI tests under tests/UiTests are excluded per the repo's conventions." }
  ]
}
```

### Example — a docs / plugin repo

```json
{
  "commands": [
    { "run": "claude plugin validate .", "label": "validate" }
  ]
}
```
