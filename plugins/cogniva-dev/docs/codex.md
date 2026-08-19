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
- **Never duplicate skill content per host.** There is no `skills-codex/` and
  never will be. Host-specific behaviour lives in an *overlay* file beside the
  skill it modifies (for example `execute-feature/CODEX.md`), which the skill
  reads only when the host requires it — the same pattern `WORKTREE.md` uses for
  worktree mode.
- **The version lives in THREE files and they must match:**
  - `plugins/cogniva-dev/.claude-plugin/plugin.json`
  - `plugins/cogniva-dev/.codex-plugin/plugin.json`
  - the `cogniva-dev` entry in the top-level `.claude-plugin/marketplace.json`

  `claude plugin validate .` does NOT catch a mismatch, so bump all three in the
  same commit and confirm with:

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
  instead: a **sequential loop of fresh subagents**, one per task, with a
  **textual `DONE` / `BLOCKED` result contract** parsed by the executor. Tasks
  run strictly in order in the same workspace; there is no reviewer fan-out and
  no parallelism.

**No Workflow-API emulation.** The Codex backend never installs, shims, or
hand-rolls Claude's Workflow JS API. The subagent loop *is* the Codex backend;
if you find yourself writing a `Workflow(...)` stub under Codex, stop.

## Lean policy

Under Codex, runs are **lean mode** — work happens directly on the branch you
already have checked out.

- **Defaults:** `commits=none` and `plan=ephemeral`.
- **No integration, no push.** A lean run never merges into another branch and
  never touches a remote.
- **`READY FOR REVIEW` finish.** The run ends by emitting the detailed handoff
  defined in `skills/execute-feature/HANDOFF.md` — what changed, what was
  checked, what was skipped, what is still dirty. `READY FOR REVIEW` means the
  implementation is complete on this branch; it does not mean approved,
  integrated, or ready to push.
- **Worktree mode is Claude-only and unchanged.** It requires the Workflow
  runtime, keeps mandatory per-task commits and persisted plans, and integrates
  by fast-forward. If worktree mode is on and the Workflow tool is absent, the
  skill stops and says so rather than degrading silently.

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
