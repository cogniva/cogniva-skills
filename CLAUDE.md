# CLAUDE.md

This repo is **cogniva** — Cogniva's local Claude Code plugin marketplace. It hosts shared tooling as plugins under `plugins/`; it is not an application codebase.

## Layout

- `.claude-plugin/marketplace.json` — the marketplace manifest (name: `cogniva`)
- `plugins/cogniva-skills/` — shared skills (`glossary`, `auto-doc`) + plugin template
- `plugins/repo-foundry/` — repo scaffolding toolkit (in progress; see the plan)
- `docs/glossary/README.md` — canonical glossary; use its terms and link them, e.g. [Module](docs/glossary/README.md#module)
- `docs/strategy.md` — conventions + tooling decisions (created by the repo-foundry plan)
- `docs/superpowers/specs/`, `docs/superpowers/plans/` — design specs and implementation plans

## Common tasks

- Test: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1`
- Validate plugins: `claude plugin validate .`

## Rules

- Tools, marketplaces, and authorship are branded "Cogniva" — never name artifacts after individual team members (no personal names or initials).
- Writing a markdown file under `docs/plans/`, `docs/superpowers/plans/`, or `docs/superpowers/specs/` auto-generates a self-contained HTML twin (plan-to-html hook, once repo-foundry is built). When reporting an HTML artifact, END the message with its raw `file:///` URL on its own line.
- Glossary protocol: `docs/glossary/README.md` is the shared glossary. Propose new entries before writing them (propose-then-confirm).
- Bump the plugin `version` in its `plugin.json` whenever its skills/scripts/templates change.
