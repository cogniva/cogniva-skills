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
