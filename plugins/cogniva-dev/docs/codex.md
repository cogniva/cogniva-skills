# Dual-host — cogniva-dev under Claude Code and OpenAI Codex

cogniva-dev is a **dual-host** plugin: the same toolkit installs and runs both
under Claude Code and under OpenAI Codex. Nothing about the skills is forked per
host — only the executor backend differs, and only where it has to.

## Packaging

- **One `skills/` tree, two manifests.** `plugins/cogniva-dev/` ships
  `.claude-plugin/plugin.json` (Claude Code) and `.codex-plugin/plugin.json`
  (Codex) side by side. Both point at the same `plugins/cogniva-dev/skills/`
  directory; the Codex manifest does it explicitly with `"skills": "./skills/"`,
  a plugin-root-relative path.
- **Checked against OpenAI's documentation (2026-08-19); runtime behaviour per
  agent host is tracked in the cogniva-skills repo's `docs/host-parity.md`.**
  The manifest location
  (`.codex-plugin/plugin.json`), the `"skills": "./skills/"` key with
  `./`-prefixed plugin-root-relative paths, marketplace-based install, the
  Codex CLI `/plugins` browser, and new-session skill visibility all match the
  official plugin docs: https://developers.openai.com/codex/plugins/build and
  https://learn.chatgpt.com/docs/build-plugins (the canonical docs domain the
  former redirects to). Two refinements from those docs: marketplaces can also
  be registered non-interactively with `codex plugin marketplace add
  <owner/repo | ./path>`, and loose `.agents/skills` skills hot-reload while
  plugin-bundled skills need a fresh session.
- **Never duplicate skill content per host.** There is no `skills-codex/` and
  never will be. Host-specific behaviour lives in an *overlay* file beside the
  skill it modifies (for example `execute-feature/CODEX.md`), which the skill
  reads only when the host requires it — the same pattern `WORKTREE.md` uses for
  worktree mode.
- **The version lives in THREE files and they must match:**
  - `plugins/cogniva-dev/.claude-plugin/plugin.json`
  - `plugins/cogniva-dev/.codex-plugin/plugin.json`
  - the `cogniva-dev` entry in the top-level `.claude-plugin/marketplace.json`

  `claude plugin validate .` reports a mismatch only as a warning and still
  exits 0; the marketplace repo's green gate fails on it (its `manifest-parity`
  check, `scripts/check-plugin-manifests.ps1`). Bump all three in the same
  commit and confirm with:

  ```
  grep -n '"version"' plugins/cogniva-dev/.claude-plugin/plugin.json plugins/cogniva-dev/.codex-plugin/plugin.json .claude-plugin/marketplace.json
  ```

## Install under Codex

1. Make sure the marketplace hosting cogniva-dev is configured for your Codex
   CLI.
2. Install the plugin from that marketplace with the Codex CLI's `/plugins`
   command.
3. **Start a NEW Codex session.** Skills from a freshly installed plugin are not
   visible in the session that installed them.

For local skill authoring and testing you can instead rely on Codex's
`.agents/skills` discovery — drop or symlink a skill directory there and iterate
without reinstalling. That is a development convenience only: **the plugin is
the distribution mechanism**, and anything you want other people to have must
ship through the manifest.

## Backend selection

`execute-feature` and `quick-fix` need a way to run each task in a fresh, lean
subagent. How that happens depends on the host:

- **Claude Code** — the background Workflow runtime. The skill dispatches a
  generated `*.workflow.js` run; see
  `skills/execute-feature/WORKFLOW-NOTES.md` for the runtime's constraints and
  the journal it writes.
- **Codex** — the Workflow tool does not exist. When a skill detects that the
  Workflow tool is unavailable in the session, it follows its `CODEX.md` overlay
  instead: a **sequential loop of fresh subagents**, one per task. Both
  executors share one worker contract: each prompt is built by
  `scripts/new-task-prompt.ps1` (kept byte-identical by test to the prompt the
  Workflow template builds), and each reply ends with one JSON result that
  conforms to `templates/task-result.schema.json` (kept equal by test to the
  schema the Workflow template passes to its agents) and is checked by
  `scripts/test-task-result.ps1`; a malformed reply counts as `BLOCKED`. Tasks
  run strictly in order in the same workspace; there is no reviewer fan-out
  and no parallelism.

**No Workflow-API emulation.** The Codex backend never installs, shims, or
hand-rolls Claude's Workflow JS API. The subagent loop *is* the Codex backend;
if you find yourself writing a `Workflow(...)` stub under Codex, stop.

## Lean policy

Under Codex, runs are **lean mode** — work happens directly on the branch you
already have checked out.

- **Defaults:** `commits=none` and `plan=ephemeral`.
- **`commits=` is the sole commit authority.** Under `commits=none` the run
  commits NOTHING — implementation, plans (even persisted ones), ride-alongs,
  ADR fixes, and repo-obligation output all stay uncommitted in the tree.
  Under `commits=final` the run makes exactly ONE commit, only after every
  landing gate (including the green gate) has passed. No plan flag, repo
  CLAUDE.md block, or later step overrides this.
- **No integration, no push.** A lean run never merges into another branch and
  never touches a remote.
- **Single-slice execution.** `execute-feature ... tasks=one` runs the next
  not-done task, lands it, and hands off listing the tasks remaining — the
  low-autonomy, review-per-slice option. Whole-plan execution stays the
  default and the explicitly higher-autonomy choice.
- **`plan-feature` does not commit by default.** In lean mode the generated
  plan folder is left uncommitted for the user to review; committing it is
  opt-in (`commits=final`). Worktree mode is unchanged.
- **`READY FOR REVIEW` finish.** The run ends by emitting the detailed handoff
  defined in `skills/execute-feature/HANDOFF.md` — what changed, what was
  checked, what was skipped, what is still dirty. `READY FOR REVIEW` means the
  executed scope (the whole feature, or the completed slice under `tasks=one`)
  is complete on this branch; it does not mean approved, integrated, or ready
  to push.
- **Worktree mode is Claude Code only and unchanged there.** It requires the
  Workflow runtime, keeps mandatory per-task commits and persisted plans, and
  integrates by fast-forward. Every skill that would start, integrate or
  clean up worktree-mode work (plan-feature, execute-feature, quick-fix,
  cleanup-work, cleanup-allwork) stops with one line when worktree mode is on
  and the Workflow tool is absent, and the parity record marks worktree mode
  `unsupported` for Codex (ADR 0056).

## Hooks under Codex

cogniva-dev ships four hooks in `hooks/hooks.json`: the primary-checkout edit
guard and branch-switch guard (worktree mode), the backlog-commit nudge, and
the opt-in Module-cycle check. Codex loads that file when
`[features] hooks = true` is set in `~/.codex/config.toml`. Every hook reads its
input through `scripts/hook-input.js`, so Codex payloads are parsed, not only
Claude Code's:

- **Edits.** Codex reports an edit as `apply_patch`, with the whole patch text
  in `tool_input.command`. The adapter reads every `*** Add File:`,
  `*** Update File:`, `*** Delete File:` and `*** Move to:` path, relative to
  the payload's `cwd`. The edit guard denies the patch if ANY of its paths is
  a guarded primary-checkout path, and names only those; the backlog nudge and
  the Module-cycle check act if any path qualifies. Codex routes `apply_patch`
  to the `Write`/`Edit` matchers, so the matchers are the same for both agent
  hosts.
- **Shell commands.** Codex reports shell calls as `Bash` with
  `tool_input.command`; the branch-switch guard reads them the same way on
  both agent hosts.
- **Trust.** Codex runs each hook only after you trust it in `/hooks`, again
  after any change to `hooks.json` (a plugin update can bring one). Re-trust
  after every cogniva-dev update; until then the hooks do not run. This churn
  is accepted and documented rather than avoided by not shipping hooks to
  Codex.
- **Best-effort.** Hooks are best-effort on both agent hosts: they see tool
  payloads, not effects, so a file written by a shell command
  (`Set-Content`, `echo >`, a script) is not seen by the edit guard. The
  guarantees live in the landing checks — the structural check,
  `git diff --check` and the green gate — not in hooks.

## Repository CLAUDE.md under Codex

A target repo's CLAUDE.md stays authoritative for **substantive constraints**:
safety rules, architecture/dependency boundaries, domain invariants,
data-integrity rules, UI constraints, diagnostics requirements, testing
restrictions, review-blocking requirements, and ADR/documentation rules that
constrain what is safe or valid.

**Claude-specific operating mechanics are NOT inherited** merely because
CLAUDE.md describes them: Workflow-runtime mechanics, worktree
creation/integration conventions, Claude-specific hooks or control-console
behaviour, automatic staging/committing, branch/worktree lifecycle machinery,
and Claude-specific model/tool preferences. A `### before-integrate` block that
expresses a substantive repository gate is honoured as a gate; the Claude
lifecycle mechanics around it (commits, worktrees, integration) are not
imported — and nothing in a repo's CLAUDE.md ever overrides `commits=`.
The full rule lives in `skills/execute-feature/CODEX.md`.

## Explicit-only lifecycle skills

The presence of a skill never authorizes a lifecycle operation. The entry
skills that no other skill dispatches or offers to run (`explore-idea`,
`cleanup-work`, `cleanup-allwork`, `repo-init`, `add-module`)
carry invocation metadata for both agent hosts, always as a pair:

- **Claude Code:** `disable-model-invocation: true` in the skill's `SKILL.md`
  frontmatter. Typing the skill (`/cogniva-dev:explore-idea …`) still runs
  it; the model never starts it on its own.
- **Codex:** `agents/openai.yaml` beside the skill, with
  `allow_implicit_invocation: false` under `policy:`. The skill is not offered
  to the model automatically; naming it (`$explore-idea …`) still runs it.

The cogniva-skills repo's green gate fails when a skill carries only one of
the pair.

`quick-fix` and `plan-feature` are deliberately not marked: `easy-work-scan`
and `groom-backlog` dispatch them after you approve a shortlist, and the
metadata would block that approved dispatch on both agent hosts. Their
descriptions carry the rule instead: they start only on an explicit request or
an approved dispatch, never because a task resembles them. `execute-feature` is
not marked either: `easy-work-scan` routes an approved deferred stub through
`plan-feature` and then `execute-feature`. Skills that other
skills route through (`backlog`, the routing gate for work any skill surfaces;
`adr`; `glossary`) stay model-invocable for the same reason, and each confirms
with you before it writes. Read-only status and diagnostic skills
(`feature-status`, `module-status`, `repo-status`, `workflow-status`,
`applicable-rules`, `feature-check`, `gate-check`) may still be selected
automatically when appropriate.

## Workflow-neutral guardrails for externally orchestrated work

When ChatGPT or a human owns architecture, sequencing, and lifecycle approval,
use `applicable-rules` before substantive implementation. It reports the
applicable `AGENTS.md` and `CLAUDE.md` authority chain, placement constraints,
and obvious Host/Contracts conflicts without changing repository state.

Use `feature-check` for `preflight`, `review`, and `commit-ready` evidence. It
delegates discovery to `applicable-rules` and mechanical validation to
`gate-check`; neither skill stages, commits, integrates, pushes, creates a
worktree, or mutates plans, backlogs, or ADRs. Heavy lifecycle skills remain
available when explicitly chosen and keep their established default behavior.

## Resume under Codex

Resume is checkbox-driven in both hosts: re-running the skill re-parses the plan
and skips every task whose checkboxes are all ticked.

- **Persisted plans** (`plan=persisted`) live under `docs/plans/<Module>/<Feature>/`
  and are tracked, so resume works across sessions and across clones.
- **Ephemeral plans** (`plan=ephemeral`, the lean default) live under
  `.plans-staging/<Module>/<Feature>/`, ignored via `.git/info/exclude` and never
  committed. Checkbox resume works identically against that scratch copy, which
  **survives sessions on the same clone but is not tracked** — clone the repo
  elsewhere, or delete `.plans-staging/`, and the resume state is gone.
