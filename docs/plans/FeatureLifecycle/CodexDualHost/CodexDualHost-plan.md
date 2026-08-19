# CodexDualHost — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/CodexDualHost
> Tasks contain NO git worktree/branch step — execute-feature creates the worktree
> and the tasks commit on the feature branch they are already on. Never run
> git switch/checkout/branch inside a task.

**Goal:** Make cogniva-dev dual-host — natively installable and executable under OpenAI Codex (lean mode, no worktrees, no commits by default, `READY FOR REVIEW` finish) while Claude worktree mode stays unchanged.

**Architecture:** One `skills/` tree, two manifests (`.claude-plugin/` + new `.codex-plugin/`). The Codex executor backend is an instruction overlay (`CODEX.md` beside `execute-feature/SKILL.md`, per the ADR 0028 overlay pattern), selected when the Workflow tool is unavailable — never an emulation of Claude's Workflow JS API. New invocation flags `commits=none|task|final` and `plan=ephemeral|persisted` with lean defaults `none`/`ephemeral`; worktree mode keeps mandatory per-task commits and persisted plans. Lean runs finish with a detailed `READY FOR REVIEW` handoff (new shared `HANDOFF.md`); `git diff --check` joins the landing order before the green gate. Optional per-repo branch policy in tracked `.claude/cogniva-dev/policy.json`.

**Read these first:** `docs/adr/0026-per-clone-worktree-switch.md`, `docs/adr/0028-worktree-overlay-pattern.md`, `plugins/cogniva-dev/skills/execute-feature/SKILL.md` + `WORKTREE.md` + `WORKFLOW-NOTES.md`, `plugins/cogniva-dev/skills/quick-fix/SKILL.md`, `plugins/cogniva-dev/templates/execute-feature.workflow.js`, `plugins/cogniva-dev/scripts/worktree-mode.js`. External agreement record: `C:\Users\j.barton\Downloads\cogniva-dev_codex_workflow_issues_for_jeff.md`, `answers_to_jeffs_questions.md`, `cogniva-dev_maintainer_response_to_codex_brief.md` (do not read during execution; context only).

## File structure (locked)

```
plugins/cogniva-dev/.codex-plugin/plugin.json                 # NEW — Codex manifest over the same skills/ tree
plugins/cogniva-dev/docs/codex.md                             # NEW — dual-host doc: packaging, install, backend, lean policy
plugins/cogniva-dev/skills/execute-feature/CODEX.md           # NEW — Codex backend overlay (sequential subagent loop)
plugins/cogniva-dev/skills/execute-feature/HANDOFF.md         # NEW — READY FOR REVIEW handoff format (shared)
plugins/cogniva-dev/skills/execute-feature/SKILL.md           # MOD — host dispatch, commits=/plan= flags, lean defaults, diff --check, lean Done → handoff
plugins/cogniva-dev/skills/execute-feature/WORKFLOW-NOTES.md  # MOD — dual-backend scope note; workflow.js syntax-check hint
plugins/cogniva-dev/templates/execute-feature.workflow.js     # MOD — args.commits; task prompts skip staging/commit under none/final
plugins/cogniva-dev/skills/quick-fix/SKILL.md                 # MOD — same flags/defaults, lean finish → handoff, diff --check
plugins/cogniva-dev/skills/workflow-status/SKILL.md           # MOD — one line: under Codex report "Claude Workflow runs only"
plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md  # MOD — document optional policy.json
plugins/cogniva-dev/templates/repo/.claude/settings.json      # MOD — drop unconditional git switch/checkout denies (lean is default)
plugins/cogniva-dev/skills/repo-init/SKILL.md                 # MOD — mention optional policy.json
plugins/cogniva-dev/.claude-plugin/plugin.json                # MOD — bump 0.6.1 → 0.7.0
.claude-plugin/marketplace.json                               # MOD — bump cogniva-dev entry to 0.7.0
CLAUDE.md                                                     # MOD — version-bump rule: THREE files now
```

## Candidate ADRs

### ADR-C1: Dual-host packaging — one skills tree, two manifests; Codex backend is an instruction overlay
**Provenance:** Suggested by human
`plugins/cogniva-dev/` ships `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` over the same `skills/` tree; skill content is never duplicated per host. The Codex executor is a `CODEX.md` overlay beside `execute-feature/SKILL.md` (extending the ADR 0028 overlay pattern), selected when the Workflow tool is unavailable; Claude's Workflow JS API is never emulated under Codex.
**Write with:** Task 2

### ADR-C2: Lean execution policy — commits=none + plan=ephemeral defaults, READY FOR REVIEW finish
**Provenance:** Suggested by human
Lean-mode runs default to `commits=none` and `plan=ephemeral` (plan in gitignored `.plans-staging/`, ignored via `.git/info/exclude`, checkbox resume preserved) and end with the detailed `READY FOR REVIEW` handoff — no integration, no push. `commits=none|final` are rejected loudly in worktree mode because integration is a fast-forward of commits; worktree mode keeps per-task commits and persisted plans unchanged.
**Write with:** Task 3

### ADR-C3: Repo branch policy — requiredDevelopmentBranchPrefix in tracked policy.json
**Provenance:** Suggested by human
An optional tracked `.claude/cogniva-dev/policy.json` may set `{"requiredDevelopmentBranchPrefix": "feature/"}`. Lean lifecycle skills validate the current branch against it BEFORE mutating anything and stop with a clear message on mismatch — they never auto-create or switch branches. Absent/unreadable file = no policy, no behavior change.
**Write with:** Task 6

## Task 1: Codex plugin manifest + dual-host doc

**Files:**
- Create: `plugins/cogniva-dev/.codex-plugin/plugin.json`
- Create: `plugins/cogniva-dev/docs/codex.md`

- [ ] **Step 1 (manifest):** Read `plugins/cogniva-dev/.claude-plugin/plugin.json` (identity fields + current version). Create `plugins/cogniva-dev/.codex-plugin/plugin.json` with EXACTLY the same `name`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords` values, plus one additional field: `"skills": "./skills/"`. (Minimal Codex manifest per OpenAI plugin docs: identity + a skills pointer; paths are plugin-root-relative, so `./skills/` resolves to the same tree `.claude-plugin` uses.)
- [ ] **Step 2 (doc):** Create `plugins/cogniva-dev/docs/codex.md` with these sections, written out fully: **Packaging** (one skills/ tree, two manifests; never duplicate skill content; the version lives in THREE files — both plugin manifests and the marketplace entry — and must match); **Install under Codex** (install the plugin from a configured marketplace via Codex CLI `/plugins`, then start a NEW session before the skills appear; local skill authoring/testing can instead use Codex's `.agents/skills` discovery, but the plugin is the distribution mechanism); **Backend selection** (Claude: background Workflow runtime, see `WORKFLOW-NOTES.md`; Codex: the Workflow tool is unavailable, so `execute-feature`/`quick-fix` follow their `CODEX.md` overlay — sequential fresh subagents, textual DONE/BLOCKED result contract, no Workflow-API emulation); **Lean policy** (lean defaults `commits=none` + `plan=ephemeral`, `READY FOR REVIEW` finish, no integration, no push; worktree mode is Claude-only and unchanged); **Resume under Codex** (persisted plans: checkbox-based cross-session resume; ephemeral plans: checkbox resume via the `.plans-staging/` scratch copy, which survives sessions on the same clone but is not tracked).
- [ ] **Step 3 (verify):** `claude plugin validate .` from the repo root → `Validation passed` (confirms the extra directory breaks nothing on the Claude side). `powershell -NoProfile -Command "Get-Content plugins/cogniva-dev/.codex-plugin/plugin.json | ConvertFrom-Json | Select-Object name, version, skills"` → prints `cogniva-dev`, the current version, `./skills/`.
- [ ] **Step 4 (commit):** `git add plugins/cogniva-dev/.codex-plugin/plugin.json plugins/cogniva-dev/docs/codex.md` then `git commit -m "feat(cogniva-dev): native Codex plugin manifest + dual-host doc"`

## Task 2: Codex backend overlay for execute-feature

**Files:**
- Create: `plugins/cogniva-dev/skills/execute-feature/CODEX.md`
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/execute-feature/WORKFLOW-NOTES.md`

- [ ] **Step 1 (host dispatch in SKILL.md):** In `plugins/cogniva-dev/skills/execute-feature/SKILL.md`, directly below the existing "**Worktree dispatch (check first):**" paragraph, add a parallel paragraph: `**Host dispatch (check second):** if the Workflow tool is not available in this session (Codex or any non-Claude host), read CODEX.md beside this file NOW — it replaces Step 3 (the Workflow dispatch). Worktree mode requires the Claude Workflow runtime; under any other host only lean mode is supported — if worktree mode is ON and the Workflow tool is absent, STOP and say so.`
- [ ] **Step 2 (CODEX.md):** Create `plugins/cogniva-dev/skills/execute-feature/CODEX.md` — the Codex backend overlay, replacing SKILL.md Step 3 only (Steps 0–2 and 4 apply unchanged). Write it in the same terse second-person style as `WORKTREE.md`, with this exact contract:
      - **Replaces Step 3 — sequential subagent loop.** For each not-`done` task in order: spawn ONE fresh subagent whose prompt carries the task's full `body` verbatim plus this frame: work only in WORKSPACE on BRANCH; never switch branches; never push; follow the commit policy passed to you (see flags in SKILL.md); when done, reply with a first line of exactly `DONE` or `BLOCKED`, then `summary:` (1–2 lines, what changed), then `commitSha:` (only if a commit was made), then `note:` (only if BLOCKED — exactly what is missing), then `followups:` (only if genuinely surfaced — one line each, with a concrete receipt). Wait for the subagent to finish before anything else.
      - **After each task:** parse the first line. `DONE` → tick that task's checkboxes in `planPath` (the executor ticks; task agents under Codex do not edit the plan), record the result, dispatch the next task. `BLOCKED` → stop the loop, report which task and the note. Task `isGate` (`⛔`) and `DONE` → stop the loop after it, report the gate.
      - **Sequencing rules:** strictly sequential, one subagent per task, later tasks see earlier tasks' changes in the same WORKSPACE, no reviewer fan-out, no parallelism.
      - **After the loop:** continue at SKILL.md Step 4 exactly as written (the lean path).
      - **Resume:** re-running the skill re-parses the plan; fully-ticked tasks come back `done` and are skipped — identical to the Claude backend.
      - **Never** attempt to install, emulate, or hand-roll the Workflow JS API; this loop IS the Codex backend.
- [ ] **Step 3 (WORFKLOW-NOTES scope + syntax-check hint):** In `plugins/cogniva-dev/skills/execute-feature/WORKFLOW-NOTES.md`: (a) extend the `> **Scope**` blockquote with one sentence: this file describes the CLAUDE backend; under Codex the Workflow runtime does not exist and `CODEX.md` defines the executor loop instead. (b) Add one hint line to the "Why a Workflow" section or a small new paragraph: `*.workflow.js` files cannot be syntax-checked with `node --check` (the DSL body has top-level return/await); verify instead with an AsyncFunction compile, e.g. `node -e "new (Object.getPrototypeOf(async function(){}).constructor)(require('fs').readFileSync(process.argv[1],'utf8'))" <file>`.
- [ ] **Step 4 (write ADR):** scan `docs/adr/` for the next number and write confirmed candidate ADR-C1 verbatim to `docs/adr/NNNN-dual-host-packaging-and-codex-overlay.md` per the adr skill's ADR-FORMAT.
- [ ] **Step 5 (verify):** `claude plugin validate .` → passes. Grep `plugins/cogniva-dev/skills/execute-feature/SKILL.md` for `Host dispatch` → 1 hit; grep `CODEX.md` for `Workflow` → every mention is about its absence/non-emulation.
- [ ] **Step 6 (commit):** `git add plugins/cogniva-dev/skills/execute-feature/ docs/adr/` then `git commit -m "feat(execute-feature): Codex backend overlay (CODEX.md) + host dispatch"`

## Task 3: commits= and plan= flags with lean defaults

**Files:**
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/execute-feature/CODEX.md`
- Modify: `plugins/cogniva-dev/templates/execute-feature.workflow.js`

- [ ] **Step 1 (flags section in SKILL.md):** In `plugins/cogniva-dev/skills/execute-feature/SKILL.md`, after the invocation examples, add a `## Flags` section defining, exactly:
      - `commits=none|task|final` — `none`: never stage or commit; the final handoff reports the uncommitted diff. `task`: one checkpoint commit per task; **tick the task's plan checkboxes BEFORE the task commit so the commit SHA represents the completed task state**; checkpoint commits never imply approval. `final`: leave work uncommitted until all tasks and gates pass, then one implementation commit. Any git failure under `task`/`final` → the task stops `BLOCKED` with the git error as the note; no retry loops, no special-casing of specific git errors.
      - `plan=ephemeral|persisted` — `persisted`: current behavior (plan lives under `docs/plans/...`, committed). `ephemeral`: Step 0a writes the pasted plan (and Step 1 any converted `.tasks.md`) under `.plans-staging/<Module>/<Feature>/` instead of `docs/plans/`, NEVER commits it, and first ensures `.plans-staging/` is ignored by appending it to `.git/info/exclude` if absent (untracked, so the repo is never dirtied). Checkbox tracking and resume work identically against the scratch copy; it survives sessions on the same clone but is not tracked — say so in the run's first status line.
      - **Defaults:** lean mode → `commits=none`, `plan=ephemeral`. Worktree mode → `commits=task`, `plan=persisted`, and `commits=none|final` are INVALID there — integration is a fast-forward of commits; reject the combination with one clear line and stop, never silently ignore it.
- [ ] **Step 2 (thread flags through the steps):** Update SKILL.md Steps 0a, 1, and 4 wording so every unconditional "commit" instruction is qualified by the commit policy (e.g. Step 0a "Commit it" → "Commit it (persisted plans only — an ephemeral plan is never committed)"; Step 1 the converted-file commit likewise; Step 4.1 "commit leftovers" applies only under `commits=task|final`, and under `final` this is where the single implementation commit happens; under `none` Step 4.1 instead records `git status --porcelain` + `git diff --stat` for the handoff). Update CODEX.md's task-agent frame to state the active commit policy verbatim in each subagent prompt.
- [ ] **Step 3 (workflow.js):** In `plugins/cogniva-dev/templates/execute-feature.workflow.js`: accept `args.commits` (default `'task'` for backward compatibility). Where each task-agent prompt is assembled, when `commits === 'none'` or `'final'`, replace the staging/commit instruction with: do NOT stage or commit anything; leave changes in the working tree. When `commits === 'task'`, instruct: tick this task's checkboxes in `planPath` FIRST, then stage only your own files and commit. Keep the result schema unchanged (`commitSha` is already optional).
- [ ] **Step 4 (write ADR):** scan `docs/adr/` for the next number and write confirmed candidate ADR-C2 verbatim to `docs/adr/NNNN-lean-execution-policy.md` per the adr skill's ADR-FORMAT.
- [ ] **Step 5 (verify):** syntax-check the template with the AsyncFunction compile one-liner from WORKFLOW-NOTES.md → exits 0. Grep SKILL.md: `commits=none` appears with the worktree rejection sentence; `\.plans-staging` appears with `info/exclude`.
- [ ] **Step 6 (commit):** `git add plugins/cogniva-dev/skills/execute-feature/ plugins/cogniva-dev/templates/execute-feature.workflow.js docs/adr/` then `git commit -m "feat(execute-feature): commits=/plan= flags, lean defaults none+ephemeral"`

## Task 4: READY FOR REVIEW handoff + git diff --check in the landing order

**Files:**
- Create: `plugins/cogniva-dev/skills/execute-feature/HANDOFF.md`
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/execute-feature/CODEX.md`

- [ ] **Step 1 (HANDOFF.md):** Create `plugins/cogniva-dev/skills/execute-feature/HANDOFF.md` defining the lean-mode finish. Header block, exactly:
      ```
      READY FOR REVIEW
      Branch: <current branch>
      Integration: not performed
      Remote push: not performed
      ```
      Then required sections, each 1–5 lines, omitting none (write "none" rather than dropping a section): **Summary** (feature/tasks in 2–4 sentences); **Files changed** (path + one line what changed); **Files read** (only where non-obvious why); **Behavioral / workflow changes**; **Deviations & surprises** (vs the plan); **Checks run** (exact commands + outcomes); **Skipped validations** (+ why); **`git diff --check`** (result); **Final tree status** (`git status --porcelain` summary; under `commits=none` also `git diff --stat`); **Pre-existing/unrelated changes** (anything dirty before the run); **Risks / limitations / assumptions**; **Follow-ups** (surfaced, not done — with receipts); **Commits** (SHAs, only under `commits=task|final`). Close with one line of semantics: READY FOR REVIEW means implementation complete on this branch — NOT approved, NOT integrated, NOT ready to push.
- [ ] **Step 2 (landing order in SKILL.md Step 4):** Insert a new step between the ADR check and the green gate: **`git diff --check`** — run it; whitespace/conflict-marker errors → fix (respecting the commit policy), re-run until clean; record the result for the handoff. Renumber/adjust surrounding text so the lean order reads: tree/workspace consistency → ride-alongs → before-integrate obligations → ADR check → `git diff --check` → green gate → **handoff**. Replace the lean "Done" step ("report what landed in 2–4 sentences") with: emit the full handoff per `HANDOFF.md` as the final text of the turn. Worktree mode keeps its integration landing (WORKTREE.md) — `git diff --check` applies there too, same position.
- [ ] **Step 3 (CODEX.md):** Reference the same finish: after the loop and Step 4 gates, emit the handoff per `HANDOFF.md`.
- [ ] **Step 4 (verify):** `claude plugin validate .` → passes. Grep SKILL.md for `diff --check` → present between ADR check and green gate; grep for `HANDOFF.md` → referenced in the lean Done step.
- [ ] **Step 5 (commit):** `git add plugins/cogniva-dev/skills/execute-feature/` then `git commit -m "feat(execute-feature): READY FOR REVIEW handoff + git diff --check gate"`

## Task 5: quick-fix parity (flags, lean finish, diff --check)

**Files:**
- Modify: `plugins/cogniva-dev/skills/quick-fix/SKILL.md`

- [ ] **Step 1 (host dispatch + flags):** In `plugins/cogniva-dev/skills/quick-fix/SKILL.md`, below the worktree-dispatch paragraph, add the same host-dispatch paragraph as execute-feature (Workflow tool absent → follow `../execute-feature/CODEX.md`'s loop with the synthesized task list; worktree mode unsupported without the Workflow runtime). Add a one-paragraph flags note: quick-fix honors `commits=` with the same semantics and the same defaults (lean → `none`, worktree → `task`; `none|final` invalid in worktree mode); quick-fix is planless so `plan=` does not apply.
- [ ] **Step 2 (lean finish):** In Step 2 ("land it"): insert `git diff --check` between the ADR check and the green gate; change the lean-mode ending from "report the fix in 1–2 sentences" to: emit the handoff per `../execute-feature/HANDOFF.md` (a short fix yields a short handoff — sections still all present). Worktree-mode ending (integrate) unchanged.
- [ ] **Step 3 (verify):** `claude plugin validate .` → passes. Grep quick-fix SKILL.md: `HANDOFF.md`, `diff --check`, `commits=` each present exactly once in the right step.
- [ ] **Step 4 (commit):** `git add plugins/cogniva-dev/skills/quick-fix/SKILL.md` then `git commit -m "feat(quick-fix): lean commits=none default, diff --check, READY FOR REVIEW finish"`

## Task 6: branch policy (policy.json) + template guard cleanup

**Files:**
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/quick-fix/SKILL.md`
- Modify: `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md`
- Modify: `plugins/cogniva-dev/templates/repo/.claude/settings.json`
- Modify: `plugins/cogniva-dev/skills/repo-init/SKILL.md`

- [ ] **Step 1 (policy check in both skills):** In execute-feature SKILL.md Step 0b and quick-fix SKILL.md Step 0, add (lean mode only): read `.claude/cogniva-dev/policy.json`; if it exists and has `requiredDevelopmentBranchPrefix`, verify `BRANCH` starts with that prefix BEFORE any mutation. Mismatch → stop with one clear line naming the branch and the required prefix; NEVER create or switch a branch to satisfy the policy. Absent/unreadable file → no policy. (Worktree mode needs no check — its generated branches are `feature/<slug>` by construction.)
- [ ] **Step 2 (template README):** In `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md`, add a `## Branch policy — policy.json` section documenting the optional file with the exact example `{"requiredDevelopmentBranchPrefix": "feature/"}` and its semantics (lean-only validation, stop-never-switch, absent = no policy).
- [ ] **Step 3 (template settings.json):** In `plugins/cogniva-dev/templates/repo/.claude/settings.json`, remove the unconditional `Bash(git switch)` / `Bash(git checkout)` deny entries — lean mode is the default and those denies block legitimate lean work; branch protection in worktree mode is enforced by the mode-aware `guard-primary-git` hook (verify that hook is registered in the same settings.json before removing; if it is not, add it per the plugin's hook registration used by `repo-init`, then remove the denies). Note the rationale in one line in the template README's worktree section.
- [ ] **Step 4 (repo-init):** In `plugins/cogniva-dev/skills/repo-init/SKILL.md`, at the step that copies the template `.claude/` folder, add one sentence: an optional `.claude/cogniva-dev/policy.json` can enforce a development-branch prefix in lean mode (see the template README).
- [ ] **Step 5 (write ADR):** scan `docs/adr/` for the next number and write confirmed candidate ADR-C3 verbatim to `docs/adr/NNNN-repo-branch-policy.md` per the adr skill's ADR-FORMAT.
- [ ] **Step 6 (verify):** `claude plugin validate .` → passes. `powershell -NoProfile -Command "Get-Content plugins/cogniva-dev/templates/repo/.claude/settings.json | ConvertFrom-Json | Out-Null; 'json ok'"` → `json ok`. Grep templates/repo/.claude/settings.json for `git switch` → no hits.
- [ ] **Step 7 (commit):** `git add plugins/cogniva-dev/skills/ plugins/cogniva-dev/templates/repo/.claude/ docs/adr/` then `git commit -m "feat(cogniva-dev): lean branch policy (policy.json); drop unconditional switch denies from template"`

## Task 7: workflow-status Codex note, version 0.7.0, three-file bump rule

**Files:**
- Modify: `plugins/cogniva-dev/skills/workflow-status/SKILL.md`
- Modify: `plugins/cogniva-dev/.claude-plugin/plugin.json`
- Modify: `plugins/cogniva-dev/.codex-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `CLAUDE.md`

- [ ] **Step 1 (workflow-status):** In `plugins/cogniva-dev/skills/workflow-status/SKILL.md`, add one scoping line near the top: this skill reads Claude Workflow journals only; under Codex (no Workflow runtime) say plainly "Claude Workflow runs only — Codex runs are not tracked here" instead of implying full coverage.
- [ ] **Step 2 (bump three files):** Set `"version": "0.7.0"` in `plugins/cogniva-dev/.claude-plugin/plugin.json`, `plugins/cogniva-dev/.codex-plugin/plugin.json`, and the cogniva-dev entry of `.claude-plugin/marketplace.json` (do NOT touch the cogniva-skills entry).
- [ ] **Step 3 (CLAUDE.md rule):** In the repo root `CLAUDE.md` `## Rules` section, update "**A bump is TWO files, always.**" to THREE files, adding `plugins/<plugin>/.codex-plugin/plugin.json` (where the plugin ships one) to the list and to the confirmation grep:
      `grep -n '"version"' plugins/<plugin>/.claude-plugin/plugin.json plugins/<plugin>/.codex-plugin/plugin.json .claude-plugin/marketplace.json`
- [ ] **Step 4 (verify):** `grep -n '"version"' plugins/cogniva-dev/.claude-plugin/plugin.json plugins/cogniva-dev/.codex-plugin/plugin.json .claude-plugin/marketplace.json` → all cogniva-dev values read `0.7.0`. `claude plugin validate .` → passes.
- [ ] **Step 5 (commit):** `git add plugins/cogniva-dev/skills/workflow-status/SKILL.md plugins/cogniva-dev/.claude-plugin/plugin.json plugins/cogniva-dev/.codex-plugin/plugin.json .claude-plugin/marketplace.json CLAUDE.md` then `git commit -m "chore(cogniva-dev): 0.7.0 — dual-host Codex support; bump rule is three files"`
