# Smoke record 2026-11-05-claude-code-cli-2
Agent host: Claude Code
Agent host version: 2.1.187 (Claude Code)
Surface: CLI
OS: Windows 11 26200
Plugin versions: cogniva-dev 0.10.2, cogniva-skills 0.8.1
Plugin source: local marketplace from C:\dev\cogniva-skills @ deb3874 (--plugin-dir C:\dev\cogniva-skills\plugins\cogniva-dev)
Date: 2026-11-05
Covers: none

## Scenarios

| Scenario | Result | Assertion output | Notes |
|---|---|---|---|
| QF-STRUCT | pass | SMOKE QF-STRUCT: PASS | exit 0; 211s; final: QF-STRUCT.final.txt; Workflow tool called |

## Observations

- Command: `C:\Users\canuc\AppData\Local\Microsoft\WinGet\Links\claude.exe -p --output-format stream-json --verbose --permission-mode bypassPermissions --plugin-dir C:\dev\cogniva-skills\plugins\cogniva-dev --setting-sources project,local` (prompt on stdin, run from the fixture folder); fixtures under `C:\Users\canuc\AppData\Local\Temp\cogniva-smoke-claude-code`, outputs under `C:\Users\canuc\AppData\Local\Temp\cogniva-smoke-claude-code\out`.
- Isolation: `--setting-sources project,local`, so user-level settings and installed plugins are not loaded; cogniva-dev comes from `--plugin-dir` only.
