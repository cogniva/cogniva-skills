# 01-SwitchAndHooks — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/LeanWorktreeSplit
> Tasks contain NO git worktree/branch step — execute-feature creates the worktree
> and the tasks commit on the feature branch they are already on.

**Goal:** Introduce the per-clone worktrees switch (untracked
`.claude/cogniva-dev.local.json`, default off), gate the three guard hooks on
it, and document it.

**Architecture:** A tiny predicate — read `<repo>/.claude/cogniva-dev.local.json`,
`worktrees === true` — replaces the `.claude/cogniva-dev/` directory-presence
test in all three hook scripts. A new docs page defines the switch; the repo
template gitignores the file; the template opt-in README is reworded (the
directory is config home, not a switch).

**Read these first:** `plugins/cogniva-dev/scripts/guard-primary-edit.js`,
`guard-primary-git.js`, `nudge-backlog-commit.js`;
`plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md`.

## File structure (locked)

```
plugins/cogniva-dev/docs/worktrees.md                          — NEW: the switch doc
plugins/cogniva-dev/scripts/guard-primary-edit.js              — switch predicate replaces marker test
plugins/cogniva-dev/scripts/guard-primary-git.js               — same
plugins/cogniva-dev/scripts/nudge-backlog-commit.js            — same
plugins/cogniva-dev/templates/repo/.gitignore                  — ignore the switch file
plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md — reword: config home, not switch
docs/adr/NNNN-per-clone-worktree-switch.md                     — ADR-C1 (written by Task 1)
```

## Candidate ADRs

### ADR-C1: Worktree mode is a per-clone opt-in via an untracked config file
**Provenance:** Suggested by human
Worktree enforcement and worktree skill behavior are controlled per clone by
untracked `.claude/cogniva-dev.local.json` (`{"worktrees": true}`), defaulting
to OFF — lean, direct-on-branch operation. The tracked `.claude/cogniva-dev/`
directory is no longer a mode switch; it remains the home of tracked repo
config (`green-gate.json`, which applies in both modes). Chosen so devs who
never use worktrees pay no worktree cost, on any repo, without per-repo
negotiation.
**Write with:** Task 1

## Task 1: Switch doc, gitignore template, README rewording, ADR

**Files:**
- Create: `plugins/cogniva-dev/docs/worktrees.md`
- Modify: `plugins/cogniva-dev/templates/repo/.gitignore`
- Modify: `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md`
- Create: `docs/adr/NNNN-per-clone-worktree-switch.md` (next free number)

- [ ] **Step 1 (docs page):** create `plugins/cogniva-dev/docs/worktrees.md` with EXACTLY:

  ```markdown
  # Worktree mode — the per-clone switch

  cogniva-dev's workflow skills run in one of two modes, decided PER CLONE by an
  untracked config file:

  - **Lean (default)** — no file, or `"worktrees": false`. Skills work directly on
    your current checkout and branch: no worktrees, no ledger, no `state.md`
    lifecycle. The quality steps still run — ADR discipline (`/adr`), the ADR
    check, and the repo's `green-gate.json`.
  - **Worktree** — `.claude/cogniva-dev.local.json` at the repo root contains
    `{ "worktrees": true }`. Every workflow skill isolates its work in a git
    worktree that fast-forward merges into your checked-out branch, and the guard
    hooks enforce that nothing edits the primary checkout directly.

  ## Turning it on

  ```json
  { "worktrees": true }
  ```

  in `.claude/cogniva-dev.local.json`, which must be listed in the repo's
  `.gitignore`. The file is a personal, per-clone choice and is never committed —
  committing it would flip the mode for everyone.

  ## What reads the switch

  - **Skills** — plan-feature, execute-feature and quick-fix read their sibling
    `WORKTREE.md` overlay only when the switch is on. cleanup-work /
    cleanup-allwork short-circuit when it is off ("Worktree mode is off in this
    repo — nothing to clean.").
  - **Hooks** — `guard-primary-edit.js`, `guard-primary-git.js`, and
    `nudge-backlog-commit.js` allow everything when the switch is off or absent.

  ## What `.claude/cogniva-dev/` means now

  The tracked `.claude/cogniva-dev/` directory is NOT a mode switch. It is the
  home of tracked whole-repo config: `green-gate.json` (runs in BOTH modes) and
  the README. A repo can have a green gate without anyone using worktrees.
  ```

- [ ] **Step 2 (gitignore template):** in
      `plugins/cogniva-dev/templates/repo/.gitignore` append:

  ```
  # cogniva-dev per-clone worktree switch (personal, never committed)
  .claude/cogniva-dev.local.json
  ```

- [ ] **Step 3 (README template):** in
      `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md`, replace
      the opening section (everything from the `# cogniva-dev opt-in marker`
      heading through the "**To opt out**, delete this directory…" paragraph)
      with:

  ```markdown
  # cogniva-dev repo config

  This directory holds this repository's TRACKED cogniva-dev configuration —
  today that is `green-gate.json` (below). It is NOT a mode switch.

  **Worktree mode** (isolated-worktree execution + primary-checkout guards) is a
  per-clone, personal opt-in: an untracked `.claude/cogniva-dev.local.json`
  containing `{ "worktrees": true }`. Default is lean — skills work directly on
  your checkout. See the plugin's `docs/worktrees.md`.
  ```

      Keep the `## Green gate config` section unchanged.

- [ ] **Step 4 (write ADR):** scan `docs/adr/` for the next number and write
      ADR-C1 verbatim to `docs/adr/NNNN-per-clone-worktree-switch.md` per the adr
      skill's ADR-FORMAT.
- [ ] **Step 5 (commit):** `git add plugins/cogniva-dev/docs/worktrees.md plugins/cogniva-dev/templates/repo/.gitignore "plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md" docs/adr/` then
      `git commit -m "feat(cogniva-dev): per-clone worktrees switch — docs, templates, ADR"`

## Task 2: Gate the three hook scripts on the switch

**Files:**
- Modify: `plugins/cogniva-dev/scripts/guard-primary-edit.js`
- Modify: `plugins/cogniva-dev/scripts/guard-primary-git.js`
- Modify: `plugins/cogniva-dev/scripts/nudge-backlog-commit.js`

- [ ] **Step 1 (shared predicate):** in EACH of the three scripts, add this
      function after the existing helper functions (each script already
      `require`s `fs` and `path`):

  ```js
  // Worktree mode is a per-clone opt-in: untracked .claude/cogniva-dev.local.json
  // with {"worktrees": true}. Absent/false/unreadable => lean mode => this hook
  // stands down (contract: on any uncertainty, allow).
  function worktreesOn(topo) {
    try {
      const cfg = JSON.parse(fs.readFileSync(path.join(topo, '.claude', 'cogniva-dev.local.json'), 'utf8'));
      return !!cfg && cfg.worktrees === true;
    } catch (e) { return false; }
  }
  ```

- [ ] **Step 2 (replace the marker test):** replace the directory-presence test
      in each script:
      - `guard-primary-edit.js`: `if (!fs.existsSync(path.join(topo, '.claude', 'cogniva-dev'))) return allow();`
        → `if (!worktreesOn(topo)) return allow();`
      - `guard-primary-git.js` (line ~56): same replacement, `return allow();`.
      - `nudge-backlog-commit.js` (line ~71): same test → `if (!worktreesOn(topo)) return quiet();`
- [ ] **Step 3 (header comments):** update each script's header comment: the
      opt-in is now "worktree mode on in this clone
      (`.claude/cogniva-dev.local.json` `worktrees: true`)" instead of "the repo
      opted in (`.claude/cogniva-dev/` marker)".
- [ ] **Step 4 (syntax check):** `node --check plugins/cogniva-dev/scripts/guard-primary-edit.js && node --check plugins/cogniva-dev/scripts/guard-primary-git.js && node --check plugins/cogniva-dev/scripts/nudge-backlog-commit.js` → no output, exit 0.
- [ ] **Step 5 (commit):** `git add plugins/cogniva-dev/scripts/guard-primary-edit.js plugins/cogniva-dev/scripts/guard-primary-git.js plugins/cogniva-dev/scripts/nudge-backlog-commit.js` then
      `git commit -m "feat(cogniva-dev): guard hooks read the per-clone worktrees switch"`
