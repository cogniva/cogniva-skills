# Cogniva — shared tooling marketplace

Cogniva's Claude Code plugin marketplace (`cogniva`). Two plugins: **cogniva-skills** and **repo-foundry**.

| Piece | Purpose |
|---|---|
| `plugins/cogniva-skills/skills/glossary` | Glossary lookup (docs/glossary) before codebase search |
| `plugins/cogniva-skills/skills/auto-doc` | Auto-document architectural decisions as ADRs |
| `plugins/cogniva-skills/plugin-template` | Starter template for new skills |
| `plugins/repo-foundry/skills/repo-init` | Scaffold a brand-new Module-architecture .NET repo |
| `plugins/repo-foundry/skills/add-module` | Add a Module (vertical slice) to an existing repo |
| `plugins/repo-foundry/skills/plan-to-html` | Convert a markdown plan/spec to self-contained HTML |
| `plugins/repo-foundry/hooks` | Auto-regenerate HTML twins when plans/specs are written |
| `docs/strategy.md` | Conventions + tooling decisions |
| `docs/glossary/README.md` | Canonical glossary (architecture terms) |

## Install into any repo

In Claude Code, from the consuming repo (local path or `cogniva/cogniva-skills` from GitHub):

```
/plugin marketplace add c:\WorkingGit\NewRepo
/plugin install repo-foundry@cogniva
/plugin install cogniva-skills@cogniva
```

Then run the `repo-init` skill in an empty repo, or `add-module` in an existing one.

## Develop

Tests: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1`
Validate plugin: `claude plugin validate .`
