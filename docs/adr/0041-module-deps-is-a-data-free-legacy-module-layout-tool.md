# module-deps is a data-free legacy Module-layout tool with opt-in enforcement

**Provenance:** Suggested by human

`module-deps` graphs only the legacy `src/Modules/<Name>/` layout that
`add-module` scaffolds, and ships no repository-specific data. Module
descriptions are display-only and come from the repo glossary's
`## <Name> (Module)` entries; allowed cycles come from the repo's
`docs/architecture/allowed-cycles.txt`. `-Check` is always callable on its own.
Blocking enforcement is a Claude Code `PostToolUse` adapter that acts only where
a repo opts in with `"moduleDepsCheck": true` in `.claude/cogniva-dev/policy.json`.
