# Smoke record 2026-11-10-claude-code-cli
Agent host: Claude Code
Agent host version: 2.1.187
Surface: CLI
OS: Windows 11 26200
Plugin versions: cogniva-dev 0.11.0, cogniva-skills 0.8.1
Plugin source: pinned local export from 5b9b65393b588997e502e11d540ad21b768e12fa under C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/control-5b9b653
Date: 2026-11-10
Covers: glossary

## Scenarios

| Scenario | Result | Assertion output | Notes |
|---|---|---|---|
| GLOSSARY-FIRST-PUBLISHED | pass | Skill(glossary, Quorin Window) precedes Read(docs/glossary/README.md); answer 90 minutes; no implementation search | Session 1eee8586-5aca-4968-9b14-d693417ab8ac; transcript.jsonl contains startup plugin paths and tool order |

## Observations

- Build role: pinned old-description control only; diagnostic, not evidence for the changed-description build. Instruction fingerprint: `62d3cb5ead5ded74464ade31c57eeb74b0e1974a7248a5bd4857ac382046111d`.
- Exact launch: claude -p <neutral prompt> --output-format stream-json --verbose --permission-mode default --plugin-dir <export>/plugins/cogniva-dev --plugin-dir <export>/plugins/cogniva-skills --setting-sources project,local; cwd is the approved control/claude-code/glossary-first fixture. Model claude-opus-4-8[1m], high effort, fast mode off.
- Startup init attests both exported plugin roots. All 179 export files match pinned Git contents after line-ending normalization; all 49 instruction files match the pinned fingerprint. The startup menu contains all 25 target commands. The fresh auto-memory directory is empty/absent.
- Artifacts: `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/output/control/claude-code/glossary-first/transcript.jsonl` and stderr.txt. Exit 0. Final answer and the exact neutral prompt are retained in the transcript.
- Matched description-only comparison: 2026-11-10-claude-code-cli-2 / GLOSSARY-FIRST also passes. No observed regression in this pair.
- Closing: process exited; no persistent Claude marketplace or plugin install change was used. Normal approved session state remains.
- The operator explicitly approved Gate A host runs, Codex refresh, normal host runtime state, and separately restoration of the captured original Codex state. This record is real-run evidence, not human acceptance; Gate A remains pending.
- Fixtures are separate external repositories with no remotes, no fixture AGENTS.md/CLAUDE.md, and no ancestor instruction files. The inspected global instruction files contain external-write and commit-default rules, no glossary-first protocol. No glossary behavior session was given a discovery/build-attestation prompt before its neutral question.
- Scenario names in visible cwd paths include glossary-first/glossary-missing; this contextual cue is an attribution limitation. The old/new glossary-first pairs use the same prompt, equivalent neutral raw inputs, host/model/effort/permission settings and scenario naming, with separate pristine directories. Results establish these observed cases, not universal unaided routing reliability.
- Raw transcripts and runtime state stay in the approved external output tree; only bounded summaries are tracked. No definition write was approved in either missing-term session.
