---
name: feature-status
description: Use to see what feature work is remaining and in-flight. Read-only scan of docs/plans/<Module>/*/ plan checkboxes and state.md files plus git worktrees - reports per-feature task progress, the next actionable task, pending manual-validation (⛔) gates, active worktrees, and any integrations queued waiting for a clean tree. No subagents.
---

# Feature Status

Answer "what's left / what's in-flight" cheaply and read-only. No subagents, no
edits.

Invoke: `/feature-status [<Module>]` (omit `<Module>` to scan all).

## Steps

1. Find feature folders: `docs/plans/<Module>/*/` (or `docs/plans/*/*/` for all).
   Each holds `<Feature>-plan.md` and usually `state.md`. A folder with `state.md`
   but **no `-plan.md`** is a backlog **stub** (`Status: deferred`) — list it as
   `deferred` with the one-line summary from its `backlog.md`; do not treat it as a
   zero-task plan.
2. For each feature with a plan, compute task progress by counting task
   headings (`### Task N` / `### ⛔ Task N`) and whether each task's checkboxes are
   all `- [x]`:
   - done = tasks fully checked, total = task count,
   - **next actionable** = first task not fully checked,
   - **pending gate** = the next `⛔` task at or before the next actionable task.
3. From `state.md`, read the **`Status:`** line (`deferred → planned →
   in-progress → blocked → integrated → done`), `Target branch`, `Worktree`, and
   `Integration:` status (e.g. `queued` means it finished but is waiting for a
   clean target tree).
4. List active feature worktrees: `git worktree list` — match `feature/<slug>`
   entries to features.

## Output

A compact table per module:

```
<Module>
  <Feature>   <Status>   <done>/<total>   next: Task <N> "<title>"   [⛔ gate at Task <G>]   [worktree: <path>]   [integration: queued]
  <Idea>      deferred   — <one-line from backlog.md>
  ...
Totals: <X> features, <Y> tasks remaining, <Z> queued integrations, <W> pending gates
```

Flag anything needing the user: queued integrations (commit/stash to land),
pending ⛔ gates (validate to continue), and CONFLICT notes in any `state.md`.
For a Module- or repo-wide view that also folds in loose `BACKLOG.md` items, use
`/module-status <Module>` or `/repo-status`.
