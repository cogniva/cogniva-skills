# quick-fix — worktree overlay

Read this ONLY when the target repo's `.claude/cogniva-dev.local.json` has
`"worktrees": true`. Same machinery as execute-feature's overlay, without
plans or `state.md`.

## Replaces Step 0

Derive `<slug>` from the description (e.g. `fix-status-bar-alignment`),
then:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/new-feature-worktree.ps1" -Slug <slug>`
Set `WORKSPACE` = `worktree`, `BRANCH` = `feature/<slug>`, the user's
current branch = `TARGET`. Staleness: `resynced: true` → mention it,
continue; `stale: true` → STOP, merge `TARGET` into the feature branch in
the worktree, commit, then dispatch — fixing a file against a stale tree
lands the fix on code the target already changed.

## Replaces Step 2's ADR check and "done"

- ADR check:
  `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/check-adrs.ps1" -Worktree "<WORKSPACE>" -TargetBranch "<TARGET>"`
- The green gate's cwd is the worktree — bracket with
  `Push-Location "<WORKSPACE>"` … `Pop-Location` in the SAME call; a shell
  left parked there blocks the worktree's deletion at close-out.
- After a green gate:
  `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/integrate-feature.ps1" -WorktreePath "<WORKSPACE>" -FeatureBranch "feature/<slug>" -TargetBranch "<TARGET>"`
  - `INTEGRATED` →
    `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/mark-cleanupable.ps1" -Worktree "<WORKSPACE>" -Branch "feature/<slug>" -Summary "<one line of what the fix did>"`
    Tell the user: "Merged into your branch. Validate it, then
    `/cogniva-dev:cleanup-work` to close out; `/cogniva-dev:cleanup-allwork`
    if this session is gone." Never `git worktree remove` manually.
  - `QUEUED_DIRTY` → the target was dirty; commit/stash, re-run integrate.
  - `CONFLICT` → report the worktree path, force nothing. `ERROR` → surface
    the detail; do not retry blindly.
