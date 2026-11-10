# Smoke record 2026-11-10-claude-code-cli-3
Agent host: Claude Code
Agent host version: 2.1.187 (Claude Code)
Surface: CLI
OS: Windows 11 26200
Plugin versions: cogniva-dev 0.11.0, cogniva-skills 0.8.1
Plugin source: session-local --plugin-dir C:/dev/cogniva-skills/plugins/{cogniva-dev,cogniva-skills} @ 9ebf453; description-only
Date: 2026-11-10
Covers: quick-fix

## Scenarios

| Scenario | Result | Assertion output | Notes |
|---|---|---|---|
| QF-NONE | pass | SMOKE QF-NONE: PASS | exit 0; 117s; final: QF-NONE.final.txt; Workflow tool called |
| BACKLOG-DIRECT | not-run | Both capture attempts stopped at host permission denials; existing dirty note preserved; no ledger write or commit | Diagnostic before observation; duplicate not attempted because capture was incomplete |
| REQUIREMENTS-READ | fail | View/status output correct, mutation proposals ask confirmation; all attempted format reads were denied | Read failure retained; no measured full-file baseline; no requirements writes |

## Observations

- Command: `C:\Users\canuc\AppData\Local\Microsoft\WinGet\Links\claude.exe -p --output-format stream-json --verbose --permission-mode bypassPermissions --plugin-dir C:\dev\cogniva-skills\plugins\cogniva-dev --setting-sources project,local --plugin-dir C:/dev/cogniva-skills/plugins/cogniva-skills` (prompt on stdin, run from the fixture folder); fixtures under `C:\Users\canuc\AppData\Local\Temp\cogniva-skill-context-efficiency-20261110\qf-before-claude`, outputs under `C:\Users\canuc\AppData\Local\Temp\cogniva-skill-context-efficiency-20261110\output\qf-before-claude`.
- Isolation: `--setting-sources project,local`, so user-level settings and installed plugins are not loaded; cogniva-dev comes from `--plugin-dir` only.

- BEFORE-READ diagnostics (non-blocking): the scenario rows above preserve the host permission limits; they are not Gate A acceptance checks. This mixed record contains a failed diagnostic and does not justify verified parity, even though native QF-NONE passed.
- Both backlog sessions loaded the direct skill and inspected their fixture ledger, but BACKLOG-FORMAT.md reads and Edit/Bash operations were permission-denied under default headless mode. They explicitly offered because:human later; the dirty-target session stated it would preserve the operator note and leave that ledger uncommitted. The fixtures confirm no new commits or writes. No CAPTURE-BAR.md read was observed in these direct sessions; no coverage-saving measurement is established.
- Requirements view/status/add/refine each attempted REQUIREMENTS-FORMAT.md; every such read was denied. View/status still reported the two seeded records correctly; add/refine returned draft/overlap proposals and sought confirmation. No confirmation was supplied and all four requirement fixtures stayed clean. Read extent: failed/none delivered, not 9,951 characters loaded; no measured savings claimed.
- Native QF-NONE: all assertions pass. The complete saved parent stream has no observed execute-feature/SKILL.md or Flags read; Workflow was called and the implementation passed. Worker tool calls are absent from this capture (zero non-null parent_tool_use_id events), so downstream instruction reads are unobservable. This is not proof that the full entrypoint was avoided everywhere, and it cannot establish a positive before/after read saving.
- QF startup init attests both checkout plugin roots. Description-only instruction fingerprint 172afc6c4b4e458f12be65a0d988205704ac7a50f26d9eead555edd234792ff2 remained stable. Normal QF harness permission mode and prompt/assertions were unchanged. Lifecycle fixture instructions are confined to QF-NONE and were not copied into glossary checks.
- Raw artifacts: C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/output/gate-a/claude-code/<scenario>/transcript.jsonl and transcript.final.txt; requirements-view uses its captured result event. QF artifacts remain under output/qf-before-claude/ with the native QF-NONE names. All processes ended; no persistent Claude marketplace or plugin install changed.
