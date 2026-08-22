# Cogniva — shared tooling marketplace

Cogniva's plugin marketplace (`cogniva`) for Claude Code and OpenAI Codex — both plugins are dual-host. Two plugins:

| Plugin | Purpose |
|---|---|
| **cogniva-skills** | General-purpose skills for any project |
| **cogniva-dev** | Development-specific skills for the Module architecture |

### cogniva-skills

| Piece | Purpose |
|---|---|
| `plugins/cogniva-skills/skills/glossary` | Glossary lookup (docs/glossary) before codebase search |
| `plugins/cogniva-skills/skills/reference` | Shared bibliography of standards, publications, and links |
| `plugins/cogniva-skills/skills/project-requirement` | Requirements capture, tracking, and analysis (docs/REQUIREMENTS.md) |
| `plugins/cogniva-skills/skills/project-context` | Persistent non-technical business context for long sessions |
| `plugins/cogniva-skills/plugin-template` | Starter template for new skills |
| `plugins/cogniva-skills/templates/glossary` | Seeded glossary for new repos |

### cogniva-dev

| Piece | Purpose |
|---|---|
| `plugins/cogniva-dev/skills/adr` | Record architectural decisions as ADRs (confirm-first) |
| `plugins/cogniva-dev/skills/backlog` | Capture planned deferrals — work with a stated reason to wait |
| `plugins/cogniva-dev/skills/repo-init` | Scaffold a brand-new Module-architecture .NET repo |
| `plugins/cogniva-dev/skills/add-module` | Add a Module (vertical slice) to an existing repo |
| `plugins/cogniva-dev/skills/explore-idea` | Brainstorm and develop an idea before any planning |
| `plugins/cogniva-dev/skills/plan-feature` | Design one feature with a strong model before implementation |
| `plugins/cogniva-dev/skills/execute-feature` | Execute a feature plan task-by-task in isolated worktrees |
| `plugins/cogniva-dev/skills/quick-fix` | Planless sibling of execute-feature for small changes |
| `plugins/cogniva-dev/skills/cleanup-work` | Close out this session's integrated worktrees |
| `plugins/cogniva-dev/skills/cleanup-allwork` | Checkout-wide reap of every cleanupable worktree |
| `plugins/cogniva-dev/skills/module-deps` | Regenerate the Module dependency graph from .csproj references |
| `plugins/cogniva-dev/skills/feature-status` | Read-only scan of per-feature task progress |
| `plugins/cogniva-dev/skills/module-status` | Read-only view of one Module's features and backlog |
| `plugins/cogniva-dev/skills/repo-status` | Cross-Module roll-up of the live roadmap |
| `plugins/cogniva-dev/skills/workflow-status` | Read-only status of background Workflow runs |
| `plugins/cogniva-dev/scripts/` | Worktree, integration, and ledger scripts |
| `plugins/cogniva-dev/hooks/` | Session hooks |
| `plugins/cogniva-dev/templates/` | Repo scaffolding templates and workflow scripts |

cogniva-dev's workflow skills run in two modes: **lean** (default — work
directly on your branch; no worktrees, no state tracking) and **worktree**
(per-clone opt-in via untracked `.claude/cogniva-dev.local.json`
`{ "worktrees": true }` — isolated worktrees, guard hooks, auto-integration).
See `plugins/cogniva-dev/docs/worktrees.md`.

### Two supported workflows

Claude-owned lifecycle automation and externally orchestrated bounded
implementation satisfy the same repository engineering obligations. They differ
only in who owns sequencing and lifecycle authorization.

| Skill family | Responsibility | Lifecycle effect |
|---|---|---|
| `applicable-rules`, status skills | Authority and constraint discovery | Read-only |
| `feature-check`, `gate-check` | Placement review and mechanical readiness evidence | Validation only |
| `execute-feature`, `quick-fix` | Implement bounded work | Implementation; lifecycle behavior is explicit to the chosen mode |
| `plan-feature`, ADR/backlog, cleanup skills | Design or lifecycle transitions | Mutating; explicit invocation required |

For externally orchestrated work, use `applicable-rules` before implementation,
`feature-check preflight` / `review` around the bounded diff, and
`feature-check commit-ready` for evidence. These skills neither acquire nor
infer authority to create branches or worktrees, mutate plans or ADRs, commit,
integrate, push, or clean state.

### Install into any repo

In Claude Code, from the consuming repo (GitHub, or substitute the path of a local clone):

```
/plugin marketplace add cogniva/cogniva-skills
/plugin install cogniva-skills@cogniva
/plugin install cogniva-dev@cogniva
```

Then run the `repo-init` skill in an empty repo, or `add-module` in an existing one.

Under OpenAI Codex:

1. Register the marketplace: `codex plugin marketplace add cogniva/cogniva-skills`
   (or a local clone path — Codex reads `.claude-plugin/marketplace.json` as a
   legacy-compatible marketplace).
2. Install the plugins with the Codex CLI's `/plugins` command.
3. Start a NEW Codex session — freshly installed plugin skills are not visible
   in the session that installed them.

See `plugins/cogniva-dev/docs/codex.md` and `plugins/cogniva-skills/docs/codex.md` for details.

### Develop

Validate plugins: `claude plugin validate .`
