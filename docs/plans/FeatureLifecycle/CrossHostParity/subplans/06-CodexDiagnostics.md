# 06 CodexDiagnostics — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/CrossHostParity
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** The first real executions of the cogniva-dev lifecycle skills under
Codex, on the CLI and in VS Code, with Claude Code as the baseline - recorded
as smoke records, captured hook payloads and a diagnostics report, then
triaged into remedies for sub-plans 07-09 before anything is redesigned.

**Architecture:** Task 1 is automated: it uses the smoke harness from
sub-plan 05 (`plugins/cogniva-dev/tests/host-smoke/`) to run all nine
scenarios headless on both agent hosts, captures real Codex hook payloads from
a fixture-local logger hook, and commits the smoke records and payload
fixtures. Codex must actually run; nothing about Codex is inferred from
documentation. A scenario failure is a finding, not a task failure. Task 2 is
the ⛔ Stage 2a gate: the agent prepares `docs/host-parity/codex-diagnostics.md`
from the CLI results, and the human runs the VS Code scenarios, answers the
worksheet (Q1-Q8) with evidence, triages with the decision table, picks the
executor for 07-09 and merges PR 2a. Nothing here installs into the user's
Claude Code or Codex configuration: installing the branch build in Codex is a
human step outside this repo.

**Read these first:** `plugins/cogniva-dev/tests/host-smoke/README.md` (the
runbook), `plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1`,
`plugins/cogniva-dev/skills/execute-feature/CODEX.md`,
`plugins/cogniva-dev/skills/execute-feature/HANDOFF.md`,
`plugins/cogniva-dev/hooks/hooks.json`, `docs/host-parity.md`,
`docs/plans/FeatureLifecycle/CrossHostParity/CrossHostParity-plan.md`
(unresolved decisions 1 and 2, the PR table).

## File structure (locked)

```
docs/host-parity/smoke/<YYYY-MM-DD>-claude-code-cli[-N].md          # Claude Code CLI baseline record (written by the driver)
docs/host-parity/smoke/<YYYY-MM-DD>-codex-cli[-N].md                # Codex CLI record (written by the driver)
plugins/cogniva-dev/tests/hooks/fixtures/codex-apply-patch.captured.json  # a real (or documented-shape) Codex apply_patch hook payload
plugins/cogniva-dev/tests/hooks/fixtures/codex-shell.captured.json        # a real (or documented-shape) Codex shell hook payload
plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1          # modified ONLY if --help shows a renamed flag
docs/host-parity/codex-diagnostics.md                               # diagnostics report: CLI results, worksheet, decision table, triage
docs/host-parity/smoke/<YYYY-MM-DD>-codex-vscode.md                 # human: Codex VS Code record
docs/host-parity/smoke/<YYYY-MM-DD>-claude-code-vscode.md           # human: Claude Code VS Code spot-check record
```

## Task 1: Automated CLI runs on both agent hosts, captured hook payloads

**Files:**
- Create (by the driver): `docs/host-parity/smoke/<YYYY-MM-DD>-claude-code-cli.md`, `docs/host-parity/smoke/<YYYY-MM-DD>-codex-cli.md` (`-2`, `-3` if a record of that name exists)
- Create: `plugins/cogniva-dev/tests/hooks/fixtures/codex-apply-patch.captured.json`, `plugins/cogniva-dev/tests/hooks/fixtures/codex-shell.captured.json`
- Modify (only if Step 2 finds a renamed flag): `plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1`

Rules for this task: run everything from the repo root in PowerShell 7. Never
write to `~/.codex`, `~/.claude` or any other path outside this repo and the
temp fixture folders (no `codex plugin` install commands, no config edits);
if a step needs that, return BLOCKED and say so. Each real driver run spends
model tokens and can take tens of minutes: run each driver command as a
background command and wait for it to finish (or use the longest timeout your
shell tool allows). This task returns DONE when the harness ran, whatever the
scenarios' results: a failing scenario is a finding for Task 2, not a reason
to retry, change skills or stop. It returns BLOCKED only for Step 1, or when
the driver exits 2 (a harness or usage error) for a reason you cannot fix
inside `invoke-host-smoke.ps1`. Code below is indented two spaces to sit
inside its step.

- [x] **Step 1 (the branch build must be installed in Codex):** _(satisfied elsewhere: the user ran the Codex steps in a separate test environment; not run on this machine.)_ run this PowerShell 7 code from the repo root:
  ```powershell
  $cacheRoot = Join-Path $env:USERPROFILE '.codex\plugins\cache\cogniva\cogniva-dev'
  $latest = @(Get-ChildItem -LiteralPath $cacheRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d+(\.\d+){1,3}\z' } | Sort-Object { [version]$_.Name }) | Select-Object -Last 1
  $probe = @('skills/execute-feature/SKILL.md', 'skills/execute-feature/CODEX.md', 'skills/quick-fix/SKILL.md', 'hooks/hooks.json', 'tests/host-smoke/scenarios/QF-NONE/scenario.json')
  $stale = @(foreach ($f in $probe) {
      $mine = Join-Path (Get-Location) "plugins/cogniva-dev/$f"
      $cached = if ($latest) { Join-Path $latest.FullName $f } else { $null }
      if (-not $cached -or -not (Test-Path -LiteralPath $cached)) { "$f (not in the Codex plugin cache)"; continue }
      if ([System.IO.File]::ReadAllText($mine).Replace("`r`n", "`n") -cne [System.IO.File]::ReadAllText($cached).Replace("`r`n", "`n")) { "$f (differs from the checkout)" }
  })
  if ($stale.Count) { "CODEX BRANCH BUILD: MISSING - $($stale -join '; ')" } else { "CODEX BRANCH BUILD: OK - cogniva-dev $($latest.Name) in $cacheRoot" }
  ```
  `CODEX BRANCH BUILD: OK - ...` → continue. `CODEX BRANCH BUILD: MISSING - ...` → stop now, change nothing, and return BLOCKED with the note: `install the branch build in Codex first: see plugins/cogniva-dev/tests/host-smoke/README.md ("Installing the branch build", Codex), then start a new Codex session and re-run this task` followed by the MISSING line. (Installing writes the user's Codex configuration, outside this repo: that is the human's step.)
- [x] **Step 2 (verify the agent hosts' flags):** `claude --version` and `claude --help`; confirm the help lists `--print`/`-p`, `--output-format` (with `stream-json`), `--verbose`, `--permission-mode` (with `bypassPermissions`), `--plugin-dir` and `--setting-sources`. Then `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost codex -Scenario QF-NONE -DryRun` and take the `codex.exe` path from its `COMMAND:` line; confirm that file exists, run `<that path> --version` and `<that path> exec --help`, and confirm the help lists `--json`, `-s, --sandbox` (with `workspace-write`), `-C, --cd`, `-o, --output-last-message`, `--dangerously-bypass-hook-trust`, and that a `-` prompt is read from stdin. If a flag is missing or renamed, change only `Get-AgentCommand` in `plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1` to the flag the help shows, re-run `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1` (update the matching `DryRun` check to the new flag text in the same edit) until `All smoke-assertions assertions passed.`, and note the change for Step 7. The driver writes the flags it used into each record's `- Command:` line.
- [x] **Step 3 (Claude Code baseline, all scenarios):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost claude-code -Scenario all -PluginDir plugins/cogniva-dev` → ten `SMOKE-RUN <ID>: pass|fail|not-run` lines (EF-GATE twice) and `RECORD: <path>`; exit 0 or 1 both mean the harness ran. If one command cannot run that long in your environment, run the scenarios one at a time instead: `-Scenario QF-NONE` first (it prints `RECORD: <path>`), then `-Scenario <ID> -RecordPath <that path>` for QF-FINAL, EF-TWO, EF-BLOCKED, EF-GATE, then `-Scenario EF-GATE -Resume -RecordPath <that path>`, then QF-STRUCT, POLICY, HOOKS, INSTR - each with `-PluginDir plugins/cogniva-dev`. Open the record and check that it has the nine header lines, ten scenario rows, and an `Isolation:` observation.
- [x] **Step 4 (Codex, all scenarios):** _(skipped by the user: run in a separate test environment, not recorded here.)_ `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost codex -Scenario all -PluginSource "local marketplace from $((Get-Location).Path) @ $(git rev-parse --short HEAD)"` → ten `SMOKE-RUN` lines and `RECORD: <path>` (same one-at-a-time fallback as Step 3, with the same `-PluginSource`). Do not add `--dangerously-bypass-hook-trust` or any other flag here: this run records the trust and approval behaviour a user gets.
- [x] **Step 5 (capture Codex hook payloads):** _(skipped by the user: no payloads captured here; Step 6 wrote the documented shapes.)_ build a separate HOOKS fixture with a fixture-local logger hook (it saves every PreToolUse payload to `.smoke/payloads/` and always allows; its command is unquoted, so the path must have no spaces) by running this PowerShell 7 code from the repo root:
  ```powershell
  $payRoot = Join-Path $env:TEMP 'cogniva-smoke-payloads'
  $fixture = Join-Path $payRoot 'HOOKS'
  if ($fixture -match '\s') { throw "the payload fixture path must not contain spaces (the hook command is unquoted): $fixture" }
  if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
  pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/new-smoke-fixture.ps1 -Path $fixture -Scenario HOOKS
  $logger = @'
  // Smoke-only payload logger: saves each hook payload (stdin) under .smoke/payloads/ and always allows.
  const fs = require('fs');
  const path = require('path');
  let raw = '';
  process.stdin.on('data', d => (raw += d)).on('end', () => {
    try {
      const dir = path.join(__dirname, 'payloads');
      fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(path.join(dir, `${Date.now()}-${process.pid}.json`), raw);
    } catch (e) { /* never block a tool call */ }
    process.exit(0);
  });
  '@
  [System.IO.File]::WriteAllText((Join-Path $fixture '.smoke\log-payload.js'), $logger)
  New-Item -ItemType Directory -Path (Join-Path $fixture '.codex') -Force | Out-Null
  $command = 'node ' + $fixture.Replace('\', '/') + '/.smoke/log-payload.js'
  $hooks = [ordered]@{ hooks = [ordered]@{ PreToolUse = @([ordered]@{ matcher = '.*'; hooks = @([ordered]@{ type = 'command'; command = $command; timeout = 10 }) }) } }
  [System.IO.File]::WriteAllText((Join-Path $fixture '.codex\hooks.json'), ($hooks | ConvertTo-Json -Depth 10))
  "LOGGER HOOK: $command"
  ```
  Then run Codex on it: `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost codex -Scenario HOOKS -Resume -FixtureRoot "$env:TEMP\cogniva-smoke-payloads" -NoRecord`, and count the payloads: `@(Get-ChildItem "$env:TEMP\cogniva-smoke-payloads\HOOKS\.smoke\payloads" -Filter *.json -ErrorAction SilentlyContinue).Count`. If the count is 0 (the project or the hook is not trusted in `exec` mode), run the same command once more with `-ExtraArgs '--dangerously-bypass-hook-trust'` and count again. That flag is acceptable only here: the fixture is a throwaway temp repo and the only project hook is the logger above. Write down, for Step 7: the count without the flag, the count with it (if run), and the `tool_name` values seen.
- [x] **Step 6 (write the payload fixtures):** run this PowerShell 7 code from the repo root. It takes the first `apply_patch` payload and the first shell payload (`Bash`, `shell`, `local_shell`, `exec_command` or `unified_exec`), replaces the fixture path with `C:/fixture` and the user profile path with `C:/Users/user` in every spelling, adds a top-level `_source`, and writes the two files; a kind with no captured payload gets the documented shape with `"_source": "documented, not captured"`:
  ```powershell
  $fixture = Join-Path $env:TEMP 'cogniva-smoke-payloads\HOOKS'
  $outDir = 'plugins/cogniva-dev/tests/hooks/fixtures'
  New-Item -ItemType Directory -Path $outDir -Force | Out-Null
  $ext = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE '.vscode\extensions') -Directory -Filter 'openai.chatgpt-*-win32-x64' | Sort-Object { [version](($_.Name -replace '^openai\.chatgpt-', '') -replace '-win32-x64\z', '') } | Select-Object -Last 1
  $codexVersion = [string](& (Join-Path $ext.FullName 'bin\windows-x86_64\codex.exe') --version | Select-Object -First 1)
  $payloads = @(Get-ChildItem -LiteralPath (Join-Path $fixture '.smoke\payloads') -Filter '*.json' -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
      $data = $null
      try { $data = [System.IO.File]::ReadAllText($_.FullName) | ConvertFrom-Json -AsHashtable } catch { $data = $null }
      if ($data) { [pscustomobject]@{ Name = $_.Name; Data = $data } }
  })
  "PAYLOADS: $($payloads.Count); tool names: $((@($payloads | ForEach-Object { $_.Data['tool_name'] }) | Select-Object -Unique) -join ', ')"
  # Absolute fixture and user paths become C:/fixture and C:/Users/user, in every spelling a payload may use.
  function Protect-Payload([System.Collections.IDictionary]$Data, [string]$Source) {
      $ordered = [ordered]@{ _source = $Source }
      foreach ($k in $Data.Keys) { $ordered[$k] = $Data[$k] }
      $text = $ordered | ConvertTo-Json -Depth 50
      foreach ($pair in @(@($fixture, 'C:/fixture'), @($env:USERPROFILE, 'C:/Users/user'))) {
          foreach ($form in @($pair[0].Replace('\', '\\'), $pair[0].Replace('\', '/'), $pair[0])) {
              $text = [regex]::Replace($text, [regex]::Escape($form), $pair[1], 'IgnoreCase')
          }
      }
      return $text + "`n"
  }
  $documented = @{
      'codex-apply-patch.captured.json' = @'
  {
    "_source": "documented, not captured",
    "session_id": "00000000-0000-0000-0000-000000000000",
    "turn_id": "00000000-0000-0000-0000-000000000001",
    "transcript_path": "C:/Users/user/.codex/sessions/rollout.jsonl",
    "cwd": "C:/fixture",
    "hook_event_name": "PreToolUse",
    "model": "model",
    "permission_mode": "default",
    "tool_name": "apply_patch",
    "tool_input": {
      "command": "*** Begin Patch\n*** Update File: src/Calc/Calc.ps1\n@@\n     return $a + $b\n }\n+# hooks-probe\n*** Add File: src/Calc/Probe.ps1\n+# canary-7\n*** End Patch\n"
    }
  }
  '@
      'codex-shell.captured.json' = @'
  {
    "_source": "documented, not captured",
    "session_id": "00000000-0000-0000-0000-000000000000",
    "turn_id": "00000000-0000-0000-0000-000000000002",
    "transcript_path": "C:/Users/user/.codex/sessions/rollout.jsonl",
    "cwd": "C:/fixture",
    "hook_event_name": "PreToolUse",
    "model": "model",
    "permission_mode": "default",
    "tool_name": "Bash",
    "tool_input": {
      "command": "git status --short"
    }
  }
  '@
  }
  $picks = [ordered]@{
      'codex-apply-patch.captured.json' = ($payloads | Where-Object { $_.Data['tool_name'] -eq 'apply_patch' } | Select-Object -First 1)
      'codex-shell.captured.json' = ($payloads | Where-Object { @('Bash', 'shell', 'local_shell', 'exec_command', 'unified_exec') -contains $_.Data['tool_name'] } | Select-Object -First 1)
  }
  foreach ($name in $picks.Keys) {
      $target = Join-Path $outDir $name
      $pick = $picks[$name]
      if ($pick) {
          [System.IO.File]::WriteAllText($target, (Protect-Payload $pick.Data "captured $(Get-Date -Format 'yyyy-MM-dd') by $codexVersion exec in the HOOKS fixture ($($pick.Name))"))
          "$($name): captured"
      }
      else {
          [System.IO.File]::WriteAllText($target, $documented[$name].Replace("`r`n", "`n") + "`n")
          "$($name): documented, not captured"
      }
  }
  ```
  → `PAYLOADS: <n>; tool names: ...`, then one `captured` or `documented, not captured` line per file. Open both files and confirm no `canuc`, no user name and no absolute path other than `C:/fixture` / `C:/Users/user` remains.
- [x] **Step 7 (observations):** append these bullets at the end of the Codex record's `## Observations` section, filled in from what you saw:
  ```
  - Branch build: `CODEX BRANCH BUILD: OK - cogniva-dev <version> in <cache path>` (Step 1 of the CodexDiagnostics plan).
  - Hook payload capture (separate HOOKS fixture with a project `.codex/hooks.json` logger): <n> payload(s) without --dangerously-bypass-hook-trust; <n, or "not run"> with it; tool names seen: <list or "none">. Fixture files: codex-apply-patch.captured.json = <captured | documented, not captured>, codex-shell.captured.json = <captured | documented, not captured>.
  - Flags: <"as in the Command line above" or the flag changes made in Step 2>.
  ```
  and this bullet at the end of the Claude Code record's `## Observations`: `- Baseline for the CodexDiagnostics plan: the same nine scenarios, same fixtures, run before any Codex remedy.`
- [x] **Step 8 (checks):** `pwsh -NoProfile -File scripts/check-host-parity.ps1` → exit 0 (the new records are not cited by any row yet; if it rejects a record's header or its `Covers: none`, set that record's `Covers:` line to the parity-record row IDs whose `Covers` cell includes `skill:cogniva-dev/quick-fix`, `skill:cogniva-dev/execute-feature` or `hook:guard-primary-edit.js`, comma-separated, and re-run). Then `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → `green-gate: GREEN - all N command(s) exited 0.`
- [x] **Step 9 (commit):** `git add docs/host-parity/smoke plugins/cogniva-dev/tests/hooks/fixtures/codex-apply-patch.captured.json plugins/cogniva-dev/tests/hooks/fixtures/codex-shell.captured.json plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1` then `git commit -m "test(host-smoke): first Claude Code and Codex CLI smoke runs and captured Codex hook payloads"`. In the task summary, list each scenario's result per agent host (from the two records) and both payload files' `_source`.

## ⛔ Task 2: VS Code runs, diagnostics report and triage  (manual validation gate — execute-feature STOPS here)

**Files:**
- Create: `docs/host-parity/codex-diagnostics.md`
- Create (human): `docs/host-parity/smoke/<YYYY-MM-DD>-codex-vscode.md`, `docs/host-parity/smoke/<YYYY-MM-DD>-claude-code-vscode.md`

A stop at this gate skips the executor's landing, so this task runs the full
green gate itself.

- [ ] **Step 1 (run the full green gate):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → `green-gate: GREEN - all N command(s) exited 0.`
- [ ] **Step 2 (prepare the report):** create `docs/host-parity/codex-diagnostics.md` with exactly the content inside the four-backtick fence (indented two spaces here; the file has no indent), then fill it in as described after the block:
  ````markdown
  # Codex diagnostics — CrossHostParity Stage 2a

  The first real runs of the cogniva-dev lifecycle skills under Codex, with
  Claude Code as the baseline: evidence before redesign. Every answer below
  cites what was seen - a smoke record row, a Codex session file, a payload
  file, a prompt shown on screen - never what the skills or docs say should
  happen. The triage at the end decides what sub-plans 07-09 change.

  ## Sources

  - Claude Code CLI: CLAUDE_RECORD
  - Codex CLI: CODEX_RECORD
  - Codex hook payloads: `plugins/cogniva-dev/tests/hooks/fixtures/codex-apply-patch.captured.json` (`_source`: PATCH_SOURCE) and `codex-shell.captured.json` (`_source`: SHELL_SOURCE)
  - Codex VS Code: (record added by the human runs)
  - Claude Code VS Code: (record added by the human runs)
  - Codex session files: `%USERPROFILE%\.codex\sessions\<yyyy>\<mm>\<dd>\rollout-*.jsonl`
  - Earlier observation, other repo: `cogniva-analysis` `tests/AgentDataGuard/results/codex-desktop.md` (2026-08-27, Codex 0.150.0-alpha.8) - project hooks fired in the Codex CLI after `/hooks` trust but never in the VS Code surface. Re-check on the current build; do not assume it still holds.

  ## CLI results

  | Scenario | Claude Code CLI | Codex CLI |
  |---|---|---|
  | QF-NONE | | |
  | QF-FINAL | | |
  | EF-TWO | | |
  | EF-BLOCKED | | |
  | EF-GATE | | |
  | EF-GATE (resume) | | |
  | QF-STRUCT | | |
  | POLICY | | |
  | HOOKS | | |
  | INSTR | | |

  ## Worksheet

  Answer each question for every surface you ran, each with its evidence
  (record row, session file and line, payload file, what the screen showed).
  "Not run" is an answer; a guess is not.

  ### Q1 — One fresh subagent per task, in order
  Did execute-feature and quick-fix spawn one subagent per task, sequentially,
  from the skill? In the VS Code surface, watch for "collaboration tools cannot
  be called from inside functions.exec".
  - Codex CLI:
  - Codex VS Code:
  - Claude Code VS Code:

  ### Q2 — Workers start without the parent conversation
  Did the INSTR canary appear in the file the worker created? Did a worker know
  anything only the parent conversation knew?
  - Codex CLI:
  - Codex VS Code:
  - Claude Code VS Code:

  ### Q3 — `.git` writes under the sandbox
  Did quick-fix's `-Snapshot` (`git write-tree`), the `.git/info/exclude`
  append (`plan=ephemeral`) and the commits succeed, ask for approval, or fail?
  - Codex CLI:
  - Codex VS Code:

  ### Q4 — Hooks fire for `apply_patch` and shell, after trust
  Did the plugin hooks run for an `apply_patch` edit and for a shell command,
  after trust? What exact payload arrived?
  - Codex CLI:
  - Codex VS Code:

  ### Q5 — Root and nested AGENTS.md
  Were the root and the nested `AGENTS.md` rules applied by the main agent and
  by the workers?
  - Codex CLI:
  - Codex VS Code:
  - Claude Code VS Code:

  ### Q6 — Approval prompts
  How many approval prompts per run, and for which commands?
  - Codex CLI:
  - Codex VS Code:
  - Claude Code VS Code:

  ### Q7 — CLI and VS Code differences
  Anything that behaved differently between the CLI and VS Code?
  - Codex:
  - Claude Code:

  ### Q8 — Handoff completeness
  Did each handoff contain every `HANDOFF.md` section?
  - Codex CLI:
  - Codex VS Code:
  - Claude Code VS Code:

  ## Decision table

  | Finding | Remedy | Where |
  |---|---|---|
  | Sequential fresh subagents work on VS Code and CLI | none | — |
  | Subagents unavailable/unreliable on VS Code, work on CLI | CODEX.md: CLI recommended for execution; inline fallback allowed, handoff states "executed inline — no fresh task context"; parity record `partial` for VS Code | sub-plan 07 (Task on CODEX.md) |
  | Workers inherit the parent conversation | CODEX.md: spawn without inherited history where the agent host offers the option; otherwise record `partial` with the reason | 07 |
  | `.git` read-only blocks snapshot/commit/exclude | docs/codex.md: document the needed approval or writable-`.git` setting; quick-fix Step 0 failure message names it; if commits=none runs cannot work at all → STOP and plan a follow-up with plan-feature before continuing | 09 (docs + message) or new plan |
  | Hook payload differs from documented shape | 08 adapts to the captured payload fixture | 08 |
  | Hooks never fire on a surface | parity record `partial` naming the surface; docs | 08 |
  | Anything else that blocks a lean scenario | STOP: plan a follow-up with plan-feature; do not continue to 07 until the user decides | — |

  ## Triage

  | Finding (question) | Decision-table row | Remedy | Where |
  |---|---|---|---|

  - Executor for sub-plans 07-09:
  - Unresolved decision 1 (VS Code subagents) settled as:
  - Stop for a follow-up plan:
  ````
  Fill-in: find the two CLI records Task 1 committed (`git log -1 --name-only --format= -- docs/host-parity/smoke` lists them; the `-claude-code-cli` and `-codex-cli` files). Replace `CLAUDE_RECORD` and `CODEX_RECORD` with links of the form `[smoke:<record-id>](smoke/<record-id>.md)`; replace `PATCH_SOURCE` and `SHELL_SOURCE` with the `_source` values of the two payload files. In `## CLI results`, fill each cell with that scenario's `Result` from the record (`pass`, `fail` or `not-run`), and for `fail` add the first `FAIL <key>` from its assertion output in parentheses, e.g. `fail (FAIL commitsSinceStart)`. Leave the worksheet answers and the triage empty.
- [ ] **Step 3 (commit the prepared report):** `git add docs/host-parity/codex-diagnostics.md` then `git commit -m "docs(host-parity): Codex diagnostics report, prepared from the CLI runs"`
- [ ] **Step 4 (human - VS Code with Codex):** install the branch build for Codex and open VS Code with the Codex extension (the team's primary surface), following `plugins/cogniva-dev/tests/host-smoke/README.md` ("Installing the branch build", then "GUI procedure"). Run QF-NONE, QF-FINAL, EF-TWO, EF-GATE and its second run, QF-STRUCT, HOOKS and INSTR, each in a fresh fixture and a new window, pasting the `$` invocation that `invoke-host-smoke.ps1 -AgentHost codex -Scenario <ID> -DryRun` prints. For HOOKS, first trust the cogniva-dev hooks (`/hooks` in the Codex CLI if the extension offers no trust prompt) and say in the record which surface showed which trust prompt. Count every approval prompt and note which command it was for. Check each run with `assert-smoke-outcome.ps1` and write the record `docs/host-parity/smoke/<YYYY-MM-DD>-codex-vscode.md` with the header lines from the README (`Surface: VS Code`, `Covers: none`).
- [ ] **Step 5 (human - VS Code with Claude Code, spot check):** with the branch build installed in Claude Code (README, "Installing the branch build", Claude Code, VS Code), run QF-NONE and EF-GATE (both runs) the same way, pasting the `/cogniva-dev:` invocation, and write `docs/host-parity/smoke/<YYYY-MM-DD>-claude-code-vscode.md` (`Surface: VS Code`, `Covers: none`).
- [ ] **Step 6 (human - optional payload capture through the CLI TUI):** if either payload file says `documented, not captured`: rebuild the payload fixture with the Step 5 code of Task 1 (README, or ask the agent to re-run that step), `cd` into `%TEMP%\cogniva-smoke-payloads\HOOKS`, start the bundled `codex.exe` without arguments, trust the project and the logger hook with `/hooks`, and paste the HOOKS prompt (from `invoke-host-smoke.ps1 -AgentHost codex -Scenario HOOKS -DryRun`). If `.smoke\payloads\` now has files, ask the agent to re-run Task 1 Step 6 so the fixtures say `captured`, and commit them.
- [ ] **Step 7 (human - answer the worksheet):** in `docs/host-parity/codex-diagnostics.md`, add the two VS Code records to `## Sources` and answer every question for every surface you ran, each with its evidence: Q1 did execute-feature/quick-fix spawn one subagent per task, sequentially, from the skill (VS Code code-mode surface: "collaboration tools cannot be called from inside functions.exec")? Q2 did workers start without the parent conversation (INSTR canary in the worker-created file? did the worker know things only the parent knew)? Q3 `.git` writes under the sandbox: did quick-fix's `-Snapshot` (`git write-tree`), the `.git/info/exclude` append (`plan=ephemeral`) and the commits succeed, prompt for approval, or fail? Q4 did hooks fire for `apply_patch` and shell, after trust, and with what exact payload? Q5 were root and nested AGENTS.md rules applied by the main agent and by workers? Q6 how many approval prompts per run, for which commands? Q7 any CLI vs VS Code difference? Q8 did each handoff contain every HANDOFF.md section? Evidence lives in the smoke records, the fixtures' `.smoke\final.txt`, the session files under `%USERPROFILE%\.codex\sessions\` (search a run's `rollout-*.jsonl` for the subagent tool calls, `apply_patch`, approval requests and hook events), and what the screen showed.
- [ ] **Step 8 (human - triage):** for each finding, pick its row in this decision table and record it in the report's `## Triage` table (finding with its question, the row, the remedy, where):

  | Finding | Remedy | Where |
  |---|---|---|
  | Sequential fresh subagents work on VS Code and CLI | none | — |
  | Subagents unavailable/unreliable on VS Code, work on CLI | CODEX.md: CLI recommended for execution; inline fallback allowed, handoff states "executed inline — no fresh task context"; parity record `partial` for VS Code | sub-plan 07 (Task on CODEX.md) |
  | Workers inherit the parent conversation | CODEX.md: spawn without inherited history where the agent host offers the option; otherwise record `partial` with the reason | 07 |
  | `.git` read-only blocks snapshot/commit/exclude | docs/codex.md: document the needed approval or writable-`.git` setting; quick-fix Step 0 failure message names it; if commits=none runs cannot work at all → STOP and plan a follow-up with plan-feature before continuing | 09 (docs + message) or new plan |
  | Hook payload differs from documented shape | 08 adapts to the captured payload fixture | 08 |
  | Hooks never fire on a surface | parity record `partial` naming the surface; docs | 08 |
  | Anything else that blocks a lean scenario | STOP: plan a follow-up with plan-feature; do not continue to 07 until the user decides | — |

  Settle the manifest's unresolved decision 1 (default (c): CLI recommended for execution under Codex, inline runs allowed and labelled) only if Q1 shows the problem, and write the outcome on the report's `Unresolved decision 1` line. If any finding lands on a STOP row, write it on the `Stop for a follow-up plan` line, plan that follow-up with plan-feature, and do not continue to sub-plan 07 until you decide.
- [ ] **Step 9 (human - executor for 07-09):** decide who executes sub-plans 07-09 and write it on the `Executor for sub-plans 07-09` line: Codex (`$execute-feature`, `commits=task`, on this branch, Claude reviewing) if Q1 shows the sequential subagent loop working; otherwise Claude Code, with the parity record keeping the Codex executor `partial`.
- [ ] **Step 10 (human - review, gate, merge PR 2a):** have Codex review sub-plan 05's fixtures and assertions in a fresh session (`plugins/cogniva-dev/tests/host-smoke/`, `plugins/cogniva-dev/tests/workflow-template/`) and resolve its findings; run `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → `green-gate: GREEN - all N command(s) exited 0.`; commit the completed report and the VS Code records (`git add docs/host-parity/codex-diagnostics.md docs/host-parity/smoke` then `git commit -m "docs(host-parity): Codex diagnostics - VS Code runs, answers and triage"`); then open and merge PR 2a (sub-plans 05-06).
- [ ] **Step 11:** Wait for the user to confirm before any later task runs.
