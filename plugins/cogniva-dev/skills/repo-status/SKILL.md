---
name: repo-status
description: Report repository-wide feature progress, deferred work, backlog, and blockers; read-only.
---

# Repo Status

The **live roadmap**: the one skill you look at to know the overall state of the
repo. Read-only, no subagents, no edits — there is intentionally no committed
`ROADMAP.md`; this view *is* the roadmap.

Invoke: `/repo-status`.

## Steps

Scan all of `docs/plans/`, and also `.plans-staging/` for feature folders
(lean mode's default `plan=ephemeral` keeps plans there, untracked and
local to this clone):

1. **Per Module** (`docs/plans/<Module>/`): roll up, without the per-task detail —
   - feature folders (`<Feature>-plan.md`): count by `Status:` and overall
     done/total tasks; note any in-flight (`in-progress`/`blocked`) feature,
   - stub folders (`state.md` `Status: deferred`, no plan): count as deferred,
   - `<Module>/BACKLOG.md`: open vs resolved loose-item counts.
   Feature folders under `.plans-staging/<Module>/` count like
   `docs/plans/` features (same checkbox rules; when a converted
   `<basename>.tasks.md` sits beside the plan, count that file), and a
   Module that exists only there still gets a row. A feature with no
   `state.md` (lean runs keep none) takes its status from its checkboxes:
   `planned` (no task done), `in-progress` (some done), `done` (all done).
   Wherever such a feature is named (for example in Action items), mark it
   `(ephemeral — this clone only)`; a feature in both places counts once,
   from `docs/plans/`.

2. **Repo-level loose items** — `docs/plans/BACKLOG.md` (cross-cutting / no
   Module): list the open (`- [ ]`) ones.

3. **Global action items** — run `git worktree list` ONCE; collect across all
   Modules: queued integrations (`Integration: queued`), pending `⛔` gates,
   `blocked` features, CONFLICT notes, and active `feature/<slug>` worktrees.

## Output

```
Repo status

  Module            features (done/total)   in-flight   deferred   loose
  <Module>          <d>/<t>                 <n>         <n>        <open>/<resolved>
  ...

  Repo backlog (docs/plans/BACKLOG.md): <open> open
    - <open item>
    ...

  Action items
    - <Module>/<Feature>: integration queued — commit/stash to land
    - <Module>/<Feature>: ⛔ gate at Task <N> — validate to continue
    - <Module>/<Feature>: blocked — <why>
    - worktrees: <feature/slug → path>, ...
```

Keep it terse — one row per Module. For depth on one Module use
`/module-status <Module>`; for per-task detail use
`/feature-status [<Module>]`. To capture new work use
`/backlog`.
