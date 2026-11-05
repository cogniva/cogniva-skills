# CrossHostParity — Feature Plan (orchestrated)

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/CrossHostParity
> Multi-plan feature: the sub-plans below execute IN LISTED ORDER (already
> dependency-sorted), all in ONE workspace, sequentially, landing ONCE at the
> end. Tasks contain NO git worktree/branch step.
> Stage boundaries are ⛔ gate tasks (the last task of sub-plans 04, 06 and 10):
> the run stops there so the stage can be reviewed by the other agent host and
> merged as its own PR. Re-run the executor to continue; ticked tasks are skipped.

**Goal:** Claude Code and OpenAI Codex deliver equivalent lean-mode capabilities
and guarantees for both plugins on the team's Windows 11 surfaces (CLI and
VS Code), with that equivalence written down, checked by the green gate where it
can be checked, and backed by real-host evidence where it cannot.

**Architecture:** Keep the shared `skills/` trees and host-neutral scripts
(ADR 0029); add only small host-specific pieces: invocation metadata, a hook
input adapter, and a shared worker prompt/result contract that both executors
consume while each keeps its own orchestration (Claude: the Workflow template;
Codex: the `CODEX.md` loop). Stage 1 (sub-plans 01–04) makes divergence hard to
introduce: `AGENTS.md` becomes this repo's canonical instruction file, a short
standing parity rule and phase blocks put the obligation where both hosts meet
it, `docs/host-parity.md` (the [Parity record](../../../glossary/README.md#parity-record), a glossary entry added by sub-plan 01)
states every capability's per-host status, and new green-gate checks derive the
inventory from the repo and fail on gaps. Stage 2 (05–10) starts with
empirical Codex runs against fixture repos, then closes the gaps the evidence
and the audits show, then re-runs the same scenarios on both hosts as the
acceptance evidence. Stage 3 is documented below and is not a prerequisite.

**Host impact:** Changes skill metadata, hook input parsing, the Codex executor
contract and several shared skill texts for both agent hosts. Worktree mode stays
Claude Code–only and is recorded as `unsupported` for Codex, and every
worktree-mode entry point stops under Codex. Implementation and review alternate
between hosts at each stage gate (see "Cross-host review points").

**Read these first:**
- [Continuation handoff](handoff.md) — current execution position, evidence,
  review ownership and the remaining Stage 2 manual gate.
- Evidence (not in the repo; findings are summarised where used):
  the Claude audit `cross-host-parity-audit.md` (2026-10-09) and the Codex
  "Cross-agent parity audit" (2026-10-09, Codex session
  `rollout-2026-10-09T10-50-38-01a12125`). Both audited `0c499d1`.
- `AGENTS.md`, `CLAUDE.md`, `docs/strategy.md` (§ Repo-scoped workflow instructions)
- `docs/adr/0028`, `0029`, `0030`, `0031`, `0039`
- `plugins/cogniva-dev/docs/codex.md`
- `plugins/cogniva-dev/skills/execute-feature/SKILL.md`, `CODEX.md`, `HANDOFF.md`;
  `plugins/cogniva-dev/templates/execute-feature.workflow.js`
- `plugins/cogniva-dev/hooks/hooks.json` and the four hook scripts in
  `plugins/cogniva-dev/scripts/`

## Decisions already made (planning inputs — do not reopen)

- Target: full **lean-mode** parity, lifecycle workflows included. Worktree mode
  stays Claude-only for now. It is recorded as unsupported, never as equivalent,
  and existing Claude worktree behaviour is preserved.
- Environments: Windows 11, Claude Code and Codex, CLI and VS Code/desktop. No
  Linux, macOS or cloud. No new Windows PowerShell 5.1 dependencies: new
  scripts are pwsh 7 (ADR 0039), and existing 5.1 scripts stay as they are.
- Validation: deterministic checks in the local green gate. Real-host smoke runs
  happen at releases and after host or adapter changes, not on every PR.
  Cross-agent review supplements tests and does not replace them.
- Architecture: shared trees plus thin adapters. No generated skills, no
  orchestration framework, no emulation of the Workflow runtime.
- Invocation (confirmed in this design session): host metadata marks a skill
  explicit-only **only where no other skill routes into it**. Skills reached by
  routing or by an accepted offer keep model invocation and rely on description
  wording.
- Packaging of this plan (confirmed): one feature, with stage gates as the
  PR boundaries.
- Execution (confirmed): Claude executes sub-plans 01–06. If the sub-plan 06
  diagnostics show the Codex loop working, **Codex executes 07–09** on the
  feature branch with `commits=task`, and Claude reviews. Otherwise Claude
  executes them and the parity record keeps the Codex executor `partial`.

## Where repository evidence corrected the audits

| Audit claim | What the repo shows | Consequence |
|---|---|---|
| `git-commit` suite fails because `git-commit.ps1` mangles messages (also the FeatureLifecycle backlog item) | The failure is the **test's** Windows PowerShell 5.1 invocation: an embedded `"` is not escaped across `powershell -File`. Under pwsh 7 all six assertions pass. Real callers (backlog skill, nudge hook) pass one-line messages from Bash, which commit correctly. | Fix the test, not the script (02). The backlog item is ticked as planned. |
| Green-gate pass and skip are indistinguishable | The runner's output differs (`GREEN`, `no … green-gate.json … skipping`, `'commands' is empty`), and all three exit 0. The gap is downstream: the skills treat exit 0 as "green or skip", HANDOFF has no rule for a skipped gate, and `run-gate-check.ps1` prints `PASS` either way. | Add a result marker and a handoff rule (09). The runner's exit codes are unchanged. |
| plan-feature lacks the host guard the execution skills have (Codex C3) | plan-feature's worktree overlay uses only scripts, never the Workflow runtime, so it is not broken under Codex. It is **unverified**, though, and execution then refuses the same clone. | Make the boundary consistent: every worktree-mode entry point stops under Codex (09), recorded `unsupported`. |
| Branch policy is checked after mutation | Confirmed for execute-feature: Step 0a writes, appends to `.git/info/exclude`, and can commit before Step 0b checks the policy. plan-feature has **no** policy check, yet commits under `commits=final`. quick-fix's ordering is correct. | Fix both (09). |
| `.git` is read-only in Codex's sandbox and affects commits and `.git/info/exclude` | Also affects **quick-fix Step 0**: the structural `-Snapshot` runs `git add` into a temporary index plus `git write-tree`, which writes objects into `.git`. A read-only `.git` would stop every quick-fix before dispatch, even under `commits=none`. Neither audit names this. | It is a first-class diagnostic question (06). Remedy per the 06 decision table. |
| Structural check runs on only one execution path | Confirmed (quick-fix only). It is the same on both hosts, so it is not a host-parity gap, and a planned deferral already exists (`because:after FeatureLifecycle/QuickFixStructuralChecks is used in real repos`). | Left deferred. Acceptance checks quick-fix's structural check on both hosts. |
| The Codex CLI is not installed (Claude audit) vs "Codex 0.162 executable" (Codex audit) | No `codex` on PATH. The VS Code extension (`openai.chatgpt-26.1007…`) bundles the Codex binaries. | The smoke driver takes `-CodexExe`. Choosing the binary is unresolved decision 2. |

## Sub-plans (execution order)

| # | Sub-plan | Delivers | Prerequisites |
|---|----------|----------|---------------|
| 1 | `subplans/01-InstructionGovernance.md` | `AGENTS.md` canonical + `@AGENTS.md` CLAUDE.md; standing `## Cross-host parity` rule; `before-planning` + extended `before-integrate` blocks; glossary **Agent host** + **Parity record**; stale-doc fixes; consumer migration procedure; instruction-governance suite; ADR C1 | — |
| 2 | `subplans/02-GateHardening.md` | `git-commit` test fixed + the five out-of-gate suites gated; applicable-rules singleton fix + regression; manifest checker requires both manifests and skill coverage; primary-hook test suite (Claude payloads asserted, Codex payload gap pinned) | 1 |
| 3 | `subplans/03-ParityRecord.md` | `docs/host-parity.md`; `check-host-parity.ps1` (derived inventory, status/evidence rules, overlay and metadata consistency); host-token ratchet `check-host-neutrality.ps1`; `docs/codex.md` reconciled; ADR C2 | 1, 2 |
| 4 | `subplans/04-InvocationPolicy.md` | Explicit-only metadata on both hosts for non-routed entry skills; routed skills' descriptions; host-neutral invocation wording in user-facing output; ratchet lowered; ADR C3; ⛔ **Stage 1 gate** (PR 1) | 3 |
| 5 | `subplans/05-SmokeHarness.md` | Fixture generator, 9 scenarios, outcome assertions (gated self-tests), Claude/Codex drivers, GUI runbook, smoke-record format, Workflow-template node harness | 4 |
| 6 | `subplans/06-CodexDiagnostics.md` | Automated CLI runs on both hosts + ⛔ human VS Code runs, captured Codex hook payloads, diagnostics report, triage via decision table; ⛔ **Stage 2a gate** (PR 2a) | 5 |
| 7 | `subplans/07-ExecutorContract.md` | Canonical task-result schema; `new-task-prompt.ps1` identical to the Workflow prompt (parity-tested); `test-task-result.ps1`; `CODEX.md` loop on the shared contract; ADR C4 | 6 |
| 8 | `subplans/08-HookAdapters.md` | `hook-input.js` (Claude `file_path`, Codex `apply_patch` multi-file, shell command); four hooks on it; Codex-gap tests flipped; hook limits documented; ADR C5 | 6 |
| 9 | `subplans/09-PolicyConsistency.md` | Branch policy before any write (execute-feature, plan-feature); worktree mode stops under Codex everywhere; green-gate result marker + Skipped-validations rule; status skills see `.plans-staging/`; repo-init/strategy install guidance for both hosts and plugins; ADR C6 | 6 |
| 10 | `subplans/10-Acceptance.md` | Full scenario matrix on both hosts and surfaces, smoke records, parity statuses earned from evidence, cross-host review; ⛔ **Stage 2 gate** (PR 2b) | 7, 8, 9 |

Sub-plans 07, 08 and 09 are independent of each other; each depends only on 06's
evidence (08 consumes the payload fixture 06 captures). Within Stage 1, 02's
fixes are independent of 01's text changes, but 02 is listed after 01 because
its gate wiring edits the same `green-gate.json`.

## PR boundaries and cross-host review points

| PR | Sub-plans | Implemented by | Reviewed by | Stops at |
|---|---|---|---|---|
| PR 1 — Stage 1 | 01–04 | Claude (`/cogniva-dev:execute-feature`) | Codex: fresh session, native-instruction probe + `feature-check review` | ⛔ 04 last task |
| PR 2a — harness + diagnostics | 05–06 | Claude builds 05; Codex **is exercised** in 06 (real runs, not inferred) | Codex reviews 05's fixtures and assertions | ⛔ 06 last task |
| PR 2b — parity fixes + acceptance | 07–10 | Codex (`$execute-feature`), Claude as fallback | Claude: `feature-check review` + its own acceptance runs | ⛔ 10 last task |

Before running anything: create the branch `feature/cross-host-parity` from
`main` (skills never create branches). The uncommitted plan folder moves with
the checkout. Run with `commits=task` so each stage gate leaves reviewable
commits. Each ⛔ gate runs the full green gate itself, because a stop at a gate
skips the executor's landing.

## Acceptance criteria

### Stage 1 (checked at sub-plan 04's ⛔ gate)

| Criterion | Objective check |
|---|---|
| Both hosts receive the same shared policy | `instruction-governance` suite: `CLAUDE.md` is `@AGENTS.md` plus at most a `## Claude Code notes` section; none of `## Rules`, `## Layout`, `## Cross-host parity`, `## Cogniva-dev workflow instructions` appears outside `AGENTS.md`; the AGENTS.md roster equals the skill directories on disk. Manual: a fresh Codex session and a fresh Claude session each state the three-file bump rule and the parity rule without being pointed at a file (recorded in the gate). |
| Future changes carry a cross-host obligation | `AGENTS.md` has `## Cross-host parity`. `resolve-workflow-obligations.ps1 -Phase before-planning` and `-Phase before-integrate` both report `Source: AGENTS.md` (suite assertion). |
| Host differences have an identifiable home | `check-host-parity.ps1` passes: every skill of both plugins and every hook script is covered by exactly one parity-record row; every overlay a skill names exists. |
| Missing coverage is detectable | Fixture tests prove `check-host-parity.ps1` fails on a new skill with no row, `verified` with no host evidence, `scripts-tested` citing an unknown gate label, and invocation metadata set on one host only. They also prove `check-plugin-manifests.ps1` fails on a missing Codex manifest or a bad `skills` path, and `check-host-neutrality.ps1` fails when a host-specific token's count rises. |
| Expanded gate is green | `run-green-gate.ps1 -Repo .` → `GREEN`, with 24 commands: the 12 original ones plus `instruction-governance`, `git-commit`, `integrate-feature`, `ledger`, `parse-plan-tasks`, `validate-json`, `manifest-checker`, `primary-hooks`, `host-parity-suite`, `host-parity`, `host-neutrality-suite`, `host-neutrality`. The `-suite` labels prove each checker on fixtures; the bare labels run it against this repo. Stage 2 adds `smoke-assertions`, `workflow-template`, `task-contract` and `hook-input`. |
| No regression | Every pre-existing suite passes. The only edited assertions are the skill-semantics pins listed in 03/04, each replaced by an assertion on the new text. The singleton fix's regression test fails before the fix and passes after. |

### Stage 2 (checked at sub-plan 10's ⛔ gate)

Scenarios (defined in 05, with the same fixture and assertions on both hosts):
`QF-NONE` quick-fix `commits=none` · `QF-FINAL` quick-fix `commits=final` ·
`EF-TWO` two-task execute-feature `commits=task` · `EF-BLOCKED` blocked first
task · `EF-GATE` ⛔ gate stop then resume · `QF-STRUCT` expected structural
change · `POLICY` branch-policy mismatch · `HOOKS` worktree-mode primary edit ·
`INSTR` instruction canary (root + nested + worker).

| Evidence area | Required evidence, per host (Claude Code, Codex) |
|---|---|
| Execution | `QF-NONE`, `EF-TWO` assertions pass: intended files changed, tests in the fixture's green gate pass, and every `HANDOFF.md` section heading is present in the final message. |
| Commit policies | `QF-NONE`: 0 new commits. `QF-FINAL`: exactly 1, created after the gate. `EF-TWO`: 2, with plan ticks committed. Checked by `git rev-list` in the assertion script, never by the agent's word. |
| Branch and unrelated work | Every scenario: branch name unchanged, and the pre-dirtied `notes/unrelated.txt` keeps its content and is in no new commit. `POLICY`: stops with no file written, no `.git/info/exclude` change, and no commit. |
| Blocked / manual gate | `EF-BLOCKED`: 0 commits and task 2 untouched. `EF-GATE`: stops after task 2 with task 3 untouched; the re-run completes task 3 only. |
| Structural checks | `QF-STRUCT`: final message carries `STRUCTURE: FOUND` with no `UNEXPECTED`. The snapshot step succeeded or the Codex sandbox remedy from 06 applied. |
| Hooks + documented limits | `HOOKS`: a Claude `Edit` and a Codex `apply_patch` to the primary checkout are both denied (where Codex hooks fire on that surface; otherwise the record says `partial` with the surface named). A shell-mediated write is documented as uncaught, not claimed. |
| Honest handoffs and status | All `HANDOFF.md` sections present. A skipped gate appears under Skipped validations. `feature-status` lists the ephemeral `EF-GATE` plan as in progress. |
| Install + discoverability | Smoke record per host/surface: plugin version, both plugins' skills listed, explicit-only skills absent from implicit selection (Codex `/skills` view; Claude `/` menu still lists them), hook trust state noted. |

A capability is `verified` for a host only when a smoke record for that host
covers it (enforced by `check-host-parity.ps1`). Shared scripts and docs alone
earn at most `scripts-tested`.

## Candidate ADRs

Proposed at the planning handoff for human confirmation (confirm, amend or
drop each before execution starts). Each sub-plan carries the full text of the
ones it writes:

| Label | Title | Written in |
|---|---|---|
| C1 | AGENTS.md is the canonical instruction file in this repo too | 01 |
| C2 | Cross-host parity is the default, recorded in one parity record backed by derived checks | 03 |
| C3 | Explicit-only invocation metadata only where no skill routes in | 04 |
| C4 | Both executors share one worker prompt and result contract | 07 |
| C5 | Hooks read both hosts' edit payloads and remain best-effort | 08 |
| C6 | Worktree mode stops under Codex at every entry point | 09 |

## Unresolved decisions (defaults apply unless changed when the stage begins)

1. **VS Code Codex cannot dispatch sequential subagents from a skill** (an open
   question in both audits). Matters because the Codex executor's
   fresh-context guarantee depends on it. Alternatives: (a) CLI-only for
   execute-feature/quick-fix under Codex; (b) an inline fallback where the main
   agent runs each task itself, reported as `partial` (no fresh context);
   (c) both. **Default: (c).** CLI is the recommended Codex surface for
   execution, and inline runs are allowed and labelled in the handoff. Decide at
   the 06 triage, and only if the diagnostics show the problem.
2. **Which Codex binary the smoke driver uses.** (a) The binary bundled with the
   VS Code extension; (b) a standalone CLI install. **Default: (a)**, passed as
   `-CodexExe`, so no new install. Decide at 05.
3. **How fresh smoke evidence must be.** **Default:** a record counts for
   `verified` if its plugin version shares the current major.minor; older
   records produce a warning, not a failure. Decide at 03 (encoded in the
   checker).
4. **Codex hook re-trust after each plugin update.** (a) Accept and document;
   (b) stop shipping hooks to Codex. **Default: (a)**, revisited only if 06 shows
   trust prompts make the hooks unusable. Decide at 08.

Malformed Codex worker results are not open: they become `BLOCKED` with the
reason, matching the Claude template's null-result handling (07).

## Known risks

- **Headless Claude Code and background Workflows.** It is untested whether
  `claude -p` waits for a background Workflow run to finish before it exits.
  If it does not, the automated Claude Code baseline in 06/10 under-reports,
  and those scenarios fall back to the VS Code runbook (05 README).
- **Codex sandbox writes outside `.git`.** 07's `CODEX.md` loop writes its
  per-task prompt and reply files to the system temp directory. If the Codex
  sandbox refuses that, 10's runs show it: record it `partial` and decide a
  fallback location then. Never use a tracked path.
- **Hook trust churn.** Codex keys trust per hook entry and hash, so a plugin
  update that changes `hooks.json` silently disables hooks until they are
  re-trusted. Documented in 03/08; unresolved decision 4.
- **Plugin build under test.** Smoke runs must use the branch build (Claude
  Code: `--plugin-dir`; Codex: a local marketplace from the checkout). 06 and 10
  stop as `BLOCKED` when Codex has only the released build installed.
- **Version-bump timing.** The minor bump at the 10 gate makes that stage's CLI
  smoke records one version old. `check-host-parity.ps1` warns and does not
  fail; the acceptance sheet says so.
- **Two template loaders.** 05 (`run-template.mjs`) and 07 (its own loader in
  `tests/task-contract/`) each evaluate the Workflow template. Acceptable
  duplication for tests. Fold them together only if one changes.

## Stage 3 — deferred (not part of this plan's completion)

Recorded so it can be planned later. Items not already in a backlog were
captured at the planning handoff with their `because:` reasons, except Codex
worktree mode, which was declined.

**Genuine parity gaps**
- **Codex worktree mode — not wanted (declined at the planning handoff,
  2026-10-09); no backlog item.** It stays `unsupported` for Codex (ADR C6).
  If it is ever revisited, these are the outcomes it would need, independent
  of mechanism: the
  primary checkout and the user's branch are untouched until integration;
  integration is fast-forward only and only after a green gate; a run is
  recoverable from on-disk state alone after the session is lost; cleanup
  removes only merged, clean worktrees; unrelated work is never lost; status
  shows active, blocked and integrable worktrees; worktree directories are
  writable under the host's sandbox (sibling directories may sit outside Codex
  writable roots). Codex's native managed worktrees count only if they meet
  these outcomes (they start in detached HEAD, with their own lifecycle).
- **Run journal / observability.** Codex has no `workflow-status` equivalent. A
  minimal shared run record beside the ephemeral plan would give both hosts the
  same status view. Plan it only after 09's `.plans-staging/` status shows what
  is still missing.
- **Shipped approval rules.** A checked-in Codex `.codex/rules` equivalent of
  the Claude allow/deny lists, if 06/10 show approval friction that makes lean
  runs impractical.
- Any gap that 06 or 10 records as `partial` and that is not fixed in 07–09.

**Separate improvements (not parity gaps)**
- Migrating consuming repos to canonical `AGENTS.md` (the procedure is written
  in 01; start with `cogniva-analysis`).
- Moving host-neutral config from `.claude/` into `.cogniva/`, with read
  fallback.
- PowerShell 7 migration and non-Windows support (existing backlog item;
  includes `run-green-gate.ps1`'s `powershell -Command`).
- Python profile and structural detector (existing backlog item).
- Codex's root `plugin.json` packaging; single-sourcing the marketplace
  version.
- Structural check in execute-feature's landing (existing backlog item; same on
  both hosts).
- Deterministic gate in CI on PRs.
