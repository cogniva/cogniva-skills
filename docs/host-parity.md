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
| lean-mode | Lean mode: work on the current branch under `commits=`, `plan=` and `tasks=one` | workflow | mode:lean | untested — Workflow template | untested — `CODEX.md` loop | gate:parse-plan-tasks, gate:git-commit, gate:green-gate-runner | The plan parser, commit wrapper and green-gate runner are gate-covered. Neither agent host's task loop has a suite (the Workflow template gets one in CrossHostParity 05). Under Codex the sandbox may make `.git` read-only (diagnosed in CrossHostParity 06). |
| worktree-mode | Worktree mode: isolated worktree, fast-forward integration, ledger | workflow | mode:worktree | untested — Workflow template and worktree scripts | unsupported — needs the Workflow runtime | gate:integrate-feature, gate:ledger | Codex: worktree execution needs the Workflow runtime, which Codex lacks; a Codex design is deferred (see CrossHostParity Stage 3). Claude Code: the integration and ledger scripts are gate-covered; the worktree task loop is not. |
| execute-feature | Execute a feature plan task by task | workflow | skill:cogniva-dev/execute-feature | untested — Workflow template | untested — `CODEX.md` sequential subagent loop | gate:parse-plan-tasks, gate:git-commit, gate:green-gate-runner | The Codex loop has never run end to end. Task results differ by agent host: a schema-checked object under Claude Code, a textual `DONE`/`BLOCKED` line under Codex (one shared contract in CrossHostParity 07). Model-invocable: routed from easy-work-scan (plugins/cogniva-dev/skills/easy-work-scan/EASY-WORK-CRITERIA.md:73). |
| quick-fix | Small planless changes | workflow | skill:cogniva-dev/quick-fix | untested — Workflow template | untested — `CODEX.md` loop | gate:structural-changes, gate:green-gate-runner | The structural snapshot and landing check are gate-covered. Under Codex the snapshot writes objects into `.git`, which the sandbox may make read-only (CrossHostParity 06). Model-invocable by design: easy-work-scan and groom-backlog dispatch it after approval, and its description states the explicit-start rule. |
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
| primary-edit-guard | Deny edits to the primary checkout in worktree mode | enforcement | hook:guard-primary-edit.js | scripts-tested — PreToolUse on Write, Edit, NotebookEdit | partial — patch edits pass unchecked | gate:primary-hooks | Codex: the `apply_patch` payload is not parsed, so patch edits pass unchecked (fixed in CrossHostParity 08); the hook runs only after the user trusts it in `/hooks`, again after any change to `hooks.json`. Both agent hosts: writes made through a shell command are not seen. |
| branch-switch-guard | Block branch switching in the primary checkout in worktree mode | enforcement | hook:guard-primary-git.js | scripts-tested — PreToolUse on Bash | partial — never exercised as a deny | gate:primary-hooks | Codex reports shell calls as `Bash`, so the guard should fire, but it has never denied a command on Codex; it runs only after the user trusts it in `/hooks`. Both agent hosts: a command the guard does not recognise passes. |
| backlog-commit-nudge | Nudge to commit a backlog capture | enforcement | hook:nudge-backlog-commit.js | scripts-tested — PostToolUse on Write, Edit | partial — patch edits unseen | gate:primary-hooks | Codex: the `apply_patch` payload is not parsed (fixed in CrossHostParity 08); the hook needs trust in `/hooks`. Both agent hosts: writes made through a shell command are not seen. |
| module-cycle-hook | Module cycle feedback after a `.csproj` edit (opt-in) | enforcement | hook:guard-module-cycles.js | scripts-tested — PostToolUse on Write, Edit | partial — untrusted on the reference machine | gate:module-deps-hook | Codex: untrusted on the reference machine, so it has never run there; the `apply_patch` payload is not parsed (CrossHostParity 08). Both agent hosts: writes made through a shell command are not seen. |

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
  Codex through the `CODEX.md` sequential subagent loop. The Workflow runtime is
  never emulated (ADR 0029).

## Smoke evidence

A smoke record is the evidence for `verified`: one real run of the smoke
scenarios on one agent host and surface, written to
`docs/host-parity/smoke/<YYYY-MM-DD>-<claude-code|codex>-<cli|vscode|desktop>.md`
in the format described in `docs/host-parity/smoke/README.md`. Cite it in a
row's Evidence as `smoke:<record-id>`. A record with a `fail` result is kept as
evidence for `partial`, never for `verified`. No smoke record exists yet, so no
capability is `verified`.
