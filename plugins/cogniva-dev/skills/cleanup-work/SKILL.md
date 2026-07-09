---
name: cleanup-work
description: Close out THIS session's worktrees after you have validated the work. Runs the close-out recipe for each worktree this session created and marked cleanupable (flips state.md Status, removes the merged+clean worktree, prunes the ledger record). Session-scoped and safe - never touches in-progress or other sessions' worktrees. Run it once you are satisfied with the integrated result in your branch. If you closed a session before running this, use /cleanup-allwork instead.
---

# Cleanup Work

The normal close-out. Run AFTER you have validated the work that this session
integrated into your branch. It finishes only the worktrees **this session**
created and marked `cleanupable` - it does not sweep other sessions' work.

Invoke: `/cleanup-work`

`<plugin>` = this plugin's root (the parent of this `skills/` dir).

## Step 1 - gather this session's worktrees

Collect the absolute worktree paths created during this session (from the
`new-feature-worktree.ps1` calls you ran - ambient ad-hoc work and/or
`execute-feature` runs). Each should already be `cleanupable` (work committed +
integrated + green, awaiting your validation).

- If you cannot identify any worktree this session created (e.g. context was lost
  or this is a fresh session), STOP and tell the user to run `/cleanup-allwork`
  instead - that one works from the ledger alone and needs no session context.

## Step 2 - run the close-out

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/cleanup-worktrees.ps1" -Scope list -Worktrees "<path1>,<path2>,<path3>"
```

Pass the worktree paths as ONE comma-joined `-Worktrees` value (no spaces around
the commas). Driven from the Bash tool via `powershell -File`, a `"a","b"` token is
delivered as a single argument anyway; the script splits on commas, so the
comma-joined form is the robust one. A single path is just `-Worktrees "<path>"`.

(Target branch defaults to your current branch; pass `-TargetBranch` only to
override.) The engine, per `cleanupable` worktree in the list:
- retries the fast-forward integrate if it was queued (target was dirty earlier),
- runs the recipe (flips `state.md` `Status:` to its target, commits that doc),
- removes the worktree once merged + clean, and prunes its ledger record.
It never touches `in-progress` records and never force-removes or deletes branches.

Parse the last JSON line: `{ closed, kept, pruned }`.

## Step 3 - report (terse)

- **closed**: worktrees finished and removed. For each, surface its recipe
  `followups` if present (backlog/manual items the work deferred) so they are not
  lost - capture any with `/backlog` if still open.
- **kept**: not closed, with a reason (`uncommitted changes in worktree` =
  unexpected WIP there; `not merged` = target was dirty/conflicting - commit or
  stash in your checkout, then re-run).
- **pruned**: stale records cleaned up (worktree was already gone).

## Rules

- NEVER force-remove a worktree, delete a branch, or push to a remote.
- Only acts on `cleanupable` records for the worktrees you pass - in-progress work
  is always left alone.
- This is the routine path; `/cleanup-allwork` is the catch-all for forgotten or
  other-session worktrees.
