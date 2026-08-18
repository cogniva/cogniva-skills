# Capture bar

What earns a backlog entry, what earns a ride-along, and how skill-initiated
entries are proposed. Read this before capturing anything on a skill's own
initiative. A direct `/cogniva-dev:backlog` invocation from the user only needs
**Test 1 (coverage)** — skip the rest and write.

Three tests, all answerable from what you already have in context. None of them
asks the human anything, and none rejects an item for being vague, small, or
unimportant — refinement is never demanded at the moment of capture. If a one-line
item is all anyone can manage mid-task, that is a good item.

- **Test 1 — coverage** decides whether there is an item at all.
- **Test 2 — intent** decides whether it is a **backlog candidate**, and how
  confidently.
- **Test 3 — ride-along** decides whether a clear-intent candidate should be done
  *now*, as part of the current work, instead of deferred.

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
**backlog candidate** only when you can point at something concrete. The agent's
own enthusiasm for its own idea is not evidence — this is the same rule the ADR
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
| **Deferred with intent** | a stated receipt, or an unambiguous observed fact | Candidate, `clear` — eligible for Test 3 |
| **Ambiguous** | engaged but did not clearly defer; a lukewarm "hm, maybe"; a passing observation with a weak receipt | Candidate, `ambiguous` — never a ride-along |
| **Raised and dropped** | you floated it and the user did not engage — no reply, changed the subject | Nothing. **Silence is not deferral.** |

Horizon is not the axis. A long-range item with a real receipt ("we definitely
want that eventually") is a candidate; a next-sprint item nobody responded to is
not. Timeframe was only ever a proxy for intent — use intent.

When you genuinely cannot tell whether a receipt is strong or weak, mark it
`ambiguous`. Dropping a candidate at the gate costs one keystroke; suppressing a
real one is silent and unrecoverable.

## Test 3 — ride-along: is doing it now cheaper than doing it later?

Applies ONLY to candidates that already passed Tests 1 and 2 at `clear` strength.
An `ambiguous` candidate is never a ride-along: if you cannot tell whether the user
wants the work at all, you certainly cannot argue for doing it this minute.

A **ride-along** is a backlog candidate promoted into the current work — done in
the same worktree, riding the same merge. It is a *promotion*, not a separate kind
of item: a ride-along the user declines falls through to the backlog like any other
candidate, so proposing one can never lose work.

All four criteria must hold.

**1. The context is already paid for — name the path.**
Not the same *files*; the same *understanding*. A ride-along may touch a file the
current work never changed, provided this work has already opened it. What it may
not do is reach for a file nobody has looked at, on the grounds that it is probably
similar.

Name the path. It must be one of:

- a path in **this run's diff**;
- a path in **the candidate's own receipt** — a receipt is already required to be a
  located fact, so the file that raised the candidate is named by definition;
- a path **you read while doing this work** — the design reads of a `plan-feature`
  session, where there is no diff yet.

"The surrounding code" and "files like the ones I changed" are not paths. If you
cannot name one, you are estimating rather than observing — send it to the backlog.

**2. Any open decision is small, and you can pose it right here.**
A ride-along may carry one or two unresolved decisions — and often the best ones
do. A candidate that raises a question is usually the one sitting closest to what
the user actually wanted and did not think to ask for; refusing those keeps only
the boring ones.

The bar is not "no decisions". It is that you can state each one as a concrete fork
**in the gate table itself**, with its options, so that approving the ride-along and
settling its decisions is a single exchange. If you would have to go and explore
before you could even pose the question, it is not a ride-along — you do not yet
know what you are proposing.

Two hard limits. At most **two** open decisions across the whole ride-along; a
third means you are designing, not riding along. And none of them ADR-worthy —
apply the adr skill's test (hard to reverse, surprising without context, the result of a
real trade-off). A decision that meets it earns a design conversation, not a line
at the end of a run when attention is at its lowest. Send it to the backlog and say
which criterion it tripped.

**3. It does not move the goal.**
The current work's Goal statement — or, for a planless fix, its one-line
description — still describes the result afterwards. Scope that changes what the
work *is* is a separate feature, however small it looks.

**4. There is a nameable saving.**
State in one clause what doing it later costs *extra*: "re-reads the same parser",
"a second pass over the same six skill files", "needs the worktree that is about to
be removed". "It is important" is not a saving — that is a backlog argument. If you
cannot name the saving, there isn't one.

Fails any → it stays a plain backlog candidate, presented in the ordinary tables.
No apology, and no mention of the near-miss.

### The aggregate check

Per-item bars cannot catch scope bloat, because bloat is a property of the set:
four items can each pass honestly and still triple the run. So one closing rule:

> **The ride-alongs together must be smaller than the work they ride on.** If they
> are not, you did not ride anything along — you built a second feature onto the end
> of the first one and called it a courtesy.

Cut the set until that is true and capture the rest. Relatedly: if more than about
three candidates pass Test 3 in one run, you are reading the bar too loosely —
re-apply criteria 3 and 4 before presenting.

### Depth-1: a ride-along carries no ride-alongs

- A run offers ride-alongs **exactly once**. Once the ride-along section has been
  presented, that run has no second offer, whatever happens next.
- Work admitted as a ride-along produces **backlog candidates only**. Anything it
  surfaces goes to the ordinary tables in the final report and can never itself be
  ridden along.

This is structural, not a matter of judgment: do not weigh whether "just one more"
is warranted, because the answer is no by construction. A genuine second round is a
fresh invocation (`/cogniva-dev:quick-fix`), not a ride-along.

### If a ride-along turns out bigger than you said

You misjudged the bar. Stop, revert that ride-along's commits, capture it to the
backlog with a one-line note on what you got wrong, and carry on with the rest of
the run. Do not design your way out of it mid-flight — the whole basis for skipping
a design conversation was that there was not one to have.

## The candidate record

Hold each candidate as a record until the gate. Never write to a `BACKLOG.md`
before confirmation, and never start ride-along work before confirmation.

```
{ description, module, tier, size, src, receipt, strength, rideAlong }
```

- `description` — the one-line item text, as it would appear in `BACKLOG.md`.
- `module` — the owning Module, or `repo` for cross-cutting.
- `tier` — `loose` | `stub` (default `loose`; a stub is a folder plus two files,
  so reserve it for a cohesive future capability).
- `size` — `S` | `M` | `L`, when you can tell. Omit rather than guess.
- `src` — the `<Feature>` or fix this came out of.
- `receipt` — the quote (stated) or the located fact (observed), verbatim and
  short. This is what the user reads at the gate.
- `strength` — `clear` | `ambiguous`. Decides the table, and gates Test 3.
- `rideAlong` — omitted, or `{ path, saving, questions[] }` when Test 3 passed:
  the path that satisfied criterion 1, the one-clause saving from criterion 4, and
  zero to two open decisions, each written as a concrete fork.

## The confirmation gate

Present ALL candidates in ONE pass, in three sections. This **extends** the
presentation contract of ADR 0013 / ADR 0019 rather than replacing it — the two
backlog tables are unchanged; ride-alongs sit above them.

The section headings are literal. Use these words:

```markdown
## Ride-alongs — do now, in this work

| # | Item | Receipt | Why now is cheaper | Open question |
|---|------|---------|--------------------|---------------|

## Backlog candidates

### Clear intent

| # | Item | Receipt |
|---|------|---------|

### Needs a decision

| # | Item | Receipt | Why ambiguous |
|---|------|---------|---------------|
```

- Numbering is continuous across all three tables — ride-alongs first, then clear
  intent, then needs-a-decision.
- `Why now is cheaper` is the one-clause saving from criterion 4. `Open question`
  holds the concrete fork(s) from criterion 2, or `—`.
- Omit any section with no rows. Never print an empty heading or an empty table.
- **Never head a table "Capture candidates".** The user-facing noun is **backlog
  candidate**; "capture" is the verb for what happens to one.

Then ask once, in these words or close to them:

> Ride along by number, or none — anything not ridden along is captured to the
> backlog instead. Answer any open question inline, or say "your call".
> Capture the clear-intent table as-is? Needs-a-decision by number (or none).

"Your call" is a real answer, not a deferral: pick, proceed, and state what you
picked in the report. A question in the table is an offer, never a toll.

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
- Only what the user confirms happens. Write each confirmed backlog candidate per
  `BACKLOG-FORMAT.md`, then report one line per item: tier, path, item text. Report
  each ride-along as one line too: what changed, and its commit.
