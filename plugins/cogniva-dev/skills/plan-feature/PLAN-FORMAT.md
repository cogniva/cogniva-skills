# Feature plan format

A feature plan is one markdown file: `docs/plans/<Module>/<Feature>/<Feature>-plan.md`.
Its tasks are executed one-at-a-time by `/execute-feature`, each in
a fresh subagent context — so **every task must be self-contained**.

## Template

```markdown
# <Feature> — Feature Plan

> REQUIRED EXECUTOR: /execute-feature <Module>/<Feature>
> Tasks contain NO git worktree/branch step — execute-feature creates the worktree
> and the tasks commit on the feature branch they are already on. Never run
> git switch/checkout/branch inside a task.

**Goal:** <one sentence — what this feature delivers>

**Architecture:** <2-4 sentences — approach, where it fits, key types>

**Read these first:** <links to spec/ADRs/related code>

## File structure (locked)

\`\`\`
<list every file created/modified, with a one-line responsibility each>
\`\`\`

## Task N: <title>

**Files:**
- Create: `exact/path.ext`
- Modify: `exact/path.ext`
- Test:   `exact/test/path.ext`

- [ ] **Step 1 (failing test):** <exact test code>
- [ ] **Step 2 (run it, expect fail):** `<exact command>` → <expected output>
- [ ] **Step 3 (implement):** <exact implementation code>
- [ ] **Step 4 (run until green):** `<exact command>` → <expected output>
- [ ] **Step 5 (commit):** `git add <only this task's files>` then
      `git commit -m "<conventional message>"`

## ⛔ Task N: <title>  (manual validation gate — execute-feature STOPS here)

- [ ] **Step 1:** <what the user must run/observe to validate>
- [ ] **Step 2:** Wait for the user to confirm before any later task runs.
```

The companion `state.md` (seeded by plan-feature, advanced by execute-feature):

```markdown
# <Feature> — execution state

Status: planned
Target branch: (set by execute-feature at run time)
Worktree: (set by execute-feature)
Integration: not started

## Log
```

## Large features: orchestration manifest + sub-plans

A feature too big for one plan is split into an **orchestration manifest** plus N
self-contained sub-plans, all in the SAME folder. The user still hands off one
`/execute-feature <Module>/<Feature>` and validates once at the end — the split is
invisible to them.

```
docs/plans/<Module>/<Feature>/
  <Feature>-plan.md          # the manifest (header + sub-plan table, NO tasks)
  state.md                   # multi-plan variant (per-sub-plan checklist)
  subplans/
    01-<SubSlug>.md          # a normal self-contained feature plan (Task sections)
    02-<SubSlug>.md
    03-<SubSlug>.md
```

The manifest `<Feature>-plan.md`:

```markdown
# <Feature> — Feature Plan (orchestrated)

> REQUIRED EXECUTOR: /execute-feature <Module>/<Feature>
> Multi-plan feature: the sub-plans below execute IN LISTED ORDER (already
> dependency-sorted), all in ONE worktree, sequentially, integrating ONCE at the
> end. Tasks contain NO git worktree/branch step.

**Goal:** <one sentence — the whole feature>

**Architecture:** <2-4 sentences — how the sub-plans fit together, key types>

**Read these first:** <links to spec/ADRs/related code>

## Sub-plans (execution order)

| # | Sub-plan | Delivers | Prerequisites |
|---|----------|----------|---------------|
| 1 | `subplans/01-<slug>.md` | <one line> | — |
| 2 | `subplans/02-<slug>.md` | <one line> | 1 |
| 3 | `subplans/03-<slug>.md` | <one line> | 1, 2 |
```

Each `subplans/NN-<SubSlug>.md` is a normal feature plan (the template above):
Task sections, self-contained, exact code/commands. The presence of the
`## Sub-plans (execution order)` heading is how execute-feature detects multi-plan
mode; without it the file is a flat single plan.

Multi-plan `state.md`:

```markdown
# <Feature> — execution state

Status: planned
Target branch: (set by execute-feature at run time)
Worktree: (set by execute-feature)
Integration: not started

## Sub-plans
- [ ] 01-<slug>
- [ ] 02-<slug>
- [ ] 03-<slug>

## Log
```

## Rules

- Self-contained tasks: repeat code rather than referencing earlier tasks.
- Exact paths, exact commands, expected outputs. No placeholders.
- One action per `- [ ]` step (2-5 min).
- Prefix a task with `⛔` when a human must validate before proceeding.
- Order tasks so each builds on the previous (they share one worktree, sequentially).
- Multi-plan: list sub-plans in a valid dependency order; the listed order IS the
  execution order. Sub-plans are self-contained too — never "same as sub-plan 01".
