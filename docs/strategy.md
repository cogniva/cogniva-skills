# Repo strategy

What this repo is, the conventions it encodes, and how to consume it.

## Purpose

`cogniva` is Cogniva's plugin marketplace for Claude Code and OpenAI Codex
(repo: github.com/cogniva/cogniva-skills). It ships two plugins: `cogniva-skills`
(general-purpose skills such as glossary and reference) and `cogniva-dev`
(development tooling: ADRs, the backlog, repo scaffolding with repo-init and
add-module, and the feature lifecycle), so every new repo starts identical and
improvements propagate: consuming repos update the plugins instead of copying
tooling. Architecture profiles are the deliberate exception; see below.

## Conventions (canonical definitions: docs/glossary/README.md)

- New .NET repos follow the `dotnet` [Architecture profile](glossary/README.md#architecture-profile):
  Cogniva's shared .NET principles plus default conventions - the first folder
  under `src/` names a project's kind, [Hosts](glossary/README.md#host) under
  `src/Hosts/` are the only composition roots, and UI is host-neutral Blazor
  libraries. `repo-init` adopts and declares it.
- A repo's own layout and exceptions live in its
  [Repo-owned profile](glossary/README.md#repo-owned-profile). The
  [Module bundle layout](glossary/README.md#module-bundle-layout) is one such
  layout, supported by `add-module` and `module-deps`.
- Every repo keeps a glossary at `docs/glossary/README.md` (seeded by repo-init)
  and grows it propose-then-confirm.
- Plans in `docs/plans/`.

## Tooling inventory

Tools ship across two plugins: general-purpose skills in `cogniva-skills`
(glossary, reference, project-requirement, project-context); development-specific
skills in `cogniva-dev`. The authoritative per-plugin roster is AGENTS.md's
`## Layout` section — it is not duplicated here.

## Consuming in a new repo

1. Register the marketplace and install both plugins, `cogniva-skills` and
   `cogniva-dev`, on each agent host you use:
   - Claude Code: `/plugin marketplace add cogniva/cogniva-skills` (or the
     path of your local clone), then `/plugin install cogniva-dev@cogniva`
     and `/plugin install cogniva-skills@cogniva`.
   - Codex: `codex plugin marketplace add cogniva/cogniva-skills` (or the
     path of your local clone), install both plugins from the `/plugins`
     browser, start a new Codex session, and trust the plugin hooks via
     `/hooks`.
2. Run the repo-init skill.

## Maintenance

- Change skills/templates/scripts here, then bump `version` per the three-file
  rule in AGENTS.md `## Rules` — the plugin's `.claude-plugin/plugin.json`, its
  `.codex-plugin/plugin.json`, and its entry in the top-level
  `.claude-plugin/marketplace.json`, all matching, in one commit; consuming
  repos pick it up via plugin update. The green gate now runs
  `scripts/check-plugin-manifests.ps1` to catch version/description/keyword
  drift between manifest pairs and the marketplace.

## Repo-scoped workflow instructions

The cogniva-dev workflow skills (plan-feature, quick-fix, execute-feature) and
the workflow-neutral checks honor an optional `## Cogniva-dev workflow
instructions` section in a repo's AGENTS.md first, with a per-phase-block
fallback to CLAUDE.md. AGENTS.md is the preferred, tool-neutral home;
CLAUDE.md remains a transitional source of substantive repository constraints.
It is a per-repo injection point: a repo adds its own obligations to generic
skills without anything repo-specific being baked into the skills.

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
listing it here. This repo's own AGENTS.md holds both of its phase blocks,
and its CLAUDE.md only imports AGENTS.md: `before-planning` asks every plan
for a `**Host impact:**` line, and `before-integrate` fires the plugin
version-bump offer while the worktree is still open and has the parity
record updated before the green gate. A consuming repo that still keeps its
rules in CLAUDE.md can move them with
`plugins/cogniva-dev/docs/agents-md-migration.md`.

## Architecture profiles

An [Architecture profile](glossary/README.md#architecture-profile) is a set of
declarative standards for one kind of codebase. Library profiles are copied in
with an adoption record (`.cogniva/adopted/<id>.yml`) so a refresh can tell a
library update from a local edit; a repo's own rules go in a
[Repo-owned profile](glossary/README.md#repo-owned-profile) that amends or adds
to them. The cogniva-dev plugin ships a
library of them (`plugins/cogniva-dev/profiles/`); a repo adopts one by copying
it into `.cogniva/profiles/` and selects it per path with a
[Profile marker](glossary/README.md#profile-marker). Tools read only the repo's
copy, so a repo's standards change only through a deliberate re-adoption.
plan-feature designs under the resolved profile, quick-fix checks structural
changes against it before landing, and applicable-rules reports it per target; executing agents see only what a plan's tasks restate. How to
adopt, declare, and write profiles: `plugins/cogniva-dev/docs/architecture-profiles.md`.

## Roadmap (deliberately not yet)

- Enforce dependency rules with Roslyn analyzers or ArchUnitNET tests.
- NuGet packaging of module templates.
- pwsh (PowerShell 7) support in hook command for non-Windows teammates.
