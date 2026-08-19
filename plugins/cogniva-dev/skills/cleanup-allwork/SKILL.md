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

## Mode check (first)

If the target repo's `.claude/cogniva-dev.local.json` is absent or its
`"worktrees"` is not `true`, reply "Worktree mode is off in this repo —
nothing to clean." and STOP.

## Scope note - surface before running

The primary checkout is **shared by parallel sessions**. This is **checkout-wide**:
it can close out worktrees created by *other* live sessions - but ONLY ones already
marked `cleanupable` (work committed + integrated + green, awaiting validation).
`in-progress` worktrees are never touched, so nothing in flight is disturbed and
nothing committed is lost. If you only want to close out *this* session's work,
use `/cleanup-work` instead.

## Step 0 - get out of the worktrees first

**Move your shell to the primary checkout root before running the sweep** (`cd
"<repo root>"` / `Set-Location`). Shell cwd persists across tool calls and the
green gate runs with a *worktree* root as its cwd, so the shell is easily still
parked inside a directory this sweep must delete. Windows will not delete a
directory that is a live process's cwd: `git worktree remove` deletes the
CONTENTS, then fails on the directory, leaving a gutted husk. The script moves
its own process out; it cannot move yours. (If it happens anyway nothing is lost -
the worktree is reported `kept` with git's error, and a later run finishes it.)

## Step 1 - run the sweep

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/cleanup-worktrees.ps1" -Scope all
```

(Target branch defaults to the checkout's current branch; pass `-TargetBranch`
only to override.) For each `cleanupable` record the engine retries a queued
integrate, runs the recipe (flips `state.md` `Status:`, commits that doc), removes
the worktree once merged + clean, deletes the merged feature branch (`git branch
-d` only - git refuses unless fully merged), and prunes the record. Stale records
(worktree already gone) are pruned. It never touches `in-progress` records, never
force-removes, never force-deletes, never pushes to a remote.

Parse the last JSON line: `{ closed, kept, pruned }`.

## Step 2 - report (terse)

- **closed**: worktrees finished and removed. Surface each recipe `followups`
  (deferred backlog/manual items) so they survive - capture still-open ones with
  `/backlog`. A `note` field means the entry was a *recovery* (a worktree an
  earlier run gutted) - pass it along.
- **kept**: left alone, with a reason. Quote it VERBATIM - it carries git's own
  error text. `uncommitted changes in worktree`; `not merged` = target
  dirty/conflict, resolve in your checkout then re-run; `worktree remove failed:
  ...` = something holds the directory, on Windows almost always a shell cd'd
  into it (Step 0) - if it also says GUTTED, cd out and re-run and the next sweep
  finishes the branch and the empty directory; `worktree gutted ... NOT merged`
  or `still holds N file(s)` = a husk that is NOT safe to finish automatically,
  report it and leave it to the user.
- **pruned**: stale ledger entries removed (the worktree path was already gone).

If the ledger is empty/missing this is a no-op - report that.

## Rules

- NEVER force-remove a worktree, force-delete a branch (`-D`), or push to a
  remote. Merged feature branches are deleted with plain `-d` at close-out -
  git refuses unless fully merged, so no work can be lost. Kept worktrees keep
  their branches.
- Only `cleanupable` records are actioned; `in-progress` worktrees (any session)
  are always preserved.
- Closing a forgotten `cleanupable` worktree assumes its validation passed. That
  is safe: the code is already fast-forward-merged onto the branch regardless;
  this only does bookkeeping (Status/backlog) + worktree removal. If something was
  wrong, it is a `git revert` on the branch, not lost work.
