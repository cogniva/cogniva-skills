# Repo strategy

What this repo is, the conventions it encodes, and how to consume it.

## Purpose

`cogniva` is Cogniva's Claude Code plugin marketplace (repo:
github.com/cogniva/cogniva-skills). Its single `cogniva-skills` plugin carries
the team toolkit: shared skills (glossary, auto-doc) and repo-initialization
scaffolding (repo-init, add-module) — so every new repo starts identical and
improvements propagate (consuming repos reinstall/update the plugin instead of
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
  `docs/plans/`.

## Tooling inventory

All tools ship in the `cogniva-skills` plugin:

| Tool | Type | Trigger |
|---|---|---|
| repo-init | skill | user starts a new repo |
| add-module | skill | user adds a vertical slice |
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

## Repo-scoped workflow instructions

The cogniva-dev workflow skills (plan-feature, quick-fix, execute-feature) honor
an optional `## Cogniva-dev workflow instructions` section in a repo's CLAUDE.md.
It is a per-repo injection point: a repo adds its own obligations to those
generic skills without anything repo-specific being baked into the skills.

Inside it, each `### <phase>` block is a checkpoint. A skill that reaches a phase
reads the matching block and follows it; a skill that never reaches that phase
ignores it; an absent section or block is a silent no-op. Phases currently wired:

- `before-planning` — plan-feature, at the start of its design loop.
- `before-integrate` — plan-feature / quick-fix / execute-feature, on the
  worktree just before integration (so anything the block produces rides the
  same merge).

The vocabulary is open: add a phase by naming it in a skill checkpoint and
listing it here. This repo's own CLAUDE.md uses `before-integrate` to fire the
plugin version-bump offer while the worktree is still open.

## Roadmap (deliberately not yet)

- Enforce dependency rules with Roslyn analyzers or ArchUnitNET tests.
- NuGet packaging of module templates.
- pwsh (PowerShell 7) support in hook command for non-Windows teammates.
