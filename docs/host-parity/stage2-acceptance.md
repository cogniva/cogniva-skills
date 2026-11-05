# Stage 2 acceptance — CrossHostParity

Prepared by the agent at the Stage 2 gate (sub-plan 10, Task 2). The human
fills the two result columns, row by row, from the smoke records and the
final messages they reference: `met`, or `not met — <why>`.

## Smoke records

- 2026-11-05-claude-code-cli — Claude Code, CLI: 8 pass, 1 fail, 0 not-run
- 2026-11-05-codex-cli — Codex, CLI: 2 pass, 7 fail, 0 not-run
- 2026-11-05-codex-cli-2 — Codex, CLI: 1 pass, 0 fail, 0 not-run (HOOKS, cogniva-dev 0.10.1)
- 2026-11-05-codex-cli-3 — Codex, CLI: 8 pass, 1 fail, 0 not-run (cogniva-dev 0.10.2, automatic approval review)
- 2026-11-05-codex-cli-4 — Codex, CLI: 1 pass, 0 fail, 0 not-run (HOOKS after fresh review, cogniva-dev 0.10.2)

## Evidence table

| Evidence area | Required evidence, per agent host | Claude Code | Codex |
|---|---|---|---|
| Execution | `QF-NONE`, `EF-TWO` assertions pass: intended files changed, tests in the fixture's green gate pass, and every `HANDOFF.md` section heading is present in the final message. | | |
| Commit policies | `QF-NONE`: 0 new commits. `QF-FINAL`: exactly 1, created after the gate. `EF-TWO`: 2, with plan ticks committed. Checked by `git rev-list` in the assertion script, never by the agent's word. | | |
| Branch and unrelated work | Every scenario: branch name unchanged, and the pre-dirtied `notes/unrelated.txt` keeps its content and is in no new commit. `POLICY`: stops with no file written, no `.git/info/exclude` change, and no commit. | | |
| Blocked / manual gate | `EF-BLOCKED`: 0 commits and task 2 untouched. `EF-GATE`: stops after task 2 with task 3 untouched; the re-run completes task 3 only. | | |
| Structural checks | `QF-STRUCT`: final message carries `STRUCTURE: FOUND` with no `UNEXPECTED`. The snapshot step succeeded or the Codex sandbox remedy from 06 applied. | | |
| Hooks + documented limits | `HOOKS`: a Claude `Edit` and a Codex `apply_patch` to the primary checkout are both denied (where Codex hooks fire on that surface; otherwise the record says `partial` with the surface named). A shell-mediated write is documented as uncaught, not claimed. | | |
| Honest handoffs and status | All `HANDOFF.md` sections present. A skipped gate appears under Skipped validations. `feature-status` lists the ephemeral `EF-GATE` plan as in progress. | | |
| Install + discoverability | Smoke record per agent host and surface: plugin version, both plugins' skills listed, explicit-only skills absent from implicit selection (Codex `/skills` view; Claude Code `/` menu still lists them), hook trust state noted. | | |

## Status changes made from smoke evidence

- primary-edit-guard — Codex: scripts-tested → verified (smoke:2026-11-05-codex-cli-4; CLI only)
- skipped 2026-11-05-claude-code-cli: failing QF-STRUCT
- skipped 2026-11-05-codex-cli: failing QF-NONE, QF-FINAL, EF-TWO, EF-GATE, QF-STRUCT, HOOKS, INSTR
- skipped 2026-11-05-codex-cli-3: failing HOOKS before fresh hook review; the later 2026-11-05-codex-cli-4 retest passes

## Stage 3 inputs

- lean-mode — Claude Code: untested — The shared parser, prompt/result contract and Workflow template are gate-covered. The Codex overlay and shared worker prompt require approval before protected Git metadata writes; the smoke driver offers process-local automatic review. Full real-host acceptance remains pending.
- lean-mode — Codex: untested — The shared parser, prompt/result contract and Workflow template are gate-covered. The Codex overlay and shared worker prompt require approval before protected Git metadata writes; the smoke driver offers process-local automatic review. Full real-host acceptance remains pending.
- worktree-mode — Claude Code: untested — Codex: stops at every entry point (ADR 0056); not wanted; what it would need is in CrossHostParity Stage 3. Claude Code: the integration and ledger scripts are gate-covered; the worktree task loop is not.
- execute-feature — Claude Code: untested — Both agent hosts share the worker prompt and result schema (ADR 0054). Parser JSON is capturable both in-process and through an external shell; the prompt builder still requires external stdout capture. Workers request required execution permission before their first Git metadata write. The initial Codex CLI matrix failed; acceptance remains pending. Model-invocable: routed from easy-work-scan (plugins/cogniva-dev/skills/easy-work-scan/EASY-WORK-CRITERIA.md:73).
- execute-feature — Codex: untested — Both agent hosts share the worker prompt and result schema (ADR 0054). Parser JSON is capturable both in-process and through an external shell; the prompt builder still requires external stdout capture. Workers request required execution permission before their first Git metadata write. The initial Codex CLI matrix failed; acceptance remains pending. Model-invocable: routed from easy-work-scan (plugins/cogniva-dev/skills/easy-work-scan/EASY-WORK-CRITERIA.md:73).
- quick-fix — Claude Code: untested — The structural snapshot and landing check are gate-covered. Under Codex both need approved execution before protected Git object writes, including commits=none; the overlay makes this a preflight obligation. Initial CLI failures preceded implementation, so acceptance remains pending. Model-invocable by design: easy-work-scan and groom-backlog dispatch it after approval, and its description states the explicit-start rule.
- quick-fix — Codex: untested — The structural snapshot and landing check are gate-covered. Under Codex both need approved execution before protected Git object writes, including commits=none; the overlay makes this a preflight obligation. Initial CLI failures preceded implementation, so acceptance remains pending. Model-invocable by design: easy-work-scan and groom-backlog dispatch it after approval, and its description states the explicit-start rule.
- plan-feature — Claude Code: untested — The profile and phase-block resolvers it calls are gate-covered; the design conversation is not. Model-invocable by design: easy-work-scan and groom-backlog dispatch it after approval, and its description states the explicit-start rule. In worktree mode it stops without the Workflow tool, so under Codex it runs in lean mode only (ADR 0056).
- plan-feature — Codex: untested — The profile and phase-block resolvers it calls are gate-covered; the design conversation is not. Model-invocable by design: easy-work-scan and groom-backlog dispatch it after approval, and its description states the explicit-start rule. In worktree mode it stops without the Workflow tool, so under Codex it runs in lean mode only (ADR 0056).
- explore-idea — Claude Code: untested — Explicit-only (metadata, both agent hosts). A conversation only; it may start read-only subagents.
- explore-idea — Codex: untested — Explicit-only (metadata, both agent hosts). A conversation only; it may start read-only subagents.
- backlog — Claude Code: untested — A direct capture commits through `git-commit.ps1` (gate-covered). Routing and confirmation are instruction-level on both agent hosts.
- backlog — Codex: untested — A direct capture commits through `git-commit.ps1` (gate-covered). Routing and confirmation are instruction-level on both agent hosts.
- backlog-grooming — Claude Code: untested — Each scan runs one read-only subagent. Approved items dispatch through quick-fix and plan-feature and inherit their status.
- backlog-grooming — Codex: untested — Each scan runs one read-only subagent. Approved items dispatch through quick-fix and plan-feature and inherit their status.
- adr — Claude Code: untested — The ADR checker is gate-covered. Confirming with the human before writing is instruction-level on both agent hosts.
- adr — Codex: untested — The ADR checker is gate-covered. Confirming with the human before writing is instruction-level on both agent hosts.
- repo-init — Claude Code: untested — Explicit-only (metadata, both agent hosts). The scaffold templates and the shipped profile are gate-covered; running the scaffold is not. Its install guidance covers both plugins on both agent hosts.
- repo-init — Codex: untested — Explicit-only (metadata, both agent hosts). The scaffold templates and the shipped profile are gate-covered; running the scaffold is not. Its install guidance covers both plugins on both agent hosts.
- add-module — Claude Code: untested — Explicit-only (metadata, both agent hosts). Profile gating is gate-covered; the scaffold itself is not.
- add-module — Codex: untested — Explicit-only (metadata, both agent hosts). Profile gating is gate-covered; the scaffold itself is not.
- plan-status — Claude Code: untested — Plain file reads on both agent hosts. Ephemeral plans in `.plans-staging/` are listed and marked as local to the clone.
- plan-status — Codex: untested — Plain file reads on both agent hosts. Ephemeral plans in `.plans-staging/` are listed and marked as local to the clone.
- workflow-status — Claude Code: untested — Codex runs write no journal; a shared run record is CrossHostParity Stage 3. `workflow-status.ps1` has no gate suite.
- glossary — Claude Code: untested — Consulting the glossary before searching is instruction-level on both agent hosts.
- glossary — Codex: untested — Consulting the glossary before searching is instruction-level on both agent hosts.
- project-records — Claude Code: untested — Plain instructions with no agent-host-specific steps.
- project-records — Codex: untested — Plain instructions with no agent-host-specific steps.

## Cross-host review

- Reviewer: a Claude Code session, `/cogniva-dev:feature-check review` over the sub-plan 07–09 diff (implemented by Codex).
- Findings and how each was resolved:

## Notes

- The 0.10.2 matrix passed eight scenarios and the separate EF-GATE resume assertion. Its initial HOOKS run allowed the edit after installation. A baseline control without automatic approval review also allowed it; the installed guard returned a JSON deny decision when invoked directly. After the user reviewed the 0.10.2 hooks, a fresh CLI retest was blocked by PreToolUse and passed every assertion. All nine scenarios therefore have passing 0.10.2 results across the matrix and hook retest; the historical failed row remains intact. Only the hook capability is promoted from its separate passing record, because the original matrix record still contains a failure. The manual acceptance cells and VS Code checks remain open.
- Bumping cogniva-dev's minor version at this gate makes the CLI records above one minor version older than `plugin.json`; `check-host-parity.ps1` then prints `WARN stale evidence` for them. That is a warning by design (they were taken from this branch before the bump), not a failure.
