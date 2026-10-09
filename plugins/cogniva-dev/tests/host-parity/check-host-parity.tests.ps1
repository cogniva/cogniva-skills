# Dependency-free tests for scripts/check-host-parity.ps1 (no Pester): a clean
# fixture repo passes, and one mutation per rule fails with that rule's name.
# Fixtures live in temp directories and are removed in `finally`. PowerShell 7.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\..\..'))
$checker = Join-Path $repoRoot 'scripts\check-host-parity.ps1'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$dash = [string][char]0x2014
$failures = @()
$temps = @()

function Check($label, $condition) {
    if ($condition) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}
function Write-Text([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Text, $script:utf8NoBom)
}
function Edit-Text([string]$Path, [string]$Old, [string]$New) {
    $text = [System.IO.File]::ReadAllText($Path)
    if (-not $text.Contains($Old)) { throw "fixture edit anchor not found in ${Path}: $Old" }
    [System.IO.File]::WriteAllText($Path, $text.Replace($Old, $New), $script:utf8NoBom)
}

$rowInstall = "| install-dev | Install cogniva-dev | packaging | manifest:cogniva-dev | scripts-tested $dash manifest | scripts-tested $dash manifest | gate:suite-a | $dash |"
$rowAlpha   = "| alpha | Alpha skill | workflow | skill:cogniva-dev/alpha, mode:lean | verified $dash smoke run | untested | smoke:2026-10-01-claude-code-cli | $dash |"
$rowBeta    = "| beta | Beta skill | workflow | skill:cogniva-dev/beta | untested | unsupported $dash not offered | $dash | Codex: beta needs a runtime Codex lacks. |"
$rowGamma   = "| gamma | Gamma skill | workflow | skill:cogniva-skills/gamma | scripts-tested | scripts-tested | gate:suite-b | $dash |"
$rowHooks   = "| hooks | Edit guards | enforcement | hook:guard-one.js, hook:guard-two.js | scripts-tested | partial $dash patch edits unseen | gate:suite-a | Codex: patch payloads are not parsed; shell writes are unseen on both. |"

function New-Fixture {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-host-parity-" + [guid]::NewGuid().ToString('N'))
    $script:temps += $root
    Write-Text "$root\plugins\cogniva-dev\.claude-plugin\plugin.json" '{ "name": "cogniva-dev", "version": "0.10.0" }'
    Write-Text "$root\plugins\cogniva-dev\skills\alpha\SKILL.md" "---`nname: alpha`ndescription: Alpha.`n---`n`n# Alpha`n`nIn worktree mode read WORKTREE.md; finish with ``../beta/HANDOFF.md``.`n"
    Write-Text "$root\plugins\cogniva-dev\skills\alpha\WORKTREE.md" "# Alpha worktree overlay`n"
    Write-Text "$root\plugins\cogniva-dev\skills\beta\SKILL.md" "---`nname: beta`ndescription: Beta.`n---`n`n# Beta`n"
    Write-Text "$root\plugins\cogniva-dev\skills\beta\HANDOFF.md" "# Beta handoff`n"
    Write-Text "$root\plugins\cogniva-dev\hooks\hooks.json" "{ `"hooks`": { `"PreToolUse`": [ { `"matcher`": `"Edit`", `"hooks`": [ { `"type`": `"command`", `"command`": `"node \`"`${CLAUDE_PLUGIN_ROOT}/scripts/guard-one.js\`"`" }, { `"type`": `"command`", `"command`": `"node \`"`${CLAUDE_PLUGIN_ROOT}/scripts/guard-two.js\`"`" } ] } ] } }"
    Write-Text "$root\plugins\cogniva-skills\.claude-plugin\plugin.json" '{ "name": "cogniva-skills", "version": "0.8.0" }'
    Write-Text "$root\plugins\cogniva-skills\skills\gamma\SKILL.md" "---`nname: gamma`ndescription: Gamma.`n---`n`n# Gamma`n"
    Write-Text "$root\.claude\cogniva-dev\green-gate.json" '{ "commands": [ { "run": "echo a", "label": "suite-a" }, { "run": "echo b", "label": "suite-b" } ] }'
    $table = @(
        '| ID | Capability | Kind | Covers | Claude Code | Codex | Evidence | Notes |',
        '|---|---|---|---|---|---|---|---|',
        $rowInstall, $rowAlpha, $rowBeta, $rowGamma, $rowHooks
    ) -join "`r`n"
    Write-Text "$root\docs\host-parity.md" "# Agent host parity record`r`n`r`n## Status values`r`n`r`ntext`r`n`r`n## Capabilities`r`n`r`n$table`r`n`r`n## Intentional asymmetries`r`n`r`n- beta: Codex lacks the runtime.`r`n"
    Write-Text "$root\docs\host-parity\smoke\2026-10-01-claude-code-cli.md" (@(
        '# Smoke record 2026-10-01-claude-code-cli',
        'Agent host: Claude Code',
        'Agent host version: 2.1.187',
        'Surface: CLI',
        'OS: Windows 11 26200',
        'Plugin versions: cogniva-dev 0.10.0, cogniva-skills 0.8.0',
        'Plugin source: local marketplace from C:\dev\cogniva-skills @ 0c499d1',
        'Date: 2026-10-01',
        'Covers: alpha',
        '',
        '## Scenarios',
        '',
        '| Scenario | Result | Assertion output | Notes |',
        '|---|---|---|---|',
        "| QF-NONE | pass | OK | $dash |",
        '',
        '## Observations',
        '',
        '- none'
    ) -join "`r`n")
    return $root
}
function Invoke-Checker([string]$Root) {
    $lines = @(& pwsh -NoProfile -File $checker -Root $Root 2>&1)
    [pscustomobject]@{ Code = $LASTEXITCODE; Lines = @($lines | ForEach-Object { [string]$_ }) }
}
function Test-Mutation([string]$Label, [string]$Rule, [scriptblock]$Mutate) {
    $root = New-Fixture
    & $Mutate $root
    $r = Invoke-Checker $root
    $fails = @($r.Lines | Where-Object { $_ -like 'FAIL *' })
    Check "$Label -> FAIL $Rule" ($r.Code -eq 1 -and $fails.Count -eq 1 -and $fails[0] -like "FAIL ${Rule}: *")
    if (-not ($r.Code -eq 1 -and $fails.Count -eq 1)) { $r.Lines | ForEach-Object { Write-Host "        $_" } }
}

try {
    # --- clean fixture ---------------------------------------------------------
    $root = New-Fixture
    $r = Invoke-Checker $root
    Check 'clean fixture passes with the OK summary' ($r.Code -eq 0 -and ($r.Lines -contains 'host-parity: OK - 5 rows, 7 items covered'))
    if ($r.Code -ne 0) { $r.Lines | ForEach-Object { Write-Host "        $_" } }

    # --- one mutation per rule -------------------------------------------------
    Test-Mutation 'a new skill with no row' 'uncovered-skill' { param($root) Write-Text "$root\plugins\cogniva-dev\skills\delta\SKILL.md" "---`nname: delta`ndescription: Delta.`n---`n" }
    Test-Mutation 'a skill covered by two rows' 'duplicate-coverage' { param($root) Edit-Text "$root\docs\host-parity.md" $rowGamma ($rowGamma + "`r`n| gamma-again | Gamma again | workflow | skill:cogniva-skills/gamma | untested | untested | $dash | $dash |") }
    Test-Mutation 'a hook script with no row' 'uncovered-hook' { param($root) Edit-Text "$root\plugins\cogniva-dev\hooks\hooks.json" 'scripts/guard-two.js\"" }' ('scripts/guard-two.js\"" }, { "type": "command", "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/guard-three.js\"" }') }
    Test-Mutation 'a stale row (skill directory gone)' 'stale-item' { param($root) Edit-Text "$root\docs\host-parity.md" $rowGamma ($rowGamma + "`r`n| old | Old skill | workflow | skill:cogniva-dev/removed | untested | untested | $dash | $dash |") }
    Test-Mutation 'an unknown mode' 'stale-item' { param($root) Edit-Text "$root\docs\host-parity.md" 'mode:lean' 'mode:cloud' }
    Test-Mutation 'a bad status value' 'bad-status' { param($root) Edit-Text "$root\docs\host-parity.md" $rowGamma $rowGamma.Replace('| scripts-tested | scripts-tested |', '| works | scripts-tested |') }
    Test-Mutation 'verified with no smoke evidence' 'verified-no-smoke' { param($root) Edit-Text "$root\docs\host-parity.md" $rowGamma $rowGamma.Replace('| scripts-tested | scripts-tested |', '| scripts-tested | verified |') }
    Test-Mutation 'verified with a smoke record from the other agent host' 'smoke-host-mismatch' { param($root) Edit-Text "$root\docs\host-parity.md" $rowAlpha $rowAlpha.Replace('| untested |', '| verified |') }
    Test-Mutation 'verified with a smoke record that has a fail row' 'smoke-failed' { param($root) Edit-Text "$root\docs\host-parity\smoke\2026-10-01-claude-code-cli.md" "| QF-NONE | pass | OK | $dash |" "| QF-NONE | pass | OK | $dash |`r`n| EF-TWO | fail | 1 commit, expected 2 | $dash |" }
    Test-Mutation 'verified with a smoke record that does not cover the row' 'smoke-not-covering' { param($root) Edit-Text "$root\docs\host-parity\smoke\2026-10-01-claude-code-cli.md" 'Covers: alpha' 'Covers: gamma' }
    Test-Mutation 'a cited smoke record that does not exist' 'missing-smoke-record' { param($root) Edit-Text "$root\docs\host-parity.md" $rowBeta $rowBeta.Replace("| $dash | Codex:", '| smoke:2026-10-02-codex-cli | Codex:') }
    Test-Mutation 'scripts-tested citing an unknown gate label' 'unknown-gate-label' { param($root) Edit-Text "$root\docs\host-parity.md" $rowGamma $rowGamma.Replace('gate:suite-b', 'gate:suite-zzz') }
    Test-Mutation 'scripts-tested with no gate evidence' 'scripts-tested-no-gate' { param($root) Edit-Text "$root\docs\host-parity.md" $rowGamma $rowGamma.Replace('| scripts-tested | gate:suite-b |', "| untested | $dash |") }
    Test-Mutation 'unsupported with empty Notes' 'notes-required' { param($root) Edit-Text "$root\docs\host-parity.md" $rowBeta $rowBeta.Replace('| Codex: beta needs a runtime Codex lacks. |', "| $dash |") }
    Test-Mutation 'a skill names an overlay that does not exist' 'missing-overlay' { param($root) Remove-Item -LiteralPath "$root\plugins\cogniva-dev\skills\alpha\WORKTREE.md" }
    Test-Mutation 'Claude Code metadata without the Codex metadata' 'invocation-metadata' { param($root) Edit-Text "$root\plugins\cogniva-dev\skills\beta\SKILL.md" "description: Beta.`n" "description: Beta.`ndisable-model-invocation: true`n" }
    Test-Mutation 'Codex metadata without the Claude Code metadata' 'invocation-metadata' { param($root) Write-Text "$root\plugins\cogniva-skills\skills\gamma\agents\openai.yaml" "policy:`n  allow_implicit_invocation: false`n" }
    Test-Mutation 'Capabilities columns in the wrong order' 'table-format' { param($root) Edit-Text "$root\docs\host-parity.md" '| Claude Code | Codex |' '| Codex | Claude Code |' }

    # --- passing variants -------------------------------------------------------
    $root = New-Fixture
    Edit-Text "$root\plugins\cogniva-dev\skills\beta\SKILL.md" "description: Beta.`n" "description: Beta.`ndisable-model-invocation: true`n"
    Write-Text "$root\plugins\cogniva-dev\skills\beta\agents\openai.yaml" "policy:`n  allow_implicit_invocation: false`n"
    $r = Invoke-Checker $root
    Check 'metadata on both agent hosts passes' ($r.Code -eq 0)

    $root = New-Fixture
    Edit-Text "$root\docs\host-parity\smoke\2026-10-01-claude-code-cli.md" 'cogniva-dev 0.10.0' 'cogniva-dev 0.9.3'
    $r = Invoke-Checker $root
    Check 'stale evidence WARNs and still exits 0' ($r.Code -eq 0 -and ($r.Lines -contains 'WARN stale evidence: alpha Claude Code') -and ($r.Lines -contains 'host-parity: OK - 5 rows, 7 items covered'))

    $root = New-Fixture
    Edit-Text "$root\plugins\cogniva-dev\skills\alpha\SKILL.md" '# Alpha' "# Alpha`n`nSee skills/execute-feature/CODEX.md in the plugin docs."
    $r = Invoke-Checker $root
    Check 'a plugin-rooted path is not read as a sibling overlay' ($r.Code -eq 0)
}
finally {
    foreach ($t in $temps) { if (Test-Path -LiteralPath $t) { Remove-Item -LiteralPath $t -Recurse -Force } }
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED: $($failures.Count) assertion(s)."
    exit 1
}
Write-Host ""
Write-Host "All host-parity assertions passed."
exit 0
