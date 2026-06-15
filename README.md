# Cogniva — shared tooling marketplace

Cogniva's Claude Code plugin marketplace (`cogniva`). One plugin: **cogniva-skills**.

| Piece | Purpose |
|---|---|
| `plugins/cogniva-skills/skills/glossary` | Glossary lookup (docs/glossary) before codebase search |
| `plugins/cogniva-skills/skills/auto-doc` | Auto-document architectural decisions as ADRs |
| `plugins/cogniva-skills/skills/repo-init` | Scaffold a brand-new Module-architecture .NET repo |
| `plugins/cogniva-skills/skills/add-module` | Add a Module (vertical slice) to an existing repo |
| `plugins/cogniva-skills/plugin-template` | Starter template for new skills |
| `docs/strategy.md` | Conventions + tooling decisions |
| `docs/glossary/README.md` | Canonical glossary (architecture terms) |

## Install into any repo

In Claude Code, from the consuming repo (GitHub, or substitute the path of a local clone):

```
/plugin marketplace add cogniva/cogniva-skills
/plugin install cogniva-skills@cogniva
```

Then run the `repo-init` skill in an empty repo, or `add-module` in an existing one.

## Develop

Validate plugin: `claude plugin validate .`
