# Repo strategy

What this repo is, the conventions it encodes, and how to consume it.

## Purpose

`cogniva` is Cogniva's Claude Code plugin marketplace (repo:
github.com/cogniva/cogniva-skills). Its single `cogniva-skills` plugin carries
the team toolkit: shared skills (glossary, auto-doc), repo-initialization
scaffolding (repo-init, add-module), and plan-to-html conversion — so every new
repo starts identical and improvements propagate (consuming repos
reinstall/update the plugin instead of copying files).

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

All tools ship in the `cogniva-skills` plugin:

| Tool | Type | Trigger |
|---|---|---|
| repo-init | skill | user starts a new repo |
| add-module | skill | user adds a vertical slice |
| plan-to-html | skill | manual conversion / hook troubleshooting |
| plan-to-html hook | PostToolUse hook | any Write/Edit of watched plan/spec markdown |
| glossary | skill | unrecognized terminology (docs/glossary lookup) |
| auto-doc | skill | architectural decisions during design/planning |

## Consuming in a new repo

1. `/plugin marketplace add cogniva/cogniva-skills` (or the path of your local clone)
2. `/plugin install cogniva-skills@cogniva`
3. Run the repo-init skill.

## Maintenance

- Change skills/templates/scripts here, bump `version` in
  `plugins/cogniva-skills/.claude-plugin/plugin.json`, commit; consuming repos
  pick it up via plugin update.
- Tests: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1`
  must pass before any commit to scripts or the HTML template.

## Roadmap (deliberately not yet)

- Enforce dependency rules with Roslyn analyzers or ArchUnitNET tests.
- NuGet packaging of module templates.
- pwsh (PowerShell 7) support in hook command for non-Windows teammates.
