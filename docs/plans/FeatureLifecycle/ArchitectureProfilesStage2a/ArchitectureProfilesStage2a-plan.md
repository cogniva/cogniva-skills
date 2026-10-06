# ArchitectureProfilesStage2a — Feature Plan (orchestrated)

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/ArchitectureProfilesStage2a
> Multi-plan feature: the sub-plans below execute IN LISTED ORDER (already
> dependency-sorted), all in ONE workspace, sequentially, landing ONCE at the
> end. Tasks contain NO git worktree/branch step.

**Goal:** Turn architecture profiles into a tested parent/child contract
(amendments, replacement standards, review states, adoption records), reframe
the `dotnet` library profile as Cogniva's shared .NET principles plus default
conventions for new repos, and point `repo-init`, `add-module` and
`applicable-rules` at that contract.

**Architecture:** Sub-plan 01 rebuilds the profile core in
`plugins/cogniva-dev/scripts/` (composition of `standards/`, `amendments/`,
`replacements/`; a normalised `basis:` hash per delta; `-Show`, `-Require`/exit
3; adoption records under `.cogniva/adopted/`; `accept-profile-delta.ps1`).
02 rewrites `profiles/cogniva-base` and `profiles/dotnet` on that contract and
adds the `profile-library` test suite. 03 makes `applicable-rules` take its
placement checks from the resolved profile. 04 moves the template to
`AGENTS.md` + an `@AGENTS.md` shim, updates the glossaries, and renames
"legacy Module layout" to **Module bundle layout** everywhere. 05 rewrites
`repo-init` to scaffold the minimal `dotnet` skeleton. 06 gates `add-module` on
the profile. 07 writes the docs, the migration guide, and the plan-feature
SKILL change.

**Read these first:**
- `docs/plans/FeatureLifecycle/ArchitectureProfiles/Stage2a-proposal.md` (the approved proposal; this plan supersedes it where they differ)
- `docs/adr/0036-architecture-profiles-declared-per-path.md` … `docs/adr/0040-architecture-profiles-copied-into-repos.md`
- `plugins/cogniva-dev/docs/architecture-profiles.md`
- `docs/glossary/README.md`

**Where this plan departs from the proposal (decided during planning):**
- "Managed profile" is **Library profile**; "child profile" as a name for a repo's own profile is **Repo-owned profile**; adoption records live in `.cogniva/adopted/<id>.yml` (not `.cogniva/managed/`); the JSON ownership values are `library` / `repo-owned`.
- "Legacy Module layout" is **Module bundle layout** everywhere (glossary, SKILL.md files, test names, ADR 0041, the leak check).
- "Shared types" is **Common types**; the standard is `architecture/common-and-published-types.md`. The exceptions standard is `architecture/architecture-exceptions.md` (so it does not read as exception handling).
- The resolver's per-standard JSON has no `Kind` field (`ReplacedBy` carries it); review entries use `Delta`, not `Kind`.
- `applies-to` is always a block list (`applies-to:` then `  - "glob"` lines); the proposal's flow-list example in §10 is not valid in the YAML subset (ADR 0038).
- repo-init's ⛔ gate is replaced by an automated scaffold-and-build check (Sub-plan 05, Task 3).
- Port and Adapter are not glossary terms (general programming concepts; see the glossary format rules); the external-integrations standard defines them in its own text.
- Every ADR this plan writes carries **Relitigation: Open to discussion**.

## Sub-plans (execution order)

| # | Sub-plan | Delivers | Prerequisites |
|---|----------|----------|---------------|
| 1 | `subplans/01-ProfileCore.md` | Deltas, basis, states, `-Show`, `-Require`/exit 3, adoption records, `-Refresh`, `accept-profile-delta.ps1`; ADRs C1, C2, C3, C6 | — |
| 2 | `subplans/02-LibraryReframe.md` | New `cogniva-base` + `dotnet` content; `profile-library` suite with the Module-bundle leak check and the two shape fixtures; ADR C4 | 1 |
| 3 | `subplans/03-ApplicableRules.md` | Placement checks from `applies-to`; `REVIEW:` vs `REVIEW_REQUIRED`; ADR C5 | 1, 2 |
| 4 | `subplans/04-TemplatesGlossaryTerminology.md` | `AGENTS.md` template + `@AGENTS.md` shim, template glossary and `Directory.Build.props`, glossary + strategy + README updates, Module bundle layout rename, plugin-wide leak check | 2 |
| 5 | `subplans/05-RepoInit.md` | repo-init scaffolds the minimal `dotnet` skeleton and declares `dotnet`; automated scaffold check | 1, 2, 4 |
| 6 | `subplans/06-AddModule.md` | add-module is the Module bundle layout scaffolder, gated with `-Require` | 1, 2 |
| 7 | `subplans/07-DocsAndPlanFeature.md` | `architecture-profiles.md` rewrite, migration guide, plan-feature SKILL change, proposal status | 1–6 |
