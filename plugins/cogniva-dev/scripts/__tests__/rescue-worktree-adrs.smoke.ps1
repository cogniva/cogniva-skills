# Smoke test for rescue-worktree-adrs.ps1. Self-contained: builds a throwaway primary
# repo + feature worktree, drops a colliding floating ADR, runs the rescue, and asserts
# the ADR was renumbered + committed onto the feature branch, the worktree is left clean,
# and a second run is a no-op. Prints "SMOKE OK"/exit 0 on success; "SMOKE FAIL: <why>"/exit 1.
$ErrorActionPreference = 'Stop'
$script = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') 'rescue-worktree-adrs.ps1')).Path

function Fail($m) { Write-Output "SMOKE FAIL: $m"; exit 1 }

$root    = Join-Path ([System.IO.Path]::GetTempPath()) ("adr-rescue-smoke-" + [System.IO.Path]::GetRandomFileName())
$primary = Join-Path $root 'primary'
New-Item -ItemType Directory -Path $primary -Force | Out-Null
try {
    git -C $primary init -q -b main *>$null
    git -C $primary config user.email t@t.t *>$null
    git -C $primary config user.name  test  *>$null
    New-Item -ItemType Directory -Path (Join-Path $primary 'docs/adr') -Force | Out-Null
    Set-Content -Path (Join-Path $primary 'docs/adr/0001-a.md') -Value '# A'
    git -C $primary add -A *>$null
    git -C $primary commit -q -m init *>$null

    # feature worktree off main (sees only 0001)
    $wt = Join-Path $root 'wt-feat'
    git -C $primary worktree add -q $wt -b feature/feat main *>$null

    # primary concurrently gains a DIFFERENT 0002
    Set-Content -Path (Join-Path $primary 'docs/adr/0002-other.md') -Value '# Other'
    git -C $primary add -A *>$null
    git -C $primary commit -q -m other *>$null

    # floating (untracked) ADR in the worktree, also numbered 0002 -> must renumber to 0003
    Set-Content -Path (Join-Path $wt 'docs/adr/0002-b.md') -Value '# B'

    $json = (& powershell -NoProfile -ExecutionPolicy Bypass -File $script -WorktreePath $wt -FeatureBranch feature/feat -Mode Commit -PrimaryRoot $primary | Out-String)

    if ($json -notmatch '"from":\s*2') { Fail "expected renumber from 2; got: $json" }
    if ($json -notmatch '"to":\s*3')   { Fail "expected renumber to 3; got: $json" }
    if (-not (Test-Path (Join-Path $wt 'docs/adr/0003-b.md'))) { Fail "renamed file 0003-b.md missing" }
    if (Test-Path (Join-Path $wt 'docs/adr/0002-b.md'))        { Fail "old 0002-b.md still present" }

    $dirty = git -C $wt status --porcelain
    if ($dirty) { Fail "worktree not clean after rescue: $dirty" }

    $head = (git -C $wt show --name-only --pretty=format: HEAD | Out-String)
    if ($head -notmatch '0003-b\.md') { Fail "HEAD commit does not include 0003-b.md: $head" }

    # idempotency: second run is a no-op (the ADR is now committed, not floating)
    $json2 = (& powershell -NoProfile -ExecutionPolicy Bypass -File $script -WorktreePath $wt -FeatureBranch feature/feat -Mode Commit -PrimaryRoot $primary | Out-String)
    if ($json2 -notmatch '"status":"NOOP"') { Fail "second run should be NOOP; got: $json2" }

    Write-Output "SMOKE OK"
    exit 0
}
finally {
    try { git -C $primary worktree remove --force (Join-Path $root 'wt-feat') *>$null } catch {}
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
