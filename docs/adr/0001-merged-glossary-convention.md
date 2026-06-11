# Merged glossary convention: docs/glossary/README.md with CONTEXT.md content rules

Two glossary conventions collided when the cogniva-skills repo merged into the cogniva marketplace: the `glossary` skill read `CONTEXT.md`/`CONTEXT-MAP.md` (bold terms, `_Avoid_` aliases, lookup-before-search gate), while repo-foundry used `docs/glossary/README.md` (`## Term` headings with anchors, Mermaid, term-linking in communication). We merged them: the glossary lives at `docs/glossary/README.md`, entries use `## Term` headings (anchors are required for clickable links and plan-to-html auto-linking) plus the CONTEXT.md content rules (`_Avoid_` aliases, what-it-IS definitions, no implementation details, no general programming concepts), and the skill keeps its glossary-before-codebase-search gate with legacy `CONTEXT.md` support for older repos.

## Considered Options

- **Adopt CONTEXT.md wholesale** — rejected: bold terms have no anchors, so per-term linking and HTML auto-linking break; root-level file loses the stable `docs/` entry point.
- **Pointer bridge (root CONTEXT.md pointing at docs/glossary)** — rejected: permanent two-file indirection that drifts.

Full comparison: `docs/glossary/conventions-comparison.html`.
