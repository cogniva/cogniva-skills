# AGENTS.md

This repo is **cogniva** — Cogniva's plugin marketplace for Claude Code and OpenAI Codex. It hosts shared tooling as plugins under `plugins/`; it is not an application codebase. This file is the one home for the repo's shared rules: Codex reads it natively, and `CLAUDE.md` imports it.

## Layout

- `.claude-plugin/marketplace.json` — the marketplace manifest (name: `cogniva`), read by both agent hosts
- `plugins/cogniva-skills/` — general-purpose skills for any project, plus the plugin template for new skills (`plugin-template/`)
  - Skills: `glossary` (terminology), `project-context` (business context), `project-requirement` (requirements tracking), `reference` (bibliography)
- `plugins/cogniva-dev/` — development-specific skills, the architecture-profile library (`profiles/`), scripts, hooks, and repo scaffolding templates
  - Skills: `add-module`, `adr`, `applicable-rules`, `backlog`, `cleanup-allwork`, `cleanup-work`, `easy-work-scan`, `execute-feature`, `explore-idea`, `feature-check`, `feature-status`, `gate-check`, `groom-backlog`, `investigate`, `module-deps`, `module-status`, `plan-feature`, `quick-fix`, `repo-init`, `repo-status`, `workflow-status`
- Roster format: each plugin's `Skills:` sub-bullet is ONE line that names every directory under that plugin's `skills/` in backticks. The green gate's `instruction-governance` suite fails when the line and the disk disagree, so add or remove a skill here in the same change.
- `docs/glossary/README.md` — canonical glossary; use its terms and link them, e.g. [Module](docs/glossary/README.md#module)
- `docs/strategy.md` — conventions + tooling decisions
- `docs/plans/<Module>/<Feature>/` — feature plans + `state.md` (lifecycle `Status:`); `docs/plans/<Module>/<Idea>/` with `backlog.md` + no plan is a deferred **backlog stub**; `BACKLOG.md` (repo-level and per-Module) holds loose deferred items. Capture with `backlog`; view with `feature-status`/`module-status`/`repo-status`

## Common tasks

- Validate plugins: `claude plugin validate .`
- Run the green gate (every check a change must pass): `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .`

## Rules

- Tools, marketplaces, and authorship are branded "Cogniva" — never name artifacts after individual team members (no personal names or initials).
- Glossary protocol: `docs/glossary/README.md` is the shared glossary. Propose new entries before writing them (propose-then-confirm).
- Bump the plugin `version` in its `plugin.json` when its skills/scripts/templates change — but **offer**, never bump on your own, and include one sentence (maybe two) on why that level. The tiers mirror semver patch/minor/major:
  - **Patch** (`0.3.0 → 0.3.1`) — makes it work *better* without meaningfully changing *what it does*: wording fixes, an added end-of-skill hand-off note, minor script tweaks.
  - **Minor** (`0.3.0 → 0.4.0`) — changes *what* the toolkit does: a significant new skill, removing one, reworking an existing skill's intent, or a workflow change.
  - **Major** (`0.3.0 → 1.0.0`) — leave the call to the user.
  - When a change sits on the patch/minor line, offer the smaller bump and say why.
  - **A bump is THREE files, always.** The version lives in the plugin's
    `plugins/<plugin>/.claude-plugin/plugin.json`, in its
    `plugins/<plugin>/.codex-plugin/plugin.json`, **and** in its entry in the
    top-level `.claude-plugin/marketplace.json` — all of them must match.
    Editing only `plugin.json` ships a marketplace that advertises the old
    version. `claude plugin validate .` reports that mismatch only as a warning
    and still exits 0; the green gate's `manifest-parity` check is what fails on
    it. Update all three in the same commit, then confirm with:
    `grep -n '"version"' plugins/<plugin>/.claude-plugin/plugin.json plugins/<plugin>/.codex-plugin/plugin.json .claude-plugin/marketplace.json`

## Cross-host parity

- Both plugins support Claude Code and OpenAI Codex ([Agent hosts](docs/glossary/README.md#agent-host)). When you change skills, scripts, hooks, profiles, templates, manifests or workflows, consider both.
- Prefer one shared implementation. Host differences go only in overlays (`CODEX.md`, `WORKTREE.md`), host metadata (SKILL.md frontmatter, `agents/openai.yaml`), manifests, or hook input adapters.
- Update the capability's row in the [Parity record](docs/host-parity.md), and state any intentional asymmetry with its reason there. The green gate's `host-parity` check fails on skills and hooks the record does not cover.
- `verified` needs smoke evidence from the real agent host. Shared scripts or docs never prove it.
- Keep workflow contracts technology-neutral: language specifics belong in profiles, detectors and setup skills.
- After changing instruction files (`AGENTS.md`, `CLAUDE.md`, a `SKILL.md`), start a fresh session on both agent hosts.
- Record in the PR which agent host implemented the change and which reviewed it.

## Cogniva-dev workflow instructions

Phase blocks that the cogniva-dev workflow skills (plan-feature, quick-fix,
execute-feature) and the workflow-neutral checks honour at named phases: a
per-repo injection point, so those generic skills pick up this repo's rules
without anything repo-specific being hard-coded into them. A skill that reaches
a phase follows its block; a skill that never reaches it ignores it; an absent
block is a silent no-op. See `docs/strategy.md` for the convention and the
phase vocabulary.

### before-planning

- Add a `**Host impact:**` line to the plan header: which agent-host behaviour
  the feature changes, which `docs/host-parity.md` rows it adds or changes, and
  any intentional asymmetry with its reason. `none` is valid when nothing
  agent-host-facing changes.

### before-integrate

- If an integration changed a plugin's skills, scripts, or templates, offer
  the plugin-version bump required by `## Rules` in AGENTS.md while the
  worktree is still open so it can ride the same merge.
- If skills, hooks, manifests or overlays changed, update their
  `docs/host-parity.md` rows before the green gate runs (its `host-parity`
  check fails on uncovered items), and note which agent host implemented the
  change and which reviewed it.
