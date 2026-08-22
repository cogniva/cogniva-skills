# Dependency-free evidence that applicable-rules is AGENTS-aware and leaves the
# checked repository unchanged.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$resolver = Join-Path $plugin 'scripts\resolve-applicable-rules.ps1'
$obligations = Join-Path $plugin 'scripts\resolve-workflow-obligations.ps1'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-applicable-rules-" + [guid]::NewGuid().ToString('N'))
$failures = @()

function Check($label, $condition) {
    if ($condition) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}

try {
    New-Item -ItemType Directory -Path (Join-Path $root 'src\Hosts\Sample') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Encoding UTF8 -Value "# Rules`n`n## Architecture`n`n- Hosts are composition roots only.`n`n## Cogniva-dev workflow instructions`n`n### before-integrate`n`n- AGENTS obligation"
    Set-Content -LiteralPath (Join-Path $root 'CLAUDE.md') -Encoding UTF8 -Value "# Architecture`n`n- Dependencies must respect Module ownership.`n`n## Cogniva-dev workflow instructions`n`n### before-planning`n`n- CLAUDE fallback planning obligation"
    $nestedAgents = Join-Path $root 'src\Hosts\AGENTS.md'
    Set-Content -LiteralPath $nestedAgents -Encoding UTF8 -Value "# Host subtree rules`n`n- Host wiring diagnostics are required here."
    & git -C $root init -q
    $before = @(& git -C $root status --porcelain)
    $json = & powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'src/Hosts/Sample/NewService.cs' -Purpose 'domain behavior' -Format Json
    $exitCode = $LASTEXITCODE
    $after = @(& git -C $root status --porcelain)
    $report = $json | ConvertFrom-Json
    $phaseJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $obligations -Repo $root -Phase 'before-planning' -Format Json
    $phaseExitCode = $LASTEXITCODE
    $phase = $phaseJson | ConvertFrom-Json

    Set-Content -LiteralPath $nestedAgents -Encoding UTF8 -Value "# Conflicting host rule`n`n- Hosts may contain domain behavior."
    $conflictJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'src/Hosts/Sample/NewService.cs' -Purpose 'wiring' -Format Json
    $conflictExitCode = $LASTEXITCODE
    $conflictReport = $conflictJson | ConvertFrom-Json
    Set-Content -LiteralPath $nestedAgents -Encoding UTF8 -Value "# Host subtree rules`n`n- Host wiring diagnostics are required here."

    Check 'resolver succeeds' ($exitCode -eq 0)
    Check 'resolver discovers root and nested AGENTS.md files' ($report.Targets[0].Agents.Count -eq 2 -and $report.Targets[0].Agents[0] -match 'AGENTS\.md$' -and $report.Targets[0].Agents[1] -match 'src[\\/]Hosts[\\/]AGENTS\.md$')
    Check 'resolver reports effective authority order and nested precedence' ($report.Targets[0].EffectiveAuthority.Count -eq 3 -and $report.Targets[0].EffectiveAuthority[1].Source -eq 'AGENTS.md' -and $report.Targets[0].EffectiveAuthority[1].Path -match 'src[\\/]Hosts[\\/]AGENTS\.md$')
    Check 'resolver retains substantive CLAUDE.md authority' ($report.Targets[0].Claude.Count -eq 1 -and $report.Targets[0].Constraints.File -match 'CLAUDE\.md$')
    Check 'resolver exposes a Host placement conflict' ($report.Targets[0].Conflicts -match 'CONFLICT:')
    Check 'phase resolution falls back to CLAUDE.md when AGENTS lacks the phase' ($phaseExitCode -eq 0 -and $phase.Source -eq 'CLAUDE.md (fallback)' -and $phase.Lines -match 'CLAUDE fallback planning obligation')
    Check 'conflicting authority produces REVIEW_REQUIRED' ($conflictExitCode -eq 0 -and $conflictReport.Targets[0].Decision -eq 'REVIEW_REQUIRED' -and -not $conflictReport.Targets[0].CanProceedAutomatically -and $conflictReport.Targets[0].ReviewReasons.Count -gt 0)
    Check 'resolver leaves repository status unchanged' (($before -join "`n") -eq ($after -join "`n"))
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { exit 1 }
Write-Host 'All applicable-rules assertions passed.'
