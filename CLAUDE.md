# CLAUDE.md

This repo is **cogniva** — Cogniva's local Claude Code plugin marketplace. It hosts shared tooling as plugins under `plugins/`; it is not an application codebase.

## Layout

- `.claude-plugin/marketplace.json` — the marketplace manifest (name: `cogniva`)
- `plugins/cogniva-skills/` — the single team plugin: skills (`glossary`, `auto-doc`, `repo-init`, `add-module`, `plan-to-html`, `plan-feature`, `execute-feature`, `complete-feature`, `quick-fix`, `backlog`, `feature-status`, `module-status`, `repo-status`), the plan-to-html hook, scripts, repo/glossary/HTML templates, vendored renderers, and a plugin template for new skills
- `docs/glossary/README.md` — canonical glossary; use its terms and link them, e.g. [Module](docs/glossary/README.md#module)
- `docs/strategy.md` — conventions + tooling decisions
- `docs/plans/<Module>/<Feature>/` — feature plans + `state.md` (lifecycle `Status:`); `docs/plans/<Module>/<Idea>/` with `backlog.md` + no plan is a deferred **backlog stub**; `BACKLOG.md` (repo-level and per-Module) holds loose deferred items. Capture with `backlog`; view with `feature-status`/`module-status`/`repo-status`
- `docs/superpowers/specs/`, `docs/superpowers/plans/` — design specs and implementation plans

## Common tasks

- Test: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1`
- Validate plugins: `claude plugin validate .`

## Rules

- Tools, marketplaces, and authorship are branded "Cogniva" — never name artifacts after individual team members (no personal names or initials).
- Writing a markdown file under `docs/plans/`, `docs/specs/`, `docs/superpowers/plans/`, or `docs/superpowers/specs/` auto-generates a self-contained HTML twin (plan-to-html hook). When reporting an HTML artifact, END the message with its raw `file:///` URL on its own line.
- Glossary protocol: `docs/glossary/README.md` is the shared glossary. Propose new entries before writing them (propose-then-confirm).
- Bump the plugin `version` in its `plugin.json` whenever its skills/scripts/templates change.
