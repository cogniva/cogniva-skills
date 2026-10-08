#Requires -Version 7.0
# Structural-change core: snapshot the working state as a git tree, list the
# changes between two trees, read files from a tree, and write a detector's
# report. Writes git objects only - never refs, the index or the working tree.
# Dot-sourced by check-structural-changes.ps1 and by every structure detector.
# Every failure throws a StructureError naming what failed.

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Invoke-StructureGit([string]$Repo, [string[]]$Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = @(& git -C $Repo -c core.safecrlf=false -c core.quotepath=false @Arguments 2>$null)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    if ($code -ne 0) { throw [System.InvalidOperationException]::new("StructureError: git $($Arguments -join ' ') failed (exit $code) in $Repo") }
    return $out
}

# The working state as a tree: tracked, staged, unstaged and untracked files
# (.gitignore'd files left out). A copy of the index is used, so the real
# index and the working tree are never touched.
function Get-WorkingTreeSnapshot([string]$Repo) {
    $index = (@(Invoke-StructureGit $Repo @('rev-parse', '--git-path', 'index')) | Select-Object -First 1).Trim()
    if (-not [System.IO.Path]::IsPathRooted($index)) { $index = Join-Path $Repo $index }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-structure-" + [guid]::NewGuid().ToString('N') + '.index')
    $previous = $env:GIT_INDEX_FILE
    try {
        if (Test-Path -LiteralPath $index -PathType Leaf) { Copy-Item -LiteralPath $index -Destination $tmp }
        $env:GIT_INDEX_FILE = $tmp
        Invoke-StructureGit $Repo @('add', '-A') | Out-Null
        $tree = (@(Invoke-StructureGit $Repo @('write-tree')) | Select-Object -First 1)
    }
    finally {
        if ($null -eq $previous) { Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue } else { $env:GIT_INDEX_FILE = $previous }
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath "$tmp.lock" -Force -ErrorAction SilentlyContinue
    }
    if ("$tree".Trim() -notmatch '^[0-9a-f]{40,64}$') { throw [System.InvalidOperationException]::new("StructureError: git write-tree returned no tree for $Repo") }
    return "$tree".Trim()
}

# The tree of a commit or tree.
function Resolve-StructureTree([string]$Repo, [string]$Revision) {
    $tree = $null
    try { $tree = (@(Invoke-StructureGit $Repo @('rev-parse', '--verify', '--quiet', "$Revision^{tree}")) | Select-Object -First 1) }
    catch { throw [System.InvalidOperationException]::new("StructureError: '$Revision' is not a commit or tree in $Repo") }
    return "$tree".Trim()
}

# Every path that differs between two trees, renames paired:
# @({ Status = 'A'|'D'|'M'|'T'|'R'; Path; OldPath }). OldPath is set only for R.
function Get-TreeChanges([string]$Repo, [string]$Base, [string]$Head) {
    $raw = (@(Invoke-StructureGit $Repo @('diff-tree', '-r', '-M', '--name-status', '-z', $Base, $Head))) -join "`n"
    $tokens = @($raw.Split([char]0) | Where-Object { $_ -ne '' })
    $changes = @()
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $letter = $tokens[$i].Substring(0, 1)
        if ($letter -eq 'R' -or $letter -eq 'C') {
            $changes += [pscustomobject]@{ Status = $letter; OldPath = $tokens[$i + 1]; Path = $tokens[$i + 2] }
            $i += 2
        }
        else {
            $changes += [pscustomobject]@{ Status = $letter; OldPath = $null; Path = $tokens[$i + 1] }
            $i += 1
        }
    }
    return $changes
}

# Every file path in a tree.
function Get-TreePaths([string]$Repo, [string]$Tree) {
    $raw = (@(Invoke-StructureGit $Repo @('ls-tree', '-r', '--name-only', '-z', $Tree))) -join "`n"
    return @($raw.Split([char]0) | Where-Object { $_ -ne '' })
}

# The text of $Path in $Tree, or $null when the tree has no such file.
function Get-TreeFileText([string]$Repo, [string]$Tree, [string]$Path) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = @(& git -C $Repo cat-file -p "${Tree}:$Path" 2>$null)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    if ($code -ne 0) { return $null }
    return ($lines -join "`n")
}

function New-StructureFact([string]$Kind, [string[]]$Units, [string[]]$Paths, [string]$Evidence) {
    return [pscustomobject]@{ kind = $Kind; units = @($Units); paths = @($Paths); evidence = $Evidence }
}

# A detector's contract-1 report, facts in a stable order.
function Write-DetectorReport([string]$Detector, [object[]]$Facts) {
    $sorted = @($Facts | Sort-Object -Property @{ Expression = { $_.kind } }, @{ Expression = { $_.units -join '|' } }, @{ Expression = { $_.paths -join '|' } })
    return ([pscustomobject]@{ contract = 1; detector = $Detector; facts = $sorted } | ConvertTo-Json -Depth 6)
}
