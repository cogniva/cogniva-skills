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

# --- Nested fence fixture: length-aware fence nesting (4-tick wrapping 3-tick) --
# A finished task whose body shows a 4-backtick fence wrapping a 3-backtick example.
# The inner ``` must NOT close the outer ````, so the example "- [ ]" lines stay
# fenced and the task still reads done. (Regression for the simple-toggle bug.)
$nest = Parse 'nested-fence-plan.md'
Check 'nest: 2 tasks'                                 ($nest.Count -eq 2)
Check 'nest: Task 1 done=true (nested-fence "- [ ]" ignored)' ($nest[0].done -eq $true)
Check 'nest: Task 2 done=false (real "- [ ]")'        ($nest[1].done -eq $false)

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED: $($failures.Count) assertion(s)."
    exit 1
}
Write-Host ""
Write-Host "All parse-plan-tasks assertions passed."
exit 0
