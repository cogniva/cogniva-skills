---
status: accepted (supersedes 0004)
---

# Plan and state.md live in the feature worktree and integrate via the merge

**Supersedes [ADR 0004](0004-plan-and-state-are-primary-checkout-control-plane.md).**

**Context.** cogniva-dev is adopting NewCogniva's more-scrutinized **pristine-primary**
model: nothing the AI writes lands on the shared primary checkout outside a git
worktree (enforced by a `guard-primary-edit` PreToolUse hook; edits are confined to
the worktree plus gitignored scratch like `.explore/**` and `.plans-staging/**`).
ADR 0004 went the opposite way — it resolved plan + `state.md` against the **primary
checkout** as untracked control-plane metadata, and relied on the Stop hook
`auto-commit-plans.ps1` to commit them. Both approaches solved the same original
fragility (a freshly-written plan not materializing in the worktree); they are
mutually exclusive, and the pristine-primary policy forces the worktree side.

**Decision.** Plan and `state.md` are **feature-branch artifacts authored inside the
worktree**, never the primary checkout:
- `plan-feature` creates/reuses the worktree first and writes the whole
  `docs/plans/<Module>/<Feature>/` folder under `<worktree>/`, landing it as a
  `plan(<Module>/<Feature>): ...` commit.
- `execute-feature` resolves `planPath`/`statePath` against `<worktree>/docs/plans/...`;
  the per-task agent edits `state.md` in the worktree, committed on the feature
  branch so it rides the fast-forward merge into the target.
- `auto-commit-plans.ps1` and its Stop hook are **removed** — there is no primary
  auto-commit; the merge is the only path onto the user's branch.
- `mark-cleanupable.ps1 -StatePath` is only a reference that cleanup maps INTO the
  worktree at close-out (the `Status: done` flip is made and committed in the
  worktree, then merged) — the primary tree is never written directly.

**Why.** Under the guard, the primary checkout must stay pristine, so plans cannot
live there. Committing the plan in the worktree makes it real tracked history that
*does* materialize and merge — removing the timing/gitignore fragility ADR 0004
fought, from the other direction — and collapses the write rule to one invariant:
the AI writes only to worktrees and gitignored scratch.

**Consequences.** `docs/plans/**` on a branch is committed feature history, not
untracked primary metadata. A repo that deliberately gitignores `docs/plans` must
let the worktree commit the plan (or stage it to gitignored scratch). The guard
enforcement (`guard-primary-edit.js` wiring) and the repo-init opt-in marker are
tracked separately in [the migration plan](../plans/worktree-ledger-migration.md);
the plan/execute/quick-fix skills already instruct this model regardless of whether
the guard hook is wired yet.
