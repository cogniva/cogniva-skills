# CLAUDE.md

This repo is **cogniva** — Cogniva's local Claude Code plugin marketplace. It hosts shared tooling as plugins under `plugins/`; it is not an application codebase.

## Layout

- `.claude-plugin/marketplace.json` — the marketplace manifest (name: `cogniva`)
- `plugins/cogniva-skills/` — general-purpose skills: `glossary` (terminology) and `reference` (bibliography) for any project; plugin template for new skills
- `plugins/cogniva-dev/` — development-specific skills: `auto-doc`, `backlog`, `repo-init`, `add-module`, `explore-idea`, `plan-feature`, `execute-feature`, `quick-fix`, `cleanup-work`, `cleanup-allwork`, `module-deps`, `feature-status`, `module-status`, `repo-status`, `workflow-status`; scripts, hooks, and repo scaffolding templates
- `docs/glossary/README.md` — canonical glossary; use its terms and link them, e.g. [Module](docs/glossary/README.md#module)
- `docs/strategy.md` — conventions + tooling decisions
- `docs/plans/<Module>/<Feature>/` — feature plans + `state.md` (lifecycle `Status:`); `docs/plans/<Module>/<Idea>/` with `backlog.md` + no plan is a deferred **backlog stub**; `BACKLOG.md` (repo-level and per-Module) holds loose deferred items. Capture with `backlog`; view with `feature-status`/`module-status`/`repo-status`

## Common tasks

- Validate plugins: `claude plugin validate .`

## Rules

- Tools, marketplaces, and authorship are branded "Cogniva" — never name artifacts after individual team members (no personal names or initials).
- Glossary protocol: `docs/glossary/README.md` is the shared glossary. Propose new entries before writing them (propose-then-confirm).
- Bump the plugin `version` in its `plugin.json` whenever its skills/scripts/templates change.
