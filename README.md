# Cogniva — shared tooling marketplace

Cogniva's Claude Code plugin marketplace (`cogniva`). Two plugins:

| Plugin | Purpose |
|---|---|
| **cogniva-skills** | General-purpose skills for any project |
| **cogniva-dev** | Development-specific skills for the Module architecture |

### cogniva-skills

| Piece | Purpose |
|---|---|
| `plugins/cogniva-skills/skills/glossary` | Glossary lookup (docs/glossary) before codebase search |
| `plugins/cogniva-skills/skills/reference` | Shared bibliography of standards, publications, and links |
| `plugins/cogniva-skills/plugin-template` | Starter template for new skills |
| `plugins/cogniva-skills/templates/glossary` | Seeded glossary for new repos |

### cogniva-dev

| Piece | Purpose |
|---|---|
| `plugins/cogniva-dev/skills/auto-doc` | Auto-document architectural decisions as ADRs |
| `plugins/cogniva-dev/skills/backlog` | Capture deferred or not-yet-planned work |
| `plugins/cogniva-dev/skills/repo-init` | Scaffold a brand-new Module-architecture .NET repo |
| `plugins/cogniva-dev/skills/add-module` | Add a Module (vertical slice) to an existing repo |
| `plugins/cogniva-dev/skills/plan-feature` | Design one feature with a strong model before implementation |
| `plugins/cogniva-dev/skills/execute-feature` | Execute a feature plan task-by-task in isolated worktrees |
| `plugins/cogniva-dev/skills/quick-fix` | Planless sibling of execute-feature for small changes |
| `plugins/cogniva-dev/skills/complete-feature` | Close out an integrated feature |
| `plugins/cogniva-dev/skills/feature-status` | Read-only scan of per-feature task progress |
| `plugins/cogniva-dev/skills/module-status` | Read-only view of one Module's features and backlog |
| `plugins/cogniva-dev/skills/repo-status` | Cross-Module roll-up of the live roadmap |
| `plugins/cogniva-dev/scripts/` | Worktree and integration scripts |
| `plugins/cogniva-dev/hooks/` | Session hooks (Stop: auto-commit plans) |
| `plugins/cogniva-dev/templates/` | Repo scaffolding templates and workflow scripts |

### Install into any repo

In Claude Code, from the consuming repo (GitHub, or substitute the path of a local clone):

```
/plugin marketplace add cogniva/cogniva-skills
/plugin install cogniva-skills@cogniva
/plugin install cogniva-dev@cogniva
```

Then run the `repo-init` skill in an empty repo, or `add-module` in an existing one.

### Develop

Validate plugins: `claude plugin validate .`
