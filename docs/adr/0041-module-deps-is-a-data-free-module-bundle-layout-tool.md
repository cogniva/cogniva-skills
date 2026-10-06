# module-deps is a data-free Module bundle layout tool with an opt-in cycle check

**Provenance:** Suggested by human

`module-deps` graphs only the Module bundle layout (`src/Modules/<Name>/`) that
`add-module` scaffolds, and ships no repository-specific data. Module
descriptions are display-only and come from the repo glossary's
`## <Name> (Module)` entries; allowed cycles come from the repo's
`docs/architecture/allowed-cycles.txt`. `-Check` is always callable on its own.
Edit-time feedback is a Claude Code `PostToolUse` adapter that acts only where
a repo opts in with `"moduleDepsCheck": true` in `.claude/cogniva-dev/policy.json`;
it runs after the edit, so it asks for a correction rather than preventing one.
Hard enforcement runs `-Check` in a completion gate.
