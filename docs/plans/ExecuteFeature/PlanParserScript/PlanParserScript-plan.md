# PlanParserScript — Feature Plan

> REQUIRED EXECUTOR: /cogniva-dev:execute-feature ExecuteFeature/PlanParserScript
> Tasks contain NO git worktree/branch step — execute-feature creates the worktree
> and the tasks commit on the feature branch they are already on. Never run
> git switch/checkout/branch inside a task.

**Goal:** Replace the hand-parsing the execute-feature skill does on every run ("Step 1 —
parse the plan into tasks") with a deterministic `scripts/parse-plan-tasks.ps1` that emits the
`{ n, title, body, isGate, done }` task array as JSON, and rewire SKILL.md Step 1 to call it.

**Architecture:** Today `skills/execute-feature/SKILL.md` Step 1 tells the executing model to
build, from scratch, an ordered task array out of the plan markdown — identical token-burning
work every invocation. We move that parse into a sibling PowerShell script (matching
`new-feature-worktree.ps1` / `integrate-feature.ps1`: `-NoProfile`-friendly, single JSON on
stdout, non-zero exit + stderr on failure). The parsing contract is fixed and load-bearing —
`templates/execute-feature.workflow.js` feeds each task's `body` verbatim to a per-task agent:

- **Task heading** = a line matching `^##\s+(⛔\s*)?Task\s+(\d+):\s*(.*)$`. `n` = the number
  (integer), `title` = the remainder, `isGate` = the ⛔ marker is present. Heading detection is
  **per-line, NOT fence-aware** — the required `Task N:` keyword is narrow enough that example
  `## …` lines inside fenced code blocks never match. (Known, deliberate limitation: a literal
  `## Task N:` line inside a fenced example would misfire; no real plan writes one. The keyword
  narrowness is the guard, and that matches the behaviour the skill relies on today.)
- **body** = every line AFTER the heading up to (not including) the next task heading, verbatim
  — fenced code blocks, `- [ ]` examples and all. Line endings are normalised to LF.
- **done** = the task is fully checked: among checkbox lines that are **NOT inside a fenced code
  block**, at least one `- [x]` and zero `- [ ]`. Fence-awareness here is the one real judgment
  call: it keeps an EXAMPLE `- [ ]` printed inside a ``` block from making a finished task look
  unfinished, so resume (skip-done-tasks) stays correct.
- **Output** = a JSON array of `{ n, title, body, isGate, done }` in document order, UTF-8.

**Read these first:**
- [skills/execute-feature/SKILL.md](../../../../plugins/cogniva-dev/skills/execute-feature/SKILL.md) — the skill whose Step 1 changes (lines 42–48 today)
- [templates/execute-feature.workflow.js](../../../../plugins/cogniva-dev/templates/execute-feature.workflow.js) — the consumer; `args.tasks = [{ n, title, body, isGate, done }]` (lines 7–14, 40–66)
- [scripts/new-feature-worktree.ps1](../../../../plugins/cogniva-dev/scripts/new-feature-worktree.ps1) — sibling-script conventions (param block, single JSON, exit codes)
- [scripts/integrate-feature.ps1](../../../../plugins/cogniva-dev/scripts/integrate-feature.ps1) — sibling-script conventions

## File structure (locked)

```
plugins/cogniva-dev/scripts/parse-plan-tasks.ps1            # NEW — the deterministic plan→tasks parser
plugins/cogniva-dev/tests/parse-plan-tasks/                 # NEW — dependency-free regression test + fixtures
  parse-plan-tasks.tests.ps1                                #   plain-PowerShell test harness (no Pester); exit 1 on any failure
  BundleAnonymiserEngine-plan.md                            #   LOCAL COPY of the real 5-task fixture (no off-disk path refs)
  synthetic-plan.md                                         #   small fixture: fence-aware done + byte-faithful body
plugins/cogniva-dev/skills/execute-feature/SKILL.md         # MODIFY — Step 1 rewritten to call the script
plugins/cogniva-dev/.claude-plugin/plugin.json             # MODIFY — version bump 0.1.0 → 0.2.0
```

## Task 1: Add the local fixtures and the failing regression test

This is the red half of the TDD cycle: write the fixtures and the test that pins down the parsing
contract, then run it and confirm it FAILS because the script does not exist yet. The real fixture
is copied LOCALLY (the prompt forbids hard-coded references to other on-disk locations); the
synthetic fixture is authored here so the test can make an exact byte-faithful body assertion and
exercise fence-aware done-detection.

**Files:**
- Create: `plugins/cogniva-dev/tests/parse-plan-tasks/BundleAnonymiserEngine-plan.md`
- Create: `plugins/cogniva-dev/tests/parse-plan-tasks/synthetic-plan.md`
- Create: `plugins/cogniva-dev/tests/parse-plan-tasks/parse-plan-tasks.tests.ps1`

- [x] **Step 1 (copy the real fixture locally):** copy the real plan into the test folder so the
      test has no off-disk path reference. Run (Bash):
      ```bash
      mkdir -p plugins/cogniva-dev/tests/parse-plan-tasks
      cp "C:/dev/FileCleanup/docs/plans/ShareInsights/BundleAnonymiserEngine/BundleAnonymiserEngine-plan.md" \
         plugins/cogniva-dev/tests/parse-plan-tasks/BundleAnonymiserEngine-plan.md
      ```
      Then confirm it landed (Bash):
      ```bash
      grep -c '^## ' plugins/cogniva-dev/tests/parse-plan-tasks/BundleAnonymiserEngine-plan.md
      ```
      Expected output: `5` (the five `## Task N:` headings; `## ⛔ Task 5:` also starts with `## `).
      If the source path does not exist in this environment, STOP and report BLOCKED — the test
      cannot be authored without the fixture.
- [x] **Step 2 (author the synthetic fixture):** create
      `plugins/cogniva-dev/tests/parse-plan-tasks/synthetic-plan.md` with EXACTLY this content
      (the fenced `- [ ]` and the fenced `## …` line must be ignored by done/heading detection):
      ````markdown
      # Synthetic — Feature Plan

      > REQUIRED EXECUTOR: /cogniva-dev:execute-feature Synthetic/Synthetic

      **Goal:** exercise fence-aware done-detection and byte-faithful bodies.

      ## Task 1: Already finished, with fenced examples

      - [x] **Step 1:** do the thing.
      - [x] **Step 2:** print sample markdown that contains examples a parser must IGNORE:
            ```
            - [ ] example unchecked box inside a fence (not a real step)
            ## Not a real task heading inside a fence
            ```
      - [x] **Step 3 (commit):** commit it.

      ## Task 2: Not finished yet

      - [ ] **Step 1:** still to do.
      - [x] **Step 2:** partially done.

      ## ⛔ Task 3: Manual gate

      - [ ] **Step 1:** human validates.
      ````
- [x] **Step 3 (write the test harness):** create
      `plugins/cogniva-dev/tests/parse-plan-tasks/parse-plan-tasks.tests.ps1` with EXACTLY:
      ```powershell
      # Dependency-free regression test for parse-plan-tasks.ps1 (no Pester).
      # Exits 0 only if every assertion passes; exits 1 and prints the failures otherwise.
      $ErrorActionPreference = 'Stop'
      [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

      $here   = Split-Path -Parent $MyInvocation.MyCommand.Path
      $script = Join-Path $here '..\..\scripts\parse-plan-tasks.ps1'
      $script = [System.IO.Path]::GetFullPath($script)

      $failures = @()
      function Check($label, $cond) {
          if ($cond) { Write-Host "  PASS  $label" }
          else { Write-Host "  FAIL  $label"; $script:failures += $label }
      }

      function Parse($planRelPath) {
          $plan = Join-Path $here $planRelPath
          $out  = & powershell -NoProfile -ExecutionPolicy Bypass -File $script -PlanPath $plan
          if ($LASTEXITCODE -ne 0) { throw "parser exit $LASTEXITCODE for $planRelPath" }
          return ($out -join "`n" | ConvertFrom-Json)
      }

      # --- Real fixture: the exact array the skill builds by hand today --------------
      $real = Parse 'BundleAnonymiserEngine-plan.md'
      Check 'real: 5 tasks'                 ($real.Count -eq 5)
      Check 'real: n = 1..5'                (@($real.n) -join ',' -eq '1,2,3,4,5')
      Check 'real: isGate only on Task 5'   ((@($real | Where-Object isGate | ForEach-Object n) -join ',') -eq '5')
      Check 'real: done = T,T,T,T,F'        ((@($real | ForEach-Object { if ($_.done) { 'T' } else { 'F' } }) -join ',') -eq 'T,T,T,T,F')
      Check 'real: Task 1 title'            ($real[0].title -eq 'Move the Python engine into the plugin')
      Check 'real: Task 5 title carries the gate parenthetical' ($real[4].title -like 'Validate portability from a second repo*manual validation gate*')
      # body fidelity: verbatim from the line after the heading; fenced "## Packaging" survives.
      Check 'real: Task 1 body starts at heading+1' ($real[0].body.StartsWith("`n**Files:**"))
      Check 'real: Task 3 body keeps fenced ## heading' ($real[2].body -match '(?m)^\s*## Packaging\s*$')
      Check 'real: Task 5 body keeps its manual steps'  ($real[4].body -match 'Wait for the user to confirm')

      # --- Synthetic fixture: fence-aware done + exact byte-faithful body ------------
      $syn = Parse 'synthetic-plan.md'
      Check 'syn: 3 tasks (fenced ## ignored as heading)' ($syn.Count -eq 3)
      Check 'syn: Task 1 done=true despite fenced "- [ ]"' ($syn[0].done -eq $true)
      Check 'syn: Task 2 done=false (real "- [ ]")'        ($syn[1].done -eq $false)
      Check 'syn: Task 3 is the gate, not done'            ($syn[2].isGate -eq $true -and $syn[2].done -eq $false)
      # exact body of Task 2: blank line, two steps, trailing blank before the next heading.
      $expectT2 = "`n- [ ] **Step 1:** still to do.`n- [x] **Step 2:** partially done.`n"
      Check 'syn: Task 2 body is byte-faithful'            ($syn[1].body -eq $expectT2)

      if ($failures.Count -gt 0) {
          Write-Host ""
          Write-Host "FAILED: $($failures.Count) assertion(s)."
          exit 1
      }
      Write-Host ""
      Write-Host "All parse-plan-tasks assertions passed."
      exit 0
      ```
- [x] **Step 4 (run it, expect failure — script does not exist yet):** run (Bash):
      ```bash
      powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/tests/parse-plan-tasks/parse-plan-tasks.tests.ps1"; echo "exit:$?"
      ```
      Expected: it throws because `scripts/parse-plan-tasks.ps1` is missing (a "parser exit" /
      file-not-found style error) and prints `exit:1`. This is the red state — do NOT create the
      script in this task.
- [x] **Step 5 (commit):**
      `git add plugins/cogniva-dev/tests/parse-plan-tasks` then
      `git commit -m "test(cogniva-dev): add failing parse-plan-tasks contract test + local fixtures"`

## Task 2: Create the parse-plan-tasks.ps1 parser (turn the test green)

This is the green half: implement the script so the Task 1 test passes. The script reads the plan
as UTF-8 (BOM-tolerant), normalises newlines to LF, finds task headings with the fixed regex
(per-line, not fence-aware), slices each body verbatim, computes `done` with **fence-aware**
checkbox counting, and writes the JSON array to stdout. Failures (missing file, no headings) go to
stderr with a non-zero exit; stdout stays empty so the skill captures either a valid array or
nothing.

**Files:**
- Create: `plugins/cogniva-dev/scripts/parse-plan-tasks.ps1`

- [x] **Step 1 (write the script):** create `plugins/cogniva-dev/scripts/parse-plan-tasks.ps1`
      with EXACTLY:
      ```powershell
      # Parse a feature plan markdown file into the ordered task array execute-feature consumes.
      # Contract (must match templates/execute-feature.workflow.js args.tasks):
      #   Output (stdout): a JSON array of { n, title, body, isGate, done } in document order, UTF-8.
      #   - Task heading: a line matching  ^##\s+(⛔\s*)?Task\s+(\d+):\s*(.*)$
      #     n = the number (integer), title = the remainder, isGate = the ⛔ marker is present.
      #     Heading detection is PER-LINE (NOT fence-aware): the required "Task N:" keyword is narrow
      #     enough that example "## ..." lines inside fenced code blocks never match. Deliberate
      #     limitation: a literal "## Task N:" line inside a fenced example WOULD misfire — no real
      #     plan writes one; the keyword narrowness is the guard, matching today's hand-parse.
      #   - body = every line AFTER the heading up to (not including) the next task heading, verbatim
      #     (fenced code blocks, "- [ ]" examples and all). Newlines normalised to LF.
      #   - done = fully checked: among checkbox lines that are NOT inside a fenced code block, at
      #     least one "- [x]" and zero "- [ ]". Fence-awareness keeps an EXAMPLE "- [ ]" printed
      #     inside a ``` block from making a finished task look unfinished (correct resume).
      # Failure: non-zero exit + a message on stderr (missing file / no tasks found); stdout stays empty.
      [CmdletBinding()]
      param(
          [Parameter(Mandatory)][string]$PlanPath
      )
      $ErrorActionPreference = 'Stop'

      # Emit as UTF-8 without a BOM so the gate marker, em-dashes and arrows round-trip cleanly.
      $utf8 = [System.Text.UTF8Encoding]::new($false)
      [Console]::OutputEncoding = $utf8

      try {
          if (-not (Test-Path -LiteralPath $PlanPath -PathType Leaf)) {
              [Console]::Error.WriteLine("parse-plan-tasks: plan file not found: $PlanPath")
              exit 1
          }

          # Read explicitly as UTF-8 (BOM-tolerant) and normalise newlines to LF.
          $text  = [System.IO.File]::ReadAllText($PlanPath, $utf8)
          $text  = $text -replace "`r`n", "`n" -replace "`r", "`n"
          $lines = $text -split "`n"

          $headingRe = '^##\s+(?<gate>⛔\s*)?Task\s+(?<n>\d+):\s*(?<title>.*)$'

          # Pass 1: locate every task heading (line index, n, title, gate flag).
          $heads = @()
          for ($i = 0; $i -lt $lines.Count; $i++) {
              $m = [regex]::Match($lines[$i], $headingRe)
              if ($m.Success) {
                  $heads += [pscustomobject]@{
                      line  = $i
                      n     = [int]$m.Groups['n'].Value
                      title = $m.Groups['title'].Value.TrimEnd()
                      gate  = $m.Groups['gate'].Success
                  }
              }
          }

          if ($heads.Count -eq 0) {
              [Console]::Error.WriteLine("parse-plan-tasks: no '## Task N:' headings found in $PlanPath")
              exit 1
          }

          # Pass 2: body = lines after each heading up to the next heading; done via fence-aware checkboxes.
          $tasks = @()
          for ($h = 0; $h -lt $heads.Count; $h++) {
              $start = $heads[$h].line + 1
              $end   = if ($h + 1 -lt $heads.Count) { $heads[$h + 1].line } else { $lines.Count }
              $bodyLines = if ($end -gt $start) { @($lines[$start..($end - 1)]) } else { @() }
              $body = ($bodyLines -join "`n")

              $inFence   = $false
              $checked   = 0
              $unchecked = 0
              foreach ($bl in $bodyLines) {
                  $trimmed = $bl.TrimStart()
                  if ($trimmed -match '^(```|~~~)') { $inFence = -not $inFence; continue }
                  if ($inFence) { continue }
                  if     ($trimmed -match '^- \[[xX]\]') { $checked++ }
                  elseif ($trimmed -match '^- \[ \]')    { $unchecked++ }
              }
              $done = ($checked -ge 1) -and ($unchecked -eq 0)

              $tasks += [pscustomobject]@{
                  n      = $heads[$h].n
                  title  = $heads[$h].title
                  body   = $body
                  isGate = [bool]$heads[$h].gate
                  done   = [bool]$done
              }
          }

          $json = $tasks | ConvertTo-Json -Depth 5
          # ConvertTo-Json renders a single-element array as a bare object; force an array shape.
          if ($tasks.Count -eq 1) { $json = "[$json]" }
          [Console]::Out.Write($json)
          [Console]::Out.Write("`n")
          exit 0
      }
      catch {
          [Console]::Error.WriteLine("parse-plan-tasks: $_")
          exit 1
      }
      ```
- [x] **Step 2 (run the test, expect green):** run (Bash):
      ```bash
      powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/tests/parse-plan-tasks/parse-plan-tasks.tests.ps1"; echo "exit:$?"
      ```
      Expected: every line prints `PASS`, then `All parse-plan-tasks assertions passed.` and
      `exit:0`. If any assertion FAILS, fix the script (not the test) until green.
- [x] **Step 3 (spot-check the raw JSON shape):** run (Bash):
      ```bash
      powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/scripts/parse-plan-tasks.ps1" -PlanPath "plugins/cogniva-dev/tests/parse-plan-tasks/synthetic-plan.md" | python -c "import sys,json; a=json.load(sys.stdin); print(len(a), [t['n'] for t in a], [t['isGate'] for t in a], [t['done'] for t in a])"
      ```
      Expected output: `3 [1, 2, 3] [False, False, True] [True, False, False]`
- [x] **Step 4 (verify failure path — missing file):** run (Bash):
      ```bash
      powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/scripts/parse-plan-tasks.ps1" -PlanPath "does/not/exist.md" 1>/tmp/out.txt 2>/tmp/err.txt; echo "exit:$?"; echo "stdout-bytes:$(wc -c </tmp/out.txt)"; cat /tmp/err.txt
      ```
      Expected: `exit:1`, `stdout-bytes:0` (stdout empty), and a stderr line containing
      `plan file not found`.
- [x] **Step 5 (commit):**
      `git add plugins/cogniva-dev/scripts/parse-plan-tasks.ps1` then
      `git commit -m "feat(cogniva-dev): add deterministic parse-plan-tasks.ps1 for execute-feature"`

## Task 3: Rewrite execute-feature SKILL.md Step 1 to call the script

Replace the "build an ordered array by hand" instruction with a single command that runs the
parser against the plan IN THE WORKTREE and captures stdout verbatim as `args.tasks`. Everything
else in the skill (Step 0 worktree creation, Step 2 arg assembly, Steps 3–4 integration) is
unchanged.

**Files:**
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`

- [x] **Step 1 (replace the Step 1 section):** in
      `plugins/cogniva-dev/skills/execute-feature/SKILL.md`, replace this EXACT block:
      ```
      ## Step 1 — parse the plan into tasks

      From the plan IN THE WORKTREE, build an ordered array of tasks:
      `{ n, title, body, isGate, done }` where
      - `body` = that task's full text (all its `- [ ]` steps, verbatim, self-contained),
      - `isGate` = the heading starts with `⛔`,
      - `done` = every checkbox in the task is already `- [x]` (resume support).
      ```
      with EXACTLY:
      ```
      ## Step 1 — parse the plan into tasks (deterministic script — no manual parsing)

      Do NOT read or hand-build the task array. Run the parser against the plan IN THE
      WORKTREE and capture its stdout verbatim:

      `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/parse-plan-tasks.ps1" -PlanPath "<worktree>/docs/plans/<Module>/<Feature>/<Feature>-plan.md"`

      It prints a single JSON array of `{ n, title, body, isGate, done }` in document order:
      - `body` = the task's full text after its heading, verbatim (all `- [ ]` steps and fenced examples),
      - `isGate` = the heading is a `⛔` gate,
      - `done` = the task's real (non-fenced) checkboxes are all `- [x]` — drives resume.

      On failure it writes a message to stderr and exits non-zero (missing file, or no
      `## Task N:` headings); surface that and STOP. Use the captured JSON **verbatim** as
      `args.tasks` in Step 2 — do not transform, re-order, or re-derive any field.
      ```
- [x] **Step 2 (verify the old instruction is gone):** run (Bash):
      ```bash
      grep -n "build an ordered array" plugins/cogniva-dev/skills/execute-feature/SKILL.md; echo "exit:$?"
      ```
      Expected output: no matching lines, then `exit:1` (grep found nothing).
- [x] **Step 3 (verify the new instruction is present):** run (Bash):
      ```bash
      grep -c "parse-plan-tasks.ps1" plugins/cogniva-dev/skills/execute-feature/SKILL.md
      ```
      Expected output: `1`
- [x] **Step 4 (commit):**
      `git add plugins/cogniva-dev/skills/execute-feature/SKILL.md` then
      `git commit -m "feat(cogniva-dev): execute-feature Step 1 calls parse-plan-tasks.ps1 instead of hand-parsing"`

## Task 4: Bump the plugin version and validate

Per CLAUDE.md, bump the plugin `version` whenever its skills/scripts change — and a new script
plus a skill change qualifies. Then validate the marketplace.

**Files:**
- Modify: `plugins/cogniva-dev/.claude-plugin/plugin.json`

- [x] **Step 1 (bump the version):** in `plugins/cogniva-dev/.claude-plugin/plugin.json`, replace
      ```
        "version": "0.1.0",
      ```
      with
      ```
        "version": "0.2.0",
      ```
- [x] **Step 2 (confirm the bump):** run (Bash):
      ```bash
      grep '"version"' plugins/cogniva-dev/.claude-plugin/plugin.json
      ```
      Expected output: a line containing `"version": "0.2.0",`
- [x] **Step 3 (validate the marketplace):** run (Bash):
      ```bash
      claude plugin validate .; echo "exit:$?"
      ```
      Expected: validation succeeds and prints `exit:0`. If `claude` is unavailable in the
      worktree, note it in the commit and proceed (validation is also run by the user at the gate).
- [x] **Step 4 (commit):**
      `git add plugins/cogniva-dev/.claude-plugin/plugin.json` then
      `git commit -m "chore(cogniva-dev): bump version to 0.2.0 for parse-plan-tasks"`

## ⛔ Task 5: Validate against the real external plan and the rewritten skill

The automated test uses a LOCAL copy of the fixture. The acceptance also requires the script to
produce the right array against the REAL plan on disk, and the SKILL.md rewrite to read as one
unambiguous command. Both are a human eyeball — hard stop.

- [x] **Step 1:** From the worktree, run the parser against the REAL external fixture and confirm
      the array matches what the skill built by hand: 5 entries, n 1–5, `isGate` true only for
      Task 5, `done` = true,true,true,true,false:
      ```bash
      powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/scripts/parse-plan-tasks.ps1" -PlanPath "C:/dev/FileCleanup/docs/plans/ShareInsights/BundleAnonymiserEngine/BundleAnonymiserEngine-plan.md" | python -c "import sys,json; a=json.load(sys.stdin); print(len(a)); print([t['n'] for t in a]); print([t['isGate'] for t in a]); print([t['done'] for t in a]); print(a[2]['body'][:80])"
      ```
      Expected: `5`, `[1, 2, 3, 4, 5]`, `[False, False, False, False, True]`,
      `[True, True, True, True, False]`, and a Task-3 body snippet that begins with the real prose.
- [x] **Step 2:** Re-read `plugins/cogniva-dev/skills/execute-feature/SKILL.md` Step 1 and confirm
      it is unambiguous: one command to run, one JSON to capture, zero model judgment about parsing.
- [x] **Step 3:** Wait for the user to confirm both before the feature is marked integrated.
