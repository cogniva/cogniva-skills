# RideAlongCandidates — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/RideAlongCandidates
> Tasks contain NO git worktree/branch step — execute-feature creates the worktree
> and the tasks commit on the feature branch they are already on. Never run
> git switch/checkout/branch inside a task.

**Goal:** Add a third tier to skill-initiated capture — the **ride-along**, work
done as part of the current run instead of deferred — rename the user-facing noun
from "capture candidate" to "backlog candidate", and reorder the execution skills
so the green gate is the last step before integration.

**Architecture:** `CAPTURE-BAR.md` gains **Test 3**, applied only to candidates that
already passed Tests 1 and 2 at `clear` strength; passing candidates get a
`rideAlong` field and are presented in a new section *above* the two existing
backlog tables, so ADR 0019's contract is extended, not replaced. A declined
ride-along falls through to the backlog, so the tier can never drop work. The
execution skills (`execute-feature`, `quick-fix`) move their ride-along gate,
`before-integrate` block and ADR check to *before* the green gate, so every change
that rides the merge is verified by it. Depth-1 is structural: work admitted as a
ride-along returns backlog candidates only.

**Read these first:**
- `plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md` — the file Task 1 rewrites
- `docs/adr/0019-capture-candidates-two-tables.md` — the two-table contract this extends
- `docs/adr/0017-backlog-capture-coverage-and-intent.md` — Tests 1 and 2
- `docs/adr/0013-backlog-grooming-propose-with-receipts.md` — the presentation contract
- `plugins/cogniva-dev/skills/auto-doc/ADR-FORMAT.md` — the ADR-worthiness test Test 3 cites
- `docs/strategy.md` lines 50-68 — the phase vocabulary Task 4 updates

## File structure (locked)

```
plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md        MODIFY — full rewrite: Test 3, depth-1, three-section gate, renamed noun
plugins/cogniva-dev/skills/backlog/SKILL.md              MODIFY — three tests, three-section gate, ride-along rules
plugins/cogniva-dev/skills/explore-idea/SKILL.md         MODIFY — noun rename only (one line)
plugins/cogniva-dev/skills/easy-work-scan/SKILL.md       MODIFY — noun rename + three sections (one paragraph)
plugins/cogniva-dev/skills/plan-feature/SKILL.md         MODIFY — ride-alongs at handoff = amend the plan; design-session form of criterion 1
plugins/cogniva-dev/skills/execute-feature/SKILL.md      MODIFY — Step 3 reorder; ride-along gate; gate-failure policy; renamed heading
plugins/cogniva-dev/skills/quick-fix/SKILL.md            MODIFY — same reorder + ride-along gate
plugins/cogniva-dev/templates/execute-feature.workflow.js MODIFY — omit tick/state prompt lines when planPath/statePath absent
docs/glossary/README.md                                  MODIFY — new "Ride-along" entry
docs/strategy.md                                         MODIFY — before-integrate's new position in the phase list
docs/adr/NNNN-ride-along-promotes-a-backlog-candidate.md CREATE — ADR-C1 (Task 1)
docs/adr/NNNN-ride-along-tier-is-depth-1.md              CREATE — ADR-C2 (Task 1)
docs/adr/NNNN-ride-along-gate-on-the-open-worktree.md    CREATE — ADR-C3 (Task 4)
docs/adr/NNNN-failing-ride-along-is-reverted.md          CREATE — ADR-C4 (Task 4)
docs/adr/NNNN-green-gate-is-last-before-integration.md   CREATE — ADR-C5 (Task 4)
```

## Candidate ADRs

### ADR-C1: A ride-along is a promotion of a backlog candidate, never a separate species
**Provenance:** Suggested by agent
A candidate must pass coverage (Test 1) and intent (Test 2) at `clear` strength before Test 3 asks whether doing it now is cheaper than doing it later, and a ride-along the user declines falls through to the backlog rather than being lost — so the tier can never drop work. Test 3's bar is locality, not importance: context already paid for (a named path), unchanged goal, a nameable saving, and at most two open decisions that can each be posed as a concrete fork in the gate table itself. Carrying a small question is deliberate, since those candidates are usually the ones closest to what the user wanted and did not think to ask for, but an ADR-worthy decision is disqualifying — it deserves a design conversation, not a line at the end of a run.
**Write with:** Task 1

### ADR-C2: The ride-along tier is depth-1 and non-recursive
**Provenance:** Suggested by agent
A run offers ride-alongs exactly once, and work admitted as a ride-along returns backlog candidates only — it never carries ride-alongs of its own. This terminates the "just one more thing" chain structurally rather than by a tunable cap or by judgment exercised at the moment of temptation; a genuine second round is a fresh invocation, not a ride-along.
**Write with:** Task 1

### ADR-C3: The ride-along gate fires on the open worktree, and only when a candidate exists
**Provenance:** Suggested by agent
Confirmed ride-along work is done and committed in the same worktree that just ran the tasks, so it rides the same merge — no second integration, no re-established context. Execution skills pause for the gate only when at least one candidate passes Test 3; a run with none stays fire-and-forget and reports its backlog candidates after integration exactly as before.
**Write with:** Task 4

### ADR-C4: A failing ride-along is repaired once, then reverted — it never blocks the work
**Provenance:** Suggested by agent
If the green gate is red after ride-along commits, the console makes one repair attempt; still red, it reverts every ride-along commit, re-runs the gate, and captures the items to the backlog instead. Reverting all of them and re-gating is also how attribution is decided — green after the revert means the ride-alongs were the cause, still red means an ordinary pre-existing failure. Optional work approved in passing must never hold finished work hostage.
**Write with:** Task 4

### ADR-C5: The green gate is the last step before integration; everything that rides the merge is finished first
**Provenance:** Suggested by human
Ride-along work, the repo's `before-integrate` obligations, and the ADR check all run *before* the green gate, so every change that will ride the merge is verified by it. The previous order gated the plan's tasks and then admitted un-gated edits after the gate had gone green — a repo obligation writing code, or an ADR renumber rewriting a code reference — which made "it passed" a claim about a tree that no longer existed. The `before-integrate` phase keeps its name: its contract was always "on the worktree, so it rides the merge", not "immediately adjacent to the merge command".
**Write with:** Task 4

---

## Task 1: Rewrite CAPTURE-BAR.md with Test 3, depth-1 and the three-section gate

**Files:**
- Modify: `plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md`
- Create: `docs/adr/NNNN-ride-along-promotes-a-backlog-candidate.md` (number resolved in Step 3)
- Create: `docs/adr/NNNN-ride-along-tier-is-depth-1.md` (number resolved in Step 3)

- [x] **Step 1 (rewrite the file):** Replace the ENTIRE contents of
      `plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md` with exactly this:

````markdown
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
apply auto-doc's test (hard to reverse, surprising without context, the result of a
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
````

- [x] **Step 2 (verify the rewrite):** run each and confirm the stated result:
      - `grep -c "^## Test 3 — ride-along" plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md` → `1`
      - `grep -c "^## Ride-alongs — do now, in this work" plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md` → `1`
      - `grep -c "Never head a table \"Capture candidates\"" plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md` → `1`
      - `grep -c "rideAlong" plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md` → `2`
      - `grep -n "^## Test 1 — coverage\|^## Test 2 — intent" plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md` → two lines, both present

- [x] **Step 3 (write ADRs C1 and C2):** scan `docs/adr/` for the highest existing
      number and increment for each file, per auto-doc's `ADR-FORMAT.md`. Write
      `docs/adr/NNNN-ride-along-promotes-a-backlog-candidate.md`:

```markdown
# A ride-along is a promotion of a backlog candidate, never a separate species

**Provenance:** Suggested by agent

A candidate must pass coverage (Test 1) and intent (Test 2) at `clear` strength before Test 3 asks whether doing it now is cheaper than doing it later, and a ride-along the user declines falls through to the backlog rather than being lost — so the tier can never drop work. Test 3's bar is locality, not importance: context already paid for (a named path), unchanged goal, a nameable saving, and at most two open decisions that can each be posed as a concrete fork in the gate table itself. Carrying a small question is deliberate, since those candidates are usually the ones closest to what the user wanted and did not think to ask for, but an ADR-worthy decision is disqualifying — it deserves a design conversation, not a line at the end of a run.
```

      Then, with the NEXT number, write `docs/adr/NNNN-ride-along-tier-is-depth-1.md`:

```markdown
# The ride-along tier is depth-1 and non-recursive

**Provenance:** Suggested by agent

A run offers ride-alongs exactly once, and work admitted as a ride-along returns backlog candidates only — it never carries ride-alongs of its own. This terminates the "just one more thing" chain structurally rather than by a tunable cap or by judgment exercised at the moment of temptation; a genuine second round is a fresh invocation, not a ride-along.
```

      Neither heading may contain `ADR-C1` or `ADR-C2` — the candidate labels belong
      to this plan, not to the shipped file.

- [x] **Step 4 (commit):** `git add plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md docs/adr/`
      then `git commit -m "feat(backlog): add the ride-along tier to the capture bar"`

---

## Task 2: Wire the ride-along tier through the backlog skill, the glossary, and the rename sweep

**Files:**
- Modify: `plugins/cogniva-dev/skills/backlog/SKILL.md`
- Modify: `docs/glossary/README.md`
- Modify: `plugins/cogniva-dev/skills/easy-work-scan/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/explore-idea/SKILL.md`

- [x] **Step 1 (backlog SKILL.md — skill-initiated mode):** in
      `plugins/cogniva-dev/skills/backlog/SKILL.md`, replace exactly:

```
**Skill-initiated** — you surfaced the work yourself while doing something else.
**Propose; do not write.** Read `CAPTURE-BAR.md` (lazy-loaded — do not read it
for a direct invocation of an already-covered item), qualify each candidate
against both tests, hold them as candidate records, and present them in the
two-table gate. Only what the user confirms is written.
```

      with:

```
**Skill-initiated** — you surfaced the work yourself while doing something else.
**Propose; do not write.** Read `CAPTURE-BAR.md` (lazy-loaded — do not read it
for a direct invocation of an already-covered item), qualify each candidate
against all three tests, hold them as candidate records, and present them in the
three-section gate. Only what the user confirms is written or done.
```

- [x] **Step 2 (backlog SKILL.md — Step 2 of its Steps list):** replace exactly:

```
2. **Skill-initiated only — qualify intent.** Apply Test 2 in `CAPTURE-BAR.md`.
   Declined or raised-and-dropped → nothing. Otherwise build a candidate record
   with its receipt and a `clear` / `ambiguous` strength, and hold it for the gate.
   Do not touch any file yet.
```

      with:

```
2. **Skill-initiated only — qualify intent, then test for a ride-along.** Apply
   Test 2 in `CAPTURE-BAR.md`. Declined or raised-and-dropped → nothing. Otherwise
   build a candidate record with its receipt and a `clear` / `ambiguous` strength.
   Then apply Test 3 to every `clear` candidate: is doing it now, as part of the
   current work, cheaper than doing it later? Passing candidates get a `rideAlong`
   field; the rest stay plain backlog candidates. Hold them all for the gate and do
   not touch any file yet. This skill never *performs* a ride-along — the calling
   skill does that work in its own worktree — and never offers one from inside work
   that was itself a ride-along (depth-1).
```

- [x] **Step 3 (backlog SKILL.md — Step 5, the gate):** replace exactly:

```
5. **Skill-initiated only — the gate.** Present every candidate in ONE pass, in
   the two tables defined in `CAPTURE-BAR.md` (clear intent / needs a decision),
   each row showing its receipt, then ask once: capture Table 1 as-is, Table 2 by
   number. Deliver it as the final text of the turn with no tool call after it.
   Nothing is written before the reply. An empty candidate set → say nothing.
```

      with:

```
5. **Skill-initiated only — the gate.** Present every candidate in ONE pass, in
   the three sections defined in `CAPTURE-BAR.md` — `## Ride-alongs — do now, in
   this work`, then `## Backlog candidates` with its `### Clear intent` and
   `### Needs a decision` tables — each row showing its receipt, then ask once in
   `CAPTURE-BAR.md`'s words. Never head a table "Capture candidates": the
   user-facing noun is **backlog candidate**. Deliver it as the final text of the
   turn with no tool call after it. Nothing is written or done before the reply. An
   empty candidate set → say nothing.
```

- [x] **Step 4 (backlog SKILL.md — called-by-another-skill routing):** replace exactly:

```
- **Interactive caller** (`plan-feature`, `groom-backlog`, `easy-work-scan`) —
  the caller batches candidates into its own end-of-run confirmation pass and
  presents the two tables there. One interruption, not two.
- **Non-interactive caller** (an `execute-feature` or `quick-fix` task agent
  inside a background Workflow) — there is nobody to ask. The agent returns
  candidates in its task result's `followups` array and writes nothing; the
  invoking console runs the gate in its end-of-run report.
```

      with:

```
- **Interactive caller** (`plan-feature`, `groom-backlog`, `easy-work-scan`) —
  the caller batches candidates into its own end-of-run confirmation pass and
  presents the three sections there. One interruption, not two.
- **Non-interactive caller** (an `execute-feature` or `quick-fix` task agent
  inside a background Workflow) — there is nobody to ask. The agent returns
  candidates in its task result's `followups` array and writes nothing; the
  invoking console applies Test 3 and runs the gate while its worktree is still
  open. A task agent never proposes a ride-along itself: it cannot know what the
  console will do next, and its receipt already names the path criterion 1 needs.
```

- [x] **Step 5 (backlog SKILL.md — Rules):** replace exactly:

```
- Nothing a skill decided on its own reaches a `BACKLOG.md` unconfirmed. A direct
  human invocation is already confirmed and needs no gate.
```

      with:

```
- Nothing a skill decided on its own reaches a `BACKLOG.md` unconfirmed. A direct
  human invocation is already confirmed and needs no gate.
- A ride-along is a promotion of a backlog candidate, never a separate species: one
  the user declines falls through to the backlog untouched. This skill proposes
  ride-alongs; the calling skill does the work.
```

- [x] **Step 6 (glossary entry):** in `docs/glossary/README.md`, replace exactly:

```
## Status

The lifecycle stage of a feature, recorded as the `Status:` line in its `state.md`:
```

      with:

```
## Ride-along

Work surfaced during planning or execution that is done as part of the current work rather than deferred to the [Backlog](#backlog): a backlog candidate promoted at the confirmation gate because doing it now is cheaper than doing it later — the context is already paid for, the goal is unchanged, and any open decision is small enough to pose in the gate table. Named for the merge it rides. Offered once per run and never recursive: a ride-along carries no ride-alongs of its own.
_Avoid_: fold-in, tag-along, scope creep

## Status

The lifecycle stage of a feature, recorded as the `Status:` line in its `state.md`:
```

      NOTE: the replacement re-emits the two `## Status` lines verbatim — do not
      delete the Status entry.

- [x] **Step 7 (easy-work-scan rename):** in
      `plugins/cogniva-dev/skills/easy-work-scan/SKILL.md`, replace exactly:

```
   is a capture CANDIDATE, not a write: drop what is already covered by an open
   item or a dispatched fix, then present the rest in the two tables from
   `CAPTURE-BAR.md` (in the `backlog` skill's directory) and write only what the
   user confirms, via `/cogniva-dev:backlog`. Nothing surviving → say nothing.
```

      with:

```
   is a backlog CANDIDATE, not a write: drop what is already covered by an open
   item or a dispatched fix, then present the rest in the sections from
   `CAPTURE-BAR.md` (in the `backlog` skill's directory) and write only what the
   user confirms, via `/cogniva-dev:backlog`. Nothing surviving → say nothing.
   This scan never rides anything along — it dispatches through `quick-fix` /
   `plan-feature`, and those runs own their own ride-along gates.
```

- [x] **Step 8 (explore-idea rename):** in
      `plugins/cogniva-dev/skills/explore-idea/SKILL.md`, replace exactly (this is a
      TWO-line match — both lines, as one replacement):

```
  `CAPTURE-BAR.md`), and an idea you floated that the user did not engage with is
  not deferred work — it is just a thing you said.
```

      with:

```
  `CAPTURE-BAR.md`), and an idea you floated that the user did not engage with is
  not deferred work — it is just a thing you said. Exploration has no ride-along
  tier either: an idea worth acting on simply becomes part of the exploration.
```

      DO NOT touch line 76 (`No plan. No code. No commits. No ADRs, no glossary
      writes - capture candidates in the doc only.`) — "capture" there is a verb
      about ADR/glossary candidates in the thinking doc, not the backlog noun.

- [x] **Step 9 (verify):** run each and confirm:
      - `grep -c "three-section gate" plugins/cogniva-dev/skills/backlog/SKILL.md` → `1`
      - `grep -c "rideAlong" plugins/cogniva-dev/skills/backlog/SKILL.md` → `1`
      - `grep -c "^## Ride-along$" docs/glossary/README.md` → `1`
      - `grep -c "^## Status$" docs/glossary/README.md` → `1`
      - `grep -c "capture CANDIDATE" plugins/cogniva-dev/skills/easy-work-scan/SKILL.md` → `0`
      - `grep -c "it is just a thing you said" plugins/cogniva-dev/skills/explore-idea/SKILL.md` → `1`

- [x] **Step 10 (commit):** `git add plugins/cogniva-dev/skills/backlog/SKILL.md docs/glossary/README.md plugins/cogniva-dev/skills/easy-work-scan/SKILL.md plugins/cogniva-dev/skills/explore-idea/SKILL.md`
      then `git commit -m "feat(backlog): wire ride-alongs through the backlog skill and glossary"`

---

## Task 3: Give plan-feature a ride-along section at handoff

**Files:**
- Modify: `plugins/cogniva-dev/skills/plan-feature/SKILL.md`

- [x] **Step 1 (the handoff pass):** in
      `plugins/cogniva-dev/skills/plan-feature/SKILL.md`, replace exactly:

```
**Capture candidates go in the same pass**, as a distinct, separately-answerable
section below the ADRs — one interruption, not two. Present them in the two tables
defined in `CAPTURE-BAR.md`:

- **Table 1 — clear intent:** numbered; the item and its receipt. Scan and nod.
- **Table 2 — needs a decision:** numbering continues; the item, its receipt, and
  one line on why it is ambiguous.

Then ask once: capture Table 1 as-is? Table 2 by number (or none). Write only
confirmed candidates, via `/cogniva-dev:backlog`, onto the worktree so they ride
the plan commit. If there are no capture candidates, omit the section entirely —
do not print an empty table. Deliver the whole handoff pass (ADRs plus tables) as
the final text of the turn, with no tool call after it.
```

      with:

```
**Backlog candidates and ride-alongs go in the same pass**, as distinct,
separately-answerable sections below the ADRs — one interruption, not three.
Present them in the three sections defined in `CAPTURE-BAR.md`: `## Ride-alongs —
do now, in this work`, then `## Backlog candidates` with its `### Clear intent` and
`### Needs a decision` tables. Never head a table "Capture candidates" — the
user-facing noun is **backlog candidate**.

**Riding along, in a design session, means amending the plan** — adding a step to
an existing task, or one more task — before the plan is committed. The executor
then does it as part of the feature. Two consequences specific to planning:

- Criterion 1 of Test 3 ("the context is already paid for") is satisfied here by a
  file you READ during this design session, since there is no diff yet. Name the
  path; "the surrounding code" is not a path.
- If a confirmed ride-along does not fit any task cleanly, say so and capture it to
  the backlog instead. Do not bend the plan's shape around it — that is criterion 3
  (it does not move the goal) failing late.

After amending the plan, do NOT re-run this pass. The amendment is not a new design
round, and ride-alongs are depth-1 (ADR: the ride-along tier is depth-1 and
non-recursive).

Write only confirmed backlog candidates, via `/cogniva-dev:backlog`, onto the
worktree so they ride the plan commit. Omit any section with no rows — do not print
an empty table. Deliver the whole handoff pass (ADRs plus the sections) as the final
text of the turn, with no tool call after it.
```

- [x] **Step 2 (the capture-deferrals section):** replace exactly:

```
A focused design always cuts scope — but most cut scope is not backlog material.
Do NOT write anything to a `BACKLOG.md` from this session. Hold cut items as
**capture candidates** and confirm them at handoff, in the same pass as the
candidate ADRs (below).
```

      with:

```
A focused design always cuts scope — but most cut scope is not backlog material.
Do NOT write anything to a `BACKLOG.md` from this session. Hold cut items as
**backlog candidates** and confirm them at handoff, in the same pass as the
candidate ADRs (below). A `clear` candidate may also qualify as a **ride-along** —
folded into the plan you are writing rather than deferred; Test 3 in
`CAPTURE-BAR.md` decides, and the handoff pass is where it is offered.
```

- [x] **Step 3 (the heading):** replace exactly:

```
## Confirm candidate ADRs and capture candidates (once, at handoff)
```

      with:

```
## Confirm candidate ADRs, ride-alongs and backlog candidates (once, at handoff)
```

- [x] **Step 4 (the deferrals heading):** replace exactly:

```
## Capture deferrals (propose, don't write)
```

      with:

```
## Deferred scope (propose, don't write)
```

- [x] **Step 5 (verify):** run each and confirm:
      - `grep -c "Capture candidates" plugins/cogniva-dev/skills/plan-feature/SKILL.md` → `1`
        (the single remaining hit is the "Never head a table" instruction)
      - `grep -c "Riding along, in a design session, means amending the plan" plugins/cogniva-dev/skills/plan-feature/SKILL.md` → `1`
      - `grep -c "^## Deferred scope (propose, don't write)$" plugins/cogniva-dev/skills/plan-feature/SKILL.md` → `1`

- [x] **Step 6 (commit):** `git add plugins/cogniva-dev/skills/plan-feature/SKILL.md`
      then `git commit -m "feat(plan-feature): offer ride-alongs at the handoff pass"`

---

## Task 4: Reorder execute-feature so the green gate is last, and add its ride-along gate

**Files:**
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`
- Modify: `docs/strategy.md`
- Create: `docs/adr/NNNN-ride-along-gate-on-the-open-worktree.md` (number resolved in Step 5)
- Create: `docs/adr/NNNN-failing-ride-along-is-reverted.md` (number resolved in Step 5)
- Create: `docs/adr/NNNN-green-gate-is-last-before-integration.md` (number resolved in Step 5)

- [x] **Step 1 (insert the ride-along gate and the new order):** in
      `plugins/cogniva-dev/skills/execute-feature/SKILL.md`, replace exactly:

```
- **All tasks done — GREEN GATE (mandatory, no shortcuts):**
  1. **Commit everything first.** `git -C "<worktree>" status --porcelain` MUST be
     empty before the gate runs. The per-task agents commit their own files, but tick
     edits / state.md / stray files can linger — stage and commit them on the feature
     branch now. NEVER run the gate against a dirty tree: a green gate over
     uncommitted changes is a lie (those changes do NOT ride into the merge, so the
     target can break even though "it passed"). This holds even when the gate runs no
     commands. Verify clean, THEN gate.
```

      with (NOTE: the replacement text below is fenced with FOUR backticks because it
      contains a three-backtick block; write the inner block with three):

````
- **All tasks done.** Run these IN ORDER. The green gate is LAST, immediately
  before integration, because everything that rides the merge must be verified by
  it — ride-along work, the repo's `before-integrate` obligations, and any ADR
  renumbering all land BEFORE the gate, never after it:

  ```
  tasks done → tree clean → ride-along gate → before-integrate → ADR check → GREEN GATE → integrate
  ```

  1. **Commit everything first.** `git -C "<worktree>" status --porcelain` MUST be
     empty before you go further. The per-task agents commit their own files, but tick
     edits / state.md / stray files can linger — stage and commit them on the feature
     branch now. NEVER run the gate against a dirty tree: a green gate over
     uncommitted changes is a lie (those changes do NOT ride into the merge, so the
     target can break even though "it passed"). This holds even when the gate runs no
     commands.

  1a. **Ride-along gate (only when a candidate exists).** Read `CAPTURE-BAR.md` in
     the `backlog` skill's directory and apply Test 3 to every `clear` candidate in
     the workflow's `followups`. If NONE passes, skip straight to 1b — the run stays
     fire-and-forget and its backlog candidates are gated after integration, as
     always. If at least one passes, STOP here and present the full three-section
     gate (ride-alongs, then the two backlog tables) as the final text of the turn.
     One interruption, and it happens now rather than after the merge precisely
     because the worktree is still open.

     For each ride-along the user confirms: make the change IN THE WORKTREE, on the
     feature branch, and commit it on its own —
     `git -C "<worktree>" commit -m "feat(<scope>): <what the ride-along did>"`.
     Answer any open question they punted with "your call" by picking, proceeding,
     and saying what you picked. Anything not ridden along is captured to the
     backlog via `/cogniva-dev:backlog`, on the worktree, exactly as a plain
     candidate would be.

     Ride-alongs are **depth-1**: this offer happens once per run. Work you just
     admitted as a ride-along never gets a ride-along gate of its own — anything it
     surfaces goes into the backlog tables of your final report. Do not weigh
     whether "just one more" is warranted; the answer is no by construction.

  1b. **Repo obligations (`before-integrate`).** Check the target repo's CLAUDE.md
     `## Cogniva-dev workflow instructions` for a `### before-integrate` block and
     honour it on the worktree now, committing anything it produces on the feature
     branch. Absent → nothing to do. This runs BEFORE the gate so an obligation that
     writes code is verified like any other change.
````

- [x] **Step 2 (renumber the ADR check ahead of the gate):** replace exactly:

```
  4. **ADR check (mandatory, after the gate, before Step 4).** Task agents write
```

      with:

```
  1c. **ADR check (mandatory, BEFORE the gate).** Task agents write
```

      Then, in that same paragraph, replace exactly:

```
     It exits 0 clean, 1 with problems listed, 2 on a usage error. On exit 1: fix
     the named files IN THE WORKTREE, commit on the feature branch, re-run it, and
     only then integrate.
```

      with:

```
     It exits 0 clean, 1 with problems listed, 2 on a usage error. On exit 1: fix
     the named files IN THE WORKTREE, commit on the feature branch, and re-run it
     until clean — before the green gate, so a renumber that rewrites a code
     reference is verified rather than shipped unseen.
```

- [x] **Step 3 (renumber the gate itself and add the ride-along failure policy):**
      replace exactly:

```
  2. **Run the repo's configured gate.** Read `<worktree>/.claude/cogniva-dev/green-gate.json`.
```

      with:

```
  2. **GREEN GATE — run the repo's configured gate (mandatory, no shortcuts).** This
     is the LAST step before integration; the tree must be exactly what will merge.
     Read `<worktree>/.claude/cogniva-dev/green-gate.json`.
```

      Then replace exactly:

```
  5. Only if the gate is GREEN (or skipped/empty) AND the ADR check is clean,
     integrate (Step 4). If either is red, report the exact failing command and its
     output, and STOP.
```

      with:

```
  2a. **If the gate is red and this run has ride-along commits.** Make ONE repair
     attempt in the worktree, commit it, and re-run the gate. Still red: `git revert`
     every ride-along commit (theirs are the only optional ones), commit the reverts,
     and re-run the gate a third time. Green now → the ride-alongs were the cause;
     integrate the feature and report plainly: "folded-in <X> failed the gate —
     reverted and captured to the backlog instead", then capture each reverted item
     via `/cogniva-dev:backlog`. Still red after the revert → an ordinary pre-existing
     gate failure; report it and STOP. Optional work approved in passing never holds
     finished work hostage. The same revert path applies if a ride-along turns out
     mid-work to be larger than you stated: stop, revert, capture, say what you got
     wrong — do not design your way out of it.

  3. Only if the gate is GREEN (or skipped/empty) AND the ADR check is clean,
     integrate (Step 4). With no ride-along commits in play, a red gate is an
     ordinary failure: report the exact failing command and its output, and STOP.
```

- [x] **Step 4 (strip the now-duplicated before-integrate block from Step 4):**
      replace exactly:

```
**Repo obligations (`before-integrate`).** Before the steps below, check the
target repo's CLAUDE.md `## Cogniva-dev workflow instructions` for a `### before-integrate`
block; honor it on the worktree now (commit anything it produces on the feature
branch so it rides the merge). Absent → nothing to do.

First, **in the WORKTREE**
```

      with:

```
(`before-integrate` already ran in Step 3.1b, before the gate — do not run it
again here.)

First, **in the WORKTREE**
```

      Then replace exactly:

```
- Rare number collisions (parallel worktrees) are caught by the Step 3.4 ADR check
```

      with:

```
- Rare number collisions (parallel worktrees) are caught by the Step 3.1c ADR check
```

      Then replace exactly:

```
  materializes one, dereference every reference it writes — the ADR's own heading
  and any code comment or skill line citing it — to the assigned number. The same
  Step 3.4 check fails the integration if one survives.
```

      with:

```
  materializes one, dereference every reference it writes — the ADR's own heading
  and any code comment or skill line citing it — to the assigned number. The same
  Step 3.1c check fails the integration if one survives.
```

      Then replace exactly:

```
<!-- check-adrs-ignore-file: Step 3.4 cites ADR-C4 as an example. -->
```

      with:

```
<!-- check-adrs-ignore-file: Step 3.1c cites ADR-C4 as an example. -->
```

- [x] **Step 5 (rename the capture-gate heading):** replace exactly:

```
## Capture gate — followups from the run

Task agents never write to a `BACKLOG.md`; they return candidates in the workflow
result's `followups` array. Whenever the workflow returns a non-empty `followups`
— on a BLOCKED stop, a gate stop, or after a successful integration — run the gate
in your report, as the last thing you say.

Read `CAPTURE-BAR.md` in the `backlog` skill's directory. Drop any candidate that
Test 1 covers (a task still remaining in this run, an open plan folder, an existing
open item), then present the survivors in two tables:

- **Table 1 — clear intent:** numbered; the item and its receipt (which task, and
  the located fact).
- **Table 2 — needs a decision:** numbering continues; the item, its receipt, and
  one line on why it is ambiguous.

Then ask once: capture Table 1 as-is? Table 2 by number (or none). Write only
confirmed candidates, via `/cogniva-dev:backlog`. Deliver the tables as the final
text of the turn, with no tool call after it. Empty `followups`, or nothing
surviving the coverage check, means say nothing at all — do not print an empty
table and do not invent candidates to fill one.
```

      with:

```
## Backlog gate — followups from the run

Task agents never write to a `BACKLOG.md`; they return candidates in the workflow
result's `followups` array. Whenever the workflow returns a non-empty `followups`
— on a BLOCKED stop, a gate stop, or after a successful integration — run the gate
in your report, as the last thing you say.

This is the post-integration half of the gate. If a candidate passed Test 3, it was
already offered as a ride-along in Step 3.1a, while the worktree was open — that
happens instead of this, not as well as it. On a BLOCKED or ⛔ stop nothing is
ridden along at all: the run is not finished, so there is no merge to ride.

Read `CAPTURE-BAR.md` in the `backlog` skill's directory. Drop any candidate that
Test 1 covers (a task still remaining in this run, an open plan folder, an existing
open item), then present the survivors under `## Backlog candidates` in its two
tables — `### Clear intent` (numbered; the item and its receipt: which task, and
the located fact) and `### Needs a decision` (numbering continues; the item, its
receipt, and one line on why it is ambiguous). Never head a table "Capture
candidates".

Then ask once, in `CAPTURE-BAR.md`'s words. Write only confirmed candidates, via
`/cogniva-dev:backlog`. Deliver the tables as the final text of the turn, with no
tool call after it. Empty `followups`, or nothing surviving the coverage check,
means say nothing at all — do not print an empty table and do not invent candidates
to fill one.
```

- [x] **Step 6 (strategy.md phase vocabulary):** in `docs/strategy.md`, replace exactly:

```
- `before-integrate` — plan-feature / quick-fix / execute-feature, on the
  worktree just before integration (so anything the block produces rides the
  same merge).
```

      with:

```
- `before-integrate` — plan-feature / quick-fix / execute-feature, on the
  worktree while it is still open, so anything the block produces rides the same
  merge. In the execution skills it runs BEFORE the green gate, not immediately
  before the merge command: everything that rides the merge must be verified by
  the gate, and a block that writes code would otherwise ship unverified. The name
  is kept — its contract was always "on the worktree", not "adjacent to the merge".
```

- [x] **Step 7 (write ADRs C3, C4 and C5):** scan `docs/adr/` for the highest
      existing number and increment for each file in turn, per auto-doc's
      `ADR-FORMAT.md`. Write `docs/adr/NNNN-ride-along-gate-on-the-open-worktree.md`:

```markdown
# The ride-along gate fires on the open worktree, and only when a candidate exists

**Provenance:** Suggested by agent

Confirmed ride-along work is done and committed in the same worktree that just ran the tasks, so it rides the same merge — no second integration, no re-established context. Execution skills pause for the gate only when at least one candidate passes Test 3; a run with none stays fire-and-forget and reports its backlog candidates after integration exactly as before.
```

      Then, with the NEXT number, `docs/adr/NNNN-failing-ride-along-is-reverted.md`:

```markdown
# A failing ride-along is repaired once, then reverted — it never blocks the work

**Provenance:** Suggested by agent

If the green gate is red after ride-along commits, the console makes one repair attempt; still red, it reverts every ride-along commit, re-runs the gate, and captures the items to the backlog instead. Reverting all of them and re-gating is also how attribution is decided — green after the revert means the ride-alongs were the cause, still red means an ordinary pre-existing failure. Optional work approved in passing must never hold finished work hostage.
```

      Then, with the NEXT number, `docs/adr/NNNN-green-gate-is-last-before-integration.md`:

```markdown
# The green gate is the last step before integration; everything that rides the merge is finished first

**Provenance:** Suggested by human

Ride-along work, the repo's `before-integrate` obligations, and the ADR check all run *before* the green gate, so every change that will ride the merge is verified by it. The previous order gated the plan's tasks and then admitted un-gated edits after the gate had gone green — a repo obligation writing code, or an ADR renumber rewriting a code reference — which made "it passed" a claim about a tree that no longer existed. The `before-integrate` phase keeps its name: its contract was always "on the worktree, so it rides the merge", not "immediately adjacent to the merge command".
```

      No heading may contain `ADR-C3`, `ADR-C4` or `ADR-C5`.

- [x] **Step 8 (verify):** run each and confirm:
      - `grep -c "tasks done → tree clean → ride-along gate → before-integrate → ADR check → GREEN GATE → integrate" plugins/cogniva-dev/skills/execute-feature/SKILL.md` → `1`
      - `grep -c "^## Backlog gate — followups from the run$" plugins/cogniva-dev/skills/execute-feature/SKILL.md` → `1`
      - `grep -c "Step 3.4" plugins/cogniva-dev/skills/execute-feature/SKILL.md` → `0`
      - `grep -c "Repo obligations (\`before-integrate\`)" plugins/cogniva-dev/skills/execute-feature/SKILL.md` → `1`
      - `grep -c "BEFORE the green gate, not immediately" docs/strategy.md` → `1`
        (Step 6's replacement text writes `BEFORE` in caps; the check is case-sensitive)
      - `ls docs/adr/ | wc -l` → 5 more than before this feature began

- [x] **Step 9 (commit):** `git add plugins/cogniva-dev/skills/execute-feature/SKILL.md docs/strategy.md docs/adr/`
      then `git commit -m "feat(execute-feature): run the green gate last and add the ride-along gate"`

---

## Task 5: Apply the same reorder and ride-along gate to quick-fix

**Files:**
- Modify: `plugins/cogniva-dev/skills/quick-fix/SKILL.md`

- [ ] **Step 1 (rewrite Step 2's ordering):** in
      `plugins/cogniva-dev/skills/quick-fix/SKILL.md`, replace exactly:

```
## Step 2 — build/test, then auto-integrate
Run the repo green gate exactly as **execute-feature Step 3** defines it: read
```

      with (NOTE: the replacement text below is fenced with FOUR backticks because it
      contains a three-backtick block; write the inner block with three):

````
## Step 2 — finish everything, gate last, then auto-integrate

Same order as **execute-feature Step 3**, and for the same reason — the green gate
is the LAST step before integration, so every change that rides the merge is
verified by it:

```
fix done → tree clean → ride-along gate → before-integrate → ADR check → GREEN GATE → integrate
```

**Ride-along gate (only when a candidate exists).** Read `CAPTURE-BAR.md` in the
`backlog` skill's directory and apply Test 3 to every `clear` candidate in the
workflow's `followups`. None passes → skip it; the fix stays fire-and-forget. At
least one passes → STOP and present the full three-section gate as the final text
of the turn, then make each confirmed ride-along IN THE WORKTREE on the feature
branch, one commit each. Anything not ridden along is captured via
`/cogniva-dev:backlog`. Depth-1: this offer happens once, and work you just admitted
as a ride-along never gets a gate of its own — a genuine second round is another
`/cogniva-dev:quick-fix`, which is cheap. That is the whole point of this skill.

Then run the repo green gate exactly as **execute-feature Step 3** defines it: read
````

- [ ] **Step 2 (move before-integrate ahead of the gate):** replace exactly:

```
**ADR check.** After the gate, before integrating, run the same mandatory check
execute-feature Step 3.4 defines:
```

      with:

```
**ADR check.** BEFORE the gate, run the same mandatory check execute-feature
Step 3.1c defines:
```

      Then replace exactly:

```
**Repo obligations (`before-integrate`).** Before integrating, check the target
repo's CLAUDE.md `## Cogniva-dev workflow instructions` for a `### before-integrate`
block; honor it on the worktree now (commit anything it produces on the feature
branch so it rides the merge). Absent → nothing to do.

If the gate is green (or skipped) and the ADR check is clean:
```

      with:

```
**Repo obligations (`before-integrate`).** Also BEFORE the gate — check the target
repo's CLAUDE.md `## Cogniva-dev workflow instructions` for a `### before-integrate`
block; honor it on the worktree now (commit anything it produces on the feature
branch so it rides the merge). Absent → nothing to do. It runs ahead of the gate so
a block that writes code is verified like any other change.

**If the gate is red and this run has ride-along commits:** one repair attempt, then
`git revert` every ride-along commit and re-run. Green after the revert → the
ride-alongs were the cause; integrate the fix and capture the reverted items to the
backlog instead. Still red → an ordinary failure; report and STOP. Full rules in
execute-feature Step 3.2a.

If the gate is green (or skipped) and the ADR check is clean:
```

- [ ] **Step 3 (update the followups rule):** replace exactly:

```
- If the fix surfaces a follow-up you are NOT doing now, don't drop it and don't
  silently write it — the task agent returns it in the workflow result's
  `followups` array, and you run the capture gate in your report (see
  execute-feature's "Capture gate — followups from the run", and `CAPTURE-BAR.md`
  in the `backlog` skill's directory). Drop anything already covered by this fix
  or an open item; present the rest in the two tables; write only what the user
  confirms, via `/cogniva-dev:backlog`. No followups, or nothing surviving
  coverage → say nothing. If this fix resolved a loose `BACKLOG.md` item, tick it
  and append `→ done` — that is a closure, not a capture, and needs no gate.
```

      with:

```
- If the fix surfaces a follow-up you are NOT doing now, don't drop it and don't
  silently write it — the task agent returns it in the workflow result's
  `followups` array, and you run the gate (see execute-feature's "Backlog gate —
  followups from the run", and `CAPTURE-BAR.md` in the `backlog` skill's
  directory). Drop anything already covered by this fix or an open item; anything
  that passed Test 3 was already offered as a ride-along in Step 2, while the
  worktree was open; present the rest under `## Backlog candidates` in its two
  tables and write only what the user confirms, via `/cogniva-dev:backlog`. Never
  head a table "Capture candidates". No followups, or nothing surviving coverage →
  say nothing. If this fix resolved a loose `BACKLOG.md` item, tick it and append
  `→ done` — that is a closure, not a capture, and needs no gate.
```

- [ ] **Step 4 (verify):** run each and confirm:
      - `grep -c "fix done → tree clean → ride-along gate → before-integrate → ADR check → GREEN GATE → integrate" plugins/cogniva-dev/skills/quick-fix/SKILL.md` → `1`
      - `grep -c "Step 3.4" plugins/cogniva-dev/skills/quick-fix/SKILL.md` → `0`
      - `grep -c "Backlog gate —" plugins/cogniva-dev/skills/quick-fix/SKILL.md` → `1`
        (the full phrase "Backlog gate — followups from the run" wraps across a
        line break in Step 3's replacement text, so a line-oriented `grep -c` for
        it can never match — check the cross-reference, not the line wrap)
      - `grep -c "Also BEFORE the gate" plugins/cogniva-dev/skills/quick-fix/SKILL.md` → `1`

- [ ] **Step 5 (commit):** `git add plugins/cogniva-dev/skills/quick-fix/SKILL.md`
      then `git commit -m "feat(quick-fix): run the green gate last and add the ride-along gate"`

---

## Task 6: Stop the workflow template telling a planless agent to edit `undefined`

**Files:**
- Modify: `plugins/cogniva-dev/templates/execute-feature.workflow.js`

Context: the task prompt interpolates `taskPlanPath` and `statePath` unconditionally
("edit `${taskPlanPath}` to flip THIS task's checkboxes… append one short line to
`${statePath}`"), but `quick-fix` Step 1 instructs the caller to OMIT `planPath` and
`statePath`. A planless run therefore tells its agent to edit the literal string
`undefined`. Make those two instructions conditional.

- [ ] **Step 1 (make the prompt conditional):** in
      `plugins/cogniva-dev/templates/execute-feature.workflow.js`, replace exactly:

```
  const taskPlanPath = t.planPath || planPath
  const prompt = [
    `Implement EXACTLY ONE task of a feature plan, then stop. Do not start the next task.`,
    `Your only working directory is this git worktree: ${worktree}`,
    `You are already checked out on ${featureBranch}. NEVER run git switch / checkout / branch — work where you are.`,
    `Use absolute paths under the worktree. Follow the task's steps verbatim, TDD-style:`,
    `write the failing test → run it (confirm it fails) → minimal implementation → run until green → run the task's full verification.`,
    `On success: stage ONLY the files you changed, commit with the task's commit message (keep the repo's commit conventions),`,
    `then edit ${taskPlanPath} to flip THIS task's checkboxes from "- [ ]" to "- [x]",`,
    `and append one short line to ${statePath}: created/modified paths, key decisions, and the commit SHA.`,
    `If you cannot finish cleanly, return status BLOCKED with a precise note and do NOT leave a partial commit.`,
```

      with:

```
  const taskPlanPath = t.planPath || planPath
  const prompt = [
    `Implement EXACTLY ONE task of a feature plan, then stop. Do not start the next task.`,
    `Your only working directory is this git worktree: ${worktree}`,
    `You are already checked out on ${featureBranch}. NEVER run git switch / checkout / branch — work where you are.`,
    `Use absolute paths under the worktree. Follow the task's steps verbatim, TDD-style:`,
    `write the failing test → run it (confirm it fails) → minimal implementation → run until green → run the task's full verification.`,
    `On success: stage ONLY the files you changed, commit with the task's commit message (keep the repo's commit conventions).`,
    // Planless runs (quick-fix) pass no planPath/statePath — omit these two instructions
    // entirely rather than interpolating the string "undefined" into the prompt.
    taskPlanPath ? `Then edit ${taskPlanPath} to flip THIS task's checkboxes from "- [ ]" to "- [x]".` : null,
    statePath ? `Append one short line to ${statePath}: created/modified paths, key decisions, and the commit SHA.` : null,
    `If you cannot finish cleanly, return status BLOCKED with a precise note and do NOT leave a partial commit.`,
```

- [ ] **Step 2 (drop the nulls before joining):** replace exactly:

```
    `=== TASK ${t.n}: ${t.title} ===`,
    t.body,
  ].join('\n')
```

      with:

```
    `=== TASK ${t.n}: ${t.title} ===`,
    t.body,
  ].filter(l => l !== null).join('\n')
```

- [ ] **Step 3 (verify — syntax and behaviour):** run each and confirm:
      - `node --check plugins/cogniva-dev/templates/execute-feature.workflow.js` → exits 0, no output
      - `grep -c "filter(l => l !== null)" plugins/cogniva-dev/templates/execute-feature.workflow.js` → `1`
      - `grep -c "taskPlanPath ?" plugins/cogniva-dev/templates/execute-feature.workflow.js` → `1`
      - `tr -cd '\r' < plugins/cogniva-dev/templates/execute-feature.workflow.js | wc -c` → `0`
        (the file must stay LF — CRLF makes the Workflow tool reject the script)

- [ ] **Step 4 (commit):** `git add plugins/cogniva-dev/templates/execute-feature.workflow.js`
      then `git commit -m "fix(execute-feature): omit plan/state prompt lines on a planless run"`
