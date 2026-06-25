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
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $script -RepoPath $repo -Path 'a.txt' -Message $msg
    $sha = ($out | Select-Object -Last 1).Trim()

    Check 'exit 0'                       ($LASTEXITCODE -eq 0)
    Check 'prints a short sha (7-12 hex)' ($sha -match '^[0-9a-f]{7,12}$')
    $log = (& git -C $repo log --oneline) -join "`n"
    Check 'one commit exists'            (($log -split "`n").Count -eq 1)
    Check 'subject is the first msg line' ($log -match 'feat\(x\): add a thing')
    $status = (& git -C $repo status --porcelain) -join "`n"
    Check 'working tree clean after commit' ([string]::IsNullOrWhiteSpace($status))

    # Error path: no -Path and no -All -> non-zero exit.
    & powershell -NoProfile -ExecutionPolicy Bypass -File $script -RepoPath $repo -Message 'x' 2>$null
    Check 'errors when neither -Path nor -All given' ($LASTEXITCODE -ne 0)
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
