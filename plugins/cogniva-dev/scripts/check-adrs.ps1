# ADR sanity check for a run of execute-feature / quick-fix, in either mode.
#
# Two ways to call it, one set of checks:
#
#   -Worktree <path> [-TargetBranch <branch>]   worktree mode - the run lives on
#     its own branch in its own worktree, so "what THIS work added" is
#     <merge base with the target>..HEAD, and a new ADR number is also checked
#     against the target branch it is about to be merged into.
#
#   -Workspace <path> -Since <commit-ish>       lean mode - the run committed
#     straight onto the user's own branch in their own checkout, so there is no
#     target branch to compare against. "What THIS work added" is <Since>..HEAD
#     (the commit the run started from), and a new ADR number is checked against
#     the tree as it stood at <Since>.
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
#   A. Every docs/adr/NNNN-*.md number is unique in the tree being checked.
#   B. Every ADR's H1 heading names the same number as its filename - this is
#      what catches an "# ADR-C4:" title.
#   C. No line ADDED by this run introduces a candidate ADR-C<n> label outside
#      the excluded paths. Labels that were already there before the run are not
#      this run's problem and are deliberately not reported.
#   D. No ADR number this run ADDS is already taken by a different file on the
#      comparison ref - the target branch (worktree mode) or the tree at -Since
#      (lean mode). That is the parallel-worktree collision, caught before it
#      lands.
#
# Exit: 0 = clean (or nothing to check), 1 = problems found, 2 = usage or
# environment error. Every path prints why before it exits.
#
# check-adrs-ignore-file - this script cites ADR-C4 as an EXAMPLE throughout, so
# it must exempt itself from its own check C or it can never be integrated.
[CmdletBinding()]
param(
    # Worktree mode.
    [string]$Worktree,
    [string]$TargetBranch = 'main',

    # Lean mode.
    [string]$Workspace,
    [string]$Since,

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

# The two modes are separated by hand rather than by a PowerShell parameter set:
# an unresolvable ParameterSetName exits 1, and 1 is reserved here for "problems
# found", so a caller could not tell a typo from a real ADR collision. Every
# usage mistake below exits 2 instead.
if ($Worktree -and $Workspace)  { Fail "pass either -Worktree (with -TargetBranch) or -Workspace (with -Since), not both." }
if ($Worktree -and $Since)      { Fail "-Since belongs to -Workspace mode; worktree mode compares against -TargetBranch." }
if ($Workspace -and -not $Since) { Fail "-Workspace requires -Since <commit-ish> - the commit this run started from." }
if ($Since -and -not $Workspace) { Fail "-Since requires -Workspace <path>." }
if (-not $Worktree -and -not $Workspace) {
    Fail "usage: check-adrs.ps1 -Worktree <path> [-TargetBranch <branch>] | -Workspace <path> -Since <commit-ish>"
}

# Everything below works off these three, so the four checks are written once.
$sinceMode = [bool]$Workspace
if ($sinceMode) { $root = $Workspace; $rootLabel = 'workspace'; $compareRef = $Since }
else            { $root = $Worktree;  $rootLabel = 'worktree';  $compareRef = $TargetBranch }

if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    Fail "$rootLabel not found: $root"
}

$adrFull    = Join-Path $root $AdrDir
$adrPresent = Test-Path -LiteralPath $adrFull -PathType Container
$problems   = @()
$checked    = @()

# --------------------------------------------------------------- checks A + B
if (-not $adrPresent) {
    Write-Output "check-adrs: no $AdrDir/ in this $rootLabel - skipping the number and heading checks (A, B)."
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
# Both need a base commit to diff from: the merge base with the target branch in
# worktree mode, the caller's -Since commit in lean mode. A target branch that
# does not resolve (fresh repo, unusual name) is tolerated and announced rather
# than silently passing; a -Since the caller handed us is a usage error.
$base = ''
if ($sinceMode) {
    $rp   = Invoke-Git -C $root rev-parse --verify --quiet "$Since^{commit}"
    $base = "$($rp.Lines | Select-Object -First 1)".Trim()
    if ($rp.Code -ne 0 -or -not $base) { Fail "cannot resolve -Since '$Since' in $root" }
} else {
    $mb   = Invoke-Git -C $root merge-base $TargetBranch HEAD
    $base = "$($mb.Lines | Select-Object -First 1)".Trim()
    if ($mb.Code -ne 0 -or -not $base) {
        $base = ''
        Write-Output "check-adrs: cannot resolve a merge base between '$TargetBranch' and HEAD - skipping the added-line checks (C, D)."
        Write-Output "check-adrs: pass -TargetBranch if '$TargetBranch' is not this repo's integration target."
    }
}

if ($base) {
    # --- Check C: candidate labels on lines this run ADDED.
    $d = Invoke-Git -C $root diff --unified=0 "$base..HEAD"
    if ($d.Code -ne 0) { Fail "git diff failed against '$compareRef' in $root" }
    $diff = $d.Lines

    # A file that legitimately DISCUSSES candidate labels - this script, its
    # tests, the ADR-FORMAT guidance, a glossary entry - would otherwise trip
    # check C on its own examples. Such a file declares itself once with the
    # marker below and is skipped wholesale. Rare by construction, and greppable,
    # so the opt-out can never quietly spread.
    $optOutMarker = 'check-adrs-ignore-file'
    $optOut = @{}
    function Test-OptOut($relPath) {
        if ($optOut.ContainsKey($relPath)) { return $optOut[$relPath] }
        $full = Join-Path $root $relPath
        $val = $false
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            try {
                $content = [System.IO.File]::ReadAllText($full)
                $val = $content.Contains($optOutMarker)
            } catch { $val = $false }
        }
        $optOut[$relPath] = $val
        return $val
    }

    $currentFile = ''
    $skippedFiles = @()
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

        if (Test-OptOut $currentFile) {
            if ($skippedFiles -notcontains $currentFile) { $skippedFiles += $currentFile }
            continue
        }

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
    # Never let an opt-out be silent - a skipped file must be visible in the report.
    foreach ($sf in $skippedFiles) {
        $checked += "C: SKIPPED $sf - declares the '$optOutMarker' marker"
    }

    # --- Check D: numbers this run adds that the comparison ref already uses.
    # A path-scoped git call returns non-zero when $AdrDir exists in neither
    # tree. That is a repo without ADRs, not a broken environment, so it is
    # announced and skipped rather than treated as a failure.
    if (-not $adrPresent) {
        Write-Output "check-adrs: no $AdrDir/ in this $rootLabel - skipping the collision check (D)."
    } else {
        $a = Invoke-Git -C $root diff --name-only --diff-filter=A "$base..HEAD" -- $AdrDir
        $added = @()
        if ($a.Code -eq 0) { $added = $a.Lines }
        else { Write-Output "check-adrs: no ADR paths in the range $compareRef..HEAD - treating check D as 'no new ADRs'." }

        $t = Invoke-Git -C $root ls-tree -r --name-only $compareRef -- $AdrDir
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
                $problems += "NUMBER TAKEN     $af collides with $($targetByNumber[$num]) already on '$compareRef' - renumber before it lands"
            }
        }
        $checked += "D: $addedCount new ADR(s) checked against '$compareRef' for an already-taken number"
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
    Write-Output "Fix them in the $rootLabel, commit, then re-run this check."
    exit 1
}

Write-Output "check-adrs: clean - ADR numbers are unique, every heading matches its filename,"
Write-Output "            no new ADR-C candidate labels were introduced, and no new ADR number"
Write-Output "            collides with '$compareRef'."
exit 0
