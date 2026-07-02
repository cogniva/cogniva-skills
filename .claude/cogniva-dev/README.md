# cogniva-dev opt-in marker

This repository — the cogniva-dev plugin's own home — **dogfoods** its
pristine-primary worktree workflow. The presence of this directory is the opt-in
signal: the plugin's PreToolUse guards (`guard-primary-edit.js`,
`guard-primary-git.js`) enforce here, and only in repos where `.claude/cogniva-dev/`
exists.

While opted in, inside the **primary checkout** Claude may not:

- edit files directly — all work happens in a git worktree that fast-forward-merges
  into the branch (the only directly-editable paths are the gitignored scratch dirs
  `.explore/**` and `.plans-staging/**`);
- `git switch` / `checkout`, or create/delete/move branches (also denied in
  `.claude/settings.json` as a node-independent backstop).

Develop via `/cogniva-dev:plan-feature`, `/cogniva-dev:execute-feature`, and
`/cogniva-dev:quick-fix`, which create the worktree, integrate, and mark it
cleanupable. See `docs/adr/0006`.

**To opt out**, delete this directory — the guards then allow direct edits here again.
