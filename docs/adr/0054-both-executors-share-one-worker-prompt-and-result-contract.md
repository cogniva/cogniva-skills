# Both executors share one worker prompt and result contract

**Provenance:** Suggested by agent

The task-agent prompt is built by `scripts/new-task-prompt.ps1`, kept
identical by test to the prompt the Workflow template builds, and the result
shape is `templates/task-result.schema.json`, which the template's schema must
equal by test; the Codex loop validates every reply with
`scripts/test-task-result.ps1` and treats a malformed reply as `BLOCKED`.
Orchestration stays native to each agent host — the Workflow template under
Claude Code, the `CODEX.md` sequential loop under Codex — and the Workflow
runtime is still never emulated (ADR 0029).
