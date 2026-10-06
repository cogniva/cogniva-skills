# Dependency-free regression test for the commit-policy / Codex semantics of the
# lifecycle skills (no Pester). Skills are prose contracts, so these assertions
# pin the textual invariants that past reviews found drifting: `commits=` as the
# sole commit authority, the commits=final commit AFTER the green gate, the
# planless Codex quick-fix contract, and the Codex CLAUDE.md-inheritance rule.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))

function ReadDoc($rel) {
    $p = Join-Path $plugin $rel
    if (-not (Test-Path $p)) { throw "missing file: $p" }
    return [System.IO.File]::ReadAllText($p, [System.Text.UTF8Encoding]::new($false))
}

$ef      = ReadDoc 'skills\execute-feature\SKILL.md'
$codex   = ReadDoc 'skills\execute-feature\CODEX.md'
$handoff = ReadDoc 'skills\execute-feature\HANDOFF.md'
$qf      = ReadDoc 'skills\quick-fix\SKILL.md'
$pf      = ReadDoc 'skills\plan-feature\SKILL.md'
$docs    = ReadDoc 'docs\codex.md'
$bk      = ReadDoc 'skills\backlog\SKILL.md'
$cb      = ReadDoc 'skills\backlog\CAPTURE-BAR.md'
$ar      = ReadDoc 'skills\applicable-rules\SKILL.md'
$fc      = ReadDoc 'skills\feature-check\SKILL.md'
$gc      = ReadDoc 'skills\gate-check\SKILL.md'
$am = ReadDoc 'skills\add-module\SKILL.md'
$ri      = ReadDoc 'skills\repo-init\SKILL.md'

$failures = @()
function Check($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}

# --- commits= is the sole commit authority (execute-feature) ---------------
Check 'execute-feature declares commits= the sole commit authority' `
    ($ef -match 'SOLE authority over committing')
Check 'Step 0a pasted-plan commit is gated on commits=task' `
    ($ef -match 'Commit it only under `commits=task`')
Check 'Step 1 converted-plan commit is gated on commits=task' `
    ($ef -match 'Commit the converted file only under `commits=task`')
Check 'do-now commits are commits=task only' `
    ($ef -match 'one commit per confirmed do-now under\s+`commits=task` ONLY')
Check 'repo-obligation output commits under commits=task only' `
    ($ef -match 'commit\s+what it produces under `commits=task` only')
Check 'diff --check fixes stay in the tree under none|final' `
    ($ef -match 'under `none\|final` it stays in the tree')
Check 'no unconditional final commit inside tree-consistency (old Step 4.1 wording gone)' `
    ($ef -notmatch 'this is where the ONE implementation\s+commit happens')

# --- commits=final ordering: green gate BEFORE the one commit --------------
# (substring anchors are ASCII-only: PS 5.1 parses this file as ANSI without a BOM)
$iGreen  = $ef.IndexOf('**Green gate**')
$iFinal  = $ef.IndexOf('**The `commits=final` commit**')
$iHand   = $ef.IndexOf('the handoff.**')
Check 'Step 4 order: green gate -> commits=final commit -> handoff' `
    ($iGreen -ge 0 -and $iFinal -gt $iGreen -and $iHand -gt $iFinal)

# --- tasks=one single-slice mode --------------------------------------------
Check 'execute-feature defines tasks=one' ($ef -match '`tasks=one`')
Check 'handoff wording covers a completed slice, not only a whole feature' `
    ($handoff -match 'executed scope is complete on this branch')

# --- Codex backend: planless quick-fix contract ------------------------------
Check 'CODEX.md states quick-fix tasks are planless (no planPath)' `
    ($codex -match 'PLANLESS tasks')
Check 'CODEX.md lands quick-fix at its own Step 2, not execute-feature Step 4' `
    ($codex -match 'quick-fix[\s\S]{0,12}its own Step 2')
Check 'CODEX.md executor skips ticking when a task has no planPath' `
    ($codex -match 'no `planPath`.*nothing to tick|task with no `planPath`[\s\S]{0,80}nothing to tick')
Check 'quick-fix names its own Step 2 as the post-loop landing' `
    ($qf -match 'lands at Step 2 BELOW')

# --- Codex CLAUDE.md inheritance rule ----------------------------------------
Check 'CODEX.md carries the Repository CLAUDE.md inheritance rule' `
    ($codex -match '## Repository CLAUDE\.md under Codex')
Check 'docs/codex.md carries the inheritance rule too' `
    ($docs -match '## Repository CLAUDE\.md under Codex')
Check 'inheritance rule: CLAUDE.md never overrides commits=' `
    ($codex -match 'ever overrides `commits=`')

# --- explicit invocation + plan-feature default -------------------------------
Check 'docs/codex.md: lifecycle skills are explicit-invocation-only' `
    ($docs -match '## Lifecycle skills are explicit-invocation-only under Codex')
Check 'plan-feature lean default leaves the plan uncommitted' `
    ($pf -match 'Lean mode default: `commits=none`')

# --- route-first capture invariants ------------------------------------------
Check 'introduced defects are unfinished work, not followups' `
    ($ef -match 'A defect a task introduced is not a\s+followup')
Check 'skill-initiated deferrals always carry because:' `
    ($bk -match 'A skill-initiated deferral always carries its `because:`')
Check 'direct human capture falls back to because:human later' `
    ($bk -match 'no stated reason is written with\s+`because:human later`')
Check 'Plan-next proposals never auto-run' `
    ($cb -match 'Never auto-run it and never write anything for it')

# --- composable workflow-neutral guardrails ---------------------------------
Check 'applicable-rules delegates discovery to the canonical resolver' `
    ($ar -match 'resolve-applicable-rules\.ps1')
Check 'feature-check delegates preflight to applicable-rules' `
    ($fc -match 'Delegate to `applicable-rules`')
Check 'feature-check delegates readiness mechanics to gate-check' `
    ($fc -match 'delegate mechanical validation to `gate-check`')
Check 'gate-check delegates mechanics to the canonical runner' `
    ($gc -match 'run-gate-check\.ps1')
Check 'applicable-rules blocks automatic conclusions on REVIEW_REQUIRED' `
    ($ar -match 'Decision` is `REVIEW_REQUIRED`')
Check 'heavyweight lifecycle skills consume the shared phase resolver' `
    ($ef -match 'resolve-workflow-obligations\.ps1' -and $qf -match 'resolve-workflow-obligations\.ps1' -and $pf -match 'resolve-workflow-obligations\.ps1')
Check 'workflow-neutral skills contain no git lifecycle command' `
    ((($ar + $fc + $gc) -notmatch '(?im)^\s*git\s+(add|commit|merge|push|switch|checkout|branch|worktree)\b'))
Check 'heavyweight execute-feature consumes the shared green-gate runner' `
    ($ef -match 'run-green-gate\.ps1')
Check 'heavyweight quick-fix consumes the shared green-gate runner' `
    ($qf -match 'run-green-gate\.ps1')
Check 'heavyweight defaults remain lean and non-committing under Codex' `
    ($ef -match 'Defaults:\*\* lean mode .+`commits=none`')

# --- architecture profiles ----------------------------------------------------
$pfFlat = $pf -replace '\s+', ' '
$fmt    = ReadDoc 'skills\plan-feature\PLAN-FORMAT.md'
Check 'plan-feature resolves the architecture profile through the shared resolver' `
    ($pf -match 'resolve-architecture-profile\.ps1')
Check 'plan-feature never adopts or declares a profile on its own' `
    ($pfFlat -match 'Adopting or declaring a profile writes files, so do it only when the user asks')
Check 'plan-feature restates standards in task bodies' `
    ($pfFlat -match 'the executing agent never sees the profile')
Check 'plan-feature reads composed standards with -Show' `
    ($pfFlat -match 'AMENDED BY' -and $pfFlat -match '-Show <id>')
Check 'plan-feature asks before designing on standards that need review' `
    ($pfFlat -match 'NEEDS HUMAN REVIEW' -and $pfFlat -match 'ask before designing on those standards')
Check 'PLAN-FORMAT carries the Architecture profile header line' `
    ($fmt -match '\*\*Architecture profile:\*\*')
Check 'applicable-rules documents the ArchitectureProfile field' `
    ($ar -match 'ArchitectureProfile')
Check 'applicable-rules: REVIEW: lines are informational, REVIEW_REQUIRED stops' `
    ($ar -match '`REVIEW:` lines are informational' -and $ar -match 'Decision` is `REVIEW_REQUIRED`')
Check 'applicable-rules: placement checks come from the resolved profile' `
    ($ar -match 'applies-to')
Check 'PLAN-FORMAT header defers committing to the commits= policy' `
    ($fmt -notmatch 'tasks commit on the branch they are already on' -and ($fmt -replace '\s+', ' ') -match 'commit step applies only when the run''s .commits=. policy commits')

# --- repo-init scaffolds the dotnet skeleton -----------------------------------
Check 'repo-init no longer calls add-module' ($ri -notmatch 'add-module')
Check 'repo-init scaffolds no src/Modules' ($ri -notmatch 'src/Modules')
Check 'repo-init carries no literal net8.0' ($ri -notmatch 'net8\.0')
Check 'repo-init drops docs/superpowers' ($ri -notmatch 'superpowers')
Check 'repo-init checks the SDK before writing' ($ri -match 'dotnet --list-sdks')
Check 'repo-init checks the newest SDK can write .slnx' ($ri -match '9\.0\.200' -and $ri -match 'newest listed SDK')
Check 'repo-init asks for .slnx explicitly' ($ri -match 'dotnet new sln -n <Repo> --format slnx')
Check 'repo-init adopts and declares dotnet' ($ri -match 'adopt-architecture-profile\.ps1' -and $ri -match 'profile: dotnet')
Check 'repo-init gates with -Require like other architecture-dependent skills' ($ri -match '-Require')
Check 'repo-init template files exist' ((@('templates\repo\AGENTS.md', 'templates\repo\CLAUDE.md', 'templates\repo\Directory.Build.props', 'templates\repo\docs\glossary\README.md') | Where-Object { -not (Test-Path (Join-Path $plugin $_)) }).Count -eq 0)

# --- add-module is the Module bundle layout scaffolder -------------------------
Check 'add-module keeps the undeclared steps' ($am -match 'undeclared' -and $am -match 'dotnet new classlib -n <M>\.Contracts')
Check 'add-module reads the effective layout with -Show' ($am -match '-Show dotnet/project-layout\.md')
Check 'add-module gates a declared repo with -Require on its dependency set' ($am -match '-Require' -and $am -match 'dotnet/projects-and-references\.md' -and $am -match 'architecture/common-and-published-types\.md')
Check 'add-module stops on exit 3' ($am -match 'Exit 3')
Check 'add-module stops in a repo without a Modules kind' ($am -match 'does not use the Module bundle layout')
Check 'add-module stops on none or error' ($am -match 'PROFILE: none')
Check 'add-module scaffolds only the selected projects in a declared repo' ($am -match 'selected projects only' -and $am -match 'Application was chosen')

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED: $($failures.Count) assertion(s)."
    exit 1
}
Write-Host ""
Write-Host "All skill-semantics assertions passed."
exit 0
