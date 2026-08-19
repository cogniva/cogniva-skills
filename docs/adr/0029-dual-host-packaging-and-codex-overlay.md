# Dual-host packaging — one skills tree, two manifests; Codex backend is an instruction overlay

**Provenance:** Suggested by human

`plugins/cogniva-dev/` ships `.claude-plugin/plugin.json` and
`.codex-plugin/plugin.json` over the same `skills/` tree; skill content is never
duplicated per host. The Codex executor is a `CODEX.md` overlay beside
`execute-feature/SKILL.md` (extending the ADR 0028 overlay pattern), selected when
the Workflow tool is unavailable; Claude's Workflow JS API is never emulated under
Codex.
