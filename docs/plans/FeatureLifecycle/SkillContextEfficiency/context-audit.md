# SkillContextEfficiency — audit and acceptance

Executor input for the [feature plan](SkillContextEfficiency-plan.md), not a shipped skill reference. Baseline captured on 2026-11-10 at revision `5b9b65393b588997e502e11d540ad21b768e12fa`; the working tree was clean before these planning documents. This covers the repository's 25 shipped skills, excluding its template and externally maintained plugins. Task 1's description-only implementation is complete; real-host validation has not started.

## Loading model and measurements

Names/descriptions are discovery content; bodies load upon selection and can persist across turns. Six existing explicit-only metadata pairs remove their descriptions from this session's model-discovery list; user-facing invocation menus may still show those commands. No registered startup/per-prompt hook injects all bodies.

References consulted: [OpenAI skill loading](https://learn.chatgpt.com/docs/build-skills), [Claude Code skill loading](https://code.claude.com/docs/en/skills).

Counts use UTF-8 decoding, BOM removal, and CRLF-to-LF normalization. Descriptions exclude enclosing YAML quotes; bodies include everything after closing frontmatter, including blank lines. Names, paths, wrappers, repo instructions, unrelated plugins, and tokenization are excluded. Character/4 is only a rough token estimate; no billing/frequency measurements were taken.

Frozen baseline: all 25 descriptions = 9,404 characters; same 19 discoverable descriptions = 7,265; all bodies combined = 140,149. The body sum is not loaded on every prompt. Previous proposed descriptions totaled 2,990 overall / 2,288 for the 19. The revised glossary draft below deliberately retains the prohibition and is longer.

For invocation comparisons, list prescribed/observed files and count each once. A section reference does not prove a whole-file read. Show conservative section-only and potential whole-file cases separately for coverage and commit flags. Include mandatory companions even if read later; relocation alone saves nothing. Separate target-repo data/evidence reads from skill instructions. Actual transcripts take precedence over predicted read sets.

## Inventory and proposed descriptions

Five bodies change narrowly: backlog, execute-feature, quick-fix, project-requirement, and glossary. Only two new skill companions are planned: COVERAGE.md and COMMIT-POLICY.md.

| Skill | Description characters | Body characters | Body treatment | Proposed discovery description |
|---|---:|---:|---|---|
| add-module | 316 | 5561 | description only | Scaffold a Module in a .NET repo using the src/Modules bundle layout; explicit invocation only. |
| adr | 488 | 4063 | description only | Record human-confirmed architecture decisions, respect existing ADR provenance and relitigation rules, and surface candidate decisions during design. |
| applicable-rules | 195 | 2873 | description only | Discover repository instructions, architecture constraints, and validation obligations for intended target paths before implementation; read-only. |
| backlog | 597 | 11365 | extract coverage only | Capture deferred work in BACKLOG.md or feature stubs, and route follow-ups surfaced by other skills for confirmation. |
| cleanup-allwork | 553 | 4675 | description only | Close out all ledger-marked cleanupable worktrees, including those from other sessions; explicit invocation only. |
| cleanup-work | 473 | 5051 | description only | Close out this session's validated, cleanupable worktrees; explicit invocation only. Use cleanup-allwork when session context is unavailable. |
| easy-work-scan | 513 | 4881 | description only | Find backlog work suitable for low-involvement execution and dispatch the user-approved shortlist. |
| execute-feature | 501 | 16176 | extract commit policy only | Execute or resume a feature plan supplied as a path, name, or pasted text, with task tracking and manual-validation gates. |
| explore-idea | 330 | 6249 | description only | Develop an idea through an ongoing brainstorm with disposable notes before planning or implementation; explicit invocation only. |
| feature-check | 190 | 1521 | description only | Check preflight, review, or commit readiness for bounded implementation without owning its lifecycle. |
| feature-status | 337 | 2605 | description only | Report feature task progress, next tasks, validation gates, and worktree or integration status; read-only. |
| gate-check | 185 | 1472 | description only | Run repository-configured completion checks and report passing, failing, or skipped validation without lifecycle actions. |
| groom-backlog | 375 | 4939 | description only | Review stale backlog items and deferred stubs; propose evidence-backed edits for confirmation. Deep restructuring is opt-in. |
| investigate | 269 | 5109 | description only | Design, record, or review technical experiments within a continuing investigation; explicit invocation only. |
| module-deps | 502 | 5542 | description only | Generate Module dependency graphs and deployment closure, or check cycles, in .NET repos using the src/Modules bundle layout. |
| module-status | 303 | 2533 | description only | Report one Module's feature progress, deferred stubs, loose backlog, and blockers; read-only. |
| plan-feature | 363 | 8659 | description only | Design one feature and write an executable task plan. Starts only on an explicit user request or an approved dispatch from easy-work-scan/groom-backlog. |
| quick-fix | 421 | 12509 | shared commit-policy reference | Implement a small change without a feature plan. Starts only on an explicit user request or an approved dispatch from easy-work-scan/groom-backlog. |
| repo-init | 198 | 5931 | description only | Scaffold a new .NET repo with chosen application hosts and the dotnet architecture profile; explicit invocation only. |
| repo-status | 411 | 2436 | description only | Report repository-wide feature progress, deferred work, backlog, and blockers; read-only. |
| workflow-status | 586 | 4458 | description only | Report Claude Workflow journal status, task progress, and stalled runs across sessions; read-only. Does not track Codex runs. |
| glossary | 634 | 7514 | deduplicate in place | Use for unfamiliar or ambiguous terms, project-specific jargon, or nouns absent from current context. DO NOT search the codebase (grep, file search or file reads) for an unrecognized term before invoking this skill. |
| project-context | 157 | 3156 | description only | Create or update business context; flag conflicts, missing rationale, or scope drift during design and planning. |
| project-requirement | 243 | 7355 | conditional format read | Capture, refine, view, or analyze project requirements; flag uncaptured requirements and status drift during planning. |
| reference | 264 | 3516 | description only | Maintain the project bibliography and propose capturing unrecorded sources cited in design or planning. |

Keep paired explicit-only metadata for add-module, cleanup-allwork, cleanup-work, explore-idea, investigate, and repo-init. All other invocation policies remain unchanged. Omitted discovery detail remains enforced in existing bodies, including investigate's separate experiment approval and acceptance/persistence rules.

## Four targeted fixes

| Fix | Evidence | Change and expected saving |
|---|---|---|
| Backlog direct coverage | CAPTURE-BAR.md is 13,276 normalized characters / 263 lines; Test 1 is 1,456 / 27. | Extract only coverage and link both callers. A whole-file direct read could avoid about 11.8k characters; an agent already reading Test 1 alone may save little. Caller, not helper, owns proceeding to intent tests. |
| Quick-fix commit flags | execute-feature/SKILL.md is 16,721 normalized characters; Flags is 2,605, including unrelated plan/tasks flags. | Share only commit definitions. Avoid a potential full entrypoint read; compare separately with a flags-section-only reader. Execution and landing stay in place. No claim that execute-feature itself saves text simply from extraction. |
| Requirements format | Body 7,355 + unconditional format 9,951 = 17,306 before edits. | Conditionalize the format read; ordinary status/view avoid about 9,951 characters. Keep the seven action procedures and existing format file. |
| Glossary repetition | Body 7,514, with repeated glossary-first statements. | Deduplicate in place, retaining each distinct obligation. No new files or arbitrary body-reduction quota. |

The broad splitting proposal was removed because its measured benefit did not justify its change surface. Further extraction needs evidence and a new scope decision. ADR 0014 supports selective lazy loading without requiring every moderately sized skill to be split.

## Targeted validation

Tasks 2 and 5 prepare materials only and return DONE at manual gates. The human/console performs actual sessions, records results using the existing [smoke harness](../../../../plugins/cogniva-dev/tests/host-smoke/README.md), and explicitly accepts or rejects the current build. Task 3 checks Gate A acceptance; Task 6 checks Gate B acceptance before normal checks and landing. Named, reasoned human waivers permit progress while preserving original fail/not-run results and verification limits. Preparation checkboxes never count as acceptance.

### Scenario scope

| Scenario | Neutral request/fixture | Check |
|---|---|---|
| DISCOVERY | Fresh hosts with both branch plugins, using a separate discovery/build probe from the neutral glossary behavior sessions. | Same 25 inventory, 19 model-discoverable descriptions, six manual-only pairs, representative matching and approved routing. User menus may still list manual commands. Attest actual loaded descriptions/paths and both plugin contents. |
| GLOSSARY-FIRST | Identical clean external raw fixture and neutral prompt against the published old-description build and the description-only build on each host; repeat the changed-build case after body edits. | Observe activation/lookup before implementation search. Attest each loaded build and inherited/global instruction sources. Published controls are non-blocking observations; compare results before attributing changed-build failure to shortening. |
| GLOSSARY-MISSING | A separate clean external fixture with an absent ambiguous term. | Clarification and offer to document; confirmation before writing. Use an interactive/manual run without the harness's unattended/no-questions instructions. |
| BACKLOG-DIRECT | Direct loose capture, repeated covered item, and a pre-existing dirty target in isolated external synthetic copies. | Preserve duplicate coverage, human-later fallback, tier/workspace/dirty-file/path-scoped commit rules. Before/after traces show whether CAPTURE-BAR.md or COVERAGE.md was read and the observed extent. |
| QUICK-FIX-FLAGS | Existing QF-NONE scenario through the unchanged host-smoke driver, before and after, with distinct external FixtureRoot/OutDir values. | Use its exact fixture/prompt/assertions. Inspect its complete saved transcript for execute-feature/SKILL.md, Flags sections, and after COMMIT-POLICY.md. Preserve no-stage/no-commit, snapshot/check, and own landing. Mechanically verify all commit-mode rules separately. |
| REQUIREMENTS-READ | Ordinary view/status and a separate add/refine path using existing synthetic records externally. | Correct read-only output, observed format read, and unchanged mutation grammar/source/severity/lifecycle/confirmation. |

Use the same raw data/prompts across hosts and before/after; fresh sessions start from isolated external copies. Do not disclose expected answers in evaluating prompts. Build-attestation requests that mention glossary happen in a separate probe, through startup metadata, or after the neutral behavioral observation. Asking a session to quote glossary's description before testing activation primes the choice and invalidates that observation.

## Human checkpoint contract

Standard smoke records are the results source; this audit holds their index, human acceptance, and waivers. Do not introduce a competing custom results format. Gate workers prepare record templates within this audit only, not fake run files under docs/host-parity/smoke. Real attempted runs produce actual records; a host that could not be started remains not-run in the audit with any human waiver, without invented runtime metadata.

- Gate A: DISCOVERY, GLOSSARY-FIRST, and GLOSSARY-MISSING on Claude Code and Codex are six acceptance checks for the description-only build. BACKLOG-DIRECT, QUICK-FIX-FLAGS, and REQUIREMENTS-READ on each host are six non-blocking before-read observations. Add one GLOSSARY-FIRST control per host from pinned baseline commit 5b9b653: two more non-blocking observations. Missing/failing/not-run controls or read observations limit interpretation but never block implementation or require waivers; a failed new-build acceptance check still needs repair or a named human waiver.
- Gate B: GLOSSARY-FIRST, GLOSSARY-MISSING, BACKLOG-DIRECT, QUICK-FIX-FLAGS, and REQUIREMENTS-READ on each host are ten acceptance checks by default. A pending Codex lifecycle limitation or unavailable host may be specifically waived by the human; it cannot force a permanent retry loop.
- Each gate's human decision is pending, accepted, accepted-with-waivers, or rejected and names the current source instruction fingerprint. An acceptance check is addressed by either a real pass with loaded-build evidence and a linked smoke row, or an explicit waiver naming the host/scenario and giving the reason and accepted limitation. A missing result may be waived, but must be described honestly as not-run; absence alone is not approval. Do not infer a blanket waiver from a general request to continue.
- The human may waive named fail/not-run cases or a missing-current-build-evidence check. Keep actual raw result statuses, failed attempts, and reasons unchanged. A waiver affects progression only; it is not a pass, proof of measured savings, or support for verified parity. Build-unattested results do not qualify as passes for the changed build.
- Tasks 3 and 6 check the explicit decision against the current source fingerprint, valid evidence for unwaived acceptance checks, and the named/reasoned waiver list. Pending/rejected decisions, source drift without renewed acceptance, or an unaddressed acceptance check return BLOCKED naming that prerequisite. A valid named waiver permits continuation despite its retained fail/not-run. Updating the audit resolves the condition without hand-editing task checkboxes or rerunning preparation.
- Source edits after acceptance require the human to accept the new fingerprint and either rerun affected checks or explicitly waive them. Keep prior attempts and their limits. Workers never fill acceptance, invent pass results, conduct human sessions, or solicit approvals from a background task.
- Record read extents as whole-file, section (observed extent), none, or unobservable with the relevant transcript/tool-call references. Inspect the QF-NONE transcript before using unobservable; a missing or incomplete capture can still justify it. Never infer a full-file read from a source link or convert unknown observations into measured savings.

### Gate A acceptance and evidence index

No validation has run; Task 2 will prepare exact prompts, inputs, commands, and in-audit record templates.

Human decision: pending.

Accepted source fingerprint: not yet evaluated.

Smoke-record references: none.

Waivers: none. Any future entry must name host/scenario, retained result, reason, and accepted limitation for the stated fingerprint.

Before-read observations: not-run; non-blocking. Record backlog, QF-NONE, and requirements reads separately for each host, including unavailable/incomplete traces.

Published GLOSSARY-FIRST controls: not-run; non-blocking. Authoritative source: 5b9b65393b588997e502e11d540ad21b768e12fa (5b9b653). The human exports that commit's plugins tree for Claude Code; an installed Codex copy may be a shortcut only when matched to that revision. Record separate old-build smoke records and compare with the same-host description-only result.

Host setup/closing disposition: not started. Capture original install state and record no persistent changes, restored-and-verified, or an explicit human decision to retain the branch build. Pending/failed restoration is never silently reported as complete.

Feature-owned evidence paths for Task 3: none yet; populate exact audit/control/description-only/before-observation smoke-record paths after real runs.

### Gate B acceptance and evidence index

No validation has run; Task 5 will prepare the after-run materials while preserving before evidence.

Human decision: pending.

Accepted source fingerprint: not yet evaluated.

Smoke-record references: none.

Waivers: none. Any future entry must name host/scenario, retained result, reason, and accepted limitation for the stated fingerprint.

Host setup/closing disposition: not started. Refresh/reinstall both plugins before this gate on persistent routes, and restore/verify recorded original state afterward or record explicit approved retention.

Feature-owned evidence paths for Task 6: none yet; populate exact real after-run or updated evidence record paths to validate and commit.

### Published-build glossary control

The repo-init scaffold already supplies a glossary protocol in [its AGENTS.md](../../../../plugins/cogniva-dev/templates/repo/AGENTS.md). A clean fixture deliberately tests unaided description routing; the old published description must therefore be observed under the same test conditions before attributing a new failure to shortening.

The authoritative control source is commit `5b9b65393b588997e502e11d540ad21b768e12fa` (`5b9b653`), which is both this audit's baseline and the published main/origin/main revision confirmed during planning. Commit identity, not a mutable branch name or version label, defines the old build. Task 1 can rewrite the checkout before Task 2 without altering that Git object.

For Claude Code, the human exports that revision's entire `plugins/` folder to a concrete approved external directory and loads its exported cogniva-dev and cogniva-skills directories with the same two session-local --plugin-dir flags/settings as the branch comparison. The evaluating session still starts in the separate clean fixture, not this checkout or the plugin export directory. This does not require an installed published cache and does not swap the user's marketplace. Do not quietly mark the Claude control not-run just because its recorded cache folder is absent; prepare this available export route. If export/run approval is declined, retain that real reason and the control's non-blocking status.

Installed copies are a shortcut only when their actual content matches this pinned revision. Codex's existing 0.11.0 and 0.8.1 caches may qualify after that check; leave that route available. An installed directory source pointing at this working tree cannot stand in for the old build after Task 1. If the pinned commit itself is not readable, report the concrete preparation prerequisite rather than substituting current HEAD or auto-fetching.

At Gate A run the same clean raw fixture, exact neutral prompt, host/model settings, and inherited instruction environment against the pinned old build and changed-description build. Use pristine independent sessions, avoid glossary priming, and record additional source/config differences that limit causal attribution. Run an installed shortcut before replacing it; the immutable Claude export can be prepared after Task 1. Record full commit, export/loaded paths, actual old description, content attestation, and the non-blocking result.

#### Human export commands to prepare

These commands are operator instructions only. The worker resolves and presents the exact external root/archive paths; the human obtains the required approval before creating them. Do not execute them as part of plan preparation or reuse/overwrite an existing export. Run from the source checkout in PowerShell 7:

```powershell
$contextCheckout = (Get-Location).Path
$contextControlRef = '5b9b65393b588997e502e11d540ad21b768e12fa'
$contextControlRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'cogniva-skill-context-control-5b9b653'
$contextControlArchive = Join-Path $contextControlRoot 'plugins-5b9b653.zip'
& git -C $contextCheckout cat-file -e ($contextControlRef + ':plugins')
if ($LASTEXITCODE -ne 0) { throw 'Pinned baseline plugins tree is not available locally.' }
if (Test-Path -LiteralPath $contextControlRoot) { throw 'Choose a fresh unused external export path and obtain approval for it.' }
New-Item -ItemType Directory -Path $contextControlRoot -ErrorAction Stop | Out-Null
& git -C $contextCheckout archive --format=zip ('--output=' + $contextControlArchive) $contextControlRef plugins
if ($LASTEXITCODE -ne 0) { throw 'Pinned plugin export failed; preserve the error and do not substitute the live checkout.' }
Expand-Archive -LiteralPath $contextControlArchive -DestinationPath $contextControlRoot -ErrorAction Stop
$contextControlDev = Join-Path $contextControlRoot 'plugins/cogniva-dev'
$contextControlSkills = Join-Path $contextControlRoot 'plugins/cogniva-skills'
```

After approval/setup, the human changes into the same kind of clean external glossary fixture used for the new-description run and launches the control with:

```powershell
claude --plugin-dir $contextControlDev --plugin-dir $contextControlSkills --setting-sources project,local
```

Record/compare exported contents against git show of this exact revision or run the existing instruction-fingerprint recipe from the export root. Numeric plugin versions alone do not identify the control. No export, installation, or model session has been performed by these planning documents.

| Published old build | Changed-description build | Interpretation |
|---|---|---|
| pass | fail | Regression signal for the changed build under matched conditions; investigate or rerun a targeted pair before attributing causality to description wording. The human may accept a specific documented limitation; never hide the failure. |
| fail | fail | Unaided activation already failed at baseline. This fixture tests behavior beyond the scaffold's instruction-backed case; that is a reasonable reason for a named human waiver, not proof of preserved behavior in all real repos. |
| pass | pass | No observed regression in this matched case; a small behavioral sample does not establish universal routing reliability. |
| fail | pass | Improved observed result in this case; do not infer a general causal improvement from one pair. |
| not-run/unattested | any | No valid matched baseline comparison. Preserve the limitation; the control remains non-blocking. |

Keep controls in separate standard smoke files with actual published Plugin source/content evidence, not in a record whose header describes the new build. Label them GLOSSARY-FIRST-PUBLISHED in the scenario table and as control observations in the audit. Retain failing control records in version control via Task 3; they need not be cited as new-build parity evidence. Do not upgrade a new-build result merely because a baseline row failed.

### Fixture isolation and prompt preparation

Stage raw neutral inputs under `.plans-staging/SkillContextEfficiency/validation/` and verify ignore status. Staging is never an evaluating session's working directory. The worker prepares exact setup/copy commands, proposed resolved absolute external paths, and bounded model runs; the console/human approves external writes before executing them. Nothing in this plan grants blanket approval for TEMP, cache, output, installation, or config writes.

For actual sessions physically copy the neutral inputs into separate clean repositories under an approved external temporary root, outside this checkout. Resolve the final path and inspect its ancestors and loaded user/global memory: a pre-existing glossary protocol makes passive activation causally ambiguous. Do not copy this repo's AGENTS.md/CLAUDE.md or its protocol into those fixtures. If clean instruction context is unavailable, record the limitation and seek a named human waiver rather than calling it a pass. Use authorized process-local configuration when suitable; never silently edit user settings.

Use the existing QF-NONE fixture generator/prompt/assertions exclusively for quick-fix. It intentionally has an unattended/no-questions policy and must not be reused wholesale for GLOSSARY-MISSING. Prepare a minimal interactive glossary fixture without that policy; a missing-definition question must be allowed. Before/after and each host get independent pristine copies so earlier mutations cannot alter later input. Keep before transcripts permanently separate from after output.

## Harness reuse and loaded-build evidence

Follow [Installing the branch build](../../../../plugins/cogniva-dev/tests/host-smoke/README.md#installing-the-branch-build), not an improvised installation procedure. Load both plugins: glossary and requirements live in cogniva-skills; the default headless example loads only cogniva-dev. Workers only prepare instructions; actual external installation/cache writes require exact-path approval from the human.

- Claude Code: prefer session-local loading for both interactive CLI and headless runs. Interactive CLI starts from the clean external fixture with both --plugin-dir flags and --setting-sources project,local, excluding user-level plugins for the isolated comparison; no marketplace swap is needed. For the old control use the two directories exported from pinned commit 5b9b653, never the current directory marketplace; for Gate A/B use the current checkout directories. Headless QF-NONE passes the second plugin through the driver's existing ExtraArgs. Record both absolute source paths/settings. Only a deliberate VS Code configuration change needs the persistent marketplace procedure and restoration; an already-correct directory pointer is not changed just for testing.
- Codex: attest installed control content against commit 5b9b653 before using it as a shortcut, then run it before swapping it out, then follow the README's branch-marketplace/install procedure for both plugins. Explicitly refresh/reinstall both plugins again before Gate B; installed versions may stay 0.11.0/0.8.1 across published, description-only, and body-refactored sources. Use the host's supported reinstall procedure verified by current help; a marketplace pointer change or a new session alone does not refresh identical-version cache content. Start fresh and compare both actual loaded source sets against the intended branch. Never silently delete caches or force a version bump as a workaround. Restore the captured pre-test source/selection after each gate and verify it.
- Obtain discovery metadata through startup/catalog capture where available. Otherwise use a separate same-configuration build probe or query it after behavior was observed, recording that source of evidence. Capture the actual revised description and skill path for glossary and relevant entries from both plugins; do not feed expected description text for the session to echo. Match actual loaded files to branch content. For shared process-local setup across separate sessions, record that the files/config stayed unchanged between attestation and behavioral run.
- A smoke header that merely copies this checkout's plugin versions is not loaded-build proof. Add the launch/install evidence and actual content/catalog match in Observations and link it from each relevant scenario. If that cannot be established, retain the result as unattested for this feature and either rerun correctly or use a named waiver; do not treat it as a pass for the changed build.

### Machine-specific live marketplace note

Read-only inspection during planning confirms Claude Code's cogniva entry in `%USERPROFILE%/.claude/plugins/known_marketplaces.json` is a directory source at this checkout; the install-record cache directories are absent. That setup does not provide an immutable installed old-description copy. Treat Task 1's working-tree edits as exposed to everyday Claude sessions resolving this source before Gate A. The control always has the pinned export above, regardless of installed-cache availability.

Isolated session-local test flags keep that user-level plugin source out of the evaluating session. If no persistent Claude configuration changed, record restoration as not needed; a directory-pointer restore is a no-op and does not roll the edited source back to the old descriptions. Keep the general restoration procedure for actual configuration changes, especially Codex. This note adds no new gate and authorizes no user-config change or implementation rollback.

### Human host setup and closing checklist

Prepare these as explicit operator actions at both gates, not an implied README link. The worker supplies the concrete paths/commands; the console obtains required external-write approvals; the human executes and records the outcome.

1. Before persistent changes, record the original cogniva marketplace source, installed/enabled cogniva-dev and cogniva-skills versions/content identities, and any relevant trust state, without dumping credentials or unrelated config. Record whether no marketplace/plugins were present. Use the pinned 5b9b653 plugin export for Claude GLOSSARY-FIRST; run any attested installed shortcut before replacing its old content. Do not assume the installed Claude directory source is an old copy.
2. Prefer an interactive Claude CLI launched from the isolated external fixture using the exact session-local form below with absolute plugin paths. Closing the process ends local loading; record that no persistent configuration/cache install was changed. Before Gate B, a fresh local process reads both current checkout directories directly, so it needs no reinstall or persistent restoration.
3. For Codex or Claude VS Code, perform the approved branch marketplace/install procedure for both plugins. Before Gate B explicitly refresh/reinstall both even when manifest versions are unchanged, then verify their content against the after-build source. Prepare exact supported reinstall commands; do not improvise recursive cache deletion, silently edit versions, or continue with stale attestation.
4. At the end of each gate, including failed/aborted runs, restore the recorded original marketplace, installed/enabled plugin selection, and original version/content identities using the README's return procedure and supported reinstall flow. Normally this returns to the published marketplace; restore the actual prior source rather than assuming it. Restore only the two tested plugins and marketplace settings, preserving unrelated state. Record commands, resolved paths/approvals, and a fresh-session verification of the restored source. If exact restoration cannot be achieved, report pending/failed with the reason and obtain an explicit human disposition instead of silently substituting latest or leaving the branch active. The human may explicitly choose to keep the branch build; record that choice and its scope.
5. Save the real smoke records and audit links/acceptance. Task 3 commits its exact validated Gate A/control/observation records with the audit under commits=task; Task 6 does the same for Gate B and any explicitly inventoried updated feature evidence. Neither task sweeps the directory or commits external transcripts/scratch. These task commits do not remove the executor's earlier dirty-tree check. Human acceptance may explicitly authorize resuming with the named evidence-only changes dirty; otherwise the existing console guard still obtains its required OK. Never infer that consent from a pass row.

For interactive Claude, the human first changes into the approved external fixture and uses this form, substituting concrete absolute directories prepared by the worker. All source variables are resolved before leaving the checkout. Use the pinned export directories for the Claude control and current checkout directories for the branch checks; do not execute this during gate preparation:

```powershell
claude --plugin-dir $contextDev --plugin-dir $contextSkills --setting-sources project,local
```

The old/new/after launch and restoration history belongs in smoke Observations and the gate acceptance index. A restoration step is not a background worker task and is not permission for outside-repository writes. Gates stop for this human work; normal workers record its disposition and do not claim it happened without evidence.

### QF-NONE commands to prepare

The worker resolves all paths and presents the concrete external fixture/output writes before the human runs them. Run these commands in PowerShell 7 from the source checkout; the driver itself starts the agent in its external fixture. Calling the script directly preserves ExtraArgs as an array. The phase is before at Gate A and after at Gate B, so roots are distinct. The dry run builds nothing and spends no model tokens; remove DryRun only after approving the concrete actual run. Codex requires the prior two-plugin branch installation from the README.

```powershell
$contextPhase = 'before'
$contextCheckout = (Get-Location).Path
$contextDriver = Join-Path $contextCheckout 'plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1'
$contextDev = Join-Path $contextCheckout 'plugins/cogniva-dev'
$contextSkills = Join-Path $contextCheckout 'plugins/cogniva-skills'
$contextExternal = Join-Path ([System.IO.Path]::GetTempPath()) ('cogniva-skill-context-' + $contextPhase)
$contextClaudeFixture = Join-Path $contextExternal 'claude-code'
$contextCodexFixture = Join-Path $contextExternal 'codex'
& $contextDriver -AgentHost claude-code -Scenario QF-NONE -PluginDir $contextDev -ExtraArgs @('--plugin-dir', $contextSkills) -FixtureRoot $contextClaudeFixture -OutDir (Join-Path $contextClaudeFixture 'out') -Covers 'quick-fix' -DryRun
& $contextDriver -AgentHost codex -Scenario QF-NONE -FixtureRoot $contextCodexFixture -OutDir (Join-Path $contextCodexFixture 'out') -Covers 'quick-fix' -DryRun
```

Before actual runs, confirm these resolved external paths are outside the checkout, choose fresh unused roots instead of overwriting previous evidence, and obtain exact-path approval. The driver prints RECORD for each real run and saves final text, transcript, assertions, and errors. Keep the full transcript, not just the final answer. Follow the README's existing Codex permission mode guidance when applicable; do not introduce automatic approval bypasses or change the harness. For glossary/requirements/backlog checks the human uses the prepared isolated interactive fixtures and records actual observations manually in the same smoke format.

## Standard smoke records

Use [docs/host-parity/smoke/README.md](../../../host-parity/smoke/README.md): actual date, agent host/version, surface, OS, both plugin versions, true Plugin source, Covers row IDs, the Scenario/Result/Assertion output/Notes table, and Observations. Use its date/host/surface filename with the next unused numeric suffix, keeping published-control, description-only, and after-body records separate because each header attests one build. Label the build role and checkpoint phase in Observations. Do not put empty templates under the real smoke directory.

Use actual applicable Covers IDs: discovery may support install-cogniva-dev/install-cogniva-skills, glossary checks glossary, QF-NONE quick-fix, backlog backlog, and requirements project-records. Keep the scope of conclusions narrower than the whole capability when only one behavior was tested. The QF driver writes its native QF-NONE row; record commit-flag read observations in its Notes/Observations or a clearly labeled supplemental scenario, without rewriting the built-in assertion outcome.

The audit links actual records, inventories their exact feature-owned paths for Task 3/6 commits, and holds acceptance/waivers plus host-restoration disposition. Keep uncited failing published/before records; only cite evidence supporting the capability/build claim. Human acceptance is not substitute evidence for parity; do not promote an entire capability to verified from a waived fail, not-run, wrong-build run, or a narrow diagnostic observation. Preserve all raw statuses and limitations even when the human elects to continue.

### Instruction fingerprint

Fingerprint only plugin skill Markdown and agents/openai.yaml content. Excluding audit, fixtures, parity notes, and version-only manifests prevents documentation commits or approved release bookkeeping from invalidating unchanged instruction evidence. Run this read-only Python code from the repo root and record its output for each checkpoint and result row:

```python
from pathlib import Path
import hashlib
files = sorted(set(Path('plugins').glob('*/skills/**/*.md')) |
               set(Path('plugins').glob('*/skills/*/agents/openai.yaml')),
               key=lambda p: p.as_posix())
h = hashlib.sha256()
for p in files:
    text = p.read_text(encoding='utf-8-sig')
    h.update(p.as_posix().encode('utf-8') + b'\0')
    h.update(text.encode('utf-8') + b'\0')
print(h.hexdigest())
```

This fingerprint identifies intended source content only. Pair it with the actual two-plugin loading/content evidence above; it cannot attest a session on its own. No script is installed by this recipe.

## Console release and parity obligations

Preferred release timing is one patch bump at final Task 6 landing. This is a planning preference, not bump approval. No bump is approved or applied. Workers make no bump offers and edit no version manifests.

The console honors AGENTS.md before-integrate whenever landing actually runs. If an earlier `tasks=one` slice lands, the console makes the required offer and records the human's timing/answer here once, then follows that explicit decision across the remaining slices. Silence is not approval. Under a full run, the preparation gates stop before landing; after Task 6 the normal landing block handles the offer, accepted three-location edits, and any resulting gate rerun.

Release decision: offer deferred to final Task 6 landing by explicit human response on 2026-11-10: "Defer the offer to Task 6 landing (recommended)". The console offered cogniva-dev 0.11.1 and cogniva-skills 0.8.2 at Task 1 landing, patch because capabilities remain unchanged. Versions remain unchanged; this timing decision authorizes no bump. Revisit the offer at Task 6 landing without repeating it for intervening slices.

Task 1 makes no parity-row edits and changes no mechanism/status/evidence claim. Tasks 3–4 update the five rows with actual loading changes. At landing the console must still honor AGENTS.md's explicit parity-update requirement; if description-only changes need additional row notes under that rule, add minimal accurate notes or evidence references without inventing mechanism/status changes. Do not force every row to change inside the description worker.

## Reproduce source counts

Run this read-only Python code from the repository root using the existing Python interpreter; it writes nothing:

```python
import pathlib, re
all_desc = exposed_desc = bodies = 0
for p in sorted(pathlib.Path('plugins').glob('*/skills/*/SKILL.md')):
    text = p.read_text(encoding='utf-8-sig')
    _, front, body = re.split(r'^---\s*$', text, maxsplit=2, flags=re.M)
    match = re.search(r'^description:\s*(.*(?:\n[ \t]+.*)*)', front, re.M)
    desc = match.group(1).strip().strip('"')
    manual = 'disable-model-invocation: true' in front
    all_desc += len(desc)
    exposed_desc += 0 if manual else len(desc)
    bodies += len(body)
    print(p.parent.name, len(desc), len(body), 'explicit-only' if manual else 'discoverable')
print('TOTAL', all_desc, exposed_desc, bodies)
```

The parser fits current single-line descriptions. Keep valid YAML; if representation changes, parse faithfully without changing the counting convention. Preserve the frozen baseline when adding results.

## Execution evidence

During execution link real standard smoke records, published-control/new-build comparisons, actual description counts, targeted read sets/assumptions, regression outcomes, two-plugin build attestation, host restoration/retention disposition, exact Task 3/6 evidence inventories, and real implementer/reviewer hosts. Preserve fail/not-run and named waivers. Acceptance with waivers permits progress while leaving the corresponding behavioral and parity claims limited.

### Task 1 — description-only source results (2026-11-10)

Applied all 25 description drafts above verbatim, each at most two sentences. The inventory remains 21 cogniva-dev skills and four cogniva-skills skills. The six paired explicit-only settings remain on add-module, cleanup-allwork, cleanup-work, explore-idea, investigate, and repo-init; the same other 19 remain model-discoverable. Quick-fix and plan-feature retain their explicit-start/approved-dispatch description rules. Glossary retains the broad unfamiliar/ambiguous-term, project-jargon, and absent-noun trigger and its explicit codebase-search prohibition.

Counts use the normalization and quote-exclusion convention above:

| Measured source | Frozen baseline characters | Task 1 characters | Reduction |
|---|---:|---:|---:|
| All 25 descriptions | 9,404 | 3,065 | 6,339 (67.41%) |
| Same 19 model-discoverable descriptions | 7,265 | 2,363 | 4,902 (67.47%) |
| All 25 bodies | 140,149 | 140,149 | 0 |

A read-only comparison against the pre-task HEAD confirmed every body and every non-description frontmatter field unchanged. No invocation metadata, parity rows, versions, overlays, or execution procedures changed. The reduction across the six explicit-only descriptions is not claimed as recurring model-discovery savings. These source sizes are not runtime token, billing, or frequency measurements.

TDD evidence: scoped the existing quick-fix, plan-feature, and glossary description assertions to frontmatter and added protection for glossary's broad trigger. The semantic suite first failed exactly that new trigger assertion on the old description (exit 1); after applying the drafts it passed (exit 0). All original workflow obligations remain checked.

Required source checks passed: `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`; `pwsh -NoProfile -File scripts/check-host-parity.ps1` (26 rows, 33 items covered); and `git diff --check`. Reviewed `scripts/check-host-neutrality.ps1` and ran it with PowerShell 7: OK, 70 references in 16 files, with no reductions or increases; no baseline refresh was needed.

Implemented on Codex; independent host review and fresh-session activation checks are not yet performed. Source assertions do not prove fresh-host activation or loaded-build identity. Gate A remains pending, with no smoke records or behavioral acceptance claimed. Task 2 prepares that checkpoint separately; console-owned version offers and any before-integrate parity obligations remain as specified above.

Release offers and decisions are console-owned as specified above; the final worker records evidence and mechanical checks, then returns DONE so normal landing can run.

### Task 1 — console landing obligations (2026-11-10)

Task result validated against the shared result contract; all five Task 1 checkboxes are complete and Tasks 2–6 remain unchecked. The console independently compared the 25 entrypoints against the pre-task commit: only descriptions changed, and all six manual-only settings remain intact. Updated all 18 affected skill capability rows in `docs/host-parity.md` with one shared description-only source-evidence note, preserving mechanisms, statuses, and existing evidence claims. Implementer: Codex; independent host review remains pending. No plugin manifests, installed caches, or user configuration were changed. The source-control ADR check and whitespace check passed; the mandatory green gate follows this obligation commit.
