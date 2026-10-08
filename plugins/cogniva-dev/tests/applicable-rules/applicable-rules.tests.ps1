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

    # Windows paths are case-insensitive: a case-variant spelling of the repo is still the repo.
    # (The Linux counterpart lives in the pwsh 7 architecture-profile suite.)
    $variantJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target (Join-Path $root.ToUpperInvariant() 'docs\readme.md') -Purpose 'documentation' -Format Json
    $variantExitCode = $LASTEXITCODE
    Check 'a case-variant spelling of the repo path is inside the repo on Windows' ($variantExitCode -eq 0 -and ($variantJson | ConvertFrom-Json).Targets[0].Target -match '^docs[\\/]readme\.md$')

    # --- architecture profile (reported alongside, never changes an undeclared repo's decision) ---
    Check 'undeclared repo reports an UNDECLARED architecture profile' ($report.Targets[0].ArchitectureProfile.Status -eq 'UNDECLARED' -and $null -eq $report.Targets[0].ArchitectureProfile.Profile)
    $plain = (& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'docs/readme.md' -Purpose 'documentation' -Format Json) | ConvertFrom-Json
    Check 'undeclared profile adds no review reason' ($plain.Targets[0].Decision -eq 'SAFE_TO_PROCEED' -and $plain.Targets[0].ArchitectureProfile.Status -eq 'UNDECLARED')

    New-Item -ItemType Directory -Path (Join-Path $root '.cogniva\profiles\fixture') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root '.cogniva\profiles\fixture\profile.yml') -Encoding ASCII -Value 'description: Fixture profile.'
    Set-Content -LiteralPath (Join-Path $root '.cogniva-profile.yml') -Encoding ASCII -Value 'profile: fixture'
    $declared = (& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'docs/readme.md' -Purpose 'documentation' -Format Json) | ConvertFrom-Json
    Check 'declared profile is reported with where it came from' ($declared.Targets[0].ArchitectureProfile.Status -eq 'RESOLVED' -and $declared.Targets[0].ArchitectureProfile.Profile -eq 'fixture' -and $declared.Targets[0].ArchitectureProfile.Kind -eq 'repo-default' -and $declared.Targets[0].ArchitectureProfile.Source -eq '.cogniva-profile.yml')
    Check 'a resolved profile does not change the decision' ($declared.Targets[0].Decision -eq 'SAFE_TO_PROCEED')
    $declaredText = (& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'docs/readme.md' -Purpose 'documentation') -join "`n"
    Check 'text output names the architecture profile' ($declaredText -match 'ARCHITECTURE PROFILE: fixture \(repo-default: \.cogniva-profile\.yml\)')

    Set-Content -LiteralPath (Join-Path $root '.cogniva-profile.yml') -Encoding ASCII -Value 'profile: missing'
    $brokenJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'docs/readme.md' -Purpose 'documentation' -Format Json
    $brokenExitCode = $LASTEXITCODE
    $broken = $brokenJson | ConvertFrom-Json
    Check 'an unresolvable profile requires review instead of crashing' ($brokenExitCode -eq 0 -and $broken.Targets[0].ArchitectureProfile.Status -eq 'ERROR' -and $broken.Targets[0].Decision -eq 'REVIEW_REQUIRED' -and ($broken.Targets[0].ReviewReasons -join ' ') -match 'Architecture profile could not be resolved')

    Set-Content -LiteralPath (Join-Path $root '.cogniva-profile.yml') -Encoding ASCII -Value 'profile: fixture'
    New-Item -ItemType Directory -Path (Join-Path $root 'broken') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root 'broken\.cogniva-profile.yml') -Encoding ASCII -Value 'profile: absent'
    $splitJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'docs/readme.md,broken/thing.md' -Purpose 'documentation' -Format Json
    $split = $splitJson | ConvertFrom-Json
    Check 'a profile error affects only its own target' ($split.Targets[0].ArchitectureProfile.Status -eq 'RESOLVED' -and $split.Targets[0].Decision -eq 'SAFE_TO_PROCEED' -and $split.Targets[1].ArchitectureProfile.Status -eq 'ERROR' -and $split.Targets[1].Decision -eq 'REVIEW_REQUIRED' -and ($split.Targets[1].ReviewReasons -join ' ') -match "profile 'absent'")

    $savedPath = $env:PATH
    try {
        $env:PATH = (($env:PATH -split ';') | Where-Object { $_ -and -not (Test-Path -LiteralPath (Join-Path $_ 'pwsh.exe')) }) -join ';'
        $noPwsh = (& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $root -Target 'docs/readme.md' -Purpose 'documentation' -Format Json) | ConvertFrom-Json
    }
    finally { $env:PATH = $savedPath }
    Check 'without pwsh the profile is UNAVAILABLE and the decision is unchanged' ($noPwsh.Targets[0].ArchitectureProfile.Status -eq 'UNAVAILABLE' -and $noPwsh.Targets[0].Decision -eq 'SAFE_TO_PROCEED')

    # --- profile-driven placement (needs pwsh to adopt the shipped dotnet profile) ---
    $pwshCmd = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pwshCmd) { Write-Host '  SKIP  profile-driven placement (PowerShell 7 not installed)' }
    else {
        $prof = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-applicable-profile-" + [guid]::NewGuid().ToString('N'))
        try {
            function Write-Text([string]$Relative, [string]$Text) {
                $path = Join-Path $prof $Relative
                New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
                [System.IO.File]::WriteAllText($path, $Text.Replace("`r`n", "`n"))
            }
            function Invoke-Preflight([string]$Targets, [string]$Purpose) {
                return ((& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $prof -Target $Targets -Purpose $Purpose -Format Json) | ConvertFrom-Json)
            }
            New-Item -ItemType Directory -Path $prof -Force | Out-Null
            & git -C $prof init -q
            & $pwshCmd.Source -NoProfile -File (Join-Path $plugin 'scripts\adopt-architecture-profile.ps1') -Repo $prof -Profile dotnet | Out-Null
            Write-Text '.cogniva-profile.yml' "profile: dotnet`n"
            Write-Text 'src/Hosts/Web/Program.cs' "// host`n"
            Write-Text 'src/Lib/Foo.cs' "// lib`n"
            Write-Text 'src/Modules/Orders/Orders.Contracts/IOrders.cs' "// contracts`n"
            Write-Text 'src/Hosts/Old/.cogniva-profile.yml' "profile: none`n"

            $p = Invoke-Preflight 'src/Hosts/Web/Program.cs,src/Lib/Foo.cs,src/Modules/Orders/Orders.Contracts/IOrders.cs,src/Hosts/Old/x.cs' 'wiring'
            Check 'dotnet: a host gets the composition-root message only' (@($p.Targets[0].Conflicts).Count -eq 1 -and ($p.Targets[0].Conflicts -join ' ') -match 'composition-roots\.md' -and $p.Targets[0].Decision -eq 'SAFE_TO_PROCEED' -and @($p.Targets[0].MatchedStandards.Id) -contains 'architecture/composition-roots.md')
            Check 'dotnet: an ordinary library gets no placement message' (@($p.Targets[1].Conflicts).Count -eq 0)
            Check 'dotnet: a Contracts folder gets no message without a repo applies-to' (@($p.Targets[2].Conflicts).Count -eq 0)
            Check "'profile: none' gets no placement message even under Hosts" (@($p.Targets[3].Conflicts).Count -eq 0 -and $p.Targets[3].ArchitectureProfile.Status -eq 'NONE')
            $p = Invoke-Preflight 'src/Hosts/Web/Program.cs' 'domain behavior'
            Check 'dotnet: domain behaviour in a host is still a CONFLICT' ($p.Targets[0].Decision -eq 'REVIEW_REQUIRED' -and ($p.Targets[0].Conflicts -join ' ') -match 'CONFLICT:')

            Write-Text '.cogniva/profiles/acme/profile.yml' "description: Acme.`ninherits: dotnet`n"
            Write-Text '.cogniva/profiles/acme/amendments/architecture/common-and-published-types.md' "---`ndescription: Acme's published types are each Module's Contracts project.`napplies-to:`n  - `"src/Modules/*/*.Contracts/**`"`n---`n`n- Contracts projects publish types.`n"
            Write-Text '.cogniva-profile.yml' "profile: acme`n"
            Write-Text 'src/Hosts/Old/.cogniva-profile.yml' "profile: acme`n"
            & $pwshCmd.Source -NoProfile -File (Join-Path $plugin 'scripts\accept-profile-delta.ps1') -Repo $prof -Profile acme -All | Out-Null
            $p = Invoke-Preflight 'src/Modules/Orders/Orders.Contracts/IOrders.cs,src/Hosts/Web/Program.cs' 'interfaces'
            Check 'a repo applies-to on published types gives the published-surface message' (($p.Targets[0].Conflicts -join ' ') -match 'common-and-published-types\.md' -and $p.Targets[0].Decision -eq 'SAFE_TO_PROCEED')
            Check 'the same repo still gives the composition-root message on a host' (($p.Targets[1].Conflicts -join ' ') -match 'composition-roots\.md')
            $p = Invoke-Preflight 'src/Modules/Orders/Orders.Contracts/IOrders.cs' 'persistence implementation'
            Check 'implementation in a published surface is a CONFLICT' ($p.Targets[0].Decision -eq 'REVIEW_REQUIRED')

            Write-Text '.cogniva/profiles/acme/amendments/architecture/composition-roots.md' "---`ndescription: Acme host note.`nbasis: aaaaaaaaaaaa`n---`n`n- Acme hosts.`n"
            $p = Invoke-Preflight 'src/Hosts/Web/Program.cs,src/Lib/Foo.cs' 'wiring'
            Check 'a stale delta on a matched standard requires review' ($p.Targets[0].Decision -eq 'REVIEW_REQUIRED' -and ($p.Targets[0].ReviewReasons -join ' ') -match 'architecture/composition-roots\.md needs human review')
            Check 'a stale delta on an unmatched standard is only a REVIEW note' ($p.Targets[1].Decision -eq 'SAFE_TO_PROCEED' -and ($p.Targets[1].ReviewNotes -join ' ') -match 'architecture/composition-roots\.md needs human review')
            $text = (& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $prof -Target 'src/Lib/Foo.cs' -Purpose 'wiring') -join "`n"
            Check 'text output prints REVIEW: notes and leaves DECISION unchanged' ($text -match 'REVIEW: Standard architecture/composition-roots\.md' -and $text -match 'DECISION: SAFE_TO_PROCEED')
            $text = (& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $prof -Target 'src/Hosts/Web/Program.cs' -Purpose 'wiring') -join "`n"
            Check 'text output prints STANDARD: lines for matched standards' ($text -match 'STANDARD: architecture/composition-roots\.md - ')
        }
        finally { if (Test-Path -LiteralPath $prof) { Remove-Item -LiteralPath $prof -Recurse -Force } }
    }
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { exit 1 }
Write-Host 'All applicable-rules assertions passed.'
