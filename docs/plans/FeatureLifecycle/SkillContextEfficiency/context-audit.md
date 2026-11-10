# SkillContextEfficiency — audit and acceptance

Executor input for the [feature plan](SkillContextEfficiency-plan.md), not a shipped skill reference. Baseline captured on 2026-11-10 at revision `5b9b65393b588997e502e11d540ad21b768e12fa`; the working tree was clean before these planning documents. This covers the repository's 25 shipped skills, excluding its template and externally maintained plugins. Task 1's description-only implementation and Task 2 preparation are complete; Gate A real-host validation is recorded, with explicit human acceptance recorded for Gate A.

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

Gate A ran on 2026-11-10 after explicit setup, host-run/refresh, and restoration
approvals. All six acceptance checks passed with build evidence. **Human
decision: accepted. Accepted source fingerprint: `172afc6c4b4e458f12be65a0d988205704ac7a50f26d9eead555edd234792ff2`.** Evaluated/offered
fingerprint: `172afc6c4b4e458f12be65a0d988205704ac7a50f26d9eead555edd234792ff2`. Permission to run tests is not acceptance.

Smoke-record references: each host's base record is its pinned control, `-2`
contains the three acceptance checks, and `-3` contains native QF-NONE plus
non-blocking before observations. Exact paths are inventoried below.

Waivers: none. Claude before-read failures need no waiver because those
observations are explicitly non-blocking. Their raw limits remain recorded.

Before-read observations: Codex backlog visibly loaded all 13,276 CAPTURE-BAR
characters; all four requirements runs loaded all 9,951 format characters.
Codex QF flags read was a 33-line/1,988-character section, not the full
entrypoint. Claude backlog capture and format reads were permission-blocked.
Native QF-NONE passed on both hosts. Worker tool reads are unobservable in
the saved QF parent streams; no after-build read saving is claimed.

Published GLOSSARY-FIRST controls: pass on both hosts using pinned
`5b9b65393b588997e502e11d540ad21b768e12fa` content. Both same-host changed-build
comparisons also pass: no observed regression in these cases, not universal
unaided-routing proof.

Host closing disposition: all validation processes exited. Claude used
session-local plugin directories; no marketplace/plugin install changed.
Codex restored-and-verified: 179 original cache files byte-identical, both
enabled selections restored, original absent marketplace registration
reproduced, persisted hook-trust hashes unchanged. A fresh session loads all
19 pinned original descriptions. Normal approved session/trust history remains.

Feature-owned evidence paths for Task 3: this audit plus the six exact smoke
records in the completed-results inventory below. They remain uncommitted
evidence-only changes explicitly authorized for Task 3 resume and validation/commit;
no directory sweep is authorized.

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

### Task 2 — prepared Gate A operator packet

Prepared on Codex, 2026-11-10, from source HEAD `e419b27`. No evaluating session, smoke run, export, installation, or external fixture creation was performed. The owning unit is FeatureLifecycle's SkillContextEfficiency documentation; no runtime dependency direction changes. Applicable-rules reported SAFE_TO_PROCEED, architecture profile undeclared, with root AGENTS.md and its CLAUDE.md import. Only this audit, task checkboxes, and ignored raw staging inputs are changed.

#### Approval paths and raw inputs

These paths are proposals for the console to present, **not approvals**. Read-only preparation confirmed the external root does not exist. If any path becomes occupied, select a new unused absolute path and obtain approval for that replacement; never overwrite evidence. All external writes, installation, restoration, and real runs remain human/console actions after exact-path approval.

| Purpose | Exact absolute path |
|---|---|
| Source checkout (read only to evaluating sessions) | `C:/dev/cogniva-skills` |
| Ignored raw inputs (never an evaluating cwd) | `C:/dev/cogniva-skills/.plans-staging/SkillContextEfficiency/validation` |
| Proposed external root | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110` |
| Immutable pinned export | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/control-5b9b653` |
| Archive to create | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/control-5b9b653/plugins-5b9b653.zip` |
| Control fixture root | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/control` |
| Description-only fixture root | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/gate-a` |
| Body-refactored fixture root (reserved for Task 5) | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/gate-b` |
| Non-QF output root | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/output` |

The finite fixture paths are `<root>/<phase>/<host>/<scenario>`: phase `gate-a` or `gate-b`, host `claude-code` or `codex`, scenario `discovery`, `glossary-first`, `glossary-missing`, `backlog-direct`, `backlog-dirty`, `requirements-view`, `requirements-status`, `requirements-add`, or `requirements-refine`. The control has only `<root>/control/<host>/glossary-first`. Expand this finite list in the approval request; it authorizes neither other folders nor later cleanup. Each non-QF output path is `<root>/output/<phase>/<host>/<scenario>` (including `control`). Keep session captures and attestation there. No runtime output belongs in source control.

Staged assets: `glossary/docs/glossary/README.md` defines **Quorin Window** as 90 minutes; `glossary/src/Window.ps1` contains a matching implementation and an intentionally undefined **Neral** label. `requirements/docs/REQUIREMENTS.md` has two synthetic entries and independent open-question bullets. `backlog/ledger-input.md` is an empty synthetic ledger, deliberately not named BACKLOG.md in this checkout. `prompts.md` holds identical neutral requests. There are no fixture AGENTS.md/CLAUDE.md files and no copied QF unattended policy. These ignored files are available locally but are not committed; the deterministic recipe below also makes the tracked audit sufficient to reconstruct them if necessary.

Raw content for reconstruction: glossary README has `# Glossary`, `## Quorin Window`, and `A Quorin Window is a 90-minute period reserved for a scheduled handoff.` plus `Used in: scheduling and handoff discussions.`; Window.ps1 has `function Get-QuorinWindowMinutes { return 90 }` and `function Get-NeralState { return 'pending' }`, with comments naming the two labels and no business definition of Neral. Requirements contains Functional Requirements 1.1 Handoff summary (MUST, agreed, display a handoff summary, notes scheduled time) and 1.2 Export summary (SHOULD, draft, export summary, output format undecided); both cite `Synthetic fixture brief, 2026-11-10`, and 1.2 asks `Which output format is needed?` and `Who approves the format?` on separate bullets. The ledger is `# Backlog` followed by `Deferred work for this synthetic fixture.` Reconstruct using the same Markdown field grammar as the staged copy, then hash and use identical bytes for every comparison.

Human-only fixture copying (PowerShell 7, after approval; no sessions below this checkout):

```powershell
$contextCheckout = 'C:/dev/cogniva-skills'
$contextStage = 'C:/dev/cogniva-skills/.plans-staging/SkillContextEfficiency/validation'
$contextRoot = 'C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110'
$contextPhase = 'gate-a' # Task 5 uses gate-b, never reuses gate-a.
$contextScenarios = @('discovery','glossary-first','glossary-missing','backlog-direct','backlog-dirty','requirements-view','requirements-status','requirements-add','requirements-refine')
foreach ($contextHost in @('claude-code','codex')) {
  foreach ($contextScenario in $contextScenarios) {
    $contextFixture = "$contextRoot/$contextPhase/$contextHost/$contextScenario"
    $contextOutput = "$contextRoot/output/$contextPhase/$contextHost/$contextScenario"
    if ((Test-Path -LiteralPath $contextFixture) -or (Test-Path -LiteralPath $contextOutput)) { throw "Occupied path: $contextFixture or $contextOutput" }
    New-Item -ItemType Directory -Path $contextFixture,$contextOutput -ErrorAction Stop | Out-Null
    if ($contextScenario -like 'glossary-*') {
      Copy-Item -LiteralPath "$contextStage/glossary/docs","$contextStage/glossary/src" -Destination $contextFixture -Recurse -ErrorAction Stop
    } elseif ($contextScenario -like 'requirements-*') {
      Copy-Item -LiteralPath "$contextStage/requirements/docs" -Destination $contextFixture -Recurse -ErrorAction Stop
    } elseif ($contextScenario -like 'backlog-*') {
      Copy-Item -LiteralPath "$contextStage/backlog/ledger-input.md" -Destination "$contextFixture/BACKLOG.md" -ErrorAction Stop
    }
    & git -C $contextFixture init -b feature/context-smoke
    if ($LASTEXITCODE -ne 0) { throw 'Fixture git init failed.' }
    & git -C $contextFixture -c user.name=Cogniva -c user.email=cogniva@example.invalid commit --allow-empty -m 'test: initialize context fixture'
    & git -C $contextFixture add --all
    & git -C $contextFixture -c user.name=Cogniva -c user.email=cogniva@example.invalid commit --allow-empty -m 'test: seed neutral context inputs'
    if ($contextScenario -eq 'backlog-dirty') {
      Add-Content -LiteralPath "$contextFixture/BACKLOG.md" -Value "`nPre-existing operator note; preserve this uncommitted line."
    }
    # Record git status, input SHA256s and ancestor/global instruction inspection in contextOutput.
    # No remote is added. No repository policy/instruction files are copied.
  }
}
# Separate pristine control copies; only loaded plugins differ from the Gate A pair.
foreach ($contextHost in @('claude-code','codex')) {
  $contextFixture = "$contextRoot/control/$contextHost/glossary-first"
  $contextOutput = "$contextRoot/output/control/$contextHost/glossary-first"
  if ((Test-Path -LiteralPath $contextFixture) -or (Test-Path -LiteralPath $contextOutput)) { throw 'Occupied control path; obtain a new approval.' }
  New-Item -ItemType Directory -Path $contextFixture,$contextOutput -ErrorAction Stop | Out-Null
  Copy-Item -LiteralPath "$contextStage/glossary/docs","$contextStage/glossary/src" -Destination $contextFixture -Recurse -ErrorAction Stop
  & git -C $contextFixture init -b feature/context-smoke
  & git -C $contextFixture -c user.name=Cogniva -c user.email=cogniva@example.invalid commit --allow-empty -m 'test: initialize context fixture'
  & git -C $contextFixture add --all
  & git -C $contextFixture -c user.name=Cogniva -c user.email=cogniva@example.invalid commit -m 'test: seed neutral context inputs'
  if ($LASTEXITCODE -ne 0) { throw 'Control fixture preparation failed.' }
}
```

Use the same raw hashes, fresh repo state, model/version/effort, host surface, permission configuration, and inherited instruction environment for each old/new pair. Different absolute fixture paths prevent state carryover; record that unavoidable cwd difference. Do not seed an expected-answer prompt or a glossary protocol. Capture all human answers for the missing-term session and stop at the proposal unless the human explicitly confirms the synthetic write.

#### Pinned control export and two-plugin launches

Read-only verification succeeded: `git cat-file -t 5b9b65393b588997e502e11d540ad21b768e12fa` returned `commit`; `git ls-tree <ref> plugins` returned tree `f468c5cc26ce5ec88dfa6da264fb0259caebf5e2`. This available control does not depend on a missing Claude cache. The earlier generic export recipe is instantiated as follows; only the human runs it after the export-path approval:

```powershell
$contextCheckout = 'C:/dev/cogniva-skills'
$contextControlRef = '5b9b65393b588997e502e11d540ad21b768e12fa'
$contextControlRoot = 'C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/control-5b9b653'
$contextControlArchive = "$contextControlRoot/plugins-5b9b653.zip"
& git -C $contextCheckout cat-file -e ($contextControlRef + ':plugins')
if ($LASTEXITCODE -ne 0) { throw 'Pinned plugins tree unavailable; do not substitute HEAD.' }
if (Test-Path -LiteralPath $contextControlRoot) { throw 'Obtain approval for a fresh export path.' }
New-Item -ItemType Directory -Path $contextControlRoot -ErrorAction Stop | Out-Null
& git -C $contextCheckout archive --format=zip "--output=$contextControlArchive" $contextControlRef plugins
if ($LASTEXITCODE -ne 0) { throw 'Pinned export failed.' }
Expand-Archive -LiteralPath $contextControlArchive -DestinationPath $contextControlRoot -ErrorAction Stop
```

Preferred interactive Claude CLI, as the README's session-local loading extension to both plugins. After changing cwd to the appropriate approved fixture, start a fresh process (never resume a prior behavioral session):

```powershell
# Old control: cwd .../control/claude-code/glossary-first
claude --plugin-dir 'C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/control-5b9b653/plugins/cogniva-dev' --plugin-dir 'C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/control-5b9b653/plugins/cogniva-skills' --setting-sources project,local
# Gate A/B: cwd .../<gate-a|gate-b>/claude-code/<scenario>
claude --plugin-dir 'C:/dev/cogniva-skills/plugins/cogniva-dev' --plugin-dir 'C:/dev/cogniva-skills/plugins/cogniva-skills' --setting-sources project,local
```

These use the same flags/settings; the old control differs only in source directories. Record the actual model and effort selected, keep them fixed, and capture the launch command/startup catalog. No need to change the live Claude marketplace. Task 1 already changed bytes exposed through its current directory source; closing a local test does not restore old bytes in that live source.

Codex control shortcut: before replacing any installed copy, compare the actual loaded `C:/Users/canuc/.codex/plugins/cache/cogniva/cogniva-dev/0.11.0` and `C:/Users/canuc/.codex/plugins/cache/cogniva/cogniva-skills/0.8.1` instruction trees to the pinned fingerprint and per-plugin file sets. Record differences, paths, manifests and original enabled selection. A numeric version alone is insufficient. If they match, run the control from its pristine external fixture first. If they do not match, record an unavailable/unattested non-blocking Codex control or obtain a separately approved supported pinned installation route; never substitute the live branch and call it old. The prepared Claude archive control remains available.

#### Loaded-build attestation worksheet

Fill this in Observations in each actual standard record, using startup metadata, a separate equivalent-configuration probe, or a post-behavior query. Never ask a neutral glossary session about skill availability, descriptions, or invocation before its test.

| Field | Required evidence (currently pending) |
|---|---|
| Intended build | Full source commit, role control/description-only/after-body, source instruction fingerprint |
| Host launch | Exact command, cwd, host version/surface, model/effort, settings sources, timestamp/session ID; no credential dumps |
| Both plugins loaded | Launch/install transcript plus actual loaded cogniva-dev and cogniva-skills roots and enabled versions |
| Content match | File lists and normalized hashes for **each** plugin's skill Markdown and agents/openai.yaml, compared with intended source; missing/extra files listed |
| Discovery metadata | Actual catalog source and descriptions/paths (especially glossary and representative entries from both plugins), restrictions/manual-only pairs; distinguish available user menu from model-discoverable list |
| Configuration equivalence | Probe and behavior session used identical plugin files/settings/model; time between them and any changes; no glossary priming |
| Trace | Raw transcript/tool calls, read extent and ordering, final answer, host prompts, human replies, errors and exit state |
| Closing state | Local session closed/no persistent change, restored-and-verified, retained by explicit human decision, or pending/failed restoration |

Fingerprint recipe above, executed read-only on 49 instruction files in preparation: description-only source `172afc6c4b4e458f12be65a0d988205704ac7a50f26d9eead555edd234792ff2`; pinned baseline `62d3cb5ead5ded74464ade31c57eeb74b0e1974a7248a5bd4857ac382046111d`. These are intended-source identities, **not session attestations**. The pinned recipe iterated `git ls-tree -r --name-only <ref> plugins`, selected the same skill Markdown and agents/openai.yaml patterns, decoded `git show <ref>:<path>` as UTF-8-sig with universal newline normalization, and fed relative paths/text plus NUL delimiters to SHA256. For loaded caches or exports, put each plugin beneath the corresponding `plugins/<name>` relative prefix before applying the same recipe; also compare per-plugin lists/hashes so one correct plugin cannot mask the other. Capture manifests separately for real version metadata. Recompute immediately before acceptance; documentation-only changes do not affect this fingerprint.

Read-only contamination inspection: `C:/Users/canuc/.codex/AGENTS.md` and `C:/Users/canuc/.claude/CLAUDE.md` contain external-write and execute-feature default rules, no glossary-first rule. No `C:/AGENTS.md`, `C:/CLAUDE.md`, `C:/Users/AGENTS.md`, `C:/Users/CLAUDE.md`, `C:/Users/canuc/AGENTS.md`, or `C:/Users/canuc/CLAUDE.md` was found. The current checkout's Claude memory text had no glossary/unfamiliar-term match; that project memory must not be carried into the external fixture. `C:/Users/canuc/.codex/memories` is absent; a read-only URI connection to `memories_1.sqlite` failed with `sqlite3.OperationalError: unable to open database file`, so stored/retrieved memory is unobservable in preparation. This worker's session already received glossary-related discovery instructions and is **not an evaluation session**. The external AppData/Local/Temp ancestor files, managed settings, new project-memory mapping and Codex retrieved memories still require inspection/capture at actual startup. Record any glossary-first instruction as contamination and any unavailable memory evidence as an attribution limitation; neither establishes successful description-only activation. Do not edit global memory to improve the result.

#### Neutral prompts and outcome criteria

Use the staged `prompts.md` verbatim on both hosts; only explicit skill command syntax differs: Claude `/cogniva-dev:backlog` or `/cogniva-skills:project-requirement`; Codex `$backlog` or `$project-requirement`. Run each named scenario in its own fresh session/copy except the deliberate repeated backlog request. The following are evaluator criteria, not text to prepend to behavioral prompts.

| Scenario | Exact neutral request / procedure | Evidence and check |
|---|---|---|
| DISCOVERY | `List the Cogniva skills available in this session, their actual source paths and discovery descriptions, and any invocation restrictions exposed by startup/catalog metadata. Without executing them, identify which skill fits each request: report feature progress; capture work for later; maintain requirements; explain an unfamiliar project term. State whether a small-fix request or a design request permits automatic invocation, and which explicit commands remain user-invoked only. Do not perform any actions.` | Separate probe only. Compare catalog to the 25/19 inventory and six paired manual-only entries; both plugin roots and actual descriptors. Expect feature-status, backlog, project-requirement, glossary matching; quick-fix/plan-feature still require explicit user request or approved dispatch. Unavailable catalog evidence is not proof of a pass. |
| GLOSSARY-FIRST | `How many minutes does a Quorin Window cover in this project?` | Observe glossary activation and definition lookup before implementation/file search for the term. Correct answer alone is insufficient. Same request/input/environment for the pinned control and Gate A. |
| GLOSSARY-MISSING | `What does the Neral state mean for this project's handoff process?` | Observe missing lookup, clarification and offer to document, with no invented definition or unconfirmed write. Interactive questions must remain possible. The operator may answer `I have not defined it yet.`; retain that answer and all proposals. |
| BACKLOG-DIRECT | Explicit backlog command plus `Add exporting the handoff summary as CSV to the backlog for later.` Repeat the same request after completion. In the independent dirty copy request `Add a printable handoff summary to the backlog for later.` | Observe loose capture, `because:human later`, coverage/dedup stop, preservation of dirty note and dirty-target commit behavior, exact file-scoped commit policy. Record the full CAPTURE-BAR.md read or actual Test 1 extent, not an assumption. Before observations are diagnostic. |
| REQUIREMENTS-READ | Explicit project-requirement command with `view`, then `status` in its separate copy; independent `add "The system MUST print the handoff summary. Source: synthetic stakeholder request on 2026-11-10."`; independent `refine "The handoff summary should export as CSV. Source: synthetic stakeholder decision on 2026-11-10."` | View/status correctly report existing records. Add/refine preserve grammar, source, severity, independent questions and confirmation before writes. Operator records all clarification/confirmation replies. Observe REQUIREMENTS-FORMAT.md read extent separately for read-only and mutation paths. |
| QUICK-FIX-FLAGS | Existing QF-NONE driver only, below. | Native assertions and full headless transcript; no custom fixture, prompt or outcome implementation. |

#### QUICK-FIX-FLAGS before observations

Source inspected: existing `scenarios/QF-NONE/scenario.json` requests `"Make Add-Numbers accept an optional third number $c (default 0) and add a test for it" commits=none`. Driver prefixes `/cogniva-dev:quick-fix` or `$quick-fix`. Assertions remain 0 new commits, branch `feature/smoke`, changes to `src/Calc/Calc.ps1` and `tests/Calc.tests.ps1`, unrelated work preserved, complete handoff including `READY FOR REVIEW` and `Integration: not performed`. Do not copy this fixture's AGENTS.md to glossary fixtures.

Exact distinct driver roots (the driver creates `<FixtureRoot>/QF-NONE`; OutDir is independent):

| Phase/host | FixtureRoot | OutDir |
|---|---|---|
| Before Claude | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/qf-before-claude` | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/output/qf-before-claude` |
| Before Codex | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/qf-before-codex` | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/output/qf-before-codex` |
| After Claude | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/qf-after-claude` | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/output/qf-after-claude` |
| After Codex | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/qf-after-codex` | `C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110/output/qf-after-codex` |

Human-only PowerShell 7 commands, after approval/loading; run from the checkout only as a driver process, which starts the **evaluating agent** inside its newly built external fixture:

```powershell
$contextDriver = 'C:/dev/cogniva-skills/plugins/cogniva-dev/tests/host-smoke/invoke-host-smoke.ps1'
$contextRoot = 'C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110'
$contextDev = 'C:/dev/cogniva-skills/plugins/cogniva-dev'
$contextSkills = 'C:/dev/cogniva-skills/plugins/cogniva-skills'
# Review this no-write preview first; then repeat exactly without -DryRun for the actual bounded run.
& $contextDriver -AgentHost claude-code -Scenario QF-NONE -PluginDir $contextDev -ExtraArgs @('--plugin-dir',$contextSkills) -FixtureRoot "$contextRoot/qf-before-claude" -OutDir "$contextRoot/output/qf-before-claude" -Covers quick-fix -PluginSource 'local marketplace from C:/dev/cogniva-skills @ e419b27; description-only' -DryRun
& $contextDriver -AgentHost codex -Scenario QF-NONE -FixtureRoot "$contextRoot/qf-before-codex" -OutDir "$contextRoot/output/qf-before-codex" -Covers quick-fix -PluginSource 'local marketplace from C:/dev/cogniva-skills @ e419b27; description-only' -DryRun
```

Before actual execution update PluginSource to the true current commit and record the instruction fingerprint. For Task 5 use the same arguments with `qf-after-claude`/`qf-after-codex` and the after build identity; never reuse a before root. Use the README's `-CodexApproveForMe` only if the operator chooses that supported permission route and it is authorized; record it, with permission required before the first Git write. A denied approval remains blocked without retry. Keep QF-NONE.final.txt, QF-NONE.transcript.jsonl, QF-NONE.assert.txt, any stderr and the driver's real RECORD path. Inspect the transcript for execute-feature/SKILL.md/Flags (and later COMMIT-POLICY.md), including subagent calls, before classifying a read as unobservable. Unavailable/read-failed before observations do not block either gate or later work and cannot establish measured savings. Do not turn native QF failures into passes when annotating the read observation.

#### Installation, refresh and Restoration worksheet

These are the README's persistent alternatives, not the preferred Claude CLI route. CLI help was inspected read-only on 2026-11-10: Codex supports `plugin add`, `plugin remove` (which uninstalls and removes that plugin's local cache), and marketplace add/list/remove; Claude supports scoped install/uninstall with `--keep-data`, marketplace add/remove, and list. No manual cache deletion, version edits, or worker installation is authorized. The actual host binary is `C:/Users/canuc/.vscode/extensions/openai.chatgpt-26.1021.22027-win32-x64/bin/windows-x86_64/codex.exe`; re-resolve the newest extension if it changes. Help emitted a home/PATH-alias warning in this sandbox; help is not an install test.

Before any persistent change, the human records commands/output for `claude plugin marketplace list`, `claude plugin list --json`, Codex `plugin marketplace list` and `plugin list`, actual enabled state, scopes, versions and content hashes. Inspect only Cogniva keys in config; omit credentials/unrelated settings. Read-only planning/preparation found Claude's cogniva directory source at `C:/dev/cogniva-skills`, install records 0.2.1/0.7.2 under its cache but those recorded directories absent, and Codex's candidate cache versions 0.11.0/0.8.1. These are not substitutes for a fresh pre-test snapshot.

Exact persistent paths to present for installation **and separately for restoration**: `C:/Users/canuc/.codex/config.toml`, `C:/Users/canuc/.codex/plugins` (two Cogniva plugin caches, marketplace metadata and supported installer state), `C:/Users/canuc/.codex/.hook-trust` if trust is changed; for Claude VS Code user-scope route `C:/Users/canuc/.claude/settings.json`, `C:/Users/canuc/.claude/plugins/known_marketplaces.json`, `C:/Users/canuc/.claude/plugins/installed_plugins.json`, and `C:/Users/canuc/.claude/plugins/cache/cogniva`. If the host reports another write target, enumerate it and obtain exact-path approval before continuing. Fixture session state under each host's project/session storage also needs to be included in the concrete run approval. No blanket approval is implied by this list.

Codex branch installation or same-version refresh before **each** persistent checkpoint, including Gate B:

```powershell
$contextCodex = 'C:/Users/canuc/.vscode/extensions/openai.chatgpt-26.1021.22027-win32-x64/bin/windows-x86_64/codex.exe'
# After old-copy control, state capture and exact-path approval:
& $contextCodex plugin remove cogniva-dev@cogniva
& $contextCodex plugin remove cogniva-skills@cogniva
& $contextCodex plugin marketplace remove cogniva
& $contextCodex plugin marketplace add 'C:/dev/cogniva-skills'
& $contextCodex plugin add cogniva-dev@cogniva
& $contextCodex plugin add cogniva-skills@cogniva
# NEW session from the external fixture; /hooks if changed hashes require trust.
```

Removing/re-adding via the supported plugin manager is the deliberate reinstall, not an instruction to delete cache directories. Stop and preserve errors if a command fails. Recheck actual loaded content from **both** plugins; an unchanged version label or marketplace pointer cannot attest refreshed bytes.

Claude VS Code branch route (only if deliberately chosen and approved; original scope must be recorded): panel `/plugin marketplace remove cogniva`, `/plugin marketplace add C:/dev/cogniva-skills`, `/plugin install cogniva-dev@cogniva`, `/plugin install cogniva-skills@cogniva`, reload window. For a same-version refresh, use supported CLI from the matching installation scope before reloading:

```powershell
claude plugin uninstall cogniva-dev@cogniva --scope user --keep-data
claude plugin uninstall cogniva-skills@cogniva --scope user --keep-data
claude plugin install cogniva-dev@cogniva --scope user
claude plugin install cogniva-skills@cogniva --scope user
```

For the captured current Claude directory pointer, no marketplace swap is needed; reinstall only if the persistent route is chosen. Do not remove declarations from every scope inadvertently. If the pre-test source differs, scoped `claude plugin marketplace remove cogniva --scope user` and `claude plugin marketplace add '<captured-original-source>' --scope user` restore it. The README's published return source is `cogniva/cogniva-skills`; the actual recorded original source takes precedence.

Restoration is scheduled immediately after Gate A and after Gate B, including failure, timeout or early stop, with separate exact-path approval. Codex: remove both tested plugins, `plugin marketplace remove cogniva`, `plugin marketplace add '<captured-original-source>'` (README published fallback `https://github.com/cogniva/cogniva-skills.git`), then `plugin add cogniva-dev@cogniva` and `plugin add cogniva-skills@cogniva`; start a new session and verify original marketplace, scope/enabled selection, versions and content identities. Claude persistent route: uninstall both with captured scope/keep-data, restore the captured marketplace as above, reinstall both, restore captured enabled selection using the host UI, reload and verify. If a plugin was originally absent, leave it absent. Neither supported CLI exposes a version pin in the inspected add/install help; if the original version/content cannot be reproduced by reinstalling that source, record restoration incomplete and obtain an explicit human decision or a supported recovery plan—do not claim success or hand-edit caches. Captured original Claude pointer already targets edited live bytes; restoring that pointer is a configuration no-op, not an old-build byte restoration.

| Host/checkpoint | Pre-test source, scope, enabled plugins, versions/hashes | Approved install paths/commands | Approved restore paths/commands | Actual ending state and verification / explicit retention decision |
|---|---|---|---|---|
| Claude Gate A | pending | Prefer local flags; persistent route not selected | pending or no persistent change | not started |
| Codex Gate A | pending | pending | pending | not started |
| Claude Gate B | pending | Fresh two-dir local process, or explicit two-plugin reinstall | pending or no persistent change | not started |
| Codex Gate B | pending | Explicit two-plugin reinstall even if versions match | pending | not started |

#### Standard record template and exact evidence inventory

Only after an actual attempted run, create a file using the [standard README](../../../host-parity/smoke/README.md). At preparation no date-matching records existed. Proposed reservations, **not created files or claims of runs**: `docs/host-parity/smoke/2026-11-10-claude-code-cli.md` (control), `2026-11-10-claude-code-cli-2.md` (description-only), `2026-11-10-claude-code-cli-3.md` (before observations); corresponding `2026-11-10-codex-cli.md`, `-2.md`, `-3.md`. Use the real run date and next unused suffix; the driver chooses/prints the QF record separately, which must be added by exact path. Never collide with or overwrite an existing record. Different build roles need separate headers. Actual records may aggregate fresh sessions from the same build/host/surface with individual session references; a failing observation may limit the whole record's parity eligibility.

Copy this template **inside a real record only after a run**; replace every placeholder from actual metadata, include the checkpoint role and fingerprint in Observations, and include only scenarios attempted or explicitly noted not-run:

```markdown
# Smoke record <actual-date-host-surface-suffix>
Agent host: <Claude Code or Codex>
Agent host version: <actual version>
Surface: <CLI or VS Code or Desktop>
OS: Windows 11 <actual build>
Plugin versions: cogniva-dev <actual loaded version>, cogniva-skills <actual loaded version>
Plugin source: <actual source path and commit; pinned export or installed marketplace>
Date: <actual YYYY-MM-DD>
Covers: <eligible IDs: install-cogniva-dev, install-cogniva-skills, glossary, backlog, quick-fix, project-records>

## Scenarios

| Scenario | Result | Assertion output | Notes |
|---|---|---|---|
| <DISCOVERY / GLOSSARY-FIRST / GLOSSARY-MISSING / GLOSSARY-FIRST-PUBLISHED / BACKLOG-DIRECT / REQUIREMENTS-READ / native QF-NONE> | <pass / fail / not-run> | <real observed assertion, failure or unavailability> | <session/transcript reference; build attestation; read extent; scope limits> |

## Observations

- Build role/checkpoint and intended source fingerprint: <actual>.
- Two-plugin loading/content evidence: <worksheet and capture references>.
- Model/settings/inherited memory, priming and contamination: <actual>.
- Read evidence: <whole-file / section with observed extent / none / unobservable, tool-call references>.
- Approval/trust prompts, operator answers, errors and surprises: <actual>.
- Host closing/restoration/retention disposition: <actual>.
```

For controls, `Plugin source` names pinned `5b9b653` and row GLOSSARY-FIRST-PUBLISHED; never put them under a new-build header. For QF use the driver's native header/row/output and supplement missing second-plugin/build/read evidence in Observations. Keep failures even when waived. At preparation there were no real records. The completed-results inventory below now names the six actual records and their row/output evidence; Task 3 must validate exactly that inventory. The tracked audit is the only prepared template/index; no unrun smoke files are created.

#### Gate A pending acceptance and waivers

Source offered for human evaluation: `172afc6c4b4e458f12be65a0d988205704ac7a50f26d9eead555edd234792ff2`. Human decision: **accepted**. Accepted fingerprint: `172afc6c4b4e458f12be65a0d988205704ac7a50f26d9eead555edd234792ff2`. Actual smoke records: six, inventoried below. Acceptance cells now contain real build-attested passes. Before-read failures and runtime limits remain unchanged; no human acceptance is inferred from permission to run tests.

| Check ID | Host/scenario | Raw result | Real standard record/row + loaded-build evidence | Human waiver reason and accepted limitation (if any) |
|---|---|---|---|---|
| GATE-A-CLAUDE-DISCOVERY | Claude Code / DISCOVERY | pass | `2026-11-10-claude-code-cli-2` / DISCOVERY; actual loading evidence in Observations | none; accepted by human |
| GATE-A-CLAUDE-GLOSSARY-FIRST | Claude Code / GLOSSARY-FIRST | pass | `2026-11-10-claude-code-cli-2` / GLOSSARY-FIRST; actual loading evidence in Observations | none; accepted by human |
| GATE-A-CLAUDE-GLOSSARY-MISSING | Claude Code / GLOSSARY-MISSING | pass | `2026-11-10-claude-code-cli-2` / GLOSSARY-MISSING; actual loading evidence in Observations | none; accepted by human |
| GATE-A-CODEX-DISCOVERY | Codex / DISCOVERY | pass | `2026-11-10-codex-cli-2` / DISCOVERY; actual loading evidence in Observations | none; accepted by human |
| GATE-A-CODEX-GLOSSARY-FIRST | Codex / GLOSSARY-FIRST | pass | `2026-11-10-codex-cli-2` / GLOSSARY-FIRST; actual loading evidence in Observations | none; accepted by human |
| GATE-A-CODEX-GLOSSARY-MISSING | Codex / GLOSSARY-MISSING | pass | `2026-11-10-codex-cli-2` / GLOSSARY-MISSING; actual loading evidence in Observations | none; accepted by human |

| Non-blocking observation | Claude Code result/record/read extent | Codex result/record/read extent | Interpretation |
|---|---|---|---|
| BACKLOG-DIRECT before | not-run / Claude -3 / no CAPTURE-BAR read observed; writes blocked | pass / Codex -3 / whole CAPTURE-BAR visible | No after-build saving yet; Claude capture incomplete |
| QUICK-FIX-FLAGS before (native QF-NONE) | pass / Claude -3 / no parent Flags read; worker reads unobservable | pass / Codex -3 / 33-line section, 1,988 chars; worker reads unobservable | Preserve native passes; full-file case is only a separate assumption |
| REQUIREMENTS-READ before (view/status + add/refine) | fail / Claude -3 / format reads attempted but denied | pass / Codex -3 / full format visible in all four | Claude outputs/proposals retained; no loaded-format baseline there; persistence not exercised |
| GLOSSARY-FIRST pinned control | pass / Claude control record | pass / Codex control record | Old pass/new pass per host; bounded matched observation |

The first three observation rows represent six per-host before observations, with subruns retained; controls add two. They require no waiver to progress. Old pass/new fail signals a possible regression; old fail/new fail is a baseline unaided-routing limitation, never automatic acceptance. Gate A still requires the six new-build checks to be addressed by real attested passes or explicit per-row waivers and an explicit human decision for this fingerprint. Waivers do not prove preserved behavior, measured savings or verified parity. Console must record host closing disposition, the exact Task 3 evidence-file inventory, and any authorization to resume with those named evidence-only edits dirty. Task 2 completion means preparation only and the executor stops at this gate.

#### Verification of preparation

The ignored `verify-preparation.ps1` check was written first and run before inputs existed; it failed on missing `glossary/docs/glossary/README.md` (exit 1). It checks the finite raw asset list, operator-packet sections and Gate A identifiers, and ignore status; it is a local material check, not host-smoke evidence. Re-run it after preparation together with `git diff --check`, local pinned-tree readability, raw-file inventory, command syntax/driver argument review and standard-record contract review. No host run, DryRun driver run, external export or installation is performed by the worker. Final mechanical results are recorded below before the task commit.

Final preparation verification: `verify-preparation.ps1` passed (exit 0), including all PowerShell fence syntax and the six acceptance IDs; `git check-ignore -- .plans-staging/SkillContextEfficiency/validation/` returned that ignored directory (exit 0); `git diff --check` passed. Every local Markdown link resolved. Read-only checks reconfirmed the pinned commit/tree, unchanged 49-file source fingerprint, absent proposed external root, and no newly created dated smoke records. Driver arguments were checked against its current parameter block, QF-NONE prompt/assertions against scenario.json, and record headers/table/results against both READMEs. No host-smoke tests were run by the worker. Gate A remains pending and no runtime savings are claimed.

Raw staging SHA256s (copy identical bytes into each applicable fixture, then verify again externally):

| Relative raw input | SHA256 |
|---|---|
| `backlog/ledger-input.md` | `015f3ce1629f6d7eec3456d303404f78cc69e6e267b91ba041744e22bf05529f` |
| `glossary/docs/glossary/README.md` | `488c5ec0776521d3d145c7e574cfee5061f97999fe3eb870d2b1d43859d8411c` |
| `glossary/src/Window.ps1` | `d71eb8dc16d4380da154104d0116627248e244362600325c3c2dfcf710b4c90b` |
| `requirements/docs/REQUIREMENTS.md` | `1c4ea10f2b36480f7ffe7f9cdce78ddc3f8d033d34b16eee1d90af0f278416a7` |
| `prompts.md` | `91c88f53c239726feb8f4943675d84bab1609ba0375a89a6d075cc6c098a9c41` |

### Gate A — approved setup completed (2026-11-10)

The human explicitly answered **Approve Gate A setup** for the concrete root
`C:/Users/canuc/AppData/Local/Temp/cogniva-skill-context-efficiency-20261110`
and the enumerated control export, Gate A fixtures, before-QF roots, and
matching outputs. This approves setup only: plugin configuration changes,
behavioral runs, and acceptance remain separate. It does not approve Gate B
creation, cleanup, or changes to other external paths.

The console exported the pinned plugins tree and created 20 separate neutral
repositories: nine Gate A scenarios per host and one glossary control per host.
Input copies matched their raw SHA256s before intentionally dirtying the two
backlog-dirty copies. Each repository is on `feature/context-smoke`, has no
remote, and is clean except those two designated dirty ledgers. No fixture
contains AGENTS.md/CLAUDE.md; no such instruction file was found along its
ancestor chain. Per-fixture starting metadata is in the matching approved
`output/<phase>/<host>/<scenario>/setup-manifest.json` directories. QF-before
roots and outputs are empty reservations for the unchanged driver; no QF
scenario was generated or run. Gate B was not created.

All 179 exported files match the pinned Git contents after CRLF normalization;
178 files received Git archive's checkout line-ending conversion. An initial
byte-identical assertion exposed that conversion, then the normalized comparison
passed. The 49-file pinned instruction fingerprint matches
`62d3cb5ead5ded74464ade31c57eeb74b0e1974a7248a5bd4857ac382046111d`.
Read-only fixture Git checks from the sandbox account encountered ownership
protection; running those checks under the creating user context passed. No
safe.directory or user configuration change was made.

Read-only cache comparison also matched all 41 cogniva-dev and eight
cogniva-skills instruction files in the candidate Codex caches to the pinned
baseline, with no missing, extra, or differing instruction files. This qualifies
their source content for the optional control shortcut, not a session loading
attestation. Both plugin selections are enabled. The current Codex configuration
has no explicit `marketplaces.cogniva` entry, so actual registered source and
restoration feasibility still need capture through the supported manager before
any install. No host was launched, no plugin was installed/refreshed, and no
standard smoke record or acceptance/waiver was created. Gate A remains pending.

### Gate A — completed runs, restoration, and pending acceptance (2026-11-10)

The human separately answered **Approve Gate A runs and Codex refresh** and
**Approve restoring the captured original state**. Approved paths included
normal host state under `C:/Users/canuc/.claude`, `C:/Users/canuc/.claude.json`,
and `C:/Users/canuc/.codex`, the two Codex Cogniva installs/configuration/trust,
and the existing approved fixture/output tree. These authorize runs and
restoration, **not build acceptance**, Gate B setup/install, or cleanup.
The release-offer deferral to Task 6 remains in force.

All six Gate A acceptance scenarios have real passes in the two -2 records.
On both hosts, old and new glossary-first sessions used glossary instructions
then glossary data before implementation search, answering 90 minutes. Both
interactive missing-term sessions looked up the missing term, then searched
implementation, asked its intended meaning, and offered a glossary entry or
definition after clarification. No definition/write confirmation was supplied.
All discovery/glossary and requirements fixtures remain clean. Models and
settings are recorded from runtime: Claude Code 2.1.187,
claude-opus-4-8[1m], high effort; Codex 0.164.0-alpha.11.1, gpt-6.1-sol,
high effort. Exact session IDs, launches, source paths and artifacts are in
the standard records, not inferred from version labels.

Codex actual startup catalogs match all 19 target descriptions exactly and
omit the same six manual-only skills; both refreshed source trees match the
intended 41+8 instruction files. Its discovery reply's 38 Cogniva entries
include 19 unrelated analysis-plugin entries, excluded from target counts.
Claude startup identifies both inline roots and all 25 target user commands;
the separate probe exposes 19 discoverable entries and expected matching.
The probe's external-path guesses were denied, and its path/restriction prose
is not ground truth: actual startup paths and paired source metadata are used.
Its abbreviated glossary quotation does not replace the two-sentence source.

Fresh Claude auto-memory directories were empty/absent. Inspected global and
ancestor files contain no extra glossary-first rule. Codex startup-message
inspection found only scenario cwd names outside skill discovery, not an
additional glossary protocol. Visible paths include glossary-first/missing,
a shared contextual cue in old/new runs. These small matched cases do not
establish universal unaided routing or a causal improvement from shortening.

Launcher failures are retained separately: PowerShell PTY exited before a
Claude session was created; a cmd positional prompt was truncated and that
session was closed. A fresh interactive session then received the intact
neutral question via terminal input. Codex interactive launch reported an
incomplete local daemon package and succeeded with its prescribed
`--no-daemon` fallback. Synthetic fixture trust prompts were accepted. Codex
continued without changing persisted hook trust and emitted plugin-content
hook-approval failures; these records do not claim hooks passed.

Before observations remain non-blocking. Codex captured one CSV item with
`because:human later` in canonical `docs/plans/BACKLOG.md`; the same-session
repeat added no item or commit. Its dirty-ledger run preserved the operator
note and made no commit. Complete CAPTURE-BAR text, 13,276 normalized
characters, is visible in both traces. The scratch repeat launcher initially
checked only root BACKLOG.md; the console found the canonical capture and
ran the real duplicate observation once. Claude capture was host-permission
blocked; its proposals/dirty-target rule remain visible but capture/dedup
are not certified. No CAPTURE-BAR read was observed there.

Requirements view/status outputs are correct on both hosts. Add/refine stop
at proposals/confirmation and all four fixtures per host remain clean;
mutation persistence/complete grammar is not certified. Codex visibly received
all 9,951 format characters on each path. Claude attempted those reads but
was denied; its failed before-read observation cannot establish loaded-text
savings. No waiver is required for this non-blocking observation.

Native QF-NONE passes on both hosts with the unchanged driver, prompt and
assertions. Codex parent received Flags lines 34–66: 33 source lines, 1,988
normalized characters without rg wrappers. This is a section observation,
not the entire 16,342-character current entrypoint. Full Flags is separately
2,605 characters as the section-only source assumption. Claude parent shows
no entrypoint/Flags read. Saved parent streams contain no worker tool calls;
downstream read extents remain unobservable. Mandatory companions/overlays
still count in later whole-invocation comparisons; no after-build read saving,
billing or frequency measurement is claimed.

All validation processes exited before restoration. Original Codex state had
two enabled caches and no registered cogniva marketplace. The console captured
all 165+14 original files plus narrow settings/trust inventories, prepared a
recovery marketplace from exact original bytes and the pinned marketplace
manifest, and refreshed through the supported manager. Restoration used that
manager and removed the temporary registration to reproduce original absence.
All 179 original SHA256s, versions, enabled selections and hook-trust file
hashes match. Fresh session `01a1c6e7-7a5e-7513-a285-610d11fe4f5c` loads all
19 original descriptions. Proof is in approved
`output/gate-a/codex/discovery/restore-verification.json`, restore-log.txt,
and restoration-probe.session-rollout.jsonl. Claude marketplace/plugin
selections were not changed. Approved session/trust history remains; no
outside-root cleanup was performed or authorized.

**Exact Task 3 evidence-only inventory (uncommitted, accepted for task-scoped validation/commit):**

- `docs/plans/FeatureLifecycle/SkillContextEfficiency/context-audit.md`
- [Claude pinned control](../../../host-parity/smoke/2026-11-10-claude-code-cli.md)
- [Claude Gate A acceptance](../../../host-parity/smoke/2026-11-10-claude-code-cli-2.md)
- [Claude before observations and QF-NONE](../../../host-parity/smoke/2026-11-10-claude-code-cli-3.md)
- [Codex pinned control](../../../host-parity/smoke/2026-11-10-codex-cli.md)
- [Codex Gate A acceptance](../../../host-parity/smoke/2026-11-10-codex-cli-2.md)
- [Codex before observations and QF-NONE](../../../host-parity/smoke/2026-11-10-codex-cli-3.md)

No other evidence path or runtime scratch may be swept into that commit.
Human decision: **accepted**, fingerprint `172afc6c4b4e458f12be65a0d988205704ac7a50f26d9eead555edd234792ff2`, with **no waivers**.
On 2026-11-10 the human answered **Accept Gate A and continue** to the question
that explicitly named this fingerprint, all six acceptance passes, retained
before-read failures/measurement limits, verified Codex restoration, and all
seven evidence-only paths above. This explicitly authorizes resuming Task 3
with exactly those paths dirty and validating/committing them with the task.
Task 3 must validate this decision and exact inventory before body edits;
permission to continue does not promote limited observations into broader
runtime or parity claims.

### Task 3 — coverage and shared commit definitions (2026-11-10)

Before body edits, recomputed the 49-file source instruction fingerprint as
`172afc6c4b4e458f12be65a0d988205704ac7a50f26d9eead555edd234792ff2`, exactly
the human-accepted description-only build. Validated all six acceptance checks
as build-attested passes in the two -2 records, with no waivers, and checked
all six exact smoke paths inventoried above against the standard record
headers, scenario rows, build roles, loaded-source evidence and limitations.
The two pinned controls remain non-blocking pass/pass comparisons; the before
observations preserve Claude's not-run backlog/failed format reads, both
native QF-NONE passes, and unobservable downstream reads. The recorded Codex
restoration is restored-and-verified; Claude made no persistent install change.
No new host session, restoration, external write or cleanup was performed by
this worker. Earlier pending statements in preparation/run records describe
those earlier times; the later explicit human acceptance governs Task 3.

Only Test 1 coverage moved to `backlog/COVERAGE.md`. Every coverage surface,
the ground-not-wording duplicate rule and covered/no-capture outcome remain.
The helper returns an outcome; CAPTURE-BAR retains its Test 1 heading/link and
owns proceeding to Test 2. Direct capture reads the helper without routing
through intent tests. Tests 0/2/3 and all capture/confirmation/placement/commit
conditions remain. Shared commit definitions moved from execute-feature Flags
to `COMMIT-POLICY.md`, required before affected writes by both entrypoints.
Authority/default summaries, tasks/plan flags, overlays, execution steps,
landing, structural checks, scripts, Workflow and worker contracts stay in place.

Normalized source comparisons count each prescribed instruction file once:

| Scenario/source-read assumption | Before characters | After characters | Reduction |
|---|---:|---:|---:|
| BACKLOG-DIRECT: entrypoint + only old Test 1 / new COVERAGE + BACKLOG-FORMAT | 17,923 | 17,935 | -12 (small increase) |
| BACKLOG-DIRECT: entrypoint + whole old CAPTURE-BAR / new COVERAGE + BACKLOG-FORMAT | 29,743 | 17,935 | 11,808 |
| QUICK-FIX-FLAGS: quick-fix + old Flags / new COMMIT-POLICY + HANDOFF | 18,249 | 17,209 | 1,040 |
| QUICK-FIX-FLAGS: quick-fix + whole old execute-feature / new COMMIT-POLICY + HANDOFF | 31,986 | 17,209 | 14,777 |

Underlying whole files: backlog entrypoint 11,518 → 11,516; CAPTURE-BAR
13,276 → 12,138; old Test 1 section 1,456 → COVERAGE 1,470; execute-feature
entrypoint 16,342 → 15,680; Flags 2,605 → 1,943; COMMIT-POLICY 1,550;
quick-fix entrypoint 12,694 → 12,709. BACKLOG-FORMAT remains 4,949 and HANDOFF
2,950, already included above. The direct path still invokes git-commit.ps1
when its existing conditions allow; its 2,076-character source is unchanged
and not a mandated instruction read. If inspected, add it once to both sides.
For Codex quick-fix add the unchanged mandatory 8,285-character CODEX overlay
to each side (26,534 → 25,494 section-only; 40,271 → 25,494 whole-entrypoint).
Claude lean mode does not require that overlay. Worktree scenarios additionally
retain their conditional overlays; no savings from those files is claimed.
Execute-feature itself grows from 16,342 to 17,230 when counting its required
policy companion, so relocation is not presented as its own invocation saving.
Target-repo instructions, plans, ledgers, phase obligations and evidence reads
are separate from these skill-instruction comparisons; conditional architecture
reads depend on the actual change. No unrelated companion was silently removed.

The Codex before trace visibly delivered whole CAPTURE-BAR (13,276) and only
1,988 characters/33 lines of Flags, not the whole entrypoint or even all Flags.
Claude backlog/format attempts failed and its QF parent had no Flags read;
worker reads remain unobservable on both hosts. Those actual observations take
precedence over source assumptions above. No after-body run, measured saving,
billing saving, frequency measurement or capability-wide parity is claimed.

TDD evidence: added focused helper/reachability/policy assertions first;
skill-semantics exited 1 on missing COVERAGE.md before implementation, then
passed after extraction with all existing sequencing, early-stop, permission,
gate and commit assertions retained. Assertions inspect the selected shared
contract and the caller's required link, never concatenate companion bodies.
Host-neutrality remained 70 references across 16 files with no relocation or
reduction, so the baseline was reviewed and left unchanged. Implemented and
source-reviewed on Codex; independent Claude Code review and after-body fresh
sessions are pending. Final task verification results are recorded below.

Final Task 3 verification: skill-semantics passed under Windows PowerShell;
task-contract, host-parity (26 rows/33 covered items), and host-neutrality
(70 references/16 files, unchanged baseline) passed under PowerShell 7.
`git diff --check` passed. The canonical full green gate completed all 28
commands with exit 0 and `GREEN-GATE-RESULT: GREEN`; its platform-specific
fixture skips do not represent fresh-host runtime evidence. A separate
read-only boundary check confirmed unchanged Test 0, Tests 2/3, backlog Step 2
onward, execute-feature Step 0 onward, and quick-fix Step 0 onward. The six
actual smoke records' standard headers, rows and build roles validated; their
raw results and contents remain untouched. Only Task 3's seven checkboxes
were completed before its task-scoped commit. No version/manifests were
changed; the human's recorded release-offer deferral to Task 6 still applies.

The staged whitespace check additionally exposed trailing blank lines at EOF
in the two new companions (untracked files were absent from the earlier plain
diff check). Removed those blank lines, updated the source counts above by
one character per companion, and reran semantic and staged-whitespace checks
before committing. This whitespace correction changes no rule or read path.

### Task 4 — conditional requirements format and glossary deduplication (2026-11-10)

Replaced only project-requirement's unconditional format-loading preamble.
Before add/refine, file/section creation, any write (including lifecycle updates),
or interpretation needing entry/lifecycle grammar, read REQUIREMENTS-FORMAT.md.
Ordinary view/status use the existing entrypoint instructions and records;
records needing grammar interpretation still trigger the guide. Gap/summary
retain their specific report-section references. A boundary comparison against
the pre-task source confirms everything from `Invoke:` onward is unchanged:
all seven actions, flags/examples, numbering, source/severity/lifecycle rules,
separate open-question bullets, passive monitoring and confirmation remain.
Neither format guide was edited and no companion was added.

Glossary consolidates activation and glossary-first rules, replacing repeated
admonitions and the red-flag table with one prerequisite. It retains canonical
and legacy existence checks and explicit glossary activation, broad term scope
(including technical terms and nouns absent from context), lookup before
codebase/filesystem/web searches, clarification and the offer to document a
missing term, confirmed immediate writes, unobtrusive monitoring, stable links,
lazy files, migration offers and definitions without implementation details.
Both skills' discovery descriptions are unchanged, including glossary's search
prohibition. Existing semantic-suite glossary protections are unchanged.

Normalized instruction read sets use the same body-count convention as the
frozen 7,355/7,514 baselines; project records and glossary data are separate:

| Scenario/source-read assumption | Before characters | After characters | Reduction |
|---|---:|---:|---:|
| REQUIREMENTS-READ ordinary view/status: body + formerly unconditional format / body only | 17,306 | 7,734 | 9,572 |
| REQUIREMENTS-READ add/refine, creation, writes or grammar-dependent interpretation: body + format | 17,306 | 17,685 | -379 (explicit condition adds text) |
| GLOSSARY-FIRST lookup: body only | 7,514 | 5,582 | 1,932 (25.71%) |
| Glossary confirmed write/migration: body + unchanged GLOSSARY-FORMAT | 10,955 | 9,023 | 1,932 |

REQUIREMENTS-FORMAT remains 9,951 characters; the new loading condition adds
379 body characters, adjusting the avoided full-guide read to 9,572 net.
GLOSSARY-FORMAT remains 3,441 and is counted when the selected operation needs
it. Counting the complete selected SKILL.md instead of its body adds unchanged
frontmatter once per side: requirements view/status 17,472 → 7,900 and glossary
lookup 7,766 → 5,834, with identical net reductions. Gap/summary continue to
consult their referenced report sections; no saving is claimed for those paths
or grammar-dependent view/status. No glossary body quota was imposed.

These are source-prescribed read-set comparisons, not after-body measurements.
The Gate A Codex before traces showed the complete requirements format on all
four paths; Claude's format-read attempts were denied, so that host has no
loaded-format before measurement. Target-project requirements/glossary data,
repo instructions, unrelated plugins and wrappers are outside these counts.
No billing/frequency saving or fresh-host behavior is inferred.

TDD evidence: added only selected-action/grammar-condition assertions and a
report-reference safeguard. Before implementation, Windows PowerShell
skill-semantics exited 1 on the two new loading-condition assertions; the
report-reference assertion and existing safeguards passed. After implementation,
all assertions passed. Glossary/source/confirmation obligations were not
weakened to meet a size target. Source review checked every distinct glossary
obligation against the pre-task file.

Host-neutrality baseline reviewed: unchanged at 70 references across 16 files;
neither skill changes a counted host token, so the baseline stays untouched.
Updated glossary/project-records parity notes without changing statuses or
claiming runtime verification. Implemented and source-reviewed on Codex;
independent Claude Code review and fresh after-body checks on both hosts remain
pending at Gate B. No external write, version change or host session was made;
the recorded release-offer deferral to Task 6 still applies.

Final Task 4 verification: Windows PowerShell skill-semantics passed, PowerShell 7
host-parity passed (26 rows/33 covered items), and host-neutrality passed
(70 references/16 files, unchanged baseline). `git diff --check` passed.
The full green gate remains scheduled for Task 6; Task 3's existing full-gate
result is not presented as verification of these later edits. Only Task 4's
six checkboxes were completed before its task-scoped commit.
