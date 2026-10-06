# 07 DocsAndPlanFeature — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/ArchitectureProfilesStage2a
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** Document the Stage 2a contract for people and agents, give Stage 2b
a migration guide for Module-bundle repos, and teach plan-feature to read
composed standards and review items.

**Architecture:** Docs under `plugins/cogniva-dev/docs/`, a one-paragraph
change to `plugins/cogniva-dev/skills/plan-feature/SKILL.md` pinned in
`tests/skill-semantics`, and a status update to the proposal. Everything
described here was built by Sub-plans 01-06; read their scripts rather than
this plan for exact behaviour.

**Read these first:** `plugins/cogniva-dev/docs/architecture-profiles.md`,
`plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1`,
`plugins/cogniva-dev/scripts/adopt-architecture-profile.ps1`,
`plugins/cogniva-dev/scripts/accept-profile-delta.ps1`,
`plugins/cogniva-dev/skills/plan-feature/SKILL.md`,
`plugins/cogniva-dev/tests/architecture-profile/fixtures/stage1/dotnet/standards/dotnet/`,
`docs/glossary/README.md` (Amendment, Replacement standard, Library profile,
Repo-owned profile, Module bundle layout).

**Constraints restated:** Use the glossary terms exactly (never "managed
profile", "child profile" as a name, or "legacy Module layout"). No real
repository names under `plugins/` (the profile-library suite's leak check
enforces it). `applies-to` examples are block lists of quoted globs.

## File structure (locked)

```
plugins/cogniva-dev/docs/architecture-profiles.md          # rewritten for the Stage 2a contract
plugins/cogniva-dev/docs/module-bundle-migration.md        # NEW: moving a Module-bundle repo onto dotnet
plugins/cogniva-dev/skills/plan-feature/SKILL.md           # read composed standards; ask on review items
plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1  # pin it
docs/plans/FeatureLifecycle/ArchitectureProfiles/Stage2a-proposal.md # status header
```

## Task 1: `architecture-profiles.md` and the migration guide

**Files:**
- Modify: `plugins/cogniva-dev/docs/architecture-profiles.md`
- Create: `plugins/cogniva-dev/docs/module-bundle-migration.md`

- [x] **Step 1 (architecture-profiles.md):** Rewrite the file. Keep the existing sections "How a path's profile is chosen" and "The YAML subset" (adding that `applies-to` is a block list), and make the rest cover, in this order:
  1. **Intro:** library profiles (shipped in the plugin's `profiles/`: `cogniva-base`, technology-neutral; `dotnet`, Cogniva's shared .NET principles plus default conventions for new repos) and repo-owned profiles (a repo's own layout and exceptions). One sentence on the hierarchy `cogniva-base -> dotnet -> <repo-owned>`.
  2. **Use a profile in a repo:** adopt (`-Profile dotnet`), declare (`.cogniva-profile.yml`), commit. Adoption records at `.cogniva/adopted/<id>.yml` (source, plugin version, content hash). Refresh with `-Refresh` or by re-running `-Profile`; the outcome table (`ADOPTED`, `UP-TO-DATE`, `REFRESHED`, `LOCALLY-EDITED`, `DIFFERS`, `REPLACED` with `-Force`), and that a locally edited library copy belongs in a repo-owned profile instead. Stage 1 adoptions without a record refresh cleanly. After a refresh adopt prints `REVIEW:` lines for repo-owned deltas that went stale. Repo-owned profiles are never written by adopt.
  3. **Reading the standards:** the index (descriptions first), `AMENDED BY` / `REPLACED - no longer receives <parent> updates` / `APPLIES TO` lines, `NEEDS HUMAN REVIEW`, and `-Show <id>` printing the composed text with a provenance line per part. JSON fields: `ChainDetail` (`Id`, `Ownership`), per standard `ReplacedBy`, `Amendments[]` (`From`, `Ownership`, `Path`, `Description`, `State`), `AppliesTo`, `NeedsReview`; per profile `Review[]`; per target `NeedsReview`, `MatchedStandards`.
  4. **Writing a profile:** the folder layout (`profile.yml`, `standards/`, `amendments/`, `replacements/`); `standards/` takes new ids only (a same-id file is an ERROR); amendments stack root first, replacement standards supersede the inherited text and every ancestor amendment and are rare; one profile may not amend and replace one id; frontmatter keys `description` (required everywhere), `basis` (deltas only), `applies-to` (block list of quoted globs, `*` within a segment, `**` across segments, most-derived declaration wins); "Standards are declarative guidance. Workflow steps belong in skills." (kept).
  5. **Review state:** what `basis` hashes (the normalised inherited text: base or nearest replacement plus ancestor amendments, in chain order) and the normalisation rules (BOM, line endings, trailing whitespace, trailing blank lines, every `basis:` line dropped); the four states (`CURRENT`, `STALE`, `UNREVIEWED`, `ORPHANED`), which all still resolve; `accept-profile-delta.ps1 -Repo . -Profile <repo-owned> (-Standard <id> | -All)` after a human review, which rewrites only `basis:` lines and refuses library profiles; `-Library` for plugin maintainers. "`basis` detects that a parent changed, not that it now contradicts something."
  6. **Resolution vs permission to change:** resolution never stops on review state; a skill that makes an architecture-dependent change passes its dependency set to `-Require` and stops on exit 3; review items on other standards never block it. Exit codes: 0, 1 (an ERROR target), 2 (usage), 3 (a required standard is missing or needs review).
  7. **Where profiles are used:** plan-feature (designs under it, asks before designing on standards that need review), applicable-rules (placement messages from `MatchedStandards`; `REVIEW_REQUIRED` only for matched standards, `REVIEW:` notes otherwise), repo-init (adopts and declares `dotnet`), add-module (gates with `-Require` in a declared Module-bundle repo). Keep the PowerShell 7 note.
  8. A pointer to `module-bundle-migration.md` for repos on the Module bundle layout.
- [x] **Step 2 (migration guide):** Create `plugins/cogniva-dev/docs/module-bundle-migration.md`, titled `# Moving a Module bundle layout repo onto dotnet`, with:
  1. Who it is for: a repo laid out as `src/Modules/<Name>/` (the Module bundle layout `add-module` scaffolds) that wants the `dotnet` library profile plus its own rules.
  2. Numbered steps: adopt `dotnet`; create a repo-owned profile `.cogniva/profiles/<id>/profile.yml` with `inherits: dotnet`; `amendments/dotnet/project-layout.md` declaring the Modules kind (and regions, if the repo has them); new standards under `standards/<id>/` for the Module bundle, its per-layer edges, and the Module UI rule (starting from the retired text below); `amendments/architecture/common-and-published-types.md` with
     ```yaml
     applies-to:
       - "src/Modules/*/*.Contracts"
       - "src/Modules/*/*.Contracts/**"
     ```
     so applicable-rules warns on implementation in Contracts projects; `amendments/architecture/architecture-exceptions.md` naming any allowed cycles (and pointing at `docs/architecture/allowed-cycles.txt` for `module-deps`); review, then `accept-profile-delta.ps1 -Repo . -Profile <id> -All`; root marker `profile: <id>` plus `profile: none` markers for non-.NET trees; replace any rule lines in `AGENTS.md` with a pointer to the profile; optionally `"moduleDepsCheck": true` in `.claude/cogniva-dev/policy.json`.
  3. `## Retired Stage 1 standards (starting text)`, with `### dotnet/module-layout.md` and `### dotnet/module-dependencies.md`, each followed by that file's body copied verbatim (everything after its frontmatter) from `plugins/cogniva-dev/tests/architecture-profile/fixtures/stage1/dotnet/standards/dotnet/`.
- [x] **Step 3 (check):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` → `All profile-library assertions passed.` (leak and wording checks cover the new docs); `grep -n -i "managed profile\|child profile\|same path replaces" plugins/cogniva-dev/docs/architecture-profiles.md` → no output.
- [x] **Step 4 (commit):** `git add plugins/cogniva-dev/docs/architecture-profiles.md plugins/cogniva-dev/docs/module-bundle-migration.md` then `git commit -m "docs(profiles): Stage 2a contract and the Module bundle migration guide"`

## Task 2: plan-feature reads composed standards and asks on review items

**Files:**
- Modify: `plugins/cogniva-dev/skills/plan-feature/SKILL.md`
- Test: `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`

- [x] **Step 1 (failing pin):** Under `# --- architecture profiles` in `skill-semantics.tests.ps1`, add:
  ```powershell
  Check 'plan-feature reads composed standards with -Show' `
      ($pfFlat -match 'AMENDED BY' -and $pfFlat -match '-Show <id>')
  Check 'plan-feature asks before designing on standards that need review' `
      ($pfFlat -match 'NEEDS HUMAN REVIEW' -and $pfFlat -match 'ask before designing on those standards')
  ```
- [x] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → FAIL on the two new pins.
- [x] **Step 3 (implement):** In `plugins/cogniva-dev/skills/plan-feature/SKILL.md`, in the **Architecture profile.** paragraph, directly after the sentence ending "open only the standards that bear on this design, and honour them like existing ADRs: surface a departure, never work around it.", add: "A standard listed with `AMENDED BY` lines (or `REPLACED`) is composed from several files: read each one, or print the composed text with `-Show <id>`. If a target prints `NEEDS HUMAN REVIEW`, list its `REVIEW:` items for the user and ask before designing on those standards; it is a question, not a stop."
- [x] **Step 4 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`
- [x] **Step 5 (commit):** `git add plugins/cogniva-dev/skills/plan-feature/SKILL.md plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` then `git commit -m "feat(plan-feature): read composed standards; ask before designing on review items"`

## Task 3: Proposal status and the full gate

**Files:**
- Modify: `docs/plans/FeatureLifecycle/ArchitectureProfiles/Stage2a-proposal.md`

- [ ] **Step 1:** Replace the proposal's opening status blockquote (every `>` line from `> Status:` down to the blank line before `**Stage 2a goal:**`) with:
  ```markdown
  > Status: **Stage 2a is implemented.** 2a.0 (`module-deps`) by PR #15, from
  > `docs/plans/FeatureLifecycle/ModuleDepsLegacyTool/`; the rest from the plan in
  > `docs/plans/FeatureLifecycle/ArchitectureProfilesStage2a/`, which records
  > where it departs from this text (naming: Library profile, Repo-owned profile,
  > Module bundle layout, Common types; `.cogniva/adopted/` records; no `Kind`
  > field; block-list `applies-to`; an automated repo-init check). This document
  > is kept as the design record; the plan and the shipped docs win where they differ.
  ```
- [ ] **Step 2 (full gate):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → every command in `.claude/cogniva-dev/green-gate.json` exits 0 (including `claude plugin validate .`, manifest parity, `architecture-profile` and `profile-library`). A failing command is a defect to fix before finishing.
- [ ] **Step 3 (commit):** `git add docs/plans/FeatureLifecycle/ArchitectureProfiles/Stage2a-proposal.md` then `git commit -m "docs(plans): mark Stage 2a implemented"`
