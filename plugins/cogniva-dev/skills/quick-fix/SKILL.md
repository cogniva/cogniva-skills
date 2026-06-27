---
name: quick-fix
description: Use for small follow-up changes (UI tweak, bug fix, copy change) without a formal feature plan. Runs the change in an isolated git worktree via a background Workflow, then auto-integrates into the branch you have checked out - same machinery as execute-feature. Designed to be fired repeatedly from within an active execute-feature session without bloating context.
---

# Quick Fix

A planless sibling of `/cogniva-dev:execute-feature` for small changes. Same
isolation + auto-integration, no plan file. The work runs in a background
Workflow, so you can fire `quick-fix` repeatedly from your control session and it
stays lean.

Invoke: `/cogniva-dev:quick-fix "<short description of the change>"`.

`<plugin>` = this plugin's root — the directory containing `scripts/` AND
`templates/`, i.e. the **parent** of `skills/`. It is NOT the skill's own folder
(`.../skills/quick-fix/`). Resolve it once from the `scripts/...` command in Step 0
and reuse that exact root verbatim everywhere `<plugin>` appears (including the
`templates/...` path in Step 1) — do not re-derive or search for it.

## Step 0 — isolated worktree (Bash)
Derive a short `<slug>` from the description (e.g. `fix-status-bar-alignment`), then:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/new-feature-worktree.ps1" -Slug <slug>`
Capture `worktree` and `branch` (`feature/<slug>`). The user's current branch is
the integration target (never switched).

## Step 1 — make the change (Workflow, background)
Run the Workflow from `<plugin>/templates/execute-feature.workflow.js` (same
`<plugin>` root as Step 0 — it sits beside `scripts/`, never under `skills/`; copy
its script verbatim, do not rewrite or hand-author it). Use a SINGLE synthesized
task for trivial fixes, or a short ordered task list for multi-step ones. Each task body must be self-contained and include: what to
change, how to verify (test or manual check), and a commit step. Pass
`planPath`/`statePath` only if you created a state file — and as
**primary-checkout** paths (built from the worktree script's `repoRoot`), never
`<worktree>/...` (see execute-feature Step 0 / docs/adr/0004). Otherwise omit
checkbox ticking from the task body and rely on the commit(s).

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
  `/cogniva-dev:plan-feature` instead.
- If the fix surfaces a follow-up you are NOT doing now, don't drop it — capture
  it: `/cogniva-dev:backlog module=<Module> tier=loose — <description>`. If this
  fix resolved a loose `BACKLOG.md` item, tick it and append `→ done`.
