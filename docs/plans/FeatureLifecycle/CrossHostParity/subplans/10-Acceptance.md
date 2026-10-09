# 10 Acceptance — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/CrossHostParity
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** Stage 2 ends on evidence: the same nine smoke scenarios run on both
agent hosts against this branch's build, the parity record's statuses move
only where a smoke record earns it, and a human checks the Stage 2 acceptance
table, the VS Code surfaces and the cross-host review before PR 2b merges.

**Architecture:** Task 1 is agent-runnable: it drives the Claude Code CLI and
the Codex CLI through the smoke harness (`invoke-host-smoke.ps1 -Scenario
all`), which builds the fixtures, runs each scenario, asserts outcomes and
writes one smoke record per agent host to `docs/host-parity/smoke/`. Task 2 is
the Stage 2 ⛔ gate: the agent updates statuses from those records under one
mechanical rule, pre-creates `docs/host-parity/stage2-acceptance.md`, and runs
`check-host-parity.ps1` and the full green gate; the human then runs the
VS Code surfaces with the runbook, marks each acceptance row, runs the
cross-host review, bumps versions, and merges.

**Read these first:** `docs/plans/FeatureLifecycle/CrossHostParity/CrossHostParity-plan.md`
(§ Acceptance criteria → Stage 2), `docs/host-parity.md` (§ Status values,
§ Smoke evidence), `plugins/cogniva-dev/tests/host-smoke/` (the driver
`invoke-host-smoke.ps1`, its scenarios and the GUI runbook),
`docs/host-parity/codex-diagnostics.md`, `AGENTS.md` (`## Rules` — version
bumps).

## File structure (locked)

```
docs/host-parity/smoke/<date>-claude-code-cli.md      # smoke record, Claude Code CLI, all nine scenarios (Task 1)
docs/host-parity/smoke/<date>-codex-cli.md            # smoke record, Codex CLI, all nine scenarios (Task 1)
docs/host-parity.md                                   # statuses earned from smoke records (Task 2)
docs/host-parity/stage2-acceptance.md                 # Stage 2 evidence table, results filled by the human (Task 2)
docs/host-parity/smoke/<date>-codex-vscode.md         # human, Task 2
docs/host-parity/smoke/<date>-claude-code-vscode.md   # human, Task 2
```

## Task 1: Agent-runnable smoke runs on both agent hosts (CLI)

**Files:**
- Create: `docs/host-parity/smoke/<YYYY-MM-DD>-claude-code-cli.md` (written by the driver)
- Create: `docs/host-parity/smoke/<YYYY-MM-DD>-codex-cli.md` (written by the driver)

Context: the smoke harness lives in `plugins/cogniva-dev/tests/host-smoke/`.
Its driver `invoke-host-smoke.ps1` (pwsh 7) runs scenarios `QF-NONE`,
`QF-FINAL`, `EF-TWO`, `EF-BLOCKED`, `EF-GATE`, `QF-STRUCT`, `POLICY`, `HOOKS`,
`INSTR` in temp fixture repos, asserts their outcomes, and writes a smoke record
named `<YYYY-MM-DD>-<claude-code|codex>-cli` (suffix `-2`, `-3` when one
already exists that day) to `docs/host-parity/smoke/`. A record's header lines
include `Agent host:`, `Plugin versions:` and `Plugin source:`; its
`## Scenarios` table has one row per scenario with Result `pass`, `fail` or
`not-run`. `claude` is on PATH. Codex has no `codex` on PATH: its binary is
bundled with the VS Code extension under
`%USERPROFILE%\.vscode\extensions\openai.chatgpt-<version>-win32-x64\bin\windows-x86_64\`,
and the driver takes it as `-CodexExe`. These runs drive real agent sessions
and take several minutes per scenario: if a single command would exceed your
shell's time limit, run the driver once per scenario ID instead of `all` (the
driver appends to the same day's record, or writes one record per call —
follow whichever its runbook documents).

- [ ] **Step 1 (driver parameters):** Read the `param()` block of `plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1` and the runbook beside it. The commands below use `-AgentHost claude-code|codex`, `-Scenario` and `-CodexExe`, the names sub-plan 05 defined; if the script names them differently, use its names with the same values throughout this task.
- [ ] **Step 2 (Claude Code CLI, all scenarios):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost claude-code -Scenario all` → it prints one result line per scenario and the path of the record it wrote under `docs/host-parity/smoke/`. A scenario `fail` does NOT stop this task: the record is the evidence either way.
- [ ] **Step 3 (Codex binary):** find the newest bundled Codex binary: `pwsh -NoProfile -Command '(Get-ChildItem -Path (Join-Path $env:USERPROFILE ".vscode\extensions") -Directory -Filter "openai.chatgpt-*-win32-x64" | Sort-Object LastWriteTime | Select-Object -Last 1 | ForEach-Object { Join-Path $_.FullName "bin\windows-x86_64\codex.exe" })'` (single-quoted so neither bash nor PowerShell expands `$env`/`$_` before pwsh runs it) → prints one path; check it exists (`Test-Path`). No path, or the file is missing → STOP and return `BLOCKED` with the note `Codex binary not found: install or update the ChatGPT/Codex VS Code extension (human step), then re-run this task.`
- [ ] **Step 4 (Codex CLI, all scenarios):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost codex -CodexExe "<path from Step 3>" -Scenario all` → result lines and the record path, as in Step 2.
- [ ] **Step 5 (branch build check):** Open each record written in Steps 2 and 4. `Plugin versions:` must show the versions in `plugins/cogniva-dev/.claude-plugin/plugin.json` and `plugins/cogniva-skills/.claude-plugin/plugin.json`, and `Plugin source:` must name a local marketplace from THIS checkout (`git rev-parse --show-toplevel`) at a commit of this branch (`git merge-base --is-ancestor <sha in the record> HEAD` exits 0). If the Codex record fails either check, delete that record file (it is not evidence of this branch's build) and STOP with `BLOCKED`, note: `Codex branch build not installed — human step: run "<CodexExe> plugin marketplace add <this checkout's path>", install cogniva-dev and cogniva-skills from it via /plugins, start a new Codex session, trust the plugin hooks via /hooks, then re-run this task.` If the Claude Code record fails either check, do the same with the note: `Claude Code branch build not installed — human step: run "/plugin marketplace add <this checkout's path>", then "/plugin install cogniva-dev@cogniva" and "/plugin install cogniva-skills@cogniva", restart Claude Code, then re-run this task.`
- [ ] **Step 6 (records are well-formed):** for each of the two records: the first lines are `# Smoke record <record-id>`, `Agent host:`, `Agent host version:`, `Surface: CLI`, `OS:`, `Plugin versions:`, `Plugin source:`, `Date:`, `Covers:`; the `## Scenarios` table has exactly nine rows, one per scenario ID; `## Observations` exists. A malformed record → fix the driver invocation (not the record by hand) and re-run that agent host's step.
- [ ] **Step 7 (parity check):** run the `run` command of the `host-parity` entry in `.claude/cogniva-dev/green-gate.json` from the repo root → exit 0 (`WARN stale evidence` lines are warnings, not failures).
- [ ] **Step 8 (commit):** `git add docs/host-parity/smoke` then `git commit -m "test(parity): Stage 2 CLI smoke records for Claude Code and Codex"`. In the task's result summary, list each record ID with its pass/fail/not-run counts.

## ⛔ Task 2: Stage 2 acceptance  (manual validation gate — execute-feature STOPS here)

**Files:**
- Modify: `docs/host-parity.md`
- Create: `docs/host-parity/stage2-acceptance.md`

Context: a parity-record status may be `verified` for an agent host only when
a smoke record from that agent host lists the row's ID in its `Covers:` line
and contains no `| fail |` scenario row; the record's `Plugin versions:`
cogniva-dev major.minor must equal the current plugin's for the checker to
count it without a `WARN stale evidence`. The Capabilities table columns are
`| ID | Capability | Kind | Covers | Claude Code | Codex | Evidence | Notes |`;
a status cell is `<status>` optionally followed by ` — <mechanism>`.

- [ ] **Step 1 (statuses from evidence, agent):** For every record in `docs/host-parity/smoke/` whose `Plugin versions:` cogniva-dev major.minor equals `plugins/cogniva-dev/.claude-plugin/plugin.json`'s, and which contains no `| fail |` row: for each row ID in its `Covers:` line, in `docs/host-parity.md` set the cell of the record's agent host (`Agent host: Claude Code` → `Claude Code` column; `Agent host: Codex` → `Codex` column) to `verified`, keeping any ` — <mechanism>` text, and add `smoke:<record-id>` to that row's `Evidence` (replace a lone `—`). Never change a cell to `verified` from a record with a `| fail |` row, never change a cell for which no such record exists, and never lower a status in this step. Keep a list of every cell you changed (row ID, agent host, old status → `verified`, record ID) and every record you skipped because it has a failing scenario (record ID, failing scenario IDs) — the result summary reports both lists.
- [ ] **Step 2 (acceptance sheet, agent):** Create `docs/host-parity/stage2-acceptance.md` with exactly the content below, then fill the three marked lists as described (leave every Result cell of the evidence table empty for the human):
  ```markdown
  # Stage 2 acceptance — CrossHostParity

  Prepared by the agent at the Stage 2 gate (sub-plan 10, Task 2). The human
  fills the two result columns, row by row, from the smoke records and the
  final messages they reference: `met`, or `not met — <why>`.

  ## Smoke records

  <!-- agent: one bullet per record in docs/host-parity/smoke/ dated this stage, as "- <record-id> — <Agent host>, <Surface>: <n> pass, <n> fail, <n> not-run" -->

  ## Evidence table

  | Evidence area | Required evidence, per agent host | Claude Code | Codex |
  |---|---|---|---|
  | Execution | `QF-NONE`, `EF-TWO` assertions pass: intended files changed, tests in the fixture's green gate pass, and every `HANDOFF.md` section heading is present in the final message. | | |
  | Commit policies | `QF-NONE`: 0 new commits. `QF-FINAL`: exactly 1, created after the gate. `EF-TWO`: 2, with plan ticks committed. Checked by `git rev-list` in the assertion script, never by the agent's word. | | |
  | Branch and unrelated work | Every scenario: branch name unchanged, and the pre-dirtied `notes/unrelated.txt` keeps its content and is in no new commit. `POLICY`: stops with no file written, no `.git/info/exclude` change, and no commit. | | |
  | Blocked / manual gate | `EF-BLOCKED`: 0 commits and task 2 untouched. `EF-GATE`: stops after task 2 with task 3 untouched; the re-run completes task 3 only. | | |
  | Structural checks | `QF-STRUCT`: final message carries `STRUCTURE: FOUND` with no `UNEXPECTED`. The snapshot step succeeded or the Codex sandbox remedy from 06 applied. | | |
  | Hooks + documented limits | `HOOKS`: a Claude `Edit` and a Codex `apply_patch` to the primary checkout are both denied (where Codex hooks fire on that surface; otherwise the record says `partial` with the surface named). A shell-mediated write is documented as uncaught, not claimed. | | |
  | Honest handoffs and status | All `HANDOFF.md` sections present. A skipped gate appears under Skipped validations. `feature-status` lists the ephemeral `EF-GATE` plan as in progress. | | |
  | Install + discoverability | Smoke record per agent host and surface: plugin version, both plugins' skills listed, explicit-only skills absent from implicit selection (Codex `/skills` view; Claude Code `/` menu still lists them), hook trust state noted. | | |

  ## Status changes made from smoke evidence

  <!-- agent: the list from Step 1, one bullet per changed cell: "- <row ID> — <agent host>: <old> → verified (smoke:<record-id>)"; then one bullet per skipped record: "- skipped <record-id>: failing <scenario IDs>" -->

  ## Stage 3 inputs

  <!-- agent: one bullet per Capabilities cell still `partial` or `untested` after Step 1: "- <row ID> — <agent host>: <status> — <Notes>" -->

  ## Cross-host review

  - Reviewer: a Claude Code session, `/cogniva-dev:feature-check review` over the sub-plan 07–09 diff (implemented by Codex).
  - Findings and how each was resolved:

  ## Notes

  - Bumping cogniva-dev's minor version at this gate makes the CLI records above one minor version older than `plugin.json`; `check-host-parity.ps1` then prints `WARN stale evidence` for them. That is a warning by design (they were taken from this branch before the bump), not a failure.
  ```
  Replace each `<!-- agent: … -->` comment with the list it describes (write `none` when a list is empty). Leave the `Findings and how each was resolved:` bullet as it is for the human.
- [ ] **Step 3 (checks, agent):** run the `run` command of the `host-parity` entry in `.claude/cogniva-dev/green-gate.json` → exit 0. Then the full green gate: `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → `green-gate: GREEN - all N command(s) exited 0.` and last line `GREEN-GATE-RESULT: GREEN`. (A stop at this gate skips the executor's landing, so this task runs the gate itself.)
- [ ] **Step 4 (commit, agent):** `git add docs/host-parity.md docs/host-parity/stage2-acceptance.md` then `git commit -m "docs(parity): Stage 2 statuses from smoke evidence; acceptance sheet"`. Report the two lists from Step 1 in the result summary.
- [ ] **Step 5 (human — VS Code runs):** Using the GUI runbook in `plugins/cogniva-dev/tests/host-smoke/`, with this branch's build installed on both agent hosts: in **Codex in VS Code**, run all nine scenarios (`QF-NONE`, `QF-FINAL`, `EF-TWO`, `EF-BLOCKED`, `EF-GATE`, `QF-STRUCT`, `POLICY`, `HOOKS`, `INSTR`); in **Claude Code in VS Code**, run `QF-NONE`, `EF-GATE` and `HOOKS`. Record each surface as a smoke record in `docs/host-parity/smoke/` (`<YYYY-MM-DD>-codex-vscode.md`, `<YYYY-MM-DD>-claude-code-vscode.md`) in the header format the runbook gives, including what `/skills` (Codex) and the `/` menu (Claude Code) show, and the hook trust state.
- [ ] **Step 6 (human — statuses from the VS Code records):** apply the Step 1 rule to the two new records (or ask an agent session to apply it), add them to the `## Smoke records` and `## Status changes made from smoke evidence` lists in `stage2-acceptance.md`, and update `## Stage 3 inputs` to the cells still `partial` or `untested`.
- [ ] **Step 7 (human — acceptance table):** for each row of the evidence table in `docs/host-parity/stage2-acceptance.md`, check the cited records (and, for "Honest handoffs and status", run `feature-status` in the `EF-GATE` fixture before its re-run) and write `met` or `not met — <why>` in the Claude Code and Codex cells. Every `not met` row either blocks the merge or is moved to `## Stage 3 inputs` with your reason.
- [ ] **Step 8 (human — cross-host review):** in a fresh Claude Code session on this branch, run `/cogniva-dev:feature-check review` over the sub-plan 07–09 commits (from the first commit of sub-plan 07 to the last commit of sub-plan 09; `git log --oneline` shows them in order). Resolve each finding (fix, or record why not) and list them under `## Cross-host review` in `stage2-acceptance.md`.
- [ ] **Step 9 (human — version bumps):** per `AGENTS.md` `## Rules`: bump **cogniva-dev** by a **minor** version (Stage 2 changes the Codex executor contract, the hooks and the lifecycle policies — a workflow change). Bump **cogniva-skills** by a **patch** version only if Stage 2 changed files under `plugins/cogniva-skills/` (`git diff --stat main...HEAD -- plugins/cogniva-skills` is non-empty) and only in wording. Each bump is THREE files that must match: `plugins/<plugin>/.claude-plugin/plugin.json`, `plugins/<plugin>/.codex-plugin/plugin.json`, and the plugin's entry in `.claude-plugin/marketplace.json`; confirm with `grep -n '"version"' plugins/<plugin>/.claude-plugin/plugin.json plugins/<plugin>/.codex-plugin/plugin.json .claude-plugin/marketplace.json`. Then run `check-host-parity.ps1` (via its `host-parity` gate entry) and the full green gate again → `GREEN-GATE-RESULT: GREEN`, and commit the bump with the updated acceptance sheet and records.
- [ ] **Step 10 (human — PR 2b):** open PR 2b from `feature/cross-host-parity` into `main` covering sub-plans 07–10, link `docs/host-parity/stage2-acceptance.md` in its description, and merge it once the table is met (or every `not met` is recorded as a Stage 3 input).
- [ ] **Step 11:** Wait for the user to confirm before any later task runs.
