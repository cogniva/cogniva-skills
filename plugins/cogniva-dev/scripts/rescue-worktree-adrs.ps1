# Deterministic backstop: rescue "floating" ADRs (uncommitted OR untracked docs/adr/**)
# from a feature worktree so an ADR written inside the worktree is never lost when the
# worktree is integrated and later torn down. See docs/adr/0005.
#
# Modes:
#   -Mode Commit        (default) commit the floating ADR(s) onto the worktree's current
#                       (feature) branch, so integrate-feature.ps1's fast-forward push
#                       carries them into the target as feature history. Leaves the
#                       worktree clean so `git worktree remove` succeeds without --force.
#   -Mode CopyToPrimary copy the floating ADR(s) into the PRIMARY checkout's docs/adr/
#                       (the Stop hook commits them). Used at teardown, when the feature
#                       is already integrated and committing onto it would be a dead end.
#
# Collision: if an ADR number is already taken by a DIFFERENT ADR in the primary checkout,
# the rescued file is renumbered to the next free number (never clobbers). If an identical
# ADR already exists in the primary checkout, the floating copy is skipped (idempotent).
#
# Best-effort: never throws to the caller and ALWAYS exits 0 — a rescue problem must never
# fail the integration or the worktree removal it rides along with. Never pushes to a
# remote; never branch-switches the primary checkout.
#
# Output (last line): JSON { status, mode, primaryRoot, branch, rescued:[...],
#   renumbered:[{from,to,file,newFile}], skipped:[{file,reason}], commit, detail }
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorktreePath,
    [string]$FeatureBranch,
    [ValidateSet('Commit','CopyToPrimary')][string]$Mode = 'Commit',
    [string]$PrimaryRoot,
    [string]$AdrDir = 'docs/adr'
)

function Emit($obj) { $obj | ConvertTo-Json -Compress -Depth 6; exit 0 }
function Get-AdrNumber([string]$name) { if ($name -match '^0*(\d+)') { return [int]$Matches[1] } return $null }

try {
    if (-not (Test-Path -LiteralPath $WorktreePath)) {
        Emit ([pscustomobject]@{ status='ERROR'; mode=$Mode; detail="worktree not found: $WorktreePath" })
    }

    # Resolve the PRIMARY checkout (the main worktree) if not supplied. `git worktree list
    # --porcelain` lists the main working tree FIRST.
    if (-not $PrimaryRoot) {
        foreach ($line in (git -C $WorktreePath worktree list --porcelain 2>$null)) {
            if ($line -like 'worktree *') { $PrimaryRoot = $line.Substring(9).Trim(); break }
        }
    }
    if (-not $PrimaryRoot) { $PrimaryRoot = $WorktreePath }   # degrade safely

    $branch = (git -C $WorktreePath branch --show-current 2>$null)
    if ($branch) { $branch = $branch.Trim() }

    # 1. Detect floating ADRs in the worktree (untracked OR uncommitted under docs/adr).
    $status = git -C $WorktreePath status --porcelain -- $AdrDir 2>$null
    if (-not $status) {
        Emit ([pscustomobject]@{ status='NOOP'; mode=$Mode; primaryRoot=$PrimaryRoot; branch=$branch; rescued=@(); renumbered=@(); skipped=@() })
    }

    $floating = @()
    foreach ($line in $status) {
        if ($line.Length -lt 4) { continue }
        $p = $line.Substring(3).Trim().Trim('"')
        if ($p -match ' -> (.+)$') { $p = $Matches[1].Trim().Trim('"') }   # rename: keep destination
        if ($p -notmatch '\.md$') { continue }
        $full = Join-Path $WorktreePath $p
        if (Test-Path -LiteralPath $full -PathType Leaf) { $floating += $full }
    }
    $floating = @($floating | Select-Object -Unique)
    if ($floating.Count -eq 0) {
        Emit ([pscustomobject]@{ status='NOOP'; mode=$Mode; primaryRoot=$PrimaryRoot; branch=$branch; rescued=@(); renumbered=@(); skipped=@() })
    }

    # 2. Index the taken ADR numbers and the primary's ADR identities.
    $primaryAdr   = Join-Path $PrimaryRoot $AdrDir
    $primaryByNum = @{}     # "<n>" -> @(basenames)
    $primaryHash  = @{}     # sha256 -> $true
    $taken        = @{}     # "<n>" -> $true (primary + worktree)

    if (Test-Path -LiteralPath $primaryAdr) {
        foreach ($f in (Get-ChildItem -LiteralPath $primaryAdr -Filter *.md -File -ErrorAction SilentlyContinue)) {
            $n = Get-AdrNumber $f.Name
            if ($null -ne $n) {
                $taken["$n"] = $true
                if (-not $primaryByNum.ContainsKey("$n")) { $primaryByNum["$n"] = @() }
                $primaryByNum["$n"] += $f.Name
            }
            try { $primaryHash[(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash] = $true } catch {}
        }
    }
    $wtAdr = Join-Path $WorktreePath $AdrDir
    if (Test-Path -LiteralPath $wtAdr) {
        foreach ($f in (Get-ChildItem -LiteralPath $wtAdr -Filter *.md -File -ErrorAction SilentlyContinue)) {
            $n = Get-AdrNumber $f.Name; if ($null -ne $n) { $taken["$n"] = $true }
        }
    }
    $nextFree = 1
    foreach ($k in $taken.Keys) { if ([int]$k -ge $nextFree) { $nextFree = [int]$k + 1 } }

    $rescued = @(); $renumbered = @(); $skipped = @(); $toCommit = @()

    foreach ($full in $floating) {
        $base = Split-Path -Leaf $full
        $num  = Get-AdrNumber $base
        $hash = $null
        try { $hash = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash } catch {}

        if ($hash -and $primaryHash.ContainsKey($hash)) {
            $skipped += [pscustomobject]@{ file=$base; reason='already present in primary' }
            continue
        }

        $finalName = $base
        if ($null -ne $num -and $primaryByNum.ContainsKey("$num") -and ($primaryByNum["$num"] -notcontains $base)) {
            $newNum  = $nextFree; $nextFree++
            $suffix  = $base -replace '^0*\d+', ''         # keep "-slug.md"
            $finalName = ('{0:0000}{1}' -f $newNum, $suffix)
            $renumbered += [pscustomobject]@{ from=$num; to=$newNum; file=$base; newFile=$finalName }
            $taken["$newNum"] = $true
        } else {
            if ($null -ne $num) { $taken["$num"] = $true }
            $rescued += $base
        }

        if ($Mode -eq 'CopyToPrimary') {
            if (-not (Test-Path -LiteralPath $primaryAdr)) { New-Item -ItemType Directory -Path $primaryAdr -Force | Out-Null }
            $dest = Join-Path $primaryAdr $finalName
            if (Test-Path -LiteralPath $dest) { $skipped += [pscustomobject]@{ file=$finalName; reason='destination already exists in primary' }; continue }
            Copy-Item -LiteralPath $full -Destination $dest -Force
        } else {
            if ($finalName -ne $base) {
                Move-Item -LiteralPath $full -Destination (Join-Path (Split-Path -Parent $full) $finalName) -Force
            }
            $toCommit += (Join-Path $AdrDir $finalName)
        }
    }

    $commitSha = $null
    if ($Mode -eq 'Commit' -and @($toCommit).Count -gt 0) {
        git -C $WorktreePath add -- @toCommit 2>$null | Out-Null
        $msgFile = [System.IO.Path]::GetTempFileName()
        try {
            $msg = "docs(adr): rescue floating ADR(s) into feature history`n`nDeterministic backstop (docs/adr/0005): commit ADR(s) written inside the worktree so integration carries them into the target."
            [System.IO.File]::WriteAllText($msgFile, $msg, [System.Text.UTF8Encoding]::new($false))
            git -C $WorktreePath commit -F $msgFile 2>$null | Out-Null
        } finally { Remove-Item -LiteralPath $msgFile -Force -ErrorAction SilentlyContinue }
        $commitSha = (git -C $WorktreePath rev-parse --short HEAD 2>$null)
        if ($commitSha) { $commitSha = $commitSha.Trim() }
    }

    Emit ([pscustomobject]@{
        status='RESCUED'; mode=$Mode; primaryRoot=$PrimaryRoot; branch=$branch;
        rescued=$rescued; renumbered=$renumbered; skipped=$skipped; commit=$commitSha
    })
}
catch {
    Emit ([pscustomobject]@{ status='ERROR'; mode=$Mode; detail="$_" })
}
