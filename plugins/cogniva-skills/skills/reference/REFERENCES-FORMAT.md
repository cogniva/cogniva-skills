# References format

External documents, standards, and URLs that inform or justify decisions live at
`docs/REFERENCES.md`. This file is the project's shared bibliography — every
decision that cites an external source links back here.

## Structure

> **Numbering resets to 1 in each section.** Each section maintains its own
> independent numbering sequence. `## Standards` starts at 1, `## Specifications`
> starts at 1, `## Publications` starts at 1, etc. **Never use global numbering.**
> This is intentional — it makes each section independently navigable and is unlike
> most bibliographies, which use a single global sequence.

```markdown
# References

External documents, standards, and specifications that inform or justify
decisions in this project. Add with `/cogniva-skills:reference`.

## Standards

1. **ISO/IEC/IEEE 42010:2011** — Systems and software engineering — Architecture description
   - **Type:** Standard
   - **URL:** https://www.iso.org/standard/45138.html
   - **Relevance:** Defines the architecture description concepts used in module boundaries

## Specifications

1. **OpenAPI 3.1.0** — Open API Specification
   - **Type:** Specification
   - **URL:** https://spec.openapis.org/oas/v3.1.0
   - **Relevance:** Contract format for all module APIs

## Articles

1. **A Guide to the Business Analysis Body of Knowledge (BABOK Guide)**
   - **Type:** Publication
   - **URL:** https://www.iiba.org/standards/babok-guide/
   - **Relevance:** Requirements elicitation and analysis techniques referenced in design decisions

## Links

1. **Microsoft .NET Documentation**
   - **URL:** https://docs.microsoft.com/dotnet/
   - **Relevance:** Primary reference for .NET framework conventions and patterns
```

> **Note:** Each section restarts numbering at 1. This is intentional and unlike
> most bibliographies.

## Entry grammar

Each entry is a numbered list item (numbers are auto-assigned; never renumber
when adding or removing — append and let the reader follow the link). Each
section has its own separate numbering.

### Numbering

Each section has its own independent numbering sequence that starts at 1.
The `## Standards` section's first entry is `1.`, the `## Specifications`
section's first entry is also `1.`, and so on.

**Never use global numbering across sections.** This is the most common
mistake — the format intentionally uses per-section numbering, which is
unusual for bibliographies but makes each section independently navigable.

```markdown
1. **<Title>**
   - **Type:** <Standard | Specification | Publication | Article | Link>
   - **URL:** <https://...>
   - **Relevance:** <one line — why this project cares about it>
```

### Field rules

- **Number:** auto-increment, per-section, append-only. Never delete or renumber.
- **Title:** bold, title case. Use the canonical/official title.
- **Type:** one of the values above. Pick the closest match; if unsure, use `Link`.
- **URL:** absolute, https when available. Omit the line for entries without a URL (rare).
- **Relevance:** one line, present tense. Answer: *why does this project need this reference?*

## Categories

Group entries under `##` headings. The five canonical categories are:

| Heading | What goes here |
|---------|---------------|
| `## Standards` | Published standards (ISO, IEEE, OASIS, IEC, etc.) |
| `## Specifications` | Technical specs, protocols, API contracts (OpenAPI, JSON Schema, etc.) |
| `## Publications` | Books, guides, body-of-knowledge references (BABOK, etc.) |
| `## Articles` | Blog posts, tutorials, conference papers, white papers |
| `## Links` | General URLs, documentation sites, tooling references |

New categories may be added when the project needs a distinct grouping (e.g.
`## Internal` for team-only docs). Keep category names short and noun-based.

## Rules

- **Append-only.** Never delete, reorder, or renumber entries. When a reference
  becomes stale, strike through its title and note the reason — keep the entry.
- **One source per entry.** Do not combine multiple documents into a single item.
- **Relevance is required.** Every entry must explain why the project cares.
  If you cannot write a relevance line, the entry does not belong here.
- **Link from decisions.** When a plan, spec, or ADR cites an external source,
  link to the entry's anchor: `[ISO/IEC/IEEE 42010](docs/REFERENCES.md#isoiee-ieee-420102011)`.
- **Propose-then-confirm.** Before adding an entry, show the draft to the user
  and confirm it belongs.

## Common Mistakes

- **Using global numbering.** The first entry in each section is always `1.`.
  If Standards has 3 entries and you add to Specifications, the first
  Specifications entry is `1.`, not `4.`. This is the most common mistake.
- **Combining multiple sources into one entry.** Each external document gets its
  own numbered entry, even if they're from the same organization.
- **Omitting the Relevance line.** Every entry must explain why the project cares.
  If you can't write one, the entry doesn't belong here.

## Migrating from inline citations

If a decision document cites external sources inline (e.g. "see [this ISO standard](url)"),
move the source to `docs/REFERENCES.md`, assign it a number, and replace the inline
citation with an anchor link: `[ISO/IEC/IEEE 42010](docs/REFERENCES.md#isoiee-ieee-420102011)`.

Delete the old inline URL after migration.
