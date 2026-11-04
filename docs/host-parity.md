# Agent host parity record

This is the [Parity record](glossary/README.md#parity-record): every capability
of the `cogniva-dev` and `cogniva-skills` plugins, its status on each
[Agent host](glossary/README.md#agent-host) (Claude Code and Codex), and the
evidence behind that status. It is the only hand-maintained inventory. The green
gate's `scripts/check-host-parity.ps1` derives the skill, hook and overlay
inventory from the repo, fails on anything this table does not cover, and
enforces the rules below. The decision is recorded in ADR 0052
(`docs/adr/0052-cross-host-parity-is-the-default.md`).

## Status values

| Value | Meaning |
|---|---|
| `verified` | A smoke record from this agent host covers the capability. Needs at least one `smoke:<record-id>` in Evidence whose record names this agent host, lists this row ID in `Covers:`, and has no `fail` result. A record counts as fresh only while its cogniva-dev major.minor equals the current one; older records produce a warning. |
| `scripts-tested` | Green-gate suites cover the scripts that carry this capability's steps on this agent host; the capability itself has not been exercised there. Needs at least one `gate:<label>` that exists in `.claude/cogniva-dev/green-gate.json`. `skill-semantics` pins prose, so it never justifies `scripts-tested` on its own. When a step is carried by something no suite runs (the Workflow template until CrossHostParity 05 adds its suite, the `CODEX.md` loop, a design conversation), the row stays `untested` and Evidence still lists the suites that cover the rest. |
| `untested` | Available on this agent host; nothing exercises the capability as a whole. Evidence may list suites that cover parts of it. |
| `partial` | Works with a stated gap. Notes must state the gap. |
| `unsupported` | Intentionally not offered on this agent host. Notes must state the reason. |
| `n/a` | The capability does not apply to this agent host. Notes must say why. |

A status cell holds the value, optionally followed by ` — ` and a short
mechanism. Every `gate:` label and `smoke:` record cited anywhere must exist.

## Kinds

| Kind | Covers |
|---|---|
| `packaging` | Install, discovery, manifests. |
| `workflow` | A skill's behaviour. |
| `enforcement` | Hooks, permissions, policy checks. Notes always state the limits. |
| `tooling` | Shared scripts and the gate. |

## Capabilities

| ID | Capability | Kind | Covers | Claude Code | Codex | Evidence | Notes |
|---|---|---|---|---|---|---|---|
| install-cogniva-dev | Install and skill discovery: cogniva-dev | packaging | manifest:cogniva-dev | scripts-tested — `.claude-plugin/plugin.json` | scripts-tested — `.codex-plugin/plugin.json` | gate:manifest-checker, gate:manifest-parity | The gate checks both manifests and the marketplace entry. Installing the plugin and listing its skills on each agent host is recorded only by a smoke run. |
| install-cogniva-skills | Install and skill discovery: cogniva-skills | packaging | manifest:cogniva-skills | scripts-tested — `.claude-plugin/plugin.json` | scripts-tested — `.codex-plugin/plugin.json` | gate:manifest-checker, gate:manifest-parity | The gate checks both manifests and the marketplace entry. Installing the plugin and listing its skills on each agent host is recorded only by a smoke run. |
| lean-mode | Lean mode: work on the current branch under `commits=`, `plan=` and `tasks=one` | workflow | mode:lean | untested — Workflow template (same prompt/result contract) | untested — CODEX.md loop on the shared prompt/result contract | gate:parse-plan-tasks, gate:git-commit, gate:green-gate-runner, gate:task-contract | The plan parser, commit wrapper and green-gate runner are gate-covered. Neither agent host's task loop has a suite (the Workflow template gets one in CrossHostParity 05). Under Codex the sandbox may make `.git` read-only (diagnosed in CrossHostParity 06). |
| worktree-mode | Worktree mode: isolated worktree, fast-forward integration, ledger | workflow | mode:worktree | untested — Workflow template and worktree scripts | unsupported — needs the Workflow runtime | gate:integrate-feature, gate:ledger | Codex: worktree execution needs the Workflow runtime, which Codex lacks; a Codex design is deferred (see CrossHostParity Stage 3). Claude Code: the integration and ledger scripts are gate-covered; the worktree task loop is not. |
| execute-feature | Execute a feature plan task by task | workflow | skill:cogniva-dev/execute-feature | untested — Workflow template (same prompt/result contract) | untested — CODEX.md loop on the shared prompt/result contract | gate:parse-plan-tasks, gate:git-commit, gate:green-gate-runner, gate:task-contract | The Codex loop has never run end to end. Both agent hosts give workers the same prompt (new-task-prompt.ps1) and check the same result schema (task-result.schema.json); a malformed Codex reply is BLOCKED (ADR 0054). Model-invocable: routed from easy-work-scan (plugins/cogniva-dev/skills/easy-work-scan/EASY-WORK-CRITERIA.md:73). |
| quick-fix | Small planless changes | workflow | skill:cogniva-dev/quick-fix | untested — Workflow template (same prompt/result contract) | untested — CODEX.md loop on the shared prompt/result contract | gate:structural-changes, gate:green-gate-runner, gate:task-contract | The structural snapshot and landing check are gate-covered. Under Codex the snapshot writes objects into `.git`, which the sandbox may make read-only (CrossHostParity 06). Model-invocable by design: easy-work-scan and groom-backlog dispatch it after approval, and its description states the explicit-start rule. |
| plan-feature | Design one feature and emit a task plan | workflow | skill:cogniva-dev/plan-feature | untested — design conversation | untested — design conversation | gate:architecture-profile, gate:instruction-governance | The profile and phase-block resolvers it calls are gate-covered; the design conversation is not. Model-invocable by design: easy-work-scan and groom-backlog dispatch it after approval, and its description states the explicit-start rule. |
| explore-idea | Brainstorm an idea into disposable notes | workflow | skill:cogniva-dev/explore-idea | untested | untested | — | Explicit-only (metadata, both agent hosts). A conversation only; it may start read-only subagents. |
| backlog | Capture a planned deferral | workflow | skill:cogniva-dev/backlog | untested | untested | gate:git-commit | A direct capture commits through `git-commit.ps1` (gate-covered). Routing and confirmation are instruction-level on both agent hosts. |
| backlog-grooming | Groom the backlog and pick low-involvement work | workflow | skill:cogniva-dev/groom-backlog, skill:cogniva-dev/easy-work-scan | untested | untested | — | Each scan runs one read-only subagent. Approved items dispatch through quick-fix and plan-feature and inherit their status. |
| adr | Record a confirmed ADR | workflow | skill:cogniva-dev/adr | untested | untested | gate:adr-checker | The ADR checker is gate-covered. Confirming with the human before writing is instruction-level on both agent hosts. |
| applicable-rules | Instruction chain and placement preflight | tooling | skill:cogniva-dev/applicable-rules | scripts-tested — `resolve-applicable-rules.ps1` | scripts-tested — `resolve-applicable-rules.ps1` | gate:applicable-rules | — |
| review-and-gates | Review evidence and mechanical gates | tooling | skill:cogniva-dev/feature-check, skill:cogniva-dev/gate-check | scripts-tested — `run-gate-check.ps1` | scripts-tested — `run-gate-check.ps1` | gate:gate-check, gate:green-gate-runner | Review judgment is instruction-level. This repo's own green gate runs `claude plugin validate .`, so a developer with only Codex installed cannot pass it. |
| repo-init | Scaffold a new .NET repo | workflow | skill:cogniva-dev/repo-init | untested | untested | gate:profile-library | Explicit-only (metadata, both agent hosts). The scaffold templates and the shipped profile are gate-covered; running the scaffold is not. Its install guidance is Claude Code-only (CrossHostParity 09). |
| add-module | Scaffold a Module bundle | workflow | skill:cogniva-dev/add-module | untested | untested | gate:architecture-profile | Explicit-only (metadata, both agent hosts). Profile gating is gate-covered; the scaffold itself is not. |
| module-deps | Module dependency graph and cycle check | tooling | skill:cogniva-dev/module-deps | scripts-tested — `module-deps.ps1` | scripts-tested — `module-deps.ps1` | gate:module-deps | — |
| worktree-cleanup | Close out worktree-mode runs | workflow | skill:cogniva-dev/cleanup-work, skill:cogniva-dev/cleanup-allwork | scripts-tested — `cleanup-worktrees.ps1` | unsupported — worktree mode only | gate:ledger | Explicit-only (metadata, both agent hosts). Codex does not start worktree-mode runs (row worktree-mode), so there is nothing to close out. In lean mode both skills report nothing to do. |
| plan-status | Feature, Module and repo status roll-ups | workflow | skill:cogniva-dev/feature-status, skill:cogniva-dev/module-status, skill:cogniva-dev/repo-status | untested | untested | — | Plain file reads on both agent hosts. Ephemeral plans in `.plans-staging/` are not scanned yet (CrossHostParity 09). |
| workflow-status | Status of background Workflow runs | tooling | skill:cogniva-dev/workflow-status | untested — Workflow journals | unsupported — no Workflow journals | — | Codex runs write no journal; a shared run record is CrossHostParity Stage 3. `workflow-status.ps1` has no gate suite. |
| glossary | Project glossary | workflow | skill:cogniva-skills/glossary | untested | untested | — | Consulting the glossary before searching is instruction-level on both agent hosts. |
| project-records | References, requirements and business context | workflow | skill:cogniva-skills/reference, skill:cogniva-skills/project-requirement, skill:cogniva-skills/project-context | untested | untested | — | Plain instructions with no agent-host-specific steps. |
| primary-edit-guard | Deny edits to the primary checkout in worktree mode | enforcement | hook:guard-primary-edit.js | scripts-tested — PreToolUse on Write, Edit, NotebookEdit | scripts-tested — hook-input adapter | gate:primary-hooks, gate:hook-input | Reads Claude Code file_path/notebook_path and every path of a Codex apply_patch through hook-input.js, and denies if any path is guarded (ADR 0055). Codex runs it only after the user trusts it in /hooks, again after any change to hooks.json. Both agent hosts: writes made through a shell command are not seen; the guarantees live in the landing checks. |
| branch-switch-guard | Block branch switching in the primary checkout in worktree mode | enforcement | hook:guard-primary-git.js | scripts-tested — PreToolUse on Bash | scripts-tested — hook-input adapter | gate:primary-hooks, gate:hook-input | Reads the Bash command through hook-input.js on both agent hosts, never apply_patch text (ADR 0055). Codex runs it only after the user trusts it in /hooks, again after any change to hooks.json. Both agent hosts: a command the guard does not recognise passes. |
| backlog-commit-nudge | Nudge to commit a backlog capture | enforcement | hook:nudge-backlog-commit.js | scripts-tested — PostToolUse on Write, Edit | scripts-tested — hook-input adapter | gate:primary-hooks, gate:hook-input | Reads Claude Code file_path and every path of a Codex apply_patch through hook-input.js (ADR 0055). Codex runs it only after the user trusts it in /hooks, again after any change to hooks.json. Both agent hosts: writes made through a shell command are not seen. |
| module-cycle-hook | Module cycle feedback after a `.csproj` edit (opt-in) | enforcement | hook:guard-module-cycles.js | scripts-tested — PostToolUse on Write, Edit | scripts-tested — hook-input adapter | gate:module-deps-hook, gate:hook-input | Reads every .csproj path of a Claude Code edit or a Codex apply_patch through hook-input.js (ADR 0055). Codex runs it only after the user trusts it in /hooks, again after any change to hooks.json. Both agent hosts: writes made through a shell command are not seen; module-deps -Check in a completion gate is the guarantee. |

## Intentional asymmetries

- `worktree-mode`, `worktree-cleanup` — worktree mode is Claude Code-only: it
  runs on the Workflow runtime, which Codex lacks (ADR 0029, ADR 0030). Codex
  worktree mode is not wanted; CrossHostParity Stage 3 records what it would need.
- `workflow-status` — Claude Code-only: it reads Claude Code's Workflow
  journals, and Codex runs write none.
- `review-and-gates` — this repo's green gate needs the `claude` CLI
  (`claude plugin validate .`), so a developer with only Codex installed cannot
  pass it.
- `lean-mode`, `execute-feature`, `quick-fix` — a mechanism difference, not a
  capability difference: Claude Code runs tasks through the Workflow runtime,
  Codex through the `CODEX.md` sequential subagent loop. Both use the same
  worker prompt and result schema, kept equal by the task-contract suite
  (ADR 0054). The Workflow runtime is never emulated (ADR 0029).
- primary-edit-guard, branch-switch-guard, backlog-commit-nudge, module-cycle-hook — Codex runs plugin hooks only after the user trusts them in /hooks, again after each hooks.json change; this re-trust is accepted and documented rather than not shipping hooks to Codex (ADR 0055).

## Smoke evidence

A smoke record is the evidence for `verified`: one real run of the smoke
scenarios on one agent host and surface, written to
`docs/host-parity/smoke/<YYYY-MM-DD>-<claude-code|codex>-<cli|vscode|desktop>.md`
in the format described in `docs/host-parity/smoke/README.md`. Cite it in a
row's Evidence as `smoke:<record-id>`. A record with a `fail` result is kept as
evidence for `partial`, never for `verified`. No smoke record exists yet, so no
capability is `verified`.
