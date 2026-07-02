# cogniva-dev opt-in marker

The **presence of this directory** opts this repository into the `cogniva-dev`
plugin's **pristine-primary worktree workflow**. The plugin's PreToolUse guards
(`guard-primary-edit.js`, `guard-primary-git.js`) only enforce in repos where
`.claude/cogniva-dev/` exists — everywhere else they allow everything.

While opted in, inside this repo's **primary checkout** Claude may not:

- edit files directly — all work happens in a git worktree that fast-forward-merges
  into your branch (the only directly-editable paths are the gitignored scratch dirs
  `.explore/**` and `.plans-staging/**`);
- `git switch` / `checkout`, or create/delete/move branches.

Feature work runs via `/cogniva-dev:plan-feature`, `/cogniva-dev:execute-feature`,
and `/cogniva-dev:quick-fix`, which create the worktree, integrate, and mark it
cleanupable. See the plugin's ADR 0006 (plans live in the worktree).

**To opt out**, delete this directory — the guards then allow everything here again.
