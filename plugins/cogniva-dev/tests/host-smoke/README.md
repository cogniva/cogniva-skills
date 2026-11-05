# Agent-host smoke harness

Runs the same small lifecycle scenarios on Claude Code and on Codex, each in a
throwaway fixture repository, and checks every outcome from git and file
state - never from the agent's own account of what it did. Results go into
smoke records under `docs/host-parity/smoke/`, the evidence that
`docs/host-parity.md` (the parity record) cites for a `verified` status.

## What it proves, and what it does not

It proves, for one agent host on one surface (CLI, VS Code or desktop) at one
plugin version, that each scenario left the expected state: the commits each
`commits=` policy allows and no others, the branch unchanged, pre-existing
uncommitted work untouched, plan checkboxes ticked or left open, the full
`READY FOR REVIEW` handoff, a blocked task or a branch-policy stop that writes
nothing, the structural check reporting an expected change, a hook denying an
edit of the primary checkout, and the repository instructions (root and nested
`AGENTS.md`) reaching the agent that writes the file.

It does not prove: that the work is good beyond the fixture's own checks; any
behaviour in a repository other than the fixture; worktree mode under Codex
(unsupported there); that hooks catch writes made through a shell command
(they do not, on either agent host); anything about a surface, agent host
version or plugin version the record does not name.

The green gate runs only the deterministic parts, with no model:
`assert-smoke-outcome.tests.ps1` (label `smoke-assertions`) proves the scenario
files, the fixture generator, every assertion key against simulated outcomes
and the driver's `-DryRun` output; `../workflow-template/workflow-template.tests.ps1`
(label `workflow-template`) runs the execute-feature Workflow template in Node
with a stubbed agent. Real runs cost model tokens and are never gated.

## Files

| File | What it does |
|---|---|
| `scenarios/<ID>/scenario.json` | The scenario: skill, arguments, branch, seeded plan, and `expect` (plus `resumeExpect` for the second EF-GATE run) |
| `scenarios/<ID>/plan.md`, `scenarios/POLICY/pasted-plan.md` | The plan a scenario seeds, or pastes into the prompt |
| `new-smoke-fixture.ps1` | `-Path <dir> -Scenario <ID>`: builds the fixture repository and records its start state in `.smoke/` |
| `assert-smoke-outcome.ps1` | `-Fixture <dir> -Scenario <ID> -FinalMessage <file> [-Resume] [-Json]`: checks the outcome; `PASS`/`FAIL` per key, then `SMOKE <ID>: PASS` or `FAIL` |
| `invoke-host-smoke.ps1` | Builds the fixture, runs one agent host headless, saves the final message and transcript, asserts, and writes the smoke record; `-DryRun` only prints |
| `assert-smoke-outcome.tests.ps1` | The gated self-test (`smoke-assertions`) |

## Scenarios

| ID | Run | What must hold |
|---|---|---|
| QF-NONE | quick-fix, `commits=none` | 0 commits; `src/Calc/Calc.ps1` and its test changed; unrelated work untouched; every handoff section |
| QF-FINAL | quick-fix, `commits=final` | exactly 1 commit, and unrelated work is not in it |
| EF-TWO | execute-feature `Smoke/TwoTasks commits=task plan=persisted` | 2 commits; both tasks ticked; every handoff section |
| EF-BLOCKED | execute-feature `Smoke/Blocked commits=task plan=persisted` | task 1 needs a file that does not exist: 0 commits, both tasks open, no new file, `BLOCKED` in the final message |
| EF-GATE | execute-feature `Smoke/Gate commits=task plan=persisted`, then the same again | first run stops after the ⛔ task 2 (2 commits, task 3 open); the second run does task 3 only (3 commits) and hands off |
| QF-STRUCT | quick-fix adding a ProjectReference under the `dotnet` profile | `STRUCTURE: FOUND` and no `dependency-added UNEXPECTED` in the final message |
| POLICY | execute-feature with a pasted plan, on `main` | stops naming `feature/`: no commit, no new file (ignored ones included), `.git/info/exclude` unchanged |
| HOOKS | a plain prompt with worktree mode on | the direct edit of the primary checkout is denied: `src/Calc/Calc.ps1` unchanged |
| INSTR | quick-fix creating `src/Calc/Divide.ps1` | the new file starts with `# canary-7` (root `AGENTS.md`) then `# nested-canary-3` (`src/Calc/AGENTS.md`) |

Every scenario also checks the branch and that `notes/unrelated.txt` (dirty
before the run) keeps its content and is in no new commit. The fixture's
`AGENTS.md` tells the agent the run is unattended: never wait for an answer,
go ahead with `notes/unrelated.txt` dirty, and accept a proposed plan name.

## Installing the branch build

### Claude Code

- **Headless (what the driver does):** pass
  `-PluginDir <checkout>\plugins\cogniva-dev`. The driver runs
  `claude -p --plugin-dir <dir> --setting-sources project,local`, which loads
  the checkout's plugin for that run only; user settings and installed plugins
  stay off, so an installed copy cannot shadow it.
- **VS Code:** in the Claude Code panel run
  `/plugin marketplace remove cogniva` (the published marketplace uses the same
  name), then `/plugin marketplace add <checkout>`, then
  `/plugin install cogniva-dev@cogniva` (and `cogniva-skills@cogniva`), and
  reload the window. To go back, remove it and add `cogniva/cogniva-skills`
  again.

### Codex

- There is no `codex` on PATH. The binary ships with the VS Code extension:
  `%USERPROFILE%\.vscode\extensions\openai.chatgpt-<version>-win32-x64\bin\windows-x86_64\codex.exe`
  (use the newest version folder; the driver picks it by default).
- `codex plugin marketplace remove cogniva` (the published marketplace uses
  the same name), then `codex plugin marketplace add <checkout>`, then install
  `cogniva-dev` and `cogniva-skills` from `/plugins` in a Codex session (or
  `codex plugin add cogniva-dev@cogniva`). Start a NEW session: a plugin's
  skills are not visible in the session that installed it.
- Check the install: `%USERPROFILE%\.codex\plugins\cache\cogniva\cogniva-dev\<version>\`
  holds the checkout's files.
- Hooks: Codex runs a plugin hook only after you trust it. A build whose
  `hooks/hooks.json` changed has new hook hashes, so re-trust the hooks with
  `/hooks` in the Codex CLI after installing it.
- To go back: `codex plugin marketplace remove cogniva`, then
  `codex plugin marketplace add https://github.com/cogniva/cogniva-skills.git`.

## Headless runs (CLI)

From the checkout root:

```
pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost claude-code -Scenario all -PluginDir plugins/cogniva-dev
pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost codex -Scenario all
```

- For lifecycle runs whose sandbox protects `.git`, pass
  `-CodexApproveForMe`. This selects `codex exec --approve-for-me`, which
  routes execution approval requests through automatic review. It replaces
  `--sandbox workspace-write`, so the sandbox mode comes from your Codex
  configuration or the CLI default, not from the driver. The executor and workers must request permission before
  their first Git-writing command, including the quick-fix snapshot under
  `commits=none`. A denied approval remains blocked; no Git failure is retried.
  Omit the switch to reproduce the baseline without automatic review. The
  generated record's command shows which mode was exercised. Use a fresh
  session with the branch build loaded; an installed older overlay does not
  contain the permission guidance.

- `-Scenario all` runs the nine scenarios and then EF-GATE again on the same
  fixture (the resume run). One scenario: `-Scenario QF-NONE`; its resume
  run: `-Scenario EF-GATE -Resume`.
- Each invocation starts a new record `docs/host-parity/smoke/<date>-<claude-code|codex>-cli.md`
  (`-2`, `-3` the same day) and prints `RECORD: <path>`. Pass
  `-RecordPath <that path>` to add later runs to the same record.
- Fixtures go to `$env:TEMP\cogniva-smoke-<claude-code|codex>\<ID>\` and outputs to its
  `out\` folder: `<ID>.final.txt`, `<ID>.transcript.jsonl`, `<ID>.assert.txt`.
- `-DryRun` prints, for each run, the fixture folder, the exact command and
  the prompt, and runs nothing.
- Safety: the agent runs without permission prompts (Claude Code
  `--permission-mode bypassPermissions`; Codex `exec --sandbox workspace-write`)
  only inside a fixture the driver has just built in a temp folder, with no
  remote. There is no option to point the driver at another repository.

## GUI procedure (VS Code, either agent host)

1. Build a fixture: `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/new-smoke-fixture.ps1 -Path $env:TEMP\cogniva-smoke-gui\<ID> -Scenario <ID>`.
2. Print the invocation: `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost <claude-code|codex> -Scenario <ID> -DryRun`
   and copy the text between `PROMPT:` and `END PROMPT`.
3. Open the fixture folder in a new VS Code window. Trust the folder if asked
   (note any trust or approval prompt for the record).
4. Paste the invocation into the agent panel (Claude Code: the `/cogniva-dev:`
   line; Codex: the `$` line). Answer approval prompts as a user would, and
   count them.
5. When the agent finishes, copy its final message into
   `<fixture>\.smoke\final.txt`.
6. Check it: `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.ps1 -Fixture <fixture> -Scenario <ID> -FinalMessage <fixture>\.smoke\final.txt`
   (EF-GATE second run: add `-Resume`, after pasting the same invocation
   again in the same window).
7. Add a row to the record for that agent host and surface (below), with the
   `SMOKE` line and any `FAIL` lines as the assertion output.

## Smoke records

`docs/host-parity/smoke/<YYYY-MM-DD>-<claude-code|codex>-<cli|vscode|desktop>.md`
(`-2`, `-3` if repeated the same day). The driver writes CLI records; write a
GUI record by hand with exactly these first lines:

```
# Smoke record <record-id>
Agent host: Claude Code | Codex
Agent host version: <version string>
Surface: CLI | VS Code | Desktop
OS: Windows 11 <build>
Plugin versions: cogniva-dev <x.y.z>, cogniva-skills <x.y.z>
Plugin source: <installed marketplace | local marketplace from <path> @ <short sha>>
Date: <YYYY-MM-DD>
Covers: <comma-separated parity-record row IDs this record supports>
```

then `## Scenarios` with the table
`| Scenario | Result | Assertion output | Notes |` (Result is `pass`,
`fail` or `not-run`), then `## Observations` (approval prompts, trust prompts,
surprises). `check-host-parity.ps1` counts a record toward `verified` only for
the row IDs in its `Covers:` and only if no row says `fail`; a record whose
cogniva-dev major.minor is older than the current one is reported as stale
evidence.

## Known limits

- A run that hits the timeout (`-TimeoutMinutes`, default 40) is `not-run`.
- If the agent host ends a headless run before a background Workflow
  finishes, the final message lacks the handoff and the run fails; the Notes
  cell says whether the Workflow tool was called.
- Under Codex, `.git` may be read-only in the sandbox, which stops snapshots,
  commits and `.git/info/exclude` writes; a project-local hook runs only in a
  trusted project, after `/hooks` trust.

## Cost

Every real run spends model tokens (a full `-Scenario all` is ten agent
sessions). Run the matrix at a release, and after a change to an agent host or
to the adapters between them (skill overlays, hook input parsing, the worker
contract) - not on every pull request.
