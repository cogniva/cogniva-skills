# execute-feature — Codex backend overlay

Read this ONLY when the Workflow tool is absent from this session (Codex or
any other non-Claude host). For `execute-feature` it replaces `SKILL.md`
Step 3 and nothing else — Steps 0, 0a, 0b, 1, 2 and 4 apply exactly as written
(subject to `## Repository CLAUDE.md under Codex` below). It is ALSO the
sequential backend `quick-fix` uses in place of that skill's Step 1:
quick-fix synthesizes one or more PLANLESS tasks — no `planPath`, no
checkboxes, no plan resume — and after the loop lands through its OWN
Step 2, not through `execute-feature` Step 4. Only lean mode is
supported here: worktree mode depends on the runtime this host does not
have, so if worktree mode is ON, STOP and say so rather than improvising.

## Replaces Step 3 — sequential subagent loop

You are the executor. Both executors hand task agents the same prompt and
read the same result shape: the prompt comes from
`<plugin>/scripts/new-task-prompt.ps1`, kept identical by test to the prompt
the Workflow template builds, and the result is one JSON object conforming
to `<plugin>/templates/task-result.schema.json` — the schema the template
passes to its agents — checked by `<plugin>/scripts/test-task-result.ps1`.
`<plugin>` = this plugin's root (the parent of `skills/`).

For each task in the parsed array that is not `done`, in order:

1. Write the task as JSON — `{ "n": <n>, "title": "<title>", "body": "<body>" }`
   with the task's full `body` VERBATIM (the parser's own object for the
   task works as is; extra fields are ignored) — to a temp file in the
   system temp directory, never inside the repo.
2. Build the prompt:
   `pwsh -NoProfile -File "<plugin>/scripts/new-task-prompt.ps1" -Workspace "<WORKSPACE>" -Branch "<BRANCH>" -Commits <policy> -TaskFile "<task file>" -ResultContract`,
   adding `-PlanPath "<the task's planPath>"` when the task has one (a
   planless quick-fix task has none) and `-StatePath "<state.md>"` only
   when the run has one. `<policy>` is the ACTIVE commit policy resolved
   from `## Flags` in `SKILL.md` (lean default `none`); the script writes
   the matching rule into the prompt — under `task`: tick this task's
   checkboxes in its `planPath` first, then stage only its own files and
   commit; under `none`/`final`: stage and commit nothing. A non-zero exit
   → stop and show its output; never hand-write a prompt instead.
3. Spawn ONE fresh subagent and send the script's stdout as its prompt
   VERBATIM — no paraphrase, no summary, no added frame or preamble. Where
   the agent host lets you choose, start it WITHOUT this conversation's
   history.
4. Wait for that subagent to finish before doing anything else. A git
   failure under `task`/`final` comes back as the worker's `BLOCKED`, with
   the git error as its `note`; no retry loops.

## After each task

Save the subagent's whole reply to a temp file in the system temp
directory and run
`pwsh -NoProfile -File "<plugin>/scripts/test-task-result.ps1" -ReplyFile "<reply file>"`.
Delete both temp files once the task's result is recorded.

- Exit 1 (`MALFORMED: <reason>`) → the task is `BLOCKED` with the note
  `malformed worker result: <reason>`. No retry, no re-prompt — the same
  rule as the Workflow template's null result. Exit 2 means the validator
  command itself was wrong: fix the command and re-run the validator, never
  the task.
- Exit 0 → stdout is the result (`status`, `summary`, and where present
  `commitSha`, `note`, `followups`). Then:
  - `DONE` → the worker's prompt told it to tick its own checkboxes in its
    `planPath` (under `commits=task` it ticked them before its commit):
    verify they are all `- [x]` and tick any it missed, record the result,
    and dispatch the next task. A task with no `planPath` (planless
    quick-fix) has nothing to tick — just record the result and move on.
  - `BLOCKED` → stop the loop; report which task and its `note`.
  - Task `isGate` (`⛔`) and `DONE` → stop the loop after it and report the
    gate. The user resolves it and re-runs the skill to continue.
- After every task print one status line, the line the Workflow template
  logs: `<tag> (<title>): <STATUS>[ @<commitSha>]` — `<tag>` is
  `<subplan>/task-<n>` for a sub-plan task, else `task-<n>`; the
  ` @<commitSha>` part only when the result carries one.
- `followups` arrive structured (`description`, `receipt`, `strength`, and
  optionally `size` and `because`). Collect them from every result and run
  the backlog gate on them exactly as `SKILL.md` defines it: at a ⛔ gate or
  `BLOCKED` stop as its Step 3 says, otherwise at landing.

## Sequencing rules

Strictly sequential. One subagent per task. Later tasks see earlier tasks'
changes in the same WORKSPACE. No reviewer fan-out, no parallelism.

## After the loop

Continue at the CALLER's landing step — `execute-feature` → `SKILL.md`
Step 4 exactly as written; `quick-fix` → its own Step 2. Both run the same
lean gates (tree consistency, ride-alongs, repo obligations, ADR check,
`git diff --check`, green gate, and — under `commits=final` — the single
final commit AFTER the green gate; quick-fix also runs its structural check,
between the repo obligations and the ADR check, exactly as its Step 2 says,
and the architecture standards a task needs travel in its body, so both
backends hand workers the same text), and the run finishes the same way every
lean run does: emit the full `READY FOR REVIEW` handoff per `HANDOFF.md`
beside this file as the final text of the turn.

## Resume

Plan-backed runs (`execute-feature`): re-running the skill re-parses the
plan; fully-ticked tasks come back `done` and are skipped — identical to the
Claude backend. A planless quick-fix has no plan to resume — re-run the
quick-fix itself.

## Repository CLAUDE.md under Codex

The target repo's CLAUDE.md stays authoritative for SUBSTANTIVE constraints
— safety rules, architecture/dependency boundaries, domain invariants,
data-integrity rules, UI constraints, diagnostics requirements, testing
restrictions, review-blocking requirements, and ADR/documentation rules that
constrain what is safe or valid. Honour those as written.

Do NOT import Claude-specific operating mechanics merely because CLAUDE.md
describes them: Workflow-runtime mechanics, worktree creation/integration
conventions, Claude-specific hooks or control-console behaviour, automatic
staging/committing, branch/worktree lifecycle machinery, Claude-specific
model/tool preferences. A `### before-integrate` block that expresses a
substantive repository gate → honour the gate; the Claude lifecycle
mechanics around it (commits, worktrees, integration) stay out — and nothing
in CLAUDE.md ever overrides `commits=`.

## Never emulate the missing runtime

Never attempt to install, emulate, or hand-roll the Workflow JS API, and
never fake its result object. It does not exist on this host. This loop IS
the Codex backend.
