# execute-feature — worktree overlay

Read this ONLY when the target repo's `.claude/cogniva-dev.local.json` has
`"worktrees": true`. It replaces the ⟦worktree⟧-tagged steps of `SKILL.md`.
Everything here exists so the user's checkout is never touched until one
clean fast-forward merge at the end.

## Step 0a in worktree mode — name first, write inside

Step 0a is unchanged for a plan REFERENCE. For PASTED plan text the order
matters, because `<slug>` comes from `<Feature>` but the file may not be
written to the primary checkout:

1. Propose and confirm `<Module>/<Feature>` FIRST — the worktree cannot be
   created before the feature has a name.
2. Create the worktree (below).
3. Only THEN write the pasted text to
   `<WORKSPACE>/docs/plans/<Module>/<Feature>/<Feature>-plan.md` and commit
   it on the feature branch, so it rides the same merge as the work it
   drives. Writing it to the primary checkout instead would dirty the
   user's tree and the guard hooks deny it anyway.

## Replaces Step 0b — isolated worktree

Derive `<slug>` (kebab of `<Feature>`), then:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/new-feature-worktree.ps1" -Slug <slug>`
It reads the user's current branch as the integration target (never switches
it) and prints
`{ worktree, branch, base, reused, ahead, behind, resynced, stale, staleReason }`.
Set `WORKSPACE` = `worktree`, `BRANCH` = `feature/<slug>`, and the user's
current branch = `TARGET`. `START` is not needed — the ADR check compares
against `TARGET`.

**Gate on staleness BEFORE Step 1.** A reused worktree may sit behind the
target, and the plan file inside it may be an older revision — tasks would
implement a decision the target already replaced.

- `resynced: true` — it was behind with no commits of its own and was
  fast-forwarded for you; say so in one line, carry on.
- `stale: true` — behind AND divergent (or dirty): STOP, report
  `staleReason`, `git -C "<WORKSPACE>" merge <TARGET>`, resolve + commit,
  then continue.

Normalize and parse the plan FROM the worktree afterwards, never before.
Record `Target branch` / `Worktree` / `branch` in the feature's `state.md`
(in the worktree) and set `Status: in-progress`.

## Qualifiers for Steps 1–4

- Every path (plan, `state.md`, task files, a converted `.tasks.md`) is
  inside the worktree. NEVER edit the primary checkout — the guard hooks
  deny it.
- A `state.md` exists next to the plan (task plans from plan-feature): add
  `statePath: "<WORKSPACE>/docs/plans/<Module>/<Feature>/state.md"` to the
  workflow args; each task appends its one-line log there. On a Blocked / ⛔
  stop, set that `state.md` `Status: blocked` before reporting.
- The green gate's cwd is the worktree root — bracket it with
  `Push-Location "<WORKSPACE>"` … `Pop-Location` in the SAME call. A shell
  left parked in the worktree is what makes Windows unable to delete it at
  close-out.
- ADR check, worktree form:
  `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/check-adrs.ps1" -Worktree "<WORKSPACE>" -TargetBranch "<TARGET>"`

## Replaces Step 4.6 "Done" — landing = integration

1. If a `state.md` exists: set `Status: integrated` and commit it on the
   feature branch so the merge carries it.
2. `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/integrate-feature.ps1" -WorktreePath "<WORKSPACE>" -FeatureBranch "feature/<slug>" -TargetBranch "<TARGET>"`
   It pre-merges the target into the feature, serializes via a lock, and
   fast-forward LOCAL-pushes into the target branch (never a remote).
3. `INTEGRATED` → mark the worktree cleanupable:
   `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/mark-cleanupable.ps1" -Worktree "<WORKSPACE>" -Branch "feature/<slug>" -StatePath "<primary>/docs/plans/<Module>/<Feature>/state.md" -TargetStatus done -Summary "<one line of what shipped>" -Followups "<deferred items, if any>"`
   (omit `-StatePath`/`-TargetStatus` when there is no `state.md`). Tell the
   user: "Merged into your branch. Validate in your working tree, then run
   `/cogniva-dev:cleanup-work` to close out; if this session is gone,
   `/cogniva-dev:cleanup-allwork` finishes it." Never `git worktree remove`
   manually — the cleanup skills own that.
4. `QUEUED_DIRTY` → the target tree had uncommitted changes; nothing was
   clobbered. Record "Integration: queued" in the WORKTREE `state.md` (when
   present); tell the user to commit/stash and re-run.
5. `CONFLICT` → a real conflict with work already on the target: report the
   worktree path for resolution, force nothing. `ERROR` → surface the
   detail; do not retry blindly.
