# Dependency-free regression test for git-commit.ps1 (no Pester).
# Exits 0 only if every assertion passes; exits 1 and prints failures otherwise.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\scripts\git-commit.ps1'))

$failures = @()
function Check($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}

# Throwaway git repo under TEMP.
$repo = Join-Path ([System.IO.Path]::GetTempPath()) ("gc-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $repo | Out-Null
try {
    & git -C $repo init -q
    & git -C $repo config user.name  'Test'
    & git -C $repo config user.email 'test@example.com'
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'hello' -NoNewline

    # Multi-line commit message — the exact shape that defeats the raw matcher.
    $msg = "feat(x): add a thing`n`nBody line with a quote `" and an em-dash —."
    # Windows PowerShell 5.1 hands a native child an embedded `"` without escaping it,
    # so the child's command line would end the argument there. Escape it the way the
    # Windows command-line convention expects (backslashes before a quote are doubled,
    # the quote becomes \"). PowerShell 7 does this itself, so leave it alone there.
    # The script still runs as a separate `powershell -File` process, as real callers run it.
    $msgArg = $msg
    if ($PSVersionTable.PSVersion.Major -lt 7) { $msgArg = $msg -replace '(\\*)"', '$1$1\"' }
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $script -RepoPath $repo -Path 'a.txt' -Message $msgArg
    $sha = ($out | Select-Object -Last 1).Trim()

    Check 'exit 0'                       ($LASTEXITCODE -eq 0)
    Check 'prints a short sha (7-12 hex)' ($sha -match '^[0-9a-f]{7,12}$')
    $log = (& git -C $repo log --oneline) -join "`n"
    Check 'one commit exists'            (($log -split "`n").Count -eq 1)
    Check 'subject is the first msg line' ($log -match 'feat\(x\): add a thing')
    $body = (& git -C $repo log -1 --format=%B) -join "`n"
    Check 'body keeps the embedded quote' ($body -match 'Body line with a quote " and an em-dash')
    $status = (& git -C $repo status --porcelain) -join "`n"
    Check 'working tree clean after commit' ([string]::IsNullOrWhiteSpace($status))

    # Error path: no -Path and no -All -> non-zero exit.
    # Windows PowerShell 5.1 turns redirected native stderr into an error record, which
    # 'Stop' would throw on; the exit code is what this case asserts.
    $ErrorActionPreference = 'Continue'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $script -RepoPath $repo -Message 'x' 2>$null
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Check 'errors when neither -Path nor -All given' ($code -ne 0)
}
finally {
    Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED: $($failures.Count) assertion(s)."
    exit 1
}
Write-Host ""
Write-Host "All git-commit assertions passed."
exit 0
