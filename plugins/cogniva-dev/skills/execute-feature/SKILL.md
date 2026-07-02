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

`<plugin>` below = this plugin's root — the directory that contains `scripts/`
AND `templates/`, i.e. the **parent** of the `skills/` dir. It is NOT the skill's
own folder (`.../skills/execute-feature/`), and `templates/` is NOT under the
skill. You resolve `<plugin>` once when you run the `scripts/...` command in
Step 0; reuse that **exact same root** verbatim everywhere `<plugin>` appears
below (including the `templates/...` path in Step 2). Do not re-derive it, and do
not Glob/Read-search for the template under the skill dir.

## Step 0 — create / reuse the isolated worktree (Bash, once)

> **Plan + state live in the PRIMARY checkout — never the worktree.** The plan
> and `state.md` are *control-plane* artifacts: execute-feature reads and
> updates them in place in the primary checkout. They are NOT carried into the
> worktree — `docs/plans/**` is often gitignored, and a fresh worktree only
> contains tracked, committed files, so uncommitted/ignored plan files never
> appear there. The worktree holds ONLY the code deliverable. Always resolve
> plan and state against the primary checkout's `repoRoot`; never
> `<worktree>/docs/plans/...`. (complete-feature already reads `state.md` from
> the primary checkout for the same reason — see docs/adr/0004.)

1. Confirm a plan exists at `docs/plans/<Module>/<Feature>/<Feature>-plan.md`
   in the primary checkout.
2. Derive `<slug>` (kebab of `<Feature>`).
3. Run:
   `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/new-feature-worktree.ps1" -Slug <slug>`
   It reads the user's current branch as the integration **target** (never
   switches it) and prints JSON `{ worktree, branch, base, reused, repoRoot }`.
   Capture `worktree` (absolute), `branch` (`feature/<slug>`), and `repoRoot`
   (the primary checkout — where plan and state live).
4. Define the control-plane paths against `repoRoot` (NOT the worktree):
   - `planPath  = <repoRoot>/docs/plans/<Module>/<Feature>/<Feature>-plan.md`
   - `statePath = <repoRoot>/docs/plans/<Module>/<Feature>/state.md`
5. Record `Target branch`, `Worktree`, and `branch` into `statePath` (the
   primary-checkout `state.md`) if not already present, and set its `Status:`
   line to `in-progress` (the status skills read this).

## Step 1 — parse the plan into tasks (deterministic script — no manual parsing)

Do NOT read or hand-build the task array. Run the parser against the plan in the
PRIMARY checkout (`planPath` from Step 0) and capture its stdout verbatim:

`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/parse-plan-tasks.ps1" -PlanPath "<planPath>"`

It prints a single JSON array of `{ n, title, body, isGate, done }` in document order:
- `body` = the task's full text after its heading, verbatim (all `- [ ]` steps and fenced examples),
- `isGate` = the heading is a `⛔` gate,
- `done` = the task's real (non-fenced) checkboxes are all `- [x]` — drives resume.

On failure it writes a message to stderr and exits non-zero (missing file, or no
`## Task N:` headings); surface that and STOP. Use the captured JSON **verbatim** as
`args.tasks` in Step 2 — do not transform, re-order, or re-derive any field.

## Step 2 — run the Workflow (background, one agent per task)

Read the canonical workflow script at `<plugin>/templates/execute-feature.workflow.js`
— the SAME `<plugin>` root you ran the `scripts/...` commands from in Steps 0–1; it
sits **beside** `scripts/`, never under `skills/`. Run it verbatim (copy its script;
do not rewrite it). If the Read fails, you have the wrong `<plugin>` path — fix it and
retry. Do NOT hand-author the workflow from `WORKFLOW-NOTES.md`: that file documents
the contract for reference, it is not a substitute for the template, and a hand-rolled
version may diverge on resume/checkbox handling. Pass:
```
args = { worktree, featureBranch: "feature/<slug>",
         pluginRoot: "<plugin>",   // parent of this skills/ dir — lets tasks commit via scripts/git-commit.ps1
         planPath:  "<planPath>",   // primary checkout — control-plane, see Step 0
         statePath: "<statePath>",  // primary checkout — control-plane, see Step 0
         tasks: [ ...parsed... ] }
```
Tasks run SEQUENTIALLY in the ONE worktree (each builds on the previous). The
workflow stops early on a BLOCKED task or after a ⛔ gate, and returns
`{ results, done, blocked, gateHit, allDone }`.

If the Workflow tool rejects the script with an error like *"script contains
control characters that would be hidden in the approval dialog"*, the template
has CRLF line endings (a lone `\r` trips the guard). The template must be LF —
check with e.g. `tr -cd '\r' < "<plugin>/templates/execute-feature.workflow.js" | wc -c`
(expect 0). `.gitattributes` enforces `eol=lf`; if a copy still has CRLF, its
checkout escaped that rule (stale plugin cache or subtree checkout under
`core.autocrlf=true`) — re-checkout or strip the CRs before rerunning.

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
- Tasks commit via `scripts/git-commit.ps1` (one call, stages+commits+prints SHA),
  not `git add && git commit`. Never chain shell commands with `&&`/`;` or prefix
  with `cd` — each command is its own call; cwd is already the worktree. This keeps
  every command matchable against the permission allowlist (see docs/adr/0003).
- No reviewer fan-out — one agent per task. (An end-of-feature review is optional
  and off by default.)
- Keep this console lean: the Workflow runs in the background; you only relay
  short status. Suggest `/clear` only if the console itself grows large.
