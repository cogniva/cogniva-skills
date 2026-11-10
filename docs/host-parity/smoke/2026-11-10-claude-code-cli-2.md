# Smoke record 2026-11-10-claude-code-cli-2
Agent host: Claude Code
Agent host version: 2.1.187
Surface: CLI
OS: Windows 11 26200
Plugin versions: cogniva-dev 0.11.0, cogniva-skills 0.8.1
Plugin source: session-local directories C:/dev/cogniva-skills/plugins/cogniva-dev and cogniva-skills @ 9ebf453; description-only
Date: 2026-11-10
Covers: install-cogniva-dev, install-cogniva-skills, glossary

## Scenarios

| Scenario | Result | Assertion output | Notes |
|---|---|---|---|
| DISCOVERY | pass | Startup menu has all 25 target commands; probe exposes the 19 target discovery descriptions and expected request mappings; six paired explicit-only settings unchanged | Session 3d343ff1-6222-4c99-a890-e8e7c3f0a64e; actual paths are attested by startup, not guessed probe paths |
| GLOSSARY-FIRST | pass | Skill(glossary, Quorin Window) precedes glossary Read; answer 90 minutes; no implementation search | Session 79cffa05-7387-4ee6-90b6-1e1aac8b5d2b; old control also passes |
| GLOSSARY-MISSING | pass | Skill and glossary lookup precede implementation search; asks intended meaning and offers a glossary entry; no unconfirmed write | Interactive session e07c2195-9940-44aa-92b6-33536c65ce05; exited at clarification |

## Observations

- Build role: Gate A description-only. Source instruction fingerprint: `172afc6c4b4e458f12be65a0d988205704ac7a50f26d9eead555edd234792ff2`. No instruction content changed during these runs.
- Discovery and glossary-first use claude -p <prepared prompt> --output-format stream-json --verbose --permission-mode default --plugin-dir C:/dev/cogniva-skills/plugins/cogniva-dev --plugin-dir C:/dev/cogniva-skills/plugins/cogniva-skills --setting-sources project,local. Both exited 0. Startup init identifies both direct source roots and model claude-opus-4-8[1m]; high effort, fast mode off; fresh auto-memory directories were empty/absent.
- The discovery response correctly maps feature-status/backlog/project-requirement/glossary and preserves the explicit-request/approved-dispatch conditions of quick-fix/plan-feature. Its attempted guesses at ~/.claude plugin paths were permission-denied, and its self-reported path/restriction summary is not treated as ground truth. Actual source paths and the 25 command inventory come from startup metadata; the 19 source descriptions and six paired metadata settings are cross-checked against those loaded roots. The summary shortened the quoted glossary description; the source retains both sentences and the explicit search prohibition.
- Interactive missing-term launch used the same two plugin-dir flags and settings sources, no unattended/no-questions policy. The PowerShell PTY launcher exited before a session was created; an initial cmd positional prompt was truncated to a literal quoted What (session 188db75c-78c9-437b-a11d-b2d24c42458b), which was closed and excluded. A new cmd session was started without a positional prompt and the exact prepared neutral question was typed intact. The synthetic fixture trust prompt was accepted. Both launch artifacts are retained.
- Valid missing-term session invokes cogniva-skills:glossary, reads the fixture glossary, then searches/reads Window.ps1, reports the missing business definition, asks for clarification, and offers to draft an entry after the meaning is confirmed. No meaning or write confirmation was supplied; the session was closed. Fixture git state is checked separately before acceptance.
- Artifacts: `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/output/gate-a/claude-code/<scenario>/transcript.jsonl`; glossary-missing additionally has final.txt, debug-valid.log and invalid-prompt-launch.jsonl. Startup source/content matches from the separate probe apply to the identical two source roots used by the interactive session; debug logs retain their actual plugin loading.
- Closing: all these processes exited. No persistent Claude marketplace or plugin install changed; approved session/trust metadata was created under the authorized host paths.
- The operator explicitly approved Gate A host runs, Codex refresh, normal host runtime state, and separately restoration of the captured original Codex state. This record is real-run evidence, not human acceptance; Gate A remains pending.
- Fixtures are separate external repositories with no remotes, no fixture AGENTS.md/CLAUDE.md, and no ancestor instruction files. The inspected global instruction files contain external-write and commit-default rules, no glossary-first protocol. No glossary behavior session was given a discovery/build-attestation prompt before its neutral question.
- Scenario names in visible cwd paths include glossary-first/glossary-missing; this contextual cue is an attribution limitation. The old/new glossary-first pairs use the same prompt, equivalent neutral raw inputs, host/model/effort/permission settings and scenario naming, with separate pristine directories. Results establish these observed cases, not universal unaided routing reliability.
- Raw transcripts and runtime state stay in the approved external output tree; only bounded summaries are tracked. No definition write was approved in either missing-term session.
