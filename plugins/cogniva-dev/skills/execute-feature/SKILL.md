---
name: execute-feature
description: Use to execute a feature plan from a single prompt — given EITHER a plan name/path OR the full text of a plan pasted straight into the prompt (e.g. copied from another agent). Accepts any plan format — freeform plans are converted to the task format first, so checkbox tracking and resume work for every run. Runs each task in a fresh subagent via a background Workflow; stops at manual-validation (⛔) gates. In worktree mode the run is isolated in a git worktree and auto-integrates into your branch.
---

# Execute Feature

Run a feature plan task-by-task via a background Workflow (one agent per
task); this session is only the control console — relay short status.

Invoke with EITHER a reference or the plan itself:

- `/cogniva-dev:execute-feature <Module>/<Feature>` (resolves to
  `docs/plans/<Module>/<Feature>/<Feature>-plan.md`), or any plan path.
- `/cogniva-dev:execute-feature <full text of a plan>` — a plan pasted
  straight into the prompt (copied from another agent, a doc, a chat).
  Step 0a names it and lands it on disk before anything runs.

**Worktree dispatch (check first):** worktree mode is ON iff the target
repo's `.claude/cogniva-dev.local.json` has `"worktrees": true`. ON → read
`WORKTREE.md` beside this file NOW; it replaces the steps tagged ⟦worktree⟧.
OFF → ignore the tags; work on the user's checkout and current branch.

**Host dispatch (check second):** if the Workflow tool is not available in
this session (Codex or any non-Claude host), read CODEX.md beside this file
NOW — it replaces Step 3 (the Workflow dispatch). Worktree mode requires the
Claude Workflow runtime; under any other host only lean mode is supported —
if worktree mode is ON and the Workflow tool is absent, STOP and say so.

`<plugin>` = this plugin's root (the parent of `skills/`); it holds
`scripts/` and `templates/`. It is tooling, not the target — the repo being
worked on is the one you were invoked from.

## Step 0a — resolve the argument: plan reference OR pasted plan text

The argument is one of two things. Decide by SHAPE, before anything else:

- **A reference** — one line, no blank line, no `#` heading: either
  `<Module>/<Feature>` or a path to a `.md` file. Read that file.
- **Pasted plan text** — anything multi-line, or carrying markdown
  headings. A plan authored elsewhere and pasted into the prompt. It has
  no file and no name yet, so give it both:
  1. Propose `<Module>/<Feature>` from the text's own H1/Goal — Module
     from an existing `docs/plans/<Module>/` when one clearly fits, else
     propose a new one. Show the proposal in ONE line and get an OK: it
     names a folder and, in worktree mode, a branch, so it is not yours
     to pick silently.
  2. Write the text VERBATIM to
     `docs/plans/<Module>/<Feature>/<Feature>-plan.md`. Never trim,
     reword, or "improve" it on the way in — Step 1 is where shaping
     happens, and an intact original is what makes a bad conversion
     diagnosable afterwards.
  3. Commit it, then continue exactly as if it had been a reference.

Never execute pasted text straight from the prompt. Landing it on disk
first is what gives every later step — normalization, checkboxes, resume,
the `planPath` each agent ticks — a file to point at. ⟦worktree⟧

## Step 0b — workspace

`WORKSPACE` = the repo root; `BRANCH` = the current branch (never switch
it); `START` = `git rev-parse HEAD`. If `git status --porcelain` is
non-empty, show the user what is dirty and get an OK before dispatching —
the run's commits will land next to their uncommitted work. ⟦worktree⟧

## Step 1 — normalize the plan to the task format

Read the plan. If it already has `## Task N:` headings (the PLAN-FORMAT.md
shape), use it as-is. Otherwise CONVERT it: write
`<same folder>/<basename>.tasks.md` in the task format — coarse,
SELF-CONTAINED `## Task N:` sections (each carries everything its agent
needs; agents don't see each other) with `- [ ]` steps and a final commit
step per task. Plans carrying old-style `### Task N:` headings are
normalized to `## Task N:` during this conversion rather than rejected —
in-flight plans in consuming repos predate this standardization. Derive the
tasks faithfully from the document; invent nothing
it doesn't ask for. Commit the converted file, tell the user in one line,
and execute THAT file from here on. Conversion is what buys tracking: every
run — even from a freeform plan — gets checkboxes, so an interrupted run can
resume.

## Step 2 — parse the (task-format) plan

Task sections are parsed deterministically by the script, not by hand:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/parse-plan-tasks.ps1" -PlanPath <plan.md>
```

It prints to stdout a JSON array of `{ n, title, body, isGate, done }`
objects in document order (non-zero exit + a stderr message on a missing
file or a plan with no task headings).

- **Flat plan** (no `## Sub-plans (execution order)` heading): run the
  parser once on the plan file.
- **Multi-plan manifest** (has that heading): run the parser once per
  `subplans/NN-*.md` in the listed table order (already dependency-sorted —
  listed order IS execution order) and concatenate the arrays into ONE
  ordered task array. Still one workspace, one landing at the end.

Each task = `{ n, title, body, isGate, done, planPath, subplan }`. The first
five come straight from the parser output: `n` = the task number; `title` =
the heading remainder; `body` = the task's full text verbatim; `isGate` =
the heading starts with `⛔`; `done` = the task HAS checkboxes AND all are
`- [x]` (the parser ignores example checkboxes inside fenced code blocks; a
task with none is NEVER done — do not skip it on resume). You assign the two
the parser does not emit: `planPath` = the file whose checkboxes the task
ticks (the file the parser was run on); `subplan` = sub-plan slug (task
numbers restart per sub-plan — key by `(subplan, n)`).

Resume = re-running this skill: fully-ticked tasks come back `done` and are
skipped.

## Step 3 — run the Workflow (background)

Run `<plugin>/templates/execute-feature.workflow.js` via
`Workflow({ scriptPath })`, copied verbatim (CRLF rejection → write an LF
copy and use that). Pass:

```
args = { workspace: WORKSPACE, branch: BRANCH, planPath, tasks }
```

⟦worktree⟧ Tasks run SEQUENTIALLY in the one workspace; each agent flips its
own task's checkboxes in `planPath`, stages only its own files, and commits
on `BRANCH`. The workflow stops early on a BLOCKED task or after a ⛔ gate
and returns `{ results, done, blocked, gateHit, allDone, followups }`.

**Blocked / ⛔ gate:** report which task and why (a ⛔ gate is a MID-RUN
checkpoint — e.g. "confirm the destructive migration before dependent tasks"
— not a pre-landing validation). If `followups` is non-empty, run the
backlog gate; STOP. The user resolves it and re-runs this skill to continue.
⟦worktree⟧

## Step 4 — land (all tasks done — in this order, green gate LAST)

1. **Tree clean** — `git status --porcelain` empty; commit leftovers on
   `BRANCH`. Never gate a dirty tree: a green gate over uncommitted changes
   is a lie.
2. **Ride-along gate** — only when a `clear` followup passes Test 3 of
   `CAPTURE-BAR.md` (in the `backlog` skill's directory): present the
   three-section gate, one commit per confirmed ride-along. Depth-1, once
   per run.
3. **Repo obligations** — honour any `### before-integrate` block under the
   target repo CLAUDE.md's `## Cogniva-dev workflow instructions`; commit
   what it produces.
4. **ADR check** —
   `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/check-adrs.ps1" -Workspace "<WORKSPACE>" -Since START` ⟦worktree⟧
   It flags, in what this run added: an ADR number the repo already uses
   (renumber the file, heading, and every reference) and a plan-candidate
   label (`ADR-Cn`) shipped into code or an ADR heading (replace with the
   assigned number). Exit 1 → fix, commit, re-run until clean.
5. **Green gate** (mandatory, no shortcuts) — read
   `.claude/cogniva-dev/green-gate.json`; run its `commands` in order, each
   must exit 0. First failure → report the command
   and its output, STOP (the commits stay on `BRANCH`; say so plainly).
   File absent → one line: "No green-gate.json — skipping the gate." Empty
   `commands` → intentional, skip silently.
6. **Done.** ⟦worktree⟧ Report what landed on `BRANCH` in 2–4 sentences,
   then the backlog gate if `followups` is non-empty.

## ADRs during execution

If the plan carries a `## Candidate ADRs` section ("Write with: Task N"),
that task's agent materializes the confirmed candidate VERBATIM to
`docs/adr/NNNN-<slug>.md` — next free number by scanning `docs/adr/` at
write time, per the adr skill's `ADR-FORMAT.md` — committed with that task's
files. Never invent, reword, or add ADRs the plan didn't list. Candidate
labels (`ADR-Cn`) never ship — dereference every mention to the assigned
number (Step 4.4 enforces this). Existing ADRs are settled — a task that
can't proceed without reopening one BLOCKS and surfaces it (see `/adr`).

## Backlog gate

Never silently write or drop `followups`. Apply `CAPTURE-BAR.md`: drop
covered items, present survivors under `## Backlog candidates`
(`### Clear intent` / `### Needs a decision`), ask once, write only
confirmed items via `/cogniva-dev:backlog`. Empty → say nothing. Deliver the
tables as the final text of the turn.

## Rules

- Never push to a remote; never switch the user's branch uninvited.
- One agent per task; no reviewer fan-out. Keep the console lean.
