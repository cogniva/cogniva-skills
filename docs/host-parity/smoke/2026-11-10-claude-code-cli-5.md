# Smoke record 2026-11-10-claude-code-cli-5
Agent host: Claude Code
Agent host version: 2.1.187 (Claude Code)
Surface: CLI
OS: Windows 11 26200
Plugin versions: cogniva-dev 0.11.0, cogniva-skills 0.8.1
Plugin source: session-local --plugin-dir C:/dev/cogniva-skills/plugins/{cogniva-dev,cogniva-skills} @ 37f8957; Gate B after-body
Date: 2026-11-10
Covers: quick-fix

## Scenarios

| Scenario | Result | Assertion output | Notes |
|---|---|---|---|
| QF-NONE | pass | SMOKE QF-NONE: PASS | exit 0; 115s; final: QF-NONE.final.txt; Workflow tool called |

## Observations

- Command: `C:\Users\canuc\AppData\Local\Microsoft\WinGet\Links\claude.exe -p --output-format stream-json --verbose --permission-mode bypassPermissions --plugin-dir C:\dev\cogniva-skills\plugins\cogniva-dev --setting-sources project,local --plugin-dir C:/dev/cogniva-skills/plugins/cogniva-skills` (prompt on stdin, run from the fixture folder); fixtures under `C:\Users\canuc\AppData\Local\Temp\cogniva-skill-context-efficiency-20261110\qf-after-claude`, outputs under `C:\Users\canuc\AppData\Local\Temp\cogniva-skill-context-efficiency-20261110\output\qf-after-claude`.
- Isolation: `--setting-sources project,local`, so user-level settings and installed plugins are not loaded; cogniva-dev comes from `--plugin-dir` only.

### Gate B read observations

- Native QF-NONE prompt/fixture/assertions and driver are unchanged. Instruction fingerprint `6d1b7abb15223a33acaa1a575c5c4d42f38bbe286a5f96ae1a1fefdafaec9d22`; both plugin builds and original-state restoration are attested in [claude-code Gate B manual record](2026-11-10-claude-code-cli-4.md). This row is real native assertion evidence, not human acceptance or a test of every commit mode.
- Full parent stream and supplemental worker-transcript.jsonl are retained under `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/output/qf-after-claude`. Worker calls are absent from the parent stream; the separate native worker log was recovered and inspected. No targeted coverage/format/commit-policy/execute-feature-entrypoint reads occur in either after worker. Before worker reads remain unobservable in the previously saved parent streams; there is no paired complete-worker comparison.
- Parent session 86a36f89-698d-456f-95c2-4b2d09d8a2c6 uses claude-opus-4-8[1m], high effort, fast off, the same two inline plugin paths. Read toolu_01KZW31S6na4i3iG7qamp5CS successfully delivers the complete COMMIT-POLICY.md (1,550 normalized source characters). Parent also reads the workflow template and HANDOFF.md, uses the real Workflow, and performs its own landing. It never reads execute-feature/SKILL.md. Recovered worker ad850b325130977e6 reads fixture code/tests and applies the tested change, without further skill-instruction reads.
- Gate A Claude parent had no observed execute-feature Flags read. The after policy read is additional observed loading, so no positive paired runtime saving is claimed. Existing snapshot/no-stage/no-commit/own-landing assertions pass. The native driver used its existing approved unattended policy; the manual scenarios in -4 use ordinary approvals.
