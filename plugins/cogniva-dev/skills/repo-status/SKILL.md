---
name: repo-status
description: Use to see the whole repo at a glance - the live roadmap. Read-only cross-Module roll-up of docs/plans/ - one row per Module (features done/total, in-flight, deferred stubs, loose-backlog count), plus repo-level BACKLOG.md items and global action items (queued integrations, pending ⛔ gates, active worktrees). This is the single skill to answer "what's the overall state / what's left". No subagents, no edits.
---

# Repo Status

The **live roadmap**: the one skill you look at to know the overall state of the
repo. Read-only, no subagents, no edits — there is intentionally no committed
`ROADMAP.md`; this view *is* the roadmap.

Invoke: `/repo-status`.

## Steps

Scan all of `docs/plans/`:

1. **Per Module** (`docs/plans/<Module>/`): roll up, without the per-task detail —
   - feature folders (`<Feature>-plan.md`): count by `Status:` and overall
     done/total tasks; note any in-flight (`in-progress`/`blocked`) feature,
   - stub folders (`state.md` `Status: deferred`, no plan): count as deferred,
   - `<Module>/BACKLOG.md`: open vs resolved loose-item counts.

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
