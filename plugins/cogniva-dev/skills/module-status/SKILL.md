---
name: module-status
description: "Use to see the whole state of ONE Module - in-flight features, deferred backlog stubs, and loose BACKLOG.md items in a single read-only view. Wraps the feature-status plan/state scan (scoped to the Module) and adds the Status: lifecycle, deferred stubs, and the loose-item count. No subagents, no edits."
---

# Module Status

Answer "what is the state of this Module" — what is in-flight, what is deferred,
and what is loose — cheaply and read-only. No subagents, no edits.

Invoke: `/module-status <Module>`.

## Steps

Scan `docs/plans/<Module>/`, and also `.plans-staging/<Module>/` for
feature folders (lean mode's default `plan=ephemeral` keeps plans there,
untracked and local to this clone):

1. **Feature folders** (contain `<Feature>-plan.md`): do the same scan as
   `/feature-status`, scoped to this Module —
   - task progress from checkboxes: done = tasks fully `- [x]`, total = task count,
   - **next actionable** = first task not fully checked,
   - **pending gate** = next `⛔` task at or before the next actionable,
   - from `state.md`: the **`Status:`** line, `Target branch`, `Worktree`, and
     `Integration:` (e.g. `queued`).
   A feature folder under `.plans-staging/<Module>/` gets the same scan
   (when a converted `<basename>.tasks.md` sits beside the plan, count that
   file) and is marked `(ephemeral — this clone only)`; a feature in both
   places is listed once, from `docs/plans/`. A feature with no
   `state.md` (lean runs keep none) takes its status from its checkboxes:
   `planned` (no task done), `in-progress` (some done), `done` (all done).

2. **Stub folders** (have `state.md` with `Status: deferred`, but **no
   `-plan.md`**): these are feature-sized backlog stubs. List each with the
   one-line summary from its `backlog.md` (the `Depends on:` / first scope bullet).

3. **`docs/plans/<Module>/BACKLOG.md`** (if present): count open (`- [ ]`) vs
   resolved (`- [x]`) loose items; list the open ones.

4. **Worktrees:** `git worktree list` — match `feature/<slug>` entries to this
   Module's features.

## Output

Group by lifecycle, then the deferred pile, then loose items:

```
<Module>

  In flight / planned
    <Feature>   <Status>   <done>/<total>   next: Task <N> "<title>"   [⛔ gate at Task <G>]   [integration: queued]   [(ephemeral — this clone only)]
    ...
  Deferred (stubs)
    <Idea>   — <one-line from backlog.md>
    ...
  Loose backlog (docs/plans/<Module>/BACKLOG.md): <open> open / <resolved> done
    - <open item>
    ...

Action items: <queued integrations to land, pending ⛔ gates to validate, blockers, CONFLICT notes>
```

Flag anything needing the user: `blocked`/gate features, queued integrations,
CONFLICT notes in any `state.md`. To capture a new deferred item, point them at
`/backlog`; to start one, `/plan-feature` (stub) or
`/execute-feature` (planned).
