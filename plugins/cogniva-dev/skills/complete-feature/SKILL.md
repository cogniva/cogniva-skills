---
name: complete-feature
description: Use after you have validated a merged feature to close out the execute-feature session — sets the feature's Status to done, removes its worktree, and deletes its feature branch. Operates ONLY on the one named feature; it does NOT sweep other worktrees. Use /cogniva-dev:sweep-worktrees for the checkout-wide reap of other integrated worktrees. Run once you are satisfied with the integrated result in your working tree.
---

# Complete Feature

Close out a feature that has been integrated into your branch and validated by you.

Run AFTER `/cogniva-dev:execute-feature` has set `Status: integrated` AND you
have confirmed the feature works in your checked-out branch.

Invoke: `/cogniva-dev:complete-feature <Module>/<Feature>`

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

## Step 5 — report

This skill closes out ONE feature only. It does NOT touch other worktrees — even
ones this checkout created — because in a shared primary checkout those may belong
to other live sessions. To reap other fully-integrated, clean worktrees on demand,
run `/cogniva-dev:sweep-worktrees` (checkout-wide).

Tell the user:

- Feature `<Module>/<Feature>` is now **done**.
- Worktree `<path>` removed.
- Branch `feature/<slug>` deleted (or skipped, with reason — e.g. shared-checkout hook).
- If you know this session spawned other now-integrated worktrees (e.g. `quick-fix`
  runs), remind them they can clear those with `/cogniva-dev:sweep-worktrees`.
- Remind them to push `<target>` to the remote when ready.

## Rules

- NEVER close out a feature with `Status: in-progress` or `Status: blocked`
  without explicit user confirmation.
- NEVER force-delete a feature branch.
- NEVER push to a remote.
- NEVER run this skill before the user has validated — it is the user's signal
  that validation is complete, not a step within validation.
