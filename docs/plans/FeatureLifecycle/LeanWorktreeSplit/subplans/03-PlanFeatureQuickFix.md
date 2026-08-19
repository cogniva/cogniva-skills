# 03-PlanFeatureQuickFix — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/LeanWorktreeSplit
> Tasks contain NO git worktree/branch step — execute-feature creates the worktree
> and the tasks commit on the feature branch they are already on.

**Goal:** Rewrite plan-feature and quick-fix as lean SKILL.md bodies with
WORKTREE.md overlays, mirroring execute-feature (sub-plan 02).

**Architecture:** Same pattern as sub-plan 02: the body carries the
mode-independent work (design loop / fix loop, ADR candidate discipline, landing
via green gate), a `⟦worktree⟧` tag marks each replaced step, and the overlay
carries worktree creation, `state.md`, and integration. plan-feature stops
seeding `state.md` in lean mode (it moves to the overlay); PLAN-FORMAT.md gets a
one-line note saying so.

**Read these first:** the current
`plugins/cogniva-dev/skills/plan-feature/SKILL.md` and
`plugins/cogniva-dev/skills/quick-fix/SKILL.md` (being replaced);
`plugins/cogniva-dev/skills/execute-feature/SKILL.md` and `WORKTREE.md` as
rewritten by sub-plan 02.

## File structure (locked)

```
plugins/cogniva-dev/skills/plan-feature/SKILL.md      — REPLACED: lean body
plugins/cogniva-dev/skills/plan-feature/WORKTREE.md   — NEW: worktree overlay
plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md — one-line state.md note
plugins/cogniva-dev/skills/quick-fix/SKILL.md         — REPLACED: lean body
plugins/cogniva-dev/skills/quick-fix/WORKTREE.md      — NEW: worktree overlay
```

## Task 1: Replace plan-feature SKILL.md; note in PLAN-FORMAT.md

**Files:**
- Modify: `plugins/cogniva-dev/skills/plan-feature/SKILL.md` (full replace)
- Modify: `plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md`

- [ ] **Step 1 (replace the file):** replace the ENTIRE content of
      `plugins/cogniva-dev/skills/plan-feature/SKILL.md` with EXACTLY:

  ````markdown
  ---
  name: plan-feature
  description: Use when designing ONE feature with a strong model before implementation - runs a focused design session and emits a task-segmented feature plan (executable by /execute-feature). Pairs with adr (ADRs) and glossary.
  ---

  # Plan Feature

  Design ONE feature with the strong model, then emit a plan whose tasks a
  small model can execute later with lean per-task context. Output:
  `docs/plans/<Module>/<Feature>/`. Design only — do not implement.

  **Worktree dispatch (check first):** worktree mode is ON iff the target
  repo's `.claude/cogniva-dev.local.json` has `"worktrees": true`. ON → read
  `WORKTREE.md` beside this file NOW; it replaces the ⟦worktree⟧ steps. OFF →
  ignore the tags; author directly on the user's checkout and current branch.

  The target repo is the checkout you were invoked from. This skill's own
  files and the `<plugin>` scripts live in the plugin install — read formats
  there, but never treat that checkout as the subject of the feature.

  ## Gather first

  1. `<Module>` and `<Feature>` (PascalCase); derive a kebab `<slug>`.
  2. The outcome the feature must deliver, and any hard constraints.

  ## Design loop

  Honour any `### before-planning` block under the target repo CLAUDE.md's
  `## Cogniva-dev workflow instructions` first.

  1. Explore the repo enough to design well — reuse existing code; respect
     its architecture rules.
  2. Domain terms: consult `/glossary`; propose new entries before writing
     them.
  3. Surface each genuine design fork with **AskUserQuestion** (one popup per
     fork). Describe UI choices in prose.
  4. **Honour existing ADRs** — read the relitigation weight before reopening
     anything in `docs/adr/` (see `/adr`); surface a needed change with the
     reason, never quietly work around it.
  5. **Candidate ADRs, not files.** When an architectural decision lands, add
     it to a running candidate list (title, the decision in 1–3 sentences,
     provenance, relitigation only if it differs from the provenance
     default). Nothing is written to `docs/adr/` during design. Provenance is
     *Suggested by agent* only once the human explicitly approves your idea.

  ## Handoff pass (once, when the design is settled)

  Present in ONE pass, as the final text of the turn: the candidate-ADR list
  (the user confirms/amends/drops each — an unconfirmed agent idea never
  becomes a candidate; none → skip, don't invent decisions to record), then
  ride-alongs and backlog candidates in `CAPTURE-BAR.md`'s three sections
  (file in the `backlog` skill's directory). Riding along in a design session
  means amending the plan before it is committed; depth-1, offered once.
  Deferred-scope rules, in short: covered-by-the-plan is not deferred;
  declined scope is gone; deferral needs a receipt in the user's words;
  silence is not deferral. Write confirmed backlog items via
  `/cogniva-dev:backlog`. Approved ADR candidates go INTO the plan (below);
  execute-feature materializes them.

  ## Emit the plan

  ⟦worktree⟧ Write `docs/plans/<Module>/<Feature>/<Feature>-plan.md`
  following `PLAN-FORMAT.md` in this skill's directory (read it). Essentials:

  - Header: **Goal**, **Architecture**, **File structure (locked)**, "Read
    these first", and the line
    `> REQUIRED EXECUTOR: /execute-feature <Module>/<Feature>`.
  - Tasks `### Task N: <title>`, each SELF-CONTAINED (repeat any code it
    needs — never "same as Task 3"), `- [ ]` steps with exact code/commands,
    and a final commit step. Keep tasks COARSE.
  - No ⛔ gates by default — only for a genuinely irreversible mid-run action.
  - Confirmed candidates → a `## Candidate ADRs` section (full title +
    provenance + relitigation + the 1–3 sentence body) plus an "On
    completion, write ADR: <title>" step in the task that finalizes each
    decision.
  - No placeholders ("TBD", "TODO") — those are plan failures.

  Large features: decompose into `subplans/NN-<SubSlug>.md` files plus a
  manifest with a `## Sub-plans (execution order)` table (format in
  PLAN-FORMAT.md). Decide the decomposition yourself, present it to the user
  as ONE feature, and do not over-decompose — a small feature stays one plan.

  Promotion: if this plan fulfills a backlog item, tick its line and append
  `→ planned: <Module>/<Feature>`; a stub folder gets the plan written into
  it.

  Then commit the plan folder as ONE commit — honour any `### before-integrate`
  CLAUDE.md block first so its output rides along:

  ```bash
  git add -- "docs/plans/<Module>/<Feature>"
  git commit -m "plan(<Module>/<Feature>): <one-line summary>"
  ```
  ⟦worktree⟧

  ## Emit a CONCISE decisions summary (what the user actually reads)

  The user does not read or approve the plan — it is executor input. End with
  3–7 bullets of CONSEQUENTIAL decisions only (each: the decision + its
  downstream consequence in one clause), then the plan path and "Run
  `/execute-feature <Module>/<Feature>` when ready." Exclude anything already
  discussed, defaults, step lists, file inventories, and UI tweaks. Present
  one feature even when decomposed — sub-plans are an executor detail.
  ````

- [ ] **Step 2 (PLAN-FORMAT note):** in
      `plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md`, find the line
      introducing the companion state file ("The companion `state.md` (seeded by
      plan-feature, advanced by execute-feature):") and replace it with:
      "The companion `state.md` (seeded by plan-feature IN WORKTREE MODE —
      lean runs have no `state.md` — advanced by execute-feature):".
- [ ] **Step 3 (commit):** `git add plugins/cogniva-dev/skills/plan-feature/SKILL.md plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md` then
      `git commit -m "feat(cogniva-dev): lean plan-feature"`

## Task 2: Create plan-feature WORKTREE.md

**Files:**
- Create: `plugins/cogniva-dev/skills/plan-feature/WORKTREE.md`

- [ ] **Step 1 (create the overlay):** create
      `plugins/cogniva-dev/skills/plan-feature/WORKTREE.md` with EXACTLY:

  ````markdown
  # plan-feature — worktree overlay

  Read this ONLY when the target repo's `.claude/cogniva-dev.local.json` has
  `"worktrees": true`. It replaces the ⟦worktree⟧ steps of `SKILL.md`.

  ## Author on a worktree (before writing anything)

  `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/new-feature-worktree.ps1" -Slug <slug>`
  Author the whole plan folder under
  `<worktree>/docs/plans/<Module>/<Feature>/`. Nothing reaches the user's
  branch until integration; abandoning the design costs nothing.

  Also seed `state.md` next to the plan:

  ```markdown
  # <Feature> — execution state

  Status: planned
  Target branch: (set by execute-feature at run time)
  Worktree: (set by execute-feature)
  Integration: not started

  ## Log
  ```

  `Status:` lifecycle: `deferred → planned → in-progress → blocked →
  integrated → done`; the status skills read it. Multi-plan features seed the
  per-sub-plan checklist variant instead (see PLAN-FORMAT.md).

  ## Integrate and close out (replaces the lean commit step)

  After the single `plan(<Module>/<Feature>): ...` commit on the worktree:

  ```
  powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/integrate-feature.ps1" -WorktreePath "<worktree>" -FeatureBranch "feature/<slug>" -TargetBranch "<your branch>"
  powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/mark-cleanupable.ps1" -Worktree "<worktree>" -Branch "feature/<slug>" -Summary "plan <Module>/<Feature>"
  powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/cleanup-worktrees.ps1" -Scope list -Worktrees "<worktree>"
  ```

  Close the worktree out IMMEDIATELY — a plan is a markdown file that
  integrate already fast-forwarded onto the user's branch; there is nothing
  to validate, and a leftover planning worktree gets silently reused by
  execute-feature (same slug → same path). Run the close-out with your shell
  in the PRIMARY checkout — Windows will not delete a directory that is a
  live process's cwd.

  Only run the last two commands when integrate reported `INTEGRATED`.
  `QUEUED_DIRTY` → still mark cleanupable, SKIP close-out, and say the plan
  is queued for `/cogniva-dev:cleanup-work` once the user's tree is clean.
  `CONFLICT` / `ERROR` → report the detail and stop; force nothing.
  ````

- [ ] **Step 2 (commit):** `git add plugins/cogniva-dev/skills/plan-feature/WORKTREE.md` then
      `git commit -m "feat(cogniva-dev): plan-feature worktree overlay"`

## Task 3: Replace quick-fix SKILL.md

**Files:**
- Modify: `plugins/cogniva-dev/skills/quick-fix/SKILL.md` (full replace)

- [ ] **Step 1 (replace the file):** replace the ENTIRE content of
      `plugins/cogniva-dev/skills/quick-fix/SKILL.md` with EXACTLY:

  ````markdown
  ---
  name: quick-fix
  description: Use for small follow-up changes (UI tweak, bug fix, copy change) without a formal feature plan. Runs the change via a background Workflow so it can be fired repeatedly without bloating context; in worktree mode the change is isolated in a git worktree and auto-integrated.
  ---

  # Quick Fix

  A planless sibling of `/cogniva-dev:execute-feature` for small changes. The
  work runs in a background Workflow, so fire it repeatedly from a control
  session and stay lean.

  Invoke: `/cogniva-dev:quick-fix "<short description of the change>"`.

  **Worktree dispatch (check first):** worktree mode is ON iff the target
  repo's `.claude/cogniva-dev.local.json` has `"worktrees": true`. ON → read
  `WORKTREE.md` beside this file NOW; it replaces the ⟦worktree⟧ steps. OFF →
  work directly on the user's checkout and current branch.

  `<plugin>` = this plugin's root (parent of `skills/`) — tooling, not the
  target; the repo being fixed is the one you were invoked from.

  ## Step 0 — workspace

  `WORKSPACE` = the repo root; `BRANCH` = the current branch; record `START`
  = `git rev-parse HEAD`. Dirty tree → show the user what is dirty and get an
  OK before dispatching. ⟦worktree⟧

  ## Step 0.5 — candidate ADRs (confirm BEFORE dispatch)

  Most quick-fixes produce none. If scoping surfaces an architectural
  decision, hold it as a candidate (title, 1–3 sentences, provenance,
  relitigation if non-default — see `/adr`) and get an explicit
  yes/amend/drop BEFORE dispatching. Fold each confirmed candidate into the
  task body as a final step — "write ADR `NNNN-<slug>.md` (next number by
  scanning `docs/adr/`) with this exact content" — so it is written during
  execution and committed with the fix.

  ## Step 1 — make the change (background Workflow)

  Run `<plugin>/templates/execute-feature.workflow.js` (copy verbatim; CRLF
  rejection → write an LF copy). One synthesized task for trivial fixes, or a
  short ordered list. Each task body: what to change, how to verify, a commit
  step. Planless — no `planPath`. The agent works in `WORKSPACE` on `BRANCH`,
  stages only its own files, and commits.

  ## Step 2 — land it

  Same order as execute-feature's Land step, for the same reasons:
  tree clean → ride-along gate (`CAPTURE-BAR.md` Test 3; depth-1 — a genuine
  second round is another `/cogniva-dev:quick-fix`, which is cheap and the
  whole point of this skill) → `### before-integrate` CLAUDE.md block → ADR
  check
  (`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/check-adrs.ps1" -Workspace "<WORKSPACE>" -Since START` ⟦worktree⟧)
  → GREEN GATE (`.claude/cogniva-dev/green-gate.json`; absent → skip with one
  line) → done ⟦worktree⟧: report the fix in 1–2 sentences.

  ## Rules

  - Never push to a remote; never switch the user's branch.
  - Keep it small — a fix growing into a real feature → stop and suggest
    `/cogniva-dev:plan-feature`.
  - Follow-ups: the workflow returns `followups`; run the backlog gate
    exactly as execute-feature defines it (CAPTURE-BAR; write only confirmed
    items via `/cogniva-dev:backlog`). A fix that resolved a loose
    `BACKLOG.md` item: tick it and append `→ done` — a closure, not a
    capture, no gate needed.
  ````

- [ ] **Step 2 (commit):** `git add plugins/cogniva-dev/skills/quick-fix/SKILL.md` then
      `git commit -m "feat(cogniva-dev): lean quick-fix"`

## Task 4: Create quick-fix WORKTREE.md

**Files:**
- Create: `plugins/cogniva-dev/skills/quick-fix/WORKTREE.md`

- [ ] **Step 1 (create the overlay):** create
      `plugins/cogniva-dev/skills/quick-fix/WORKTREE.md` with EXACTLY:

  ```markdown
  # quick-fix — worktree overlay

  Read this ONLY when the target repo's `.claude/cogniva-dev.local.json` has
  `"worktrees": true`. Same machinery as execute-feature's overlay, without
  plans or `state.md`.

  ## Replaces Step 0

  Derive `<slug>` from the description (e.g. `fix-status-bar-alignment`),
  then:
  `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/new-feature-worktree.ps1" -Slug <slug>`
  Set `WORKSPACE` = `worktree`, `BRANCH` = `feature/<slug>`, the user's
  current branch = `TARGET`. Staleness: `resynced: true` → mention it,
  continue; `stale: true` → STOP, merge `TARGET` into the feature branch in
  the worktree, commit, then dispatch — fixing a file against a stale tree
  lands the fix on code the target already changed.

  ## Replaces Step 2's ADR check and "done"

  - ADR check:
    `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/check-adrs.ps1" -Worktree "<WORKSPACE>" -TargetBranch "<TARGET>"`
  - The green gate's cwd is the worktree — bracket with
    `Push-Location "<WORKSPACE>"` … `Pop-Location` in the SAME call; a shell
    left parked there blocks the worktree's deletion at close-out.
  - After a green gate:
    `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/integrate-feature.ps1" -WorktreePath "<WORKSPACE>" -FeatureBranch "feature/<slug>" -TargetBranch "<TARGET>"`
    - `INTEGRATED` →
      `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/mark-cleanupable.ps1" -Worktree "<WORKSPACE>" -Branch "feature/<slug>" -Summary "<one line of what the fix did>"`
      Tell the user: "Merged into your branch. Validate it, then
      `/cogniva-dev:cleanup-work` to close out; `/cogniva-dev:cleanup-allwork`
      if this session is gone." Never `git worktree remove` manually.
    - `QUEUED_DIRTY` → the target was dirty; commit/stash, re-run integrate.
    - `CONFLICT` → report the worktree path, force nothing. `ERROR` → surface
      the detail; do not retry blindly.
  ```

- [ ] **Step 2 (commit):** `git add plugins/cogniva-dev/skills/quick-fix/WORKTREE.md` then
      `git commit -m "feat(cogniva-dev): quick-fix worktree overlay"`
