# Coverage check

Do NOT capture something that current in-flight work already covers. This is the
observed source of backlog churn: items written during planning and closed days
later during execution, having never been deferred at all.

An item is **covered** if it falls inside any of:

- **The plan being written this session** — its Goal, any task, or any sub-plan.
  (Applies to `plan-feature` above all: scope that the plan actually delivers is
  not deferred scope.)
- **An open plan folder** — a `docs/plans/<Module>/<Feature>/` whose `state.md`
  `Status:` is `planned`, `in-progress`, or `blocked`. The work is already
  queued; a backlog line just duplicates it.
- **The change currently in flight** — the fix `quick-fix` is making, or a task
  remaining in the `execute-feature` run that is proposing it.
- **An active exploration** — a `.explore/<slug>/` thread the user is still
  developing. Ideas raised during exploration belong to the exploration until
  the user decides what happens to it.
- **An existing open item** — an unticked line in any `BACKLOG.md` or a deferred
  stub that covers the same ground. Judge ground, not wording: "make the
  dropdown a treeview" and "the picker should be hierarchical" are one item.

Covered → do not capture. Say so in one line ("that's Task 3 of the plan" /
"already open in `FeatureLifecycle/BACKLOG.md`") and return covered.
Not covered → return not covered to the caller; the caller decides the next step.
