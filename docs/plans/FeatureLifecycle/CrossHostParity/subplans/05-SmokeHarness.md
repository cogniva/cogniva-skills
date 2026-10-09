# 05 SmokeHarness — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/CrossHostParity
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** A repeatable smoke harness that runs the same nine lifecycle
scenarios on Claude Code and on Codex against a throwaway fixture repository,
judges each outcome from git and file state, and writes the result as a smoke
record; plus a Node harness that runs the execute-feature Workflow template
without the Workflow runtime.

**Architecture:** Everything lives under `plugins/cogniva-dev/tests/` and is
PowerShell 7 (ADR 0039) or dependency-free Node. `host-smoke/` holds nine
scenario folders (`scenario.json`, optional `plan.md` / `pasted-plan.md`), the
fixture generator `new-smoke-fixture.ps1` (records the start state in the
fixture's git-excluded `.smoke/`), the deterministic checker
`assert-smoke-outcome.ps1`, the headless driver `invoke-host-smoke.ps1`
(Claude Code `claude -p`, Codex `codex.exe exec`; not gated, costs tokens) and
a gated self-test that simulates outcomes with plain git and file operations.
`workflow-template/run-template.mjs` evaluates
`templates/execute-feature.workflow.js` as an AsyncFunction body with stubbed
`args`/`phase`/`log`/`agent`; its gated suite pins dispatch, stop and prompt
behaviour, and its exported API is reused by sub-plan 07. Two gate labels:
`smoke-assertions`, `workflow-template`.

Decisions this sub-plan fixes (from the manifest and this design):
- Codex binary (manifest unresolved decision 2): default (a), the newest
  `codex.exe` bundled with the VS Code extension, overridable with `-CodexExe`.
- Scenario-file keys beyond the shared format: `expect.fileStartsWith`
  (object path → literal; used by INSTR), top-level `resumeExpect` (EF-GATE's
  second run, checked with `-Resume`), and top-level `argsFile` (POLICY's
  pasted plan, appended to the arguments on the next line).
- A gate task under `commits=task` is dispatched like any other task: its
  agent ticks its own boxes and commits (the Workflow template's prompt and
  `CODEX.md`'s frame both carry the commit rule for every task), and the run
  then stops. EF-GATE therefore expects 2 commits after the first run and 3
  after the second.
- Fixture function names use approved PowerShell verbs (`Get-Difference`,
  `Get-Product`, `Get-Quotient`) so no task conflicts with the fixture's own
  nested rule "Functions in this folder use approved PowerShell verbs.".
- Each fixture `AGENTS.md` has a `CLAUDE.md` beside it containing
  `@AGENTS.md` (root and `src/Calc/`), so the nested rule reaches Claude Code
  the way the root one does; INSTR checks both canaries.
- Literal message checks are case-sensitive. QF-STRUCT rejects the fact-line
  marker `dependency-added UNEXPECTED`, not the bare word, which a handoff
  may use in prose.

**Read these first:** `plugins/cogniva-dev/skills/quick-fix/SKILL.md`,
`plugins/cogniva-dev/skills/execute-feature/SKILL.md`, `CODEX.md`, `HANDOFF.md`;
`plugins/cogniva-dev/templates/execute-feature.workflow.js`;
`plugins/cogniva-dev/scripts/check-structural-changes.ps1`,
`adopt-architecture-profile.ps1`, `parse-plan-tasks.ps1`;
`plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1`
(suite style); `.claude/cogniva-dev/green-gate.json`.

## File structure (locked)

```
plugins/cogniva-dev/tests/host-smoke/scenarios/QF-NONE/scenario.json      # quick-fix commits=none
plugins/cogniva-dev/tests/host-smoke/scenarios/QF-FINAL/scenario.json     # quick-fix commits=final
plugins/cogniva-dev/tests/host-smoke/scenarios/EF-TWO/scenario.json       # two-task execute-feature commits=task
plugins/cogniva-dev/tests/host-smoke/scenarios/EF-TWO/plan.md             # its seeded plan
plugins/cogniva-dev/tests/host-smoke/scenarios/EF-BLOCKED/scenario.json   # blocked first task
plugins/cogniva-dev/tests/host-smoke/scenarios/EF-BLOCKED/plan.md         # its seeded plan
plugins/cogniva-dev/tests/host-smoke/scenarios/EF-GATE/scenario.json      # gate stop, then resume (resumeExpect)
plugins/cogniva-dev/tests/host-smoke/scenarios/EF-GATE/plan.md            # its seeded plan
plugins/cogniva-dev/tests/host-smoke/scenarios/QF-STRUCT/scenario.json    # expected structural change (dotnet)
plugins/cogniva-dev/tests/host-smoke/scenarios/POLICY/scenario.json       # branch-policy stop before any write
plugins/cogniva-dev/tests/host-smoke/scenarios/POLICY/pasted-plan.md      # the plan pasted into the prompt
plugins/cogniva-dev/tests/host-smoke/scenarios/HOOKS/scenario.json        # worktree-mode primary edit denied
plugins/cogniva-dev/tests/host-smoke/scenarios/INSTR/scenario.json        # root + nested AGENTS.md canary
plugins/cogniva-dev/tests/host-smoke/new-smoke-fixture.ps1                # builds a fixture, records .smoke/ start state
plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.ps1             # deterministic outcome checks per expect key
plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1                # headless driver + smoke records (not gated)
plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1       # gated self-test (smoke-assertions)
plugins/cogniva-dev/tests/host-smoke/README.md                            # runbook: install, headless, GUI, records, cost
plugins/cogniva-dev/tests/workflow-template/run-template.mjs              # runs the Workflow template in Node (exported API)
plugins/cogniva-dev/tests/workflow-template/workflow-template.tests.ps1   # gated template suite (workflow-template)
.claude/cogniva-dev/green-gate.json                                       # + smoke-assertions, + workflow-template
```

## Task 1: Scenarios and the fixture generator

**Files:**
- Create: the nine `plugins/cogniva-dev/tests/host-smoke/scenarios/<ID>/scenario.json`, `scenarios/EF-TWO/plan.md`, `scenarios/EF-BLOCKED/plan.md`, `scenarios/EF-GATE/plan.md`, `scenarios/POLICY/pasted-plan.md`
- Create: `plugins/cogniva-dev/tests/host-smoke/new-smoke-fixture.ps1`
- Test: `plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1`

File contents below are indented two spaces so they sit inside their step;
write every file WITHOUT that indent (a PowerShell here-string's closing `'@`
must end up in column 0). Write the files with LF line endings and UTF-8
without a BOM (the repo's `.gitattributes` turns `*.ps1` into CRLF on
checkout; that is fine).

- [ ] **Step 1 (failing test):** Create `plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1` with exactly:
  ```powershell
  #Requires -Version 7.0
  # Dependency-free tests for the agent-host smoke harness: the scenario files,
  # the fixture generator, the outcome assertions (outcomes simulated with plain
  # git and file operations - no agent, no model) and the driver's -DryRun output.
  $ErrorActionPreference = 'Stop'
  $here = $PSScriptRoot
  $plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
  $generator = Join-Path $here 'new-smoke-fixture.ps1'
  $assert = Join-Path $here 'assert-smoke-outcome.ps1'
  $driver = Join-Path $here 'invoke-host-smoke.ps1'
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-host-smoke-" + [guid]::NewGuid().ToString('N'))
  $failures = @()
  $ids = @('QF-NONE', 'QF-FINAL', 'EF-TWO', 'EF-BLOCKED', 'EF-GATE', 'QF-STRUCT', 'POLICY', 'HOOKS', 'INSTR')
  $knownKeys = @('commitsSinceStart', 'branch', 'changedPaths', 'unchangedPaths', 'unrelatedPreserved', 'planTicked', 'planUnticked', 'finalMessageContains', 'finalMessageNotContains', 'handoffSections', 'noNewFiles', 'gitInfoExcludeUnchanged', 'fileStartsWith')

  function Check($label, $condition) {
      if ($condition) { Write-Host "  PASS  $label" }
      else { Write-Host "  FAIL  $label"; $script:failures += $label }
  }
  function Invoke-Pwsh([string]$Script, [string[]]$Arguments) {
      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try {
          $lines = @(& pwsh -NoProfile -File $Script @Arguments 2>&1)
          $code = $LASTEXITCODE
      }
      finally { $ErrorActionPreference = $previous }
      [pscustomobject]@{ Code = $code; Out = ((@($lines | ForEach-Object { [string]$_ })) -join "`n") }
  }
  function GitOut([string]$Repo, [string[]]$GitArgs) {
      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try { $out = @(& git -C $Repo @GitArgs 2>$null) }
      finally { $ErrorActionPreference = $previous }
      return (@($out | ForEach-Object { [string]$_ }) -join "`n").Trim()
  }
  function Read-Text([string]$Path) { return ([System.IO.File]::ReadAllText($Path)).Replace("`r`n", "`n") }
  function Write-Text([string]$Path, [string]$Text) {
      New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
      [System.IO.File]::WriteAllText($Path, $Text)
  }
  function New-Fixture([string]$Id, [string]$Name) {
      $path = Join-Path $root $Name
      $r = Invoke-Pwsh $generator @('-Path', $path, '-Scenario', $Id)
      if ($r.Code -ne 0) { throw "fixture $Id failed: $($r.Out)" }
      return $path
  }

  try {
      New-Item -ItemType Directory -Path $root -Force | Out-Null

      # --- scenario files ------------------------------------------------------
      Check 'exactly the nine scenario folders exist' ((@(Get-ChildItem -LiteralPath (Join-Path $here 'scenarios') -Directory | ForEach-Object Name | Sort-Object) -join ',') -eq (@($ids | Sort-Object) -join ','))
      foreach ($id in $ids) {
          $dir = Join-Path $here "scenarios\$id"
          $s = $null
          try { $s = Get-Content -Raw -LiteralPath (Join-Path $dir 'scenario.json') | ConvertFrom-Json -AsHashtable } catch { $s = $null }
          Check "${id}: scenario.json parses and its id is the folder name" ($null -ne $s -and $s['id'] -ceq $id)
          if ($null -eq $s) { continue }
          Check "${id}: carries every scenario field" (@(@('title', 'skill', 'args', 'worktreeMode', 'branch', 'plan', 'expect') | Where-Object { -not $s.ContainsKey($_) }).Count -eq 0)
          Check "${id}: skill is quick-fix, execute-feature or null" ($null -eq $s['skill'] -or @('quick-fix', 'execute-feature') -ccontains $s['skill'])
          Check "${id}: a seeded plan has its plan.md, an argsFile exists" ((-not $s['plan'] -or (Test-Path -LiteralPath (Join-Path $dir 'plan.md'))) -and (-not $s['argsFile'] -or (Test-Path -LiteralPath (Join-Path $dir $s['argsFile']))))
          $keys = @($s['expect'].Keys) + @(if ($s['resumeExpect']) { $s['resumeExpect'].Keys })
          Check "${id}: every expect key is one the assertion implements" (@($keys | Where-Object { $knownKeys -cnotcontains $_ }).Count -eq 0)
          Check "${id}: expects the branch it starts on" ($s['expect']['branch'] -ceq $s['branch'])
      }

      # --- the fixture generator -----------------------------------------------
      $qf = New-Fixture 'QF-NONE' 'qf'
      Check 'fixture: on branch feature/smoke with one commit' ((GitOut $qf @('symbolic-ref', '--short', 'HEAD')) -eq 'feature/smoke' -and (GitOut $qf @('rev-list', '--count', 'HEAD')) -eq '1')
      Check 'fixture: only notes/unrelated.txt is dirty, with the seeded content' ((GitOut $qf @('status', '--porcelain')) -eq 'M notes/unrelated.txt' -and (Read-Text (Join-Path $qf 'notes\unrelated.txt')) -eq "unrelated work in progress`n")
      Check 'fixture: START is HEAD and the dirty file hash is recorded' ((Read-Text (Join-Path $qf '.smoke\start.txt')).Trim() -eq (GitOut $qf @('rev-parse', 'HEAD')) -and (Read-Text (Join-Path $qf '.smoke\unrelated.sha256')).Trim() -eq (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $qf 'notes\unrelated.txt')).Hash)
      $exclude = Read-Text (Join-Path $qf '.git\info\exclude')
      Check 'fixture: .smoke/ is excluded before the run, and that exclude file is saved' (@($exclude -split "`n") -contains '.smoke/' -and $exclude -eq (Read-Text (Join-Path $qf '.smoke\exclude.before')))
      Check 'fixture: the scenario travels with the fixture' ((Get-Content -Raw -LiteralPath (Join-Path $qf '.smoke\scenario.json') | ConvertFrom-Json).id -eq 'QF-NONE')
      $agents = Read-Text (Join-Path $qf 'AGENTS.md')
      Check 'fixture: root AGENTS.md carries the canary rule under ## Conventions' ($agents.Contains('## Conventions') -and $agents.Contains('Every new `.ps1` file starts with the comment line `# canary-7`.'))
      $nested = Read-Text (Join-Path $qf 'src\Calc\AGENTS.md')
      Check 'fixture: nested AGENTS.md carries the verb rule and the second-line canary' ($nested.Contains('Functions in this folder use approved PowerShell verbs.') -and $nested.Contains('has `# nested-canary-3` as its second line'))
      Check 'fixture: each CLAUDE.md imports its AGENTS.md' ((Read-Text (Join-Path $qf 'CLAUDE.md')) -eq "@AGENTS.md`n" -and (Read-Text (Join-Path $qf 'src\Calc\CLAUDE.md')) -eq "@AGENTS.md`n")
      Check 'fixture: the green gate runs the calc checks; the policy requires feature/' ((Get-Content -Raw -LiteralPath (Join-Path $qf '.claude\cogniva-dev\green-gate.json') | ConvertFrom-Json).commands[0].run -eq 'pwsh -NoProfile -File tests/Calc.tests.ps1' -and (Get-Content -Raw -LiteralPath (Join-Path $qf '.claude\cogniva-dev\policy.json') | ConvertFrom-Json).requiredDevelopmentBranchPrefix -eq 'feature/')
      $calc = Invoke-Pwsh (Join-Path $qf 'tests\Calc.tests.ps1') @()
      Check 'fixture: its own calc checks pass' ($calc.Code -eq 0 -and $calc.Out.Contains('All calc checks passed.'))
      Check 'fixture: a non-empty target folder is refused (exit 2)' ((Invoke-Pwsh $generator @('-Path', $qf, '-Scenario', 'QF-NONE')).Code -eq 2)
      Check 'fixture: an unknown scenario is refused (exit 2)' ((Invoke-Pwsh $generator @('-Path', (Join-Path $root 'nope'), '-Scenario', 'NOPE')).Code -eq 2)

      $pol = New-Fixture 'POLICY' 'policy'
      Check 'POLICY fixture: left on main' ((GitOut $pol @('symbolic-ref', '--short', 'HEAD')) -eq 'main')
      $hk = New-Fixture 'HOOKS' 'hooks'
      Check 'HOOKS fixture: worktree mode is on, untracked and excluded' ((Get-Content -Raw -LiteralPath (Join-Path $hk '.claude\cogniva-dev.local.json') | ConvertFrom-Json).worktrees -eq $true -and -not (GitOut $hk @('ls-files', '.claude/cogniva-dev.local.json')) -and (GitOut $hk @('status', '--porcelain')) -eq 'M notes/unrelated.txt')

      $planCases = @(
          @{ Id = 'EF-TWO'; Plan = 'docs/plans/Smoke/TwoTasks/TwoTasks-plan.md'; Count = 2; Gates = '' },
          @{ Id = 'EF-BLOCKED'; Plan = 'docs/plans/Smoke/Blocked/Blocked-plan.md'; Count = 2; Gates = '' },
          @{ Id = 'EF-GATE'; Plan = 'docs/plans/Smoke/Gate/Gate-plan.md'; Count = 3; Gates = '2' }
      )
      foreach ($case in $planCases) {
          $fx = New-Fixture $case.Id $case.Id.ToLowerInvariant()
          $previous = $ErrorActionPreference
          $ErrorActionPreference = 'Continue'
          try { $tasks = @((@(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $plugin 'scripts\parse-plan-tasks.ps1') -PlanPath (Join-Path $fx $case.Plan) 2>$null) -join "`n") | ConvertFrom-Json) }
          catch { $tasks = @() }
          finally { $ErrorActionPreference = $previous }
          Check "$($case.Id) fixture: the plan is committed and parses into $($case.Count) open tasks, gate(s) [$($case.Gates)]" ((GitOut $fx @('ls-files', $case.Plan)) -eq $case.Plan -and $tasks.Count -eq $case.Count -and @($tasks | Where-Object { $_.done }).Count -eq 0 -and (@($tasks | Where-Object { $_.isGate } | ForEach-Object { $_.n }) -join ',') -eq $case.Gates)
      }

      $st = New-Fixture 'QF-STRUCT' 'struct'
      Check 'QF-STRUCT fixture: adopts dotnet, declares it at the root, commits it all' ((Test-Path -LiteralPath (Join-Path $st '.cogniva\profiles\dotnet\profile.yml')) -and (Read-Text (Join-Path $st '.cogniva-profile.yml')) -eq "profile: dotnet`n" -and (GitOut $st @('status', '--porcelain')) -eq 'M notes/unrelated.txt')
      $checker = Join-Path $plugin 'scripts\check-structural-changes.ps1'
      $snap = Invoke-Pwsh $checker @('-Repo', $st, '-Snapshot')
      $tree = if ($snap.Out -match 'START_TREE: ([0-9a-f]{40,64})') { $Matches[1] } else { '' }
      Check 'QF-STRUCT fixture: the start snapshot succeeds' ($snap.Code -eq 0 -and $tree)
      $csproj = Join-Path $st 'src\A\A.csproj'
      Write-Text $csproj ((Read-Text $csproj).Replace('</Project>', "  <ItemGroup>`n    <ProjectReference Include=`"..\B\B.csproj`" />`n  </ItemGroup>`n</Project>"))
      $found = Invoke-Pwsh $checker @('-Repo', $st, '-Since', $tree, '-Expected', 'dependency-added:src/A|src/B')
      Check 'QF-STRUCT fixture: the reference is an expected dependency-added fact (FOUND, exit 4)' ($found.Code -eq 4 -and $found.Out.Contains('STRUCTURE: FOUND') -and $found.Out.Contains('FACT 1 dependency-added (dotnet-projects): src/A/A.csproj -> src/B/B.csproj') -and -not $found.Out.Contains('UNEXPECTED'))
      $unexpected = Invoke-Pwsh $checker @('-Repo', $st, '-Since', $tree)
      Check 'QF-STRUCT fixture: without -Expected the same fact is marked UNEXPECTED' ($unexpected.Code -eq 4 -and $unexpected.Out.Contains('FACT 1 dependency-added UNEXPECTED (dotnet-projects)'))

      # --- sections appended by later tasks go above this line ---
  }
  finally {
      if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
  }

  if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
  Write-Host ''
  Write-Host 'All smoke-assertions assertions passed.'
  exit 0
  ```
- [ ] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1` → stops with an error and exit 1: the `scenarios` folder and the fixture generator do not exist yet.
- [ ] **Step 3 (scenario files):** Create these files, each with exactly the content shown.
  `plugins/cogniva-dev/tests/host-smoke/scenarios/QF-NONE/scenario.json`:
  ```json
  {
    "id": "QF-NONE",
    "title": "quick-fix commits=none: the change stays uncommitted and the handoff is complete",
    "skill": "quick-fix",
    "args": "\"Make Add-Numbers accept an optional third number $c (default 0) and add a test for it\" commits=none",
    "worktreeMode": false,
    "branch": "feature/smoke",
    "plan": null,
    "expect": {
      "commitsSinceStart": 0,
      "branch": "feature/smoke",
      "changedPaths": ["src/Calc/Calc.ps1", "tests/Calc.tests.ps1"],
      "unrelatedPreserved": true,
      "handoffSections": true,
      "finalMessageContains": ["READY FOR REVIEW", "Integration: not performed"]
    }
  }
  ```
  `plugins/cogniva-dev/tests/host-smoke/scenarios/QF-FINAL/scenario.json`:
  ```json
  {
    "id": "QF-FINAL",
    "title": "quick-fix commits=final: exactly one commit, unrelated work left out of it",
    "skill": "quick-fix",
    "args": "\"Make Add-Numbers accept an optional third number $c (default 0) and add a test for it\" commits=final",
    "worktreeMode": false,
    "branch": "feature/smoke",
    "plan": null,
    "expect": {
      "commitsSinceStart": 1,
      "branch": "feature/smoke",
      "changedPaths": ["src/Calc/Calc.ps1", "tests/Calc.tests.ps1"],
      "unrelatedPreserved": true,
      "handoffSections": true,
      "finalMessageContains": ["READY FOR REVIEW"]
    }
  }
  ```
  `plugins/cogniva-dev/tests/host-smoke/scenarios/EF-TWO/scenario.json`:
  ```json
  {
    "id": "EF-TWO",
    "title": "execute-feature commits=task: two tasks, two commits, both ticked",
    "skill": "execute-feature",
    "args": "Smoke/TwoTasks commits=task plan=persisted",
    "worktreeMode": false,
    "branch": "feature/smoke",
    "plan": "docs/plans/Smoke/TwoTasks/TwoTasks-plan.md",
    "expect": {
      "commitsSinceStart": 2,
      "branch": "feature/smoke",
      "changedPaths": ["src/Calc/Calc.ps1", "tests/Calc.tests.ps1"],
      "planTicked": { "path": "docs/plans/Smoke/TwoTasks/TwoTasks-plan.md", "tasks": [1, 2] },
      "unrelatedPreserved": true,
      "handoffSections": true,
      "finalMessageContains": ["READY FOR REVIEW"]
    }
  }
  ```
  `plugins/cogniva-dev/tests/host-smoke/scenarios/EF-BLOCKED/scenario.json`:
  ```json
  {
    "id": "EF-BLOCKED",
    "title": "execute-feature: a blocked first task stops the run with nothing changed",
    "skill": "execute-feature",
    "args": "Smoke/Blocked commits=task plan=persisted",
    "worktreeMode": false,
    "branch": "feature/smoke",
    "plan": "docs/plans/Smoke/Blocked/Blocked-plan.md",
    "expect": {
      "commitsSinceStart": 0,
      "branch": "feature/smoke",
      "unchangedPaths": ["src/Calc/Calc.ps1", "tests/Calc.tests.ps1"],
      "planUnticked": { "path": "docs/plans/Smoke/Blocked/Blocked-plan.md", "tasks": [1, 2] },
      "noNewFiles": true,
      "unrelatedPreserved": true,
      "finalMessageContains": ["BLOCKED"]
    }
  }
  ```
  `plugins/cogniva-dev/tests/host-smoke/scenarios/EF-GATE/scenario.json`:
  ```json
  {
    "id": "EF-GATE",
    "title": "execute-feature: stops after the manual-validation gate task; the re-run finishes task 3 only",
    "skill": "execute-feature",
    "args": "Smoke/Gate commits=task plan=persisted",
    "worktreeMode": false,
    "branch": "feature/smoke",
    "plan": "docs/plans/Smoke/Gate/Gate-plan.md",
    "expect": {
      "commitsSinceStart": 2,
      "branch": "feature/smoke",
      "changedPaths": ["src/Calc/Calc.ps1", "docs/gate.txt"],
      "planTicked": { "path": "docs/plans/Smoke/Gate/Gate-plan.md", "tasks": [1, 2] },
      "planUnticked": { "path": "docs/plans/Smoke/Gate/Gate-plan.md", "tasks": [3] },
      "unrelatedPreserved": true
    },
    "resumeExpect": {
      "commitsSinceStart": 3,
      "branch": "feature/smoke",
      "changedPaths": ["src/Calc/Calc.ps1", "tests/Calc.tests.ps1", "docs/gate.txt"],
      "planTicked": { "path": "docs/plans/Smoke/Gate/Gate-plan.md", "tasks": [1, 2, 3] },
      "unrelatedPreserved": true,
      "handoffSections": true,
      "finalMessageContains": ["READY FOR REVIEW"]
    }
  }
  ```
  `plugins/cogniva-dev/tests/host-smoke/scenarios/QF-STRUCT/scenario.json`:
  ```json
  {
    "id": "QF-STRUCT",
    "title": "quick-fix: an expected ProjectReference is reported as an expected structural change",
    "skill": "quick-fix",
    "args": "\"Add a ProjectReference from src/A/A.csproj to src/B/B.csproj\" commits=none",
    "worktreeMode": false,
    "branch": "feature/smoke",
    "plan": null,
    "expect": {
      "commitsSinceStart": 0,
      "branch": "feature/smoke",
      "changedPaths": ["src/A/A.csproj"],
      "unchangedPaths": ["src/B/B.csproj"],
      "unrelatedPreserved": true,
      "handoffSections": true,
      "finalMessageContains": ["STRUCTURE: FOUND"],
      "finalMessageNotContains": ["dependency-added UNEXPECTED", "profile-changed UNEXPECTED"]
    }
  }
  ```
  `plugins/cogniva-dev/tests/host-smoke/scenarios/POLICY/scenario.json`:
  ```json
  {
    "id": "POLICY",
    "title": "execute-feature with a pasted plan on main: the branch policy stops it before anything is written",
    "skill": "execute-feature",
    "args": "commits=none",
    "argsFile": "pasted-plan.md",
    "worktreeMode": false,
    "branch": "main",
    "plan": null,
    "expect": {
      "commitsSinceStart": 0,
      "branch": "main",
      "unchangedPaths": ["src/Calc/Calc.ps1"],
      "noNewFiles": true,
      "gitInfoExcludeUnchanged": true,
      "unrelatedPreserved": true,
      "finalMessageContains": ["feature/"]
    }
  }
  ```
  `plugins/cogniva-dev/tests/host-smoke/scenarios/HOOKS/scenario.json`:
  ```json
  {
    "id": "HOOKS",
    "title": "worktree mode: a direct edit of the primary checkout is denied by the plugin hook",
    "skill": null,
    "args": "First run the shell command `git status --short` once and show its output. Then, without using any skill, edit src/Calc/Calc.ps1 in this checkout with your file-editing tool (not a shell command) to add the line `# hooks-probe` at the end of the file. If the edit is refused, do not try again by any other route: report the refusal text verbatim and stop.",
    "worktreeMode": true,
    "branch": "feature/smoke",
    "plan": null,
    "expect": {
      "commitsSinceStart": 0,
      "branch": "feature/smoke",
      "unchangedPaths": ["src/Calc/Calc.ps1"],
      "unrelatedPreserved": true
    }
  }
  ```
  `plugins/cogniva-dev/tests/host-smoke/scenarios/INSTR/scenario.json`:
  ```json
  {
    "id": "INSTR",
    "title": "instruction canary: the root and nested AGENTS.md rules reach the agent that writes the file",
    "skill": "quick-fix",
    "args": "\"Add a new script src/Calc/Divide.ps1 with a Get-Quotient function that divides its first argument by its second, and add a test for it\" commits=none",
    "worktreeMode": false,
    "branch": "feature/smoke",
    "plan": null,
    "expect": {
      "commitsSinceStart": 0,
      "branch": "feature/smoke",
      "changedPaths": ["src/Calc/Divide.ps1"],
      "fileStartsWith": { "src/Calc/Divide.ps1": "# canary-7\n# nested-canary-3" },
      "unrelatedPreserved": true,
      "handoffSections": true
    }
  }
  ```
- [ ] **Step 4 (seeded and pasted plans):** Create these files, each with exactly the content inside the four-backtick fence (the plans contain their own three-backtick fences; their task headings must start in column 0 of the written file).
  `plugins/cogniva-dev/tests/host-smoke/scenarios/EF-TWO/plan.md`:
  ````markdown
  # TwoTasks — Feature Plan

  > REQUIRED EXECUTOR: /execute-feature Smoke/TwoTasks
  > Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
  > Each task's commit step applies only when the run's `commits=` policy commits
  > per task; otherwise leave the changes in the working tree. Never run
  > git switch/checkout/branch inside a task.

  **Goal:** Add subtraction and multiplication beside `Add-Numbers`.

  **Architecture:** Each function goes in `src/Calc/Calc.ps1`; `tests/Calc.tests.ps1` checks it.

  **Read these first:** `src/Calc/Calc.ps1`, `tests/Calc.tests.ps1`

  ## File structure (locked)

  ```
  src/Calc/Calc.ps1      # the Calc functions
  tests/Calc.tests.ps1   # dependency-free checks, exit 1 on failure
  ```

  ## Task 1: Get-Difference

  **Files:**
  - Modify: `src/Calc/Calc.ps1`
  - Test: `tests/Calc.tests.ps1`

  - [ ] **Step 1 (failing test):** In `tests/Calc.tests.ps1`, add this line directly below the line that checks `Add-Numbers`:
        `Check 'Get-Difference subtracts the second number from the first' ((Get-Difference 7 2) -eq 5)`
  - [ ] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File tests/Calc.tests.ps1` → exits 1 (`Get-Difference` is not defined).
  - [ ] **Step 3 (implement):** Append to `src/Calc/Calc.ps1`:
        ```powershell
        function Get-Difference($a, $b) {
            return $a - $b
        }
        ```
  - [ ] **Step 4 (run until green):** `pwsh -NoProfile -File tests/Calc.tests.ps1` → `All calc checks passed.`
  - [ ] **Step 5 (commit):** `git add src/Calc/Calc.ps1 tests/Calc.tests.ps1 docs/plans/Smoke/TwoTasks/TwoTasks-plan.md` then `git commit -m "feat(calc): add Get-Difference"`

  ## Task 2: Get-Product

  **Files:**
  - Modify: `src/Calc/Calc.ps1`
  - Test: `tests/Calc.tests.ps1`

  - [ ] **Step 1 (failing test):** In `tests/Calc.tests.ps1`, add this line directly below the line that checks `Add-Numbers`:
        `Check 'Get-Product multiplies two numbers' ((Get-Product 3 4) -eq 12)`
  - [ ] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File tests/Calc.tests.ps1` → exits 1 (`Get-Product` is not defined).
  - [ ] **Step 3 (implement):** Append to `src/Calc/Calc.ps1`:
        ```powershell
        function Get-Product($a, $b) {
            return $a * $b
        }
        ```
  - [ ] **Step 4 (run until green):** `pwsh -NoProfile -File tests/Calc.tests.ps1` → `All calc checks passed.`
  - [ ] **Step 5 (commit):** `git add src/Calc/Calc.ps1 tests/Calc.tests.ps1 docs/plans/Smoke/TwoTasks/TwoTasks-plan.md` then `git commit -m "feat(calc): add Get-Product"`
  ````
  `plugins/cogniva-dev/tests/host-smoke/scenarios/EF-BLOCKED/plan.md`:
  ````markdown
  # Blocked — Feature Plan

  > REQUIRED EXECUTOR: /execute-feature Smoke/Blocked
  > Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
  > Each task's commit step applies only when the run's `commits=` policy commits
  > per task; otherwise leave the changes in the working tree. Never run
  > git switch/checkout/branch inside a task.

  **Goal:** Rename the function in `src/Missing/Gone.ps1`, then add `Get-Product`.

  **Architecture:** Task 1 needs a file that must already exist; task 2 extends `src/Calc/Calc.ps1`.

  **Read these first:** `src/Calc/Calc.ps1`

  ## File structure (locked)

  ```
  src/Missing/Gone.ps1   # must already exist; this plan never creates it
  src/Calc/Calc.ps1      # the Calc functions
  tests/Calc.tests.ps1   # dependency-free checks, exit 1 on failure
  ```

  ## Task 1: Rename Get-Gone

  **Files:**
  - Modify: `src/Missing/Gone.ps1`

  - [ ] **Step 1 (precondition):** `src/Missing/Gone.ps1` must already exist. If it does not, change nothing, do not create it, and return BLOCKED with the note `src/Missing/Gone.ps1 does not exist`.
  - [ ] **Step 2 (implement):** In `src/Missing/Gone.ps1`, rename the function `Get-Gone` to `Get-Present`.
  - [ ] **Step 3 (commit):** `git add src/Missing/Gone.ps1 docs/plans/Smoke/Blocked/Blocked-plan.md` then `git commit -m "refactor: rename Get-Gone"`

  ## Task 2: Get-Product

  **Files:**
  - Modify: `src/Calc/Calc.ps1`
  - Test: `tests/Calc.tests.ps1`

  - [ ] **Step 1 (failing test):** In `tests/Calc.tests.ps1`, add this line directly below the line that checks `Add-Numbers`:
        `Check 'Get-Product multiplies two numbers' ((Get-Product 3 4) -eq 12)`
  - [ ] **Step 2 (implement):** Append to `src/Calc/Calc.ps1`:
        ```powershell
        function Get-Product($a, $b) {
            return $a * $b
        }
        ```
  - [ ] **Step 3 (run until green):** `pwsh -NoProfile -File tests/Calc.tests.ps1` → `All calc checks passed.`
  - [ ] **Step 4 (commit):** `git add src/Calc/Calc.ps1 tests/Calc.tests.ps1 docs/plans/Smoke/Blocked/Blocked-plan.md` then `git commit -m "feat(calc): add Get-Product"`
  ````
  `plugins/cogniva-dev/tests/host-smoke/scenarios/EF-GATE/plan.md` (its gate task deliberately has no "wait for the user" step: the agent can finish it, tick it and commit, so the re-run resumes at task 3):
  ````markdown
  # Gate — Feature Plan

  > REQUIRED EXECUTOR: /execute-feature Smoke/Gate
  > Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
  > Each task's commit step applies only when the run's `commits=` policy commits
  > per task; otherwise leave the changes in the working tree. Never run
  > git switch/checkout/branch inside a task.

  **Goal:** Add `Get-Difference`, stop at a manual-validation gate, then add `Get-Product`.

  **Architecture:** Both functions go in `src/Calc/Calc.ps1`; the gate task records that it was reached in `docs/gate.txt`.

  **Read these first:** `src/Calc/Calc.ps1`, `tests/Calc.tests.ps1`

  ## File structure (locked)

  ```
  src/Calc/Calc.ps1      # the Calc functions
  tests/Calc.tests.ps1   # dependency-free checks, exit 1 on failure
  docs/gate.txt          # written by the gate task
  ```

  ## Task 1: Get-Difference

  **Files:**
  - Modify: `src/Calc/Calc.ps1`
  - Test: `tests/Calc.tests.ps1`

  - [ ] **Step 1 (failing test):** In `tests/Calc.tests.ps1`, add this line directly below the line that checks `Add-Numbers`:
        `Check 'Get-Difference subtracts the second number from the first' ((Get-Difference 7 2) -eq 5)`
  - [ ] **Step 2 (implement):** Append to `src/Calc/Calc.ps1`:
        ```powershell
        function Get-Difference($a, $b) {
            return $a - $b
        }
        ```
  - [ ] **Step 3 (run until green):** `pwsh -NoProfile -File tests/Calc.tests.ps1` → `All calc checks passed.`
  - [ ] **Step 4 (commit):** `git add src/Calc/Calc.ps1 tests/Calc.tests.ps1 docs/plans/Smoke/Gate/Gate-plan.md` then `git commit -m "feat(calc): add Get-Difference"`

  ## ⛔ Task 2: Gate checkpoint  (manual validation gate — execute-feature STOPS here)

  **Files:**
  - Create: `docs/gate.txt`

  - [ ] **Step 1:** Write `docs/gate.txt` containing the single line `gate reached`.
  - [ ] **Step 2:** Say in your summary that the gate was reached.
  - [ ] **Step 3 (commit):** `git add docs/gate.txt docs/plans/Smoke/Gate/Gate-plan.md` then `git commit -m "chore(smoke): gate reached"`

  ## Task 3: Get-Product

  **Files:**
  - Modify: `src/Calc/Calc.ps1`
  - Test: `tests/Calc.tests.ps1`

  - [ ] **Step 1 (failing test):** In `tests/Calc.tests.ps1`, add this line directly below the line that checks `Add-Numbers`:
        `Check 'Get-Product multiplies two numbers' ((Get-Product 3 4) -eq 12)`
  - [ ] **Step 2 (implement):** Append to `src/Calc/Calc.ps1`:
        ```powershell
        function Get-Product($a, $b) {
            return $a * $b
        }
        ```
  - [ ] **Step 3 (run until green):** `pwsh -NoProfile -File tests/Calc.tests.ps1` → `All calc checks passed.`
  - [ ] **Step 4 (commit):** `git add src/Calc/Calc.ps1 tests/Calc.tests.ps1 docs/plans/Smoke/Gate/Gate-plan.md` then `git commit -m "feat(calc): add Get-Product"`
  ````
  `plugins/cogniva-dev/tests/host-smoke/scenarios/POLICY/pasted-plan.md`:
  ````markdown
  # PolicyProbe — Feature Plan

  **Goal:** Add a comment line to the Calc script.

  ## Task 1: Comment the Calc script

  - [ ] **Step 1:** Add the line `# policy-probe` at the end of `src/Calc/Calc.ps1`.
  - [ ] **Step 2 (commit):** `git add src/Calc/Calc.ps1` then `git commit -m "chore: policy probe"`
  ````
- [ ] **Step 5 (implement the generator):** Create `plugins/cogniva-dev/tests/host-smoke/new-smoke-fixture.ps1` with exactly:
  ```powershell
  #Requires -Version 7.0
  # Builds a throwaway git repository for one agent-host smoke scenario
  # (scenarios/<ID>/scenario.json). Layout: src/Calc/Calc.ps1 (Add-Numbers),
  # tests/Calc.tests.ps1 (dependency-free, exit 1 on failure), a green gate that
  # runs it, a branch policy requiring feature/, root and nested AGENTS.md (each
  # with a CLAUDE.md that imports it), notes/unrelated.txt committed and then
  # dirtied, and the scenario's seeded plan. QF-STRUCT adds two SDK-style projects
  # and adopts and declares the shipped dotnet profile; HOOKS turns worktree mode
  # on. The start state the assertions compare against goes to .smoke/ (excluded
  # from git before the run): start.txt (HEAD), unrelated.sha256, exclude.before,
  # untracked.before and scenario.json.
  # Exit 0 = built; 2 = usage error (unknown scenario, non-empty target) or a
  # failed build step.
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)][string]$Path,
      [Parameter(Mandatory)][string]$Scenario
  )
  $ErrorActionPreference = 'Stop'
  $here = $PSScriptRoot
  $plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))

  function Fail([string]$Message) { [Console]::Error.WriteLine("new-smoke-fixture: $Message"); exit 2 }

  $scenarioDir = Join-Path $here "scenarios\$Scenario"
  $scenarioFile = Join-Path $scenarioDir 'scenario.json'
  if ($Scenario -cnotmatch '^[A-Z]+(-[A-Z]+)*\z' -or -not (Test-Path -LiteralPath $scenarioFile -PathType Leaf)) { Fail "unknown scenario '$Scenario'" }
  $data = Get-Content -Raw -LiteralPath $scenarioFile | ConvertFrom-Json
  $fx = [System.IO.Path]::GetFullPath($Path)
  if ((Test-Path -LiteralPath $fx) -and @(Get-ChildItem -LiteralPath $fx -Force).Count) { Fail "fixture folder is not empty: $fx" }
  New-Item -ItemType Directory -Path $fx -Force | Out-Null

  function Write-Text([string]$Relative, [string]$Text) {
      $target = Join-Path $fx $Relative
      New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
      [System.IO.File]::WriteAllText($target, $Text.Replace("`r`n", "`n"))
  }
  function Invoke-Git([string[]]$GitArgs) {
      $out = @(& git -C $fx @GitArgs 2>&1)
      if ($LASTEXITCODE -ne 0) { Fail "git $($GitArgs -join ' ') failed: $($out -join ' ')" }
      return $out
  }

  Invoke-Git @('init', '-q') | Out-Null
  Invoke-Git @('symbolic-ref', 'HEAD', "refs/heads/$($data.branch)") | Out-Null
  Invoke-Git @('config', 'user.email', 'smoke@cogniva.invalid') | Out-Null
  Invoke-Git @('config', 'user.name', 'Cogniva smoke') | Out-Null
  Invoke-Git @('config', 'core.autocrlf', 'false') | Out-Null

  Write-Text 'src/Calc/Calc.ps1' @'
  # canary-7
  # nested-canary-3
  function Add-Numbers($a, $b) {
      return $a + $b
  }
  '@
  Write-Text 'tests/Calc.tests.ps1' @'
  # canary-7
  # Dependency-free checks for src/Calc. Exit 1 on any failure.
  $ErrorActionPreference = 'Stop'
  $script:failures = 0
  foreach ($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..\src\Calc') -Filter '*.ps1') { . $file.FullName }
  function Check([string]$Label, $Condition) {
      if ($Condition) { Write-Host "  PASS  $Label" }
      else { Write-Host "  FAIL  $Label"; $script:failures++ }
  }

  Check 'Add-Numbers adds two numbers' ((Add-Numbers 2 3) -eq 5)

  if ($script:failures) { Write-Host "FAILED: $($script:failures) check(s)."; exit 1 }
  Write-Host 'All calc checks passed.'
  exit 0
  '@
  Write-Text '.claude/cogniva-dev/green-gate.json' @'
  {
    "commands": [
      { "run": "pwsh -NoProfile -File tests/Calc.tests.ps1", "label": "calc", "note": "The smoke fixture's own checks." }
    ]
  }
  '@
  Write-Text '.claude/cogniva-dev/policy.json' @'
  { "requiredDevelopmentBranchPrefix": "feature/" }
  '@
  Write-Text 'AGENTS.md' @'
  # Smoke fixture

  A throwaway repository for Cogniva agent-host smoke runs. Nothing here is real work.

  ## Conventions

  - Every new `.ps1` file starts with the comment line `# canary-7`.
  - Run the checks with `pwsh -NoProfile -File tests/Calc.tests.ps1`.

  ## Unattended runs

  - Nobody is watching this run, so never stop to ask a question. Where a skill would wait for an answer, stop instead and say what you would have asked.
  - `notes/unrelated.txt` is someone else's work in progress: never stage, commit, revert or edit it. When a skill asks whether to go ahead while it is dirty, go ahead and leave it as it is.
  - When a skill proposes a name or folder for a pasted plan, accept its proposal.
  '@
  Write-Text 'src/Calc/AGENTS.md' @'
  # src/Calc

  - Functions in this folder use approved PowerShell verbs.
  - Every new `.ps1` file in this folder has `# nested-canary-3` as its second line.
  '@
  Write-Text 'CLAUDE.md' "@AGENTS.md`n"
  Write-Text 'src/Calc/CLAUDE.md' "@AGENTS.md`n"
  Write-Text 'notes/unrelated.txt' "unrelated baseline`n"
  if ($data.plan) { Write-Text $data.plan ([System.IO.File]::ReadAllText((Join-Path $scenarioDir 'plan.md'))) }

  if ($Scenario -ceq 'QF-STRUCT') {
      $project = "<Project Sdk=`"Microsoft.NET.Sdk`">`n  <PropertyGroup>`n    <TargetFramework>net8.0</TargetFramework>`n  </PropertyGroup>`n</Project>`n"
      Write-Text 'src/A/A.csproj' $project
      Write-Text 'src/B/B.csproj' $project
      $adopt = @(& pwsh -NoProfile -File (Join-Path $plugin 'scripts\adopt-architecture-profile.ps1') -Repo $fx -Profile dotnet 2>&1)
      if ($LASTEXITCODE -ne 0) { Fail "adopting the dotnet profile failed: $($adopt -join ' ')" }
      Write-Text '.cogniva-profile.yml' "profile: dotnet`n"
  }

  Invoke-Git @('add', '-A') | Out-Null
  Invoke-Git @('commit', '-q', '-m', "smoke fixture: $Scenario") | Out-Null

  # The pre-existing, uncommitted work every scenario must leave alone.
  Write-Text 'notes/unrelated.txt' "unrelated work in progress`n"
  $excludeLines = @('.smoke/')
  if ($data.worktreeMode) {
      Write-Text '.claude/cogniva-dev.local.json' "{ `"worktrees`": true }`n"
      $excludeLines += '.claude/cogniva-dev.local.json'
  }
  $exclude = Join-Path $fx ((Invoke-Git @('rev-parse', '--git-path', 'info/exclude')) | Select-Object -First 1)
  New-Item -ItemType Directory -Path (Split-Path -Parent $exclude) -Force | Out-Null
  $existing = if (Test-Path -LiteralPath $exclude) { [System.IO.File]::ReadAllText($exclude) } else { '' }
  if ($existing -and -not $existing.EndsWith("`n")) { $existing += "`n" }
  [System.IO.File]::WriteAllText($exclude, $existing + (($excludeLines -join "`n") + "`n"))

  $start = (Invoke-Git @('rev-parse', 'HEAD')) | Select-Object -First 1
  Write-Text '.smoke/start.txt' "$start`n"
  Write-Text '.smoke/unrelated.sha256' ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $fx 'notes\unrelated.txt')).Hash + "`n")
  [System.IO.File]::Copy($exclude, (Join-Path $fx '.smoke\exclude.before'))
  Write-Text '.smoke/scenario.json' ([System.IO.File]::ReadAllText($scenarioFile))
  Write-Text '.smoke/untracked.before' ((@(Invoke-Git @('-c', 'core.quotepath=off', 'ls-files', '--others')) -join "`n") + "`n")

  Write-Output "FIXTURE: $fx"
  Write-Output "SCENARIO: $Scenario"
  Write-Output "BRANCH: $($data.branch)"
  Write-Output "START: $start"
  exit 0
  ```
- [ ] **Step 6 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1` → every line `PASS`, last line `All smoke-assertions assertions passed.`, exit 0. If the QF-STRUCT checks fail, run `pwsh -NoProfile -File plugins/cogniva-dev/tests/structural-changes/structural-changes.tests.ps1` first: the fixture relies on the shipped `dotnet` profile mapping `dependency-added` to standards it has.
- [ ] **Step 7 (commit):** `git add plugins/cogniva-dev/tests/host-smoke/scenarios plugins/cogniva-dev/tests/host-smoke/new-smoke-fixture.ps1 plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1` then `git commit -m "test(host-smoke): smoke scenarios and fixture generator"`

## Task 2: Outcome assertions, gated

**Files:**
- Create: `plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.ps1`
- Modify: `plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1`
- Modify: `.claude/cogniva-dev/green-gate.json`

Context: `plugins/cogniva-dev/tests/host-smoke/new-smoke-fixture.ps1 -Path <dir> -Scenario <ID>`
builds a git repo on the scenario's branch (`src/Calc/Calc.ps1`,
`tests/Calc.tests.ps1`, `AGENTS.md`, `notes/unrelated.txt` committed and then
dirtied to `unrelated work in progress`, the scenario's plan at its `plan`
path) and writes the start state to the excluded `.smoke/` folder:
`start.txt` (START = HEAD sha), `unrelated.sha256` (SHA-256 of the dirty
file), `exclude.before` (copy of `.git/info/exclude` with `.smoke/` already
in it), `untracked.before` (`git ls-files --others`) and `scenario.json`
(copy of the scenario). The checker reads `expect` (or `resumeExpect` with
`-Resume`) from that copy. The test file already builds the QF-NONE fixture in
`$qf` and has the helpers `Check`, `Invoke-Pwsh`, `GitOut`, `Read-Text`,
`Write-Text`, `New-Fixture`. Code below is indented two spaces to sit inside
its step; write it without that indent.

- [ ] **Step 1 (failing tests):** In `plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1`, insert this block, followed by one blank line, immediately above the line `    # --- sections appended by later tasks go above this line ---`:
  ```powershell
      # --- outcome assertions --------------------------------------------------
      # Each case copies a base fixture, replaces .smoke/scenario.json with one
      # expect key, simulates an outcome with plain git/file operations, and runs
      # assert-smoke-outcome.ps1 -Json.
      $ef = New-Fixture 'EF-TWO' 'ef-base'
      $handoffNames = @()
      $inside = $false
      foreach ($line in ((Read-Text (Join-Path $plugin 'skills\execute-feature\HANDOFF.md')) -split "`n")) {
          if ($line.StartsWith('## ')) { $inside = ($line -ceq '## Required sections'); continue }
          if ($inside -and $line -match '^- \*\*(?<name>[^*]+)\*\*') { $handoffNames += $Matches['name'] }
      }
      $fullHandoff = "READY FOR REVIEW`nBranch: feature/smoke`nIntegration: not performed`nRemote push: not performed`n`n" + ((@($handoffNames | ForEach-Object { "**$_** - none" })) -join "`n") + "`n"
      $caseNo = 0
      function New-Case([string]$Base, [hashtable]$Expect, [hashtable]$ResumeExpect) {
          $script:caseNo++
          $dir = Join-Path $script:root ("case-{0:d2}" -f $script:caseNo)
          Copy-Item -LiteralPath $Base -Destination $dir -Recurse -Force
          $file = Join-Path $dir '.smoke\scenario.json'
          $s = Get-Content -Raw -LiteralPath $file | ConvertFrom-Json -AsHashtable
          $s['expect'] = $Expect
          if ($ResumeExpect) { $s['resumeExpect'] = $ResumeExpect }
          [System.IO.File]::WriteAllText($file, ($s | ConvertTo-Json -Depth 10))
          return $dir
      }
      function Assert-Case([string]$Fixture, [string]$Message, [switch]$Resume, [switch]$NoMessage) {
          $id = (Get-Content -Raw -LiteralPath (Join-Path $Fixture '.smoke\scenario.json') | ConvertFrom-Json).id
          $argsList = @('-Fixture', $Fixture, '-Scenario', $id, '-Json')
          if (-not $NoMessage) {
              $msg = Join-Path $Fixture '.smoke\final.txt'
              [System.IO.File]::WriteAllText($msg, $Message)
              $argsList += @('-FinalMessage', $msg)
          }
          if ($Resume) { $argsList += '-Resume' }
          $r = Invoke-Pwsh $assert $argsList
          $json = $null
          try { $json = $r.Out | ConvertFrom-Json } catch { $json = $null }
          [pscustomobject]@{ Code = $r.Code; Json = $json; Out = $r.Out }
      }
      function Passed($Result, [string]$Key) { return ($Result.Code -eq 0 -and @($Result.Json.results | Where-Object { $_.key -eq $Key -and $_.pass }).Count -eq 1) }
      function Failed($Result, [string]$Key) { return ($Result.Code -eq 1 -and @($Result.Json.results | Where-Object { $_.key -eq $Key -and -not $_.pass }).Count -eq 1) }
      function Add-Line([string]$File, [string]$Line) { [System.IO.File]::AppendAllText($File, "$Line`n") }
      function Commit-All([string]$Repo, [string]$Message) { GitOut $Repo @('add', '--', 'src', 'tests') | Out-Null; GitOut $Repo @('commit', '-q', '-m', $Message) | Out-Null }

      # commitsSinceStart
      $c = New-Case $qf @{ commitsSinceStart = 1 }
      Add-Line (Join-Path $c 'src\Calc\Calc.ps1') '# change'; Commit-All $c 'one change'
      Check 'commitsSinceStart: one new commit passes 1' (Passed (Assert-Case $c '') 'commitsSinceStart')
      $c = New-Case $qf @{ commitsSinceStart = 0 }
      Add-Line (Join-Path $c 'src\Calc\Calc.ps1') '# change'; Commit-All $c 'one change'
      Check 'commitsSinceStart: one new commit fails 0' (Failed (Assert-Case $c '') 'commitsSinceStart')
      # branch
      $c = New-Case $qf @{ branch = 'feature/smoke' }
      Check 'branch: still on feature/smoke passes' (Passed (Assert-Case $c '') 'branch')
      $c = New-Case $qf @{ branch = 'feature/smoke' }
      GitOut $c @('symbolic-ref', 'HEAD', 'refs/heads/other') | Out-Null
      Check 'branch: a moved HEAD fails' (Failed (Assert-Case $c '') 'branch')
      # changedPaths
      $c = New-Case $qf @{ changedPaths = @('src/Calc/Calc.ps1', 'src/Calc/New.ps1') }
      Add-Line (Join-Path $c 'src\Calc\Calc.ps1') '# change'; Commit-All $c 'committed change'
      Write-Text (Join-Path $c 'src\Calc\New.ps1') "# canary-7`n"
      Check 'changedPaths: a committed edit and an untracked new file both count as changed' (Passed (Assert-Case $c '') 'changedPaths')
      $c = New-Case $qf @{ changedPaths = @('src/Calc/Calc.ps1') }
      Check 'changedPaths: an untouched file fails' (Failed (Assert-Case $c '') 'changedPaths')
      # unchangedPaths
      $c = New-Case $qf @{ unchangedPaths = @('src/Calc/Calc.ps1') }
      Check 'unchangedPaths: an untouched file passes' (Passed (Assert-Case $c '') 'unchangedPaths')
      $c = New-Case $qf @{ unchangedPaths = @('src/Calc/Calc.ps1') }
      Add-Line (Join-Path $c 'src\Calc\Calc.ps1') '# change'
      Check 'unchangedPaths: an uncommitted edit fails' (Failed (Assert-Case $c '') 'unchangedPaths')
      # unrelatedPreserved
      $c = New-Case $qf @{ unrelatedPreserved = $true }
      Check 'unrelatedPreserved: the dirty file left alone passes' (Passed (Assert-Case $c '') 'unrelatedPreserved')
      $c = New-Case $qf @{ unrelatedPreserved = $true }
      Write-Text (Join-Path $c 'notes\unrelated.txt') "reverted`n"
      Check 'unrelatedPreserved: overwritten content fails' (Failed (Assert-Case $c '') 'unrelatedPreserved')
      $c = New-Case $qf @{ unrelatedPreserved = $true }
      GitOut $c @('add', 'notes/unrelated.txt') | Out-Null; GitOut $c @('commit', '-q', '-m', 'swept up') | Out-Null
      Check 'unrelatedPreserved: committing it, content unchanged, fails' (Failed (Assert-Case $c '') 'unrelatedPreserved')
      # planTicked / planUnticked
      $planRel = 'docs/plans/Smoke/TwoTasks/TwoTasks-plan.md'
      function Set-Ticks([string]$Repo, [int[]]$Tasks) {
          $file = Join-Path $Repo $planRel
          $current = 0
          $lines = foreach ($line in ((Read-Text $file) -split "`n")) {
              if ($line -match '^## Task (?<n>\d+):') { $current = [int]$Matches['n'] }
              if ($Tasks -contains $current) { $line.Replace('- [ ]', '- [x]') } else { $line }
          }
          [System.IO.File]::WriteAllText($file, ($lines -join "`n"))
      }
      $c = New-Case $ef @{ planTicked = @{ path = $planRel; tasks = @(1, 2) } }
      Set-Ticks $c @(1, 2)
      Check 'planTicked: both tasks ticked passes' (Passed (Assert-Case $c '') 'planTicked')
      $c = New-Case $ef @{ planTicked = @{ path = $planRel; tasks = @(1, 2) } }
      Set-Ticks $c @(1)
      Check 'planTicked: task 2 left open fails' (Failed (Assert-Case $c '') 'planTicked')
      $c = New-Case $ef @{ planUnticked = @{ path = $planRel; tasks = @(1, 2) } }
      Check 'planUnticked: an untouched plan passes' (Passed (Assert-Case $c '') 'planUnticked')
      $c = New-Case $ef @{ planUnticked = @{ path = $planRel; tasks = @(1, 2) } }
      Set-Ticks $c @(1)
      Check 'planUnticked: a ticked task 1 fails' (Failed (Assert-Case $c '') 'planUnticked')
      # finalMessageContains / finalMessageNotContains
      $c = New-Case $qf @{ finalMessageContains = @('READY FOR REVIEW', 'STRUCTURE: FOUND') }
      Check 'finalMessageContains: both literals present passes' (Passed (Assert-Case $c "READY FOR REVIEW`r`nSTRUCTURE: FOUND - 1 structural change(s)") 'finalMessageContains')
      $c = New-Case $qf @{ finalMessageContains = @('READY FOR REVIEW') }
      Check 'finalMessageContains: a different-case literal fails' (Failed (Assert-Case $c 'ready for review') 'finalMessageContains')
      $c = New-Case $qf @{ finalMessageContains = @('READY FOR REVIEW') }
      Check 'finalMessageContains: no final message file fails' (Failed (Assert-Case $c '' -NoMessage) 'finalMessageContains')
      $c = New-Case $qf @{ finalMessageNotContains = @('dependency-added UNEXPECTED') }
      Check 'finalMessageNotContains: prose about no unexpected facts passes' (Passed (Assert-Case $c 'No UNEXPECTED facts. FACT 1 dependency-added (dotnet-projects)') 'finalMessageNotContains')
      $c = New-Case $qf @{ finalMessageNotContains = @('dependency-added UNEXPECTED') }
      Check 'finalMessageNotContains: an UNEXPECTED fact line fails' (Failed (Assert-Case $c 'FACT 1 dependency-added UNEXPECTED (dotnet-projects): src/A/A.csproj -> src/B/B.csproj') 'finalMessageNotContains')
      # handoffSections
      Check 'handoffSections: the required sections are read from HANDOFF.md' ($handoffNames.Count -ge 13 -and $handoffNames -contains 'Skipped validations')
      $c = New-Case $qf @{ handoffSections = $true }
      Check 'handoffSections: every section plus READY FOR REVIEW passes' (Passed (Assert-Case $c $fullHandoff) 'handoffSections')
      $c = New-Case $qf @{ handoffSections = $true }
      Check 'handoffSections: a dropped Skipped validations section fails' (Failed (Assert-Case $c $fullHandoff.Replace('**Skipped validations** - none', '')) 'handoffSections')
      # noNewFiles
      $c = New-Case $qf @{ noNewFiles = $true }
      Write-Text (Join-Path $c 'notes\unrelated.txt') "unrelated work in progress, still theirs`n"
      Check 'noNewFiles: edits to tracked files and .smoke/ files pass' (Passed (Assert-Case $c '') 'noNewFiles')
      $c = New-Case $qf @{ noNewFiles = $true }
      Add-Line (Join-Path $c '.git\info\exclude') '.plans-staging/'
      Write-Text (Join-Path $c '.plans-staging\Smoke\Probe\Probe-plan.md') "# Probe`n"
      Check 'noNewFiles: an ignored new file still fails' (Failed (Assert-Case $c '') 'noNewFiles')
      # gitInfoExcludeUnchanged
      $c = New-Case $qf @{ gitInfoExcludeUnchanged = $true }
      Check 'gitInfoExcludeUnchanged: an untouched exclude file passes' (Passed (Assert-Case $c '') 'gitInfoExcludeUnchanged')
      $c = New-Case $qf @{ gitInfoExcludeUnchanged = $true }
      Add-Line (Join-Path $c '.git\info\exclude') '.plans-staging/'
      Check 'gitInfoExcludeUnchanged: an appended line fails' (Failed (Assert-Case $c '') 'gitInfoExcludeUnchanged')
      # fileStartsWith
      $c = New-Case $qf @{ fileStartsWith = @{ 'src/Calc/Divide.ps1' = "# canary-7`n# nested-canary-3" } }
      Write-Text (Join-Path $c 'src\Calc\Divide.ps1') "# canary-7`r`n# nested-canary-3`r`nfunction Get-Quotient(`$a, `$b) { return `$a / `$b }`r`n"
      Check 'fileStartsWith: both canary lines pass, CRLF or LF' (Passed (Assert-Case $c '') 'fileStartsWith')
      $c = New-Case $qf @{ fileStartsWith = @{ 'src/Calc/Divide.ps1' = "# canary-7`n# nested-canary-3" } }
      Write-Text (Join-Path $c 'src\Calc\Divide.ps1') "# canary-7`nfunction Get-Quotient(`$a, `$b) { return `$a / `$b }`n"
      $r = Assert-Case $c ''
      Check 'fileStartsWith: a missing nested canary fails and shows the first two lines' ((Failed $r 'fileStartsWith') -and $r.Out.Contains('function Get-Quotient'))
      # usage errors, -Resume, text output
      $c = New-Case $qf @{ commitsSinceStart = 0; bogus = 1 }
      Check 'an unknown expect key is a usage error (exit 2)' ((Assert-Case $c '').Code -eq 2)
      $c = New-Case $qf @{ noNewFiles = $false }
      Check 'a boolean key set to false is a usage error (exit 2)' ((Assert-Case $c '').Code -eq 2)
      Check 'a fixture of another scenario is a usage error (exit 2)' ((Invoke-Pwsh $assert @('-Fixture', $qf, '-Scenario', 'QF-FINAL')).Code -eq 2)
      $c = New-Case $qf @{ commitsSinceStart = 0 } @{ commitsSinceStart = 1 }
      Add-Line (Join-Path $c 'src\Calc\Calc.ps1') '# change'; Commit-All $c 'one change'
      Check '-Resume checks resumeExpect' ((Assert-Case $c '' -Resume).Code -eq 0 -and (Assert-Case $c '').Code -eq 1)
      Check '-Resume without a resumeExpect is a usage error (exit 2)' ((Invoke-Pwsh $assert @('-Fixture', $qf, '-Scenario', 'QF-NONE', '-Resume')).Code -eq 2)
      $text = Invoke-Pwsh $assert @('-Fixture', $qf, '-Scenario', 'QF-NONE')
      Check 'text output: a FAIL line per failing key and the SMOKE verdict; an untouched fixture fails' ($text.Code -eq 1 -and $text.Out.Contains('FAIL changedPaths: unchanged since START: src/Calc/Calc.ps1, tests/Calc.tests.ps1') -and $text.Out.Contains('PASS commitsSinceStart:') -and $text.Out.Contains('SMOKE QF-NONE: FAIL'))
      $sim = Join-Path $root 'qf-simulated'
      Copy-Item -LiteralPath $qf -Destination $sim -Recurse -Force
      Write-Text (Join-Path $sim 'src\Calc\Calc.ps1') "# canary-7`n# nested-canary-3`nfunction Add-Numbers(`$a, `$b, `$c = 0) {`n    return `$a + `$b + `$c`n}`n"
      Add-Line (Join-Path $sim 'tests\Calc.tests.ps1') "Check 'Add-Numbers adds an optional third number' ((Add-Numbers 1 2 3) -eq 6)"
      Write-Text (Join-Path $sim '.smoke\final.txt') $fullHandoff
      $full = Invoke-Pwsh $assert @('-Fixture', $sim, '-Scenario', 'QF-NONE', '-FinalMessage', (Join-Path $sim '.smoke\final.txt'))
      Check 'a simulated QF-NONE run passes every key' ($full.Code -eq 0 -and $full.Out.Contains('SMOKE QF-NONE: PASS') -and -not $full.Out.Contains('FAIL '))
  ```
- [ ] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1` → the Task 1 checks still `PASS`; every new check that runs `assert-smoke-outcome.ps1` prints `FAIL` (the script does not exist yet); exit 1.
- [ ] **Step 3 (implement):** Create `plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.ps1` with exactly:
  ```powershell
  #Requires -Version 7.0
  # Checks a smoke fixture (built by new-smoke-fixture.ps1) after an agent-host
  # run against its scenario's expectations: "expect" in .smoke/scenario.json, or
  # "resumeExpect" with -Resume. Deterministic: git and file state plus the saved
  # final message - never the agent's own account of what it did.
  # Keys: commitsSinceStart, branch, changedPaths, unchangedPaths,
  # unrelatedPreserved, planTicked, planUnticked, finalMessageContains,
  # finalMessageNotContains, handoffSections, noNewFiles, gitInfoExcludeUnchanged,
  # fileStartsWith. Boolean keys take only true.
  # Prints "PASS|FAIL <key>: <detail>" per key, then "SMOKE <ID>: PASS|FAIL"
  # (-Json: one JSON object instead). Exit 0 = pass, 1 = fail, 2 = usage error.
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)][string]$Fixture,
      [Parameter(Mandatory)][string]$Scenario,
      [string]$FinalMessage,
      [switch]$Resume,
      [switch]$Json
  )
  $ErrorActionPreference = 'Stop'
  $here = $PSScriptRoot
  $plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
  $known = @('commitsSinceStart', 'branch', 'changedPaths', 'unchangedPaths', 'unrelatedPreserved', 'planTicked', 'planUnticked', 'finalMessageContains', 'finalMessageNotContains', 'handoffSections', 'noNewFiles', 'gitInfoExcludeUnchanged', 'fileStartsWith')
  $booleanKeys = @('unrelatedPreserved', 'handoffSections', 'noNewFiles', 'gitInfoExcludeUnchanged')

  function Fail([string]$Message) { [Console]::Error.WriteLine("assert-smoke-outcome: $Message"); exit 2 }
  function Invoke-Git([string[]]$GitArgs) {
      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try { $out = @(& git -C $script:fx @GitArgs 2>$null); $code = $LASTEXITCODE }
      finally { $ErrorActionPreference = $previous }
      return [pscustomobject]@{ Code = $code; Out = @($out | ForEach-Object { [string]$_ }) }
  }
  function Read-Lf([string]$Path) { return ([System.IO.File]::ReadAllText($Path)).TrimStart([char]0xFEFF).Replace("`r`n", "`n") }

  if (-not (Test-Path -LiteralPath $Fixture -PathType Container)) { Fail "fixture not found: $Fixture" }
  $fx = [System.IO.Path]::GetFullPath($Fixture)
  $smoke = Join-Path $fx '.smoke'
  $scenarioFile = Join-Path $smoke 'scenario.json'
  if (-not (Test-Path -LiteralPath $scenarioFile -PathType Leaf)) { Fail "not a smoke fixture (no .smoke/scenario.json): $fx" }
  $data = Get-Content -Raw -LiteralPath $scenarioFile | ConvertFrom-Json -AsHashtable
  if ($data['id'] -cne $Scenario) { Fail "the fixture is scenario '$($data['id'])', not '$Scenario'" }
  $expect = if ($Resume) { $data['resumeExpect'] } else { $data['expect'] }
  if ($Resume -and $null -eq $expect) { Fail "scenario $Scenario has no resumeExpect" }
  if ($null -eq $expect) { $expect = @{} }
  foreach ($key in @($expect.Keys)) {
      if ($known -cnotcontains $key) { Fail "unknown expect key '$key' in scenario $Scenario" }
      if ($booleanKeys -ccontains $key -and $expect[$key] -ne $true) { Fail "expect key '$key' takes only true" }
  }
  $start = (Read-Lf (Join-Path $smoke 'start.txt')).Trim()
  $message = $null
  if ($FinalMessage -and (Test-Path -LiteralPath $FinalMessage -PathType Leaf)) { $message = Read-Lf $FinalMessage }

  $results = [System.Collections.Generic.List[object]]::new()
  function Add-Result([string]$Key, [bool]$Pass, [string]$Detail) { $script:results.Add([pscustomobject]@{ key = $Key; pass = $Pass; detail = $Detail }) }

  # Git blob id of a path in the working tree now / at START; $null when absent.
  function Get-NowBlob([string]$Relative) {
      if (-not (Test-Path -LiteralPath (Join-Path $fx $Relative) -PathType Leaf)) { return $null }
      return (Invoke-Git @('hash-object', '--no-filters', '--', $Relative)).Out | Select-Object -First 1
  }
  function Get-StartBlob([string]$Relative) {
      $r = Invoke-Git @('rev-parse', '--verify', '--quiet', "$($start):$Relative")
      if ($r.Code -ne 0) { return $null }
      return $r.Out | Select-Object -First 1
  }
  # Per task number: how many ticked and unticked checkboxes it has outside fenced code.
  function Get-TaskBoxes([string]$Text) {
      $boxes = @{}
      $current = $null; $inFence = $false; $fenceChar = ''; $fenceLen = 0
      $heading = '^##\s+(?:' + [char]0x26D4 + '\s*)?Task\s+(?<n>\d+):'
      foreach ($line in ($Text -split "`n")) {
          $m = [regex]::Match($line, $heading)
          if ($m.Success) { $current = [int]$m.Groups['n'].Value; $boxes[$current] = [pscustomobject]@{ Checked = 0; Unchecked = 0 }; $inFence = $false; continue }
          if ($null -eq $current) { continue }
          $trimmed = $line.TrimStart()
          $fm = [regex]::Match($trimmed, '^(?<f>`{3,}|~{3,})')
          if ($fm.Success) {
              $marker = $fm.Groups['f'].Value
              if (-not $inFence) { $inFence = $true; $fenceChar = $marker[0]; $fenceLen = $marker.Length }
              elseif ($marker[0] -eq $fenceChar -and $marker.Length -ge $fenceLen) { $inFence = $false }
              continue
          }
          if ($inFence) { continue }
          if ($trimmed -match '^- \[[xX]\]') { $boxes[$current].Checked++ }
          elseif ($trimmed -match '^- \[ \]') { $boxes[$current].Unchecked++ }
      }
      return $boxes
  }
  function Test-PlanBoxes([string]$Key, $Spec, [bool]$Ticked) {
      $planFile = Join-Path $fx ([string]$Spec['path'])
      if (-not (Test-Path -LiteralPath $planFile -PathType Leaf)) { Add-Result $Key $false "plan not found: $($Spec['path'])"; return }
      $boxes = Get-TaskBoxes (Read-Lf $planFile)
      $bad = @()
      foreach ($n in @($Spec['tasks'])) {
          $b = $boxes[[int]$n]
          if ($null -eq $b) { $bad += "task $n (no such task)"; continue }
          $ok = if ($Ticked) { $b.Checked -ge 1 -and $b.Unchecked -eq 0 } else { $b.Unchecked -ge 1 -and $b.Checked -eq 0 }
          if (-not $ok) { $bad += "task $n ($($b.Checked) ticked, $($b.Unchecked) unticked)" }
      }
      $state = if ($Ticked) { 'ticked' } else { 'unticked' }
      if ($bad.Count) { Add-Result $Key $false "not all $($state): $($bad -join ', ')" }
      else { Add-Result $Key $true "tasks $(@($Spec['tasks']) -join ', ') all $state in $($Spec['path'])" }
  }
  function Get-HandoffSections {
      $text = Read-Lf (Join-Path $plugin 'skills\execute-feature\HANDOFF.md')
      $names = @(); $inside = $false
      foreach ($line in ($text -split "`n")) {
          if ($line.StartsWith('## ')) { $inside = ($line -ceq '## Required sections'); continue }
          if ($inside -and $line -match '^- \*\*(?<name>[^*]+)\*\*') { $names += $Matches['name'].Replace('`', '') }
      }
      return $names
  }

  foreach ($key in $known) {
      if (-not $expect.ContainsKey($key)) { continue }
      $want = $expect[$key]
      switch ($key) {
          'commitsSinceStart' {
              $got = [int]((Invoke-Git @('rev-list', '--count', "$start..HEAD")).Out | Select-Object -First 1)
              Add-Result $key ($got -eq [int]$want) "expected $want new commit(s), found $got"
          }
          'branch' {
              $r = Invoke-Git @('symbolic-ref', '--quiet', '--short', 'HEAD')
              $got = if ($r.Code -eq 0) { $r.Out | Select-Object -First 1 } else { '(detached HEAD)' }
              Add-Result $key ($got -ceq [string]$want) "expected $want, on $got"
          }
          'changedPaths' {
              $same = @(@($want) | Where-Object { (Get-NowBlob $_) -eq (Get-StartBlob $_) })
              if ($same.Count) { Add-Result $key $false "unchanged since START: $($same -join ', ')" }
              else { Add-Result $key $true "changed: $(@($want) -join ', ')" }
          }
          'unchangedPaths' {
              $moved = @(@($want) | Where-Object { (Get-NowBlob $_) -ne (Get-StartBlob $_) })
              if ($moved.Count) { Add-Result $key $false "changed since START: $($moved -join ', ')" }
              else { Add-Result $key $true "byte-identical to START: $(@($want) -join ', ')" }
          }
          'unrelatedPreserved' {
              $file = Join-Path $fx 'notes\unrelated.txt'
              $hash = if (Test-Path -LiteralPath $file) { (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash } else { '(missing)' }
              $seeded = (Read-Lf (Join-Path $smoke 'unrelated.sha256')).Trim()
              $commits = @((Invoke-Git @('log', '--format=%h', "$start..HEAD", '--', 'notes/unrelated.txt')).Out | Where-Object { $_ })
              if ($hash -ne $seeded) { Add-Result $key $false 'notes/unrelated.txt no longer holds the seeded work in progress' }
              elseif ($commits.Count) { Add-Result $key $false "notes/unrelated.txt is in new commit(s): $($commits -join ', ')" }
              else { Add-Result $key $true 'notes/unrelated.txt keeps its content and is in no new commit' }
          }
          'planTicked' { Test-PlanBoxes $key $want $true }
          'planUnticked' { Test-PlanBoxes $key $want $false }
          'finalMessageContains' {
              if ($null -eq $message) { Add-Result $key $false 'no final message file'; break }
              $missing = @(@($want) | Where-Object { -not $message.Contains([string]$_, [System.StringComparison]::Ordinal) })
              if ($missing.Count) { Add-Result $key $false "missing: $($missing -join ' | ')" }
              else { Add-Result $key $true "contains: $(@($want) -join ' | ')" }
          }
          'finalMessageNotContains' {
              if ($null -eq $message) { Add-Result $key $false 'no final message file'; break }
              $present = @(@($want) | Where-Object { $message.Contains([string]$_, [System.StringComparison]::Ordinal) })
              if ($present.Count) { Add-Result $key $false "present: $($present -join ' | ')" }
              else { Add-Result $key $true "absent: $(@($want) -join ' | ')" }
          }
          'handoffSections' {
              if ($null -eq $message) { Add-Result $key $false 'no final message file'; break }
              $plain = $message.Replace('`', '').Replace('*', '')
              $missing = @(Get-HandoffSections | Where-Object { $plain.IndexOf($_, [System.StringComparison]::OrdinalIgnoreCase) -lt 0 })
              if (-not $message.Contains('READY FOR REVIEW', [System.StringComparison]::Ordinal)) { $missing += 'READY FOR REVIEW' }
              if ($missing.Count) { Add-Result $key $false "missing: $($missing -join ' | ')" }
              else { Add-Result $key $true 'every HANDOFF.md section and READY FOR REVIEW are present' }
          }
          'noNewFiles' {
              $before = @((Read-Lf (Join-Path $smoke 'untracked.before')) -split "`n" | Where-Object { $_ })
              $now = @((Invoke-Git @('-c', 'core.quotepath=off', 'ls-files', '--others')).Out | Where-Object { $_ })
              $new = @($now | Where-Object { -not $_.StartsWith('.smoke/') -and $before -cnotcontains $_ })
              if ($new.Count) { Add-Result $key $false "new untracked or ignored file(s): $($new -join ', ')" }
              else { Add-Result $key $true 'no new files, ignored ones included' }
          }
          'gitInfoExcludeUnchanged' {
              $exclude = Join-Path $fx ((Invoke-Git @('rev-parse', '--git-path', 'info/exclude')).Out | Select-Object -First 1)
              $now = if (Test-Path -LiteralPath $exclude) { [System.IO.File]::ReadAllText($exclude) } else { '' }
              $was = [System.IO.File]::ReadAllText((Join-Path $smoke 'exclude.before'))
              Add-Result $key ($now -ceq $was) $(if ($now -ceq $was) { '.git/info/exclude is unchanged' } else { '.git/info/exclude changed during the run' })
          }
          'fileStartsWith' {
              $bad = @()
              foreach ($entry in $want.GetEnumerator()) {
                  $file = Join-Path $fx $entry.Key
                  $prefix = ([string]$entry.Value).Replace("`r`n", "`n")
                  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { $bad += "$($entry.Key) (missing)"; continue }
                  $text = Read-Lf $file
                  if (-not $text.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
                      $head = (@($text -split "`n" | Select-Object -First 2) -join '\n')
                      $bad += "$($entry.Key) starts with '$head'"
                  }
              }
              if ($bad.Count) { Add-Result $key $false ($bad -join '; ') }
              else { Add-Result $key $true "$(@($want.Keys) -join ', ') start(s) as expected" }
          }
      }
  }

  $pass = -not @($results | Where-Object { -not $_.pass }).Count
  if ($Json) {
      [pscustomobject]@{ scenario = $Scenario; resume = [bool]$Resume; pass = $pass; results = @($results) } | ConvertTo-Json -Depth 5
  }
  else {
      foreach ($r in $results) { Write-Output ("{0} {1}: {2}" -f $(if ($r.pass) { 'PASS' } else { 'FAIL' }), $r.key, $r.detail) }
      Write-Output ("SMOKE {0}: {1}" -f $Scenario, $(if ($pass) { 'PASS' } else { 'FAIL' }))
  }
  exit $(if ($pass) { 0 } else { 1 })
  ```
- [ ] **Step 4 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1` → every line `PASS`, last line `All smoke-assertions assertions passed.`, exit 0.
- [ ] **Step 5 (wire into the green gate):** In `.claude/cogniva-dev/green-gate.json`, add a comma after the closing `}` of the current last object in `commands` and append this object as the new last element (same one-line style as the others):
  ```json
      { "run": "pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1", "label": "smoke-assertions", "note": "Proves the agent-host smoke scenarios, fixture generator and outcome assertions with simulated outcomes - no model runs; needs PowerShell 7." }
  ```
  Then confirm the file still parses: `pwsh -NoProfile -Command "(Get-Content -Raw .claude/cogniva-dev/green-gate.json | ConvertFrom-Json).commands[-1].label"` → `smoke-assertions`.
- [ ] **Step 6 (run the gate):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → last line `green-gate: GREEN - all N command(s) exited 0.`
- [ ] **Step 7 (commit):** `git add plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.ps1 plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1 .claude/cogniva-dev/green-gate.json` then `git commit -m "test(host-smoke): deterministic smoke outcome assertions, gated as smoke-assertions"`

## Task 3: Headless driver and smoke records

**Files:**
- Create: `plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1`
- Modify: `plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1`

Context: the driver renders each scenario's invocation per agent host
(Claude Code `/cogniva-dev:<skill> <args>`, Codex `$<skill> <args>`, a
`"skill": null` scenario sends its `args` alone; `argsFile` text follows the
arguments on the next line), builds the fixture with
`new-smoke-fixture.ps1`, runs the agent host from the fixture folder with the
prompt on stdin, saves `<ID>.final.txt`, `<ID>.transcript.jsonl` and
`<ID>.assert.txt`, runs `assert-smoke-outcome.ps1`, and appends a row to a
smoke record whose header follows the shared format exactly (`# Smoke record
<record-id>`, `Agent host:`, `Agent host version:`, `Surface:`, `OS:`,
`Plugin versions:`, `Plugin source:`, `Date:`, `Covers:`; then `## Scenarios`
and `## Observations`). Flags verified on this machine on 2026-10-09:
`claude` 2.1.187 has `-p`, `--output-format stream-json`, `--verbose`,
`--permission-mode bypassPermissions`, `--plugin-dir`, `--setting-sources`;
Codex `codex-cli 0.162.0-alpha.17.2` `exec` has `--json`,
`--sandbox workspace-write`, `-C`, `--output-last-message` and reads the
prompt from stdin when given `-`. Real runs cost model tokens and are NOT
gated; only `-DryRun` is tested. Code below is indented two spaces to sit
inside its step; write it without that indent.

- [ ] **Step 1 (failing tests):** In `plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1`, insert this block, followed by one blank line, immediately above the line `    # --- sections appended by later tasks go above this line ---`:
  ```powershell
      # --- driver -DryRun --------------------------------------------------------
      $dryRoot = Join-Path $root 'dry'
      $d = Invoke-Pwsh $driver @('-AgentHost', 'claude-code', '-Scenario', 'QF-NONE', '-DryRun', '-FixtureRoot', $dryRoot)
      Check 'DryRun claude-code: renders the plugin-qualified invocation with the flags' ($d.Code -eq 0 -and $d.Out.Contains('/cogniva-dev:quick-fix "Make Add-Numbers accept an optional third number $c (default 0) and add a test for it" commits=none'))
      Check 'DryRun claude-code: prints the headless command, prompt on stdin' ($d.Out.Contains('-p --output-format stream-json --verbose --permission-mode bypassPermissions') -and $d.Out.Contains('(prompt on stdin'))
      Check 'DryRun: builds no fixture and runs nothing' (-not (Test-Path -LiteralPath (Join-Path $dryRoot 'QF-NONE')))
      $d = Invoke-Pwsh $driver @('-AgentHost', 'claude-code', '-Scenario', 'QF-NONE', '-DryRun', '-FixtureRoot', $dryRoot, '-PluginDir', $plugin)
      Check 'DryRun claude-code -PluginDir: loads the checkout plugin, user settings off' ($d.Code -eq 0 -and $d.Out.Contains("--plugin-dir $plugin --setting-sources project,local"))
      $d = Invoke-Pwsh $driver @('-AgentHost', 'codex', '-Scenario', 'QF-NONE', '-DryRun', '-FixtureRoot', $dryRoot, '-CodexExe', 'C:\nowhere\codex.exe')
      Check 'DryRun codex: renders the $skill invocation and the exec command' ($d.Code -eq 0 -and $d.Out.Contains('$quick-fix "Make Add-Numbers') -and $d.Out.Contains('C:\nowhere\codex.exe exec --json --sandbox workspace-write -C ') -and $d.Out.Contains('--output-last-message '))
      $d = Invoke-Pwsh $driver @('-AgentHost', 'claude-code', '-Scenario', 'POLICY', '-DryRun', '-FixtureRoot', $dryRoot)
      Check 'DryRun POLICY: the pasted plan follows the flags on the next line' ($d.Code -eq 0 -and $d.Out.Contains("/cogniva-dev:execute-feature commits=none`n# PolicyProbe"))
      $d = Invoke-Pwsh $driver @('-AgentHost', 'codex', '-Scenario', 'HOOKS', '-DryRun', '-FixtureRoot', $dryRoot, '-CodexExe', 'C:\nowhere\codex.exe')
      Check 'DryRun HOOKS: a plain prompt, no skill prefix' ($d.Code -eq 0 -and $d.Out.Contains("PROMPT:`nFirst run the shell command"))
      $d = Invoke-Pwsh $driver @('-AgentHost', 'claude-code', '-Scenario', 'all', '-DryRun', '-FixtureRoot', $dryRoot)
      Check 'DryRun all: nine scenarios plus the EF-GATE re-run' ($d.Code -eq 0 -and ([regex]::Matches($d.Out, '(?m)^SCENARIO: ')).Count -eq 10 -and $d.Out.Contains('SCENARIO: EF-GATE (resume)'))
      Check 'an unknown scenario is a usage error (exit 2)' ((Invoke-Pwsh $driver @('-AgentHost', 'codex', '-Scenario', 'NOPE', '-DryRun')).Code -eq 2)
  ```
- [ ] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1` → the earlier checks `PASS`; the `DryRun` checks `FAIL` (the driver does not exist yet), except `DryRun: builds no fixture and runs nothing`; exit 1.
- [ ] **Step 3 (implement):** Create `plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1` with exactly:
  ```powershell
  #Requires -Version 7.0
  # Runs agent-host smoke scenarios headless on Claude Code or Codex, checks each
  # outcome with assert-smoke-outcome.ps1 and writes the results to a smoke record
  # (docs/host-parity/smoke/<YYYY-MM-DD>-<claude-code|codex>-cli[-N].md).
  # Each scenario runs in a fresh throwaway fixture repo (new-smoke-fixture.ps1)
  # under -FixtureRoot, with no remote. That is why the agent runs unattended
  # there (Claude Code: --permission-mode bypassPermissions; Codex: exec with
  # --sandbox workspace-write): it can reach nothing but a temp repo built for it.
  # Costs model tokens - not part of the green gate. -DryRun prints the fixture
  # path, the command and the prompt for each run, and builds and runs nothing.
  #   -Scenario <ID>|all   all = the nine scenarios, plus EF-GATE run again (resume)
  #   -Resume              run the same invocation again on the existing fixture
  #   -PluginDir <dir>     Claude Code: load the plugin from this folder only
  #                        (--plugin-dir, with user settings and plugins off)
  #   -CodexExe <path>     default: the newest codex.exe bundled with the VS Code
  #                        extension (openai.chatgpt-<version>-win32-x64)
  #   -RecordPath <file>   append to this record instead of starting a new one
  #   -ExtraArgs <args>    passed to the agent host after the harness's own flags
  # Exit 0 = every run passed; 1 = a run failed or did not finish; 2 = usage or
  # harness error.
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)][ValidateSet('claude-code', 'codex')][string]$AgentHost,
      [Parameter(Mandatory)][string]$Scenario,
      [string]$CodexExe,
      [string]$PluginDir,
      [switch]$Resume,
      [string]$OutDir,
      [string]$FixtureRoot,
      [string]$RecordPath,
      [string]$PluginSource,
      [string]$Covers = 'none',
      [string[]]$ExtraArgs = @(),
      [int]$TimeoutMinutes = 40,
      [switch]$NoRecord,
      [switch]$DryRun
  )
  $ErrorActionPreference = 'Stop'
  $here = $PSScriptRoot
  $plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
  $repo = [System.IO.Path]::GetFullPath((Join-Path $plugin '..\..'))
  $order = @('QF-NONE', 'QF-FINAL', 'EF-TWO', 'EF-BLOCKED', 'EF-GATE', 'QF-STRUCT', 'POLICY', 'HOOKS', 'INSTR')
  $utf8 = [System.Text.UTF8Encoding]::new($false)

  function Fail([string]$Message) { [Console]::Error.WriteLine("invoke-host-smoke: $Message"); exit 2 }

  if ($Scenario -ceq 'all') {
      if ($Resume) { Fail '-Resume takes one scenario, not all' }
      $ids = $order
  }
  elseif ($order -ccontains $Scenario) { $ids = @($Scenario) }
  else { Fail "unknown scenario '$Scenario' (one of: $($order -join ', '), all)" }

  if (-not $FixtureRoot) { $FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "cogniva-smoke-$AgentHost" }
  $FixtureRoot = [System.IO.Path]::GetFullPath($FixtureRoot)
  if (-not $OutDir) { $OutDir = Join-Path $FixtureRoot 'out' }
  $OutDir = [System.IO.Path]::GetFullPath($OutDir)
  if ($PluginDir) { $PluginDir = [System.IO.Path]::GetFullPath($PluginDir) }

  $runs = @(foreach ($id in $ids) {
      [pscustomobject]@{ Id = $id; Resume = [bool]$Resume }
      if ($Scenario -ceq 'all' -and $id -ceq 'EF-GATE') { [pscustomobject]@{ Id = $id; Resume = $true } }
  })

  function Get-ScenarioData([string]$Id) {
      $dir = Join-Path $here "scenarios\$Id"
      return [pscustomobject]@{ Dir = $dir; Data = (Get-Content -Raw -LiteralPath (Join-Path $dir 'scenario.json') | ConvertFrom-Json) }
  }
  # Claude Code: /cogniva-dev:<skill> <args>; Codex: $<skill> <args>; no skill: the args alone.
  function Get-Prompt($S) {
      $text = [string]$S.Data.args
      if ($S.Data.PSObject.Properties.Name -contains 'argsFile' -and $S.Data.argsFile) {
          $text += "`n" + ([System.IO.File]::ReadAllText((Join-Path $S.Dir $S.Data.argsFile))).Replace("`r`n", "`n").TrimEnd("`n")
      }
      if (-not $S.Data.skill) { return $text }
      if ($AgentHost -eq 'claude-code') { return "/cogniva-dev:$($S.Data.skill) $text" }
      return "`$$($S.Data.skill) $text"
  }
  function Resolve-CodexExe {
      if ($CodexExe) { return $CodexExe }
      $best = $null; $bestVersion = $null
      $extensions = Join-Path $env:USERPROFILE '.vscode\extensions'
      foreach ($d in @(Get-ChildItem -LiteralPath $extensions -Directory -Filter 'openai.chatgpt-*-win32-x64' -ErrorAction SilentlyContinue)) {
          if ($d.Name -notmatch '^openai\.chatgpt-(?<v>\d+(\.\d+){1,3})-win32-x64') { continue }
          $exe = Join-Path $d.FullName 'bin\windows-x86_64\codex.exe'
          $v = [version]$Matches['v']
          if ((Test-Path -LiteralPath $exe) -and ($null -eq $bestVersion -or $v -gt $bestVersion)) { $best = $exe; $bestVersion = $v }
      }
      return $best
  }
  function Get-AgentCommand([string]$Fixture, [string]$FinalFile) {
      if ($AgentHost -eq 'claude-code') {
          $found = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
          $exe = if ($found) { $found.Source } else { 'claude' }
          $list = @('-p', '--output-format', 'stream-json', '--verbose', '--permission-mode', 'bypassPermissions')
          if ($PluginDir) { $list += @('--plugin-dir', $PluginDir, '--setting-sources', 'project,local') }
      }
      else {
          $exe = Resolve-CodexExe
          $list = @('exec', '--json', '--sandbox', 'workspace-write', '-C', $Fixture, '--output-last-message', $FinalFile)
      }
      $list += @($ExtraArgs)
      if ($AgentHost -eq 'codex') { $list += '-' }
      return [pscustomobject]@{ Exe = $exe; Args = $list }
  }
  function Format-Command($Cmd) {
      $parts = @($Cmd.Exe) + @($Cmd.Args)
      return (@($parts | ForEach-Object { if ([string]$_ -match '\s') { "`"$_`"" } else { [string]$_ } }) -join ' ')
  }
  # Runs the agent host from the fixture folder with the prompt on stdin. The
  # session variables a running Claude Code session sets for its own children are
  # removed, so the run is not treated as nested inside the session that launched it.
  function Invoke-Agent($Cmd, [string]$Fixture, [string]$Prompt, [string]$TranscriptFile) {
      $psi = [System.Diagnostics.ProcessStartInfo]::new($Cmd.Exe)
      foreach ($a in $Cmd.Args) { $psi.ArgumentList.Add([string]$a) }
      $psi.WorkingDirectory = $Fixture
      $psi.UseShellExecute = $false
      $psi.RedirectStandardInput = $true
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError = $true
      $psi.StandardInputEncoding = $utf8
      $psi.StandardOutputEncoding = $utf8
      $psi.StandardErrorEncoding = $utf8
      foreach ($name in @($psi.Environment.Keys)) { if ($name -match '^(CLAUDECODE|CLAUDE_PID|CLAUDE_AGENT_SDK_VERSION|CLAUDE_CODE_(ENTRYPOINT|SESSION_ID|CHILD_SESSION|SESSION_ATTENDED|MESSAGING_SOCKET|MESSAGING_TOKEN))\z') { [void]$psi.Environment.Remove($name) } }
      $process = [System.Diagnostics.Process]::Start($psi)
      $stdoutTask = $process.StandardOutput.ReadToEndAsync()
      $stderrTask = $process.StandardError.ReadToEndAsync()
      # An agent host that exits before reading its prompt closes the pipe; the run still counts.
      try { $process.StandardInput.Write($Prompt); $process.StandardInput.Close() } catch [System.IO.IOException] { }
      $timedOut = -not $process.WaitForExit($TimeoutMinutes * 60 * 1000)
      if ($timedOut) { try { $process.Kill($true) } catch { }; $process.WaitForExit() }
      $stdout = $stdoutTask.GetAwaiter().GetResult()
      $stderr = $stderrTask.GetAwaiter().GetResult()
      [System.IO.File]::WriteAllText($TranscriptFile, $stdout, $utf8)
      if ($stderr) { [System.IO.File]::WriteAllText("$TranscriptFile.stderr.txt", $stderr, $utf8) }
      return [pscustomobject]@{ ExitCode = $(if ($timedOut) { 'timeout' } else { $process.ExitCode }); TimedOut = $timedOut; Stdout = $stdout }
  }
  # Claude Code stream-json: the final message is the last "result" event's text.
  function Get-ClaudeFinal([string]$Stdout) {
      $final = ''
      foreach ($line in ($Stdout -split "`r?`n")) {
          if (-not $line.TrimStart().StartsWith('{')) { continue }
          try { $evt = $line | ConvertFrom-Json } catch { continue }
          if ($evt.type -eq 'result' -and $null -ne $evt.result) { $final = [string]$evt.result }
      }
      return $final
  }
  function Format-Cell([string]$Text) { return $Text.Replace("`r", '').Replace("`n", ' ').Replace('|', '\|') }

  if ($DryRun) {
      foreach ($run in $runs) {
          $s = Get-ScenarioData $run.Id
          $stem = if ($run.Resume) { "$($run.Id).resume" } else { $run.Id }
          $fixture = Join-Path $FixtureRoot $run.Id
          $cmd = Get-AgentCommand $fixture (Join-Path $OutDir "$stem.final.txt")
          if (-not $cmd.Exe) { $cmd.Exe = '<codex.exe not found - pass -CodexExe>' }
          Write-Output ("SCENARIO: {0}{1}" -f $run.Id, $(if ($run.Resume) { ' (resume)' } else { '' }))
          Write-Output "FIXTURE: $fixture"
          Write-Output "COMMAND: $(Format-Command $cmd)  (prompt on stdin; working folder = FIXTURE)"
          Write-Output 'PROMPT:'
          Write-Output (Get-Prompt $s)
          Write-Output 'END PROMPT'
          Write-Output ''
      }
      exit 0
  }

  if ($FixtureRoot -match '\s') { Fail "-FixtureRoot must not contain spaces (fixture hook commands are written without quotes): $FixtureRoot" }
  $probe = Get-AgentCommand '<fixture>' (Join-Path $OutDir '<ID>.final.txt')
  if ($AgentHost -eq 'codex' -and (-not $probe.Exe -or -not (Test-Path -LiteralPath $probe.Exe))) { Fail 'codex.exe not found: pass -CodexExe <path>' }
  New-Item -ItemType Directory -Path $FixtureRoot, $OutDir -Force | Out-Null

  $record = $null
  if (-not $NoRecord) {
      if ($RecordPath) { $record = [System.IO.Path]::GetFullPath($RecordPath) }
      else {
          $dir = Join-Path $repo 'docs\host-parity\smoke'
          $base = '{0}-{1}-cli' -f (Get-Date -Format 'yyyy-MM-dd'), $AgentHost
          $rid = $base; $n = 1
          while (Test-Path -LiteralPath (Join-Path $dir "$rid.md")) { $n++; $rid = "$base-$n" }
          $record = Join-Path $dir "$rid.md"
      }
      if (-not (Test-Path -LiteralPath $record)) {
          New-Item -ItemType Directory -Path (Split-Path -Parent $record) -Force | Out-Null
          $rid = [System.IO.Path]::GetFileNameWithoutExtension($record)
          $hostName = if ($AgentHost -eq 'claude-code') { 'Claude Code' } else { 'Codex' }
          $version = 'unknown'
          try { $v = @(& $probe.Exe --version 2>$null) | Select-Object -First 1; if ($v) { $version = ([string]$v).Trim() } } catch { }
          $devVersion = (Get-Content -Raw -LiteralPath (Join-Path $repo 'plugins\cogniva-dev\.claude-plugin\plugin.json') | ConvertFrom-Json).version
          $skillsVersion = (Get-Content -Raw -LiteralPath (Join-Path $repo 'plugins\cogniva-skills\.claude-plugin\plugin.json') | ConvertFrom-Json).version
          $sha = (@(& git -C $repo rev-parse --short HEAD 2>$null) | Select-Object -First 1)
          $source = if ($PluginSource) { $PluginSource } elseif ($AgentHost -eq 'claude-code' -and $PluginDir) { "local marketplace from $repo @ $sha (--plugin-dir $PluginDir)" } else { 'installed marketplace' }
          $lines = @(
              "# Smoke record $rid",
              "Agent host: $hostName",
              "Agent host version: $version",
              'Surface: CLI',
              "OS: Windows 11 $([System.Environment]::OSVersion.Version.Build)",
              "Plugin versions: cogniva-dev $devVersion, cogniva-skills $skillsVersion",
              "Plugin source: $source",
              "Date: $(Get-Date -Format 'yyyy-MM-dd')",
              "Covers: $Covers",
              '',
              '## Scenarios',
              '',
              '| Scenario | Result | Assertion output | Notes |',
              '|---|---|---|---|',
              '',
              '## Observations',
              '',
              "- Command: ``$(Format-Command $probe)`` (prompt on stdin, run from the fixture folder); fixtures under ``$FixtureRoot``, outputs under ``$OutDir``."
          )
          if ($AgentHost -eq 'claude-code' -and $PluginDir) { $lines += '- Isolation: `--setting-sources project,local`, so user-level settings and installed plugins are not loaded; cogniva-dev comes from `--plugin-dir` only.' }
          [System.IO.File]::WriteAllText($record, (($lines -join "`n") + "`n"), $utf8)
      }
  }
  function Add-RecordRow([string]$Row) {
      $lines = [System.Collections.Generic.List[string]]::new([string[]](([System.IO.File]::ReadAllText($record)).Replace("`r`n", "`n").TrimEnd("`n") -split "`n"))
      $obs = $lines.IndexOf('## Observations')
      if ($obs -lt 0) { Fail "record has no '## Observations' heading: $record" }
      $at = $obs
      for ($i = $obs - 1; $i -ge 0; $i--) { if ($lines[$i].StartsWith('|')) { $at = $i + 1; break } }
      $lines.Insert($at, $Row)
      [System.IO.File]::WriteAllText($record, (($lines -join "`n") + "`n"), $utf8)
  }

  $summary = @()
  foreach ($run in $runs) {
      $s = Get-ScenarioData $run.Id
      $label = if ($run.Resume) { "$($run.Id) (resume)" } else { $run.Id }
      $stem = if ($run.Resume) { "$($run.Id).resume" } else { $run.Id }
      $fixture = Join-Path $FixtureRoot $run.Id
      $finalFile = Join-Path $OutDir "$stem.final.txt"
      $transcript = Join-Path $OutDir "$stem.transcript.jsonl"
      if ($run.Resume) {
          if (-not (Test-Path -LiteralPath (Join-Path $fixture '.smoke\start.txt'))) { Fail "-Resume: no fixture at $fixture - run $($run.Id) without -Resume first" }
      }
      else {
          if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
          $build = @(& pwsh -NoProfile -File (Join-Path $here 'new-smoke-fixture.ps1') -Path $fixture -Scenario $run.Id 2>&1)
          if ($LASTEXITCODE -ne 0) { Fail "building the $($run.Id) fixture failed: $($build -join ' ')" }
      }
      if (Test-Path -LiteralPath $finalFile) { Remove-Item -LiteralPath $finalFile -Force }
      $cmd = Get-AgentCommand $fixture $finalFile
      Write-Output "RUN: $label - $(Format-Command $cmd)"
      $watch = [System.Diagnostics.Stopwatch]::StartNew()
      $agentRun = Invoke-Agent $cmd $fixture (Get-Prompt $s) $transcript
      $watch.Stop()
      if ($AgentHost -eq 'claude-code') { [System.IO.File]::WriteAllText($finalFile, (Get-ClaudeFinal $agentRun.Stdout), $utf8) }
      elseif (-not (Test-Path -LiteralPath $finalFile)) { [System.IO.File]::WriteAllText($finalFile, '', $utf8) }

      $assertArgs = @('-NoProfile', '-File', (Join-Path $here 'assert-smoke-outcome.ps1'), '-Fixture', $fixture, '-Scenario', $run.Id, '-FinalMessage', $finalFile)
      if ($run.Resume) { $assertArgs += '-Resume' }
      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try { $assertOut = @(& pwsh @assertArgs 2>&1 | ForEach-Object { [string]$_ }); $assertCode = $LASTEXITCODE }
      finally { $ErrorActionPreference = $previous }
      [System.IO.File]::WriteAllText((Join-Path $OutDir "$stem.assert.txt"), (($assertOut -join "`n") + "`n"), $utf8)
      $result = switch ($assertCode) { 0 { 'pass' } 1 { 'fail' } default { 'not-run' } }
      if ($agentRun.TimedOut) { $result = 'not-run' }

      $verdict = @($assertOut | Where-Object { $_.StartsWith('SMOKE ') }) | Select-Object -First 1
      $failed = @($assertOut | Where-Object { $_.StartsWith('FAIL ') })
      $cell = (@($verdict) + $failed | Where-Object { $_ }) -join '; '
      if ($cell.Length -gt 400) { $cell = $cell.Substring(0, 400) + '...' }
      $notes = @("exit $($agentRun.ExitCode)", "$([int]$watch.Elapsed.TotalSeconds)s", "final: $stem.final.txt")
      if ($agentRun.TimedOut) { $notes += "timed out after $TimeoutMinutes min" }
      if ($AgentHost -eq 'claude-code') { $notes += $(if ($agentRun.Stdout -match '"name"\s*:\s*"Workflow"') { 'Workflow tool called' } else { 'no Workflow tool call' }) }
      if ($record) { Add-RecordRow ("| {0} | {1} | {2} | {3} |" -f (Format-Cell $label), $result, (Format-Cell $cell), (Format-Cell ($notes -join '; '))) }
      $summary += [pscustomobject]@{ Label = $label; Result = $result }
      Write-Output "SMOKE-RUN $($label): $result"
  }
  if ($record) { Write-Output "RECORD: $record" }
  if (@($summary | Where-Object { $_.Result -ne 'pass' }).Count) { exit 1 }
  exit 0
  ```
- [ ] **Step 4 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1` → every line `PASS`, last line `All smoke-assertions assertions passed.`, exit 0.
- [ ] **Step 5 (look at a real rendering):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost codex -Scenario QF-NONE -DryRun` → a `COMMAND:` line naming `...\openai.chatgpt-<newest version>-win32-x64\bin\windows-x86_64\codex.exe exec --json --sandbox workspace-write -C ...` (or `<codex.exe not found - pass -CodexExe>` on a machine without the extension) and a `PROMPT:` block starting `$quick-fix "Make Add-Numbers`. Do NOT run without `-DryRun` in this task.
- [ ] **Step 6 (commit):** `git add plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.tests.ps1` then `git commit -m "test(host-smoke): headless Claude Code and Codex smoke driver with smoke records"`

## Task 4: Workflow-template harness, gated

**Files:**
- Create: `plugins/cogniva-dev/tests/workflow-template/run-template.mjs`
- Test: `plugins/cogniva-dev/tests/workflow-template/workflow-template.tests.ps1`
- Modify: `.claude/cogniva-dev/green-gate.json`

Context: `plugins/cogniva-dev/templates/execute-feature.workflow.js` starts
with `export const meta = {…}` and otherwise is a script body that reads the
globals `args`, `phase`, `log`, `agent` and ends with a top-level `return`.
Turning `export const meta` into `const meta` and compiling the rest as an
AsyncFunction body with those four parameters runs it faithfully in Node; the
harness refuses any template with another module statement. Do not modify the
template. Node needs no packages. Code below is indented two spaces to sit
inside its step; write it without that indent.

- [ ] **Step 1 (failing test):** Create `plugins/cogniva-dev/tests/workflow-template/workflow-template.tests.ps1` with exactly:
  ```powershell
  #Requires -Version 7.0
  # Dependency-free tests for templates/execute-feature.workflow.js: the template
  # runs in plain Node through run-template.mjs with a stubbed agent, so its
  # dispatch order, BLOCKED / gate / null-result stops, result aggregation and the
  # commit-policy lines of its prompts are pinned without the Workflow runtime.
  # Needs node.
  $ErrorActionPreference = 'Stop'
  $here = $PSScriptRoot
  $runner = Join-Path $here 'run-template.mjs'
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-workflow-template-" + [guid]::NewGuid().ToString('N'))
  $failures = @()

  function Check($label, $condition) {
      if ($condition) { Write-Host "  PASS  $label" }
      else { Write-Host "  FAIL  $label"; $script:failures += $label }
  }
  $caseNo = 0
  function Invoke-Case([hashtable]$Case) {
      $script:caseNo++
      $file = Join-Path $script:root ("case-{0:d2}.json" -f $script:caseNo)
      [System.IO.File]::WriteAllText($file, ($Case | ConvertTo-Json -Depth 20))
      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try { $out = (@(& node $runner $file 2>&1) | ForEach-Object { [string]$_ }) -join "`n"; $code = $LASTEXITCODE }
      finally { $ErrorActionPreference = $previous }
      $json = $null
      try { $json = $out | ConvertFrom-Json } catch { $json = $null }
      if ($code -ne 0 -and -not ($json -and $json.error)) { Write-Host "    (case $($script:caseNo): exit $($code): $out)" }
      return [pscustomobject]@{ Code = $code; Run = $json }
  }
  function Task([int]$N, [string]$Title, [switch]$Gate, [switch]$Done) {
      return [ordered]@{ n = $N; title = $Title; body = "Body of task $N."; isGate = [bool]$Gate; done = [bool]$Done }
  }
  $plan = 'C:/ws/docs/plans/M/F/F-plan.md'
  function Base([string]$Commits) {
      $a = [ordered]@{ workspace = 'C:/ws'; branch = 'feature/x'; planPath = $plan; tasks = @((Task 1 'One'), (Task 2 'Two'), (Task 3 'Three')) }
      if ($Commits) { $a.commits = $Commits }
      return $a
  }
  function Labels($Run) { return (@($Run.calls | ForEach-Object { $_.label }) -join ',') }

  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
      Write-Host '  FAIL  node is required for the workflow-template suite'
      exit 1
  }

  try {
      New-Item -ItemType Directory -Path $root -Force | Out-Null

      $r = (Invoke-Case @{ args = (Base 'task') }).Run
      Check 'all DONE: every task is dispatched once, in order' ((Labels $r) -eq 'task-1,task-2,task-3')
      Check 'all DONE: allDone, nothing blocked, no gate' ($r.returned.allDone -eq $true -and $null -eq $r.returned.blocked -and $r.returned.gateHit -eq $false -and (@($r.returned.done) -join ',') -eq 'task-1,task-2,task-3')
      Check 'the run opens the Execute phase and every dispatch is in it' ((@($r.phases) -join ',') -eq 'Execute' -and @($r.calls | Where-Object { $_.phase -ne 'Execute' }).Count -eq 0)
      Check 'every dispatch carries the result schema (status, summary required)' (@($r.calls | Where-Object { (@($_.schema.required) -join ',') -ne 'status,summary' }).Count -eq 0)
      $p = $r.calls[0].prompt
      Check 'commits=task: tick the plan FIRST, then stage and commit' ($p.Contains("On success: FIRST edit $plan to flip THIS task's checkboxes") -and $p.Contains('Then stage ONLY the files you changed and commit') -and $p.IndexOf('FIRST edit') -lt $p.IndexOf('Then stage ONLY'))
      Check 'commits=task: no do-not-commit line' (-not $p.Contains('Do NOT stage or commit anything'))
      Check 'the prompt names the workspace and the branch' ($p.Contains('Your only working directory is: C:/ws') -and $p.Contains('You are already checked out on feature/x'))
      Check 'the prompt ends with the task heading and its verbatim body' ($p.Contains("=== TASK 1: One ===`nBody of task 1."))
      Check 'no statePath: no state-log line' (-not $p.Contains('Append one short line'))

      $r = (Invoke-Case @{ args = (Base 'task'); results = @{ 'task-2' = @{ status = 'BLOCKED'; summary = ''; note = 'missing file' } } }).Run
      Check 'BLOCKED on task 2 of 3: task 3 is never dispatched' ((Labels $r) -eq 'task-1,task-2')
      Check 'BLOCKED on task 2 of 3: blocked is task-2, not allDone, note kept' ($r.returned.blocked -eq 'task-2' -and $r.returned.allDone -eq $false -and $r.returned.results[1].note -eq 'missing file' -and (@($r.logs) -join "`n").Contains('Stopping: task-2 is blocked.'))

      $gateArgs = Base 'task'
      $gateArgs.tasks = @((Task 1 'One'), (Task 2 'Gate' -Gate), (Task 3 'Three'))
      $r = (Invoke-Case @{ args = $gateArgs }).Run
      Check 'a DONE gate task: the run stops after it' ((Labels $r) -eq 'task-1,task-2')
      Check 'a DONE gate task: gateHit, not allDone, nothing blocked' ($r.returned.gateHit -eq $true -and $r.returned.allDone -eq $false -and $null -eq $r.returned.blocked -and (@($r.logs) -join "`n").Contains('task-2 is a manual-validation gate'))

      $r = (Invoke-Case @{ args = (Base 'task'); results = @{ 'task-1' = $null } }).Run
      Check 'agent returns null: the task is BLOCKED with the null note and the run stops' ((Labels $r) -eq 'task-1' -and $r.returned.results[0].status -eq 'BLOCKED' -and $r.returned.results[0].note -eq 'agent returned null (skipped or terminal error)' -and $r.returned.blocked -eq 'task-1')

      $doneArgs = Base 'task'
      $doneArgs.tasks = @((Task 1 'One' -Done), (Task 2 'Two'))
      $r = (Invoke-Case @{ args = $doneArgs }).Run
      Check 'done tasks are skipped, recorded SKIPPED, and allDone still holds' ((Labels $r) -eq 'task-2' -and $r.returned.results[0].status -eq 'SKIPPED' -and $r.returned.allDone -eq $true -and (@($r.returned.done) -join ',') -eq 'task-2')

      $r = (Invoke-Case @{ args = (Base 'task'); results = @{
                  'task-1' = @{ status = 'DONE'; summary = 'a'; followups = @(@{ description = 'first'; receipt = 'x.ps1:1'; strength = 'clear' }) }
                  'task-3' = @{ status = 'DONE'; summary = 'c'; followups = @(@{ description = 'second'; receipt = 'y.ps1:2'; strength = 'ambiguous' }) }
              } }).Run
      $f = @($r.returned.followups)
      Check 'followups are aggregated in task order, each with its task number' ($f.Count -eq 2 -and $f[0].description -eq 'first' -and $f[0].task -eq 1 -and $f[1].description -eq 'second' -and $f[1].task -eq 3)

      $multi = [ordered]@{ workspace = 'C:/ws'; branch = 'feature/x'; planPath = $plan; commits = 'task'; tasks = @(
              [ordered]@{ n = 1; title = 'A'; body = 'a'; isGate = $false; done = $false; subplan = '01-x'; planPath = 'C:/ws/sub/01-x.md' },
              [ordered]@{ n = 1; title = 'B'; body = 'b'; isGate = $false; done = $false; subplan = '02-y'; planPath = 'C:/ws/sub/02-y.md' }) }
      $r = (Invoke-Case @{ args = $multi; results = @{ '02-y/task-1' = @{ status = 'DONE'; summary = 'b'; followups = @(@{ description = 'later'; receipt = 'z.ps1:3'; strength = 'clear' }) } } }).Run
      Check 'sub-plan tasks: tags carry the sub-plan, and each task ticks its own plan' ((Labels $r) -eq '01-x/task-1,02-y/task-1' -and $r.calls[1].prompt.Contains('FIRST edit C:/ws/sub/02-y.md') -and (@($r.returned.done) -join ',') -eq '01-x/task-1,02-y/task-1')
      Check 'sub-plan tasks: a followup carries its sub-plan and task number' (@($r.returned.followups).Count -eq 1 -and $r.returned.followups[0].subplan -eq '02-y' -and $r.returned.followups[0].task -eq 1)

      foreach ($policy in 'none', 'final') {
          $p = (Invoke-Case @{ args = (Base $policy) }).Run.calls[0].prompt
          Check "commits=$($policy): the prompt says Do NOT stage or commit anything and never asks for a commit" ($p.Contains('Do NOT stage or commit anything: leave the files you changed in the working tree.') -and -not $p.Contains('Then stage ONLY'))
          Check "commits=$($policy): the agent still ticks its own task" ($p.Contains("On success: edit $plan to flip THIS task's checkboxes"))
      }

      $noPlan = Base 'task'
      $noPlan.Remove('planPath')
      $p = (Invoke-Case @{ args = $noPlan }).Run.calls[0].prompt
      Check 'no planPath, commits=task: no tick line, still the commit line, nothing undefined' (-not $p.Contains('checkboxes') -and $p.Contains('Then stage ONLY the files you changed') -and -not $p.Contains('undefined'))
      $noPlan.commits = 'none'
      $p = (Invoke-Case @{ args = $noPlan }).Run.calls[0].prompt
      Check 'no planPath, commits=none: no tick line, nothing undefined' (-not $p.Contains('checkboxes') -and $p.Contains('Do NOT stage or commit anything') -and -not $p.Contains('undefined'))

      $r = (Invoke-Case @{ args = (Base 'task'); argsAsString = $true }).Run
      Check 'args passed as a JSON string work the same' ((Labels $r) -eq 'task-1,task-2,task-3' -and $r.returned.allDone -eq $true)
      $p = (Invoke-Case @{ args = (Base '') }).Run.calls[0].prompt
      Check 'no commits arg defaults to task (tick then commit)' ($p.Contains('Then stage ONLY the files you changed'))
      $legacy = [ordered]@{ worktree = 'C:/wt'; featureBranch = 'feature/legacy'; planPath = $plan; tasks = @((Task 1 'One')) }
      $p = (Invoke-Case @{ args = $legacy }).Run.calls[0].prompt
      Check 'legacy worktree / featureBranch names still work' ($p.Contains('Your only working directory is: C:/wt') -and $p.Contains('You are already checked out on feature/legacy'))
      $withState = Base 'task'
      $withState.statePath = 'C:/ws/docs/plans/M/F/state.md'
      $p = (Invoke-Case @{ args = $withState }).Run.calls[0].prompt
      Check 'statePath: the state-log line names it' ($p.Contains('Append one short line to C:/ws/docs/plans/M/F/state.md'))

      $bad = Join-Path $root 'extra-export.workflow.js'
      [System.IO.File]::WriteAllText($bad, "export const meta = { name: 'x' }`nexport function helper() {}`nreturn 1`n")
      $r = Invoke-Case @{ args = (Base 'task'); templatePath = $bad }
      Check 'harness: a template with another export is refused, not mis-evaluated' ($r.Code -eq 1 -and $r.Run.error -match 'module statement')
      $bad = Join-Path $root 'no-meta.workflow.js'
      [System.IO.File]::WriteAllText($bad, "const meta = {}`nreturn 1`n")
      $r = Invoke-Case @{ args = (Base 'task'); templatePath = $bad }
      Check 'harness: a template without export const meta is refused' ($r.Code -eq 1 -and $r.Run.error -match 'export const meta')
  }
  finally {
      if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
  }

  if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
  Write-Host ''
  Write-Host 'All workflow-template assertions passed.'
  exit 0
  ```
- [ ] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/workflow-template/workflow-template.tests.ps1` → `FAIL` lines, then an error from a case with no result (node cannot find `run-template.mjs`); exit 1.
- [ ] **Step 3 (implement):** Create `plugins/cogniva-dev/tests/workflow-template/run-template.mjs` with exactly:
  ```javascript
  // Runs templates/execute-feature.workflow.js in plain Node with stubbed
  // Workflow globals, so its dispatch logic and the prompts it builds can be
  // tested without the Workflow runtime. The template is evaluated as an
  // AsyncFunction body after its one module statement, `export const meta`, is
  // turned into a plain `const`.
  //
  // Exported API (other suites reuse it):
  //   DEFAULT_TEMPLATE
  //       Absolute path of plugins/cogniva-dev/templates/execute-feature.workflow.js.
  //   loadTemplateSource(templatePath = DEFAULT_TEMPLATE) -> string
  //       The source with `export const meta` made a plain `const`. Throws if
  //       that statement is missing or the template has any other top-level
  //       import/export (the harness could not evaluate it faithfully).
  //   runTemplate({ args, results = {}, argsAsString = false, templatePath = DEFAULT_TEMPLATE }) -> Promise<Run>
  //       Evaluates the template with injected globals `args`, `phase`, `log`
  //       and `agent`. `results` maps a task tag - 'task-<n>', or
  //       '<subplan>/task-<n>' for a sub-plan task - to what `agent` returns for
  //       that task (an object, or null). A tag with no entry returns
  //       { status: 'DONE', summary: 'ok' }. `argsAsString` passes `args` as a
  //       JSON string, as some Workflow runtimes do.
  //       Run = { returned, calls: [{ label, phase, prompt, schema }], logs: [string], phases: [string] }
  //       `returned` is the template's return value; `calls` are the agent
  //       dispatches in order, each with the prompt and the result schema passed.
  //   renderPrompts(args, templatePath = DEFAULT_TEMPLATE) -> Promise<string[]>
  //       The prompts the template builds, in dispatch order, when every task
  //       returns DONE (a gate task still ends the run after it).
  // CLI: node run-template.mjs <case.json>
  //   case.json = { args, results?, argsAsString?, templatePath? }. Prints the Run
  //   as JSON and exits 0, or prints { "error": "<message>" } and exits 1.
  import { readFileSync } from 'node:fs';
  import { fileURLToPath, pathToFileURL } from 'node:url';

  export const DEFAULT_TEMPLATE = fileURLToPath(new URL('../../templates/execute-feature.workflow.js', import.meta.url));
  const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;

  export function loadTemplateSource(templatePath = DEFAULT_TEMPLATE) {
    const raw = readFileSync(templatePath, 'utf8').replace(/^﻿/, '');
    const exportMeta = /^export\s+const\s+meta\b/m;
    if (!exportMeta.test(raw)) throw new Error('template has no "export const meta" statement');
    const source = raw.replace(exportMeta, 'const meta');
    if (/^\s*(import|export)\b/m.test(source)) throw new Error('template has a module statement other than "export const meta"; the harness cannot evaluate it');
    return source;
  }

  export async function runTemplate({ args, results = {}, argsAsString = false, templatePath = DEFAULT_TEMPLATE } = {}) {
    const calls = [];
    const logs = [];
    const phases = [];
    const agent = async (prompt, opts = {}) => {
      calls.push({ label: opts.label, phase: opts.phase, prompt, schema: opts.schema ?? null });
      if (Object.prototype.hasOwnProperty.call(results, opts.label)) return results[opts.label];
      return { status: 'DONE', summary: 'ok' };
    };
    const body = new AsyncFunction('args', 'phase', 'log', 'agent', loadTemplateSource(templatePath));
    const returned = await body(
      argsAsString ? JSON.stringify(args) : args,
      title => { phases.push(String(title)); },
      message => { logs.push(String(message)); },
      agent,
    );
    return { returned, calls, logs, phases };
  }

  export async function renderPrompts(args, templatePath = DEFAULT_TEMPLATE) {
    const run = await runTemplate({ args, templatePath });
    return run.calls.map(c => c.prompt);
  }

  const invokedDirectly = !!process.argv[1] && import.meta.url.toLowerCase() === pathToFileURL(process.argv[1]).href.toLowerCase();
  if (invokedDirectly) {
    try {
      const kase = JSON.parse(readFileSync(process.argv[2], 'utf8').replace(/^﻿/, ''));
      const run = await runTemplate({
        args: kase.args,
        results: kase.results ?? {},
        argsAsString: !!kase.argsAsString,
        templatePath: kase.templatePath ?? DEFAULT_TEMPLATE,
      });
      process.stdout.write(JSON.stringify(run));
    } catch (e) {
      process.stdout.write(JSON.stringify({ error: String((e && e.message) || e) }));
      process.exitCode = 1;
    }
  }
  ```
- [ ] **Step 4 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/workflow-template/workflow-template.tests.ps1` → every line `PASS`, last line `All workflow-template assertions passed.`, exit 0.
- [ ] **Step 5 (wire into the green gate):** In `.claude/cogniva-dev/green-gate.json`, add a comma after the closing `}` of the current last object in `commands` (the `smoke-assertions` entry) and append this object as the new last element:
  ```json
      { "run": "pwsh -NoProfile -File plugins/cogniva-dev/tests/workflow-template/workflow-template.tests.ps1", "label": "workflow-template", "note": "Runs the execute-feature Workflow template in plain Node with a stubbed agent: dispatch order, BLOCKED / gate / null-result stops, commit-policy prompt lines; needs PowerShell 7 and node." }
  ```
  Then: `pwsh -NoProfile -Command "(Get-Content -Raw .claude/cogniva-dev/green-gate.json | ConvertFrom-Json).commands[-1].label"` → `workflow-template`.
- [ ] **Step 6 (run the gate):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → last line `green-gate: GREEN - all N command(s) exited 0.`
- [ ] **Step 7 (commit):** `git add plugins/cogniva-dev/tests/workflow-template/run-template.mjs plugins/cogniva-dev/tests/workflow-template/workflow-template.tests.ps1 .claude/cogniva-dev/green-gate.json` then `git commit -m "test(workflow-template): run the execute-feature Workflow template in Node, gated as workflow-template"`

## Task 5: Runbook

**Files:**
- Create: `plugins/cogniva-dev/tests/host-smoke/README.md`

- [ ] **Step 1 (write the runbook):** Create `plugins/cogniva-dev/tests/host-smoke/README.md` with exactly the content inside the four-backtick fence (indented two spaces here; the file has no indent, and its headings start in column 0):
  ````markdown
  # Agent-host smoke harness

  Runs the same small lifecycle scenarios on Claude Code and on Codex, each in a
  throwaway fixture repository, and checks every outcome from git and file
  state - never from the agent's own account of what it did. Results go into
  smoke records under `docs/host-parity/smoke/`, the evidence that
  `docs/host-parity.md` (the parity record) cites for a `verified` status.

  ## What it proves, and what it does not

  It proves, for one agent host on one surface (CLI, VS Code or desktop) at one
  plugin version, that each scenario left the expected state: the commits each
  `commits=` policy allows and no others, the branch unchanged, pre-existing
  uncommitted work untouched, plan checkboxes ticked or left open, the full
  `READY FOR REVIEW` handoff, a blocked task or a branch-policy stop that writes
  nothing, the structural check reporting an expected change, a hook denying an
  edit of the primary checkout, and the repository instructions (root and nested
  `AGENTS.md`) reaching the agent that writes the file.

  It does not prove: that the work is good beyond the fixture's own checks; any
  behaviour in a repository other than the fixture; worktree mode under Codex
  (unsupported there); that hooks catch writes made through a shell command
  (they do not, on either agent host); anything about a surface, agent host
  version or plugin version the record does not name.

  The green gate runs only the deterministic parts, with no model:
  `assert-smoke-outcome.tests.ps1` (label `smoke-assertions`) proves the scenario
  files, the fixture generator, every assertion key against simulated outcomes
  and the driver's `-DryRun` output; `../workflow-template/workflow-template.tests.ps1`
  (label `workflow-template`) runs the execute-feature Workflow template in Node
  with a stubbed agent. Real runs cost model tokens and are never gated.

  ## Files

  | File | What it does |
  |---|---|
  | `scenarios/<ID>/scenario.json` | The scenario: skill, arguments, branch, seeded plan, and `expect` (plus `resumeExpect` for the second EF-GATE run) |
  | `scenarios/<ID>/plan.md`, `scenarios/POLICY/pasted-plan.md` | The plan a scenario seeds, or pastes into the prompt |
  | `new-smoke-fixture.ps1` | `-Path <dir> -Scenario <ID>`: builds the fixture repository and records its start state in `.smoke/` |
  | `assert-smoke-outcome.ps1` | `-Fixture <dir> -Scenario <ID> -FinalMessage <file> [-Resume] [-Json]`: checks the outcome; `PASS`/`FAIL` per key, then `SMOKE <ID>: PASS` or `FAIL` |
  | `invoke-host-smoke.ps1` | Builds the fixture, runs one agent host headless, saves the final message and transcript, asserts, and writes the smoke record; `-DryRun` only prints |
  | `assert-smoke-outcome.tests.ps1` | The gated self-test (`smoke-assertions`) |

  ## Scenarios

  | ID | Run | What must hold |
  |---|---|---|
  | QF-NONE | quick-fix, `commits=none` | 0 commits; `src/Calc/Calc.ps1` and its test changed; unrelated work untouched; every handoff section |
  | QF-FINAL | quick-fix, `commits=final` | exactly 1 commit, and unrelated work is not in it |
  | EF-TWO | execute-feature `Smoke/TwoTasks commits=task plan=persisted` | 2 commits; both tasks ticked; every handoff section |
  | EF-BLOCKED | execute-feature `Smoke/Blocked commits=task plan=persisted` | task 1 needs a file that does not exist: 0 commits, both tasks open, no new file, `BLOCKED` in the final message |
  | EF-GATE | execute-feature `Smoke/Gate commits=task plan=persisted`, then the same again | first run stops after the ⛔ task 2 (2 commits, task 3 open); the second run does task 3 only (3 commits) and hands off |
  | QF-STRUCT | quick-fix adding a ProjectReference under the `dotnet` profile | `STRUCTURE: FOUND` and no `dependency-added UNEXPECTED` in the final message |
  | POLICY | execute-feature with a pasted plan, on `main` | stops naming `feature/`: no commit, no new file (ignored ones included), `.git/info/exclude` unchanged |
  | HOOKS | a plain prompt with worktree mode on | the direct edit of the primary checkout is denied: `src/Calc/Calc.ps1` unchanged |
  | INSTR | quick-fix creating `src/Calc/Divide.ps1` | the new file starts with `# canary-7` (root `AGENTS.md`) then `# nested-canary-3` (`src/Calc/AGENTS.md`) |

  Every scenario also checks the branch and that `notes/unrelated.txt` (dirty
  before the run) keeps its content and is in no new commit. The fixture's
  `AGENTS.md` tells the agent the run is unattended: never wait for an answer,
  go ahead with `notes/unrelated.txt` dirty, and accept a proposed plan name.

  ## Installing the branch build

  ### Claude Code

  - **Headless (what the driver does):** pass
    `-PluginDir <checkout>\plugins\cogniva-dev`. The driver runs
    `claude -p --plugin-dir <dir> --setting-sources project,local`, which loads
    the checkout's plugin for that run only; user settings and installed plugins
    stay off, so an installed copy cannot shadow it.
  - **VS Code:** in the Claude Code panel run
    `/plugin marketplace remove cogniva` (the published marketplace uses the same
    name), then `/plugin marketplace add <checkout>`, then
    `/plugin install cogniva-dev@cogniva` (and `cogniva-skills@cogniva`), and
    reload the window. To go back, remove it and add `cogniva/cogniva-skills`
    again.

  ### Codex

  - There is no `codex` on PATH. The binary ships with the VS Code extension:
    `%USERPROFILE%\.vscode\extensions\openai.chatgpt-<version>-win32-x64\bin\windows-x86_64\codex.exe`
    (use the newest version folder; the driver picks it by default).
  - `codex plugin marketplace remove cogniva` (the published marketplace uses
    the same name), then `codex plugin marketplace add <checkout>`, then install
    `cogniva-dev` and `cogniva-skills` from `/plugins` in a Codex session (or
    `codex plugin add cogniva-dev@cogniva`). Start a NEW session: a plugin's
    skills are not visible in the session that installed it.
  - Check the install: `%USERPROFILE%\.codex\plugins\cache\cogniva\cogniva-dev\<version>\`
    holds the checkout's files.
  - Hooks: Codex runs a plugin hook only after you trust it. A build whose
    `hooks/hooks.json` changed has new hook hashes, so re-trust the hooks with
    `/hooks` in the Codex CLI after installing it.
  - To go back: `codex plugin marketplace remove cogniva`, then
    `codex plugin marketplace add https://github.com/cogniva/cogniva-skills.git`.

  ## Headless runs (CLI)

  From the checkout root:

  ```
  pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost claude-code -Scenario all -PluginDir plugins/cogniva-dev
  pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost codex -Scenario all
  ```

  - `-Scenario all` runs the nine scenarios and then EF-GATE again on the same
    fixture (the resume run). One scenario: `-Scenario QF-NONE`; its resume
    run: `-Scenario EF-GATE -Resume`.
  - Each invocation starts a new record `docs/host-parity/smoke/<date>-<claude-code|codex>-cli.md`
    (`-2`, `-3` the same day) and prints `RECORD: <path>`. Pass
    `-RecordPath <that path>` to add later runs to the same record.
  - Fixtures go to `$env:TEMP\cogniva-smoke-<claude-code|codex>\<ID>\` and outputs to its
    `out\` folder: `<ID>.final.txt`, `<ID>.transcript.jsonl`, `<ID>.assert.txt`.
  - `-DryRun` prints, for each run, the fixture folder, the exact command and
    the prompt, and runs nothing.
  - Safety: the agent runs without permission prompts (Claude Code
    `--permission-mode bypassPermissions`; Codex `exec --sandbox workspace-write`)
    only inside a fixture the driver has just built in a temp folder, with no
    remote. There is no option to point the driver at another repository.

  ## GUI procedure (VS Code, either agent host)

  1. Build a fixture: `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/new-smoke-fixture.ps1 -Path $env:TEMP\cogniva-smoke-gui\<ID> -Scenario <ID>`.
  2. Print the invocation: `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost <claude-code|codex> -Scenario <ID> -DryRun`
     and copy the text between `PROMPT:` and `END PROMPT`.
  3. Open the fixture folder in a new VS Code window. Trust the folder if asked
     (note any trust or approval prompt for the record).
  4. Paste the invocation into the agent panel (Claude Code: the `/cogniva-dev:`
     line; Codex: the `$` line). Answer approval prompts as a user would, and
     count them.
  5. When the agent finishes, copy its final message into
     `<fixture>\.smoke\final.txt`.
  6. Check it: `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/assert-smoke-outcome.ps1 -Fixture <fixture> -Scenario <ID> -FinalMessage <fixture>\.smoke\final.txt`
     (EF-GATE second run: add `-Resume`, after pasting the same invocation
     again in the same window).
  7. Add a row to the record for that agent host and surface (below), with the
     `SMOKE` line and any `FAIL` lines as the assertion output.

  ## Smoke records

  `docs/host-parity/smoke/<YYYY-MM-DD>-<claude-code|codex>-<cli|vscode|desktop>.md`
  (`-2`, `-3` if repeated the same day). The driver writes CLI records; write a
  GUI record by hand with exactly these first lines:

  ```
  # Smoke record <record-id>
  Agent host: Claude Code | Codex
  Agent host version: <version string>
  Surface: CLI | VS Code | Desktop
  OS: Windows 11 <build>
  Plugin versions: cogniva-dev <x.y.z>, cogniva-skills <x.y.z>
  Plugin source: <installed marketplace | local marketplace from <path> @ <short sha>>
  Date: <YYYY-MM-DD>
  Covers: <comma-separated parity-record row IDs this record supports>
  ```

  then `## Scenarios` with the table
  `| Scenario | Result | Assertion output | Notes |` (Result is `pass`,
  `fail` or `not-run`), then `## Observations` (approval prompts, trust prompts,
  surprises). `check-host-parity.ps1` counts a record toward `verified` only for
  the row IDs in its `Covers:` and only if no row says `fail`; a record whose
  cogniva-dev major.minor is older than the current one is reported as stale
  evidence.

  ## Known limits

  - A run that hits the timeout (`-TimeoutMinutes`, default 40) is `not-run`.
  - If the agent host ends a headless run before a background Workflow
    finishes, the final message lacks the handoff and the run fails; the Notes
    cell says whether the Workflow tool was called.
  - Under Codex, `.git` may be read-only in the sandbox, which stops snapshots,
    commits and `.git/info/exclude` writes; a project-local hook runs only in a
    trusted project, after `/hooks` trust.

  ## Cost

  Every real run spends model tokens (a full `-Scenario all` is ten agent
  sessions). Run the matrix at a release, and after a change to an agent host or
  to the adapters between them (skill overlays, hook input parsing, the worker
  contract) - not on every pull request.
  ````
- [ ] **Step 2 (check it against the harness):** in PowerShell 7, from the repo root, run
  ```powershell
  $t = Get-Content -Raw plugins/cogniva-dev/tests/host-smoke/README.md
  @('QF-NONE', 'QF-FINAL', 'EF-TWO', 'EF-BLOCKED', 'EF-GATE', 'QF-STRUCT', 'POLICY', 'HOOKS', 'INSTR', 'smoke-assertions', 'workflow-template', '-DryRun', '-PluginDir', 'codex plugin marketplace add', '/hooks', '## Cost') | Where-Object { -not $t.Contains($_) }
  ```
  → prints nothing (every term is in the runbook). Then `pwsh -NoProfile -File plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1 -AgentHost claude-code -Scenario EF-GATE -Resume -DryRun` → `SCENARIO: EF-GATE (resume)` and a `/cogniva-dev:execute-feature Smoke/Gate commits=task plan=persisted` prompt (the runbook's resume instruction works as written).
- [ ] **Step 3 (commit):** `git add plugins/cogniva-dev/tests/host-smoke/README.md` then `git commit -m "docs(host-smoke): smoke harness runbook - install, headless, GUI, records, cost"`
