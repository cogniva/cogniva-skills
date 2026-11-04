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
