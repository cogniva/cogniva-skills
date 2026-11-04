# Smoke record 2026-11-04-claude-code-cli
Agent host: Claude Code
Agent host version: 2.1.187 (Claude Code)
Surface: CLI
OS: Windows 11 26200
Plugin versions: cogniva-dev 0.10.1, cogniva-skills 0.8.1
Plugin source: local marketplace from C:\dev\cogniva-skills @ 0b80e7f (--plugin-dir C:\dev\cogniva-skills\plugins\cogniva-dev)
Date: 2026-11-04
Covers: none

## Scenarios

| Scenario | Result | Assertion output | Notes |
|---|---|---|---|
| QF-NONE | pass | SMOKE QF-NONE: PASS | exit 0; 131s; final: QF-NONE.final.txt; Workflow tool called |
| QF-FINAL | pass | SMOKE QF-FINAL: PASS | exit 0; 362s; final: QF-FINAL.final.txt; Workflow tool called |
| EF-TWO | pass | SMOKE EF-TWO: PASS | exit 0; 164s; final: EF-TWO.final.txt; Workflow tool called |
| EF-BLOCKED | pass | SMOKE EF-BLOCKED: PASS | exit 0; 78s; final: EF-BLOCKED.final.txt; Workflow tool called |
| EF-GATE | pass | SMOKE EF-GATE: PASS | exit 0; 145s; final: EF-GATE.final.txt; Workflow tool called |
| EF-GATE (resume) | pass | SMOKE EF-GATE: PASS | exit 0; 134s; final: EF-GATE.resume.final.txt; Workflow tool called |
| QF-STRUCT | pass | SMOKE QF-STRUCT: PASS | exit 0; 631s; final: QF-STRUCT.final.txt; Workflow tool called |
| POLICY | pass | SMOKE POLICY: PASS | exit 0; 24s; final: POLICY.final.txt; no Workflow tool call |
| HOOKS | pass | SMOKE HOOKS: PASS | exit 0; 13s; final: HOOKS.final.txt; no Workflow tool call |
| INSTR | pass | SMOKE INSTR: PASS | exit 0; 131s; final: INSTR.final.txt; Workflow tool called |

## Observations

- Command: `C:\Users\canuc\AppData\Local\Microsoft\WinGet\Links\claude.exe -p --output-format stream-json --verbose --permission-mode bypassPermissions --plugin-dir C:\dev\cogniva-skills\plugins\cogniva-dev --setting-sources project,local` (prompt on stdin, run from the fixture folder); fixtures under `C:\Users\canuc\AppData\Local\Temp\cogniva-smoke-claude-code`, outputs under `C:\Users\canuc\AppData\Local\Temp\cogniva-smoke-claude-code\out`.
- Isolation: `--setting-sources project,local`, so user-level settings and installed plugins are not loaded; cogniva-dev comes from `--plugin-dir` only.
- Baseline for the CodexDiagnostics plan: the same nine scenarios, same fixtures, run before any Codex remedy.
- Codex CLI runs (Steps 1, 4, 5 of the CodexDiagnostics plan): run by the user in a separate test environment, not recorded in this repo; this machine's Codex plugin cache held a stale 0.10.0. Payload fixtures are documented, not captured.
