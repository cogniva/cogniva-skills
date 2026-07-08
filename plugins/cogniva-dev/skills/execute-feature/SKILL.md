---
name: execute-feature
description: Use to execute a feature plan produced by plan-feature, from a single prompt, with a small model. Runs each task in a fresh subagent (lean context, no manual /clear, no reviewer fan-out) inside an isolated git worktree, then auto-integrates the result into the branch you have checked out. Resumable; stops at manual-validation (⛔) gates. Run several at once — each is isolated.
---

# Execute Feature

Execute `docs/plans/<Module>/<Feature>/<Feature>-plan.md` task-by-task. The heavy
work runs in a background Workflow of one-agent-per-task, so this session stays a
lean control console — fire another `execute-feature`, or make small ad-hoc edits
(which auto-isolate into their own worktree), from the same session without
bloating context.

Invoke: `/execute-feature <Module>/<Feature>` (or a plan path).

> **MERGE FLOW — read this first:**
> When all tasks complete the feature is **automatically merged** into the
> user's checked-out branch, then marked **cleanupable** in the ledger (with a
> close-out recipe). There is NO pre-merge validation step — the user validates
> AFTER the merge in their own working tree, then runs `/cleanup-work` to close
> it out (or `/cleanup-allwork` if this session is gone).
>
> ⛔ gates are **mid-process checkpoints** (e.g. "confirm the DB migration before
> writing the code that depends on it") — NOT a pre-merge gate. After the user
> resolves a gate and re-runs this skill, execution continues and the auto-merge
> still happens at the end.

`<plugin>` below = this plugin's root (the parent of this `skills/` dir); it holds the `scripts/` and `templates/` these steps reference.

## Step 0 — create / reuse the isolated worktree (Bash, once)

1. Confirm a plan exists at `docs/plans/<Module>/<Feature>/<Feature>-plan.md`.
2. Derive `<slug>` (kebab of `<Feature>`).
3. Run:
   `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/new-feature-worktree.ps1" -Slug <slug>`
   It reads the user's current branch as the integration **target** (never
   switches it) and prints JSON `{ worktree, branch, base, reused }`. Capture
   `worktree` (absolute) and `branch` (`feature/<slug>`).
4. Record `Target branch`, `Worktree`, and `branch` into the worktree's
   `state.md` if not already present, and set its `Status:` line to
   `in-progress` (the status skills read this).

## Step 1 — parse the plan into one ordered task array

Work from the plan IN THE WORKTREE. First detect the mode by reading
`<Feature>-plan.md`:

- **Flat plan** (no `## Sub-plans (execution order)` heading): parse its own Task
  sections, as before.
- **Multi-plan manifest** (has that heading): read each `subplans/NN-<slug>.md`
  file **in the listed table order** (the list is already dependency-sorted —
  listed order IS execution order; do not re-sort) and parse each one's Task
  sections. Concatenate them into a SINGLE ordered task array. The split is just a
  bigger chunk of sequential work in the SAME worktree — there is still ONE
  integration, at the very end (Step 4).

Each task object is `{ n, title, body, isGate, done, planPath, subplan }` where
- `body` = that task's full text (all its `- [ ]` steps, verbatim, self-contained),
- `isGate` = the heading starts with `⛔`,
- `done` = every checkbox in the task is already `- [x]` (resume support),
- `planPath` = absolute path to the file whose checkboxes this task ticks — the
  manifest/flat plan for a flat plan, or the specific `subplans/NN-<slug>.md` for a
  multi-plan task,
- `subplan` = the sub-plan slug (e.g. `01-<slug>`) for multi-plan tasks, omitted for
  flat plans. Used only for labels/logging.

Task numbers restart per sub-plan; that is fine — tasks are keyed by `(subplan, n)`
for resume and labels.

## Step 2 — run the Workflow (background, one agent per task)

Author/run the Workflow from `<plugin>/templates/execute-feature.workflow.js`
(copy its script; do not rewrite it). Prefer `Workflow({ scriptPath: ... })` over
inlining. If the launch is rejected for *"script contains control characters"*, the
template was checked out with CRLF (a pre-fix Windows checkout — `.gitattributes`
now pins `*.workflow.js` to LF): write an LF copy to the scratchpad
(`tr -d '\r' < template > scratchpad/execute-feature.workflow.js`) and pass THAT
`scriptPath`. Then run, passing:
```
args = { worktree, featureBranch: "feature/<slug>",
         planPath:  "<worktree>/docs/plans/<Module>/<Feature>/<Feature>-plan.md",
         statePath: "<worktree>/docs/plans/<Module>/<Feature>/state.md",
         tasks: [ ...parsed... ] }
```
- `planPath` (global) is the FALLBACK file for ticking checkboxes — used for flat
  plans. For multi-plan, every task carries its own `planPath` (its
  `subplans/NN-<slug>.md`); the workflow ticks per-task.
- `statePath` is always the single `state.md` — all tasks append their one-line log
  there regardless of sub-plan.

Tasks run SEQUENTIALLY in the ONE worktree (each builds on the previous), whether
they came from one plan or several sub-plans. The workflow stops early on a BLOCKED
task or after a ⛔ gate, and returns `{ results, done, blocked, gateHit, allDone }`.

## Step 3 — on workflow completion

- **Blocked / gate hit:** set the WORKTREE `state.md` `Status: blocked` (never the
  primary checkout); report which task and
  why; STOP. The user resolves / validates the specific gate concern, then re-runs
  this skill — Step 1 marks finished tasks `done`, sets `Status: in-progress`
  again, and the workflow resumes (or use the Workflow `resumeFromRunId`). After
  the gate the workflow continues toward auto-merge; the gate is NOT a signal that
  the user should validate the whole feature. If a BLOCKED task surfaced leftover
  scope that won't be done here, capture it:
  `/backlog module=<Module> tier=loose src=<Feature> — <description>`.
- **All tasks done — GREEN GATE (mandatory, no shortcuts):**
  1. **Commit everything first.** `git -C "<worktree>" status --porcelain` MUST be
     empty before the gate runs. The per-task agents commit their own files, but tick
     edits / state.md / stray files can linger — stage and commit them on the feature
     branch now. NEVER run the gate against a dirty tree: a green gate over
     uncommitted changes is a lie (those changes do NOT ride into the merge, so the
     target can break even though "it passed"). This holds even when the gate runs no
     commands. Verify clean, THEN gate.
  2. **Run the repo's configured gate.** Read `<worktree>/.claude/cogniva-dev/green-gate.json`.
     Schema: `{ "commands": [ { "run": "<shell command>", "label": "<short, optional>",
     "note": "<optional reasoning, shown in reports>" } ] }`. Run each `commands[].run`
     IN ORDER, in the worktree. Each must exit 0. The FIRST non-zero exit fails the
     gate: report the failing command (its `label` if present) and its output, and
     STOP — do not integrate.
  3. **No gate file → skip, don't block.** If `green-gate.json` is ABSENT, skip the
     gate and proceed to Step 4 after emitting exactly ONE line: "No
     `.claude/cogniva-dev/green-gate.json` in this repo — skipping the build/test
     gate. Add one to gate future runs (see the opt-in README)." Do NOT prompt, do
     NOT fall back to any build command. Absence is expected for docs-only or
     early-stage repos. A present-but-empty `commands: []` means an intentional
     no-gate — proceed silently. (A .NET Module repo's gate typically runs a
     whole-solution `dotnet build <RepoName>.slnx` — which catches cross-module test
     consumers that scoped per-project builds miss — then `dotnet test <RepoName>.slnx`
     with the suspended UI tests excluded; see the opt-in README for the worked example.)
  4. Only if the gate is GREEN (or skipped/empty), integrate (Step 4). If red, report
     the exact failing command and its output, and STOP.

  For a multi-plan feature this fires only after EVERY sub-plan's tasks are done —
  there is no per-sub-plan integration. Tick the `## Sub-plans` checklist in the
  WORKTREE `state.md` for any sub-plan whose tasks are all complete (resume aid; the
  source of truth is the per-sub-plan checkboxes). All such edits happen in the
  worktree and ride in on the Step 4 merge — never edit the primary checkout.

## Step 4 — auto-integrate into the user's branch

First, **in the WORKTREE** (NEVER the primary checkout — the guard blocks it and a
direct primary edit would dirty the shared tree), set `state.md` `Status: integrated`
and commit it on the feature branch so the merge carries it:
  edit `<worktree>/docs/plans/<Module>/<Feature>/state.md`, then
  `git -C "<worktree>" commit -m "docs(<module>): integrate <Feature>" -- <that state.md>`

Then run:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/integrate-feature.ps1" -WorktreePath "<worktree>" -FeatureBranch "feature/<slug>" -TargetBranch "<target>"`

It pre-merges the target into the feature (sandbox), serializes via a lock, and
**fast-forward LOCAL-pushes** into the target branch (`git push .` — never a
remote). Interpret the JSON `status`:
- `INTEGRATED` — done (the `Status: integrated` flip you committed above is now on
  the branch). Mark the worktree **cleanupable** so it can close itself out later:
  `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/mark-cleanupable.ps1" -Worktree "<worktree>" -Branch "feature/<slug>" -StatePath "<PRIMARY-checkout>/docs/plans/<Module>/<Feature>/state.md" -TargetStatus done -Summary "<one line of what shipped>" -Followups "<deferred items, if any>"`
  (the `-StatePath` is only a reference cleanup maps INTO the worktree at close-out:
  the `Status: done` flip is made + committed IN THE WORKTREE and merged in — the
  primary tree is never written directly.)
  **The feature is now live on the user's branch.** Tell them: "Merged into your
  branch. Validate it in your working tree, then run `/cleanup-work` to close out
  (removes the worktree, sets Status: done). If you close this session first,
  `/cleanup-allwork` will finish it." Do NOT run `git worktree remove` manually —
  cleanup-work / cleanup-allwork own that.
- `QUEUED_DIRTY` — the target tree had uncommitted changes; nothing was clobbered.
  Tell the user to commit/stash, then re-run `execute-feature` (or a future
  `integrate`) to land it. Record "Integration: queued" in the WORKTREE `state.md`
  and commit it there (never edit the primary checkout).
- `CONFLICT` — a real semantic conflict with work already on the target. Report
  the worktree path for resolution (human or a one-shot resolve agent); do not
  force anything.
- `ERROR` — surface the detail; do not retry blindly.

## ADRs during execution

Concrete ADRs are written HERE, not by plan-feature. If the plan has a
`## Candidate ADRs` section, each candidate names the task it's attached to
("Write with: Task N"). When that task completes, its agent writes the confirmed
candidate **verbatim** to `docs/adr/NNNN-<slug>.md` — scan `docs/adr/` for the next
number (see auto-doc's ADR-FORMAT), copy the candidate's title + Provenance +
Relitigation + body, and commit it with that task's files.

- The ADRs were already human-confirmed during planning. Do NOT invent new ones,
  reword them, or add ADRs the plan didn't list — just materialize what's there.
- Rare number collisions (parallel worktrees) surface as a merge conflict at
  integration; resolve by renumbering. Don't pre-reserve.
- Treat the plan's decisions and any existing ADRs as **settled**. If a task truly
  can't proceed without reopening a documented decision, BLOCK and surface it to the
  human with the reason — honour the ADR's relitigation weight; never silently change
  course or re-propose a `Blockers only` / `Compelling reasons only` call.

## Rules

- NEVER push to a remote. NEVER `git switch/checkout/branch` in the primary
  checkout. All task work happens on `feature/<slug>` inside the worktree.
- No reviewer fan-out — one agent per task. (An end-of-feature review is optional
  and off by default.)
- Keep this console lean: the Workflow runs in the background; you only relay
  short status. Suggest `/clear` only if the console itself grows large.
