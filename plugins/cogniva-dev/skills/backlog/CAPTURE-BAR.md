# Capture bar

What earns a backlog entry, and how skill-initiated entries are proposed. Read
this before capturing anything on a skill's own initiative. A direct
`/cogniva-dev:backlog` invocation from the user only needs **Test 1 (coverage)**
— skip the rest and write.

Two tests, both answerable from what you already have in context. Neither test
asks the human anything, and neither one rejects an item for being vague, small,
or unimportant — refinement is never demanded at the moment of capture. If a
one-line item is all anyone can manage mid-task, that is a good item.

## Test 1 — coverage: is this already being handled right now?

Do NOT capture something that current in-flight work already covers. This is the
observed source of backlog churn: items written during planning and closed days
later during execution, having never been deferred at all.

An item is **covered** if it falls inside any of:

- **The plan being written this session** — its Goal, any task, or any sub-plan.
  (Applies to `plan-feature` above all: scope that the plan actually delivers is
  not deferred scope.)
- **An open plan folder** — a `docs/plans/<Module>/<Feature>/` whose `state.md`
  `Status:` is `planned`, `in-progress`, or `blocked`. The work is already
  queued; a backlog line just duplicates it.
- **The change currently in flight** — the fix `quick-fix` is making, or a task
  remaining in the `execute-feature` run that is proposing it.
- **An active exploration** — a `.explore/<slug>/` thread the user is still
  developing. Ideas raised during exploration belong to the exploration until
  the user decides what happens to it.
- **An existing open item** — an unticked line in any `BACKLOG.md` or a deferred
  stub that covers the same ground. Judge ground, not wording: "make the
  dropdown a treeview" and "the picker should be hierarchical" are one item.

Covered → do not capture. Say so in one line ("that's Task 3 of the plan" /
"already open in `FeatureLifecycle/BACKLOG.md`") and move on. Not covered → go
to Test 2.

## Test 2 — intent: is there a receipt?

Applies only to work you surfaced yourself. An out-of-scope idea becomes a
**candidate** only when you can point at something concrete. The agent's own
enthusiasm for its own idea is not evidence — this is the same rule the ADR
provenance table enforces, where "Suggested by agent" requires explicit human
approval or it is not an ADR.

A **receipt** is one of two kinds. Both are concrete; neither is a mood read:

- **Stated** — the user's own words. Quote them. "let's handle that soon but not
  today", "next one", "we'll want that once the API settles"; or substantive
  engagement — they asked how it would work, named a constraint on it, or tied
  it to something else landing.
- **Observed** — a fact you can name with a location. "Task 5 blocked needing
  `IExportPort`, which the plan never defines"; "the same off-by-one is at
  `handler.ts:88`"; "`groom-backlog` Step 4 closed two items whose remainder
  scope has no home".

How an out-of-scope moment ends decides what happens:

| Outcome | Looks like | Result |
|---|---|---|
| **Declined** | "no", "we're not doing that", "wrong approach" | Nothing, ever. Not a candidate, not a maybe. |
| **Deferred with intent** | a stated receipt, or an unambiguous observed fact | Candidate → **Table 1** |
| **Ambiguous** | engaged but did not clearly defer; a lukewarm "hm, maybe"; a passing observation with a weak receipt | Candidate → **Table 2** |
| **Raised and dropped** | you floated it and the user did not engage — no reply, changed the subject | Nothing. **Silence is not deferral.** |

Horizon is not the axis. A long-range item with a real receipt ("we definitely
want that eventually") is a candidate; a next-sprint item nobody responded to is
not. Timeframe was only ever a proxy for intent — use intent.

When you genuinely cannot tell whether a receipt is strong or weak, put it in
**Table 2**. Dropping a candidate at the gate costs one keystroke; suppressing a
real one is silent and unrecoverable.

## The candidate record

Hold each candidate as a record until the gate. Never write to a `BACKLOG.md`
before confirmation.

```
{ description, module, tier, size, src, receipt, strength }
```

- `description` — the one-line item text, as it would appear in `BACKLOG.md`.
- `module` — the owning Module, or `repo` for cross-cutting.
- `tier` — `loose` | `stub` (default `loose`; a stub is a folder plus two files,
  so reserve it for a cohesive future capability).
- `size` — `S` | `M` | `L`, when you can tell. Omit rather than guess.
- `src` — the `<Feature>` or fix this came out of.
- `receipt` — the quote (stated) or the located fact (observed), verbatim and
  short. This is what the user reads at the gate.
- `strength` — `clear` | `ambiguous`. Decides the table.

## The confirmation gate

Present ALL candidates in ONE pass, split into two tables. This mirrors
`groom-backlog`'s presentation contract (ADR 0013) — same shape, same ask, so a
user who has seen one has seen both.

- **Table 1 — clear intent.** Numbered. Item, and its receipt. The user should be
  able to scan and nod.
- **Table 2 — needs a decision.** Numbering continues from Table 1. Item, its
  receipt, and one line on why it is ambiguous (e.g. "you engaged with it but
  did not say when").

Then ask once, in these words or close to them:

> Capture Table 1 as-is? Table 2 by number (or none).

Only what the user confirms is written. Write each confirmed candidate per
`BACKLOG-FORMAT.md`, then report one line per item: tier, path, item text.

Rules for the gate:

- Deliver the tables as the FINAL text of the turn — a plain chat message with NO
  tool call after it, the question as plain text at its end. Text emitted before
  a tool call may not be shown to the user.
- An empty candidate set is a real and good outcome. Say nothing rather than
  presenting an empty table, and never soften a test to produce candidates.
- One table with no rows is simply omitted; do not print an empty heading.
- Never fold this gate into an unrelated question. It may share a turn with a
  caller's own end-of-run confirmation (see `plan-feature`), but it stays a
  distinct, separately-answerable section.
