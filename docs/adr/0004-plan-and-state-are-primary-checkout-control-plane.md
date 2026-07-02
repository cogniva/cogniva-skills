---
status: superseded by 0006 (2026-07-02)
---

> **Superseded (2026-07-02) by [ADR 0006](0006-plan-and-state-live-in-the-worktree.md).**
> cogniva-dev adopted NewCogniva's pristine-primary model — plan + `state.md` now live
> **in the feature worktree** and integrate via the merge, the opposite of this ADR.
> `auto-commit-plans.ps1` and its Stop hook were removed. Retained as history; the
> decision below is no longer in effect.

# Plan and state.md are primary-checkout control-plane artifacts, never resolved in the worktree

**Context.** execute-feature creates a fresh git worktree per feature, then read the
plan and `state.md` from `<worktree>/docs/plans/<Module>/<Feature>/`. But a git
worktree only materializes **tracked, committed** files: `docs/plans/**` is
frequently gitignored, and even when tracked, a freshly-written plan is still
uncommitted when execute-feature runs in the same session as plan-feature. So the
plan/state files never propagated into the worktree, and every run turned into a
manual scavenger hunt ("the plan dir isn't in the worktree… likely gitignored…").

**Decision.** Plan and `state.md` are *control-plane* artifacts that live in and are
resolved against the **primary checkout** (`repoRoot`), never the worktree. The
worktree holds ONLY the code deliverable. execute-feature and quick-fix build
`planPath`/`statePath` from `repoRoot` (now emitted by `new-feature-worktree.ps1`);
the per-task agent edits those files in place as untracked metadata that is NEVER
part of its commit. complete-feature already reads `state.md` from the primary
checkout — this ADR makes the convention explicit and consistent across the whole
execute-feature toolchain.

**Why.** Resolving against the primary checkout is correct regardless of whether
`docs/plans` is gitignored, tracked-but-uncommitted, or committed — so it removes
the timing/gitignore fragility at the source. The Stop-hook (`auto-commit-plans.ps1`)
still commits the primary-checkout `docs/plans` where it is tracked; where it is
ignored, the files simply stay local — which is the intended behavior for a repo
that deliberately ignores planning artifacts.
