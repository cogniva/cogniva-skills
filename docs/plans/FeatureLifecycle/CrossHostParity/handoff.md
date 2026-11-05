# CrossHostParity — continuation handoff

Prepared 2026-11-05 by Codex against `ae4bf90` on
`feature/cross-host-parity`. Implementation and CLI validation are ready for
review; the feature remains at the Stage 2 manual acceptance gate. Integration
and remote push have not been performed by this Codex run.

## Start here

Read [AGENTS.md](../../../../AGENTS.md), the
[acceptance sheet](../../../host-parity/stage2-acceptance.md), and
[sub-plan 10](subplans/10-Acceptance.md).

Sub-plans 01–09 are checked off. In sub-plan 10, Task 1 and Task 2's agent
steps 1–4 are checked off. **Task 2's human steps 5–11 remain open.** Those
checkboxes remain the execution/resume authority; no `state.md` was created
for this lean run.

This run used `commits=task` on the existing branch. The plan reference is
already tracked. Review commands remain read-only; further implementation
must preserve the user's commit policy and the repository's branch rules.

The next agent work Claude can do is review Codex's follow-up fixes and
evidence with `/cogniva-dev:feature-check review`, scoped to
`6e66eea..ae4bf90`, particularly `45625f6`. Record findings and resolutions in
the acceptance sheet. Coordinate the manual VS Code runs with the user;
their results have not been supplied by this Codex run.

## What changed in the Codex follow-up

- `45625f6` fixes PowerShell task capture: `parse-plan-tasks.ps1` returns JSON
  through the success stream. Its new regression checks in-process capture
  against external invocation, including task bodies, gate flags and resume
  state. It passes under Windows PowerShell 5.1 and PowerShell 7.
- The same commit adds permission guidance to `execute-feature/CODEX.md` and
  the shared worker prompt: obtain approved execution before a protected Git
  metadata write, including snapshots under `commits=none`. Git failures
  still block without retries; commit policies are unchanged. The prompt
  builder remains byte-identical to the Workflow template and still needs
  external `pwsh -File` invocation when capturing its raw stdout.
- The smoke driver now accepts `-CodexApproveForMe`, selecting automatic
  approval review with workspace sandboxing. The original baseline mode is
  still available without that switch.
- `4fcbc7f` applies the user-approved **0.10.2 patch bump** in both manifests
  and the marketplace entry. Codex's installed 0.10.2 cache was verified
  against all 161 tracked plugin files. `cogniva-skills` remains 0.8.1.

The source changes are in `plugins/cogniva-dev/`; see
`git show --stat 45625f6` and `git show --stat 4fcbc7f` for their exact paths.

## Evidence to use

| Record | Result and scope |
|---|---|
| [Codex initial CLI run](../../../host-parity/smoke/2026-11-05-codex-cli.md) | 0.10.1: 2 pass, 7 fail. Historical diagnostics before the fixes. |
| [Codex 0.10.2 matrix](../../../host-parity/smoke/2026-11-05-codex-cli-3.md) | 8 pass, 1 fail. Every Git/parser failure passed; HOOKS failed before fresh trust review. |
| [Codex trusted-hook retest](../../../host-parity/smoke/2026-11-05-codex-cli-4.md) | 0.10.2: HOOKS passed after the user reviewed the updated hooks. PreToolUse actually blocked the attempted edit; the file stayed byte-identical. |
| [Claude initial CLI run](../../../host-parity/smoke/2026-11-05-claude-code-cli.md) | 0.10.1: 8 pass, 1 fail. QF-STRUCT failed only on the required final-message literal. |
| [Claude structural retest](../../../host-parity/smoke/2026-11-05-claude-code-cli-2.md) | Claude added `ae4bf90`: QF-STRUCT passed on 0.10.2. Its earlier failure did not recur. |

Codex has passing 0.10.2 results for all nine scenarios **across the matrix
and hook retest**, plus a passing separate EF-GATE resume check. There is no
single newly recorded nine-row all-pass matrix. Preserve the historical
failed rows. The original Claude nine-scenario run and its later structural
retest likewise span two records and plugin patch versions.

`primary-edit-guard` was first promoted to `verified` for Codex on CLI
evidence; the Claude Code cross-host review held it back at `scripts-tested`
until a VS Code record exists (user decision, 2026-11-05). The conservative parity rule disqualifies a whole
record with any failed row, so the mixed-result matrix did not promote
execute-feature or quick-fix. Do not infer VS Code verification from CLI
records or treat the Stage 3 inputs list as an approved backlog deferral.

## Review ownership

The original sub-plans 07–09 were implemented by **Claude Code**, as recorded
in the [Stage 2a diagnostics triage](../../../host-parity/codex-diagnostics.md#triage).
Their range is `bfcbd2e..fd413a3` (first task `e0df32d`, last task
`fd413a3`). The older acceptance-template claim that Codex implemented that
range was inaccurate.

Codex implemented the follow-up fixes, patch bump and CLI evidence from
`c4491da` through `deb3874`; `45625f6` contains the substantive fixes.
Claude's `ae4bf90` adds the later structural retest. Claude should review
the Codex work; confirm or obtain independent Codex review evidence for the
original Claude-implemented range before claiming cross-host review is
complete. The acceptance sheet's findings section is still empty.

## Remaining manual gate

1. Sub-plan 10, Task 2, Step 5: run all nine scenarios in Codex VS Code and
   QF-NONE, EF-GATE and HOOKS in Claude Code VS Code, using the
   [GUI runbook](../../../../plugins/cogniva-dev/tests/host-smoke/README.md#gui-procedure-vs-code-either-agent-host).
   Record install/discovery and hook trust observations on each surface.
2. Steps 6–7: apply the evidence rules to those records and fill the manual
   acceptance table. All 16 result cells are currently blank. In particular,
   ephemeral-plan status visibility and skipped-gate reporting still need
   the specific acceptance evidence; the CLI pass counts do not settle
   every row of that table.
3. Step 8: complete and record the review ownership work above.
4. Step 9: offer the planned Stage 2 minor release bump. The approved 0.10.2
   repair patch does not fulfill that separate minor-release step. Follow
   the three-file version rule; bump cogniva-skills only if the plan's
   Stage 2 change condition applies.
5. Steps 10–11: PR 2b, human acceptance and confirmation remain open. Nothing
   in this handoff grants merge or push authorization.

## Validation and local runtime notes

- Last full gate confirmed by this Codex run, after `692798a`:
  `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .`
  returned exit 0 and `GREEN-GATE-RESULT: GREEN`, all 28 commands passing.
  Later commits added smoke evidence and parity documentation.
- `pwsh -NoProfile -File scripts/check-host-parity.ps1` passed after the
  trusted-hook evidence update. Whitespace checks passed; the tree was clean
  at the start of this handoff update. Run the canonical gate again for the
  final release/acceptance artifact as the plan requires.
- Codex CLI used:
  `C:/Users/canuc/.vscode/extensions/openai.chatgpt-26.1021.22027-win32-x64/bin/windows-x86_64/codex.exe`
  (`0.164.0-alpha.11.1`). It exists; the earlier failed directory lookup was
  corrected. Use `-CodexExe` explicitly if automatic discovery omits it.
- Smoke runs used process-only marketplace overrides pointing `cogniva` at
  `C:/dev/cogniva-skills`, plus `notify=[]`; these source overrides were not
  persisted as marketplace configuration. New sessions loaded the installed
  0.10.2 cache. Do not assume an existing session reloads plugin instructions.
- For Claude CLI, use the runbook's `-PluginDir` branch loading so the
  reviewer and any reruns use the current 0.10.2 skills.
- The user reviewed/trusted 0.10.2 hooks after installation. The subsequent
  fresh-session hook test passed. Finish any future plugin update before
  reviewing its hooks, then use a fresh session for enforcement tests.
- Codex fixtures and raw outputs remain under
  `C:/Users/canuc/AppData/Local/Temp/Cogniva-CrossHostParity-session-6e66eea/`.
  The matrix is in `codex-0102-125103/out/`, including
  `EF-GATE.resume.assert.txt`; the hook retest is in
  `hooks-0102-trusted-132827/out/`. The full gate log is
  `0102-rerun-green-gate.log`. These local temporary files may not survive
  cleanup; the tracked smoke records and commits are the durable evidence.

This handoff authorizes no outside-repo writes. Follow the user's global
AGENTS.md rule and the current session's actual approvals for any further
installation, configuration or runtime writes.
