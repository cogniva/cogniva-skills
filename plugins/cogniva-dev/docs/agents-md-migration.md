# Moving a repo's rules from CLAUDE.md to AGENTS.md

A repo whose shared rules live in `CLAUDE.md` gives them only to Claude Code;
Codex reads `AGENTS.md`. This procedure gives both agent hosts the same rules.
New repos from `repo-init` already have this arrangement, and the
cogniva-skills repo follows it for itself. It is a procedure only: the plan
that added it migrated no consuming repo.

1. **Move the shared rules.** Move every section that applies to any agent
   (conventions, layout, glossary protocol, build and test rules,
   architecture pointers) from `CLAUDE.md` into `AGENTS.md`. Where both files
   state a rule, keep one copy, in `AGENTS.md`.
2. **Reduce CLAUDE.md to the import.** Make its first line `@AGENTS.md`. Below
   it, under `## Claude Code notes`, keep only mechanics that exist for
   Claude Code alone (a `.claude/settings.json` permission, a Claude-only
   hook). With none, the file is exactly `@AGENTS.md`.
3. **Move the workflow phase blocks.** Move any `## Cogniva-dev workflow
   instructions` section, with its `### <phase>` blocks, into `AGENTS.md`. The
   resolver reads `AGENTS.md` first and falls back to `CLAUDE.md` per phase,
   so a block left behind still resolves but is easy to miss. No line inside
   a phase block may start with `#`: the resolver ends the block at any
   heading.
4. **Verify.** From the repo root, with the cogniva-dev plugin installed, run
   for each phase the repo defines:
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File "<cogniva-dev plugin>/scripts/resolve-workflow-obligations.ps1" -Repo . -Phase before-integrate
   ```
   Its first line must contain `### before-integrate from AGENTS.md`. With
   `-Format Json`, `Source` is `AGENTS.md`.
5. **Start fresh sessions** on Claude Code and on Codex. Both read
   instruction files when a session starts, so a running session keeps the
   old text.
