# Dual-host — cogniva-skills under Claude Code and OpenAI Codex

cogniva-skills is a **dual-host** plugin: one `skills/` tree, two manifests —
`.claude-plugin/plugin.json` (Claude Code) and `.codex-plugin/plugin.json`
(Codex) side by side over the same `skills/` directory. The full convention is
recorded in ADR 0029 and `plugins/cogniva-dev/docs/codex.md`, both in the
marketplace repo (github.com/cogniva/cogniva-skills), not shipped inside this
plugin.

Every skill in this plugin is host-neutral plain instructions, so no `CODEX.md`
overlays exist here and none are needed.

## Install under Codex

1. Register the marketplace: `codex plugin marketplace add
   cogniva/cogniva-skills` (or a local clone path). Codex reads the manifest at
   `.claude-plugin/marketplace.json` as a legacy-compatible marketplace
   (verified against OpenAI's plugin docs, 2026-08-19).
2. Install cogniva-skills from that marketplace with the Codex CLI's `/plugins`
   command.
3. Start a NEW Codex session — freshly installed plugin skills are not visible
   in the session that installed them.

This replaces manually copying skill folders into a personal Codex skills
directory (`~/.codex/skills` or `.agents/skills`): installed as a plugin, the
skills update through the marketplace and the version is tracked.

Maintainers: the version-bump rule (three files, all matching) lives in the
marketplace repo's `CLAUDE.md` under `## Rules`.
