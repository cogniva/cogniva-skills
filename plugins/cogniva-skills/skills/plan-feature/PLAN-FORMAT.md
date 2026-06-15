# Feature plan format

A feature plan is one markdown file: `docs/plans/<Module>/<Feature>/<Feature>-plan.md`.
Its tasks are executed one-at-a-time by `/cogniva-skills:execute-feature`, each in
a fresh subagent context — so **every task must be self-contained**.

## Template

```markdown
# <Feature> — Feature Plan

> REQUIRED EXECUTOR: /cogniva-skills:execute-feature <Module>/<Feature>
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

## Rules

- Self-contained tasks: repeat code rather than referencing earlier tasks.
- Exact paths, exact commands, expected outputs. No placeholders.
- One action per `- [ ]` step (2-5 min).
- Prefix a task with `⛔` when a human must validate before proceeding.
- Order tasks so each builds on the previous (they share one worktree, sequentially).
