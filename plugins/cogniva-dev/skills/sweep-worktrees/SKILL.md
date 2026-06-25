---
name: sweep-worktrees
description: Explicitly reap fully-integrated, clean git worktrees created by cogniva (execute-feature / quick-fix runs) across this whole checkout. Removes every ledger worktree whose branch is fully merged into the target branch AND whose tree is clean; leaves in-progress, unmerged, or dirty worktrees untouched. Use when you deliberately want to clean up the checkout's worktrees — note it is checkout-wide and may remove worktrees created by OTHER live sessions on this shared checkout (that is safe: only merged+clean ones are removed, nothing is lost).
---

# Sweep Worktrees

On-demand cleanup of cogniva-created worktrees that are safe to discard.

This is the **explicit, checkout-wide** counterpart to `complete-feature` (which
closes out only its one named feature). Reach for it when you want to tidy the
worktree list — e.g. after several `quick-fix` runs have all integrated.

`<plugin>` below = this plugin's root (the parent of this `skills/` dir).

## What it does

Reads the checkout-local ledger written when each worktree was created
(`<git-common-dir>/cogniva-worktrees.tsv`) and removes every entry that is
**fully merged into the target branch AND clean** (no uncommitted changes). It
prunes stale ledger entries (worktree already gone), never deletes branches, and
never uses `--force`. In-progress, unmerged, or dirty worktrees are kept.

## ⚠️ Scope warning — surface this BEFORE running

The primary checkout is **shared by parallel sessions**. This sweep is
**checkout-wide**: it can remove worktrees created by *other* live sessions, as
long as they are merged + clean. That is safe (nothing committed is lost — the
work is already merged into the target), but the other session will find its
worktree gone. If the user only wants to close out the feature *this* session
worked on, point them to `/cogniva-dev:complete-feature <Module>/<Feature>`
instead and do NOT run this.

## Step 1 — run the sweep

Target branch defaults to the primary checkout's current branch (the integration
target). Pass `-TargetBranch` only to override.

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/cleanup-session-worktrees.ps1" -TargetBranch "<target>"
```

Parse the last line of JSON: `{ removed, kept, pruned }`.

## Step 2 — report

- `removed`: worktrees deleted (merged + clean).
- `kept`: worktrees left, each with a reason (`uncommitted changes` or
  `not merged into <target>`) — these are still in use or have unsaved work.
- `pruned`: stale ledger entries cleaned up (worktree was already gone).

If the ledger is empty/missing the sweep is a no-op — report that and remind the
user older worktrees are removed manually with `git worktree remove`.

## Rules

- NEVER force-remove a worktree or delete a branch.
- NEVER push to a remote.
- ALWAYS surface the checkout-wide scope warning before running if there is any
  chance other sessions are active.
