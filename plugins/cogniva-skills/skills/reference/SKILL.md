---
name: reference
description: Use when adding, viewing, or managing external references (standards, specifications, publications, articles, URLs) that inform or justify project decisions. Also activates when the user mentions a citation, bibliography, or external source that should be tracked.
---

# Reference

Manage the project's shared bibliography — external documents, standards, and
URLs that inform or justify decisions. Stored in `docs/REFERENCES.md`.

Read `REFERENCES-FORMAT.md` in this skill's directory for the entry format,
categories, and rules.

Invoke: `/cogniva-skills:reference [<action>] [<args>]`

## Actions

### `add` — add a new reference

```
/cogniva-skills:reference add --title "OpenAPI 3.1.0" --type Specification --url https://spec.openapis.org/oas/v3.1.0 --relevance "Contract format for all module APIs"
```

All flags are optional — when omitted, ask the user interactively.

**Steps:**

1. **Read** `docs/REFERENCES.md`. If it doesn't exist, create it with the header
   from `REFERENCES-FORMAT.md` and all five canonical categories.
2. **Dedup.** Check for an existing entry with the same URL or a near-identical
   title. If found, point the user at the existing entry instead of adding a
   duplicate.
3. **Pick the category.** Use the mapping in `REFERENCES-FORMAT.md`. If unsure,
   propose a category and ask the user to confirm.
4. **Append the entry.** Follow the grammar in `REFERENCES-FORMAT.md`. The number
   is one greater than the last entry in the chosen category (or the first entry
   if the category is new).

   **Important: numbering is per-section, not global.** The first entry in
   `## Standards` is `1.`, the first entry in `## Specifications` is also `1.`,
   etc. See `REFERENCES-FORMAT.md#common-mistakes` for details.
5. **Report** the result: category, number, and title.

### `view` — show existing references

```
/cogniva-skills:reference view [--category Standards|Specifications|Publications|Articles|Links]
```

- No flag → print all categories and entries.
- `--category <name>` → print only that category.
- `--format markdown` → output as markdown (default).
- `--format list` → output as a plain numbered list.

### `remove` — archive a reference

```
/cogniva-skills:reference remove <number> [--reason "no longer cited"]
```

Per `REFERENCES-FORMAT.md` rules, references are append-only. "Remove" strikes
through the title and appends a `-- retired: <reason>` note. Never delete an
entry.

### `search` — find references by keyword

```
/cogniva-skills:reference search <keyword>
```

Searches titles, URLs, and relevance lines. Returns matching entries with their
category and number.

## Passive monitoring

During any design, planning, or decision session, watch for:

1. **Inline citations** — when the user or a document cites an external source
   with a URL or name but no entry in `docs/REFERENCES.md`. Prompt: *"I noticed
   you cited [source] — should I add it to the references?"*
2. **Uncited decisions** — when a design decision references a standard, spec, or
   article. If no entry exists, propose adding one before finalizing the decision.
3. **Stale references** — when a linked URL returns a 404 or the user reports a
   broken link. Suggest archiving and replacing with the current URL.

## Rules

- **Append-only.** Never delete or renumber. Strike through and annotate on
  retirement.
- **One source per entry.** Do not combine multiple documents.
- **Relevance required.** Every entry must explain why the project cares.
- **Link from decisions.** When a plan, spec, or ADR cites an external source,
  link to the entry's anchor rather than pasting a raw URL.
- **Propose-then-confirm.** Show the draft entry to the user before writing.
- **Use canonical titles.** Match the official/accepted title of the source.
