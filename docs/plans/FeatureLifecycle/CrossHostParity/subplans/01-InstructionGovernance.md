# 01 InstructionGovernance — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/CrossHostParity
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** `AGENTS.md` becomes this repo's one instruction file, read by both
Claude Code and Codex, carrying the shared rules, the skill roster, a standing
cross-host parity rule and both workflow phase blocks; `CLAUDE.md` only imports
it, and a new green-gate suite keeps it that way.

**Architecture:** Root `AGENTS.md` takes everything shared from root
`CLAUDE.md` plus a new `## Cross-host parity` section and a new
`### before-planning` phase block; `CLAUDE.md` becomes exactly `@AGENTS.md`
(nothing in this repo is Claude Code–only today; the suite still allows a
future `## Claude Code notes` section). A pwsh 7 suite
(`instruction-governance`) asserts the split, resolves both phase blocks with
the existing Windows PowerShell 5.1 resolver, and compares the AGENTS.md skill
roster with the skill directories on disk. The glossary gains **Agent host** and
**Parity record**; stale references to rules "in CLAUDE.md" are corrected;
consumer-facing templates become host-neutral; a migration procedure for
consuming repos is written (no consuming repo is migrated by this plan).

**Read these first:** `AGENTS.md`, `CLAUDE.md`, `docs/strategy.md`
(§ Repo-scoped workflow instructions), `plugins/cogniva-dev/scripts/resolve-workflow-obligations.ps1`
(a phase block ends at ANY `#`–`###` heading line), `docs/glossary/README.md`,
`plugins/cogniva-dev/templates/repo/AGENTS.md`,
`plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` (pins the
template AGENTS.md: it must not contain `src/Modules`, `->`, `references nothing`
or `Contracts`), `plugins/cogniva-dev/skills/adr/ADR-FORMAT.md`.

Verified facts this plan relies on: `claude plugin validate .` reports a
marketplace/plugin version mismatch only as a warning (`‼ Found 1 warning …
√ Validation passed with warnings`) and exits 0; the green gate's
`manifest-parity` command (`scripts/check-plugin-manifests.ps1`) is what fails.
No skill-semantics, profile-library or other suite pins any text this sub-plan
replaces except the template AGENTS.md drift checks named above, which the new
text satisfies.

## File structure (locked)

```
plugins/cogniva-dev/tests/instruction-governance/instruction-governance.tests.ps1  # NEW pwsh 7 suite: one instruction home, phase blocks, roster = disk
AGENTS.md                                           # canonical: intro, Layout + roster, Common tasks, Rules, Cross-host parity, both phase blocks
CLAUDE.md                                           # exactly @AGENTS.md
.claude/cogniva-dev/green-gate.json                 # + instruction-governance entry; validate note host-neutral
docs/adr/NNNN-agents-md-is-the-canonical-instruction-file-in-this-repo-too.md  # ADR C1
docs/glossary/README.md                             # + Agent host, Parity record; Cogniva entry names both agent hosts
plugins/cogniva-skills/templates/glossary/README.md # Cogniva entry names both agent hosts
plugins/cogniva-dev/templates/repo/AGENTS.md        # worktree section host-neutral + Codex sentence
plugins/cogniva-skills/plugin-template/README.md    # "Works on both agent hosts" checklist; host-neutral Active trigger
plugins/cogniva-skills/plugin-template/SKILL.md     # checklist reminder comment
plugins/cogniva-dev/docs/agents-md-migration.md     # NEW consumer migration procedure
docs/strategy.md                                    # both agent hosts; rules + roster live in AGENTS.md; phase blocks; migration pointer
plugins/cogniva-dev/docs/codex.md                   # validate only warns; manifest-parity fails
plugins/cogniva-skills/docs/codex.md                # maintainers pointer -> AGENTS.md; "verified" claim corrected
README.md                                           # skill table: five missing skills added, execute-feature row corrected
.claude/cogniva-dev/README.md                       # repo config (green gate), not the mode switch
```

## Candidate ADRs

### ADR-C1: AGENTS.md is the canonical instruction file in this repo too
**Provenance:** Suggested by agent
This repo's shared engineering rules (layout and skill roster, branding, glossary protocol, version bumps, cross-host parity, workflow phase blocks) live in root `AGENTS.md`, which Codex loads natively; root `CLAUDE.md` is `@AGENTS.md` plus, at most, a short `## Claude Code notes` section for genuinely Claude-only mechanics. The repo now follows the arrangement its own `repo-init` template scaffolds, and no rule is stated in both files.
**Write with:** Task 1

## Task 1: AGENTS.md becomes the canonical instruction file (instruction-governance suite first)

**Files:**
- Create: `plugins/cogniva-dev/tests/instruction-governance/instruction-governance.tests.ps1`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`
- Modify: `.claude/cogniva-dev/green-gate.json`
- Create: `docs/adr/NNNN-agents-md-is-the-canonical-instruction-file-in-this-repo-too.md`

- [x] **Step 1 (failing test):** Create `plugins/cogniva-dev/tests/instruction-governance/instruction-governance.tests.ps1` (PowerShell 7; UTF-8 without BOM is fine — the file is ASCII) with exactly:
  ```powershell
  # Dependency-free tests (no Pester) that this repository's agent instructions
  # have one home: AGENTS.md holds the shared rules and the workflow phase blocks,
  # CLAUDE.md only imports it, and the AGENTS.md skill roster matches the skill
  # directories on disk. Each check is a function that takes a repository root and
  # returns its problems, so the suite can prove on a fixture that it can fail.
  # PowerShell 7. Runs against the repository this file lives in.
  $ErrorActionPreference = 'Stop'
  $here = Split-Path -Parent $MyInvocation.MyCommand.Path
  $Root = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\..\..'))
  $obligations = Join-Path $Root 'plugins\cogniva-dev\scripts\resolve-workflow-obligations.ps1'
  $sharedHeadings = @('## Rules', '## Layout', '## Cross-host parity', '## Cogniva-dev workflow instructions', '## Common tasks')
  $failures = @()
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

  # A check passes when the function under test reported no problem.
  function Check($label, [string[]]$Problems) {
      $Problems = @($Problems | Where-Object { $_ })
      if ($Problems.Count -eq 0) { Write-Host "  PASS  $label" }
      else {
          Write-Host "  FAIL  $label"
          foreach ($p in $Problems) { Write-Host "        $p" }
          $script:failures += $label
      }
  }
  # A self-test passes when the function under test DID report a problem.
  function CheckFails($label, [string[]]$Problems) {
      if (@($Problems | Where-Object { $_ }).Count -gt 0) { Write-Host "  PASS  $label" }
      else { Write-Host "  FAIL  $label (the check reported nothing)"; $script:failures += $label }
  }
  function Read-Lines([string]$Path) {
      if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
      return @([System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8) | ForEach-Object { $_.TrimEnd() })
  }
  function Write-Text([string]$Path, [string]$Text) {
      New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
      [System.IO.File]::WriteAllText($Path, $Text, $script:utf8NoBom)
  }

  # The first non-blank line of CLAUDE.md imports AGENTS.md.
  function Test-ClaudeImportsAgents([string]$RepoRoot) {
      $lines = Read-Lines (Join-Path $RepoRoot 'CLAUDE.md')
      if ($null -eq $lines) { return 'CLAUDE.md is missing' }
      $first = @($lines | Where-Object { $_.Trim() }) | Select-Object -First 1
      if ($first -cne '@AGENTS.md') { return "the first non-blank line of CLAUDE.md is '$first', not '@AGENTS.md'" }
      return @()
  }

  # CLAUDE.md states no shared rule: none of the shared headings, and no heading
  # other than '## Claude Code notes'.
  function Test-ClaudeHoldsNoSharedRules([string]$RepoRoot) {
      $lines = Read-Lines (Join-Path $RepoRoot 'CLAUDE.md')
      if ($null -eq $lines) { return 'CLAUDE.md is missing' }
      $problems = @()
      foreach ($h in $script:sharedHeadings) { if ($lines -ccontains $h) { $problems += "CLAUDE.md contains '$h'" } }
      foreach ($l in @($lines | Where-Object { $_ -match '^#{1,6}\s' })) {
          if ($l -cne '## Claude Code notes') { $problems += "CLAUDE.md has the heading '$l'; only '## Claude Code notes' is allowed" }
      }
      return $problems
  }

  # AGENTS.md carries every shared section.
  function Test-AgentsHoldsSharedRules([string]$RepoRoot) {
      $lines = Read-Lines (Join-Path $RepoRoot 'AGENTS.md')
      if ($null -eq $lines) { return 'AGENTS.md is missing' }
      return @($script:sharedHeadings | Where-Object { $lines -cnotcontains $_ } | ForEach-Object { "AGENTS.md lacks '$_'" })
  }

  # Both wired phases resolve from AGENTS.md with at least one non-blank line.
  # resolve-workflow-obligations.ps1 is a Windows PowerShell 5.1 script.
  function Test-PhaseBlocksFromAgents([string]$RepoRoot) {
      $problems = @()
      foreach ($phase in @('before-planning', 'before-integrate')) {
          $json = (& powershell -NoProfile -ExecutionPolicy Bypass -File $script:obligations -Repo $RepoRoot -Phase $phase -Format Json) -join "`n"
          if ($LASTEXITCODE -ne 0) { $problems += "resolve-workflow-obligations exited $LASTEXITCODE for $phase"; continue }
          $report = $json | ConvertFrom-Json
          if ($report.Source -ne 'AGENTS.md') { $problems += "$phase resolves from '$($report.Source)', not 'AGENTS.md'" }
          if (@($report.Lines | Where-Object { "$_".Trim() }).Count -eq 0) { $problems += "$phase block has no non-blank lines" }
      }
      return $problems
  }

  # The AGENTS.md roster equals the skill directories on disk, per plugin. Format:
  # inside '## Layout', the plugin's bullet starts with "- `plugins/<plugin>/`", and
  # a sub-bullet line starting "  - Skills:" follows it before the next top-level
  # bullet; every backticked name on that ONE line is a skill.
  function Get-LayoutSkills([string[]]$Lines, [string]$Plugin) {
      $start = [array]::IndexOf($Lines, '## Layout')
      if ($start -lt 0) { return $null }
      $bullet = '- `plugins/' + $Plugin + '/`'
      for ($i = $start + 1; $i -lt $Lines.Count; $i++) {
          if ($Lines[$i] -match '^##\s') { return $null }
          if (-not $Lines[$i].StartsWith($bullet)) { continue }
          for ($j = $i + 1; $j -lt $Lines.Count; $j++) {
              if ($Lines[$j] -match '^(- |#)') { return $null }
              if ($Lines[$j].StartsWith('  - Skills:')) {
                  return @([regex]::Matches($Lines[$j], '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value })
              }
          }
          return $null
      }
      return $null
  }
  function Test-LayoutRoster([string]$RepoRoot) {
      $lines = Read-Lines (Join-Path $RepoRoot 'AGENTS.md')
      if ($null -eq $lines) { return 'AGENTS.md is missing' }
      $problems = @()
      $plugins = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'plugins') -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'skills') -PathType Container })
      foreach ($plugin in $plugins) {
          $onDisk = @(Get-ChildItem -LiteralPath (Join-Path $plugin.FullName 'skills') -Directory | ForEach-Object Name)
          $listed = Get-LayoutSkills $lines $plugin.Name
          if ($null -eq $listed) { $problems += "AGENTS.md ## Layout has no '  - Skills:' line under the plugins/$($plugin.Name)/ bullet"; continue }
          foreach ($s in $onDisk) { if ($listed -cnotcontains $s) { $problems += "$($plugin.Name): skills/$s is not in the AGENTS.md roster" } }
          foreach ($s in $listed) { if ($onDisk -cnotcontains $s) { $problems += "$($plugin.Name): the AGENTS.md roster names '$s', which has no skills/ directory" } }
      }
      return $problems
  }

  # The repo-init template's CLAUDE.md is exactly the import.
  function Test-TemplateClaude([string]$RepoRoot) {
      $path = Join-Path $RepoRoot 'plugins\cogniva-dev\templates\repo\CLAUDE.md'
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return 'templates/repo/CLAUDE.md is missing' }
      if ((Get-Content -Raw -LiteralPath $path).Trim() -cne '@AGENTS.md') { return 'templates/repo/CLAUDE.md is not exactly @AGENTS.md' }
      return @()
  }

  # --- this repository ----------------------------------------------------------
  Check 'CLAUDE.md starts by importing AGENTS.md' (Test-ClaudeImportsAgents $Root)
  Check 'CLAUDE.md holds no shared rule (only a ## Claude Code notes section is allowed)' (Test-ClaudeHoldsNoSharedRules $Root)
  Check 'AGENTS.md holds Rules, Layout, Cross-host parity, Cogniva-dev workflow instructions and Common tasks' (Test-AgentsHoldsSharedRules $Root)
  Check 'before-planning and before-integrate resolve from AGENTS.md' (Test-PhaseBlocksFromAgents $Root)
  Check 'the AGENTS.md skill roster equals the skill directories of every plugin' (Test-LayoutRoster $Root)
  Check 'the repo-init template CLAUDE.md is exactly @AGENTS.md' (Test-TemplateClaude $Root)

  # --- the checks can fail (fixture) ----------------------------------------------
  $fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-instruction-governance-" + [guid]::NewGuid().ToString('N'))
  try {
      Write-Text (Join-Path $fixture 'CLAUDE.md') "@AGENTS.md`n`n## Rules`n`n- A rule stated in the wrong file.`n"
      Write-Text (Join-Path $fixture 'AGENTS.md') "# AGENTS.md`n`n## Layout`n`n- ``plugins/demo/`` - demo plugin`n  - Skills: ``alpha```n"
      New-Item -ItemType Directory -Path (Join-Path $fixture 'plugins\demo\skills\alpha') -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $fixture 'plugins\demo\skills\beta') -Force | Out-Null
      CheckFails 'self-test: a CLAUDE.md with ## Rules is reported' @(Test-ClaudeHoldsNoSharedRules $fixture | Where-Object { $_ -match "contains '## Rules'" })
      CheckFails 'self-test: a skill directory missing from the roster is reported' @(Test-LayoutRoster $fixture | Where-Object { $_ -match 'skills/beta is not in the AGENTS\.md roster' })
      CheckFails 'self-test: an AGENTS.md without phase blocks is reported' @(Test-PhaseBlocksFromAgents $fixture)
      Write-Text (Join-Path $fixture 'CLAUDE.md') "# CLAUDE.md`n`n@AGENTS.md`n"
      CheckFails 'self-test: a CLAUDE.md that does not start with @AGENTS.md is reported' @(Test-ClaudeImportsAgents $fixture)
  }
  finally {
      if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
  }

  if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
  Write-Host ''
  Write-Host 'All instruction-governance assertions passed.'
  exit 0
  ```
- [x] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/instruction-governance/instruction-governance.tests.ps1` → exit 1, `FAILED: 5 assertion(s).`: FAIL on the first five checks (CLAUDE.md starts with `# CLAUDE.md`; CLAUDE.md contains `## Rules`, `## Layout`, `## Cogniva-dev workflow instructions`, `## Common tasks`; AGENTS.md lacks `## Rules`, `## Layout`, `## Cross-host parity`, `## Common tasks`; `before-planning resolves from 'none'`; no `  - Skills:` line for either plugin). PASS on the template check and all four self-tests.
- [x] **Step 3 (implement AGENTS.md):** Replace the whole content of root `AGENTS.md` with exactly the text below. Constraints the text already meets and any later edit must keep: the section heading is exactly `## Cogniva-dev workflow instructions`; the phase headings are exactly `### before-planning` and `### before-integrate`; no line inside a phase body starts with `#` (the resolver ends a block at any `#`–`###` heading line); each plugin's `  - Skills:` line stays ONE line.
  ```markdown
  # AGENTS.md

  This repo is **cogniva** — Cogniva's plugin marketplace for Claude Code and OpenAI Codex. It hosts shared tooling as plugins under `plugins/`; it is not an application codebase. This file is the one home for the repo's shared rules: Codex reads it natively, and `CLAUDE.md` imports it.

  ## Layout

  - `.claude-plugin/marketplace.json` — the marketplace manifest (name: `cogniva`), read by both agent hosts
  - `plugins/cogniva-skills/` — general-purpose skills for any project, plus the plugin template for new skills (`plugin-template/`)
    - Skills: `glossary` (terminology), `project-context` (business context), `project-requirement` (requirements tracking), `reference` (bibliography)
  - `plugins/cogniva-dev/` — development-specific skills, the architecture-profile library (`profiles/`), scripts, hooks, and repo scaffolding templates
    - Skills: `add-module`, `adr`, `applicable-rules`, `backlog`, `cleanup-allwork`, `cleanup-work`, `easy-work-scan`, `execute-feature`, `explore-idea`, `feature-check`, `feature-status`, `gate-check`, `groom-backlog`, `module-deps`, `module-status`, `plan-feature`, `quick-fix`, `repo-init`, `repo-status`, `workflow-status`
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
  ```
  (`docs/host-parity.md`, the glossary anchor `#agent-host` and the `host-parity` gate check are created later in this feature — sub-plan 03 and Task 2 below; the forward links are intended.)
- [x] **Step 4 (implement CLAUDE.md):** Replace the whole content of root `CLAUDE.md` with exactly one line:
  ```markdown
  @AGENTS.md
  ```
  No `## Claude Code notes` section: nothing in this repo is Claude Code–only today (the `.claude/settings.json` deny on `git switch`/`git checkout` was removed in `a351717`). This removes the old `## Layout`, `## Common tasks`, `## Rules` and the `## Cogniva-dev workflow instructions` breadcrumb from CLAUDE.md; AGENTS.md now holds all of them.
- [x] **Step 5 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/instruction-governance/instruction-governance.tests.ps1` → ten PASS lines and `All instruction-governance assertions passed.` (exit 0). Also `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/resolve-workflow-obligations.ps1 -Repo . -Phase before-planning` → first line `workflow-obligations: ### before-planning from AGENTS.md (…\AGENTS.md)` followed by the Host-impact bullet.
- [x] **Step 6 (wire into the green gate):** In `.claude/cogniva-dev/green-gate.json`, append one entry at the END of the `commands` array: add a comma after the closing `}` of the current last entry (today the `"label": "gate-check"` line), then insert this line before the array's closing `  ]`:
  ```json
      { "run": "pwsh -NoProfile -File plugins/cogniva-dev/tests/instruction-governance/instruction-governance.tests.ps1", "label": "instruction-governance", "note": "Pins AGENTS.md as this repo's one instruction file: CLAUDE.md only imports it, both phase blocks resolve from it, and its skill roster equals the skill directories; needs PowerShell 7." }
  ```
  Then `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/validate-json.ps1 .claude/cogniva-dev/green-gate.json` → exit 0.
- [x] **Step 7 (write ADR):** scan `docs/adr/` for the next free number (0051 if nothing newer than 0050 exists) and write ADR-C1 from this sub-plan's `## Candidate ADRs` verbatim to `docs/adr/NNNN-agents-md-is-the-canonical-instruction-file-in-this-repo-too.md` per `plugins/cogniva-dev/skills/adr/ADR-FORMAT.md`: H1 `# AGENTS.md is the canonical instruction file in this repo too` (no `ADR-C1` label anywhere in the file), then `**Provenance:** Suggested by agent`, a blank line, and the body paragraph; no Relitigation line, no `Write with` line. Run `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/check-adrs.ps1 -Workspace .` → exit 0.
- [x] **Step 8 (commit):** `git add AGENTS.md CLAUDE.md .claude/cogniva-dev/green-gate.json plugins/cogniva-dev/tests/instruction-governance/instruction-governance.tests.ps1 docs/adr` then `git commit -m "docs(agents): AGENTS.md is the canonical instruction file; CLAUDE.md imports it"`

## Task 2: Glossary terms, host-neutral consumer templates, and the migration procedure

**Files:**
- Modify: `docs/glossary/README.md`
- Modify: `plugins/cogniva-skills/templates/glossary/README.md`
- Modify: `plugins/cogniva-dev/templates/repo/AGENTS.md`
- Modify: `plugins/cogniva-skills/plugin-template/README.md`
- Modify: `plugins/cogniva-skills/plugin-template/SKILL.md`
- Create: `plugins/cogniva-dev/docs/agents-md-migration.md`
- Test: `plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` (existing pins on the template AGENTS.md; no change needed)

Decision recorded here: the consumer template glossary `plugins/cogniva-dev/templates/repo/docs/glossary/README.md` does NOT get an Agent host entry. The template AGENTS.md text below names Claude Code and Codex but never uses the term "agent host", and that template glossary is a .NET seed that `profile-library.tests.ps1` keeps free of tooling terms.

- [x] **Step 1 (glossary entries):** In `docs/glossary/README.md`, insert the two entries below between the end of the `## Cogniva` entry (its paragraph ends "Tools are never named after individual team members.") and the `## Plan` heading, with one blank line before each `##` heading:
  ```markdown
  ## Agent host

  The coding-agent product a skill runs under — Claude Code or OpenAI Codex — on one of its surfaces (CLI, VS Code extension, desktop app). Distinct from a [Host](#host), which is a runnable .NET project.
  _Avoid_: host (alone), harness, platform

  ## Parity record

  `docs/host-parity.md` in the cogniva-skills repo: one row per capability stating, for each [Agent host](#agent-host), its mechanism, its status (`verified`, `scripts-tested`, `untested`, `partial`, `unsupported`, `n/a`), the evidence behind that status, and any intentional asymmetry with its reason. The green gate derives the skill and hook inventory and fails on anything the record does not cover.
  _Avoid_: parity matrix, compatibility table
  ```
- [x] **Step 2 (Cogniva entry names both agent hosts):** In `docs/glossary/README.md`, in the `## Cogniva` paragraph, replace `The Claude Code plugin marketplace in this repo is named` with `The plugin marketplace in this repo, for Claude Code and OpenAI Codex, is named`. In `plugins/cogniva-skills/templates/glossary/README.md`, in its `## Cogniva` paragraph, replace `The Claude Code plugin marketplace is named` with `The plugin marketplace, for Claude Code and OpenAI Codex, is named`.
- [x] **Step 3 (template AGENTS.md):** In `plugins/cogniva-dev/templates/repo/AGENTS.md`, `## Git / worktree workflow` section, replace:
  ```markdown
  In worktree mode, nothing Claude does lands on your checked-out branch outside
  a git worktree:

  - Claude does not edit the primary checkout directly, and does not
    `git switch`/`checkout` or move branches there. The plugin's guards enforce
  ```
  with:
  ```markdown
  Worktree mode currently requires Claude Code; under Codex the lifecycle skills
  stop when it is on. In worktree mode, nothing an agent does lands on your
  checked-out branch outside a git worktree:

  - Agents do not edit the primary checkout directly, and do not
    `git switch`/`checkout` or move branches there. The plugin's guards enforce
  ```
  (The rest of that bullet and section is unchanged. The new text contains none of `src/Modules`, `->`, `references nothing`, `Contracts`, which profile-library pins out of this file.)
- [x] **Step 4 (skill authoring template, README):** In `plugins/cogniva-skills/plugin-template/README.md`, replace the line
  `    - **Active**: Explicitly call this skill (e.g., `/run-skill`).`
  with
  `    - **Active**: The user asks for this skill by name.`
  and append at the end of the file (after the `## Example: Passive Triggering` section, separated by one blank line):
  ```markdown
  ## Works on both agent hosts

  Every skill ships to Claude Code and OpenAI Codex from the same `SKILL.md`. Before shipping one, check:

  - Other skills are named by their bare name (`backlog`), never by one agent host's invocation syntax.
  - No agent-host tool (for example the Workflow tool or `apply_patch`) is named without the other agent host's equivalent.
  - Steps only one agent host needs live in an overlay file beside `SKILL.md` (for example `CODEX.md`), which the skill reads only on that agent host.
  - Explicit-only invocation is set in both places together: `disable-model-invocation: true` in the frontmatter and `policy.allow_implicit_invocation: false` in `agents/openai.yaml`.
  - The skill has a row in the parity record (`docs/host-parity.md` in the cogniva-skills repo).
  - The green gate passes: `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .`
  ```
- [x] **Step 5 (skill authoring template, SKILL.md):** Append to the end of `plugins/cogniva-skills/plugin-template/SKILL.md` (the file currently ends without a newline after "then [action]."; add a newline, a blank line, then):
  ```markdown
  <!-- Template note (delete before shipping): work through "Works on both agent hosts" in this template's README.md - bare skill names, no agent-host tool without the other's equivalent, host-only steps in an overlay, explicit-only metadata in both frontmatter and agents/openai.yaml, a parity-record row, a green gate run. -->
  ```
- [x] **Step 6 (migration procedure):** Create `plugins/cogniva-dev/docs/agents-md-migration.md` with exactly:
  ````markdown
  # Moving a repo's rules from CLAUDE.md to AGENTS.md

  A repo whose shared rules live in `CLAUDE.md` gives them only to Claude Code;
  Codex reads `AGENTS.md`. This procedure gives both agent hosts the same rules.
  New repos from `repo-init` already have this arrangement, and the
  cogniva-skills repo follows it for itself. It is a procedure only: the plan
  that added it migrated no consuming repo.

  1. **Move the shared rules.** Move every section that applies to any agent
     (conventions, layout, glossary protocol, build and test rules,
     architecture pointers) from `CLAUDE.md` into `AGENTS.md`. Where both files
     state a rule, keep one copy, in `AGENTS.md`.
  2. **Reduce CLAUDE.md to the import.** Make its first line `@AGENTS.md`. Below
     it, under `## Claude Code notes`, keep only mechanics that exist for
     Claude Code alone (a `.claude/settings.json` permission, a Claude-only
     hook). With none, the file is exactly `@AGENTS.md`.
  3. **Move the workflow phase blocks.** Move any `## Cogniva-dev workflow
     instructions` section, with its `### <phase>` blocks, into `AGENTS.md`. The
     resolver reads `AGENTS.md` first and falls back to `CLAUDE.md` per phase,
     so a block left behind still resolves but is easy to miss. No line inside
     a phase block may start with `#`: the resolver ends the block at any
     heading.
  4. **Verify.** From the repo root, with the cogniva-dev plugin installed, run
     for each phase the repo defines:
     ```
     powershell -NoProfile -ExecutionPolicy Bypass -File "<cogniva-dev plugin>/scripts/resolve-workflow-obligations.ps1" -Repo . -Phase before-integrate
     ```
     Its first line must contain `### before-integrate from AGENTS.md`. With
     `-Format Json`, `Source` is `AGENTS.md`.
  5. **Start fresh sessions** on Claude Code and on Codex. Both read
     instruction files when a session starts, so a running session keeps the
     old text.
  ````
- [x] **Step 7 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/profile-library/profile-library.tests.ps1` → exit 0 with its final all-passed line (the template AGENTS.md and template glossary pins hold); `pwsh -NoProfile -File plugins/cogniva-dev/tests/instruction-governance/instruction-governance.tests.ps1` → `All instruction-governance assertions passed.`; `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`; `grep -c "^## Agent host\|^## Parity record" docs/glossary/README.md` → `2`.
- [x] **Step 8 (commit):** `git add docs/glossary/README.md plugins/cogniva-skills/templates/glossary/README.md plugins/cogniva-dev/templates/repo/AGENTS.md plugins/cogniva-skills/plugin-template/README.md plugins/cogniva-skills/plugin-template/SKILL.md plugins/cogniva-dev/docs/agents-md-migration.md` then `git commit -m "docs(glossary): agent host and parity record; host-neutral templates and an AGENTS.md migration procedure"`

## Task 3: Point every reference at AGENTS.md and correct the stale docs

**Files:**
- Modify: `docs/strategy.md`
- Modify: `plugins/cogniva-dev/docs/codex.md`
- Modify: `plugins/cogniva-skills/docs/codex.md`
- Modify: `.claude/cogniva-dev/README.md`
- Modify: `.claude/cogniva-dev/green-gate.json`
- Modify: `README.md` (skill table rows only)

Scope: only references to THIS repo's rules move to AGENTS.md. Text that describes a consuming repo's `CLAUDE.md` (the resolver's per-phase fallback, the Codex inheritance rule in `plugins/cogniva-dev/docs/codex.md` § Repository CLAUDE.md under Codex, `applicable-rules`, `execute-feature`, `plan-feature`, `repo-init`) stays as it is. No test pins the replaced text (`skill-semantics.tests.ps1` reads `docs/codex.md` only for its two `##` headings, which are unchanged).

- [ ] **Step 1 (strategy.md):** In `docs/strategy.md` make these replacements:
  1. Under `## Purpose`, replace
     ```
     `cogniva` is Cogniva's Claude Code plugin marketplace (repo:
     github.com/cogniva/cogniva-skills). It ships two plugins: `cogniva-skills`
     ```
     with
     ```
     `cogniva` is Cogniva's plugin marketplace for Claude Code and OpenAI Codex
     (repo: github.com/cogniva/cogniva-skills). It ships two plugins: `cogniva-skills`
     ```
  2. Under `## Tooling inventory`, replace `The authoritative per-plugin roster is CLAUDE.md's` with `The authoritative per-plugin roster is AGENTS.md's`.
  3. Under `## Maintenance`, replace `  rule in CLAUDE.md `## Rules` — the plugin's` with `  rule in AGENTS.md `## Rules` — the plugin's`.
  4. Under `## Repo-scoped workflow instructions`, replace
     ```
     listing it here. This repo's own AGENTS.md uses `before-integrate` to fire the
     plugin version-bump offer while the worktree is still open; CLAUDE.md keeps a
     breadcrumb for older consumers.
     ```
     with
     ```
     listing it here. This repo's own AGENTS.md holds both of its phase blocks,
     and its CLAUDE.md only imports AGENTS.md: `before-planning` asks every plan
     for a `**Host impact:**` line, and `before-integrate` fires the plugin
     version-bump offer while the worktree is still open and has the parity
     record updated before the green gate. A consuming repo that still keeps its
     rules in CLAUDE.md can move them with
     `plugins/cogniva-dev/docs/agents-md-migration.md`.
     ```
- [ ] **Step 2 (cogniva-dev codex.md):** In `plugins/cogniva-dev/docs/codex.md`, `## Packaging`, replace
  ```
    `claude plugin validate .` does NOT catch a mismatch, so bump all three in the
    same commit and confirm with:
  ```
  with
  ```
    `claude plugin validate .` reports a mismatch only as a warning and still
    exits 0; the marketplace repo's green gate fails on it (its `manifest-parity`
    check, `scripts/check-plugin-manifests.ps1`). Bump all three in the same
    commit and confirm with:
  ```
- [ ] **Step 3 (cogniva-skills codex.md):** In `plugins/cogniva-skills/docs/codex.md`, replace
  ```
  Maintainers: the version-bump rule (three files, all matching) lives in the
  marketplace repo's `CLAUDE.md` under `## Rules`.
  ```
  with
  ```
  Maintainers: the version-bump rule (three files, all matching) lives in the
  marketplace repo's `AGENTS.md` under `## Rules`.
  ```
  In the same file, step 1 of `## Install under Codex`, replace
  ```
     (verified against OpenAI's plugin docs, 2026-08-19).
  ```
  with
  ```
     (checked against OpenAI's plugin documentation, 2026-08-19; runtime
     behaviour per agent host is tracked in the marketplace repo's
     `docs/host-parity.md`).
  ```
  (Read the surrounding lines first and keep the list item's indentation.)
- [ ] **Step 3b (README skill table):** In root `README.md`, the cogniva-dev `| Piece | Purpose |` table:
  1. Replace the row
     ```
     | `plugins/cogniva-dev/skills/execute-feature` | Execute a feature plan task-by-task in isolated worktrees |
     ```
     with
     ```
     | `plugins/cogniva-dev/skills/execute-feature` | Execute a feature plan task-by-task, one fresh agent per task (on your branch by default; in an isolated worktree in worktree mode) |
     ```
  2. Insert these rows directly after the `backlog` row:
     ```
     | `plugins/cogniva-dev/skills/groom-backlog` | Propose closures for stale backlog items; you confirm once before any edit |
     | `plugins/cogniva-dev/skills/easy-work-scan` | Shortlist backlog work that needs little involvement from you |
     ```
  3. Insert these rows directly after the `workflow-status` row:
     ```
     | `plugins/cogniva-dev/skills/applicable-rules` | Read-only: the instruction chain and placement constraints for target paths |
     | `plugins/cogniva-dev/skills/feature-check` | Read-only preflight, review and commit-readiness evidence |
     | `plugins/cogniva-dev/skills/gate-check` | Run the repo's mechanical completion gates without lifecycle changes |
     ```
  Check: every directory under `plugins/cogniva-dev/skills/` and `plugins/cogniva-skills/skills/` now appears in a README table row — run in PowerShell 7 from the repo root:
  ```powershell
  $readme = Get-Content -Raw README.md
  Get-ChildItem plugins/cogniva-dev/skills, plugins/cogniva-skills/skills -Directory |
      ForEach-Object { $p = ($_.FullName.Substring((Get-Location).Path.Length + 1)) -replace '\\', '/'; if ($readme -notmatch [regex]::Escape("``$p``")) { "MISSING $p" } }
  ```
  → no output.
- [ ] **Step 4 (this repo's .claude/cogniva-dev/README.md):** Replace the whole file (today it still describes the directory as the worktree opt-in marker, which it no longer is) with exactly:
  ```markdown
  # cogniva-dev repo config

  This directory holds this repository's TRACKED cogniva-dev configuration —
  today that is `green-gate.json` (below). It is NOT a mode switch: its presence
  turns nothing on.

  **Worktree mode** (isolated-worktree execution + primary-checkout guards) is a
  per-clone, personal opt-in: an untracked `.claude/cogniva-dev.local.json`
  containing `{ "worktrees": true }`. Default is lean — skills work directly on
  your checkout. Worktree mode currently requires Claude Code; under Codex, work
  in lean mode. See `plugins/cogniva-dev/docs/worktrees.md`.

  ## Where this repo differs from the template

  - There is no `policy.json`: no branch-prefix policy and no Module cycle check.

  ## Green gate config — `green-gate.json`

  The gate is everything a change to this repo must pass before it lands: plugin
  validation, manifest parity, and the plugin test suites. Each `commands[]`
  entry has a `run` (executed in order from the repo root; each must exit 0), a
  `label`, and a `note` saying what the command pins. Add a suite by appending
  one entry in the same style. Run the whole gate with
  `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .`;
  it ends `green-gate: GREEN - all N command(s) exited 0.` when everything passes.

  The full semantics (what a missing file or an empty `commands` list means, and
  the optional `policy.json`) are in the copy of this README that `repo-init`
  ships: `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md`.
  ```
- [ ] **Step 5 (green-gate validate note):** In `.claude/cogniva-dev/green-gate.json`, in the `"label": "validate"` entry, replace the note text `This is a Claude Code plugin marketplace repo, not a .NET solution — the gate validates the plugins.` with `This is a plugin marketplace repo for Claude Code and OpenAI Codex, not a .NET solution — the gate validates the plugins.` Then `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/validate-json.ps1 .claude/cogniva-dev/green-gate.json` → exit 0.
- [ ] **Step 6 (no stale pointer left):** `grep -rn "CLAUDE.md's\|in CLAUDE.md .## Rules\|repo's .CLAUDE.md. under\|does NOT catch\|breadcrumb for older\|Claude Code plugin marketplace" README.md AGENTS.md CLAUDE.md docs/strategy.md docs/glossary plugins .claude/cogniva-dev` → no output (exit 1). If a hit remains that refers to THIS repo's rules, fix it the same way; a hit about a consuming repo's CLAUDE.md is out of scope and stays.
- [ ] **Step 7 (run the full green gate):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → last line `green-gate: GREEN - all 13 command(s) exited 0.` (the 12 original commands plus `instruction-governance`).
- [ ] **Step 8 (commit):** `git add docs/strategy.md plugins/cogniva-dev/docs/codex.md plugins/cogniva-skills/docs/codex.md .claude/cogniva-dev/README.md .claude/cogniva-dev/green-gate.json README.md` then `git commit -m "docs: point rule references at AGENTS.md and correct the version-mismatch claim"`
