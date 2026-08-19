# Dependency-free regression test for check-adrs.ps1 (no Pester).
# Builds throwaway git repos in TEMP so the checks run against real history.
#
# check-adrs-ignore-file - the fixtures below contain deliberate ADR-C labels.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\scripts\check-adrs.ps1'))

$failures = @()
function Check($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}

# `git init -b main` needs git 2.28+; setting the unborn HEAD by hand does the
# same thing on every version, so the suite runs on older git too.
function Init-Repo($root) {
    & git -C $root init -q 2>$null | Out-Null
    & git -C $root symbolic-ref HEAD refs/heads/main 2>$null | Out-Null
    & git -C $root config user.email 'test@example.com' | Out-Null
    & git -C $root config user.name  'Test' | Out-Null
}

function New-Repo($root) {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    Init-Repo $root
    New-Item -ItemType Directory -Path (Join-Path $root 'docs\adr') -Force | Out-Null
}

function Add-Adr($root, $name, $heading) {
    Set-Content -LiteralPath (Join-Path $root "docs\adr\$name") -Value @($heading, '', 'Body.') -Encoding UTF8
}

function Commit-All($root, $msg) {
    & git -C $root add -A 2>$null | Out-Null
    & git -C $root commit -q -m $msg 2>$null | Out-Null
}

function Run-Raw($cliArgs) {
    # Merging the child's stderr into stdout yields ErrorRecords, which the
    # file-level 'Stop' preference would turn into a thrown NativeCommandError
    # before we could inspect the exit code. Relax it just for the invocation.
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out  = & powershell -NoProfile -ExecutionPolicy Bypass -File $script @cliArgs 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    return @{ code = $code; text = (($out | ForEach-Object { $_.ToString() }) -join "`n") }
}

function Run-Check($root, $extra) { Run-Raw (@('-Worktree', $root) + $extra) }

# Lean mode: no worktree and no target branch, just the commit the run started
# from - so the examined change set is <Since>..HEAD.
function Run-Since($root, $since, $extra) { Run-Raw (@('-Workspace', $root, '-Since', $since) + $extra) }

function Head-Sha($root) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $sha = & git -C $root rev-parse HEAD 2>$null } finally { $ErrorActionPreference = $prev }
    return "$($sha | Select-Object -First 1)".Trim()
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ca-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    # ---------------------------------------------------------- clean baseline
    $r1 = Join-Path $tmp 'clean'
    New-Repo $r1
    Add-Adr $r1 '0001-first.md'  '# ADR-0001: First'
    Add-Adr $r1 '0002-second.md' '# ADR-0002: Second'
    Commit-All $r1 'base'
    $res = Run-Check $r1 @()
    Check 'exit 0 on a clean repo' ($res.code -eq 0)
    Check 'clean run says so' ($res.text -match 'check-adrs: clean')

    # ------------------------------------------------- A: duplicate ADR number
    $r2 = Join-Path $tmp 'dup'
    New-Repo $r2
    Add-Adr $r2 '0001-first.md'      '# ADR-0001: First'
    Add-Adr $r2 '0001-also-first.md' '# ADR-0001: Also first'
    Commit-All $r2 'base'
    $res = Run-Check $r2 @()
    Check 'exit 1 when two files claim one number' ($res.code -eq 1)
    Check 'duplicate is named in the report' ($res.text -match 'DUPLICATE NUMBER ADR-0001')

    # ------------------------------------------------ B: candidate label in H1
    $r3 = Join-Path $tmp 'candidate-title'
    New-Repo $r3
    Add-Adr $r3 '0086-thing.md' '# ADR-C4: Thing'
    Commit-All $r3 'base'
    $res = Run-Check $r3 @()
    Check 'exit 1 on an ADR-Cn H1 title' ($res.code -eq 1)
    Check 'candidate title is named with both labels' (($res.text -match 'CANDIDATE TITLE') -and ($res.text -match 'ADR-C4') -and ($res.text -match '0086'))

    # ---------------------------------------------------- B: plain H1 mismatch
    $r4 = Join-Path $tmp 'mismatch'
    New-Repo $r4
    Add-Adr $r4 '0007-thing.md' '# 0008 - Thing'
    Commit-All $r4 'base'
    $res = Run-Check $r4 @()
    Check 'exit 1 when the H1 number differs from the filename' ($res.code -eq 1)
    Check 'mismatch is reported as such' ($res.text -match 'NUMBER MISMATCH')

    # ------------------------- B: a numberless H1 is the canonical template
    $r4b = Join-Path $tmp 'numberless'
    New-Repo $r4b
    Add-Adr $r4b '0007-thing.md' '# Do the thing a particular way'
    Add-Adr $r4b '0008-other.md' '# 0008 - Numbered house variant'
    Commit-All $r4b 'base'
    $res = Run-Check $r4b @()
    Check 'exit 0 - ADR-FORMAT''s numberless H1 is not a problem' ($res.code -eq 0)

    # ------------------------------ C: candidate label added on a branch, code
    $r5 = Join-Path $tmp 'added-label'
    New-Repo $r5
    Add-Adr $r5 '0001-first.md' '# ADR-0001: First'
    Commit-All $r5 'base'
    & git -C $r5 checkout -q -b feature/x 2>$null | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $r5 'src') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $r5 'src\thing.py') -Value '# see ADR-C8 for the rule' -Encoding UTF8
    Commit-All $r5 'add code'
    $res = Run-Check $r5 @()
    Check 'exit 1 when a branch adds an ADR-C label in code' ($res.code -eq 1)
    Check 'the citing file and label are both reported' (($res.text -match 'CANDIDATE LABEL') -and ($res.text -match 'src/thing.py') -and ($res.text -match 'ADR-C8'))

    # ------------------------- C: the same label under docs/plans/ is EXCLUDED
    $r6 = Join-Path $tmp 'excluded-label'
    New-Repo $r6
    Add-Adr $r6 '0001-first.md' '# ADR-0001: First'
    Commit-All $r6 'base'
    & git -C $r6 checkout -q -b feature/x 2>$null | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $r6 'docs\plans\M\F') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $r6 'docs\plans\M\F\F-plan.md') -Value '- ADR-C8: a candidate' -Encoding UTF8
    Commit-All $r6 'add plan'
    $res = Run-Check $r6 @()
    Check 'exit 0 - a candidate label in docs/plans/ is legitimate' ($res.code -eq 0)

    # ---------------------- C: a file may opt out of the label check explicitly
    $r5b = Join-Path $tmp 'opt-out'
    New-Repo $r5b
    Add-Adr $r5b '0001-first.md' '# First'
    Commit-All $r5b 'base'
    & git -C $r5b checkout -q -b feature/x 2>$null | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $r5b 'src') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $r5b 'src\doc.md') -Encoding UTF8 -Value @(
        '<!-- check-adrs-ignore-file: explains the convention -->',
        'A candidate label looks like ADR-C8.')
    Commit-All $r5b 'add doc that explains the convention'
    $res = Run-Check $r5b @()
    Check 'exit 0 - a file declaring the ignore marker is skipped' ($res.code -eq 0)
    Check 'the skipped file is named, never silent' (($res.text -match 'SKIPPED') -and ($res.text -match 'src/doc.md'))

    # -------------------------- C: pre-existing labels do NOT fail integration
    $r7 = Join-Path $tmp 'preexisting-label'
    New-Repo $r7
    Add-Adr $r7 '0001-first.md' '# ADR-0001: First'
    New-Item -ItemType Directory -Path (Join-Path $r7 'src') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $r7 'src\old.py') -Value '# legacy ADR-C3 reference' -Encoding UTF8
    Commit-All $r7 'base with a pre-existing label'
    & git -C $r7 checkout -q -b feature/x 2>$null | Out-Null
    Set-Content -LiteralPath (Join-Path $r7 'src\new.py') -Value 'x = 1' -Encoding UTF8
    Commit-All $r7 'unrelated change'
    $res = Run-Check $r7 @()
    Check 'exit 0 - a label already on main is not this branch''s problem' ($res.code -eq 0)

    # ------------------------------ D: new ADR number already taken on target
    $r8 = Join-Path $tmp 'number-taken'
    New-Repo $r8
    Add-Adr $r8 '0001-first.md' '# ADR-0001: First'
    Commit-All $r8 'base'
    & git -C $r8 checkout -q -b feature/x 2>$null | Out-Null
    Add-Adr $r8 '0002-mine.md' '# ADR-0002: Mine'
    Commit-All $r8 'my adr'
    & git -C $r8 checkout -q main 2>$null | Out-Null
    Add-Adr $r8 '0002-theirs.md' '# ADR-0002: Theirs'
    Commit-All $r8 'their adr'
    & git -C $r8 checkout -q feature/x 2>$null | Out-Null
    $res = Run-Check $r8 @()
    Check 'exit 1 when the new ADR number is taken on the target' ($res.code -eq 1)
    Check 'the colliding target file is named' (($res.text -match 'NUMBER TAKEN') -and ($res.text -match '0002-theirs.md'))

    # ------------------------------------------------------- graceful skipping
    $r9 = Join-Path $tmp 'no-adr-dir'
    New-Item -ItemType Directory -Path $r9 -Force | Out-Null
    Init-Repo $r9
    Set-Content -LiteralPath (Join-Path $r9 'README.md') -Value 'hi' -Encoding UTF8
    Commit-All $r9 'base'
    $res = Run-Check $r9 @()
    Check 'exit 0 when the repo has no docs/adr/' ($res.code -eq 0)
    Check 'the skip is announced, not silent' ($res.text -match 'no docs/adr/ in this worktree')

    # ========================================== lean mode: -Workspace / -Since
    # The lean run has no worktree and no target branch - it commits straight
    # onto the user's own branch - so "what this run added" is <Since>..HEAD.

    # ------------------------------------------ Since: clean run over the range
    $s1 = Join-Path $tmp 'since-clean'
    New-Repo $s1
    Add-Adr $s1 '0001-first.md' '# ADR-0001: First'
    New-Item -ItemType Directory -Path (Join-Path $s1 'src') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $s1 'src\old.py') -Value '# legacy ADR-C3 reference' -Encoding UTF8
    Commit-All $s1 'base with a pre-existing label'
    $since1 = Head-Sha $s1
    Add-Adr $s1 '0002-second.md' '# ADR-0002: Second'
    Commit-All $s1 'the run adds an ADR'
    $res = Run-Since $s1 $since1 @()
    Check 'exit 0 - a clean -Since run passes' ($res.code -eq 0)
    Check 'a label committed before -Since is not this run''s problem' ($res.text -match 'check-adrs: clean')
    Check 'the report names the since commit it compared against' ($res.text -match [regex]::Escape($since1))

    # -------------------------------- Since: candidate label added after -Since
    $s2 = Join-Path $tmp 'since-label'
    New-Repo $s2
    Add-Adr $s2 '0001-first.md' '# ADR-0001: First'
    Commit-All $s2 'base'
    $since2 = Head-Sha $s2
    New-Item -ItemType Directory -Path (Join-Path $s2 'src') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $s2 'src\thing.py') -Value '# see ADR-C8 for the rule' -Encoding UTF8
    Commit-All $s2 'the run adds code'
    $res = Run-Since $s2 $since2 @()
    Check 'exit 1 when the run adds an ADR-C label after -Since' ($res.code -eq 1)
    Check 'the citing file and label are reported in -Since mode' (($res.text -match 'CANDIDATE LABEL') -and ($res.text -match 'src/thing.py') -and ($res.text -match 'ADR-C8'))

    # --------------------- Since: a number the repo already used before the run
    $s3 = Join-Path $tmp 'since-taken'
    New-Repo $s3
    Add-Adr $s3 '0002-theirs.md' '# ADR-0002: Theirs'
    Commit-All $s3 'base'
    $since3 = Head-Sha $s3
    Add-Adr $s3 '0002-mine.md' '# ADR-0002: Mine'
    Commit-All $s3 'the run adds a colliding ADR'
    $res = Run-Since $s3 $since3 @()
    Check 'exit 1 when the run reuses a number the repo already had' ($res.code -eq 1)
    Check 'check D names the pre-run holder in -Since mode' (($res.text -match 'NUMBER TAKEN') -and ($res.text -match '0002-theirs.md'))

    # ------------------------------------ Since: the opt-out marker still works
    $s4 = Join-Path $tmp 'since-opt-out'
    New-Repo $s4
    Add-Adr $s4 '0001-first.md' '# First'
    Commit-All $s4 'base'
    $since4 = Head-Sha $s4
    New-Item -ItemType Directory -Path (Join-Path $s4 'src') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $s4 'src\doc.md') -Encoding UTF8 -Value @(
        '<!-- check-adrs-ignore-file: explains the convention -->',
        'A candidate label looks like ADR-C8.')
    Commit-All $s4 'the run adds a doc that explains the convention'
    $res = Run-Since $s4 $since4 @()
    Check 'exit 0 - the ignore marker is honoured in -Since mode' ($res.code -eq 0)
    Check 'the skipped file is named in -Since mode too' (($res.text -match 'SKIPPED') -and ($res.text -match 'src/doc.md'))

    # --------------------------------------------------------- usage / env errors
    $res = Run-Check (Join-Path $tmp 'does-not-exist') @()
    Check 'exit 2 when the worktree does not exist' ($res.code -eq 2)

    $res = Run-Check $r1 @('-TargetBranch', 'no-such-branch')
    Check 'exit 0 but announced when the target branch does not resolve' (($res.code -eq 0) -and ($res.text -match 'cannot resolve a merge base'))

    $res = Run-Since (Join-Path $tmp 'does-not-exist') $since1 @()
    Check 'exit 2 when the workspace does not exist' ($res.code -eq 2)

    # -Since is handed over by the caller, so an unresolvable one is a usage
    # error - not the tolerated "the target branch may not exist yet" case.
    $res = Run-Since $s1 'no-such-commit' @()
    Check 'exit 2 when -Since does not resolve' ($res.code -eq 2)

    $res = Run-Raw @()
    Check 'exit 2 when neither -Worktree nor -Workspace is given' ($res.code -eq 2)

    $res = Run-Raw @('-Workspace', $s1)
    Check 'exit 2 when -Workspace is given without -Since' ($res.code -eq 2)

    $res = Run-Raw @('-Worktree', $r1, '-Since', 'HEAD')
    Check 'exit 2 when -Since is given without -Workspace' ($res.code -eq 2)

    $res = Run-Raw @('-Worktree', $r1, '-Workspace', $s1, '-Since', $since1)
    Check 'exit 2 when the two modes are mixed' ($res.code -eq 2)
}
finally {
    # Git marks pack files read-only on Windows; clear it so cleanup succeeds.
    Get-ChildItem -LiteralPath $tmp -Recurse -File -Force -ErrorAction SilentlyContinue |
        ForEach-Object { try { $_.IsReadOnly = $false } catch { } }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED: $($failures.Count) assertion(s)."
    exit 1
}
Write-Host ""
Write-Host "All check-adrs assertions passed."
exit 0
