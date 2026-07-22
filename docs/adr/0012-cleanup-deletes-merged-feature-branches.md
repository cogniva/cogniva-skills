# Cleanup deletes merged feature branches at close-out

**Provenance:** Suggested by agent (confirmed by human, 2026-07-22)
**Relitigation:** Open to discussion

`cleanup-work` / `cleanup-allwork` delete the feature branch with plain
`git branch -d` after the merged worktree is removed, because cleanup's contract
is to leave the checkout tidy and a fully-merged branch is bookkeeping residue,
not work. The previous blanket "never delete branches" rule conflated this with
genuinely destructive operations: `-d` cannot destroy anything - git itself
refuses unless the branch is fully merged. Force-delete (`-D`), force worktree
removal, and pushes remain forbidden, and kept/queued worktrees keep their
branches. A failed deletion is non-fatal and reported as `branchDeleted: false`
on the closed record.
