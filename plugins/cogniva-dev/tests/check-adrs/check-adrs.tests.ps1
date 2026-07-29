# Dependency-free regression test for check-adrs.ps1 (no Pester).
# Builds throwaway git repos in TEMP so the checks run against real history.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\scripts\check-adrs.ps1'))

$failures = @()
function Check($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}

function New-Repo($root) {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    & git -C $root init -q -b main 2>$null | Out-Null
    & git -C $root config user.email 'test@example.com' | Out-Null
    & git -C $root config user.name  'Test' | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'docs\adr') -Force | Out-Null
}

function Add-Adr($root, $name, $heading) {
    Set-Content -LiteralPath (Join-Path $root "docs\adr\$name") -Value @($heading, '', 'Body.') -Encoding UTF8
}

function Commit-All($root, $msg) {
    & git -C $root add -A 2>$null | Out-Null
    & git -C $root commit -q -m $msg 2>$null | Out-Null
}

function Run-Check($root, $extra) {
    # Merging the child's stderr into stdout yields ErrorRecords, which the
    # file-level 'Stop' preference would turn into a thrown NativeCommandError
    # before we could inspect the exit code. Relax it just for the invocation.
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out  = & powershell -NoProfile -ExecutionPolicy Bypass -File $script -Worktree $root @extra 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    return @{ code = $code; text = (($out | ForEach-Object { $_.ToString() }) -join "`n") }
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
    & git -C $r9 init -q -b main 2>$null | Out-Null
    & git -C $r9 config user.email 'test@example.com' | Out-Null
    & git -C $r9 config user.name  'Test' | Out-Null
    Set-Content -LiteralPath (Join-Path $r9 'README.md') -Value 'hi' -Encoding UTF8
    Commit-All $r9 'base'
    $res = Run-Check $r9 @()
    Check 'exit 0 when the repo has no docs/adr/' ($res.code -eq 0)
    Check 'the skip is announced, not silent' ($res.text -match 'no docs/adr/ in this worktree')

    # --------------------------------------------------------- usage / env errors
    $res = Run-Check (Join-Path $tmp 'does-not-exist') @()
    Check 'exit 2 when the worktree does not exist' ($res.code -eq 2)

    $res = Run-Check $r1 @('-TargetBranch', 'no-such-branch')
    Check 'exit 0 but announced when the target branch does not resolve' (($res.code -eq 0) -and ($res.text -match 'cannot resolve a merge base'))
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
