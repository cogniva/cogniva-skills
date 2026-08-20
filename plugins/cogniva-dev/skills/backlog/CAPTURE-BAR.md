# Capture bar

How work surfaced mid-run is routed, what earns a backlog entry, and how
skill-initiated proposals are presented. Read this before capturing anything on
a skill's own initiative. A direct `/cogniva-dev:backlog` invocation from the
user only needs **Test 1 (coverage)** — skip the rest and write (a `because:`
reason is encouraged, never demanded).

The governing principle (ADR: a backlog item is a planned deferral): a backlog
entry exists only with a stated reason not to do the work now. Reason-less real
work is routed — done now, or handed to the user as a ready-to-fire plan
invocation — and vague-and-unimportant observations are dropped. The backlog is
never the default sink.

Order of application:

- **Test 0 — introduced defect** is not routing at all: broken current work is
  unfinished work.
- **Test 1 — coverage** decides whether there is an item at all.
- **Test 2 — intent** decides whether it is worth the user's attention, and how
  confidently.
- **Test 3 — route** decides what is proposed: Do now / Plan next / Defer.

None of these tests asks the human anything mid-task, and none demands
refinement at the moment of capture — a one-line item from someone mid-task is
a good item. Importance is an axis; size never is.

## Test 0 — introduced defect: did this run break it?

A defect introduced by the current run's own work is NOT a candidate for any
route — it is unfinished work (ADR: introduced defects are unfinished work).
Fix it before the run completes, in the same workspace, no gate. Two
exceptions, both raised IMMEDIATELY — stop and tell the user, not a row at the
end-of-run gate:

- the fix would change what the feature is, or its design;
- the fix is big enough to warrant its own plan — propose the
  `/cogniva-dev:plan-feature` invocation for it.

An introduced defect is never backlogged and never silently dropped.

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

## Test 2 — intent: is there a receipt, and does it matter?

Applies only to work you surfaced yourself. An out-of-scope idea earns the
user's attention only when you can point at something concrete. The agent's
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
| **Deferred with intent** | a stated receipt, or an unambiguous observed fact | Candidate, `clear` — route it in Test 3 |
| **Ambiguous** | engaged but did not clearly defer; a lukewarm "hm, maybe"; a passing observation with a weak receipt | Candidate, `ambiguous` — presented under Needs a decision; never Do now |
| **Raised and dropped** | you floated it and the user did not engage — no reply, changed the subject | Nothing. **Silence is not deferral.** |
| **Vague AND unimportant** | a passing thought with no receipt and nothing broken; "would be nice"; polish nobody asked for | Dropped — one throwaway line in the report ("noticed X — dropped; say the word to keep it"), no table row, no backlog. (ADR: vague-and-unimportant is dropped, amending ADR 0017.) |

Importance, not size: a small item that matters — a real bug, a wrong doc, a
broken command — is never "unimportant". When you genuinely cannot tell whether
it matters, it is `ambiguous`, not dropped: a Needs-a-decision row costs the
user one keystroke; a silent suppression is unrecoverable.

Horizon is not the axis either. A long-range item with a real receipt ("we
definitely want that eventually") is a candidate; a next-sprint item nobody
responded to is not. Timeframe was only ever a proxy for intent — use intent.

## Test 3 — route: what happens to it?

Every candidate that survives Tests 1–2 at `clear` strength is proposed with
exactly one route. An `ambiguous` candidate takes no route from you: it goes to
**Needs a decision** and the user picks.

### Do now — the assumed preference

Do now means done as part of the current work — same workspace, same landing.
(The glossary calls this a ride-along; the gate says "Do now".) It is a
promotion of a candidate, never a separate species (ADR 0020): one the user
declines is re-routed at the gate, so proposing it can never lose work. Propose
it when ALL of these hold:

1. **The context is in hand — name the path.** One of: a path in this run's
   diff; the path in the candidate's own receipt; a path you read while doing
   this work (the design reads of a `plan-feature` session, where there is no
   diff yet). "The surrounding code" and "files like the ones I changed" are
   not paths — if you cannot name one, route Plan next.
2. **Any open decision is small and posable in the gate row** — at most two
   across the item, none ADR-worthy (hard to reverse / surprising without
   context / a real trade-off ⇒ a design conversation, not a gate row).
3. **It does not change what the current work is.** The Goal statement — or,
   for a planless fix, its one-line description — still describes the result
   afterwards.
4. **It is not plan-sized.** Work big enough to earn its own plan goes to Plan
   next, however in-hand it is.

Tie-breaker: when a reason-less `clear` candidate could honestly go either way
between Do now and Plan next, propose **Do now** — the observed failure mode is
deferring current-session work, not bloated runs.

Anti-bloat guards:

> **The Do-now set together must be smaller than the work it rides on.** If it
> is not, you did not ride anything along — you built a second feature onto the
> end of the first one. Cut the set until that is true and route the rest.

More than about three Do-now proposals in one run means the bar is being read
too loosely — re-apply criteria 3 and 4 before presenting.

**Depth-1:** a run offers Do now exactly once — once the gate has been
presented, that run has no second offer, whatever happens next. Work admitted
as a Do now can itself only produce Plan-next / Defer / drop outcomes, never
another Do now. This is structural, not a matter of judgment. A genuine second
round is a fresh `/cogniva-dev:quick-fix`.

**If a Do now turns out bigger than you said:** you misjudged the bar. Stop,
revert its changes, route it Plan next with a one-line note on what you got
wrong, and carry on with the rest of the run. Do not design your way out of it
mid-flight.

### Plan next — a ready-to-fire invocation

For real, wanted work that is not in hand or is plan-sized. Propose the EXACT
invocation the user can fire — `/cogniva-dev:quick-fix "<one-line
description>"` or `/cogniva-dev:plan-feature <Module>/<Feature>` — with a
one-line rationale. Never auto-run it and never write anything for it: the
proposal in the gate is the artifact.

### Defer — only with a reason

The ONLY route that writes to a `BACKLOG.md` (or creates a stub). It requires a
deferral reason (`because:`): blocked-on-X, sequenced-after-Y, decision
pending, or the user's explicit "later". No reason → this route is not
available; go back to Do now / Plan next, or drop.

## The candidate record

Hold each candidate as a record until the gate. Never write to a `BACKLOG.md`
before confirmation, and never start Do-now work before confirmation.

```
{ description, module, tier, size, src, receipt, strength, route,
  doNow?, invocation?, because? }
```

- `description` — the one-line item text, as it would appear in `BACKLOG.md`.
- `module` — the owning Module, or `repo` for cross-cutting.
- `tier` — `loose` | `stub` (default `loose`; a stub is a folder plus two files,
  so reserve it for a cohesive future capability).
- `size` — `S` | `M` | `L`, when you can tell. Omit rather than guess.
- `src` — the `<Feature>` or fix this came out of.
- `receipt` — the quote (stated) or the located fact (observed), verbatim and
  short. This is what the user reads at the gate.
- `strength` — `clear` | `ambiguous`. `ambiguous` ⇒ no route; Needs a decision.
- `route` — `do-now` | `plan-next` | `defer`, for `clear` candidates.
- `doNow` — when route is `do-now`: `{ path, questions[] }` — the in-hand path
  from criterion 1 and zero to two open decisions, each a concrete fork.
- `invocation` — when route is `plan-next`: the exact command line to propose.
- `because` — when route is `defer`: the deferral reason, as it will appear in
  the item's `because:` tag.

## The confirmation gate

Present ALL candidates in ONE pass, route-first (ADR: the confirmation gate is
route-first — it supersedes the two-table contract of ADR 0019; receipts,
confidence separation, and the single gate carry forward). The section headings
are literal. Use these words:

```markdown
## Do now — in this work

| # | Item | Receipt | Path in hand | Open question |
|---|------|---------|--------------|---------------|

## Plan next — fire when ready

| # | Item | Receipt | Proposed invocation |
|---|------|---------|---------------------|

## Backlog — planned deferrals

| # | Item | Receipt | Deferred because |
|---|------|---------|------------------|

## Needs a decision

| # | Item | Receipt | Why unclear |
|---|------|---------|-------------|
```

- Numbering is continuous across all four tables, in the order above.
- `Open question` holds the concrete fork(s) from criterion 2, or `—`.
- Below the tables, one throwaway line for anything Test 2 dropped:
  "Noticed and dropped: <x>; <y> — say the word to keep any." Omit the line
  when nothing was dropped.
- Omit any section with no rows. Never print an empty heading or an empty
  table. **Never head a table "Capture candidates"** — the user-facing noun is
  **backlog candidate**.

Then ask once, in these words or close to them:

> Do now by number, or none — anything declined moves to Plan next or the
> backlog as you direct. Plan-next invocations are yours to fire — nothing
> auto-runs. Capture the Backlog table as-is? Route each Needs-a-decision item
> by number (do now / plan next / defer because:<reason> / drop), or say "your
> call".

"Your call" is a real answer, not a deferral: pick, proceed, and state what you
picked in the report. A question in the table is an offer, never a toll.

Rules for the gate:

- Deliver the tables as the FINAL text of the turn — a plain chat message with
  NO tool call after it, the question as plain text at its end. Text emitted
  before a tool call may not be shown to the user.
- An empty candidate set is a real and good outcome. Say nothing rather than
  presenting an empty table, and never soften a test to produce candidates.
- Never fold this gate into an unrelated question. It may share a turn with a
  caller's own end-of-run confirmation (see `plan-feature`), but it stays a
  distinct, separately-answerable section.
- Only what the user confirms happens. Confirmed Do nows are done by the
  CALLING skill in its own workspace; confirmed deferrals are written per
  `BACKLOG-FORMAT.md`, each with its `because:` tag; Plan-next items are left
  as proposals for the user to fire. Report one line per item: the route, the
  path (for anything written), the item text, and each Do now's commit.
