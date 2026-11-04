# 04 InvocationPolicy — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/CrossHostParity
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** Lifecycle entry skills that no other skill routes into start only when
the user names them, on both agent hosts; the skills other skills route into
say when they may start; and the text shared skills show the user is correct on
both Claude Code and Codex. Ends with the Stage 1 review gate (PR 1).

**Architecture:** Invocation policy is metadata, always as a pair:
`disable-model-invocation: true` in `SKILL.md` frontmatter (Claude Code) and
`agents/openai.yaml` with `policy: allow_implicit_invocation: false` (Codex),
applied only to skills no other skill dispatches or offers to run.
`scripts/check-host-parity.ps1` (rule `invocation-metadata`) already fails when
only one of the pair is present; `skill-semantics` pins which skills carry it.
Routed skills (quick-fix, plan-feature) keep model invocation and state their
explicit-start rule in their description, so an approved dispatch from
easy-work-scan or groom-backlog still works on both agent hosts. User-facing
wording drops Claude Code-only tool names, and the agent-host token ratchet
(`scripts/check-host-neutrality.ps1`) is lowered to lock that in.

**Read these first:** `docs/plans/FeatureLifecycle/CrossHostParity/CrossHostParity-plan.md`
(manifest; Stage 1 acceptance), `docs/host-parity.md` (the parity record),
`plugins/cogniva-dev/docs/codex.md`,
`plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`,
`scripts/check-host-parity.ps1`, `scripts/check-host-neutrality.ps1`,
`AGENTS.md` (`## Rules`: the three-file version bump).

Terminology in every text you write: "agent host" means Claude Code or Codex;
never write the bare word "host" for them (the glossary term **Host** means a
.NET runnable project). `skill-semantics.tests.ps1` runs under Windows
PowerShell 5.1 and is read as ANSI without a BOM: every assertion you add stays
ASCII-only and 5.1-compatible.

## File structure (locked)

```
plugins/cogniva-dev/skills/{execute-feature,explore-idea,cleanup-work,cleanup-allwork,repo-init,add-module}/SKILL.md   # + disable-model-invocation: true
plugins/cogniva-dev/skills/{execute-feature,explore-idea,cleanup-work,cleanup-allwork,repo-init,add-module}/agents/openai.yaml   # new: allow_implicit_invocation: false
plugins/cogniva-dev/skills/quick-fix/SKILL.md          # description: explicit-start clause
plugins/cogniva-dev/skills/plan-feature/SKILL.md       # description clause; agent-host-neutral question + execute-feature wording
plugins/cogniva-dev/skills/explore-idea/SKILL.md       # agent-host-neutral question + subagent wording
plugins/cogniva-dev/skills/groom-backlog/SKILL.md      # scan subagent named for both agent hosts
plugins/cogniva-dev/skills/easy-work-scan/SKILL.md     # scan subagent named for both agent hosts
plugins/cogniva-dev/skills/execute-feature/HANDOFF.md  # skill invocations in the current agent host's syntax
plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md   # BACKLOG.md header names skills, not commands
docs/plans/BACKLOG.md, docs/plans/FeatureLifecycle/BACKLOG.md   # existing headers updated to the same wording
plugins/cogniva-skills/skills/glossary/SKILL.md        # description + question wording without Claude Code tool names
plugins/cogniva-dev/docs/codex.md                      # "## Explicit-only lifecycle skills" replaces the Codex-only section
plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1   # pins for all of the above
docs/host-parity.md                                    # Notes for the affected rows
scripts/host-neutrality-baseline.json                  # lowered with -Update
docs/adr/NNNN-explicit-only-invocation-metadata-only-where-no-skill-routes-in.md   # ADR C3
docs/host-parity/stage1-review.md                      # new: Stage 1 review checklist
```

## Candidate ADRs

### ADR-C3: Explicit-only invocation metadata only where no skill routes in
**Provenance:** Suggested by human
A lifecycle entry skill that no other skill dispatches or offers to run carries both `disable-model-invocation: true` (Claude Code) and `agents/openai.yaml` `policy.allow_implicit_invocation: false` (Codex), always together, and `check-host-parity.ps1` fails if only one is present. Skills that other skills route into or offer (quick-fix, plan-feature, backlog, adr, glossary, groom-backlog, easy-work-scan, applicable-rules, gate-check) stay model-invocable and state their explicit-start rule in their description, so approved skill-to-skill dispatch keeps working on both agent hosts.
**Write with:** Task 2

## Task 1: Explicit-only metadata on the non-routed entry skills

**Files:**
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`, `.../explore-idea/SKILL.md`, `.../cleanup-work/SKILL.md`, `.../cleanup-allwork/SKILL.md`, `.../repo-init/SKILL.md`, `.../add-module/SKILL.md` (all under `plugins/cogniva-dev/skills/`)
- Create: `plugins/cogniva-dev/skills/<same six>/agents/openai.yaml`
- Modify: `docs/host-parity.md`
- Test:   `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`

Candidate set: `execute-feature`, `explore-idea`, `cleanup-work`,
`cleanup-allwork`, `repo-init`, `add-module`. Claude Code's
`disable-model-invocation: true` also stops other skills from invoking the
skill, so a candidate qualifies only if no shared skill tells the agent to run
it. The Codex key path is confirmed by Codex's bundled skill-creator reference
(`~/.codex/skills/.system/skill-creator/references/openai_yaml.md`:
"`policy.allow_implicit_invocation`: When false, the skill is not injected into
the model context by default, but can still be invoked explicitly via
`$skill`"); the Stage 1 gate still has a human confirm the behaviour in Codex.

- [x] **Step 1 (qualify each candidate):** Run (Bash):
  ```bash
  for n in execute-feature explore-idea cleanup-work cleanup-allwork repo-init add-module; do echo "## $n"; grep -rnF --include='*.md' -e "$n" plugins/cogniva-dev/skills plugins/cogniva-skills/skills | grep -v "/skills/$n/"; done
  ```
  Acceptance rule, applied to every hit line (read 3 lines of context where the line alone is unclear). A hit is ACCEPTED when it is: (a) a command or pointer for the USER (`/cogniva-dev:<name>`, `/<name>`, `$<name>` inside "tell the user", "point them at", "Run … when ready", "the close-out pointer", "STOP and tell the user to run", a status hint); (b) a reference to the skill's files, format or prose (`../execute-feature/CODEX.md`, `templates/execute-feature.workflow.js`, "as execute-feature defines it", "a planless sibling of", `(set by execute-feature)`, a REQUIRED EXECUTOR header); reading another skill's file by path is a file read, not an invocation, on both agent hosts; or (c) a negation ("do NOT chain `execute-feature`"). A hit FAILS when it tells the agent to run, invoke, dispatch, chain or start that skill, or offers to run it so that a "yes" makes the agent start it. At the plan's base commit every hit was accepted: `execute-feature` hits are file references in quick-fix/plan-feature/adr/backlog/PLAN-FORMAT, user commands in plan-feature ("Run `/execute-feature …` when ready"), module-status and workflow-status, and the negation in `easy-work-scan/EASY-WORK-CRITERIA.md`; `cleanup-work`/`cleanup-allwork` hits are user close-out pointers in easy-work-scan, cleanup-work, cleanup-allwork, workflow-status and the `WORKTREE.md` overlays; `add-module` hits are prose in module-deps; `explore-idea` and `repo-init` have no hits. Record each candidate's verdict in your task report. A candidate that FAILS is dropped: delete its name from `$explicitOnly` in the Step 2 block, skip it in Steps 4–7, and in `docs/host-parity.md` append to its row's Notes `Model-invocable: routed from <skill> (<file>:<line>).`; the ADR for this policy stays as written.
- [x] **Step 2 (failing pins):** In `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`, insert this block immediately BEFORE the line `if ($failures.Count -gt 0) {` near the end of the file (no indentation in the file):
  ```powershell
  # --- explicit-only invocation metadata (both agent hosts) ----------------------
  $explicitOnly = @('execute-feature', 'explore-idea', 'cleanup-work', 'cleanup-allwork', 'repo-init', 'add-module')
  foreach ($name in $explicitOnly) {
      $skillText = ReadDoc "skills\$name\SKILL.md"
      $yamlPath = Join-Path $plugin "skills\$name\agents\openai.yaml"
      $yamlText = ''
      if (Test-Path $yamlPath) { $yamlText = [System.IO.File]::ReadAllText($yamlPath) }
      Check "$name is explicit-only on both agent hosts" `
          ($skillText -match '(?m)^disable-model-invocation: true' -and $yamlText -match '(?m)^policy:' -and $yamlText -match '(?m)^\s+allow_implicit_invocation: false')
  }
  $routed = @('quick-fix', 'plan-feature', 'backlog', 'adr', 'groom-backlog', 'easy-work-scan', 'applicable-rules', 'feature-check', 'gate-check')
  Check 'routed skills stay model-invocable on both agent hosts' `
      (@($routed | Where-Object { (ReadDoc "skills\$_\SKILL.md") -match 'disable-model-invocation' -or (Test-Path (Join-Path $plugin "skills\$_\agents\openai.yaml")) }).Count -eq 0)
  ```
- [x] **Step 3 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → one `FAIL  <skill> is explicit-only on both agent hosts` line per qualifying candidate (6), `PASS  routed skills stay model-invocable on both agent hosts`, then `FAILED: 6 assertion(s).`, exit 1.
- [x] **Step 4 (Claude Code metadata):** In each qualifying `plugins/cogniva-dev/skills/<skill>/SKILL.md`, the frontmatter is `---` / `name: <skill>` / `description: …` / `---`. Insert one new line `disable-model-invocation: true` directly after the `description:` line, before the closing `---`. Change nothing else. For example `explore-idea/SKILL.md` begins:
  ```
  ---
  name: explore-idea
  description: Use when the user wants to BRAINSTORM and develop an idea before any planning - a long, question-driven design conversation that produces only disposable thinking docs (gitignored .explore/), never a plan and never code. Invoke explicitly only; the goal is to deepen the idea, not to converge on action. Comes BEFORE plan-feature.
  disable-model-invocation: true
  ---
  ```
- [x] **Step 5 (Codex metadata):** For each qualifying skill create `plugins/cogniva-dev/skills/<skill>/agents/openai.yaml` with exactly this content (two lines, LF, trailing newline):
  ```yaml
  policy:
    allow_implicit_invocation: false
  ```
- [x] **Step 6 (run until green):**
  - `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`
  - `pwsh -NoProfile -File scripts/check-host-parity.ps1` → `host-parity: OK - 25 rows, 32 items covered` (no `FAIL invocation-metadata`)
  - `claude plugin validate .` → `✔ Validation passed`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-plugin-manifests.ps1` → exit 0
  - `pwsh -NoProfile -File scripts/check-host-neutrality.ps1` → the `host-neutrality: OK` line, no `FAIL`
- [x] **Step 7 (parity record):** In `docs/host-parity.md`, `## Capabilities`, put `Explicit-only (metadata, both agent hosts). ` at the START of the Notes cell of each row covering a qualifying skill (if a Notes cell is `—`, replace it with `Explicit-only (metadata, both agent hosts).`). With all six qualifying, the rows and their resulting Notes are:
  - `execute-feature`: ``Explicit-only (metadata, both agent hosts). The Codex loop has never run end to end. Task results differ by agent host: a schema-checked object under Claude Code, a textual `DONE`/`BLOCKED` line under Codex (one shared contract in CrossHostParity 07).``
  - `explore-idea`: `Explicit-only (metadata, both agent hosts). A conversation only; it may start read-only subagents.`
  - `worktree-cleanup` (covers cleanup-work and cleanup-allwork): `Explicit-only (metadata, both agent hosts). Codex does not start worktree-mode runs (row worktree-mode), so there is nothing to close out. In lean mode both skills report nothing to do.`
  - `repo-init`: `Explicit-only (metadata, both agent hosts). The scaffold templates and the shipped profile are gate-covered; running the scaffold is not. Its install guidance is Claude Code-only (CrossHostParity 09).`
  - `add-module`: `Explicit-only (metadata, both agent hosts). Profile gating is gate-covered; the scaffold itself is not.`

  Re-run `pwsh -NoProfile -File scripts/check-host-parity.ps1` → `host-parity: OK - 25 rows, 32 items covered`.
- [x] **Step 8 (commit):** `git add plugins/cogniva-dev/skills/execute-feature plugins/cogniva-dev/skills/explore-idea plugins/cogniva-dev/skills/cleanup-work plugins/cogniva-dev/skills/cleanup-allwork plugins/cogniva-dev/skills/repo-init plugins/cogniva-dev/skills/add-module plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1 docs/host-parity.md` (omit any dropped skill's folder) then `git commit -m "feat(skills): explicit-only invocation metadata on both agent hosts for entry skills no skill routes into"`

## Task 2: Routed skills state their start rule; agent-host-neutral explicit-only section; ADR

**Files:**
- Modify: `plugins/cogniva-dev/skills/quick-fix/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/plan-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/docs/codex.md`
- Modify: `docs/host-parity.md`
- Create: `docs/adr/NNNN-explicit-only-invocation-metadata-only-where-no-skill-routes-in.md`
- Test:   `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`

quick-fix and plan-feature keep model invocation because other skills route into
them: easy-work-scan dispatches approved items through quick-fix or plan-feature,
groom-backlog dispatches approved fixes through quick-fix, and backlog is the
routing gate every skill uses. Blocking model invocation would block those
approved dispatches too, so the rule lives in their descriptions instead.

- [x] **Step 1 (failing pins):** In `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`, under `# --- explicit invocation + plan-feature default`, replace these two lines:
  ```powershell
  Check 'docs/codex.md: lifecycle skills are explicit-invocation-only' `
      ($docs -match '## Lifecycle skills are explicit-invocation-only under Codex')
  ```
  with (no indentation in the file):
  ```powershell
  Check 'docs/codex.md: explicit-only lifecycle skills carry metadata on both agent hosts' `
      ($docs -match '## Explicit-only lifecycle skills' -and $docs -match 'disable-model-invocation: true' -and $docs -match 'allow_implicit_invocation: false' -and $docs -notmatch 'explicit-invocation-only under Codex')
  Check 'quick-fix description states its explicit-start rule' `
      ($qf -match 'Starts only on an explicit user request or an approved dispatch from easy-work-scan/groom-backlog')
  Check 'plan-feature description states its explicit-start rule' `
      ($pf -match 'Starts only on an explicit user request or an approved dispatch from easy-work-scan/groom-backlog')
  ```
- [x] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `FAIL` on the three new pins, `FAILED: 3 assertion(s).`, exit 1.
- [x] **Step 3 (quick-fix description):** In `plugins/cogniva-dev/skills/quick-fix/SKILL.md` replace the frontmatter line
  ```
  description: Use for small follow-up changes (UI tweak, bug fix, copy change) without a formal feature plan. Runs the change via a background Workflow so it can be fired repeatedly without bloating context; in worktree mode the change is isolated in a git worktree and auto-integrated.
  ```
  with
  ```
  description: Use for small follow-up changes (UI tweak, bug fix, copy change) without a formal feature plan. Runs the change via a background Workflow so it can be fired repeatedly without bloating context; in worktree mode the change is isolated in a git worktree and auto-integrated. Starts only on an explicit user request or an approved dispatch from easy-work-scan/groom-backlog - never auto-selected because a task resembles it.
  ```
- [x] **Step 4 (plan-feature description):** In `plugins/cogniva-dev/skills/plan-feature/SKILL.md` replace the frontmatter line
  ```
  description: Use when designing ONE feature with a strong model before implementation - runs a focused design session and emits a task-segmented feature plan (executable by /execute-feature). Pairs with adr (ADRs) and glossary.
  ```
  with
  ```
  description: Use when designing ONE feature with a strong model before implementation - runs a focused design session and emits a task-segmented feature plan (executable by /execute-feature). Pairs with adr (ADRs) and glossary. Starts only on an explicit user request or an approved dispatch from easy-work-scan/groom-backlog - never auto-selected because a task resembles it.
  ```
- [x] **Step 5 (the other routed skills already state their rule — verify, no edit):** Run in PowerShell 7:
  ```powershell
  $expect = [ordered]@{
      'plugins/cogniva-dev/skills/backlog/SKILL.md'          = 'Skill-initiated capture is proposed and confirmed first'
      'plugins/cogniva-dev/skills/adr/SKILL.md'              = 'ALWAYS with explicit human confirmation first'
      'plugins/cogniva-dev/skills/groom-backlog/SKILL.md'    = 'the user confirms everything once before any edit happens'
      'plugins/cogniva-dev/skills/easy-work-scan/SKILL.md'   = 'behind one approval gate'
      'plugins/cogniva-dev/skills/applicable-rules/SKILL.md' = 'Read-only; never changes repository or lifecycle state'
      'plugins/cogniva-dev/skills/gate-check/SKILL.md'       = 'without taking lifecycle ownership'
      'plugins/cogniva-skills/skills/glossary/SKILL.md'      = 'explicitly offer to document it in the glossary'
  }
  foreach ($k in $expect.Keys) { $d = (Get-Content -LiteralPath $k | Where-Object { $_ -like 'description:*' } | Select-Object -First 1); '{0} {1}' -f ($(if ($d.Contains($expect[$k])) { 'OK  ' } else { 'MISS' })), $k }
  ```
  → seven lines starting `OK  `. A `MISS` means that description changed since this plan was written: report it in the task report (do not edit the description in this task).
- [x] **Step 6 (agent-host-neutral explicit-only section):** In `plugins/cogniva-dev/docs/codex.md`, replace the whole section from the heading `## Lifecycle skills are explicit-invocation-only under Codex` down to, but not including, the heading `## Workflow-neutral guardrails for externally orchestrated work`. The section being replaced reads:
  ```markdown
  ## Lifecycle skills are explicit-invocation-only under Codex

  The presence of a skill never authorizes a lifecycle operation. Under Codex,
  mutation and lifecycle skills — `plan-feature`, `execute-feature`, `quick-fix`,
  ADR writes, backlog writes, cleanup/integration operations, and any branch or
  worktree operation — run only on explicit user invocation or unambiguous user
  intent, never auto-selected because a task description resembles a skill
  description. Read-only status and diagnostic skills (`feature-status`,
  `module-status`, `repo-status`, `workflow-status`) may still be selected
  automatically when appropriate.
  ```
  Replace it with exactly this, followed by one blank line (without the two-space block indentation; if one of the six skills has no `agents/openai.yaml` because it was found to be routed, remove its name from the list in the first paragraph):
  ```markdown
  ## Explicit-only lifecycle skills

  The presence of a skill never authorizes a lifecycle operation. The entry
  skills that no other skill dispatches or offers to run (`execute-feature`,
  `explore-idea`, `cleanup-work`, `cleanup-allwork`, `repo-init`, `add-module`)
  carry invocation metadata for both agent hosts, always as a pair:

  - **Claude Code:** `disable-model-invocation: true` in the skill's `SKILL.md`
    frontmatter. Typing the skill (`/cogniva-dev:execute-feature …`) still runs
    it; the model never starts it on its own.
  - **Codex:** `agents/openai.yaml` beside the skill, with
    `allow_implicit_invocation: false` under `policy:`. The skill is not offered
    to the model automatically; naming it (`$execute-feature …`) still runs it.

  The cogniva-skills repo's green gate fails when a skill carries only one of
  the pair.

  `quick-fix` and `plan-feature` are deliberately not marked: `easy-work-scan`
  and `groom-backlog` dispatch them after you approve a shortlist, and the
  metadata would block that approved dispatch on both agent hosts. Their
  descriptions carry the rule instead: they start only on an explicit request or
  an approved dispatch, never because a task resembles them. Skills that other
  skills route through (`backlog`, the routing gate for work any skill surfaces;
  `adr`; `glossary`) stay model-invocable for the same reason, and each confirms
  with you before it writes. Read-only status and diagnostic skills
  (`feature-status`, `module-status`, `repo-status`, `workflow-status`,
  `applicable-rules`, `feature-check`, `gate-check`) may still be selected
  automatically when appropriate.
  ```
- [x] **Step 7 (write ADR):** List `docs/adr/`, take the highest `NNNN-` number and add 1 (expected `0053`). Write `docs/adr/<that number>-explicit-only-invocation-metadata-only-where-no-skill-routes-in.md` per `plugins/cogniva-dev/skills/adr/ADR-FORMAT.md` with exactly this content (no candidate label in the heading, no Relitigation line):
  ```markdown
  # Explicit-only invocation metadata only where no skill routes in

  **Provenance:** Suggested by human

  A lifecycle entry skill that no other skill dispatches or offers to run
  carries both `disable-model-invocation: true` (Claude Code) and
  `agents/openai.yaml` `policy.allow_implicit_invocation: false` (Codex), always
  together, and `check-host-parity.ps1` fails if only one is present. Skills
  that other skills route into or offer (quick-fix, plan-feature, backlog, adr,
  glossary, groom-backlog, easy-work-scan, applicable-rules, gate-check) stay
  model-invocable and state their explicit-start rule in their description, so
  approved skill-to-skill dispatch keeps working on both agent hosts.
  ```
  Then `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/check-adrs.ps1 -Workspace . -Since HEAD` → exit 0, last lines start `check-adrs: clean`.
- [x] **Step 8 (parity record):** In `docs/host-parity.md`, `## Capabilities`, append to the END of the Notes cell of row `quick-fix` and of row `plan-feature` (one space before it): `Model-invocable by design: easy-work-scan and groom-backlog dispatch it after approval, and its description states the explicit-start rule.`
- [x] **Step 9 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`; `pwsh -NoProfile -File scripts/check-host-parity.ps1` → `host-parity: OK - 25 rows, 32 items covered`; `claude plugin validate .` → `✔ Validation passed`; `pwsh -NoProfile -File scripts/check-host-neutrality.ps1` → the `OK` line, no `FAIL`.
- [x] **Step 10 (commit):** `git add plugins/cogniva-dev/skills/quick-fix/SKILL.md plugins/cogniva-dev/skills/plan-feature/SKILL.md plugins/cogniva-dev/docs/codex.md docs/host-parity.md plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1 docs/adr` then `git commit -m "docs(skills): routed skills state their explicit-start rule; explicit-only section covers both agent hosts"`

## Task 3: Agent-host-neutral user-facing wording; lower the ratchet

**Files:**
- Modify: `plugins/cogniva-dev/skills/plan-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/explore-idea/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/groom-backlog/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/easy-work-scan/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/execute-feature/HANDOFF.md`
- Modify: `plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md`
- Modify: `docs/plans/BACKLOG.md`, `docs/plans/FeatureLifecycle/BACKLOG.md` (header lines only)
- Modify: `plugins/cogniva-skills/skills/glossary/SKILL.md`
- Modify: `scripts/host-neutrality-baseline.json` (via `-Update`)
- Test:   `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`

Only text that tells the USER what to type, and Claude Code tool names where a
neutral phrase says the same thing, change here. The `/cogniva-dev:` and
`/cogniva-skills:` examples in skills' "Invoke:" lines are documentation and
stay. New wording must not add any token the ratchet counts (`AskUserQuestion`,
`Workflow(`, `subagent_type`, `general-purpose`, `` `Explore` ``,
`CLAUDE_PLUGIN_ROOT`, `~/.claude`, `spawn_agent`, `request_user_input`,
`apply_patch`, `/cogniva-dev:`, `/cogniva-skills:`), so the baseline can only
fall. No existing test pins the BACKLOG.md header text (checked: no file under
`plugins/*/tests/` contains `Promote with`). Edit each line in place; do not
re-wrap surrounding paragraphs.

- [x] **Step 1 (failing pins):** In `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`, insert this block immediately BEFORE the line `if ($failures.Count -gt 0) {` near the end of the file (no indentation in the file):
  ```powershell
  # --- agent-host-neutral wording in shared skills ------------------------------
  $handoffFlat = $handoff -replace '\s+', ' '
  $bkFmtFlat = (ReadDoc 'skills\backlog\BACKLOG-FORMAT.md') -replace '\s+', ' '
  $eiText = ReadDoc 'skills\explore-idea\SKILL.md'
  $glText = [System.IO.File]::ReadAllText((Join-Path $plugin '..\cogniva-skills\skills\glossary\SKILL.md'))
  $scanFlat = ((ReadDoc 'skills\groom-backlog\SKILL.md') + ' ' + (ReadDoc 'skills\easy-work-scan\SKILL.md')) -replace '\s+', ' '
  Check 'plan-feature summary names execute-feature in both agent hosts'' syntax' `
      ($pfFlat -match 'Run the execute-feature skill on `<Module>/<Feature>` when ready' -and $pfFlat -match '`\$execute-feature <Module>/<Feature>` in Codex')
  Check 'HANDOFF: skill invocations use the current agent host''s syntax' `
      ($handoffFlat -match 'write the invocation in the current agent host''s syntax')
  Check 'backlog header names skills, not one agent host''s commands' `
      ($bkFmtFlat -match 'Promote with the plan-feature skill; trivial fixes can go straight to quick-fix\.')
  Check 'shared skills name no Claude Code question tool' `
      ($pf -notmatch 'AskUserQuestion' -and $eiText -notmatch 'AskUserQuestion' -and $glText -notmatch 'AskUserQuestion')
  Check 'glossary description names no Claude Code tools' `
      ($glText -notmatch 'DO NOT use Grep, Glob, Read' -and $glText -match 'DO NOT search the codebase \(grep, file search or file reads\)')
  Check 'scan subagents are described for both agent hosts' `
      ([regex]::Matches($scanFlat, 'Spawn ONE read-only subagent \(Claude Code: `general-purpose`; Codex: the default agent\)').Count -eq 2)
  ```
- [x] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `FAIL` on the six new pins, `FAILED: 6 assertion(s).`, exit 1.
- [x] **Step 3 (plan-feature: the closing line the user reads):** In `plugins/cogniva-dev/skills/plan-feature/SKILL.md`, `## Emit a CONCISE decisions summary`, replace
  ```
  downstream consequence in one clause), then the plan path and "Run
  `/execute-feature <Module>/<Feature>` when ready." Exclude anything already
  ```
  with
  ```
  downstream consequence in one clause), then the plan path and "Run the
  execute-feature skill on `<Module>/<Feature>` when ready
  (`/execute-feature <Module>/<Feature>` in Claude Code,
  `$execute-feature <Module>/<Feature>` in Codex)." Exclude anything already
  ```
- [x] **Step 4 (plan-feature: design questions):** In the same file replace
  ```
  3. Surface each genuine design fork with **AskUserQuestion** (one popup per
     fork). Describe UI choices in prose.
  ```
  with
  ```
  3. Surface each genuine design fork as one question, asked with the agent
     host's structured question tool, or as a plain question when there is
     none. Describe UI choices in prose.
  ```
- [x] **Step 5 (explore-idea):** In `plugins/cogniva-dev/skills/explore-idea/SKILL.md` replace `use **AskUserQuestion** only for genuine forks.` with `use the agent host's structured question tool only for genuine forks.`, and replace ``dispatch read-only `Explore` agents`` with `dispatch read-only exploration subagents`.
- [x] **Step 6 (glossary):** In `plugins/cogniva-skills/skills/glossary/SKILL.md`, in the `description:` frontmatter line replace `DO NOT use Grep, Glob, Read, or any search tool on an unrecognized term` with `DO NOT search the codebase (grep, file search or file reads) for an unrecognized term` (the rest of the line is unchanged); and in step 2 of the issue-detection list replace ``Use `AskUserQuestion` or direct text to confirm:`` with `Use the agent host's structured question tool, or a plain question, to confirm:`.
- [x] **Step 7 (scan subagents):** In `plugins/cogniva-dev/skills/groom-backlog/SKILL.md` and in `plugins/cogniva-dev/skills/easy-work-scan/SKILL.md`, replace `Spawn ONE general-purpose subagent with:` with ``Spawn ONE read-only subagent (Claude Code: `general-purpose`; Codex: the default agent) with:`` (one occurrence in each file).
- [x] **Step 8 (handoff rule):** In `plugins/cogniva-dev/skills/execute-feature/HANDOFF.md`, insert this section immediately BEFORE the heading `## Closing line`, followed by one blank line (without the two-space block indentation):
  ```markdown
  ## Skill invocations

  When any section tells the user to run a skill (a resume, a follow-up, a
  close-out), write the invocation in the current agent host's syntax: a slash
  command in Claude Code (`/execute-feature <Module>/<Feature>`), a `$` mention
  in Codex (`$execute-feature <Module>/<Feature>`).
  ```
- [x] **Step 9 (BACKLOG.md header the backlog skill writes):** In `plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md`, `### Header (used when lazy-creating the file)`, replace the two lines
  ```
  Planned deferrals — work with a stated reason to wait (`because:` tag). Promote with /cogniva-dev:plan-feature;
  trivial fixes can go straight to /cogniva-dev:quick-fix.
  ```
  with
  ```
  Planned deferrals — work with a stated reason to wait (`because:` tag). Promote with the plan-feature skill;
  trivial fixes can go straight to quick-fix.
  ```
  Then make the same two-line replacement in every existing backlog file in this repo, so old and new files read the same: run `git ls-files "docs/plans/BACKLOG.md" "docs/plans/*/BACKLOG.md"` (at planning time: `docs/plans/BACKLOG.md` and `docs/plans/FeatureLifecycle/BACKLOG.md`) and, in each file listed, replace the two lines above with the two new lines. Change nothing else in those files. Check: `grep -rn "Promote with /cogniva-dev" docs/plans plugins/cogniva-dev/skills/backlog` → no output (exit 1).
- [x] **Step 10 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`; `claude plugin validate .` → `✔ Validation passed`; `pwsh -NoProfile -File scripts/check-host-parity.ps1` → `host-parity: OK - 25 rows, 32 items covered`.
- [x] **Step 11 (the ratchet sees only decreases):** Save the current baseline, then run the checker: `pwsh -NoProfile -Command "Copy-Item scripts/host-neutrality-baseline.json (Join-Path ([System.IO.Path]::GetTempPath()) 'host-neutrality-before.json')"`, then `pwsh -NoProfile -File scripts/check-host-neutrality.ps1` → exit 0, no `FAIL` line, and these five `INFO lower the baseline:` lines (any order):
  ```
  INFO lower the baseline: plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md '/cogniva-dev:' baseline 3, now 1 - run check-host-neutrality.ps1 -Update
  INFO lower the baseline: plugins/cogniva-dev/skills/explore-idea/SKILL.md 'AskUserQuestion' baseline 1, now 0 - run check-host-neutrality.ps1 -Update
  INFO lower the baseline: plugins/cogniva-dev/skills/explore-idea/SKILL.md '`Explore`' baseline 1, now 0 - run check-host-neutrality.ps1 -Update
  INFO lower the baseline: plugins/cogniva-dev/skills/plan-feature/SKILL.md 'AskUserQuestion' baseline 1, now 0 - run check-host-neutrality.ps1 -Update
  INFO lower the baseline: plugins/cogniva-skills/skills/glossary/SKILL.md 'AskUserQuestion' baseline 1, now 0 - run check-host-neutrality.ps1 -Update
  ```
  (The "baseline" numbers are those in the committed `scripts/host-neutrality-baseline.json`; if that file holds a different number for one of these pairs, the line still has to go DOWN.) Any `FAIL host-token-` line means new wording added a counted token: reword it, do not update the baseline.
- [x] **Step 12 (lower the baseline and prove it only fell):** `pwsh -NoProfile -File scripts/check-host-neutrality.ps1 -Update` → `host-neutrality: baseline updated - <n> references in <m> files` (5 fewer references and 2 fewer files than before: explore-idea and glossary drop out). Then run in PowerShell 7:
  ```powershell
  $old = Get-Content -Raw (Join-Path ([System.IO.Path]::GetTempPath()) 'host-neutrality-before.json') | ConvertFrom-Json -AsHashtable
  $new = Get-Content -Raw scripts/host-neutrality-baseline.json | ConvertFrom-Json -AsHashtable
  foreach ($p in @(@($old.Keys) + @($new.Keys) | Sort-Object -Unique)) {
      $o = if ($old.ContainsKey($p)) { $old[$p] } else { @{} }
      $n = if ($new.ContainsKey($p)) { $new[$p] } else { @{} }
      foreach ($t in @(@($o.Keys) + @($n.Keys) | Sort-Object -Unique)) {
          $a = if ($o.ContainsKey($t)) { [int]$o[$t] } else { 0 }
          $b = if ($n.ContainsKey($t)) { [int]$n[$t] } else { 0 }
          if ($b -gt $a) { "UP   $p '$t' $a -> $b" } elseif ($b -lt $a) { "DOWN $p '$t' $a -> $b" }
      }
  }
  ```
  → exactly five `DOWN` lines (the five pairs from Step 11) and no `UP` line. Then `pwsh -NoProfile -File scripts/check-host-neutrality.ps1` → `host-neutrality: OK - …` with no `INFO` line.
- [x] **Step 13 (commit):** `git add plugins/cogniva-dev/skills/plan-feature/SKILL.md plugins/cogniva-dev/skills/explore-idea/SKILL.md plugins/cogniva-dev/skills/groom-backlog/SKILL.md plugins/cogniva-dev/skills/easy-work-scan/SKILL.md plugins/cogniva-dev/skills/execute-feature/HANDOFF.md plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md docs/plans/BACKLOG.md docs/plans/FeatureLifecycle/BACKLOG.md plugins/cogniva-skills/skills/glossary/SKILL.md scripts/host-neutrality-baseline.json plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` then `git commit -m "refactor(skills): agent-host-neutral invocation and tool wording; lower the host-token baseline"`

## ⛔ Task 4: Stage 1 review  (manual validation gate — execute-feature STOPS here)

**Files:**
- Create: `docs/host-parity/stage1-review.md`

A stop at this gate skips the executor's landing, so this task runs the full
green gate itself.

- [x] **Step 1 (full green gate):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → `green-gate: GREEN - all 24 command(s) exited 0.` Then `pwsh -NoProfile -Command "(Get-Content -Raw .claude/cogniva-dev/green-gate.json | ConvertFrom-Json).commands.label -join ','"` → the 24 labels are the 12 original ones (`validate`, `manifest-parity`, `skill-semantics`, `adr-checker`, `green-gate-runner`, `applicable-rules`, `architecture-profile`, `profile-library`, `structural-changes`, `module-deps`, `module-deps-hook`, `gate-check`) plus `instruction-governance`, `git-commit`, `integrate-feature`, `ledger`, `parse-plan-tasks`, `validate-json`, `manifest-checker`, `primary-hooks`, `host-parity-suite`, `host-parity`, `host-neutrality-suite`, `host-neutrality`. A failing command or a missing label: STOP, report it, and do not continue to the human steps.
- [x] **Step 2 (the two Stage 1 checkers):** `pwsh -NoProfile -File scripts/check-host-parity.ps1` → `host-parity: OK - 25 rows, 32 items covered`. `pwsh -NoProfile -File scripts/check-host-neutrality.ps1` → `host-neutrality: OK - <n> host-specific references in <m> files (baseline)`, no `INFO` or `FAIL` line.
- [x] **Step 3 (review checklist):** Create `docs/host-parity/stage1-review.md` with this content, filling the `Prepared:` date and the three agent-check Result cells with the exact result lines from Steps 1–2, and leaving every human-check Result and Notes cell empty (without the two-space block indentation):
  ```markdown
  # CrossHostParity Stage 1 review

  Branch: `feature/cross-host-parity`
  Prepared: <YYYY-MM-DD>, by the agent that ran sub-plan 04

  ## Agent checks

  | Check | Command | Result |
  |---|---|---|
  | Green gate | `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` | |
  | Parity record | `pwsh -NoProfile -File scripts/check-host-parity.ps1` | |
  | Agent-host token ratchet | `pwsh -NoProfile -File scripts/check-host-neutrality.ps1` | |

  ## Human checks

  | # | Check | Agent host and surface | Result (pass / fail) | Notes |
  |---|---|---|---|---|
  | 1 | Fresh session, no file named: "What files does a plugin version bump touch, and what must a change to a skill consider about agent hosts?" The answer names the three version files and the cross-host parity rule. | Codex, VS Code | | |
  | 2 | The same question in a fresh session. | Claude Code | | |
  | 3 | `$feature-check review` over the branch diff against `main`; every finding resolved or answered. | Codex | | |
  | 4 | `/skills` lists the six explicit-only skills, and "clean up my worktrees" does not start cleanup-work on its own. | Codex, VS Code | | |
  | 5 | Typing `/cogniva-dev:execute-feature` still starts the skill. | Claude Code | | |
  | 6 | Version bumps applied, three files each, matching (`grep -n '"version"'`), green gate re-run GREEN. | either | | |
  | 7 | PR 1 (Stage 1) opened from `feature/cross-host-parity`, reviewed and merged. | n/a | | |
  ```
- [x] **Step 4 (commit, `commits=task` only):** `git add docs/host-parity/stage1-review.md` then `git commit -m "docs(host-parity): Stage 1 review checklist"`
- [x] **Step 5 (human — Codex instruction probe):** Open a FRESH Codex session in VS Code in this repo, on `feature/cross-host-parity`. Without naming any file, ask: "What files does a plugin version bump touch, and what must a change to a skill consider about agent hosts?" Record in `docs/host-parity/stage1-review.md` row 1 whether the answer names the three version files (`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, the marketplace entry) and states the cross-host parity rule.
- [x] **Step 6 (human — Claude Code instruction probe):** Ask the same question in a FRESH Claude Code session in this repo; record the result in row 2.
- [x] **Step 7 (human — Codex reviews Stage 1):** In Codex, run `$feature-check review` over the branch diff against `main` (Codex reviews the Stage 1 work Claude Code implemented). Resolve or answer every finding (fixes go in as normal commits on the branch, then re-run the green gate); record the outcome in row 3.
- [x] **Step 8 (human — invocation policy on both agent hosts):** In Codex (VS Code), open `/skills` and confirm `execute-feature`, `explore-idea`, `cleanup-work`, `cleanup-allwork`, `repo-init` and `add-module` are listed but not auto-selected: type "clean up my worktrees" and observe that cleanup-work does NOT start on its own. Record in row 4. In Claude Code, type `/cogniva-dev:execute-feature` and confirm the skill still starts when typed (cancel it once it asks for a plan); record in row 5.
- [x] **Step 9 (human — version bumps):** Per `AGENTS.md` `## Rules`, the agent offers: cogniva-dev MINOR `0.10.0 → 0.11.0` (a workflow and policy change: explicit-only invocation metadata, the parity record and its gate checks); cogniva-skills PATCH `0.8.0 → 0.8.1` (wording only: the glossary skill's description and question wording). Approve or change them, then have them applied — each bump edits THREE files that must match: `plugins/<plugin>/.claude-plugin/plugin.json`, `plugins/<plugin>/.codex-plugin/plugin.json` and the plugin's entry in `.claude-plugin/marketplace.json`. Confirm with `grep -n '"version"' plugins/cogniva-dev/.claude-plugin/plugin.json plugins/cogniva-dev/.codex-plugin/plugin.json plugins/cogniva-skills/.claude-plugin/plugin.json plugins/cogniva-skills/.codex-plugin/plugin.json .claude-plugin/marketplace.json`, re-run the green gate (expect `GREEN`), commit, and record in row 6.
- [x] **Step 10 (human — PR 1):** Open PR 1 (Stage 1) from `feature/cross-host-parity` into `main`, review it, merge it, and record the PR number in row 7. Commit the filled-in `docs/host-parity/stage1-review.md` on the branch before merging.
- [x] **Step 11:** Wait for the user to confirm before any later task runs.
