# Smoke record 2026-11-05-claude-code-cli
Agent host: Claude Code
Agent host version: 2.1.187 (Claude Code)
Surface: CLI
OS: Windows 11 26200
Plugin versions: cogniva-dev 0.10.1, cogniva-skills 0.8.1
Plugin source: local marketplace from C:\dev\cogniva-skills @ 6e66eea (--plugin-dir C:\dev\cogniva-skills\plugins\cogniva-dev)
Date: 2026-11-05
Covers: none

## Scenarios

| Scenario | Result | Assertion output | Notes |
|---|---|---|---|
| QF-NONE | pass | SMOKE QF-NONE: PASS | exit 0; 292s; final: QF-NONE.final.txt; Workflow tool called |
| QF-FINAL | pass | SMOKE QF-FINAL: PASS | exit 0; 179s; final: QF-FINAL.final.txt; Workflow tool called |
| EF-TWO | pass | SMOKE EF-TWO: PASS | exit 0; 196s; final: EF-TWO.final.txt; Workflow tool called |
| EF-BLOCKED | pass | SMOKE EF-BLOCKED: PASS | exit 0; 80s; final: EF-BLOCKED.final.txt; Workflow tool called |
| EF-GATE | pass | SMOKE EF-GATE: PASS | exit 0; 129s; final: EF-GATE.final.txt; Workflow tool called |
| QF-STRUCT | fail | SMOKE QF-STRUCT: FAIL; FAIL finalMessageContains: missing: STRUCTURE: FOUND | exit 0; 250s; final: QF-STRUCT.final.txt; Workflow tool called |
| POLICY | pass | SMOKE POLICY: PASS | exit 0; 40s; final: POLICY.final.txt; no Workflow tool call |
| HOOKS | pass | SMOKE HOOKS: PASS | exit 0; 13s; final: HOOKS.final.txt; no Workflow tool call |
| INSTR | pass | SMOKE INSTR: PASS | exit 0; 195s; final: INSTR.final.txt; Workflow tool called |

## Observations

- Command: `C:\Users\canuc\AppData\Local\Microsoft\WinGet\Links\claude.exe -p --output-format stream-json --verbose --permission-mode bypassPermissions --plugin-dir C:\dev\cogniva-skills\plugins\cogniva-dev --setting-sources project,local` (prompt on stdin, run from the fixture folder); fixtures under `C:\Users\canuc\AppData\Local\Temp\Cogniva-CrossHostParity-session-6e66eea\claude-code`, outputs under `C:\Users\canuc\AppData\Local\Temp\Cogniva-CrossHostParity-session-6e66eea\claude-code\out`.
- Isolation: `--setting-sources project,local`, so user-level settings and installed plugins are not loaded; cogniva-dev comes from `--plugin-dir` only.
