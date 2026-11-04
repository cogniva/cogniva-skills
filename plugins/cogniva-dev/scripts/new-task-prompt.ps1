#Requires -Version 7.0
# Builds the task-agent prompt for ONE task - byte-for-byte the prompt that
# templates/execute-feature.workflow.js builds for the same inputs (the
# task-contract suite proves it). Used by the sequential executor in
# skills/execute-feature/CODEX.md, so both executors hand workers the same text.
# -TaskFile: a UTF-8 JSON file holding { "n", "title", "body" } for the task
#   (other fields, such as parse-plan-tasks.ps1's isGate/done, are ignored).
# -ResultContract: append the "=== RESULT ===" section that asks the worker to
#   end its reply with one fenced json block conforming to
#   templates/task-result.schema.json (the Workflow runtime enforces the schema
#   itself, so the template has no such section).
# Writes the prompt to stdout as UTF-8 without a BOM and without a trailing
# newline. Exit 0 on success, 2 on a usage error.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Workspace,
    [Parameter(Mandatory)][string]$Branch,
    [Parameter(Mandatory)][ValidateSet('none', 'task', 'final')][string]$Commits,
    [string]$PlanPath,
    [string]$StatePath,
    [Parameter(Mandatory)][string]$TaskFile,
    [switch]$ResultContract
)
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) { [Console]::Error.WriteLine("new-task-prompt: $Message"); exit 2 }

if (-not (Test-Path -LiteralPath $TaskFile -PathType Leaf)) { Fail "task file not found: $TaskFile" }
try {
    $raw = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $TaskFile).ProviderPath, [System.Text.UTF8Encoding]::new($false))
    # System.Text.Json, not ConvertFrom-Json: it never turns date-like strings into dates.
    $task = [System.Text.Json.JsonDocument]::Parse($raw.TrimStart([char]0xFEFF)).RootElement
}
catch { Fail "task file is not valid JSON: $TaskFile" }

function Get-TaskText([string]$Name) {
    $value = [System.Text.Json.JsonElement]::new()
    if (-not $task.TryGetProperty($Name, [ref]$value)) { Fail "task file has no '$Name'" }
    switch ($value.ValueKind) {
        'String' { return $value.GetString() }
        'Number' { return [string]$value.GetDouble() }
        default { Fail "task file '$Name' must be a string or a number" }
    }
}
$n = Get-TaskText 'n'
$title = Get-TaskText 'title'
$body = Get-TaskText 'body'

# Mirrors the template's line array; $null entries are dropped like its
# .filter(l => l !== null), and the lines are joined with "\n".
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('Implement EXACTLY ONE task of a feature plan, then stop. Do not start the next task.')
$lines.Add("Your only working directory is: $Workspace")
$lines.Add("You are already checked out on $Branch. NEVER run git switch / checkout / branch " + [char]0x2014 + ' work where you are.')
$lines.Add("Use absolute paths under the workspace. Follow the task's steps verbatim, TDD-style:")
$lines.Add('write the failing test ' + [char]0x2192 + ' run it (confirm it fails) ' + [char]0x2192 + ' minimal implementation ' + [char]0x2192 + ' run until green ' + [char]0x2192 + " run the task's full verification.")
if ($Commits -eq 'task') {
    if ($PlanPath) { $lines.Add("On success: FIRST edit $PlanPath to flip THIS task's checkboxes from `"- [ ]`" to `"- [x]`".") }
    $lines.Add("Then stage ONLY the files you changed and commit with the task's commit message (keep the repo's commit conventions).")
}
else {
    $lines.Add('Do NOT stage or commit anything: leave the files you changed in the working tree.')
    if ($PlanPath) { $lines.Add("On success: edit $PlanPath to flip THIS task's checkboxes from `"- [ ]`" to `"- [x]`".") }
}
if ($StatePath) { $lines.Add("Append one short line to ${StatePath}: created/modified paths, key decisions, and the commit SHA.") }
$lines.Add('If you cannot finish cleanly, return status BLOCKED with a precise note and do NOT leave a partial commit.')
$lines.Add('NEVER write to any BACKLOG.md. Fix any bug YOUR changes introduced before returning DONE ' + [char]0x2014 + ' an introduced defect is unfinished work, not a followup. If this task surfaced real work outside the plan, return it in "followups" with a concrete receipt (a located fact) ' + [char]0x2014 + ' the console routes it with the user (do now / plan next / defer with a reason). No receipt, no followup.')
$lines.Add('')
$lines.Add("=== TASK ${n}: $title ===")
$lines.Add($body)
$prompt = [string]::Join("`n", $lines)

if ($ResultContract) {
    $schemaPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\templates\task-result.schema.json'))
    $contract = @(
        ''
        '=== RESULT ==='
        "End your reply with exactly one fenced ``````json block - the last fenced block in your reply - holding one JSON object that conforms to $schemaPath :"
        '- "status": required; exactly "DONE" or "BLOCKED".'
        '- "summary": required string; one or two lines: what changed.'
        '- "commitSha": string; the short SHA of the task commit. Include it only if you committed.'
        '- "note": string; exactly what is missing or needed. Include it only when "status" is "BLOCKED".'
        '- "followups": optional array; omit it or leave it empty unless this task surfaced real work outside the plan that you can tie to a concrete observed fact. Each item is an object with "description" (required; one line, as it would appear in BACKLOG.md), "receipt" (required; the observed fact, with a location), "strength" (required; "clear" or "ambiguous" - when unsure, "ambiguous"), "size" (optional; "S", "M" or "L") and "because" (optional; a deferral reason, only if the work genuinely must wait).'
        '- No other properties, at the top level or inside a followups item.'
        'A reply without that block, or whose block breaks these rules, is treated as BLOCKED.'
    )
    $prompt = $prompt + "`n" + [string]::Join("`n", $contract)
}

$stdout = [Console]::OpenStandardOutput()
$bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($prompt)
$stdout.Write($bytes, 0, $bytes.Length)
$stdout.Flush()
exit 0
