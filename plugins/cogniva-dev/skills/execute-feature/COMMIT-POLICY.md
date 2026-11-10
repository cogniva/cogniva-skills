# Shared commit policy

**`commits=` is the SOLE authority over committing.** No later step, other
flag, ride-along, ADR correction, or repo obligation may create a commit the
policy forbids. `plan=` never authorizes a commit on its own.

Resolve the explicit `commits=` value before applying defaults; an explicit
value takes precedence over defaults. Resolve and validate the policy before
any write, staging, or commit.

- `commits=none|task|final` — `none`: never stage or commit ANYTHING —
  implementation, plans (even persisted ones), ride-alongs, ADR and
  whitespace fixes, repo-obligation output all stay uncommitted in the tree;
  the final handoff reports the uncommitted diff. `task`: one checkpoint
  commit per task; when the task has a plan, **tick the task's plan
  checkboxes BEFORE the task commit
  so the commit SHA represents the completed task state**; checkpoint
  commits never imply approval. `final`: leave ALL run-produced changes
  uncommitted until every task and every landing gate has passed, then
  exactly ONE implementation commit at the caller's final landing step — never
  an earlier or intermediate one. Any git failure under `task`/`final`
  → the task stops `BLOCKED` with the git error as the note; no retry loops,
  no special-casing of specific git errors.

- **Defaults:** lean mode → `commits=none`. Worktree mode →
  `commits=task`, and `commits=none|final` are INVALID
  there — integration is a fast-forward of commits; reject the combination
  with one clear line and stop, never silently ignore it.
