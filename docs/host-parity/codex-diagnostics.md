# Codex diagnostics — CrossHostParity Stage 2a

The first real runs of the cogniva-dev lifecycle skills under Codex, with
Claude Code as the baseline: evidence before redesign. Every answer below
cites what was seen - a smoke record row, a Codex session file, a payload
file, a prompt shown on screen - never what the skills or docs say should
happen. The triage at the end decides what sub-plans 07-09 change.

## Sources

- Claude Code CLI: [smoke:2026-11-04-claude-code-cli](smoke/2026-11-04-claude-code-cli.md)
- Codex CLI: separate test environment, not recorded here (no Codex CLI smoke record in this repo)
- Codex hook payloads: `plugins/cogniva-dev/tests/hooks/fixtures/codex-apply-patch.captured.json` (`_source`: documented, not captured) and `codex-shell.captured.json` (`_source`: documented, not captured)
- Codex VS Code: (record added by the human runs)
- Claude Code VS Code: (record added by the human runs)
- Codex session files: `%USERPROFILE%\.codex\sessions\<yyyy>\<mm>\<dd>\rollout-*.jsonl` (for runs on this machine; the Codex CLI runs' session files are in the separate test environment)
- Earlier observation, other repo: `cogniva-analysis` `tests/AgentDataGuard/results/codex-desktop.md` (2026-08-27, Codex 0.150.0-alpha.8) - project hooks fired in the Codex CLI after `/hooks` trust but never in the VS Code surface. Re-check on the current build; do not assume it still holds.

## CLI results

| Scenario | Claude Code CLI | Codex CLI |
|---|---|---|
| QF-NONE | pass | separate test environment, not recorded here |
| QF-FINAL | pass | separate test environment, not recorded here |
| EF-TWO | pass | separate test environment, not recorded here |
| EF-BLOCKED | pass | separate test environment, not recorded here |
| EF-GATE | pass | separate test environment, not recorded here |
| EF-GATE (resume) | pass | separate test environment, not recorded here |
| QF-STRUCT | pass | separate test environment, not recorded here |
| POLICY | pass | separate test environment, not recorded here |
| HOOKS | pass | separate test environment, not recorded here |
| INSTR | pass | separate test environment, not recorded here |

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
