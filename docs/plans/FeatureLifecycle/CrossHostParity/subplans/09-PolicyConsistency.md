# 09 PolicyConsistency — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/CrossHostParity
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** The lifecycle skills apply the same policies, in the same order, on
both agent hosts: branch policy before any write, worktree mode refused at
every entry point when the Workflow tool is absent, a skipped green gate
reported as skipped, ephemeral plans visible to the status skills, and install
guidance that covers both plugins on both agent hosts.

**Architecture:** Prose contracts in the skills, pinned by the skill-semantics
suite, plus one script change: `run-green-gate.ps1` (stays Windows PowerShell
5.1 compatible, exit codes unchanged) ends every run with one
`GREEN-GATE-RESULT: GREEN|SKIPPED|RED|ERROR` line, which `run-gate-check.ps1`
and the lifecycle skills read so that a skip is never reported as a pass.
Worktree mode is recorded `unsupported` for Codex in the parity record. One
step applies a remedy from the Codex diagnostics report only if its triage
selected it.

**Read these first:** `plugins/cogniva-dev/skills/execute-feature/SKILL.md`,
`CODEX.md` and `HANDOFF.md` beside it; `plugins/cogniva-dev/skills/plan-feature/SKILL.md`,
`plugins/cogniva-dev/skills/quick-fix/SKILL.md`,
`plugins/cogniva-dev/skills/cleanup-work/SKILL.md`,
`plugins/cogniva-dev/skills/cleanup-allwork/SKILL.md`,
`plugins/cogniva-dev/skills/feature-status/SKILL.md`, `module-status/SKILL.md`,
`repo-status/SKILL.md`, `repo-init/SKILL.md`, `gate-check/SKILL.md`;
`plugins/cogniva-dev/scripts/run-green-gate.ps1`, `run-gate-check.ps1` and their
suites; `plugins/cogniva-dev/docs/codex.md`; `docs/strategy.md`;
`docs/host-parity.md`; `docs/host-parity/codex-diagnostics.md`;
`docs/adr/0031-repo-branch-policy.md`.

## File structure (locked)

```
plugins/cogniva-dev/skills/execute-feature/SKILL.md       # Step 0 branch policy before Step 0a; green-gate marker wording
plugins/cogniva-dev/skills/execute-feature/CODEX.md       # intro names Step 0
plugins/cogniva-dev/skills/execute-feature/HANDOFF.md     # Skipped validations: a SKIPPED green gate
plugins/cogniva-dev/skills/plan-feature/SKILL.md          # branch policy before Emit; worktree STOP without Workflow
plugins/cogniva-dev/skills/quick-fix/SKILL.md             # green-gate marker wording; (conditional) .git sandbox sentence
plugins/cogniva-dev/skills/cleanup-work/SKILL.md          # worktree STOP without Workflow
plugins/cogniva-dev/skills/cleanup-allwork/SKILL.md       # worktree STOP without Workflow
plugins/cogniva-dev/skills/feature-status/SKILL.md        # scans .plans-staging/
plugins/cogniva-dev/skills/module-status/SKILL.md         # scans .plans-staging/<Module>/
plugins/cogniva-dev/skills/repo-status/SKILL.md           # scans .plans-staging/
plugins/cogniva-dev/skills/gate-check/SKILL.md            # SKIPPED is never a pass
plugins/cogniva-dev/skills/repo-init/SKILL.md             # install both plugins on both agent hosts
plugins/cogniva-dev/scripts/run-green-gate.ps1            # final GREEN-GATE-RESULT line (5.1-compatible)
plugins/cogniva-dev/scripts/run-gate-check.ps1            # SKIPPED: green gate not configured (5.1-compatible)
plugins/cogniva-dev/tests/run-green-gate/run-green-gate.tests.ps1   # marker per outcome
plugins/cogniva-dev/tests/run-gate-check/run-gate-check.tests.ps1   # skipped green gate is not PASS
plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1 # pins
plugins/cogniva-dev/docs/codex.md                         # worktree stop everywhere; (conditional) .git sandbox setting
docs/strategy.md                                          # Consuming in a new repo: both plugins, both agent hosts
docs/host-parity.md                                       # worktree rows, plan-status, repo-init notes
docs/adr/NNNN-worktree-mode-stops-under-codex-at-every-entry-point.md  # ADR C6
```

## Candidate ADRs

### ADR-C6: Worktree mode stops under Codex at every entry point
**Provenance:** Suggested by agent
Worktree mode is not offered under Codex (not wanted at the time of this decision): every skill that would start, integrate or clean up worktree-mode work (plan-feature, execute-feature, quick-fix, cleanup-work, cleanup-allwork) stops with one line when worktree mode is on and the Workflow tool is absent. The parity record marks worktree mode `unsupported` for Codex rather than leaving a path that works partway; the outcomes a Codex design would need, should it ever be wanted, are recorded in the CrossHostParity plan's Stage 3.
**Write with:** Task 2

## Task 1: Branch policy before any write

**Files:**
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/execute-feature/CODEX.md`
- Modify: `plugins/cogniva-dev/skills/plan-feature/SKILL.md`
- Test: `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`

Context: today execute-feature's Step 0a (a pasted plan) writes the plan file,
appends `.plans-staging/` to `.git/info/exclude` under `plan=ephemeral`, and can
commit under `commits=task` — all BEFORE Step 0b checks the repo branch policy
(`.claude/cogniva-dev/policy.json` key `requiredDevelopmentBranchPrefix`, ADR
0031). plan-feature has no policy check at all, yet writes the plan folder and
commits it under `commits=final`. The skill-semantics suite runs under Windows
PowerShell 5.1 and reads the test file as ANSI: every string or regex you add
to it must be ASCII-only.

- [x] **Step 1 (failing pins):** In `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`, immediately BEFORE the line `if ($failures.Count -gt 0) {`, add:
  ```powershell
  # --- branch policy before any write --------------------------------------------
  $efFlat = $ef -replace '\s+', ' '
  $iPolicy = $ef.IndexOf('Branch policy')
  $iStep0a = $ef.IndexOf('## Step 0a')
  Check 'execute-feature checks the branch policy before Step 0a' ($iPolicy -ge 0 -and $iStep0a -gt $iPolicy -and $ef -match '## Step 0 . branch policy \(before anything else\)')
  Check 'execute-feature: the policy check precedes every write, .git/info/exclude and commit' ($efFlat -match 'BEFORE writing, appending to `\.git/info/exclude`, or committing anything \(Step 0a included\)')
  Check 'execute-feature: Step 0b no longer carries the policy paragraph' ($ef.IndexOf('Branch policy') -eq $ef.LastIndexOf('Branch policy'))
  $iPfPolicy = $pf.IndexOf('**Branch policy (lean mode only)')
  $iPfEmit = $pf.IndexOf('## Emit the plan')
  Check 'plan-feature checks the branch policy before it emits the plan' ($iPfPolicy -ge 0 -and $iPfEmit -gt $iPfPolicy -and $pf -match 'requiredDevelopmentBranchPrefix')
  Check 'plan-feature never creates or switches a branch for the policy' (($pf -replace '\s+', ' ') -match 'NEVER create or switch a branch to satisfy the policy')
  Check 'CODEX.md: execute-feature Step 0 applies under Codex too' ($codex -match 'Steps 0, 0a, 0b, 1, 2 and 4')
  ```
- [x] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `FAIL` on all six new checks except `Step 0b no longer carries the policy paragraph` (it passes today, because the paragraph exists once); `FAILED: 5 assertion(s).`, exit 1.
- [x] **Step 3 (execute-feature):** In `plugins/cogniva-dev/skills/execute-feature/SKILL.md`:
  1. Delete this paragraph from `## Step 0b — workspace` (and the blank line before it), leaving Step 0b's first paragraph — `WORKSPACE` = the repo root … get an OK before dispatching … ⟦worktree⟧ — exactly as it is:
     ```markdown
     **Branch policy (lean mode only).** BEFORE mutating anything, read
     `.claude/cogniva-dev/policy.json`. If it exists and carries
     `requiredDevelopmentBranchPrefix`, `BRANCH` must start with that prefix.
     Mismatch → STOP with one clear line naming the current branch and the
     required prefix; NEVER create or switch a branch to satisfy the policy —
     which branch to work on is the user's call, not yours. Absent or unreadable
     file, or no such key → no policy, no behaviour change. Worktree mode needs
     no check: its generated branches are `feature/<slug>` by construction.
     ```
  2. Insert this new section immediately BEFORE the line `## Step 0a — resolve the argument: plan reference OR pasted plan text` (followed by one blank line):
     ```markdown
     ## Step 0 — branch policy (before anything else)

     **Branch policy (lean mode only).** BEFORE writing, appending to
     `.git/info/exclude`, or committing anything (Step 0a included), read
     `.claude/cogniva-dev/policy.json`. If it exists and carries
     `requiredDevelopmentBranchPrefix`, the current branch (`git branch
     --show-current`; it becomes `BRANCH` in Step 0b) must start with that
     prefix. Mismatch → STOP with one clear line naming the current branch and
     the required prefix; NEVER create or switch a branch to satisfy the policy
     — which branch to work on is the user's call, not yours. Absent or
     unreadable file, or no such key → no policy, no behaviour change. Worktree
     mode needs no check: its generated branches are `feature/<slug>` by
     construction.
     ```
- [x] **Step 4 (CODEX.md):** In `plugins/cogniva-dev/skills/execute-feature/CODEX.md`, replace `Steps 0a, 0b, 1, 2 and 4 apply exactly as written` with `Steps 0, 0a, 0b, 1, 2 and 4 apply exactly as written`.
- [x] **Step 5 (plan-feature):** In `plugins/cogniva-dev/skills/plan-feature/SKILL.md`, insert this paragraph immediately BEFORE the line `## Emit the plan` (one blank line before and after it):
  ```markdown
  **Branch policy (lean mode only) — before you write anything.** BEFORE
  writing the plan folder, ticking a backlog line, or committing anything,
  read `.claude/cogniva-dev/policy.json`. If it exists and carries
  `requiredDevelopmentBranchPrefix`, the current branch (`git branch
  --show-current`) must start with that prefix. Mismatch → STOP with one clear
  line naming the current branch and the required prefix, and keep the design
  in this conversation so it can be emitted once the user is on a matching
  branch; NEVER create or switch a branch to satisfy the policy — which branch
  to work on is the user's call, not yours. Absent or unreadable file, or no
  such key → no policy, no behaviour change. Worktree mode needs no check: its
  generated branches are `feature/<slug>` by construction.
  ```
- [x] **Step 6 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`, exit 0.
- [x] **Step 7 (commit):** `git add plugins/cogniva-dev/skills/execute-feature/SKILL.md plugins/cogniva-dev/skills/execute-feature/CODEX.md plugins/cogniva-dev/skills/plan-feature/SKILL.md plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` then `git commit -m "fix(lifecycle): check the branch policy before execute-feature or plan-feature writes anything"`

## Task 2: Worktree mode stops without the Workflow tool at every entry point

**Files:**
- Modify: `plugins/cogniva-dev/skills/plan-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/cleanup-work/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/cleanup-allwork/SKILL.md`
- Modify: `plugins/cogniva-dev/docs/codex.md`
- Modify: `docs/host-parity.md`
- Test: `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`
- Create: `docs/adr/NNNN-worktree-mode-stops-under-codex-at-every-entry-point.md`

Context: execute-feature and quick-fix already say, in their "Host dispatch"
paragraph, "if worktree mode is ON and the Workflow tool is absent, STOP and
say so". plan-feature, cleanup-work and cleanup-allwork have no such line.
cleanup-work and cleanup-allwork already STOP in lean mode (their
`## Mode check (first)` section), so their new line goes right after that
check. Worktree mode stays Claude Code–only and unchanged on Claude Code. The
skill-semantics suite runs under Windows PowerShell 5.1: every string or regex
you add must be ASCII-only.

- [ ] **Step 1 (failing pins):** In `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`, immediately BEFORE the line `if ($failures.Count -gt 0) {`, add:
  ```powershell
  # --- worktree mode stops without the Workflow tool, at every entry point -------
  $cw = ReadDoc 'skills\cleanup-work\SKILL.md'
  $ca = ReadDoc 'skills\cleanup-allwork\SKILL.md'
  $noWorkflowStop = 'worktree mode is ON and the Workflow tool is absent, STOP|Workflow tool is not available in this session \(Codex or any other agent host without it\) and worktree mode is ON, STOP and say: worktree mode currently requires Claude Code \(see the parity record\)'
  foreach ($entry in @(@('execute-feature', $ef), @('quick-fix', $qf), @('plan-feature', $pf), @('cleanup-work', $cw), @('cleanup-allwork', $ca))) {
      Check "$($entry[0]) stops in worktree mode when the Workflow tool is absent" (($entry[1] -replace '\s+', ' ') -match $noWorkflowStop)
  }
  Check 'plan-feature: the worktree stop comes before the design work' ($pf.IndexOf('worktree mode currently requires Claude Code') -ge 0 -and $pf.IndexOf('worktree mode currently requires Claude Code') -lt $pf.IndexOf('## Gather first'))
  Check 'cleanup skills: the worktree stop sits right after the lean-mode check' ($cw.IndexOf('worktree mode currently requires Claude Code') -gt $cw.IndexOf('## Mode check') -and $cw.IndexOf('worktree mode currently requires Claude Code') -lt $cw.IndexOf('## Step 0') -and $ca.IndexOf('worktree mode currently requires Claude Code') -gt $ca.IndexOf('## Mode check') -and $ca.IndexOf('worktree mode currently requires Claude Code') -lt $ca.IndexOf('## Scope note'))
  ```
  If an earlier sub-plan reworded the execute-feature or quick-fix clause so the first alternative no longer matches, add the current wording of that clause (whitespace collapsed, regex-escaped) as a third `|` alternative instead — keeping the meaning "worktree mode ON + no Workflow tool → STOP".
- [ ] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → FAIL for `plan-feature`, `cleanup-work`, `cleanup-allwork` stops and the two placement checks; PASS for execute-feature and quick-fix; `FAILED: 5 assertion(s).`
- [ ] **Step 3 (plan-feature):** In `plugins/cogniva-dev/skills/plan-feature/SKILL.md`, insert immediately AFTER the `**Worktree dispatch (check first):**` paragraph (the one ending `author directly on the user's checkout and current branch.`), separated by one blank line:
  ```markdown
  **Host dispatch (check second):** if the Workflow tool is not available in
  this session (Codex or any other agent host without it) and worktree mode is
  ON, STOP and say: worktree mode currently requires Claude Code (see the
  parity record).
  ```
- [ ] **Step 4 (cleanup-work, cleanup-allwork):** In BOTH `plugins/cogniva-dev/skills/cleanup-work/SKILL.md` and `plugins/cogniva-dev/skills/cleanup-allwork/SKILL.md`, insert immediately AFTER the `## Mode check (first)` paragraph (the one ending `you)." and STOP.`), separated by one blank line:
  ```markdown
  **Host dispatch (check second):** if the Workflow tool is not available in
  this session (Codex or any other agent host without it) and worktree mode is
  ON, STOP and say: worktree mode currently requires Claude Code (see the
  parity record).
  ```
- [ ] **Step 5 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`, exit 0.
- [ ] **Step 6 (write ADR):** scan `docs/adr/` for the next free number and write ADR-C6 from this sub-plan's `## Candidate ADRs` verbatim — heading `# Worktree mode stops under Codex at every entry point` (no `ADR-C6` label), `**Provenance:** Suggested by agent`, then the body paragraph — to `docs/adr/NNNN-worktree-mode-stops-under-codex-at-every-entry-point.md` per `plugins/cogniva-dev/skills/adr/ADR-FORMAT.md`. Run `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/check-adrs.ps1 -Workspace .` → exit 0.
- [ ] **Step 7 (docs/codex.md):** In `plugins/cogniva-dev/docs/codex.md`, replace the whole bullet that begins `- **Worktree mode is Claude-only and unchanged.**` (through its last line) with the bullet below; if an earlier sub-plan reworded or moved it, replace the bullet or sentence that says worktree mode is Claude-only, wherever it now is:
  ```markdown
  - **Worktree mode is Claude Code only and unchanged there.** It requires the
    Workflow runtime, keeps mandatory per-task commits and persisted plans, and
    integrates by fast-forward. Every skill that would start, integrate or
    clean up worktree-mode work (plan-feature, execute-feature, quick-fix,
    cleanup-work, cleanup-allwork) stops with one line when worktree mode is on
    and the Workflow tool is absent, and the parity record marks worktree mode
    `unsupported` for Codex (ADR NNNN).
  ```
  using the number from Step 6.
- [ ] **Step 8 (parity record):** In `docs/host-parity.md` `## Capabilities` (columns `| ID | Capability | Kind | Covers | Claude Code | Codex | Evidence | Notes |`; `NNNN` is the number from Step 6):
  - row `worktree-mode` (`Covers` `mode:worktree`): set the `Codex` cell to `unsupported — stops at every entry point`. In its `Notes`, replace the Codex sentence (the one beginning `Codex: worktree execution needs the Workflow runtime`) with `Codex: stops at every entry point (ADR NNNN); not wanted; what it would need is in CrossHostParity Stage 3.` and keep the Claude Code sentence. Leave its `Claude Code` cell unchanged.
  - row `worktree-cleanup` (`Covers` `skill:cogniva-dev/cleanup-work, skill:cogniva-dev/cleanup-allwork`): keep the `Codex` cell `unsupported — worktree mode only`; replace its `Notes` with `Worktree-mode only. Under Codex both skills stop with one line when worktree mode is on (ADR NNNN); in lean mode they report nothing to do.`
  - row `plan-feature`: append to its `Notes`: ` In worktree mode it stops without the Workflow tool, so under Codex it runs in lean mode only (ADR NNNN).`
  Under `## Intentional asymmetries`, replace the bullet that begins `` - `worktree-mode`, `worktree-cleanup` — `` with:
  ```markdown
  - `worktree-mode`, `worktree-cleanup` — worktree mode is Claude Code only: it
    runs on the Workflow runtime, which Codex lacks (ADR 0029, ADR 0030). Under
    Codex every entry point that would start, integrate or clean up
    worktree-mode work stops with one line (ADR NNNN). Codex worktree mode is
    not wanted; the CrossHostParity plan's Stage 3 records what it would need.
  ```
  Then `pwsh -NoProfile -File scripts/check-host-parity.ps1` → a `host-parity: OK - …` line, exit 0.
- [ ] **Step 9 (host-neutrality ratchet):** `pwsh -NoProfile -File scripts/check-host-neutrality.ps1` → `host-neutrality: OK - …`, exit 0. The new Host dispatch lines name Codex, Claude Code and "the Workflow tool", none of which is one of the ratchet's tokens (`Workflow(` with a parenthesis is), so nothing should move. A `FAIL host-token-…` line for a file this task changed → reword the text it names.
- [ ] **Step 10 (commit):** `git add plugins/cogniva-dev/skills/plan-feature/SKILL.md plugins/cogniva-dev/skills/cleanup-work/SKILL.md plugins/cogniva-dev/skills/cleanup-allwork/SKILL.md plugins/cogniva-dev/docs/codex.md docs/host-parity.md plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1 docs/adr` then `git commit -m "fix(lifecycle): every worktree-mode entry point stops when the Workflow tool is absent"`

## Task 3: Green-gate result marker; a skipped gate is never a pass

**Files:**
- Modify: `plugins/cogniva-dev/scripts/run-green-gate.ps1`
- Modify: `plugins/cogniva-dev/scripts/run-gate-check.ps1`
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/quick-fix/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/execute-feature/HANDOFF.md`
- Modify: `plugins/cogniva-dev/skills/gate-check/SKILL.md`
- Test: `plugins/cogniva-dev/tests/run-green-gate/run-green-gate.tests.ps1`
- Test: `plugins/cogniva-dev/tests/run-gate-check/run-gate-check.tests.ps1`
- Test: `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`

Constraints: `run-green-gate.ps1` and `run-gate-check.ps1` are Windows
PowerShell 5.1 scripts and must STAY 5.1-compatible (no `??`, no `?:`, no
`-Parallel`, no pwsh-only APIs). Keep every existing output line and every
exit code: green-gate 0 green or skipped, 1 red, 2 usage/config error;
gate-check 0 pass, 1 fail, 2 inconclusive. New behaviour only: green-gate's
LAST stdout line is always `GREEN-GATE-RESULT: GREEN|SKIPPED|RED|ERROR`
(`SKIPPED` for an absent config AND for an empty command list; `ERROR` for
every exit-2 case the script itself reports); gate-check, when that marker is
`SKIPPED`, prints `SKIPPED: green gate not configured` and ends with
`PASS WITH SKIPS: …` instead of `PASS: mechanical gate checks completed.`,
still exit 0. (A call without the mandatory `-Repo` fails in PowerShell's
parameter binding before the script runs, so it prints no marker.)

- [ ] **Step 1 (failing tests — green gate):** Replace the content of `plugins/cogniva-dev/tests/run-green-gate/run-green-gate.tests.ps1` with:
  ```powershell
  # Dependency-free tests for the single green-gate implementation.
  $ErrorActionPreference = 'Stop'
  $here = Split-Path -Parent $MyInvocation.MyCommand.Path
  $plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
  $runner = Join-Path $plugin 'scripts\run-green-gate.ps1'
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-green-gate-" + [guid]::NewGuid().ToString('N'))
  $failures = @()

  function Check($label, $condition) {
      if ($condition) { Write-Host "  PASS  $label" }
      else { Write-Host "  FAIL  $label"; $script:failures += $label }
  }
  function Invoke-Runner([string]$repo, [string]$configPath) {
      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try {
          $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Repo $repo -ConfigPath $configPath 2>&1)
          $code = $LASTEXITCODE
      }
      finally { $ErrorActionPreference = $previous }
      # stdout lines only (stderr arrives as ErrorRecords), so "the last line" is the runner's own last stdout line.
      $stdout = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() })
      $last = if ($stdout.Count) { $stdout[$stdout.Count - 1] } else { '' }
      [pscustomobject]@{ Code = $code; Text = ($output -join "`n"); Last = $last }
  }

  try {
      New-Item -ItemType Directory -Path $root -Force | Out-Null
      $missing = Invoke-Runner $root (Join-Path $root 'missing.json')
      Check 'absent config skips successfully' ($missing.Code -eq 0 -and $missing.Text -match 'skipping the build/test gate')
      Check 'absent config ends with GREEN-GATE-RESULT: SKIPPED' ($missing.Last -eq 'GREEN-GATE-RESULT: SKIPPED')

      $emptyConfig = Join-Path $root 'empty.json'
      Set-Content -LiteralPath $emptyConfig -Encoding UTF8 -Value '{"commands":[]}'
      $empty = Invoke-Runner $root $emptyConfig
      Check 'empty command list is an intentional no-gate' ($empty.Code -eq 0 -and $empty.Text -match "'commands' is empty - intentional no-gate")
      Check 'empty command list ends with GREEN-GATE-RESULT: SKIPPED' ($empty.Last -eq 'GREEN-GATE-RESULT: SKIPPED')

      $greenConfig = Join-Path $root 'green.json'
      Set-Content -LiteralPath $greenConfig -Encoding UTF8 -Value '{"commands":[{"run":"exit 0","label":"green"}]}'
      $green = Invoke-Runner $root $greenConfig
      Check 'green command succeeds' ($green.Code -eq 0 -and $green.Text -match 'GREEN - all 1 command')
      Check 'green run ends with GREEN-GATE-RESULT: GREEN' ($green.Last -eq 'GREEN-GATE-RESULT: GREEN')

      $redConfig = Join-Path $root 'red.json'
      Set-Content -LiteralPath $redConfig -Encoding UTF8 -Value '{"commands":[{"run":"exit 3","label":"red"}]}'
      $red = Invoke-Runner $root $redConfig
      Check 'red command fails the gate' ($red.Code -eq 1 -and $red.Text -match 'RED - \[red\] exited 3')
      Check 'red run ends with GREEN-GATE-RESULT: RED' ($red.Last -eq 'GREEN-GATE-RESULT: RED')

      $badConfig = Join-Path $root 'bad.json'
      Set-Content -LiteralPath $badConfig -Encoding UTF8 -Value '{not-json'
      $bad = Invoke-Runner $root $badConfig
      Check 'invalid config is an error' ($bad.Code -eq 2 -and $bad.Text -match 'cannot parse')
      Check 'invalid config ends with GREEN-GATE-RESULT: ERROR' ($bad.Last -eq 'GREEN-GATE-RESULT: ERROR')

      $noRunConfig = Join-Path $root 'norun.json'
      Set-Content -LiteralPath $noRunConfig -Encoding UTF8 -Value '{"commands":[{"label":"no-run"}]}'
      $noRun = Invoke-Runner $root $noRunConfig
      Check 'a command without run is an error ending with GREEN-GATE-RESULT: ERROR' ($noRun.Code -eq 2 -and $noRun.Last -eq 'GREEN-GATE-RESULT: ERROR')

      $absentRepo = Invoke-Runner (Join-Path $root 'no-such-repo') $greenConfig
      Check 'a missing repo is an error ending with GREEN-GATE-RESULT: ERROR' ($absentRepo.Code -eq 2 -and $absentRepo.Last -eq 'GREEN-GATE-RESULT: ERROR')
  }
  finally {
      if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
  }

  if ($failures.Count) { exit 1 }
  Write-Host 'All run-green-gate assertions passed.'
  ```
- [ ] **Step 2 (failing tests — gate-check):** Replace the content of `plugins/cogniva-dev/tests/run-gate-check/run-gate-check.tests.ps1` with the version below. The existing pass case now runs in a fixture WITH a committed green-gate config (a fixture without one is the new skipped case):
  ```powershell
  # Dependency-free behavioral tests for workflow-neutral gate orchestration.
  $ErrorActionPreference = 'Stop'
  $here = Split-Path -Parent $MyInvocation.MyCommand.Path
  $plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
  $runner = Join-Path $plugin 'scripts\run-gate-check.ps1'
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-gate-check-" + [guid]::NewGuid().ToString('N'))
  $bare = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-gate-check-bare-" + [guid]::NewGuid().ToString('N'))
  $failures = @()

  function Check($label, $condition) {
      if ($condition) { Write-Host "  PASS  $label" }
      else { Write-Host "  FAIL  $label"; $script:failures += $label }
  }
  function Invoke-Gate([string]$target, [string]$repo = $root) {
      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try {
          $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Repo $repo -TargetBranch $target 2>&1)
          $code = $LASTEXITCODE
      }
      finally { $ErrorActionPreference = $previous }
      [pscustomobject]@{ Code = $code; Text = ($output -join "`n") }
  }
  function Get-RepositoryState {
      [pscustomobject]@{
          Head = (& git -C $root rev-parse HEAD).Trim()
          Branch = (& git -C $root branch --show-current).Trim()
          Status = ((& git -C $root status --porcelain) -join "`n")
          Refs = ((& git -C $root show-ref) -join "`n")
          Worktrees = ((& git -C $root worktree list --porcelain) -join "`n")
      }
  }
  function New-Fixture([string]$Path, [bool]$WithGreenGate) {
      New-Item -ItemType Directory -Path $Path -Force | Out-Null
      & git -C $Path init -q
      & git -C $Path config user.email 'gate-check-test@example.invalid'
      & git -C $Path config user.name 'Gate Check Test'
      & git -C $Path config core.autocrlf false
      Set-Content -LiteralPath (Join-Path $Path 'README.md') -Encoding UTF8 -Value 'fixture'
      if ($WithGreenGate) {
          New-Item -ItemType Directory -Path (Join-Path $Path '.claude\cogniva-dev') -Force | Out-Null
          Set-Content -LiteralPath (Join-Path $Path '.claude\cogniva-dev\green-gate.json') -Encoding UTF8 -Value '{"commands":[{"run":"exit 0","label":"ok"}]}'
      }
      & git -C $Path add -A
      & git -C $Path commit -qm 'fixture'
  }

  try {
      New-Fixture $root $true
      $branch = (& git -C $root branch --show-current).Trim()
      $before = Get-RepositoryState

      $green = Invoke-Gate $branch
      $afterGreen = Get-RepositoryState
      Check 'resolvable target branch produces a pass' ($green.Code -eq 0 -and $green.Text -match 'PASS: mechanical gate checks completed')
      Check 'a configured green gate reports no SKIPPED line' ($green.Text -notmatch 'SKIPPED:')
      Check 'gate orchestration leaves repository lifecycle state unchanged' (($before | ConvertTo-Json -Compress) -eq ($afterGreen | ConvertTo-Json -Compress))

      $unknown = Invoke-Gate 'does-not-exist'
      $afterUnknown = Get-RepositoryState
      Check 'unresolved target is inconclusive rather than certified' ($unknown.Code -eq 2 -and $unknown.Text -match 'INCONCLUSIVE:' -and $unknown.Text -match 'NOT CERTIFIED:' -and $unknown.Text -notmatch 'PASS: mechanical gate checks completed')
      Check 'inconclusive gate leaves repository lifecycle state unchanged' (($before | ConvertTo-Json -Compress) -eq ($afterUnknown | ConvertTo-Json -Compress))

      New-Fixture $bare $false
      $bareBranch = (& git -C $bare branch --show-current).Trim()
      $skipped = Invoke-Gate $bareBranch $bare
      Check 'an unconfigured green gate is reported as SKIPPED, not passed' ($skipped.Code -eq 0 -and $skipped.Text -match 'SKIPPED: green gate not configured' -and $skipped.Text -notmatch 'PASS: mechanical gate checks completed' -and $skipped.Text -match 'PASS WITH SKIPS:')
  }
  finally {
      foreach ($dir in @($root, $bare)) { if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force } }
  }

  if ($failures.Count) { exit 1 }
  Write-Host 'All run-gate-check assertions passed.'
  ```
- [ ] **Step 3 (failing pins):** In `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`, immediately BEFORE the line `if ($failures.Count -gt 0) {`, add:
  ```powershell
  # --- a skipped green gate is never a pass ---------------------------------------
  Check 'execute-feature: GREEN-GATE-RESULT: SKIPPED is not a pass' ((($ef -replace '\s+', ' ') -match '`GREEN-GATE-RESULT: SKIPPED` is not a pass') -and (($ef -replace '\s+', ' ') -match 'report it under Skipped validations'))
  Check 'execute-feature: the green gate is read by its last line' (($ef -replace '\s+', ' ') -match 'Read its LAST line, `GREEN-GATE-RESULT: GREEN\|SKIPPED\|RED\|ERROR`')
  Check 'quick-fix: GREEN-GATE-RESULT: SKIPPED is not a pass' (($qf -replace '\s+', ' ') -match '`GREEN-GATE-RESULT: SKIPPED` is not a pass . report it under Skipped validations')
  Check 'HANDOFF: a green gate that reported SKIPPED goes under Skipped validations' (($handoff -replace '\s+', ' ') -match '\*\*Skipped validations\*\* . anything not run, and why, including a green gate that reported SKIPPED')
  Check 'gate-check: SKIPPED is never reported as passed' (($gc -replace '\s+', ' ') -match 'SKIPPED: green gate not configured' -and ($gc -replace '\s+', ' ') -match 'never as passed')
  ```
- [ ] **Step 4 (run them, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/run-green-gate/run-green-gate.tests.ps1` → the seven `ends with GREEN-GATE-RESULT` / `ERROR` checks FAIL, exit 1. `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/run-gate-check/run-gate-check.tests.ps1` → `FAIL  an unconfigured green gate is reported as SKIPPED, not passed`, exit 1. `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → the five new checks FAIL, exit 1.
- [ ] **Step 5 (implement run-green-gate.ps1):** Replace the content of `plugins/cogniva-dev/scripts/run-green-gate.ps1` with (every existing line kept; additions are the header comment, the marker lines and `Fail`'s marker):
  ```powershell
  # Runs a repo's configured green gate: .claude/cogniva-dev/green-gate.json.
  #
  # This is the single implementation of green-gate command semantics. Consumers
  # include gate-check and the heavyweight lifecycle skills.
  #
  # The LAST line of stdout is always one result marker:
  #   GREEN-GATE-RESULT: GREEN    every command exited 0 (exit 0)
  #   GREEN-GATE-RESULT: SKIPPED  no config, or an empty 'commands' list (exit 0) -
  #                               the build/test gate did NOT run; never report it as a pass
  #   GREEN-GATE-RESULT: RED      a command failed (exit 1)
  #   GREEN-GATE-RESULT: ERROR    usage or config error (exit 2)
  # Windows PowerShell 5.1 compatible.
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)][string]$Repo,
      [string]$ConfigPath
  )
  $ErrorActionPreference = 'Stop'

  function Fail($Message) {
      [Console]::Error.WriteLine("green-gate: $Message")
      Write-Output 'GREEN-GATE-RESULT: ERROR'
      exit 2
  }

  if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
  if (-not $ConfigPath) { $ConfigPath = Join-Path $Repo '.claude/cogniva-dev/green-gate.json' }

  if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
      Write-Output 'green-gate: no .claude/cogniva-dev/green-gate.json in this repo - skipping the build/test gate.'
      Write-Output 'GREEN-GATE-RESULT: SKIPPED'
      exit 0
  }

  try { $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json }
  catch { Fail "cannot parse $ConfigPath as JSON: $($_.Exception.Message)" }

  if ($null -eq $config.commands) { Fail "config $ConfigPath has no 'commands' array" }
  $commands = @($config.commands)
  if ($commands.Count -eq 0) {
      Write-Output "green-gate: 'commands' is empty - intentional no-gate."
      Write-Output 'GREEN-GATE-RESULT: SKIPPED'
      exit 0
  }

  $number = 0
  Push-Location -LiteralPath $Repo
  try {
      foreach ($command in $commands) {
          $number++
          if (-not $command.run) { Fail "commands[$($number - 1)] has no 'run'" }
          $label = if ($command.label) { $command.label } else { "command $number" }
          Write-Output ""
          Write-Output "green-gate: [$label] $($command.run)"
          if ($command.note) { Write-Output "green-gate:   note: $($command.note)" }
          $priorPreference = $ErrorActionPreference
          $ErrorActionPreference = 'Continue'
          try {
              & powershell -NoProfile -Command $command.run 2>&1 | ForEach-Object { Write-Output ([string]$_) }
              $exitCode = $LASTEXITCODE
          }
          finally { $ErrorActionPreference = $priorPreference }
          if ($exitCode -ne 0) {
              Write-Output ""
              Write-Output "green-gate: RED - [$label] exited $exitCode. Do NOT integrate until this passes."
              Write-Output 'GREEN-GATE-RESULT: RED'
              exit 1
          }
      }
  }
  finally { Pop-Location }

  Write-Output ""
  Write-Output "green-gate: GREEN - all $number command(s) exited 0."
  Write-Output 'GREEN-GATE-RESULT: GREEN'
  exit 0
  ```
- [ ] **Step 6 (implement run-gate-check.ps1):** In `plugins/cogniva-dev/scripts/run-gate-check.ps1`:
  1. After the line `$inconclusive = @()` add the line `$skipped = @()`.
  2. Replace everything from the line `$green = Invoke-Native 'green gate' { …` to the end of the file with:
     ```powershell
     $green = Invoke-Native 'green gate' { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $plugin 'scripts/run-green-gate.ps1') -Repo $repoFull }
     if ($green.Code -ne 0) { $failures += "green gate exited $($green.Code)" }
     # The runner's last GREEN-GATE-RESULT line says whether the gate ran at all.
     $greenResult = @($green.Lines | Where-Object { $_ -match '^GREEN-GATE-RESULT: ' } | Select-Object -Last 1)
     if ($green.Code -eq 0 -and $greenResult.Count -and $greenResult[0] -match 'SKIPPED') { $skipped += 'green gate not configured' }

     foreach ($warning in $warnings) { Write-Output "WARN: $warning" }
     foreach ($reason in $skipped) { Write-Output "SKIPPED: $reason" }
     if ($failures.Count) {
         foreach ($failure in $failures) { Write-Output "FAIL: $failure" }
         exit 1
     }
     if ($inconclusive.Count) {
         foreach ($reason in $inconclusive) { Write-Output "INCONCLUSIVE: $reason" }
         Write-Output 'NOT CERTIFIED: commit readiness cannot be certified until the target branch is resolvable or explicitly supplied.'
         exit 2
     }
     if ($skipped.Count) {
         Write-Output 'PASS WITH SKIPS: the checks that ran passed; each SKIPPED check did not run and is not a pass.'
         exit 0
     }
     Write-Output 'PASS: mechanical gate checks completed.'
     exit 0
     ```
  Exit codes are unchanged (a skipped green gate still exits 0); only the final line differs.
- [ ] **Step 7 (skill wording):**
  1. `plugins/cogniva-dev/skills/execute-feature/SKILL.md`, Step 4 item 6 (**Green gate**): replace
     ```markdown
        Exit `0` is green or a legitimate skip (absent config or an empty command
        list); exit `1` is red; exit `2` is a usage/config error. For either
     ```
     with
     ```markdown
        Read its LAST line, `GREEN-GATE-RESULT: GREEN|SKIPPED|RED|ERROR`:
        `GREEN` (exit `0`) passed. `SKIPPED` (exit `0`: absent config or an
        empty command list) means the build/test gate did not run —
        `GREEN-GATE-RESULT: SKIPPED` is not a pass — report it under Skipped
        validations and never call the run green. `RED` (exit `1`) failed;
        `ERROR` (exit `2`) is a usage/config error. For either
     ```
  2. `plugins/cogniva-dev/skills/quick-fix/SKILL.md`, Step 2: replace
     ```markdown
     "<plugin>/scripts/run-green-gate.ps1" -Repo "<WORKSPACE>"`; exit 0 = green or
     legitimate skip, 1 = red, 2 = config error) → under `commits=final`, NOW the single implementation commit —
     ```
     with
     ```markdown
     "<plugin>/scripts/run-green-gate.ps1" -Repo "<WORKSPACE>"`; read its last
     line: `GREEN-GATE-RESULT: GREEN` passed; `GREEN-GATE-RESULT: SKIPPED` is not a pass — report it under Skipped validations;
     `RED` (exit 1) or `ERROR` (exit 2) stops landing) → under `commits=final`, NOW the single implementation commit —
     ```
  3. `plugins/cogniva-dev/skills/execute-feature/HANDOFF.md`: replace the line `- **Skipped validations** — anything not run, and why.` with
     ```markdown
     - **Skipped validations** — anything not run, and why, including a green gate
       that reported SKIPPED (`GREEN-GATE-RESULT: SKIPPED`: no config or an empty
       command list).
     ```
  4. `plugins/cogniva-dev/skills/gate-check/SKILL.md`: append this paragraph at the end of the file (after a blank line):
     ```markdown
     A repository with no green-gate config, or an empty command list, prints
     `SKIPPED: green gate not configured` and ends with `PASS WITH SKIPS:`
     instead of `PASS:`. Report the build/test gate as skipped, never as passed.
     ```
- [ ] **Step 8 (run until green):** the three suites from Step 4 → `All run-green-gate assertions passed.`, `All run-gate-check assertions passed.`, `All skill-semantics assertions passed.`; then `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → last line `GREEN-GATE-RESULT: GREEN`.
- [ ] **Step 9 (commit):** `git add plugins/cogniva-dev/scripts/run-green-gate.ps1 plugins/cogniva-dev/scripts/run-gate-check.ps1 plugins/cogniva-dev/skills/execute-feature/SKILL.md plugins/cogniva-dev/skills/quick-fix/SKILL.md plugins/cogniva-dev/skills/execute-feature/HANDOFF.md plugins/cogniva-dev/skills/gate-check/SKILL.md plugins/cogniva-dev/tests/run-green-gate/run-green-gate.tests.ps1 plugins/cogniva-dev/tests/run-gate-check/run-gate-check.tests.ps1 plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` then `git commit -m "feat(green-gate): GREEN-GATE-RESULT marker; a skipped gate is reported as skipped, never as a pass"`

## Task 4: Status skills see ephemeral plans

**Files:**
- Modify: `plugins/cogniva-dev/skills/feature-status/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/module-status/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/repo-status/SKILL.md`
- Modify: `docs/host-parity.md`
- Test: `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`

Context: lean mode's default `plan=ephemeral` writes plans to
`.plans-staging/<Module>/<Feature>/` (excluded through `.git/info/exclude`,
never committed). A converted freeform plan gets a `<basename>.tasks.md` beside
it, and that is the file the run ticks. Lean runs keep no `state.md`. The three
status skills scan only `docs/plans/` today. The skill-semantics suite runs
under Windows PowerShell 5.1: every string or regex you add must be ASCII-only.

- [ ] **Step 1 (failing pins):** In `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`, immediately BEFORE the line `if ($failures.Count -gt 0) {`, add:
  ```powershell
  # --- status skills see ephemeral plans ------------------------------------------
  foreach ($entry in @(@('feature-status', 'skills\feature-status\SKILL.md'), @('module-status', 'skills\module-status\SKILL.md'), @('repo-status', 'skills\repo-status\SKILL.md'))) {
      $statusFlat = (ReadDoc $entry[1]) -replace '\s+', ' '
      Check "$($entry[0]) scans .plans-staging for ephemeral plans" ($statusFlat -match '\.plans-staging/' -and $statusFlat -match 'plan=ephemeral')
      Check "$($entry[0]) marks ephemeral features" ($statusFlat -match '\(ephemeral . this clone only\)')
      Check "$($entry[0]) takes status from checkboxes when there is no state.md" ($statusFlat -match 'no `state\.md` \(lean runs keep none\)' -and $statusFlat -match '`in-progress` \(some done\)')
  }
  ```
- [ ] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → nine new FAIL lines, exit 1.
- [ ] **Step 3 (feature-status):** In `plugins/cogniva-dev/skills/feature-status/SKILL.md`:
  1. Immediately after Step 1's last line (`zero-task plan.`), add these lines, indented as part of Step 1:
     ```markdown
        Also scan `.plans-staging/<Module>/*/` (or `.plans-staging/*/*/` for
        all): lean mode's default `plan=ephemeral` keeps plans there, untracked
        and local to this clone. Treat each folder holding a `<Feature>-plan.md`
        exactly like a `docs/plans/` feature — same task and checkbox rules;
        when a converted `<basename>.tasks.md` sits beside the plan, count that
        file, because it is the one the run ticks — and mark it
        `(ephemeral — this clone only)`. A feature in both places is listed
        once, from `docs/plans/`.
     ```
  2. Immediately after Step 3's last line (`clean target tree).`), add, indented as part of Step 3:
     ```markdown
        A feature with no `state.md` (lean runs keep none) takes its status
        from its checkboxes: `planned` (no task done), `in-progress` (some
        done), `done` (all done).
     ```
  3. In the `## Output` code block, replace the line
     `  <Feature>   <Status>   <done>/<total>   next: Task <N> "<title>"   [⛔ gate at Task <G>]   [worktree: <path>]   [integration: queued]`
     with
     `  <Feature>   <Status>   <done>/<total>   next: Task <N> "<title>"   [⛔ gate at Task <G>]   [worktree: <path>]   [integration: queued]   [(ephemeral — this clone only)]`
- [ ] **Step 4 (module-status):** In `plugins/cogniva-dev/skills/module-status/SKILL.md`:
  1. Replace the line `Scan `docs/plans/<Module>/`:` with:
     ```markdown
     Scan `docs/plans/<Module>/`, and also `.plans-staging/<Module>/` for
     feature folders (lean mode's default `plan=ephemeral` keeps plans there,
     untracked and local to this clone):
     ```
  2. Immediately after item 1's last line (`` `Integration:` (e.g. `queued`). ``), add, indented as part of item 1:
     ```markdown
        A feature folder under `.plans-staging/<Module>/` gets the same scan
        (when a converted `<basename>.tasks.md` sits beside the plan, count that
        file) and is marked `(ephemeral — this clone only)`; a feature in both
        places is listed once, from `docs/plans/`. A feature with no
        `state.md` (lean runs keep none) takes its status from its checkboxes:
        `planned` (no task done), `in-progress` (some done), `done` (all done).
     ```
  3. In the `## Output` code block, replace the line
     `    <Feature>   <Status>   <done>/<total>   next: Task <N> "<title>"   [⛔ gate at Task <G>]   [integration: queued]`
     with
     `    <Feature>   <Status>   <done>/<total>   next: Task <N> "<title>"   [⛔ gate at Task <G>]   [integration: queued]   [(ephemeral — this clone only)]`
- [ ] **Step 5 (repo-status):** In `plugins/cogniva-dev/skills/repo-status/SKILL.md`:
  1. Replace the line `Scan all of `docs/plans/`:` with:
     ```markdown
     Scan all of `docs/plans/`, and also `.plans-staging/` for feature folders
     (lean mode's default `plan=ephemeral` keeps plans there, untracked and
     local to this clone):
     ```
  2. Immediately after item 1's last line (`` - `<Module>/BACKLOG.md`: open vs resolved loose-item counts. ``), add, indented as part of item 1:
     ```markdown
        Feature folders under `.plans-staging/<Module>/` count like
        `docs/plans/` features (same checkbox rules; when a converted
        `<basename>.tasks.md` sits beside the plan, count that file), and a
        Module that exists only there still gets a row. A feature with no
        `state.md` (lean runs keep none) takes its status from its checkboxes:
        `planned` (no task done), `in-progress` (some done), `done` (all done).
        Wherever such a feature is named (for example in Action items), mark it
        `(ephemeral — this clone only)`; a feature in both places counts once,
        from `docs/plans/`.
     ```
- [ ] **Step 6 (parity record):** In `docs/host-parity.md` `## Capabilities`, row `plan-status`: in its `Notes`, replace the sentence `Ephemeral plans in `.plans-staging/` are not scanned yet (CrossHostParity 09).` with `Ephemeral plans in `.plans-staging/` are listed and marked as local to the clone.` (if the sentence is worded differently, replace the sentence that says ephemeral plans are not scanned). Then `pwsh -NoProfile -File scripts/check-host-parity.ps1` → `host-parity: OK - …`, exit 0.
- [ ] **Step 7 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`, exit 0; `pwsh -NoProfile -File scripts/check-host-neutrality.ps1` → `host-neutrality: OK - …`.
- [ ] **Step 8 (commit):** `git add plugins/cogniva-dev/skills/feature-status/SKILL.md plugins/cogniva-dev/skills/module-status/SKILL.md plugins/cogniva-dev/skills/repo-status/SKILL.md plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1 docs/host-parity.md` then `git commit -m "feat(status): feature-, module- and repo-status list ephemeral plans from .plans-staging"`

## Task 5: Install guidance for both agent hosts; diagnostics remedy; full green gate

**Files:**
- Modify: `plugins/cogniva-dev/skills/repo-init/SKILL.md`
- Modify: `docs/strategy.md`
- Modify: `docs/host-parity.md`
- Modify (only if the diagnostics triage selected it): `plugins/cogniva-dev/docs/codex.md`, `plugins/cogniva-dev/skills/quick-fix/SKILL.md`
- Test: `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`

Context: today repo-init and `docs/strategy.md` tell the user to install only
`cogniva-skills`, and only with Claude Code commands. The marketplace is named
`cogniva` and hosted at `cogniva/cogniva-skills`. Codex registers a
marketplace with `codex plugin marketplace add <owner/repo | ./path>`,
installs plugins from its `/plugins` browser, shows a new plugin's skills only
in a NEW session, and runs plugin hooks only after the user trusts them in
`/hooks`. The skill-semantics suite runs under Windows PowerShell 5.1: every
string or regex you add must be ASCII-only.

- [ ] **Step 1 (failing pins):** In `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`, immediately BEFORE the line `if ($failures.Count -gt 0) {`, add:
  ```powershell
  # --- install guidance: both plugins, both agent hosts ---------------------------
  $strategy = ReadDoc '..\..\docs\strategy.md'
  foreach ($entry in @(@('repo-init', $ri), @('docs/strategy.md', $strategy))) {
      $installFlat = $entry[1] -replace '\s+', ' '
      Check "$($entry[0]) installs both plugins under Claude Code" ($installFlat -match '/plugin marketplace add cogniva/cogniva-skills' -and $installFlat -match '/plugin install cogniva-dev@cogniva' -and $installFlat -match '/plugin install cogniva-skills@cogniva')
      Check "$($entry[0]) installs both plugins under Codex" ($installFlat -match 'codex plugin marketplace add cogniva/cogniva-skills' -and $installFlat -match '`/plugins`' -and $installFlat -match 'new Codex session' -and $installFlat -match '`/hooks`')
  }
  ```
- [ ] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → four new FAIL lines, exit 1.
- [ ] **Step 3 (repo-init):** In `plugins/cogniva-dev/skills/repo-init/SKILL.md`, replace the whole numbered step that recommends installing the plugin (step 11 at planning time: `11. Recommend the user install this plugin in the new repo:` and its continuation line, ending before `12. Commit everything`) with:
  ```markdown
  11. Recommend the user install both Cogniva plugins, `cogniva-dev` and
      `cogniva-skills`, on each agent host they use in the new repo:
      - Claude Code: `/plugin marketplace add cogniva/cogniva-skills` (or the
        path of your local clone), then `/plugin install cogniva-dev@cogniva`
        and `/plugin install cogniva-skills@cogniva`.
      - Codex: `codex plugin marketplace add cogniva/cogniva-skills` (or the
        path of your local clone), install both plugins from the `/plugins`
        browser, start a new Codex session (a new plugin's skills appear only
        there), and trust the plugin hooks via `/hooks`.
  ```
  Keep the step's number as it is in the file if an earlier sub-plan renumbered the steps.
- [ ] **Step 4 (strategy):** In `docs/strategy.md`, replace the numbered list under `## Consuming in a new repo` (the three lines `1. `/plugin marketplace add …`, `2. `/plugin install cogniva-skills@cogniva``, `3. Run the repo-init skill.`) with:
  ```markdown
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
  ```
- [ ] **Step 5 (diagnostics remedy — only if selected):** Open `docs/host-parity/codex-diagnostics.md`, find its triage (decision) table, and look for the row about `.git` being read-only in Codex's sandbox (it breaks quick-fix's Step 0 snapshot, which writes git objects, plus commits and `.git/info/exclude`). If that row's `Where` column does NOT name `09`, skip this step entirely and write "no 09 sandbox remedy selected" in the commit message body. If it names `09`, read the report's answer under **Q3** and copy the setting or approval it records VERBATIM — call it SETTING (for example a `config.toml` key and value, or the approval choice to make). This is the only value this plan takes from the report. Then:
  1. In `plugins/cogniva-dev/docs/codex.md`, insert this section immediately BEFORE the `## Repository CLAUDE.md under Codex` heading, with SETTING substituted:
     ```markdown
     ## Codex sandbox: `.git` must be writable

     quick-fix's Step 0 snapshot (`check-structural-changes.ps1 -Snapshot`)
     writes git objects into `.git`; `commits=task|final` and `plan=ephemeral`
     (which appends to `.git/info/exclude`) write there too. Codex's sandbox
     can keep `.git` read-only, and then quick-fix stops before dispatch. Allow
     it with: SETTING. Then start a new Codex session.
     ```
  2. In `plugins/cogniva-dev/skills/quick-fix/SKILL.md` Step 0, immediately after the sentence ending `without a valid `START_TREE` the structural check cannot run.`, insert (SETTING substituted): ` If it failed because the agent host's sandbox keeps `.git` read-only, tell the user to allow it with: SETTING.`
  3. Add a pin immediately BEFORE `if ($failures.Count -gt 0) {` in the skill-semantics suite: `Check 'quick-fix and docs/codex.md name the .git sandbox setting' ((($qf -replace '\s+', ' ') -match 'sandbox keeps `\.git` read-only') -and $docs -match '## Codex sandbox: `\.git` must be writable')`.
- [ ] **Step 6 (parity record):** In `docs/host-parity.md` `## Capabilities`, row `repo-init`: in its `Notes`, replace the sentence `Its install guidance is Claude Code-only (CrossHostParity 09).` with `Its install guidance covers both plugins on both agent hosts.` (if worded differently, replace the sentence that says the install guidance is Claude Code-only). If Step 5 applied the sandbox remedy, also append to the `quick-fix` row's `Notes`: ` docs/codex.md and quick-fix Step 0 name the setting that makes .git writable.` Then `pwsh -NoProfile -File scripts/check-host-parity.ps1` → `host-parity: OK - …`, exit 0.
- [ ] **Step 7 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`, exit 0; `pwsh -NoProfile -File scripts/check-host-neutrality.ps1` → `host-neutrality: OK - …` (the install commands use `/plugin` and `codex plugin`, which are not ratchet tokens; a `FAIL host-token-…` line for a file this task changed → reword the text it names).
- [ ] **Step 8 (full green gate):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → `green-gate: GREEN - all N command(s) exited 0.` followed by the last line `GREEN-GATE-RESULT: GREEN`. Any RED → fix the cause inside this sub-plan's files and re-run until GREEN.
- [ ] **Step 9 (commit):** `git add plugins/cogniva-dev/skills/repo-init/SKILL.md docs/strategy.md docs/host-parity.md plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` (plus `plugins/cogniva-dev/docs/codex.md` and `plugins/cogniva-dev/skills/quick-fix/SKILL.md` if Step 5 changed them) then `git commit -m "docs(install): both plugins on both agent hosts; Codex sandbox remedy where the diagnostics selected it"`
