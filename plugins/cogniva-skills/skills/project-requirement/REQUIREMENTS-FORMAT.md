# Requirements Format

Project requirements live at `docs/REQUIREMENTS.md`. This file captures what the
project must deliver, organized by section, with a lifecycle from draft through
verified. Add with `/cogniva-skills:project-requirement`.

## Structure

> **Numbering resets to 1 in each section.** Each section maintains its own
> independent numbering sequence. `## Functional Requirements` starts at 1,
> `## Non-Functional Requirements` starts at 1, etc. **Never use global
> numbering.** This is the same per-section numbering convention used in
> REFERENCES.md.

```markdown
# Requirements

Project requirements organized by domain area. Each requirement carries a
RFC 2119 severity level and a lifecycle status from draft to verified.

## Functional Requirements

1.1 **User Authentication**
   - **Severity:** MUST
   - **Status:** agreed
   - **Source:** RFP Section 3.2, meeting 2026-01-15
   - **Description:** The system SHALL authenticate users via SAML 2.0 before
     granting access to any module workspace.
   - **Notes:** Depends on IdP configuration from IT team.

1.2 **Role-Based Access**
   - **Severity:** SHOULD
   - **Status:** draft
   - **Source:** RFP Section 4.1
   - **Description:** The system SHOULD enforce role-based access control so that
     users can only see data relevant to their assigned roles.
   - **Notes:** TBD: which roles are needed.
   - **Open Questions:** Which roles are needed? Who decides?

## Non-Functional Requirements

1.1 **Response Time**
   - **Severity:** MUST
   - **Status:** implemented
   - **Source:** RFP Section 5.1
   - **Description:** The system MUST respond to all API requests within 200 ms
     for 95th percentile of requests under normal load.
   - **Notes:** Performance testing scheduled for 2026-03-01.

1.2 **Audit Logging**
   - **Severity:** MUST NOT
   - **Status:** verified
   - **Source:** Compliance policy CP-2024-07
   - **Description:** ~~The system MUST NOT log plaintext passwords.~~
   - **Notes:** ~~Verified during security review on 2026-02-15.~~
```

## Entry Grammar

Each requirement is a numbered list item within its section. Numbers are
auto-assigned; never renumber when adding or removing.

### Numbering

Each section has its own independent numbering sequence that starts at 1.
The `## Functional Requirements` section's first entry is `1.`, the
`## Non-Functional Requirements` section's first entry is also `1.`, and so on.

**Never use global numbering across sections.** This is the same convention
as REFERENCES.md.

### Field grammar

Each entry follows this structure:

```markdown
N.M **<Title>**
   - **Severity:** <MUST | SHOULD | SHOULD NOT | MUST NOT>
   - **Status:** <draft | agreed | implemented | verified>
   - **Source:** <document, section, or conversation reference>
   - **Description:** <full requirement text>
   - **Notes:** <additional context, dependencies, clarifications>
   - **Open Questions:** <unresolved items requiring stakeholder input> (optional)
```

### Field rules

- **Number:** auto-increment, per-section, append-only. Never delete or renumber.
- **Title:** bold, title case. Short, descriptive, action-oriented.
- **Severity:** one of the four RFC 2119 terms:
  - **MUST** — absolute requirement, no exceptions.
  - **SHOULD** — strong expectation; exceptions require documented justification.
  - **SHOULD NOT** — strong expectation against; exceptions require documented justification.
  - **MUST NOT** — absolute prohibition, no exceptions.
- **Status:** one of four lifecycle stages:
  - **draft** — captured but not yet reviewed or agreed upon.
  - **agreed** — reviewed and accepted by stakeholders.
  - **implemented** — work is complete; awaiting verification.
  - **verified** — confirmed as implemented and working as specified.
- **Source:** reference to the origin of the requirement (RFP section, meeting date, email, conversation). Be specific enough to trace back.
- **Description:** full requirement text in present or future tense. Answer: what the system shall do. Keep it testable — if you can't define acceptance criteria, refine it.
- **Notes:** any additional context, dependencies, clarifications, or clarifications. Open questions should be moved to the 'Open Questions' field.
- **Open Questions:** (optional) unresolved items that require stakeholder input or clarification. Each question should be a distinct, answerable item. This field should be used in place of 'Notes' for open questions or lingering decisions.

## Default Sections

When creating a new `docs/REQUIREMENTS.md`, use these default sections:

| Section Heading | Purpose |
|-----------------|---------|
| `## Functional Requirements` | What the system must do |
| `## Non-Functional Requirements` | Quality attributes and constraints |
| `## Constraints` | Technical, regulatory, or business constraints |
| `## Assumptions` | Things taken as true for planning purposes |

Additional sections may be added as the project domain requires. Section names
should be short noun phrases. If you're generating documentation based on an RFP
or similar document that comes from a customer, you SHOULD retain the same
sections in the extracted document. When in doubt, ask the user.

## Status Transitions

| From | To | When |
|------|-----|------|
| draft | agreed | Stakeholders have reviewed and accepted |
| agreed | implemented | Work is complete |
| implemented | verified | Testing or review confirms correctness |

Status moves forward only. To move backward, strike through the current status
line and add a new one with the earlier status and a `-- reverted: <reason>` note.

## Retired Requirements

Retired requirements use strikethrough on the title and description lines,
appended with a `-- retired: <reason>` note. Never delete an entry.

```markdown
~~1.3 **Legacy Format Export**~~
   - **Severity:** SHOULD
   - ~~**Status:** agreed~~
   - **Source:** RFP Section 6.0
   - ~~**Description:** The system SHALL export data in legacy CSV format.~~
   - **Notes:** ~~Retired: client dropped legacy format in Q3 2026.~~
```

## Rules

- **Append-only.** Never delete, reorder, or renumber entries. When a
  requirement is retired, strike through its title and description and append
  a `-- retired: <reason>` note.
- **One requirement per entry.** Do not combine multiple requirements into a
  single item. If a requirement has multiple sub-conditions, split them into
  separate numbered entries.
- **RFC 2119 severity.** Use MUST, SHOULD, SHOULD NOT, or MUST NOT. Do not
  substitute synonyms (e.g., "will", "needs to", "expected to") — they weaken
  the requirement.
- **Source required.** Every entry must cite where it came from. If you cannot
  trace it to a document, meeting, or conversation, ask the user to confirm the
  origin before adding.
- **Link from decisions.** When a plan, spec, or ADR cites a requirement,
  link to the entry's anchor: `[User Authentication](docs/REQUIREMENTS.md#user-authentication)`.
- **Propose-then-confirm.** Before adding a requirement, show the draft to the
  user and confirm it belongs.
- **Status reflects reality.** Update status when work completes. Do not batch
  status updates — update them as they happen.

## Common Mistakes

- **Using global numbering.** The first entry in each section is always `1.`.
  If Functional Requirements has 3 entries and you add to Constraints, the
  first Constraints entry is `1.`, not `4.`. This is the same convention as
  REFERENCES.md.
- **Combining multiple requirements into one entry.** Each distinct requirement
  gets its own numbered entry, even if they are closely related.
- **Omitting the Source line.** Every entry must cite its origin. If you can't
  trace it, ask the user before adding.
- **Using vague severity terms.** Replace "will", "needs to", "expected to" with
  MUST, SHOULD, SHOULD NOT, or MUST NOT.
- **Skipping status updates.** Keep status current. Stale status misleads
  stakeholders about project progress.

## Gap Analysis

A gap analysis compares implemented/verified requirements against the full set
to identify what remains. When producing a gap analysis:

1. List all requirements with status `draft` or `agreed` that have no matching
   implemented work (no linked ADR, spec, or PR).
2. List all requirements with status `implemented` but not yet `verified`.
3. Flag any MUST requirements that are not yet implemented or verified.
4. Note any requirements blocked on external dependencies.

## Executive Summary

An executive summary is a stakeholder-facing overview. When producing a summary:

1. State the total count of requirements by section.
2. Show the status distribution: draft, agreed, implemented, verified counts.
3. Highlight MUST requirements that are not yet implemented or verified.
4. Note any critical blockers or dependencies.
5. Keep it to one page — no more than 5-7 bullet points.
