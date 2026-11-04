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

    # --- sections appended by later tasks go above this line ---
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All smoke-assertions assertions passed.'
exit 0
