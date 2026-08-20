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

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED: $($failures.Count) assertion(s)."
    exit 1
}
Write-Host ""
Write-Host "All skill-semantics assertions passed."
exit 0
