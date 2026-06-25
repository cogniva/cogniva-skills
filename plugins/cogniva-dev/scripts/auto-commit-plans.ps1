# Stop hook: auto-commit uncommitted docs/plans, docs/specs, docs/glossary, and docs/adr files.
# Contract: NEVER block the stop - exit 0 on every path.
try {
    $raw = [Console]::In.ReadToEnd()
    $cwd = $null
    $stopHookActive = $false
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $payload = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        $cwd = $payload.cwd
        $stopHookActive = $payload.stop_hook_active -eq $true
    }
    # Guard against infinite Stop-hook loop
    if ($stopHookActive) { exit 0 }

    if (-not $cwd) { $cwd = (Get-Location).Path }
    if (-not (Test-Path $cwd)) { exit 0 }

    $gitRoot = & git -C $cwd rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0) { exit 0 }
    $gitRoot = $gitRoot.Trim()

    $docPaths = @('docs/plans', 'docs/specs', 'docs/glossary', 'docs/adr')
    $status = & git -C $gitRoot status --porcelain -- $docPaths 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($status)) { exit 0 }

    # Stage only the tracked doc paths - never a broad git add
    & git -C $gitRoot add -- $docPaths 2>&1 | Out-Null
    & git -C $gitRoot commit -m "chore: auto-commit plans, specs, glossary, and ADR docs" 2>&1 | Out-Null
    exit 0
} catch {
    exit 0
}
