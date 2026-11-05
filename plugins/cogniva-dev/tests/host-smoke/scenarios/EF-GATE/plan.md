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
