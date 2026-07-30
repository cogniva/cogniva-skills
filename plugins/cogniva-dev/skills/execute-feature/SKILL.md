---
name: execute-feature
description: Use to execute a feature plan produced by plan-feature, from a single prompt, with a small model. Runs each task in a fresh subagent (lean context, no manual /clear, no reviewer fan-out) inside an isolated git worktree, then auto-integrates the result into the branch you have checked out. Resumable; stops at manual-validation (⛔) gates. Run several at once — each is isolated.
---

<!-- check-adrs-ignore-file: Step 3.1c cites ADR-C4 as an example. -->


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

`<plugin>` below = this plugin's root (the parent of this `skills/` dir); it holds the `scripts/` and `templates/` these steps reference. `<plugin>` is tooling, not the target: it usually lives in a DIFFERENT checkout (the plugin marketplace repo). The repo being worked on is the one you were invoked from — even when the plan's tasks touch a Claude Code skill or plugin, those files live in the target repo, never under `<plugin>`.

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
  the user should validate the whole feature. If the workflow returned any
  `followups`, run the capture gate below before stopping.
- **All tasks done.** Run these IN ORDER. The green gate is LAST, immediately
  before integration, because everything that rides the merge must be verified by
  it — ride-along work, the repo's `before-integrate` obligations, and any ADR
  renumbering all land BEFORE the gate, never after it:

  ```
  tasks done → tree clean → ride-along gate → before-integrate → ADR check → GREEN GATE → integrate
  ```

  1. **Commit everything first.** `git -C "<worktree>" status --porcelain` MUST be
     empty before you go further. The per-task agents commit their own files, but tick
     edits / state.md / stray files can linger — stage and commit them on the feature
     branch now. NEVER run the gate against a dirty tree: a green gate over
     uncommitted changes is a lie (those changes do NOT ride into the merge, so the
     target can break even though "it passed"). This holds even when the gate runs no
     commands.

  1a. **Ride-along gate (only when a candidate exists).** Read `CAPTURE-BAR.md` in
     the `backlog` skill's directory and apply Test 3 to every `clear` candidate in
     the workflow's `followups`. If NONE passes, skip straight to 1b — the run stays
     fire-and-forget and its backlog candidates are gated after integration, as
     always. If at least one passes, STOP here and present the full three-section
     gate (ride-alongs, then the two backlog tables) as the final text of the turn.
     One interruption, and it happens now rather than after the merge precisely
     because the worktree is still open.

     For each ride-along the user confirms: make the change IN THE WORKTREE, on the
     feature branch, and commit it on its own —
     `git -C "<worktree>" commit -m "feat(<scope>): <what the ride-along did>"`.
     Answer any open question they punted with "your call" by picking, proceeding,
     and saying what you picked. Anything not ridden along is captured to the
     backlog via `/cogniva-dev:backlog`, on the worktree, exactly as a plain
     candidate would be.

     Ride-alongs are **depth-1**: this offer happens once per run. Work you just
     admitted as a ride-along never gets a ride-along gate of its own — anything it
     surfaces goes into the backlog tables of your final report. Do not weigh
     whether "just one more" is warranted; the answer is no by construction.

  1b. **Repo obligations (`before-integrate`).** Check the target repo's CLAUDE.md
     `## Cogniva-dev workflow instructions` for a `### before-integrate` block and
     honour it on the worktree now, committing anything it produces on the feature
     branch. Absent → nothing to do. This runs BEFORE the gate so an obligation that
     writes code is verified like any other change.

  1c. **ADR check (mandatory, BEFORE the gate).** Task agents write
     concrete ADRs during execution without seeing each other or the target branch,
     so two things go wrong silently: two parallel worktrees pick the same free
     number, and a plan's candidate label (`ADR-C4`) gets copied into shipped code
     or into the ADR's own heading instead of the number it was assigned — and
     `ADR-C4` means a different decision in every feature. Run:
     `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/check-adrs.ps1" -Worktree "<worktree>" -TargetBranch "<target>"`
     It exits 0 clean, 1 with problems listed, 2 on a usage error. On exit 1: fix
     the named files IN THE WORKTREE, commit on the feature branch, and re-run it
     until clean — before the green gate, so a renumber that rewrites a code
     reference is verified rather than shipped unseen. Renumber the ADR (file, heading, and any reference to it)
     when the number is taken; dereference the candidate label to the assigned
     number when a heading or a shipped line still cites one. It reports only what
     THIS branch introduced — pre-existing labels elsewhere in the repo are not
     this integration's problem and are deliberately not raised. A file that
     legitimately *discusses* candidate labels (guidance, a glossary entry, a test
     fixture) exempts itself by containing the literal `check-adrs-ignore-file`;
     skipped files are named in the report, so the opt-out is never silent. Reach
     for it only when the label is an example, never to quiet a real citation.

  2. **GREEN GATE — run the repo's configured gate (mandatory, no shortcuts).** This
     is the LAST step before integration; the tree must be exactly what will merge.
     Read `<worktree>/.claude/cogniva-dev/green-gate.json`.
     Schema: `{ "commands": [ { "run": "<shell command>", "label": "<short, optional>",
     "note": "<optional reasoning, shown in reports>" } ] }`. Run each `commands[].run`
     IN ORDER, in the worktree. Each must exit 0. The FIRST non-zero exit fails the
     gate: report the failing command (its `label` if present) and its output, and
     STOP — do not integrate.

     **The gate's cwd is the worktree root, but do NOT leave your shell parked
     there.** Shell cwd persists across tool calls, and a live process sitting in
     the worktree is what makes Windows refuse to delete it at close-out — `git
     worktree remove` deletes the CONTENTS, fails on the directory, and leaves a
     gutted husk. So scope the cwd to the gate: `Push-Location "<worktree>"` … run
     the commands … `Pop-Location` **in the same call**, or run each command as
     `powershell -NoProfile -Command "Set-Location '<worktree>'; <run>"`. Either
     way the shell must be back in the primary checkout before Step 4.
  2a. **No gate file → skip, don't block.** If `green-gate.json` is ABSENT, skip the
     gate and proceed to Step 4 after emitting exactly ONE line: "No
     `.claude/cogniva-dev/green-gate.json` in this repo — skipping the build/test
     gate. Add one to gate future runs (see the opt-in README)." Do NOT prompt, do
     NOT fall back to any build command. Absence is expected for docs-only or
     early-stage repos. A present-but-empty `commands: []` means an intentional
     no-gate — proceed silently. (A .NET Module repo's gate typically runs a
     whole-solution `dotnet build <RepoName>.slnx` — which catches cross-module test
     consumers that scoped per-project builds miss — then `dotnet test <RepoName>.slnx`
     with the suspended UI tests excluded; see the opt-in README for the worked example.)

  2b. **If the gate is red and this run has ride-along commits.** Make ONE repair
     attempt in the worktree, commit it, and re-run the gate. Still red: `git revert`
     every ride-along commit (theirs are the only optional ones), commit the reverts,
     and re-run the gate a third time. Green now → the ride-alongs were the cause;
     integrate the feature and report plainly: "folded-in <X> failed the gate —
     reverted and captured to the backlog instead", then capture each reverted item
     via `/cogniva-dev:backlog`. Still red after the revert → an ordinary pre-existing
     gate failure; report it and STOP. Optional work approved in passing never holds
     finished work hostage. The same revert path applies if a ride-along turns out
     mid-work to be larger than you stated: stop, revert, capture, say what you got
     wrong — do not design your way out of it.

  3. Only if the gate is GREEN (or skipped/empty) AND the ADR check is clean,
     integrate (Step 4). With no ride-along commits in play, a red gate is an
     ordinary failure: report the exact failing command and its output, and STOP.

  For a multi-plan feature this fires only after EVERY sub-plan's tasks are done —
  there is no per-sub-plan integration. Tick the `## Sub-plans` checklist in the
  WORKTREE `state.md` for any sub-plan whose tasks are all complete (resume aid; the
  source of truth is the per-sub-plan checkboxes). All such edits happen in the
  worktree and ride in on the Step 4 merge — never edit the primary checkout.

## Step 4 — auto-integrate into the user's branch

(`before-integrate` already ran in Step 3.1b, before the gate — do not run it
again here.)

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

## Backlog gate — followups from the run

Task agents never write to a `BACKLOG.md`; they return candidates in the workflow
result's `followups` array. Whenever the workflow returns a non-empty `followups`
— on a BLOCKED stop, a gate stop, or after a successful integration — run the gate
in your report, as the last thing you say.

This is the post-integration half of the gate. If a candidate passed Test 3, it was
already offered as a ride-along in Step 3.1a, while the worktree was open — that
happens instead of this, not as well as it. On a BLOCKED or ⛔ stop nothing is
ridden along at all: the run is not finished, so there is no merge to ride.

Read `CAPTURE-BAR.md` in the `backlog` skill's directory. Drop any candidate that
Test 1 covers (a task still remaining in this run, an open plan folder, an existing
open item), then present the survivors under `## Backlog candidates` in its two
tables — `### Clear intent` (numbered; the item and its receipt: which task, and
the located fact) and `### Needs a decision` (numbering continues; the item, its
receipt, and one line on why it is ambiguous). Never head a table "Capture
candidates".

Then ask once, in `CAPTURE-BAR.md`'s words. Write only confirmed candidates, via
`/cogniva-dev:backlog`. Deliver the tables as the final text of the turn, with no
tool call after it. Empty `followups`, or nothing surviving the coverage check,
means say nothing at all — do not print an empty table and do not invent candidates
to fill one.

## ADRs during execution

Concrete ADRs are written HERE, not by plan-feature. If the plan has a
`## Candidate ADRs` section, each candidate names the task it's attached to
("Write with: Task N"). When that task completes, its agent writes the confirmed
candidate **verbatim** to `docs/adr/NNNN-<slug>.md` — scan `docs/adr/` for the next
number (see auto-doc's ADR-FORMAT), copy the candidate's title + Provenance +
Relitigation + body, and commit it with that task's files.

- The ADRs were already human-confirmed during planning. Do NOT invent new ones,
  reword them, or add ADRs the plan didn't list — just materialize what's there.
- Rare number collisions (parallel worktrees) are caught by the Step 3.1c ADR check
  BEFORE the merge — git itself only notices when the two filenames happen to
  match, so different slugs would otherwise merge cleanly into two ADRs claiming
  one number. Resolve by renumbering. Don't pre-reserve.
- The candidate labels (`ADR-C4`) belong to the plan, not the code. When a task
  materializes one, dereference every reference it writes — the ADR's own heading
  and any code comment or skill line citing it — to the assigned number. The same
  Step 3.1c check fails the integration if one survives.
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
