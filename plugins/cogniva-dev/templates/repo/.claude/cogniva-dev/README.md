# cogniva-dev opt-in marker

The **presence of this directory** opts this repository into the `cogniva-dev`
plugin's **pristine-primary worktree workflow**. The plugin's PreToolUse guards
(`guard-primary-edit.js`, `guard-primary-git.js`) only enforce in repos where
`.claude/cogniva-dev/` exists — everywhere else they allow everything.

While opted in, inside this repo's **primary checkout** Claude may not:

- edit files directly — all work happens in a git worktree that fast-forward-merges
  into your branch (the only directly-editable paths are the gitignored scratch dirs
  `.explore/**` and `.plans-staging/**`, plus tier-1 backlog capture:
  `docs/plans/BACKLOG.md` and `docs/plans/<Module>/BACKLOG.md`);
- `git switch` / `checkout`, or create/delete/move branches.

Feature work runs via `/cogniva-dev:plan-feature`, `/cogniva-dev:execute-feature`,
and `/cogniva-dev:quick-fix`, which create the worktree, integrate, and mark it
cleanupable. See the plugin's ADR 0006 (plans live in the worktree).

**To opt out**, delete this directory — the guards then allow everything here again.

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
