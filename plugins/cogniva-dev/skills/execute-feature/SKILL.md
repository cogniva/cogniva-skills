---
name: execute-feature
description: Use to execute a feature plan produced by plan-feature, from a single prompt, with a small model. Runs each task in a fresh subagent (lean context, no manual /clear, no reviewer fan-out) inside an isolated git worktree, then auto-integrates the result into the branch you have checked out. Resumable; stops at manual-validation (⛔) gates. Run several at once — each is isolated.
---

# Execute Feature

Execute `docs/plans/<Module>/<Feature>/<Feature>-plan.md` task-by-task. The heavy
work runs in a background Workflow of one-agent-per-task, so this session stays a
lean control console — fire `quick-fix` or another `execute-feature` from the same
session without bloating context.

Invoke: `/cogniva-dev:execute-feature <Module>/<Feature>` (or a plan path).

> **MERGE FLOW — read this first:**
> When all tasks complete the feature is **automatically merged** into the
> user's checked-out branch. There is NO pre-merge validation step — the user
> validates AFTER the merge in their own working tree, then runs
> `/cogniva-dev:complete-feature <Module>/<Feature>` to remove the worktree
> and close out.
>
> ⛔ gates are **mid-process checkpoints** (e.g. "confirm the DB migration before
> writing the code that depends on it") — NOT a pre-merge gate. After the user
> resolves a gate and re-runs this skill, execution continues and the auto-merge
> still happens at the end.

`<plugin>` below = this plugin's root (the parent of this `skills/` dir).

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

## Step 1 — parse the plan into tasks (deterministic script — no manual parsing)

Do NOT read or hand-build the task array. Run the parser against the plan IN THE
WORKTREE and capture its stdout verbatim:

`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/parse-plan-tasks.ps1" -PlanPath "<worktree>/docs/plans/<Module>/<Feature>/<Feature>-plan.md"`

It prints a single JSON array of `{ n, title, body, isGate, done }` in document order:
- `body` = the task's full text after its heading, verbatim (all `- [ ]` steps and fenced examples),
- `isGate` = the heading is a `⛔` gate,
- `done` = the task's real (non-fenced) checkboxes are all `- [x]` — drives resume.

On failure it writes a message to stderr and exits non-zero (missing file, or no
`## Task N:` headings); surface that and STOP. Use the captured JSON **verbatim** as
`args.tasks` in Step 2 — do not transform, re-order, or re-derive any field.

## Step 2 — run the Workflow (background, one agent per task)

Author/run the Workflow from `<plugin>/templates/execute-feature.workflow.js`
(copy its script; do not rewrite it), passing:
```
args = { worktree, featureBranch: "feature/<slug>",
         planPath:  "<worktree>/docs/plans/<Module>/<Feature>/<Feature>-plan.md",
         statePath: "<worktree>/docs/plans/<Module>/<Feature>/state.md",
         tasks: [ ...parsed... ] }
```
Tasks run SEQUENTIALLY in the ONE worktree (each builds on the previous). The
workflow stops early on a BLOCKED task or after a ⛔ gate, and returns
`{ results, done, blocked, gateHit, allDone }`.

## Step 3 — on workflow completion

- **Blocked / gate hit:** set `state.md` `Status: blocked`; report which task and
  why; STOP. The user resolves / validates the specific gate concern, then re-runs
  this skill — Step 1 marks finished tasks `done`, sets `Status: in-progress`
  again, and the workflow resumes (or use the Workflow `resumeFromRunId`). After
  the gate the workflow continues toward auto-merge; the gate is NOT a signal that
  the user should validate the whole feature. If a BLOCKED task surfaced leftover
  scope that won't be done here, capture it:
  `/cogniva-dev:backlog module=<Module> tier=loose src=<Feature> — <description>`.
- **All tasks done:** build/test the feature in the worktree (the repo's build +
  test commands). Only if GREEN, integrate (Step 4). If red, report and STOP.

## Step 4 — auto-integrate into the user's branch

Run:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/integrate-feature.ps1" -WorktreePath "<worktree>" -FeatureBranch "feature/<slug>" -TargetBranch "<target>"`

It pre-merges the target into the feature (sandbox), serializes via a lock, and
**fast-forward LOCAL-pushes** into the target branch (`git push .` — never a
remote). Interpret the JSON `status`:
- `INTEGRATED` — done. Set `state.md` `Status: integrated`. **The feature is now
  live on the user's branch.** Tell them clearly: "The feature has been merged
  into your branch. Validate it in your working tree. When satisfied, run
  `/cogniva-dev:complete-feature <Module>/<Feature>` to remove the worktree
  and set Status: done." Do NOT offer `git worktree remove` manually — that is
  the complete-feature skill's job.
- `QUEUED_DIRTY` — the target tree had uncommitted changes; nothing was clobbered.
  Tell the user to commit/stash, then re-run `execute-feature` (or a future
  `integrate`) to land it. Record "Integration: queued" in `state.md`.
- `CONFLICT` — a real semantic conflict with work already on the target. Report
  the worktree path for resolution (human or a one-shot resolve agent); do not
  force anything.
- `ERROR` — surface the detail; do not retry blindly.

## Rules

- NEVER push to a remote. NEVER `git switch/checkout/branch` in the primary
  checkout. All task work happens on `feature/<slug>` inside the worktree.
- No reviewer fan-out — one agent per task. (An end-of-feature review is optional
  and off by default.)
- Keep this console lean: the Workflow runs in the background; you only relay
  short status. Suggest `/clear` only if the console itself grows large.
