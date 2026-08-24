# GateCheck — Feature Plan

> **Superseded:** The composable-workflow-guardrails implementation retains this
> plan's shared green-gate runner and tool-neutral gate-check decisions, while
> adding workflow-neutral placement discovery and readiness review. Its
> task-by-task, lifecycle-owned execution steps are therefore no longer the
> authoritative implementation plan.

> **HISTORICAL DESIGN EVIDENCE ONLY — DO NOT RUN `/execute-feature` against
> this plan.** The task and execution instructions below record the original
> design context; they were not executed as written and must not be resumed.

**Goal:** Give any AI tool (or a human with a shell) a single manual entry point —
the `gate-check` skill — that runs the same pre-merge gate checks the cogniva-dev
workflow skills enforce, and make those checks tool-agnostic: one shared green-gate
runner script used by every consumer, and phase-block config resolved AGENTS.md-first
with a transitional CLAUDE.md fallback.

**Architecture:** A new `run-green-gate.ps1` script becomes the single implementation
of the `green-gate.json` semantics (absent → skip, empty → intentional no-gate,
ordered commands each exiting 0, cwd scoped internally). A new `gate-check` skill —
written in the Agent Skills SKILL.md format both Claude Code and Codex consume, with
no Claude-specific tooling in its body — orchestrates the four checks (tree clean,
repo obligations, ADR check, green gate) and reports one verdict. execute-feature and
quick-fix are rewired to call the shared runner instead of restating the semantics in
prose. All consumers of `## Cogniva-dev workflow instructions` switch to AGENTS.md-first,
per-block CLAUDE.md-fallback resolution, and this repo's own block migrates to AGENTS.md
with a breadcrumb left in CLAUDE.md.

**Read these first:**
- `docs/strategy.md` — "Repo-scoped workflow instructions" section (the phase-block convention)
- `docs/adr/0011-green-gate-is-repo-configured.md`
- `docs/adr/0024-green-gate-is-last-before-integration.md`
- `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md` (green-gate.json schema + semantics)
- `plugins/cogniva-dev/scripts/check-adrs.ps1` (style reference for the new script: `Fail`, `Invoke-Git`-style stderr handling, exit codes 0/1/2)

## File structure (locked)

```
plugins/cogniva-dev/scripts/run-green-gate.ps1        # NEW — the single green-gate implementation (exit 0 green/skip, 1 red, 2 config error)
plugins/cogniva-dev/skills/gate-check/SKILL.md        # NEW — tool-agnostic manual gate-check skill (dual-consumed: Claude Code + Codex)
AGENTS.md                                             # NEW (repo root) — this repo's `## Cogniva-dev workflow instructions` moves here
plugins/cogniva-dev/skills/execute-feature/SKILL.md   # MOD — Step 3.2/2a call run-green-gate.ps1; Step 3.1b resolves AGENTS.md-first
plugins/cogniva-dev/skills/quick-fix/SKILL.md         # MOD — Step 2 gate calls run-green-gate.ps1; before-integrate resolves AGENTS.md-first
plugins/cogniva-dev/skills/plan-feature/SKILL.md      # MOD — before-planning + before-integrate resolve AGENTS.md-first
plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md  # MOD — mention manual gate-check + the shared runner
docs/strategy.md                                      # MOD — convention: AGENTS.md primary, CLAUDE.md transitional fallback, per-block
CLAUDE.md                                             # MOD — workflow-instructions block replaced with a breadcrumb to AGENTS.md
docs/adr/NNNN-*.md                                    # 3 ADRs, written by Tasks 2, 3, 4 (next free numbers at execution time)
```

## Candidate ADRs

### ADR-C1: Gate checks have one dual-consumed gate-check skill in the cogniva-dev plugin
**Provenance:** Suggested by agent
The manual pre-merge check is authored once, tool-agnostically, at
`plugins/cogniva-dev/skills/gate-check/SKILL.md` in the Agent Skills SKILL.md format
that both Claude Code and Codex consume — Claude Code loads it as
`/cogniva-dev:gate-check`, other tools register the same folder from a cogniva-skills
clone. One source of truth; no per-tool forks to drift.
**Write with:** Task 2

### ADR-C2: Workflow phase blocks resolve AGENTS.md-first with a per-block CLAUDE.md fallback
**Provenance:** Suggested by human
Every consumer of `## Cogniva-dev workflow instructions` (plan-feature, quick-fix,
execute-feature, gate-check) looks for each `### <phase>` block in the target repo's
AGENTS.md first, then falls back to CLAUDE.md for any block AGENTS.md lacks. AGENTS.md
is the preferred, tool-agnostic home; the CLAUDE.md fallback is transitional
pragmatism so existing repos keep working while they migrate — not an endorsement of
CLAUDE.md as a config location.
**Write with:** Task 4

### ADR-C3: The green gate has exactly one implementation, shared by all consumers
**Provenance:** Suggested by human
execute-feature, quick-fix, and gate-check all run the gate through
`plugins/cogniva-dev/scripts/run-green-gate.ps1` rather than each restating the
`green-gate.json` semantics in prose. Any tool checking the same bar runs the same
code, so an issue affects everyone equally and a semantics change lands once. The
script scopes its cwd to the target repo internally, which removes the
parked-shell-in-worktree hazard from every caller.
**Write with:** Task 3

## Task 1: run-green-gate.ps1 — the shared green-gate runner

**Files:**
- Create: `plugins/cogniva-dev/scripts/run-green-gate.ps1`

- [ ] **Step 1 (implement):** create `plugins/cogniva-dev/scripts/run-green-gate.ps1` with exactly this content:

```powershell
# Runs a repo's configured green gate: .claude/cogniva-dev/green-gate.json.
#
# This is the SINGLE implementation of the green-gate semantics (ADR: the green
# gate has exactly one implementation). Consumers: execute-feature Step 3,
# quick-fix Step 2, and the gate-check skill. Semantics (ADR 0011):
#
#   - ABSENT config file  -> print the one-line skip note, exit 0. Absence is
#     expected for docs-only / early-stage repos and must never be a nuisance.
#   - "commands": []      -> intentional no-gate; one line, exit 0.
#   - otherwise           -> run each commands[].run IN ORDER with the repo as
#     cwd; each must exit 0. First non-zero exit fails the gate.
#
# The cwd is scoped INSIDE this script (Push/Pop-Location), so the caller's
# shell never enters the target repo/worktree - a live process parked in a
# worktree is what makes Windows refuse to delete it at close-out.
#
# Exit: 0 = green or legitimately skipped, 1 = a gate command failed (red),
# 2 = usage or config error. Every path prints why before it exits.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    # Override the config location (used by tests); default is the repo's own.
    [string]$ConfigPath
)
$ErrorActionPreference = 'Stop'

function Fail($msg) { [Console]::Error.WriteLine("green-gate: $msg"); exit 2 }

if (-not (Test-Path -LiteralPath $Repo -PathType Container)) {
    Fail "repo not found: $Repo"
}
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $Repo '.claude/cogniva-dev/green-gate.json'
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    Write-Output "green-gate: no .claude/cogniva-dev/green-gate.json in this repo - skipping the build/test gate. Add one to gate future runs (see the opt-in README)."
    exit 0
}

try {
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
} catch {
    Fail "cannot parse $ConfigPath as JSON: $($_.Exception.Message)"
}

$commands = @($config.commands)
if ($commands.Count -eq 0) {
    Write-Output "green-gate: 'commands' is empty - intentional no-gate."
    exit 0
}

$n = 0
Push-Location -LiteralPath $Repo
try {
    foreach ($c in $commands) {
        $n++
        if (-not $c.run) { Pop-Location; Fail "commands[$($n - 1)] has no 'run'" }
        $label = if ($c.label) { $c.label } else { "command $n" }
        Write-Output ""
        Write-Output "green-gate: [$label] $($c.run)"
        if ($c.note) { Write-Output "green-gate:   note: $($c.note)" }

        # Native stderr under EAP 'Stop' becomes a terminating
        # NativeCommandError in Windows PowerShell; run each command with EAP
        # 'Continue' so its own exit code is what decides pass/fail.
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & powershell -NoProfile -Command $c.run 2>&1 | ForEach-Object { Write-Output ([string]$_) }
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = $prev }

        if ($code -ne 0) {
            Write-Output ""
            Write-Output "green-gate: RED - [$label] exited $code. Do NOT integrate until this passes."
            exit 1
        }
    }
} finally { Pop-Location }

Write-Output ""
Write-Output "green-gate: GREEN - all $n command(s) exited 0."
exit 0
```

- [ ] **Step 2 (green case, this repo's real gate):** run
      `powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/scripts/run-green-gate.ps1" -Repo "."`
      → output ends with `green-gate: GREEN - all 1 command(s) exited 0.` and `$LASTEXITCODE` is 0
      (this repo's gate runs `claude plugin validate .`).
- [ ] **Step 3 (skip case):** run
      `powershell -NoProfile -Command "$d = Join-Path $env:TEMP 'gg-skip-test'; New-Item -ItemType Directory -Force $d | Out-Null; exit 0"`
      then
      `powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/scripts/run-green-gate.ps1" -Repo "$env:TEMP\gg-skip-test"`
      → prints the one-line skip note (`green-gate: no .claude/cogniva-dev/green-gate.json ...`), exit code 0.
- [ ] **Step 4 (red case):** write a throwaway config
      `powershell -NoProfile -Command "Set-Content -Path (Join-Path $env:TEMP 'gg-red.json') -Value '{ \"commands\": [ { \"run\": \"exit 3\", \"label\": \"always-red\" } ] }'"`
      then
      `powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/scripts/run-green-gate.ps1" -Repo "." -ConfigPath "$env:TEMP\gg-red.json"`
      → prints `green-gate: RED - [always-red] exited 3. ...`, exit code 1. Delete both temp artifacts afterwards
      (`Remove-Item "$env:TEMP\gg-red.json", "$env:TEMP\gg-skip-test" -Recurse -Force`).
- [ ] **Step 5 (commit):** `git add plugins/cogniva-dev/scripts/run-green-gate.ps1`
      then `git commit -m "feat(cogniva-dev): run-green-gate.ps1 - single shared green-gate runner"`

## Task 2: the gate-check skill (dual-consumed SKILL.md)

**Files:**
- Create: `plugins/cogniva-dev/skills/gate-check/SKILL.md`
- Modify: `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md`

- [ ] **Step 1 (create the skill):** create `plugins/cogniva-dev/skills/gate-check/SKILL.md` with exactly this content:

```markdown
---
name: gate-check
description: Manually run this repo's pre-merge gate checks - the same checks the cogniva-dev workflow skills (plan-feature, quick-fix, execute-feature) run before integrating. Use before merging a branch whose work was NOT produced by those skills, from any AI tool (Claude Code, Codex, or none). Reports a verdict; changes nothing except what the repo's own gate commands do.
---

# Gate Check

Run the pre-merge checks this repo configures, in the same order the cogniva-dev
workflow skills run them, and report one verdict. This skill is tool-agnostic:
it assumes only that you can read files and run shell commands. Follow it
literally; do not substitute your own build/test commands for the repo's
configured ones.

**Inputs.**
- `<repo>` — the repo checkout being checked: your current working directory.
- `<target>` — the branch this work will merge into. Ask the user if unknown;
  default `main`.
- `<plugin>` — the cogniva-skills clone or plugin install that holds this skill:
  the parent of the `skills/` directory this file lives in
  (`<plugin>/skills/gate-check/SKILL.md`). The scripts below resolve relative to
  it, so never copy this SKILL.md around on its own — register the folder from a
  full clone.

Run the four checks IN ORDER. Do not stop at the first failure — run everything,
then give a single verdict, so all problems surface in one pass.

## 1. Tree clean

`git -C "<repo>" status --porcelain` — empty output means clean. A dirty tree is
not fatal for a preview run, but say it prominently in the verdict: a gate over
a dirty tree certifies NOTHING, because uncommitted changes do not ride the
merge.

## 2. Repo obligations (phase blocks)

Find the `## Cogniva-dev workflow instructions` section — in `<repo>/AGENTS.md`
first, then `<repo>/CLAUDE.md`. Resolution is PER PHASE BLOCK: a `### <phase>`
block missing from AGENTS.md may still be in CLAUDE.md (transitional; AGENTS.md
is the preferred home).

Honor the `### before-integrate` block now: its instructions are judgment calls
only an agent or a human can make (e.g. offering a plugin version bump with a
one-sentence rationale), not commands to run blindly. If it tells you to produce
or offer something, do that as part of this check's report. Mention any other
`### <phase>` blocks you saw in one informational line each. No section or no
block anywhere → say so in one line; that is a normal no-op, not a failure.

## 3. ADR check

`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/check-adrs.ps1" -Worktree "<repo>" -TargetBranch "<target>"`

Exit 0 = clean. Exit 1 = problems listed (duplicate or already-taken ADR
numbers, un-dereferenced `ADR-C` candidate labels in shipped lines) — each must
be fixed and the check re-run before merging. Exit 2 = usage/environment error;
report it as inconclusive, not as a pass.

## 4. Green gate

`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/run-green-gate.ps1" -Repo "<repo>"`

Runs the ordered commands in `<repo>/.claude/cogniva-dev/green-gate.json`. Exit
0 = green, or legitimately skipped (an absent config prints its own skip note;
an empty `commands: []` is an intentional no-gate — either way, NOT a failure).
Exit 1 = red — report the failing command and its output. Exit 2 = config error
— report it as inconclusive.

## Verdict

End with one line per check — `PASS` / `FAIL` / `SKIPPED` / `WARN (why)` — and a
plain conclusion:

- Any FAIL → "Do not merge until this is fixed", naming the fix.
- All pass/skip → the branch meets the same bar the automated cogniva-dev
  workflow skills enforce.

## Using from Codex or another tool

Clone github.com/cogniva/cogniva-skills (or pull the latest), then register
`plugins/cogniva-dev/skills/gate-check/` with your tool's skills mechanism
(Agent Skills format). Keep the clone intact — this skill calls sibling scripts
via `<plugin>/scripts/`, so a copied-out SKILL.md will not find them.
```

- [ ] **Step 2 (template README pointer):** in
      `plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md`, find the paragraph under
      `## Green gate config — .claude/cogniva-dev/green-gate.json` that ends with
      `declared here:` and add this sentence to the end of that paragraph:
      `The gate itself is executed by the plugin's shared runner (`scripts/run-green-gate.ps1`), and any agent — Claude or otherwise — can run the full pre-merge check set manually via the plugin's `gate-check` skill.`
- [ ] **Step 3 (validate):** run `claude plugin validate .` from the repo root → expect validation success (the new skill parses).
- [ ] **Step 4 (write ADR):** scan `docs/adr/` for the next free number and write the confirmed
      candidate **ADR-C1** (from `## Candidate ADRs`) verbatim to `docs/adr/NNNN-gate-checks-have-one-dual-consumed-gate-check-skill.md`,
      heading `# Gate checks have one dual-consumed gate-check skill in the cogniva-dev plugin`, body = the ADR-C1 provenance line + text.
- [ ] **Step 5 (commit):** `git add plugins/cogniva-dev/skills/gate-check/SKILL.md plugins/cogniva-dev/templates/repo/.claude/cogniva-dev/README.md docs/adr/`
      then `git commit -m "feat(cogniva-dev): gate-check skill - manual, tool-agnostic pre-merge checks"`

## Task 3: rewire execute-feature and quick-fix onto the shared runner

**Files:**
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/quick-fix/SKILL.md`

- [ ] **Step 1 (execute-feature):** in `plugins/cogniva-dev/skills/execute-feature/SKILL.md`,
      replace the whole span from the line beginning
      `  2. **GREEN GATE — run the repo's configured gate (mandatory, no shortcuts).**`
      up to and including the line ending
      `with the suspended UI tests excluded; see the opt-in README for the worked example.)`
      (this span currently comprises step 2, the cwd-warning paragraph, and step 2a) with:

```markdown
  2. **GREEN GATE — run the repo's configured gate (mandatory, no shortcuts).** This
     is the LAST step before integration; the tree must be exactly what will merge.
     Run:
     `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/run-green-gate.ps1" -Repo "<worktree>"`
     It reads `<worktree>/.claude/cogniva-dev/green-gate.json`
     (schema: `{ "commands": [ { "run": "<shell command>", "label": "<short, optional>",
     "note": "<optional reasoning, shown in reports>" } ] }`) and runs each
     `commands[].run` IN ORDER with the worktree as cwd. The script scopes the cwd
     internally, so your shell never enters the worktree (a parked shell is what
     makes Windows refuse to delete it at close-out). Act on the exit code:
     - `0` — GREEN, or legitimately skipped: an ABSENT config file makes the script
       print its own one-line skip note and is expected for docs-only or
       early-stage repos — do NOT prompt and do NOT fall back to any build
       command; an empty `commands: []` is an intentional no-gate. Either way,
       proceed.
     - `1` — RED. Report the failing command (its `label` if present) and its
       output, and STOP — do not integrate (unless Step 2b applies).
     - `2` — config/usage error (unparseable JSON, bad path). Report and STOP.
     (A .NET Module repo's gate typically runs a whole-solution
     `dotnet build <RepoName>.slnx` — which catches cross-module test consumers
     that scoped per-project builds miss — then `dotnet test <RepoName>.slnx` with
     the suspended UI tests excluded; see the opt-in README for the worked example.)
```

- [ ] **Step 2 (renumber references):** still in `execute-feature/SKILL.md`, step `2b`
      immediately follows the block above; verify its text still reads correctly (it refers to
      "the gate" generically — no edits expected) and that no other line in the file still
      instructs running gate commands inline (search for `Push-Location` in the Step 3 gate
      context — the only remaining `Push-Location`/`Pop-Location` guidance about the GATE should be gone;
      the general worktree-cwd cautions elsewhere in the file stay).
- [ ] **Step 3 (quick-fix):** in `plugins/cogniva-dev/skills/quick-fix/SKILL.md`, replace the
      two consecutive paragraphs — the one beginning
      `Then run the repo green gate exactly as **execute-feature Step 3** defines it: read`
      (ending `a gate over a dirty tree is a lie.`) and the one beginning
      `The gate runs with `<worktree>` as its cwd, but **do not leave your shell parked`
      (ending `execute-feature Step 3 for the full reasoning.`) — with this single paragraph:

```markdown
Then run the repo green gate exactly as **execute-feature Step 3** defines it:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/run-green-gate.ps1" -Repo "<worktree>"`.
Exit 0 = green or legitimately skipped (an absent `green-gate.json` prints its own
one-line skip note; an empty `commands: []` is an intentional no-gate); 1 = red —
report the failing command and its output and STOP; 2 = config error — report and
STOP. The script scopes its cwd to the worktree internally, so your shell never
enters the worktree. Commit any lingering worktree changes first — a gate over a
dirty tree is a lie.
```

- [ ] **Step 4 (validate):** `claude plugin validate .` → success.
- [ ] **Step 5 (write ADR):** scan `docs/adr/` for the next free number and write the confirmed
      candidate **ADR-C3** verbatim to `docs/adr/NNNN-green-gate-has-one-shared-implementation.md`,
      heading `# The green gate has exactly one implementation, shared by all consumers`,
      body = the ADR-C3 provenance line + text.
- [ ] **Step 6 (commit):** `git add plugins/cogniva-dev/skills/execute-feature/SKILL.md plugins/cogniva-dev/skills/quick-fix/SKILL.md docs/adr/`
      then `git commit -m "refactor(cogniva-dev): execute-feature + quick-fix run the gate via run-green-gate.ps1"`

## Task 4: AGENTS.md-first phase-block resolution, everywhere

**Files:**
- Modify: `plugins/cogniva-dev/skills/plan-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/quick-fix/SKILL.md`
- Modify: `docs/strategy.md`
- Create: `AGENTS.md` (repo root)
- Modify: `CLAUDE.md` (repo root)

The resolution rule, used verbatim in every edit below: *look for each `### <phase>`
block under `## Cogniva-dev workflow instructions` in the target repo's AGENTS.md
first, then fall back to CLAUDE.md for any block AGENTS.md lacks. AGENTS.md is the
preferred home; the CLAUDE.md fallback is transitional.*

- [ ] **Step 1 (plan-feature, before-planning):** in
      `plugins/cogniva-dev/skills/plan-feature/SKILL.md`, replace the sentence
      `**Repo obligations (`before-planning`).** Check the target repo's CLAUDE.md for a` + its continuation
      `` `## Cogniva-dev workflow instructions` section; if it has a `### before-planning` `` +
      `block, follow it before designing. Absent → nothing to do.` with:
      `**Repo obligations (`before-planning`).** Check the target repo's `## Cogniva-dev workflow instructions` section — AGENTS.md first, then CLAUDE.md (per-block fallback; AGENTS.md is the preferred home) — and if it has a `### before-planning` block, follow it before designing. Absent from both → nothing to do.`
- [ ] **Step 2 (plan-feature, before-integrate):** in the same file, in the `## Integrate (one commit)`
      section, replace `check` + `the target repo's CLAUDE.md `## Cogniva-dev workflow instructions` for a` + `` `### before-integrate` block ``
      with `check the target repo's `## Cogniva-dev workflow instructions` — AGENTS.md first, then CLAUDE.md (per-block fallback) — for a `### before-integrate` block`.
- [ ] **Step 3 (execute-feature, Step 3.1b):** in `plugins/cogniva-dev/skills/execute-feature/SKILL.md`,
      replace `Check the target repo's CLAUDE.md` + `` `## Cogniva-dev workflow instructions` for a `### before-integrate` block and ``
      with `Check the target repo's `## Cogniva-dev workflow instructions` — AGENTS.md first, then CLAUDE.md (per-block fallback; AGENTS.md is the preferred home) — for a `### before-integrate` block and`.
- [ ] **Step 4 (quick-fix, before-integrate):** in `plugins/cogniva-dev/skills/quick-fix/SKILL.md`,
      replace `check the target` + `repo's CLAUDE.md `## Cogniva-dev workflow instructions` for a `### before-integrate``
      with `check the target repo's `## Cogniva-dev workflow instructions` — AGENTS.md first, then CLAUDE.md (per-block fallback; AGENTS.md is the preferred home) — for a `### before-integrate``.
- [ ] **Step 5 (strategy.md):** in `docs/strategy.md`, section `## Repo-scoped workflow instructions`:
      - Replace the sentence `The cogniva-dev workflow skills (plan-feature, quick-fix, execute-feature) honor an optional `## Cogniva-dev workflow instructions` section in a repo's CLAUDE.md.` with:
        `The cogniva-dev workflow skills (plan-feature, quick-fix, execute-feature) and the manual gate-check skill honor an optional `## Cogniva-dev workflow instructions` section in a repo's AGENTS.md, falling back to CLAUDE.md per phase block. AGENTS.md is the preferred, tool-agnostic home; the CLAUDE.md fallback exists so repos keep working while they migrate.`
      - Replace the closing sentence `This repo's own CLAUDE.md uses `before-integrate` to fire the plugin version-bump offer while the worktree is still open.` with:
        `This repo's own AGENTS.md uses `before-integrate` to fire the plugin version-bump offer while the worktree is still open (CLAUDE.md keeps a breadcrumb pointing there).`
- [ ] **Step 6 (migrate this repo's block):** create `AGENTS.md` at the repo root with exactly:

```markdown
# Cogniva-dev workflow instructions (repo-scoped)

Phase blocks the cogniva-dev workflow skills and gate-check honor at named
phases. Resolution is AGENTS.md-first with a per-block CLAUDE.md fallback; see
docs/strategy.md ("Repo-scoped workflow instructions") for the convention.

## Cogniva-dev workflow instructions

### before-integrate

- If this integration changed a plugin's skills/scripts/templates, apply the
  version-bump rule under `## Rules` in CLAUDE.md - **offer** the bump on that
  plugin now, while the worktree is still open, so it rides the same merge.
```

      Then in root `CLAUDE.md`, replace the `### before-integrate` block (the heading plus its
      bullet, at the end of the `## Cogniva-dev workflow instructions` section) with:

```markdown
### before-integrate

- This repo's phase blocks have moved to `AGENTS.md` (AGENTS.md-first
  resolution — see docs/strategy.md). Read `## Cogniva-dev workflow
  instructions` there and honor its `### before-integrate` block.
```

      (The breadcrumb keeps any consumer that still only reads CLAUDE.md working during the transition.)
- [ ] **Step 7 (validate):** `claude plugin validate .` → success.
- [ ] **Step 8 (write ADR):** scan `docs/adr/` for the next free number and write the confirmed
      candidate **ADR-C2** verbatim to `docs/adr/NNNN-phase-blocks-resolve-agents-md-first.md`,
      heading `# Workflow phase blocks resolve AGENTS.md-first with a per-block CLAUDE.md fallback`,
      body = the ADR-C2 provenance line + text.
- [ ] **Step 9 (commit):** `git add plugins/cogniva-dev/skills/plan-feature/SKILL.md plugins/cogniva-dev/skills/execute-feature/SKILL.md plugins/cogniva-dev/skills/quick-fix/SKILL.md docs/strategy.md AGENTS.md CLAUDE.md docs/adr/`
      then `git commit -m "feat(cogniva-dev): phase blocks resolve AGENTS.md-first, CLAUDE.md fallback"`
