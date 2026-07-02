# Shared helpers for the cogniva JSON worktree ledger (ASCII only - PS 5.1 safe).
#
# The ledger lives in the git COMMON dir (shared by every worktree of this
# checkout), so it is NOT inside any working tree and never shows up as an
# uncommitted change. One record per worktree:
#   branch      feature/<slug>
#   worktree    absolute path to the worktree
#   base        integration target branch at creation time
#   owner       free-form label (slug or session token) - informational
#   createdAt   ISO-8601
#   state       'in-progress' | 'cleanupable'
#   recipe      $null while in-progress; on 'cleanupable' a self-contained
#               close-out recipe: { statePath, targetStatus, summary, followups }
#
# 'done' is never persisted: closing a record out removes the worktree AND prunes
# the record, so the ledger only ever holds in-progress + cleanupable entries.

function Get-CommonDir([string]$RepoRoot) {
    $c = (git -C $RepoRoot rev-parse --git-common-dir).Trim()
    if (-not [System.IO.Path]::IsPathRooted($c)) { $c = Join-Path $RepoRoot $c }
    return $c
}

function Get-LedgerPath([string]$CommonDir) { Join-Path $CommonDir 'cogniva-worktrees.json' }

function Read-Ledger([string]$LedgerPath) {
    if (-not (Test-Path $LedgerPath)) { return @() }
    # PS 5.1: `@( ... | ConvertFrom-Json )` collapses a JSON array into a SINGLE
    # wrapped item -> callers iterate once over the whole blob and Write-Ledger
    # re-nests it into { value, Count } corruption. Assign first, then @() keeps
    # the already-Object[] flat. (See memory: ledger-convertfromjson-bug.)
    try {
        $data = Get-Content -Raw -LiteralPath $LedgerPath | ConvertFrom-Json
        if ($null -eq $data) { return @() }
        return @($data)
    } catch { return @() }
}

function Write-Ledger([string]$LedgerPath, $Records) {
    $arr = @($Records)
    if ($arr.Count -eq 0) { Set-Content -LiteralPath $LedgerPath -Value '[]'; return }
    if ($arr.Count -eq 1) { Set-Content -LiteralPath $LedgerPath -Value ('[' + ($arr[0] | ConvertTo-Json -Depth 12) + ']'); return }
    Set-Content -LiteralPath $LedgerPath -Value ($arr | ConvertTo-Json -Depth 12)
}

function Lock-Ledger([string]$CommonDir) {
    $lock = Join-Path $CommonDir 'cogniva-ledger.lock'
    $deadline = (Get-Date).AddSeconds(30)
    while (Test-Path $lock) { if ((Get-Date) -gt $deadline) { break }; Start-Sleep -Milliseconds 100 }
    try { Set-Content -LiteralPath $lock -Value "$PID" -NoNewline } catch {}
    return $lock
}

function Unlock-Ledger([string]$Lock) {
    if ($Lock -and (Test-Path $Lock)) { Remove-Item -LiteralPath $Lock -Force -ErrorAction SilentlyContinue }
}

function Test-SamePath([string]$A, [string]$B) {
    if (-not $A -or -not $B) { return $false }
    $na = $A.TrimEnd('\','/').ToLowerInvariant()
    $nb = $B.TrimEnd('\','/').ToLowerInvariant()
    return $na -eq $nb
}
