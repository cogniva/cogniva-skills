---
name: project-requirement
description: Capture, track, and analyze project requirements stored in docs/REQUIREMENTS.md. Supports adding structured requirements, viewing by severity or status, refining loose requirements, gap analysis, open-questions review, and executive summaries.
---

# Project Requirement

Manage project requirements stored at `docs/REQUIREMENTS.md`. Requirements are
grouped by section with per-section numbering, RFC 2119 severity levels, and a
lifecycle from draft through verified.

Read `REQUIREMENTS-FORMAT.md` in this skill's directory for the entry format,
status transitions, and rules.

Invoke: `/cogniva-skills:project-requirement [<action>] [<args>]`

## Actions

### `add` — add a requirement to a section

```
/cogniva-skills:project-requirement add --section "Functional Requirements" --title "User Authentication" --severity MUST --source "RFP Section 3.2" --description "The system SHALL authenticate users via SAML 2.0 before granting access."
```

All flags are optional — when omitted, ask the user interactively.

**Steps:**

1. **Check existence.** Read `docs/REQUIREMENTS.md`. If it does not exist,
   propose creating it with the header and default sections from
   `REQUIREMENTS-FORMAT.md#default-sections`.
2. **Locate the section.** Find the `## <section>` heading. If the section
   exists, use it. If not, propose creating it after the last existing section
   (or after the default sections if all defaults exist).
3. **Determine the number.** The new number is one greater than the last entry
   in that section. If the section is empty, start at `1.`.
4. **Propose the entry.** Show the draft entry to the user with the inferred
   or provided fields. Confirm before writing.
5. **Append the entry.** Follow the grammar in `REQUIREMENTS-FORMAT.md`.
   Append after the last entry in the section. Never renumber existing entries.

### `view` — show existing requirements

```
/cogniva-skills:project-requirement view [--section <name>] [--severity MUST|SHOULD|MUST NOT|SHOULD NOT] [--status draft|agreed|implemented|verified]
```

- No flags → print all sections and entries.
- `--section <name>` → print only that section.
- `--severity <level>` → print only entries matching that severity.
- `--status <status>` → print only entries matching that status.
- Flags may be combined; entries matching all criteria are shown.
- `--format markdown` → output as markdown (default).
- `--format list` → output as a plain numbered list.

### `refine` — refine a loose requirement into formal language

```
/cogniva-skills:project-requirement refine "System must handle user login" --severity MUST
```

Takes a natural-language statement and produces a structured draft entry:

1. Parse the statement to infer severity (default: SHOULD if not specified).
2. Extract a title from the statement (title case, short).
3. Rewrite the description using RFC 2119 language (SHALL/SHOULD/MUST NOT).
4. Rigorously check for hidden assumptions or unanswered questions. If any are found, add them as 'Open Questions', one question per indented bullet line (never combine on a single line with commas or semicolons). If there are multiple open questions, format them exactly as shown below (each on its own line):
  - **Open Questions:**
   - Which roles are needed?
   - Who decides?
5. Show the draft entry and ask the user to confirm or adjust.
6. On confirmation, use `add` to write the entry.

### `status` — show status summary

```
/cogniva-skills:project-requirement status [--section <name>]
```

Produces a status summary table:

```
Status Summary
==============
Functional Requirements:
  draft:          3
  agreed:         2
  implemented:    1
  verified:       0

Non-Functional Requirements:
  draft:          1
  agreed:         0
  implemented:    2
  verified:       1

Total: 9 requirements (33% verified)
```

- `--section <name>` → show summary for one section only.
- No flag → show all sections plus a total row.

### `open-questions` — list all unresolved questions across all sections

```
/cogniva-skills:project-requirement open-questions [--section <name>]
```

Extracts all 'Open Questions' fields (each item on its own bullet line) from
every requirement and presents them as a consolidated list grouped by section:

```
Open Questions
==============

Functional Requirements:
  1.2 Role-Based Access
    - Which roles are needed?
    - Who decides?

Constraints:
  3.1 Permission Review Scope Limitation
    - Should we expand beyond sensitive folders?
```

- `--section <name>` → show open questions for one section only.
- No flag → show all sections.
- If no section has any open questions, print: "No open questions found."

### `gap` — produce a gap analysis

```
/cogniva-skills:project-requirement gap
```

Produces a gap analysis per `REQUIREMENTS-FORMAT.md#gap-analysis`:

1. List draft/agreed requirements with no matching implemented work.
2. List implemented-but-not-verified requirements.
3. Flag all MUST requirements not yet implemented or verified.
4. Note any requirements blocked on external dependencies.
5. Format as a structured report with severity-weighted priorities.

### `summary` — produce an executive summary

```
/cogniva-skills:project-requirement summary [--audience stakeholders|engineering|management]
```

Produces an executive summary per `REQUIREMENTS-FORMAT.md#executive-summary`:

1. Total count by section.
2. Status distribution across all sections.
3. MUST requirements not yet implemented or verified.
4. Critical blockers and dependencies.
5. Tailor tone to audience:
   - **stakeholders** — business impact, risk, timeline concerns.
   - **engineering** — implementation gaps, technical blockers.
   - **management** — progress %, resource needs, decisions needed.

## Passive monitoring

During any design, planning, or scoping session, watch for:

1. **Scope language** — when the user says "must", "should", "will need to",
   "required", "constraint", "deliverable", or similar scope-defining language.
   Prompt: *"You mentioned '[statement]' — should I capture this as a
   requirement in `docs/REQUIREMENTS.md`?"*

2. **Uncaptured source material** — when the user references an RFP section,
   meeting note, or email that contains requirements but no entry exists.
   Prompt: *"I see requirements in [source] that are not yet in the requirements
   doc. Should I extract them?"*

3. **Status drift** — when the user says "we finished" or "done" for a feature
   that has corresponding `agreed` or `implemented` requirements. Suggest
   updating the status.

4. **New section needs** — when requirements are being added that clearly belong
   to a new domain area not yet represented as a section. Propose a new section.

## Rules

- **Append-only.** Never delete, reorder, or renumber entries. When a
  requirement is retired, strike through its title and description and append
  a `-- retired: <reason>` note.
- **RFC 2119 severity.** Use MUST, SHOULD, SHOULD NOT, or MUST NOT. Do not
  substitute synonyms (e.g., "will", "needs to", "expected to") — they weaken
  the requirement.
- **Source required.** Every entry must cite its origin. If you cannot trace it,
  ask the user before adding.
- **Link from decisions.** When a plan, spec, or ADR cites a requirement,
  link to the entry's anchor: `[User Authentication](docs/REQUIREMENTS.md#user-authentication)`.
- **Propose-then-confirm.** Before adding a requirement, show the draft to the
  user and confirm it belongs.
- **Update status as it happens.** Do not batch status updates.
- **One requirement per entry.** Split compound requirements into separate entries.
