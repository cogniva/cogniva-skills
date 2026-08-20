# Repo strategy

What this repo is, the conventions it encodes, and how to consume it.

## Purpose

`cogniva` is Cogniva's Claude Code plugin marketplace (repo:
github.com/cogniva/cogniva-skills). Its single `cogniva-skills` plugin carries
the team toolkit: shared skills (glossary, adr) and repo-initialization
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

Tools ship across two plugins: general-purpose skills in `cogniva-skills`
(glossary, reference, project-requirement, project-context); development-specific
skills in `cogniva-dev`. The authoritative per-plugin roster is CLAUDE.md's
`## Layout` section — it is not duplicated here.

## Consuming in a new repo

1. `/plugin marketplace add cogniva/cogniva-skills` (or the path of your local clone)
2. `/plugin install cogniva-skills@cogniva`
3. Run the repo-init skill.

## Maintenance

- Change skills/templates/scripts here, then bump `version` per the three-file
  rule in CLAUDE.md `## Rules` — the plugin's `.claude-plugin/plugin.json`, its
  `.codex-plugin/plugin.json`, and its entry in the top-level
  `.claude-plugin/marketplace.json`, all matching, in one commit; consuming
  repos pick it up via plugin update. The green gate now runs
  `scripts/check-plugin-manifests.ps1` to catch version/description/keyword
  drift between manifest pairs and the marketplace.

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
  worktree while it is still open, so anything the block produces rides the same
  merge. In the execution skills it runs BEFORE the green gate, not immediately
  before the merge command: everything that rides the merge must be verified by
  the gate, and a block that writes code would otherwise ship unverified. The name
  is kept — its contract was always "on the worktree", not "adjacent to the merge".

The vocabulary is open: add a phase by naming it in a skill checkpoint and
listing it here. This repo's own CLAUDE.md uses `before-integrate` to fire the
plugin version-bump offer while the worktree is still open.

## Roadmap (deliberately not yet)

- Enforce dependency rules with Roslyn analyzers or ArchUnitNET tests.
- NuGet packaging of module templates.
- pwsh (PowerShell 7) support in hook command for non-Windows teammates.
