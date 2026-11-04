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
