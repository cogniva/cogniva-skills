# Dependency-free regression tests for the cogniva worktree ledger machinery
# (no Pester). Covers three fixes:
#   Bug 1 - cleanup-worktrees.ps1 -Scope list silently no-ops when several paths
#           arrive as one comma-joined argument (the Bash-tool `powershell -File`
#           tokenizing).
#   Bug 2 - Test-SamePath / stored records did not normalize `/` vs `\`, so
#           mark-cleanupable appended a DUPLICATE record instead of updating the
#           in-progress one.
#   Bug 3 - the ledger was written as ANSI, so an em-dash became invalid UTF-8.
#
# Exits 0 only if every assertion passes; exits 1 and prints failures otherwise.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\scripts'))
. (Join-Path $scripts 'ledger-lib.ps1')

$failures = @()
function Check($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}

$emdash = [string][char]0x2014   # U+2014, byte 0x97 under Windows-1252

# ---------------------------------------------------------------------------
# Bug 2 - Get-CanonicalPath / Test-SamePath normalize slash direction, trailing
# separator, and case.
# ---------------------------------------------------------------------------
Check 'Get-CanonicalPath normalizes forward slashes to back' `
    ((Get-CanonicalPath 'C:/dev/Foo') -eq (Get-CanonicalPath 'C:\dev\Foo'))
Check 'Get-CanonicalPath strips a trailing separator' `
    ((Get-CanonicalPath 'C:\dev\Foo\') -eq (Get-CanonicalPath 'C:\dev\Foo'))
Check 'Get-CanonicalPath is case-insensitive' `
    ((Get-CanonicalPath 'C:\DEV\Foo') -eq (Get-CanonicalPath 'c:\dev\foo'))
Check 'Get-CanonicalPath of empty is empty' ((Get-CanonicalPath '') -eq '')
Check 'Test-SamePath: forward vs back slash are the same path' `
    (Test-SamePath 'c:\dev\Foo' 'C:/dev/Foo')
Check 'Test-SamePath: genuinely different paths are not equal' `
    (-not (Test-SamePath 'c:\dev\Foo' 'c:\dev\Bar'))

# ---------------------------------------------------------------------------
# Bug 3 - Write-Ledger emits valid UTF-8 (no BOM); Read-Ledger round-trips a
# multi-byte char, and a stdlib UTF-8 reader (python) parses the file.
# ---------------------------------------------------------------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ledg-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
$worktreeDirs = @()
try {
    $lp = Join-Path $tmp 'ledger.json'
    $rec = [pscustomobject]@{
        branch = 'feature/x'; worktree = 'c:\dev\x'; base = 'main'
        owner = 'x'; createdAt = '2026-07-09T00:00:00.000Z'; state = 'cleanupable'
        recipe = [pscustomobject]@{ statePath = $null; targetStatus = 'done'; summary = "did a thing $emdash cleanly"; followups = $null }
    }
    Write-Ledger $lp @($rec)

    $bytes = [System.IO.File]::ReadAllBytes($lp)
    Check 'ledger has no UTF-8 BOM' `
        (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF))
    Check 'em-dash is the 3-byte UTF-8 sequence E2 80 94, not ANSI 0x97' `
        (($bytes -contains 0xE2) -and ($bytes -contains 0x94) -and (-not ($bytes -contains 0x97)))

    $back = @(Read-Ledger $lp)
    Check 'Read-Ledger returns a flat single record' ($back.Count -eq 1)
    Check 'em-dash survives the write/read round-trip' ($back[0].recipe.summary -eq "did a thing $emdash cleanly")

    $py = & python -c "import json,sys;json.load(open(sys.argv[1],encoding='utf-8'));print('ok')" $lp 2>&1
    Check 'python parses the ledger as UTF-8' ("$py".Trim() -eq 'ok')

    # -----------------------------------------------------------------------
    # Bugs 1 & 2 end-to-end - drive the scripts the way the skills do, through
    # `powershell -File`, in a throwaway git repo. Native processes (git, the child
    # powershell) write benign progress to stderr; under $ErrorActionPreference =
    # 'Stop' PS 5.1 turns that into a terminating NativeCommandError, so localize to
    # 'Continue' for this subprocess-driven section (same trick Invoke-Git uses).
    # -----------------------------------------------------------------------
    $ErrorActionPreference = 'Continue'
    $repo = Join-Path $tmp 'repo'
    New-Item -ItemType Directory -Path $repo | Out-Null
    & git -C $repo init -q
    & git -C $repo config user.name  'Test'
    & git -C $repo config user.email 'test@example.com'
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'hello' -NoNewline
    & git -C $repo add a.txt
    & git -C $repo commit -q -m 'init'

    function New-Wt($slug) {
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'new-feature-worktree.ps1') `
            -Slug $slug -RepoRoot $repo 2>$null
        return (($out | Select-Object -Last 1) | ConvertFrom-Json).worktree
    }
    $wtA = New-Wt 'aaa'; $worktreeDirs += $wtA
    $wtB = New-Wt 'bbb'; $worktreeDirs += $wtB

    $ledgerPath = Get-LedgerPath (Get-CommonDir $repo)
    Check 'two worktrees -> two in-progress records' (@(Read-Ledger $ledgerPath).Count -eq 2)

    # Mark A cleanupable with a FORWARD-slash path (Bug 2): new-feature-worktree
    # stored it with backslashes; the mismatched-separator call must UPDATE that
    # record, not append a second one.
    $wtAfwd = $wtA -replace '\\','/'
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'mark-cleanupable.ps1') `
        -Worktree $wtAfwd -Branch 'feature/aaa' -RepoRoot $repo 2>$null | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'mark-cleanupable.ps1') `
        -Worktree $wtB -Branch 'feature/bbb' -RepoRoot $repo 2>$null | Out-Null

    $afterMark = @(Read-Ledger $ledgerPath)
    Check 'Bug 2: forward-slash mark updates in place - still two records, no duplicate' ($afterMark.Count -eq 2)
    Check 'Bug 2: both records are now cleanupable' (@($afterMark | Where-Object { $_.state -eq 'cleanupable' }).Count -eq 2)

    # Close out BOTH via a single comma-joined -Worktrees value (Bug 1) - exactly
    # how the Bash tool delivers `"a","b"`. Use the forward-slash form for A to
    # exercise Bug 2's selector normalization too.
    $joined = ($wtAfwd + ',' + $wtB)
    $cout = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'cleanup-worktrees.ps1') `
        -Scope list -Worktrees $joined -RepoRoot $repo 2>$null
    $result = ($cout | Select-Object -Last 1) | ConvertFrom-Json

    Check 'Bug 1: both worktrees are closed (not a silent no-op)' (@($result.closed).Count -eq 2)
    Check 'Bug 1: nothing was left kept' (@($result.kept).Count -eq 0)
    Check 'ledger is empty after both close out' (@(Read-Ledger $ledgerPath).Count -eq 0)
    Check 'merged feature branches are deleted at close-out (ADR 0012)' `
        (-not (& git -C $repo branch --list 'feature/*'))
    Check 'closed records report branchDeleted = true' `
        (@($result.closed | Where-Object { $_.branchDeleted }).Count -eq 2)
}
finally {
    foreach ($d in $worktreeDirs) { if ($d -and (Test-Path $d)) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue } }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED: $($failures.Count) assertion(s)."
    exit 1
}
Write-Host ""
Write-Host "All ledger assertions passed."
exit 0
