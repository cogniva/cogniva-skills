# Parse a feature plan markdown file into the ordered task array execute-feature consumes.
# Contract (must match templates/execute-feature.workflow.js args.tasks):
#   Output (stdout): a JSON array of { n, title, body, isGate, done } in document order, UTF-8.
#   - Task heading: a line matching  ^##\s+(⛔\s*)?Task\s+(\d+):\s*(.*)$
#     n = the number (integer), title = the remainder, isGate = the ⛔ marker is present.
#     Heading detection is PER-LINE (NOT fence-aware): the required "Task N:" keyword is narrow
#     enough that example "## ..." lines inside fenced code blocks never match. Deliberate
#     limitation: a literal "## Task N:" line inside a fenced example WOULD misfire — no real
#     plan writes one; the keyword narrowness is the guard, matching today's hand-parse.
#   - body = every line AFTER the heading up to (not including) the next task heading, verbatim
#     (fenced code blocks, "- [ ]" examples and all). Newlines normalised to LF.
#   - done = fully checked: among checkbox lines that are NOT inside a fenced code block, at
#     least one "- [x]" and zero "- [ ]". Fence-awareness keeps an EXAMPLE "- [ ]" printed
#     inside a ``` block from making a finished task look unfinished (correct resume).
# Failure: non-zero exit + a message on stderr (missing file / no tasks found); stdout stays empty.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PlanPath
)
$ErrorActionPreference = 'Stop'

# Emit as UTF-8 without a BOM so the gate marker, em-dashes and arrows round-trip cleanly.
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8

try {
    if (-not (Test-Path -LiteralPath $PlanPath -PathType Leaf)) {
        [Console]::Error.WriteLine("parse-plan-tasks: plan file not found: $PlanPath")
        exit 1
    }

    # Read explicitly as UTF-8 (BOM-tolerant) and normalise newlines to LF.
    $text  = [System.IO.File]::ReadAllText($PlanPath, $utf8)
    $text  = $text -replace "`r`n", "`n" -replace "`r", "`n"
    $lines = $text -split "`n"

    $headingRe = '^##\s+(?<gate>⛔\s*)?Task\s+(?<n>\d+):\s*(?<title>.*)$'

    # Pass 1: locate every task heading (line index, n, title, gate flag).
    $heads = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $m = [regex]::Match($lines[$i], $headingRe)
        if ($m.Success) {
            $heads += [pscustomobject]@{
                line  = $i
                n     = [int]$m.Groups['n'].Value
                title = $m.Groups['title'].Value.TrimEnd()
                gate  = $m.Groups['gate'].Success
            }
        }
    }

    if ($heads.Count -eq 0) {
        [Console]::Error.WriteLine("parse-plan-tasks: no '## Task N:' headings found in $PlanPath")
        exit 1
    }

    # Pass 2: body = lines after each heading up to the next heading; done via fence-aware checkboxes.
    $tasks = @()
    for ($h = 0; $h -lt $heads.Count; $h++) {
        $start = $heads[$h].line + 1
        $end   = if ($h + 1 -lt $heads.Count) { $heads[$h + 1].line } else { $lines.Count }
        $bodyLines = if ($end -gt $start) { @($lines[$start..($end - 1)]) } else { @() }
        $body = ($bodyLines -join "`n")

        $inFence   = $false
        $checked   = 0
        $unchecked = 0
        foreach ($bl in $bodyLines) {
            $trimmed = $bl.TrimStart()
            if ($trimmed -match '^(```|~~~)') { $inFence = -not $inFence; continue }
            if ($inFence) { continue }
            if     ($trimmed -match '^- \[[xX]\]') { $checked++ }
            elseif ($trimmed -match '^- \[ \]')    { $unchecked++ }
        }
        $done = ($checked -ge 1) -and ($unchecked -eq 0)

        $tasks += [pscustomobject]@{
            n      = $heads[$h].n
            title  = $heads[$h].title
            body   = $body
            isGate = [bool]$heads[$h].gate
            done   = [bool]$done
        }
    }

    $json = $tasks | ConvertTo-Json -Depth 5
    # ConvertTo-Json renders a single-element array as a bare object; force an array shape.
    if ($tasks.Count -eq 1) { $json = "[$json]" }
    [Console]::Out.Write($json)
    [Console]::Out.Write("`n")
    exit 0
}
catch {
    [Console]::Error.WriteLine("parse-plan-tasks: $_")
    exit 1
}
