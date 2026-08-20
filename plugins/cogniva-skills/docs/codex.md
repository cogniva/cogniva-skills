# Dual-host — cogniva-skills under Claude Code and OpenAI Codex

cogniva-skills is a **dual-host** plugin: the same toolkit installs and runs
both under Claude Code and under OpenAI Codex.

## Packaging

- **One `skills/` tree, two manifests** — the same convention as cogniva-dev.
  `plugins/cogniva-skills/` ships `.claude-plugin/plugin.json` (Claude Code)
  and `.codex-plugin/plugin.json` (Codex) side by side over the same
  `skills/` tree. See ADR 0029
  (`docs/adr/0029-dual-host-packaging-and-codex-overlay.md`) and
  `plugins/cogniva-dev/docs/codex.md` for the full convention.
- **No overlays.** All four skills — `glossary`, `reference`,
  `project-requirement`, `project-context` — are host-neutral
  plain-instruction skills, so no `CODEX.md` overlays exist or are needed in
  this plugin.

## Install under Codex

1. Register the marketplace hosting cogniva-skills if needed
   (`codex plugin marketplace add <owner/repo | ./path>`).
2. Install the plugin from that marketplace with the Codex CLI's `/plugins`
   command.
3. **Start a NEW Codex session.** Skills from a freshly installed plugin are
   not visible in the session that installed them.

This replaces manually copying skill folders into `~/.codex/skills`.

## Version bumps

The version lives in THREE files that must match:
`plugins/cogniva-skills/.claude-plugin/plugin.json`,
`plugins/cogniva-skills/.codex-plugin/plugin.json`, and the `cogniva-skills`
entry in the top-level `.claude-plugin/marketplace.json`.
`claude plugin validate .` does NOT catch a mismatch, so bump all three in one
commit and confirm with:

```
grep -n '"version"' plugins/cogniva-skills/.claude-plugin/plugin.json plugins/cogniva-skills/.codex-plugin/plugin.json .claude-plugin/marketplace.json
```
