# Hooks read both hosts' edit payloads and remain best-effort

**Provenance:** Suggested by agent

The plugin hooks take their target paths from `scripts/hook-input.js`, which
reads Claude Code's `tool_input.file_path`/`notebook_path` and every path in a
Codex `apply_patch` payload, and a hook acts if any of those paths qualifies.
Hooks are a best-effort guardrail on both agent hosts — shell-mediated writes
are not seen, and Codex runs a plugin hook only after the user trusts it — so
guarantees live in the landing checks (structural check, `git diff --check`,
green gate), and the parity record states each hook's per-host limits.
