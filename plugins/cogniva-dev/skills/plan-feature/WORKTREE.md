# plan-feature — worktree overlay

Read this ONLY when the target repo's `.claude/cogniva-dev.local.json` has
`"worktrees": true`. It replaces the ⟦worktree⟧ steps of `SKILL.md`.

## Author on a worktree (before writing anything)

`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/new-feature-worktree.ps1" -Slug <slug>`
Author the whole plan folder under
`<worktree>/docs/plans/<Module>/<Feature>/`. Nothing reaches the user's
branch until integration; abandoning the design costs nothing.

Also seed `state.md` next to the plan:

```markdown
# <Feature> — execution state

Status: planned
Target branch: (set by execute-feature at run time)
Worktree: (set by execute-feature)
Integration: not started

## Log
```

`Status:` lifecycle: `deferred → planned → in-progress → blocked →
integrated → done`; the status skills read it. Multi-plan features seed the
per-sub-plan checklist variant instead (see PLAN-FORMAT.md).

## Integrate and close out (replaces the lean commit step)

After the single `plan(<Module>/<Feature>): ...` commit on the worktree:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/integrate-feature.ps1" -WorktreePath "<worktree>" -FeatureBranch "feature/<slug>" -TargetBranch "<your branch>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/mark-cleanupable.ps1" -Worktree "<worktree>" -Branch "feature/<slug>" -Summary "plan <Module>/<Feature>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/cleanup-worktrees.ps1" -Scope list -Worktrees "<worktree>"
```

Close the worktree out IMMEDIATELY — a plan is a markdown file that
integrate already fast-forwarded onto the user's branch; there is nothing
to validate, and a leftover planning worktree gets silently reused by
execute-feature (same slug → same path). Run the close-out with your shell
in the PRIMARY checkout — Windows will not delete a directory that is a
live process's cwd.

Only run the last two commands when integrate reported `INTEGRATED`.
`QUEUED_DIRTY` → still mark cleanupable, SKIP close-out, and say the plan
is queued for `/cogniva-dev:cleanup-work` once the user's tree is clean.
`CONFLICT` / `ERROR` → report the detail and stop; force nothing.
