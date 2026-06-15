---
name: complete-feature
description: Use after you have validated a merged feature to close out the execute-feature session — sets Status: done, removes the feature worktree, and sweeps this checkout's other fully-integrated, clean worktrees (quick-fix runs included) via the cogniva worktree ledger. Run once you are satisfied with the integrated result in your working tree.
---

# Complete Feature

Close out a feature that has been integrated into your branch and validated by you.

Run AFTER `/cogniva-skills:execute-feature` has set `Status: integrated` AND you
have confirmed the feature works in your checked-out branch.

Invoke: `/cogniva-skills:complete-feature <Module>/<Feature>`

`<plugin>` below = this plugin's root (the parent of this `skills/` dir).
`<slug>` = kebab of `<Feature>`.

## Step 1 — verify state

Read `docs/plans/<Module>/<Feature>/state.md` from the **primary checkout** (not
the worktree).

- If `Status:` is not `integrated`, warn the user and ask for explicit
  confirmation before proceeding. Do not silently close out an in-progress or
  blocked feature.
- Record `Worktree:` path and `Target branch:` for the steps below.

## Step 2 — set Status: done

In `docs/plans/<Module>/<Feature>/state.md` (primary checkout):

1. Change `Status: integrated` → `Status: done`.
2. Append to the `## Log` section:
   ```
   - Closed out: validated by user, worktree removed.
   ```

The Stop-hook auto-commits `docs/plans/` on session end; no manual commit needed
here.

## Step 3 — remove the worktree

```
git worktree remove "<worktree>"
```

If the worktree has unexpected uncommitted changes, surface them and ask the user
whether to discard before proceeding — do NOT pass `--force` blindly.

## Step 4 — delete the feature branch

```
git branch -d feature/<slug>
```

If `-d` fails (branch not fully merged from git's perspective), report it and
skip — do NOT force-delete. The user can delete manually after inspecting.

NOTE: in a shared primary checkout, branch deletion may be blocked by a PreToolUse
protection hook (the primary's branch list is global state). If the command is
denied, skip it and report that the branch remains — that is expected, not an error.

## Step 5 — sweep this checkout's other integrated worktrees

A session typically spawns several worktrees (the feature plus any `quick-fix`
runs). Each is recorded in a checkout-local ledger when created
(`<git-common-dir>/cogniva-worktrees.tsv`). Sweep the ones that are now safe to
discard — **fully merged into the target AND clean**:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/cleanup-session-worktrees.ps1" -TargetBranch "<target>"
```

It removes every ledger worktree whose branch is fully merged into `<target>` and
whose tree is clean, prunes stale ledger entries (worktree already gone, e.g. the
one removed in Step 3), and leaves in-progress or unmerged worktrees untouched. It
never deletes branches and never uses `--force`. Parse the JSON
`{ removed, kept, pruned }` and surface it in the report. (If the ledger predates
this mechanism and is empty/missing, the sweep is a no-op — older worktrees are
removed manually with `git worktree remove`.)

## Step 6 — report

Tell the user:

- Feature `<Module>/<Feature>` is now **done**.
- Worktree `<path>` removed.
- Branch `feature/<slug>` deleted (or skipped, with reason — e.g. shared-checkout hook).
- Swept worktrees: the `removed` list from Step 5 (and any `kept` with their reason).
- Remind them to push `<target>` to the remote when ready.

## Rules

- NEVER close out a feature with `Status: in-progress` or `Status: blocked`
  without explicit user confirmation.
- NEVER force-delete a feature branch.
- NEVER push to a remote.
- NEVER run this skill before the user has validated — it is the user's signal
  that validation is complete, not a step within validation.
