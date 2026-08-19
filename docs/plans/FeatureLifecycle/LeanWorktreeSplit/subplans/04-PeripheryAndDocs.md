# 04-PeripheryAndDocs — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/LeanWorktreeSplit
> Tasks contain NO git worktree/branch step — execute-feature creates the worktree
> and the tasks commit on the feature branch they are already on.

**Goal:** Make the remaining skills mode-aware (short-circuits and mode-neutral
wording) and update repo docs.

**Architecture:** cleanup-work / cleanup-allwork stop early when the switch is
off. backlog, explore-idea and groom-backlog lose their worktree-assuming
phrases (they need no overlays — only wording). The repo README and the
cogniva-dev plugin description mention the two modes; the module-deps `-Check`
idea is captured to the backlog.

**Read these first:** `plugins/cogniva-dev/docs/worktrees.md` (sub-plan 01);
the current SKILL.md of each file below.

## File structure (locked)

```
plugins/cogniva-dev/skills/cleanup-work/SKILL.md     — mode short-circuit prepended
plugins/cogniva-dev/skills/cleanup-allwork/SKILL.md  — mode short-circuit prepended
plugins/cogniva-dev/skills/backlog/SKILL.md          — mode-neutral wording
plugins/cogniva-dev/skills/explore-idea/SKILL.md     — trimmed workflow end-note
plugins/cogniva-dev/skills/groom-backlog/SKILL.md    — mode-neutral wording
README.md                                            — modes mentioned in the cogniva-dev section
.claude-plugin/marketplace.json                      — (no version change here; see plan header note)
plugins/cogniva-dev/.claude-plugin/plugin.json       — description mentions optional worktree mode
BACKLOG.md                                           — module-deps -Check capture
```

## Task 1: Short-circuit the cleanup skills

**Files:**
- Modify: `plugins/cogniva-dev/skills/cleanup-work/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/cleanup-allwork/SKILL.md`

- [x] **Step 1 (both files):** immediately after each file's H1 heading and
      intro paragraph, insert this block:

  ```markdown
  ## Mode check (first)

  If the target repo's `.claude/cogniva-dev.local.json` is absent or its
  `"worktrees"` is not `true`, reply "Worktree mode is off in this repo —
  nothing to clean." and STOP.
  ```

- [x] **Step 2 (commit):** `git add plugins/cogniva-dev/skills/cleanup-work/SKILL.md plugins/cogniva-dev/skills/cleanup-allwork/SKILL.md` then
      `git commit -m "feat(cogniva-dev): cleanup skills short-circuit when worktrees are off"`

## Task 2: Mode-neutral wording in backlog, explore-idea, groom-backlog

**Files:**
- Modify: `plugins/cogniva-dev/skills/backlog/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/explore-idea/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/groom-backlog/SKILL.md`

- [x] **Step 1 (backlog):** grep `plugins/cogniva-dev/skills/backlog/SKILL.md`
      for `worktree` and `primary checkout`. Rewrite each hit mode-neutrally:
      writing happens "in your workspace (the worktree you are working in, when
      one is active; otherwise the checkout)"; keep the tier-1
      primary-capture rule but condition it: "in worktree mode, tier-1 files
      (`docs/plans/BACKLOG.md`, `docs/plans/<Module>/BACKLOG.md`) are the ONLY
      tracked files captured directly in the primary checkout". Do not change
      any capture-bar semantics.
- [x] **Step 2 (explore-idea):** replace the closing section
      `## Note for the ambient-worktree workflow` (heading and body) with:

  ```markdown
  ## Note for worktree mode

  In worktree mode (`.claude/cogniva-dev.local.json` `"worktrees": true`),
  `.explore/**` stays on the primary checkout's exempt list: it is gitignored,
  so brainstorm writes never touch the branch and need no worktree.
  ```

- [x] **Step 3 (groom-backlog):** grep for `worktree`; rewrite each hit
      mode-neutrally the same way as Step 1 (grooming itself edits only
      `BACKLOG.md` files and plan stubs; in worktree mode those edits follow the
      same tier-1 / worktree rules the backlog skill states).
- [x] **Step 4 (commit):** `git add plugins/cogniva-dev/skills/backlog/SKILL.md plugins/cogniva-dev/skills/explore-idea/SKILL.md plugins/cogniva-dev/skills/groom-backlog/SKILL.md` then
      `git commit -m "docs(cogniva-dev): mode-neutral wording in backlog, explore-idea, groom-backlog"`

## Task 3: README, plugin description, backlog capture

**Files:**
- Modify: `README.md`
- Modify: `plugins/cogniva-dev/.claude-plugin/plugin.json`
- Modify: `BACKLOG.md` (repo root; create if absent)

- [x] **Step 1 (README):** in the cogniva-dev section of the repo `README.md`,
      after the pieces table, add one paragraph:

  ```markdown
  cogniva-dev's workflow skills run in two modes: **lean** (default — work
  directly on your branch; no worktrees, no state tracking) and **worktree**
  (per-clone opt-in via untracked `.claude/cogniva-dev.local.json`
  `{ "worktrees": true }` — isolated worktrees, guard hooks, auto-integration).
  See `plugins/cogniva-dev/docs/worktrees.md`.
  ```

- [x] **Step 2 (plugin.json):** in
      `plugins/cogniva-dev/.claude-plugin/plugin.json`, update the
      `description`: replace the phrase `with isolated-worktree execution and
      ledger-based cleanup (cleanup-work, cleanup-allwork)` with `with optional
      per-clone isolated-worktree execution and ledger-based cleanup
      (cleanup-work, cleanup-allwork)`. (Version is NOT bumped in this task —
      the bump is offered at integration per `CLAUDE.md ## Rules`, and it must
      change `plugin.json` and `.claude-plugin/marketplace.json` together.)
- [x] **Step 3 (backlog):** append to the repo-root `BACKLOG.md` (create with a
      `# Backlog` heading if absent):

  ```markdown
  - [ ] Port a `-Check` gate mode into `module-deps` (report cycles, exit 1, write nothing — CognivaNewRepo's local copy has one to crib from) so completion flows can verify Module dependencies  `size:S` `area:skills` `src:LeanWorktreeSplit`
  ```

- [x] **Step 4 (commit):** `git add README.md plugins/cogniva-dev/.claude-plugin/plugin.json BACKLOG.md` then
      `git commit -m "docs: two-mode note in README and plugin description; backlog module-deps -Check"`
