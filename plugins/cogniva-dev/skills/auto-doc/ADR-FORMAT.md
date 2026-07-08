# ADR Format

ADRs live in `docs/adr/` and use sequential numbering: `0001-slug.md`,
`0002-slug.md`, etc. Create the `docs/adr/` directory lazily — only when the first
confirmed ADR is written.

> **Never write an ADR without explicit human confirmation.** An ADR is a
> constraint on all future work; it must not appear because an agent inferred one.
> See [SKILL.md](./SKILL.md) for the confirm-first flow.

## Template

```md
# {Short title of the decision}

**Provenance:** {Suggested by agent | Suggested by human | Required by human}
**Relitigation:** {Open to discussion | Compelling reasons only | Blockers only}

{1-3 sentences: what's the context, what did we decide, and why.}
```

An ADR can be a single paragraph. The value is in recording *that* a decision was
made, *why*, and *how firmly it's held* — not in filling out sections.

- **Provenance** is **required** — it records who the decision came from and is the
  primary signal for how willing we are to override it later.
- **Relitigation** is **optional** — include the line only when the openness differs
  from the default implied by the provenance (see below). When absent, read the
  default.

## Provenance — required

Pick the one that honestly describes where the decision originated:

- **Suggested by agent** — the idea was proposed by the agent and then *explicitly
  approved* by a human. If the human has not clearly agreed, it is not yet an ADR —
  get confirmation first.
- **Suggested by human** — a human put the idea forward, in the original prompt or
  in later discussion. **This is the default; err toward it when unsure.**
- **Required by human** — a human stated a *hard* requirement they are clearly
  committed to (e.g. "we have to build this in PowerShell", "the results file must
  be Markdown"). Reserve this for unambiguous, committed constraints. If it's not
  clearly a hard requirement, use *Suggested by human*; if still unclear, **ask the
  human** before choosing this.

## Relitigation — optional

How willing we are to reopen the decision. Each provenance carries a **default**;
state a relitigation line *only* when the user signals something other than the
default.

| Provenance          | Default relitigation    |
|---------------------|-------------------------|
| Suggested by agent  | Open to discussion      |
| Suggested by human  | Compelling reasons only |
| Required by human   | Blockers only           |

Levels, from most to least open:

- **Completely open** — the decision carries no weight; we'd change course for any
  reason. If you find yourself reaching for this, **reconsider whether the ADR
  should exist at all** — if nobody cares to preserve the decision, it hasn't earned
  the weight of an ADR.
- **Open to discussion** — willing to relitigate if there's *a* reason. Revisit when
  it conflicts with current work. (Default for *Suggested by agent*.)
- **Compelling reasons only** — willing to relitigate only for *significant*
  benefit. Don't reopen on a whim; only raise it if the alternative's upside is
  large. (Default for *Suggested by human*.)
- **Blockers only** — generally unwilling to reopen unless there's no other
  reasonable option. Don't relitigate the "why" — the gaps/limits are usually
  deliberate and human-chosen even when an agent lacks the context to see why.
  (Default for *Required by human*.)

## Numbering

Scan `docs/adr/` for the highest existing number and increment by one, at the
moment you write the file. Because ADRs may be written inside isolated worktrees
running in parallel, two features can occasionally pick the same number; that
surfaces as an ordinary merge conflict and is resolved by renumbering one of them.
Don't pre-reserve numbers.

## When to offer an ADR

All three of these must be true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful.
2. **Surprising without context** — a future reader will look at the code and wonder
   "why on earth did they do it this way?".
3. **The result of a real trade-off** — there were genuine alternatives and one was
   picked for specific reasons.

If a decision is easy to reverse, skip it — you'll just reverse it. If it's not
surprising, nobody will wonder why. If there was no real alternative, there's
nothing to record beyond "we did the obvious thing."

### What qualifies

- **Architectural shape.** "We're using a monorepo." "The write model is
  event-sourced, the read model is projected into Postgres."
- **Integration patterns between contexts.** "Ordering and Billing communicate via
  domain events, not synchronous HTTP."
- **Technology choices that carry lock-in.** Database, message bus, auth provider,
  deployment target. Not every library — just the ones that would take a quarter to
  swap out.
- **Boundary and scope decisions.** "Customer data is owned by the Customer context;
  other contexts reference it by ID only." The explicit no-s are as valuable as the
  yes-s.
- **Deliberate deviations from the obvious path.** "We're using manual SQL instead of
  an ORM because X." Anything where a reasonable reader would assume the opposite.
  These stop the next engineer from "fixing" something that was deliberate.
- **Constraints not visible in the code.** "We can't use AWS because of compliance
  requirements." "Response times must be under 200ms because of the partner API
  contract."
- **Rejected alternatives when the rejection is non-obvious.** If you considered
  GraphQL and picked REST for subtle reasons, record it — otherwise someone will
  suggest GraphQL again in six months.

## Optional sections

Only include these when they add genuine value. Most ADRs won't need them.

- **Status** frontmatter (`proposed | accepted | deprecated | superseded by
  ADR-NNNN`) — useful when decisions are revisited.
- **Considered Options** — only when the rejected alternatives are worth remembering.
- **Consequences** — only when non-obvious downstream effects need to be called out.
