# 02-ExecuteFeature — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/LeanWorktreeSplit
> Tasks contain NO git worktree/branch step — execute-feature creates the worktree
> and the tasks commit on the feature branch they are already on.

**Goal:** Rewrite execute-feature as a lean SKILL.md (dispatcher + plan
normalization + landing) with a WORKTREE.md overlay, and adapt the workflow
template and check-adrs script to both modes.

**Architecture:** SKILL.md carries only mode-independent execution: workspace,
normalize-any-plan-to-task-format (Step 1), parse, background Workflow, and the
landing sequence ending in the green gate. All worktree mechanics (creation,
staleness gate, state.md, integration, ledger) move to WORKTREE.md, read only
when the per-clone switch (sub-plan 01) is on. The workflow template accepts
`workspace` (with `worktree` as legacy alias) and an optional `statePath`;
`check-adrs.ps1` gains a lean `-Workspace/-Since` parameter set.

**Read these first:** `plugins/cogniva-dev/skills/execute-feature/SKILL.md`
(current, being replaced); `plugins/cogniva-dev/templates/execute-feature.workflow.js`;
`plugins/cogniva-dev/scripts/check-adrs.ps1`; `plugins/cogniva-dev/docs/worktrees.md`
(from sub-plan 01).

## File structure (locked)

```
plugins/cogniva-dev/skills/execute-feature/SKILL.md     — REPLACED: lean body
plugins/cogniva-dev/skills/execute-feature/WORKTREE.md  — NEW: worktree overlay
plugins/cogniva-dev/templates/execute-feature.workflow.js — workspace alias, optional statePath
plugins/cogniva-dev/scripts/check-adrs.ps1              — lean -Workspace/-Since parameter set
docs/adr/NNNN-plan-normalization-step.md                — ADR-C3 (Task 1)
docs/adr/NNNN-worktree-overlay-pattern.md               — ADR-C2 (Task 2)
```

## Candidate ADRs

### ADR-C2: Worktree rules live in per-skill WORKTREE.md overlays
**Provenance:** Suggested by human
Each worktree-using skill keeps a lean, mode-independent SKILL.md; its worktree
mechanics live in a sibling WORKTREE.md read only when the per-clone switch is
on, at steps tagged ⟦worktree⟧. Lean invocations never load worktree text; the
guard hooks remain the behavioral backstop, so instruction and enforcement stay
separable.
**Write with:** Task 2

### ADR-C3: execute-feature normalizes every plan to the task format first
**Provenance:** Suggested by human
Step 1 of execute-feature converts any non-task-format plan into a task-format
file (`<basename>.tasks.md`, committed beside the original) and executes that.
Not every plan comes from plan-feature; normalizing at the door means checkbox
tracking and resume work for freeform and hand-written plans too, and the rest
of the skill handles exactly one shape.
**Write with:** Task 1

## Task 1: Replace SKILL.md with the lean body

**Files:**
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md` (full replace)
- Create: `docs/adr/NNNN-plan-normalization-step.md` (next free number)

- [x] **Step 1 (replace the file):** replace the ENTIRE content of
      `plugins/cogniva-dev/skills/execute-feature/SKILL.md` with EXACTLY:

  ````markdown
  ---
  name: execute-feature
  description: Use to execute a feature plan from a single prompt. Accepts any plan format — freeform plans are converted to the task format first, so checkbox tracking and resume work for every run. Runs each task in a fresh subagent via a background Workflow; stops at manual-validation (⛔) gates. In worktree mode the run is isolated in a git worktree and auto-integrates into your branch.
  ---

  # Execute Feature

  Run a feature plan task-by-task via a background Workflow (one agent per
  task); this session is only the control console — relay short status.

  Invoke: `/cogniva-dev:execute-feature <Module>/<Feature>` (resolves to
  `docs/plans/<Module>/<Feature>/<Feature>-plan.md`) or any plan path.

  **Worktree dispatch (check first):** worktree mode is ON iff the target
  repo's `.claude/cogniva-dev.local.json` has `"worktrees": true`. ON → read
  `WORKTREE.md` beside this file NOW; it replaces the steps tagged ⟦worktree⟧.
  OFF → ignore the tags; work on the user's checkout and current branch.

  `<plugin>` = this plugin's root (the parent of `skills/`); it holds
  `scripts/` and `templates/`. It is tooling, not the target — the repo being
  worked on is the one you were invoked from.

  ## Step 0 — workspace

  `WORKSPACE` = the repo root; `BRANCH` = the current branch (never switch
  it); `START` = `git rev-parse HEAD`. If `git status --porcelain` is
  non-empty, show the user what is dirty and get an OK before dispatching —
  the run's commits will land next to their uncommitted work. ⟦worktree⟧

  ## Step 1 — normalize the plan to the task format

  Read the plan. If it already has `### Task N:` headings (the PLAN-FORMAT.md
  shape), use it as-is. Otherwise CONVERT it: write
  `<same folder>/<basename>.tasks.md` in the task format — coarse,
  SELF-CONTAINED `### Task N:` sections (each carries everything its agent
  needs; agents don't see each other) with `- [ ]` steps and a final commit
  step per task. Derive the tasks faithfully from the document; invent nothing
  it doesn't ask for. Commit the converted file, tell the user in one line,
  and execute THAT file from here on. Conversion is what buys tracking: every
  run — even from a freeform plan — gets checkboxes, so an interrupted run can
  resume.

  ## Step 2 — parse the (task-format) plan

  - **Flat plan** (no `## Sub-plans (execution order)` heading): parse its
    Task sections.
  - **Multi-plan manifest** (has that heading): read each `subplans/NN-*.md`
    in the listed table order (already dependency-sorted — listed order IS
    execution order) and concatenate all Task sections into ONE ordered task
    array. Still one workspace, one landing at the end.

  Each task = `{ n, title, body, isGate, done, planPath, subplan }`: `body` =
  the task's full text verbatim; `isGate` = the heading starts with `⛔`;
  `done` = the task HAS checkboxes AND all are `- [x]` (a task with none is
  NEVER done — do not skip it on resume); `planPath` = the file whose
  checkboxes the task ticks; `subplan` = sub-plan slug (task numbers restart
  per sub-plan — key by `(subplan, n)`).

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
  5. **Green gate** — read `.claude/cogniva-dev/green-gate.json`; run its
     `commands` in order, each must exit 0. First failure → report the command
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

  - Never push to a remote; never switch the user's branch.
  - One agent per task; no reviewer fan-out. Keep the console lean.
  ````

- [x] **Step 2 (write ADR):** scan `docs/adr/` for the next number and write
      ADR-C3 verbatim to `docs/adr/NNNN-plan-normalization-step.md` per the adr
      skill's ADR-FORMAT.
- [x] **Step 3 (commit):** `git add plugins/cogniva-dev/skills/execute-feature/SKILL.md docs/adr/` then
      `git commit -m "feat(cogniva-dev): lean execute-feature with plan normalization"`

## Task 2: Create WORKTREE.md

**Files:**
- Create: `plugins/cogniva-dev/skills/execute-feature/WORKTREE.md`
- Create: `docs/adr/NNNN-worktree-overlay-pattern.md` (next free number)

- [x] **Step 1 (create the overlay):** create
      `plugins/cogniva-dev/skills/execute-feature/WORKTREE.md` with EXACTLY:

  ```markdown
  # execute-feature — worktree overlay

  Read this ONLY when the target repo's `.claude/cogniva-dev.local.json` has
  `"worktrees": true`. It replaces the ⟦worktree⟧-tagged steps of `SKILL.md`.
  Everything here exists so the user's checkout is never touched until one
  clean fast-forward merge at the end.

  ## Replaces Step 0 — isolated worktree

  Derive `<slug>` (kebab of `<Feature>`), then:
  `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/new-feature-worktree.ps1" -Slug <slug>`
  It reads the user's current branch as the integration target (never switches
  it) and prints
  `{ worktree, branch, base, reused, ahead, behind, resynced, stale, staleReason }`.
  Set `WORKSPACE` = `worktree`, `BRANCH` = `feature/<slug>`, and the user's
  current branch = `TARGET`. `START` is not needed — the ADR check compares
  against `TARGET`.

  **Gate on staleness BEFORE Step 1.** A reused worktree may sit behind the
  target, and the plan file inside it may be an older revision — tasks would
  implement a decision the target already replaced.

  - `resynced: true` — it was behind with no commits of its own and was
    fast-forwarded for you; say so in one line, carry on.
  - `stale: true` — behind AND divergent (or dirty): STOP, report
    `staleReason`, `git -C "<WORKSPACE>" merge <TARGET>`, resolve + commit,
    then continue.

  Normalize and parse the plan FROM the worktree afterwards, never before.
  Record `Target branch` / `Worktree` / `branch` in the feature's `state.md`
  (in the worktree) and set `Status: in-progress`.

  ## Qualifiers for Steps 1–4

  - Every path (plan, `state.md`, task files, a converted `.tasks.md`) is
    inside the worktree. NEVER edit the primary checkout — the guard hooks
    deny it.
  - A `state.md` exists next to the plan (task plans from plan-feature): add
    `statePath: "<WORKSPACE>/docs/plans/<Module>/<Feature>/state.md"` to the
    workflow args; each task appends its one-line log there. On a Blocked / ⛔
    stop, set that `state.md` `Status: blocked` before reporting.
  - The green gate's cwd is the worktree root — bracket it with
    `Push-Location "<WORKSPACE>"` … `Pop-Location` in the SAME call. A shell
    left parked in the worktree is what makes Windows unable to delete it at
    close-out.
  - ADR check, worktree form:
    `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/check-adrs.ps1" -Worktree "<WORKSPACE>" -TargetBranch "<TARGET>"`

  ## Replaces Step 4.6 "Done" — landing = integration

  1. If a `state.md` exists: set `Status: integrated` and commit it on the
     feature branch so the merge carries it.
  2. `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/integrate-feature.ps1" -WorktreePath "<WORKSPACE>" -FeatureBranch "feature/<slug>" -TargetBranch "<TARGET>"`
     It pre-merges the target into the feature, serializes via a lock, and
     fast-forward LOCAL-pushes into the target branch (never a remote).
  3. `INTEGRATED` → mark the worktree cleanupable:
     `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/mark-cleanupable.ps1" -Worktree "<WORKSPACE>" -Branch "feature/<slug>" -StatePath "<primary>/docs/plans/<Module>/<Feature>/state.md" -TargetStatus done -Summary "<one line of what shipped>" -Followups "<deferred items, if any>"`
     (omit `-StatePath`/`-TargetStatus` when there is no `state.md`). Tell the
     user: "Merged into your branch. Validate in your working tree, then run
     `/cogniva-dev:cleanup-work` to close out; if this session is gone,
     `/cogniva-dev:cleanup-allwork` finishes it." Never `git worktree remove`
     manually — the cleanup skills own that.
  4. `QUEUED_DIRTY` → the target tree had uncommitted changes; nothing was
     clobbered. Record "Integration: queued" in the WORKTREE `state.md` (when
     present); tell the user to commit/stash and re-run.
  5. `CONFLICT` → a real conflict with work already on the target: report the
     worktree path for resolution, force nothing. `ERROR` → surface the
     detail; do not retry blindly.
  ```

- [x] **Step 2 (write ADR):** scan `docs/adr/` for the next number and write
      ADR-C2 verbatim to `docs/adr/NNNN-worktree-overlay-pattern.md` per the adr
      skill's ADR-FORMAT.
- [x] **Step 3 (commit):** `git add plugins/cogniva-dev/skills/execute-feature/WORKTREE.md docs/adr/` then
      `git commit -m "feat(cogniva-dev): execute-feature worktree overlay"`

## Task 3: Workflow template — workspace arg + optional statePath

**Files:**
- Modify: `plugins/cogniva-dev/templates/execute-feature.workflow.js`

- [x] **Step 1 (read it):** read the template top-to-bottom before editing; the
      steps below name anchors, not line numbers.
- [x] **Step 2 (workspace alias):** where the script reads `args.worktree`
      (destructuring or direct access), accept both:
      `const workspace = args.workspace ?? args.worktree;` and use `workspace`
      everywhere the worktree path was used. Update the header comment's args
      documentation accordingly (`workspace` primary, `worktree` legacy alias).
- [x] **Step 3 (optional statePath):** every instruction the script emits that
      references `statePath` (the per-task state-log append) must be emitted
      ONLY when `args.statePath` is set — same pattern the tick instruction
      already uses for `taskPlanPath` (`taskPlanPath ? … : null`). A missing
      `statePath` must produce no state-log instruction and no error.
- [x] **Step 4 (tick guard):** confirm the tick instruction is emitted only when
      the task has a `planPath` (it already is — the `taskPlanPath ? … : null`
      pattern); if any other line assumes `planPath` is always set, guard it the
      same way.
- [x] **Step 5 (syntax check):** `node --check plugins/cogniva-dev/templates/execute-feature.workflow.js` → exit 0.
- [x] **Step 6 (commit):** `git add plugins/cogniva-dev/templates/execute-feature.workflow.js` then
      `git commit -m "feat(cogniva-dev): workflow template takes workspace arg, statePath optional"`

## Task 4: check-adrs.ps1 — lean -Workspace/-Since parameter set

**Files:**
- Modify: `plugins/cogniva-dev/scripts/check-adrs.ps1`
- Test:   `plugins/cogniva-dev/tests/check-adrs/` (extend the existing suite in its own style)

- [x] **Step 1 (read it):** read the script and the existing tests under
      `plugins/cogniva-dev/tests/check-adrs/` to match their conventions.
- [x] **Step 2 (parameter set):** add a second parameter set alongside the
      existing `-Worktree`/`-TargetBranch` pair: `-Workspace <path>` +
      `-Since <commit-ish>`. In that mode the examined change set is
      `git -C <Workspace> diff --name-only <Since>..HEAD` (plus the same
      untracked-file handling the worktree mode uses, if any) and "what THIS
      work added" means added lines in `<Since>..HEAD`. All existing checks
      (duplicate ADR number vs the rest of the repo at HEAD; leaked `ADR-Cn`
      labels; the `check-adrs-ignore-file` opt-out) run unchanged over that
      set. Exit codes keep their meaning (0 clean / 1 problems / 2 usage).
- [x] **Step 3 (tests):** add at least: one case where `-Since` mode flags a
      duplicate number introduced after the since-commit, one where it flags a
      leaked `ADR-Cn`, and one clean pass. Run the suite the same way the
      existing check-adrs tests are run (see the test folder's runner/README) →
      all green.
- [x] **Step 4 (commit):** `git add plugins/cogniva-dev/scripts/check-adrs.ps1 plugins/cogniva-dev/tests/check-adrs/` then
      `git commit -m "feat(cogniva-dev): check-adrs lean -Workspace/-Since mode"`
