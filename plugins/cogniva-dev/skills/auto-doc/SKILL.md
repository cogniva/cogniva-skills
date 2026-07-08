---
name: auto-doc
description: The authority on Architecture Decision Records (ADRs) — their format, provenance, relitigation weight, and numbering. Use to record a confirmed architectural decision as an ADR (ALWAYS with explicit human confirmation first), or to check how open an existing decision is to being reopened. Also runs as a quiet background observer during design/planning: it holds ADR-worthy decisions as candidates and offers them for confirmation at natural breakpoints — it never writes one on its own.
---

# auto-doc

The single source of truth for ADRs. Two jobs:

1. **Write ADRs — confirm-first, never silently.** Notice decisions worth
   recording, hold them as candidates, and write an ADR only after a human says yes.
2. **Honour ADRs that already exist.** Before reopening a documented decision, read
   its relitigation weight and respect it.

An ADR is a standing constraint on future work. A noisy pile of unwanted ADRs
constrains development for no benefit — so the bar to *create* one is a human's
explicit approval, and the bar to *reopen* one is set by its provenance.

Read [ADR-FORMAT.md](./ADR-FORMAT.md) for the template, the provenance levels, the
relitigation levels + defaults, and the numbering rule.

## Golden rule

**Never write an ADR without explicit human confirmation.** No exceptions, no
"the decision was obvious", no batching them in silently. If you came up with the
idea yourself, you need the human's explicit yes before it becomes an ADR.

There is **no hard gate** — recording an ADR is never a precondition for writing
code or proceeding. Missing ADRs don't block work; unwanted ADRs do.

## Writing ADRs (confirm-first)

### 1. Observe quietly
During design, brainstorming, or planning, watch for decisions that meet all three
ADR criteria (hard to reverse, surprising without context, a real trade-off — see
ADR-FORMAT). Keep them as a **candidate list in your head**. Do not write anything,
do not interrupt the user's flow to ask mid-thought.

### 2. Offer at a breakpoint
At a natural pause (a section wrapped, a decision settled, the end of a design
pass), present the candidate ADRs to the user for confirmation. For each candidate
give: the one-line decision, the **provenance** you'd assign, and the
**relitigation** weight (state it only if it differs from the provenance default).
Ask the user to confirm, amend, or drop each.

- If YOU proposed the idea and the human hasn't explicitly agreed to it, get that
  agreement before the ADR — that's what makes it *Suggested by agent* rather than
  an ADR you invented.
- Err toward **Suggested by human**; reserve **Required by human** for hard
  requirements the human is clearly committed to, and ask if it's unclear.

### 3. Write only what's confirmed
For each approved candidate, write the ADR per ADR-FORMAT: scan `docs/adr/` for the
next number, fill in title + Provenance + (optional) Relitigation + 1–3 sentences.
Drop the relitigation line when it matches the provenance default. Announce briefly
what you wrote; don't editorialize.

## Honouring existing ADRs (before you reopen a decision)

When your work touches, contradicts, or tempts you to revisit a documented
decision, **read the relevant ADR first** and calibrate to its relitigation weight:

- **Completely open** — no weight; change freely.
- **Open to discussion** — raise it if it genuinely conflicts with current work.
- **Compelling reasons only** — only raise it when the alternative's benefit is
  large; don't reopen on a whim.
- **Blockers only** — leave it alone unless there's no other reasonable option;
  don't relitigate the "why". The limits are usually deliberate and human-chosen
  even when you can't see the reason.

When no relitigation line is present, use the provenance default (see ADR-FORMAT).
If you believe a decision above your threshold really should change, **surface it to
the human with the reason** — don't quietly work around it or repeatedly re-propose
it.

## Direct invocation

You can call `/auto-doc` explicitly to:
- record a specific decision as an ADR (still confirm-first), or
- check the provenance / relitigation posture of an existing decision before acting
  on it.

## Working with the feature-lifecycle skills

`plan-feature`, `execute-feature`, and `quick-fix` handle ADRs as **candidate ADRs
carried in the plan** and only materialize concrete ADR files during execution —
still under human confirmation, obtained during planning. Those skills own that
flow; this skill owns the format, the confirm-first rule, and the honour-existing
rule they all defer to.
