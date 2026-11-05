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
