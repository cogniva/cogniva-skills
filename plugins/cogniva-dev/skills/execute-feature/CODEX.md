# execute-feature — Codex backend overlay

Read this ONLY when the Workflow tool is absent from this session (Codex or
any other non-Claude host). It replaces `SKILL.md` Step 3 and nothing else —
Steps 0a, 0b, 1, 2 and 4 apply exactly as written. Only lean mode is
supported here: worktree mode depends on the runtime this host does not
have, so if worktree mode is ON, STOP and say so rather than improvising.

## Replaces Step 3 — sequential subagent loop

You are the executor. For each task in the parsed array that is not `done`,
in order, spawn ONE fresh subagent. Its prompt carries the task's full
`body` VERBATIM plus this frame:

- Work only in WORKSPACE, on BRANCH. Never switch branches. Never push.
- Follow the ACTIVE commit policy — resolve it from `## Flags` in `SKILL.md`
  (lean default `commits=none`) and write the resolved rule into the prompt
  VERBATIM, never a pointer to go and read:
  - `commits=none` → "Do NOT stage or commit anything; leave your changes in
    the working tree."
  - `commits=task` → "FIRST tick THIS task's checkboxes in `<planPath>`, then
    stage ONLY the files you changed and commit with the task's commit
    message." (Under `task` the task agent ticks and commits, so the SHA
    represents the completed task state; the executor-ticks rule below then
    applies to `none`/`final` only.)
  - `commits=final` → "Do NOT stage or commit anything; leave your changes in
    the working tree." The single implementation commit happens once, at
    `SKILL.md` Step 4.
  Any git failure under `task`/`final` → the task returns `BLOCKED` with the
  git error as its `note`; no retry loops.
- When done, reply with a first line of exactly `DONE` or `BLOCKED`, then:
  - `summary:` — 1–2 lines, what changed.
  - `commitSha:` — only if a commit was made.
  - `note:` — only if BLOCKED: exactly what is missing.
  - `followups:` — only if genuinely surfaced; one line each, with a
    concrete receipt.

Wait for that subagent to finish before doing anything else.

## After each task

Parse the subagent's first line.

- `DONE` → tick that task's checkboxes in its `planPath` (the executor
  ticks; task agents under this backend do not edit the plan — except under
  `commits=task`, where the agent has already ticked them before its commit,
  so verify rather than re-tick), record the result, dispatch the next task.
- `BLOCKED` → stop the loop; report which task and its `note`.
- Task `isGate` (`⛔`) and `DONE` → stop the loop after it and report the
  gate. The user resolves it and re-runs the skill to continue.

## Sequencing rules

Strictly sequential. One subagent per task. Later tasks see earlier tasks'
changes in the same WORKSPACE. No reviewer fan-out, no parallelism.

## After the loop

Continue at `SKILL.md` Step 4 exactly as written — the lean path. Its gates
(tree consistency, ride-alongs, repo obligations, ADR check,
`git diff --check`, green gate) run here unchanged, and the run finishes the
same way every lean run does: emit the full `READY FOR REVIEW` handoff per
`HANDOFF.md` beside this file as the final text of the turn.

## Resume

Re-running the skill re-parses the plan; fully-ticked tasks come back `done`
and are skipped — identical to the Claude backend.

## Never emulate the missing runtime

Never attempt to install, emulate, or hand-roll the Workflow JS API, and
never fake its result object. It does not exist on this host. This loop IS
the Codex backend.
