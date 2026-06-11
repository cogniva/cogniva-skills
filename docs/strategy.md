# Repo strategy

What this repo is, the conventions it encodes, and how to consume it.

## Purpose

`cogniva` is Cogniva's Claude Code plugin marketplace (repo:
github.com/cogniva/cogniva-skills). The `cogniva-skills` plugin carries shared
skills (glossary, auto-doc); the `repo-foundry` plugin packages our
repo-initialization conventions so every new repo starts identical and
improvements propagate (consuming repos reinstall/update plugins instead of
copying files).

## Conventions (canonical definitions: docs/glossary/README.md)

- .NET solutions composed of [Modules](glossary/README.md#module) - vertical
  slices, each with Contracts / Domain / Application / Infrastructure /
  optional Client / Blazor UI.
- Cross-Module communication only via [Contracts](glossary/README.md#contracts).
- [Hosts](glossary/README.md#host) choose in-process (Application) or HTTP
  (Client) per deployment; UIs are always Blazor so they run in web and WPF hosts.
- Every repo keeps a glossary at `docs/glossary/README.md` (seeded by repo-init)
  and grows it propose-then-confirm.
- Specs in `docs/superpowers/specs/`, plans in `docs/superpowers/plans/` or
  `docs/plans/`; each markdown gets a self-contained HTML twin automatically.

## Tooling inventory

| Tool | Plugin | Type | Trigger |
|---|---|---|---|
| repo-init | repo-foundry | skill | user starts a new repo |
| add-module | repo-foundry | skill | user adds a vertical slice |
| plan-to-html | repo-foundry | skill | manual conversion / hook troubleshooting |
| plan-to-html hook | repo-foundry | PostToolUse hook | any Write/Edit of watched plan/spec markdown |
| glossary | cogniva-skills | skill | unrecognized terminology (docs/glossary lookup) |
| auto-doc | cogniva-skills | skill | architectural decisions during design/planning |

## Consuming in a new repo

1. `/plugin marketplace add c:\WorkingGit\NewRepo`
2. `/plugin install repo-foundry@cogniva`
3. Run the repo-init skill.

## Maintenance

- Change skills/templates/scripts here, bump `version` in
  `plugins/repo-foundry/.claude-plugin/plugin.json`, commit; consuming repos
  pick it up via plugin update.
- Tests: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1`
  must pass before any commit to scripts or the HTML template.

## Roadmap (deliberately not yet)

- Enforce dependency rules with Roslyn analyzers or ArchUnitNET tests.
- NuGet packaging of module templates.
- pwsh (PowerShell 7) support in hook command for non-Windows teammates.
