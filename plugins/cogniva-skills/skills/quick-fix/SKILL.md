---
name: quick-fix
description: Use for small follow-up changes (UI tweak, bug fix, copy change) without a formal feature plan. Runs the change in an isolated git worktree via a background Workflow, then auto-integrates into the branch you have checked out - same machinery as execute-feature. Designed to be fired repeatedly from within an active execute-feature session without bloating context.
---

# Quick Fix

A planless sibling of `/cogniva-skills:execute-feature` for small changes. Same
isolation + auto-integration, no plan file. The work runs in a background
Workflow, so you can fire `quick-fix` repeatedly from your control session and it
stays lean.

Invoke: `/cogniva-skills:quick-fix "<short description of the change>"`.

`<plugin>` = this plugin's root (parent of `skills/`).

## Step 0 — isolated worktree (Bash)
Derive a short `<slug>` from the description (e.g. `fix-status-bar-alignment`), then:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/new-feature-worktree.ps1" -Slug <slug>`
Capture `worktree` and `branch` (`feature/<slug>`). The user's current branch is
the integration target (never switched).

## Step 1 — make the change (Workflow, background)
Run the Workflow from `<plugin>/templates/execute-feature.workflow.js` with a
SINGLE synthesized task for trivial fixes, or a short ordered task list for
multi-step ones. Each task body must be self-contained and include: what to
change, how to verify (test or manual check), and a commit step. Pass
`planPath`/`statePath` only if you created a state file; otherwise omit checkbox
ticking from the task body and rely on the commit(s).

The task-agent works ONLY in `<worktree>` on `feature/<slug>`, never switches
branches, stages only its own files, and commits.

## Step 2 — build/test, then auto-integrate
Build/test in the worktree. If green:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/integrate-feature.ps1" -WorktreePath "<worktree>" -FeatureBranch "feature/<slug>" -TargetBranch "<target>"`
Handle the JSON `status` exactly as execute-feature does:
`INTEGRATED` (offer worktree removal) / `QUEUED_DIRTY` (commit-or-stash then
re-run) / `CONFLICT` (report worktree for resolution) / `ERROR` (surface detail).

## Rules
- Never push to remote. Never branch-switch the primary checkout.
- Keep it small — if the change grows into a real feature, stop and suggest
  `/cogniva-skills:plan-feature` instead.
