# Pre-integration ADR sanity check for a feature / quick-fix worktree.
#
# Concrete ADRs are written DURING execution (execute-feature's "ADRs during
# execution", quick-fix Step 0.5), by task agents that cannot see each other or
# the target branch. Two failure modes follow from that, and both are invisible
# until well after the merge:
#
#   1. NUMBER COLLISION - two parallel worktrees each scan docs/adr/, each find
#      0142 free, and each write a different 0142. Git only reports this when the
#      two filenames happen to match; different slugs merge cleanly and leave two
#      ADRs claiming the same number.
#   2. UNDEREFERENCED CANDIDATE LABEL - a plan's candidate label (ADR-C4) is
#      copied verbatim into shipped code, a skill, or the ADR's own H1 instead of
#      the number it was assigned. ADR-C4 means a DIFFERENT decision in every
#      feature, so a reader following one from elsewhere lands on the wrong ADR.
#
# Checks (all four run; the script does not stop at the first problem):
#   A. Every docs/adr/NNNN-*.md number is unique within the worktree.
#   B. Every ADR's H1 heading names the same number as its filename - this is
#      what catches an "# ADR-C4:" title.
#   C. No line ADDED by this branch introduces a candidate ADR-C<n> label outside
#      the excluded paths. Pre-existing labels elsewhere in the repo are not this
#      integration's problem and are deliberately not reported.
#   D. No ADR number this branch ADDS is already taken on the target branch by a
#      different file (the parallel-worktree collision, caught pre-merge).
#
# Exit: 0 = clean (or nothing to check), 1 = problems found, 2 = usage or
# environment error. Every path prints why before it exits.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Worktree,
    [string]$TargetBranch = 'main',
    [string]$AdrDir = 'docs/adr',
    # Paths where a candidate ADR-C label is CORRECT and must not be reported.
    # Plans and design notes are where candidates are supposed to live; the
    # tool-call log is machine-written transcript data.
    [string[]]$ExcludePath = @('docs/plans/', 'docs/local/')
)
$ErrorActionPreference = 'Stop'

function Fail($msg) { [Console]::Error.WriteLine("check-adrs: $msg"); exit 2 }

# Windows PowerShell turns a native command's stderr into a TERMINATING
# NativeCommandError while $ErrorActionPreference is 'Stop', and `2>$null` does
# NOT prevent it. Every git call goes through here so an ordinary git failure
# (an unresolvable target branch, say) reaches our own reporting instead of
# killing the script with a stack trace and no explanation.
function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments)][string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $raw  = & git @GitArgs 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    $lines = @()
    foreach ($o in $raw) {
        if ($o -isnot [System.Management.Automation.ErrorRecord]) { $lines += [string]$o }
    }
    return [pscustomobject]@{ Code = $code; Lines = $lines }
}

if (-not (Test-Path -LiteralPath $Worktree -PathType Container)) {
    Fail "worktree not found: $Worktree"
}

$adrFull    = Join-Path $Worktree $AdrDir
$adrPresent = Test-Path -LiteralPath $adrFull -PathType Container
$problems   = @()
$checked    = @()

# --------------------------------------------------------------- checks A + B
if (-not $adrPresent) {
    Write-Output "check-adrs: no $AdrDir/ in this worktree - skipping the number and heading checks (A, B)."
} else {
    $adrFiles = @(Get-ChildItem -LiteralPath $adrFull -Filter '*.md' -File | Sort-Object Name)
    if ($adrFiles.Count -eq 0) {
        Write-Output "check-adrs: $AdrDir/ is empty - skipping the number and heading checks (A, B)."
    } else {
        $checked += "A: $($adrFiles.Count) ADR filename(s) scanned for duplicate numbers"
        $checked += "B: $($adrFiles.Count) ADR heading(s) checked against their filename"

        $byNumber = @{}
        foreach ($f in $adrFiles) {
            $m = [regex]::Match($f.Name, '^(?<n>\d{4})-')
            if (-not $m.Success) {
                $problems += "MALFORMED NAME   $AdrDir/$($f.Name) - does not start with a 4-digit ADR number"
                continue
            }
            $num = $m.Groups['n'].Value
            if (-not $byNumber.ContainsKey($num)) { $byNumber[$num] = @() }
            $byNumber[$num] += $f.Name

            # Check B: the H1 must not contradict the filename.
            #
            # ADR-FORMAT's template is `# {Short title}` - NO number in the
            # heading - and many repos also carry a `# NNNN - Title` house
            # variant. Both are fine, so a heading WITHOUT a number is never a
            # problem. Only two things are:
            #   * a candidate label (ADR-C4) that was never dereferenced, and
            #   * an explicit number that disagrees with the filename.
            $first = ''
            foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
                if ($line.Trim().Length -gt 0) { $first = $line; break }
            }
            $cand = [regex]::Match($first, 'ADR-C(?<c>\d+)')
            if ($cand.Success) {
                $problems += "CANDIDATE TITLE  $AdrDir/$($f.Name) - H1 still says ADR-C$($cand.Groups['c'].Value) (a planning candidate label); it shipped as $num"
            } else {
                # An explicit number, written either as `# NNNN ...` or `# ADR-NNNN ...`.
                $hn = [regex]::Match($first, '^#\s+(?:ADR-)?(?<n>\d{4})\b')
                if ($hn.Success -and $hn.Groups['n'].Value -ne $num) {
                    $problems += "NUMBER MISMATCH  $AdrDir/$($f.Name) - H1 says $($hn.Groups['n'].Value) but the filename says $num"
                }
            }
        }

        foreach ($num in ($byNumber.Keys | Sort-Object)) {
            if ($byNumber[$num].Count -gt 1) {
                $problems += "DUPLICATE NUMBER ADR-$num is claimed by $($byNumber[$num].Count) files: $($byNumber[$num] -join ', ')"
            }
        }
    }
}

# --------------------------------------------------------------- checks C + D
# Both need the merge base with the target branch. If it does not resolve (fresh
# repo, unusual target name), say so rather than silently passing.
$mb = Invoke-Git -C $Worktree merge-base $TargetBranch HEAD
$mergeBase = ($mb.Lines | Select-Object -First 1)
if ($mb.Code -ne 0 -or -not $mergeBase) {
    Write-Output "check-adrs: cannot resolve a merge base between '$TargetBranch' and HEAD - skipping the added-line checks (C, D)."
    Write-Output "check-adrs: pass -TargetBranch if '$TargetBranch' is not this repo's integration target."
} else {
    $mergeBase = $mergeBase.Trim()

    # --- Check C: candidate labels on lines this branch ADDED.
    $d = Invoke-Git -C $Worktree diff --unified=0 "$mergeBase..HEAD"
    if ($d.Code -ne 0) { Fail "git diff failed against '$TargetBranch' in $Worktree" }
    $diff = $d.Lines

    $currentFile = ''
    foreach ($line in $diff) {
        if ($line -match '^\+\+\+ b/(.+)$') { $currentFile = $Matches[1]; continue }
        if ($line -like '+++ /dev/null*')   { $currentFile = ''; continue }
        if (-not $currentFile)              { continue }
        if ($line -like '+++*')             { continue }
        if ($line -notlike '+*')            { continue }

        $skip = $false
        foreach ($ex in $ExcludePath) {
            if ($currentFile.StartsWith($ex, [StringComparison]::OrdinalIgnoreCase)) { $skip = $true; break }
        }
        if ($skip) { continue }

        $labels = [regex]::Matches($line, 'ADR-C\d+')
        if ($labels.Count -gt 0) {
            $seen = @()
            foreach ($l in $labels) { if ($seen -notcontains $l.Value) { $seen += $l.Value } }
            $text = $line.Substring(1).Trim()
            if ($text.Length -gt 100) { $text = $text.Substring(0, 100) + '...' }
            $problems += "CANDIDATE LABEL  $currentFile - added line still cites $($seen -join ', '): $text"
        }
    }
    $checked += "C: added lines scanned for candidate ADR-C labels (excluding: $($ExcludePath -join ', '))"

    # --- Check D: numbers this branch adds that the target already uses.
    # --- Check D: numbers this branch adds that the target already uses.
    # A path-scoped git call returns non-zero when $AdrDir exists in neither
    # tree. That is a repo without ADRs, not a broken environment, so it is
    # announced and skipped rather than treated as a failure.
    if (-not $adrPresent) {
        Write-Output "check-adrs: no $AdrDir/ in this worktree - skipping the target-collision check (D)."
    } else {
        $a = Invoke-Git -C $Worktree diff --name-only --diff-filter=A "$mergeBase..HEAD" -- $AdrDir
        $added = @()
        if ($a.Code -eq 0) { $added = $a.Lines }
        else { Write-Output "check-adrs: no ADR paths in the range $TargetBranch..HEAD - treating check D as 'no new ADRs'." }

        $t = Invoke-Git -C $Worktree ls-tree -r --name-only $TargetBranch -- $AdrDir
        $targetFiles = @()
        if ($t.Code -eq 0) { $targetFiles = $t.Lines }

        $targetByNumber = @{}
        foreach ($tf in $targetFiles) {
            $leaf = Split-Path -Leaf $tf
            $m = [regex]::Match($leaf, '^(?<n>\d{4})-')
            if ($m.Success) { $targetByNumber[$m.Groups['n'].Value] = $leaf }
        }

        $addedCount = 0
        foreach ($af in $added) {
            $leaf = Split-Path -Leaf $af
            $m = [regex]::Match($leaf, '^(?<n>\d{4})-')
            if (-not $m.Success) { continue }
            $addedCount++
            $num = $m.Groups['n'].Value
            if ($targetByNumber.ContainsKey($num) -and $targetByNumber[$num] -ne $leaf) {
                $problems += "NUMBER TAKEN     $af collides with $($targetByNumber[$num]) already on '$TargetBranch' - renumber before integrating"
            }
        }
        $checked += "D: $addedCount new ADR(s) checked against '$TargetBranch' for an already-taken number"
    }
}

# --------------------------------------------------------------------- report
Write-Output ""
foreach ($c in $checked) { Write-Output "  ran  $c" }
Write-Output ""

if ($problems.Count -gt 0) {
    Write-Output "check-adrs: $($problems.Count) problem(s) found - do NOT integrate until these are resolved:"
    Write-Output ""
    foreach ($p in $problems) { Write-Output "  $p" }
    Write-Output ""
    Write-Output "Fix them in the worktree, commit on the feature branch, then re-run this check."
    exit 1
}

Write-Output "check-adrs: clean - ADR numbers are unique, every heading matches its filename,"
Write-Output "            no new ADR-C candidate labels were introduced, and no new ADR number"
Write-Output "            collides with '$TargetBranch'."
exit 0
