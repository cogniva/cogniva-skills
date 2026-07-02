---
name: cleanup-allwork
description: Checkout-wide safety net that finishes EVERY cleanupable worktree on this checkout, including ones from sessions you closed or forgot. Works from the JSON ledger recipe alone - no original-session context needed. For each cleanupable record it retries integrate if queued, runs the close-out recipe (state.md Status, etc.), removes the merged+clean worktree, and prunes the record. Never touches in-progress worktrees. Replaces sweep-worktrees and complete-feature. Run it when you suspect leftover worktrees or forgot to run /cleanup-work in a session.
---

# Cleanup All Work

The catch-all. Closes out **every** `cleanupable` worktree recorded in the
ledger, regardless of which session created it - because each worktree self-records
a complete close-out recipe, this needs no context from the original session. Use
it when you forgot `/cleanup-work`, closed a session mid-flow, or just want the
checkout tidy. This is the rename of `sweep-worktrees` and absorbs the per-feature
close-out that `complete-feature` used to do.

Invoke: `/cleanup-allwork`

`<plugin>` = this plugin's root (the parent of this `skills/` dir).

## Scope note - surface before running

The primary checkout is **shared by parallel sessions**. This is **checkout-wide**:
it can close out worktrees created by *other* live sessions - but ONLY ones already
marked `cleanupable` (work committed + integrated + green, awaiting validation).
`in-progress` worktrees are never touched, so nothing in flight is disturbed and
nothing committed is lost. If you only want to close out *this* session's work,
use `/cleanup-work` instead.

## Step 1 - run the sweep

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/cleanup-worktrees.ps1" -Scope all
```

(Target branch defaults to the checkout's current branch; pass `-TargetBranch`
only to override.) For each `cleanupable` record the engine retries a queued
integrate, runs the recipe (flips `state.md` `Status:`, commits that doc), removes
the worktree once merged + clean, and prunes the record. Stale records (worktree
already gone) are pruned. It never touches `in-progress` records, never
force-removes, never deletes branches, never pushes to a remote.

Parse the last JSON line: `{ closed, kept, pruned }`.

## Step 2 - report (terse)

- **closed**: worktrees finished and removed. Surface each recipe `followups`
  (deferred backlog/manual items) so they survive - capture still-open ones with
  `/backlog`.
- **kept**: left alone, with a reason (`uncommitted changes in worktree`, or
  `not merged` = target dirty/conflict - resolve in your checkout, then re-run).
- **pruned**: stale ledger entries removed.

If the ledger is empty/missing this is a no-op - report that.

## Rules

- NEVER force-remove a worktree, delete a branch, or push to a remote.
- Only `cleanupable` records are actioned; `in-progress` worktrees (any session)
  are always preserved.
- Closing a forgotten `cleanupable` worktree assumes its validation passed. That
  is safe: the code is already fast-forward-merged onto the branch regardless;
  this only does bookkeeping (Status/backlog) + worktree removal. If something was
  wrong, it is a `git revert` on the branch, not lost work.
