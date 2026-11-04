#Requires -Version 7.0
# Validates a task agent's reply against the shared result contract
# (templates/task-result.schema.json). Used by the sequential executor in
# skills/execute-feature/CODEX.md; the Workflow runtime enforces the same
# schema itself.
# Takes the LAST closed fenced json block in -ReplyFile, parses it, and checks
# it against the schema file: type, enum, required, properties,
# additionalProperties false, and array items - the keywords that file uses.
# No external modules.
# Exit 0 + the normalised JSON (one line) on stdout when valid.
# Exit 1 + "MALFORMED: <reason>" on stdout when there is no closed json block,
#   the block is not valid JSON, or it breaks the schema.
# Exit 2 on a usage error (reply file or schema file missing).
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ReplyFile,
    [string]$SchemaPath
)
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) { [Console]::Error.WriteLine("test-task-result: $Message"); exit 2 }
function Malformed([string]$Reason) { [Console]::Out.WriteLine("MALFORMED: $Reason"); exit 1 }

if (-not $SchemaPath) { $SchemaPath = Join-Path $PSScriptRoot '..\templates\task-result.schema.json' }
if (-not (Test-Path -LiteralPath $ReplyFile -PathType Leaf)) { Fail "reply file not found: $ReplyFile" }
if (-not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) { Fail "schema file not found: $SchemaPath" }

$utf8 = [System.Text.UTF8Encoding]::new($false)
$reply = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $ReplyFile).ProviderPath, $utf8).TrimStart([char]0xFEFF)
$schema = [System.Text.Json.JsonDocument]::Parse([System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $SchemaPath).ProviderPath, $utf8).TrimStart([char]0xFEFF)).RootElement

# The last CLOSED fenced block whose opening fence is ```json (any case).
$blocks = [System.Collections.Generic.List[string]]::new()
$current = $null
foreach ($line in ($reply -split "\r?\n")) {
    if ($null -eq $current) {
        if ($line -match '^\s*```\s*json\s*$') { $current = [System.Collections.Generic.List[string]]::new() }
    }
    elseif ($line -match '^\s*```\s*$') { $blocks.Add([string]::Join("`n", $current)); $current = $null }
    else { $current.Add($line) }
}
if ($blocks.Count -eq 0) { Malformed 'no fenced ```json block in the reply' }
$text = $blocks[$blocks.Count - 1]

try { $doc = [System.Text.Json.JsonDocument]::Parse($text) }
catch { Malformed "the last json block is not valid JSON ($($_.Exception.InnerException.Message ?? $_.Exception.Message))" }

function Get-Prop($Element, [string]$Name) {
    $value = [System.Text.Json.JsonElement]::new()
    if ($Element.ValueKind -eq 'Object' -and $Element.TryGetProperty($Name, [ref]$value)) { return , $value }
    return $null
}
function Test-Node($Value, $Rule, [string]$Where) {
    $type = Get-Prop $Rule 'type'
    if ($null -ne $type) {
        $expected = $type.GetString()
        $actual = switch ($Value.ValueKind) { 'Object' { 'object' } 'Array' { 'array' } 'String' { 'string' } 'Number' { 'number' } 'True' { 'boolean' } 'False' { 'boolean' } default { 'null' } }
        if ($actual -ne $expected) { Malformed "$Where must be a $expected, not a $actual" }
    }
    $enum = Get-Prop $Rule 'enum'
    if ($null -ne $enum) {
        $allowed = @($enum.EnumerateArray() | ForEach-Object { $_.GetRawText() })
        if ($allowed -notcontains $Value.GetRawText()) { Malformed "$Where is $($Value.GetRawText()); allowed: $($allowed -join ', ')" }
    }
    if ($Value.ValueKind -eq 'Object') {
        $properties = Get-Prop $Rule 'properties'
        $required = Get-Prop $Rule 'required'
        if ($null -ne $required) {
            foreach ($name in $required.EnumerateArray()) {
                if ($null -eq (Get-Prop $Value $name.GetString())) { Malformed "$Where is missing required property '$($name.GetString())'" }
            }
        }
        $additional = Get-Prop $Rule 'additionalProperties'
        foreach ($property in $Value.EnumerateObject()) {
            $propertyRule = if ($null -ne $properties) { Get-Prop $properties $property.Name } else { $null }
            if ($null -eq $propertyRule) {
                if ($null -ne $additional -and $additional.ValueKind -eq 'False') { Malformed "$Where has a property the contract does not allow: '$($property.Name)'" }
                continue
            }
            Test-Node $property.Value $propertyRule "$Where.$($property.Name)"
        }
    }
    if ($Value.ValueKind -eq 'Array') {
        $items = Get-Prop $Rule 'items'
        if ($null -ne $items) {
            $index = 0
            foreach ($item in $Value.EnumerateArray()) { Test-Node $item $items "$Where[$index]"; $index++ }
        }
    }
}

Test-Node $doc.RootElement $schema 'result'

$options = [System.Text.Json.JsonSerializerOptions]::new()
$options.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
$normalised = [System.Text.Json.JsonSerializer]::Serialize($doc.RootElement, $options)
$stdout = [Console]::OpenStandardOutput()
$bytes = $utf8.GetBytes($normalised + "`n")
$stdout.Write($bytes, 0, $bytes.Length)
$stdout.Flush()
exit 0
