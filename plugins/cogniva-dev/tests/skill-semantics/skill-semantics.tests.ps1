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
Check 'docs/codex.md: explicit-only lifecycle skills carry metadata on both agent hosts' `
    ($docs -match '## Explicit-only lifecycle skills' -and $docs -match 'disable-model-invocation: true' -and $docs -match 'allow_implicit_invocation: false' -and $docs -notmatch 'explicit-invocation-only under Codex')
Check 'quick-fix description states its explicit-start rule' `
    ($qf -match 'Starts only on an explicit user request or an approved dispatch from easy-work-scan/groom-backlog')
Check 'plan-feature description states its explicit-start rule' `
    ($pf -match 'Starts only on an explicit user request or an approved dispatch from easy-work-scan/groom-backlog')
Check 'plan-feature lean default leaves the plan uncommitted' `
    ($pf -match 'Lean mode default: `commits=none`')

# --- docs/codex.md: the parity record and hooks under Codex --------------------
$docsFlat = $docs -replace '\s+', ' '
Check 'docs/codex.md no longer claims runtime verification' `
    ($docs -notmatch 'Verified against OpenAI' -and $docsFlat -match 'runtime behaviour per agent host is tracked in the cogniva-skills repo''s `docs/host-parity\.md`')
Check 'docs/codex.md: hooks under Codex need trust and read apply_patch edits' `
    ($docs -match '## Hooks under Codex' -and $docsFlat -match 'only after you trust it in `/hooks`' -and $docsFlat -match 'reads its input through `scripts/hook-input\.js`' -and $docsFlat -notmatch 'do not see edits Codex makes with `apply_patch`' -and $docsFlat -match 'best-effort on both agent hosts')
Check 'docs/codex.md: Codex hooks need trust again after every update' `
    ($docsFlat -match 'Re-trust after every cogniva-dev update')
Check 'docs/codex.md: shell writes are unseen; guarantees live in the landing checks' `
    ($docsFlat -match 'not seen by the edit guard' -and $docsFlat -match 'guarantees live in the landing checks')
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

# --- quick-fix structural checks ----------------------------------------------
$qfFlat    = $qf -replace '\s+', ' '
$wtQfFlat  = (ReadDoc 'skills\quick-fix\WORKTREE.md') -replace '\s+', ' '
$codexFlat = $codex -replace '\s+', ' '
$tpl       = ReadDoc 'templates\execute-feature.workflow.js'
Check 'quick-fix records START_TREE with the snapshot at Step 0' ($qf -match 'check-structural-changes\.ps1" -Repo "<WORKSPACE>" -Snapshot' -and $qf -match 'START_TREE: <sha>')
Check 'quick-fix: work already dirty is part of the start state' ($qfFlat -match 'none of that is attributed to this fix')
Check 'quick-fix: an ordinary fix makes no profile call and adds nothing to tasks' ($qfFlat -match 'Otherwise skip this step: no profile call, nothing added to tasks')
Check 'quick-fix: no valid START_TREE stops before dispatch' ($qfFlat -match 'Any other result \(a non-zero exit, or no `START_TREE:` line\) . stop before dispatching' -and $qfFlat -match 'without a valid `START_TREE` the structural check cannot run')
Check 'quick-fix preflights each expected item with its own kind and paths, and stops on exit 3' ($qf -match '-Target "<that item''s paths>" -Kinds "<that item''s kind>"' -and $qfFlat -match 'Never pass one item''s kind against another item''s paths' -and $qfFlat -match 'Exit 3 . stop before dispatching')
Check 'quick-fix reads landing requirements by profile, not by path' ($qf -match '-Target \. -Profile <the profile on that REQUIRES line> -Show' -and $qfFlat -match 'a path the fix deleted no longer resolves')
Check 'quick-fix: a profile-changed fact always needs the user''s OK' ($qfFlat -match 'A `profile-changed` fact is always `UNEXPECTED`')
Check 'quick-fix: expectations name paths as well as kinds' ($qf -match '<kind>:<path>\[\|<path>\.\.\.\]' -and $qfFlat -match 'A structural change outside the folders you name counts as unexpected at landing')
Check 'quick-fix: each profile''s own standards are printed from its REQUIRE FOR line' ($qfFlat -match 'For each `REQUIRE FOR <target> \(<profile>\): <ids>` line that lists standards')
Check 'quick-fix: a usage error never dispatches and never lands' ($qfFlat -match 'Exit 2 . the command is wrong: fix it and re-run; never dispatch on it' -and $qfFlat -match 'never treat it as no structural changes')
Check 'quick-fix: a missing standard is fixed in the profile, a stale one is reviewed and accepted' ($qfFlat -match 'adds the standard or corrects the `structure-requires` pair' -and $qfFlat -match 'reviews (that|the) standard and runs `accept-profile-delta\.ps1`')
Check 'quick-fix gives the full standards text only to tasks that make the change' ($qf -match '### Architecture standards for this task' -and $qfFlat -match 'Put the `-Show` output VERBATIM' -and $qfFlat -match 'Tasks that do not make the change get none of it')
Check 'quick-fix workers stop on a structural change they were not asked for' ($qfFlat -match 'and this task does not ask for it, stop and return BLOCKED')
$iObl    = $qf.IndexOf('### before-integrate')
$iStruct = $qf.IndexOf('STRUCTURAL CHECK')
$iAdr    = $qf.IndexOf('check-adrs.ps1')
$iGate   = $qf.IndexOf('run-green-gate.ps1')
Check 'quick-fix: the structural check runs after before-integrate, before the ADR check and green gate' ($iObl -ge 0 -and $iStruct -gt $iObl -and $iAdr -gt $iStruct -and $iGate -gt $iAdr)
Check 'quick-fix: the landing check compares against START_TREE' ($qf -match '-Since <START_TREE>')
Check 'quick-fix: an UNEXPECTED fact waits for the user' ($qfFlat -match 'wait for their OK before continuing')
Check 'quick-fix: a blocked required standard stops landing' ($qfFlat -match 'BLOCKED` \| Stop landing')
Check 'quick-fix: a failed check is never no structural changes' ($qfFlat -match 'Never treat a failed check as no structural changes')
Check 'quick-fix: a waived check is recorded under Skipped validations' ($qfFlat -match 'land without the check; record that under Skipped validations')
Check 'quick-fix: finding a structural change never alone leaves quick-fix' ($qfFlat -match 'Finding a structural change is never by itself a reason to leave quick-fix')
Check 'quick-fix: a departure routes to plan-feature, never auto-run' ($qfFlat -match 'needed exception . stop landing' -and $qfFlat -match 'propose `/cogniva-dev:plan-feature` for the decision \(never auto-run it\)')
Check 'quick-fix: no pwsh in a repo that declares or owns a profile asks the user before dispatch' ($qfFlat -match 'if the repo declares an architecture profile \(a `\.cogniva-profile\.yml` anywhere in it\) or has a `\.cogniva/profiles/` folder, say the structural check cannot run and ask the user before dispatching')
Check 'quick-fix stays technology-neutral' ($qf -notmatch '(?i)csproj|ProjectReference|\.NET\b|pyproject')
Check 'quick-fix does not use applicable-rules as its architecture check' ($qf -notmatch 'applicable-rules')
Check 'worktree quick-fix snapshots after any staleness merge' ($wtQfFlat -match 'record `START_TREE` exactly as Step 0 says' -and $wtQfFlat -match 'after any staleness merge is committed')
Check 'Codex parity: both backends send the same prompt, task body verbatim inside it' ($codexFlat -match '`body` VERBATIM' -and $codexFlat -match 'new-task-prompt\.ps1' -and $codexFlat -match 'stdout as its prompt VERBATIM' -and $tpl -match 't\.body')
Check 'Codex parity: quick-fix landing under Codex includes the structural check' ($codexFlat -match 'quick-fix also runs its structural check')
# --- explicit-only invocation metadata (both agent hosts) ----------------------
$explicitOnly = @('explore-idea', 'cleanup-work', 'cleanup-allwork', 'repo-init', 'add-module')
foreach ($name in $explicitOnly) {
    $skillText = ReadDoc "skills\$name\SKILL.md"
    $yamlPath = Join-Path $plugin "skills\$name\agents\openai.yaml"
    $yamlText = ''
    if (Test-Path $yamlPath) { $yamlText = [System.IO.File]::ReadAllText($yamlPath) }
    Check "$name is explicit-only on both agent hosts" `
        ($skillText -match '(?m)^disable-model-invocation: true' -and $yamlText -match '(?m)^policy:' -and $yamlText -match '(?m)^\s+allow_implicit_invocation: false')
}
$routed = @('quick-fix', 'plan-feature', 'backlog', 'adr', 'groom-backlog', 'easy-work-scan', 'applicable-rules', 'feature-check', 'gate-check')
Check 'routed skills stay model-invocable on both agent hosts' `
    (@($routed | Where-Object { (ReadDoc "skills\$_\SKILL.md") -match 'disable-model-invocation' -or (Test-Path (Join-Path $plugin "skills\$_\agents\openai.yaml")) }).Count -eq 0)
# --- agent-host-neutral wording in shared skills ------------------------------
$handoffFlat = $handoff -replace '\s+', ' '
$bkFmtFlat = (ReadDoc 'skills\backlog\BACKLOG-FORMAT.md') -replace '\s+', ' '
$eiText = ReadDoc 'skills\explore-idea\SKILL.md'
$glText = [System.IO.File]::ReadAllText((Join-Path $plugin '..\cogniva-skills\skills\glossary\SKILL.md'))
$scanFlat = ((ReadDoc 'skills\groom-backlog\SKILL.md') + ' ' + (ReadDoc 'skills\easy-work-scan\SKILL.md')) -replace '\s+', ' '
Check 'plan-feature summary names execute-feature in both agent hosts'' syntax' `
    ($pfFlat -match 'Run the execute-feature skill on `<Module>/<Feature>` when ready' -and $pfFlat -match '`\$execute-feature <Module>/<Feature>` in Codex')
Check 'HANDOFF: skill invocations use the current agent host''s syntax' `
    ($handoffFlat -match 'write the invocation in the current agent host''s syntax')
Check 'backlog header names skills, not one agent host''s commands' `
    ($bkFmtFlat -match 'Promote with the plan-feature skill; trivial fixes can go straight to quick-fix\.')
Check 'shared skills name no Claude Code question tool' `
    ($pf -notmatch 'AskUserQuestion' -and $eiText -notmatch 'AskUserQuestion' -and $glText -notmatch 'AskUserQuestion')
Check 'glossary description names no Claude Code tools' `
    ($glText -notmatch 'DO NOT use Grep, Glob, Read' -and $glText -match 'DO NOT search the codebase \(grep, file search or file reads\)')
Check 'scan subagents are described for both agent hosts' `
    ([regex]::Matches($scanFlat, 'Spawn ONE read-only subagent \(Claude Code: `general-purpose`; Codex: the default agent\)').Count -eq 2)

# --- shared worker prompt + result contract (both executors) ------------------
Check 'CODEX.md builds every worker prompt with new-task-prompt.ps1 -ResultContract' ($codexFlat -match 'new-task-prompt\.ps1' -and $codexFlat -match '-ResultContract')
Check 'CODEX.md sends the prompt verbatim with no added frame' ($codexFlat -match 'no paraphrase, no summary, no added frame or preamble')
Check 'CODEX.md starts one fresh subagent per task without this conversation where it can' ($codexFlat -match 'Spawn ONE fresh subagent' -and $codexFlat -match 'WITHOUT this conversation''s history')
Check 'CODEX.md validates every reply with test-task-result.ps1' ($codexFlat -match 'test-task-result\.ps1" -ReplyFile')
Check 'CODEX.md: a malformed worker result is BLOCKED, never retried' ($codexFlat -match 'malformed worker result: <reason>' -and $codexFlat -match 'No retry, no re-prompt')
Check 'CODEX.md prints the template status line after every task' ($codex -match '<tag> \(<title>\): <STATUS>\[ @<commitSha>\]')
Check 'CODEX.md: under commits=task the worker ticked before committing; the executor verifies' ($codexFlat -match 'under `commits=task` it ticked them before its commit')
Check 'CODEX.md: structured followups feed the backlog gate' ($codexFlat -match '`followups` arrive structured' -and $codexFlat -match 'backlog gate')
Check 'CODEX.md no longer parses a textual first line' ($codex -notmatch 'first line of exactly' -and $codex -notmatch 'Parse the subagent''s first line')
Check 'docs/codex.md: the Codex backend uses the shared JSON result contract' ($docs -match 'task-result\.schema\.json' -and $docs -match 'new-task-prompt\.ps1' -and $docs -notmatch 'textual `DONE` / `BLOCKED` result contract')
# --- branch policy before any write --------------------------------------------
$efFlat = $ef -replace '\s+', ' '
$iPolicy = $ef.IndexOf('Branch policy')
$iStep0a = $ef.IndexOf('## Step 0a')
Check 'execute-feature checks the branch policy before Step 0a' ($iPolicy -ge 0 -and $iStep0a -gt $iPolicy -and $ef -match '## Step 0 . branch policy \(before anything else\)')
Check 'execute-feature: the policy check precedes every write, .git/info/exclude and commit' ($efFlat -match 'BEFORE writing, appending to `\.git/info/exclude`, or committing anything \(Step 0a included\)')
Check 'execute-feature: Step 0b no longer carries the policy paragraph' ($ef.IndexOf('Branch policy') -eq $ef.LastIndexOf('Branch policy'))
$iPfPolicy = $pf.IndexOf('**Branch policy (lean mode only)')
$iPfEmit = $pf.IndexOf('## Emit the plan')
Check 'plan-feature checks the branch policy before it emits the plan' ($iPfPolicy -ge 0 -and $iPfEmit -gt $iPfPolicy -and $pf -match 'requiredDevelopmentBranchPrefix')
Check 'plan-feature never creates or switches a branch for the policy' (($pf -replace '\s+', ' ') -match 'NEVER create or switch a branch to satisfy the policy')
Check 'CODEX.md: execute-feature Step 0 applies under Codex too' ($codex -match 'Steps 0, 0a, 0b, 1, 2 and 4')
# --- worktree mode stops without the Workflow tool, at every entry point -------
$cw = ReadDoc 'skills\cleanup-work\SKILL.md'
$ca = ReadDoc 'skills\cleanup-allwork\SKILL.md'
$noWorkflowStop = 'worktree mode is ON and the Workflow tool is absent, STOP|Workflow tool is not available in this session \(Codex or any other agent host without it\) and worktree mode is ON, STOP and say: worktree mode currently requires Claude Code \(see the parity record\)'
foreach ($entry in @(@('execute-feature', $ef), @('quick-fix', $qf), @('plan-feature', $pf), @('cleanup-work', $cw), @('cleanup-allwork', $ca))) {
    Check "$($entry[0]) stops in worktree mode when the Workflow tool is absent" (($entry[1] -replace '\s+', ' ') -match $noWorkflowStop)
}
Check 'plan-feature: the worktree stop comes before the design work' ($pf.IndexOf('worktree mode currently requires Claude Code') -ge 0 -and $pf.IndexOf('worktree mode currently requires Claude Code') -lt $pf.IndexOf('## Gather first'))
Check 'cleanup skills: the worktree stop sits right after the lean-mode check' ($cw.IndexOf('worktree mode currently requires Claude Code') -gt $cw.IndexOf('## Mode check') -and $cw.IndexOf('worktree mode currently requires Claude Code') -lt $cw.IndexOf('## Step 0') -and $ca.IndexOf('worktree mode currently requires Claude Code') -gt $ca.IndexOf('## Mode check') -and $ca.IndexOf('worktree mode currently requires Claude Code') -lt $ca.IndexOf('## Scope note'))
# --- a skipped green gate is never a pass ---------------------------------------
Check 'execute-feature: GREEN-GATE-RESULT: SKIPPED is not a pass' ((($ef -replace '\s+', ' ') -match '`GREEN-GATE-RESULT: SKIPPED` is not a pass') -and (($ef -replace '\s+', ' ') -match 'report it under Skipped validations'))
Check 'execute-feature: the green gate is read by its last line' (($ef -replace '\s+', ' ') -match 'Read its LAST line, `GREEN-GATE-RESULT: GREEN\|SKIPPED\|RED\|ERROR`')
Check 'quick-fix: GREEN-GATE-RESULT: SKIPPED is not a pass' (($qf -replace '\s+', ' ') -match '`GREEN-GATE-RESULT: SKIPPED` is not a pass . report it under Skipped validations')
Check 'HANDOFF: a green gate that reported SKIPPED goes under Skipped validations' (($handoff -replace '\s+', ' ') -match '\*\*Skipped validations\*\* . anything not run, and why, including a green gate that reported SKIPPED')
Check 'gate-check: SKIPPED is never reported as passed' (($gc -replace '\s+', ' ') -match 'SKIPPED: green gate not configured' -and ($gc -replace '\s+', ' ') -match 'never as passed')
# --- status skills see ephemeral plans ------------------------------------------
foreach ($entry in @(@('feature-status', 'skills\feature-status\SKILL.md'), @('module-status', 'skills\module-status\SKILL.md'), @('repo-status', 'skills\repo-status\SKILL.md'))) {
    $statusFlat = (ReadDoc $entry[1]) -replace '\s+', ' '
    Check "$($entry[0]) scans .plans-staging for ephemeral plans" ($statusFlat -match '\.plans-staging/' -and $statusFlat -match 'plan=ephemeral')
    Check "$($entry[0]) marks ephemeral features" ($statusFlat -match '\(ephemeral . this clone only\)')
    Check "$($entry[0]) takes status from checkboxes when there is no state.md" ($statusFlat -match 'no `state\.md` \(lean runs keep none\)' -and $statusFlat -match '`in-progress` \(some done\)')
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED: $($failures.Count) assertion(s)."
    exit 1
}
Write-Host ""
Write-Host "All skill-semantics assertions passed."
exit 0
