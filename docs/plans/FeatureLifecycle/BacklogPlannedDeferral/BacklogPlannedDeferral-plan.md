# BacklogPlannedDeferral — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/BacklogPlannedDeferral
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace
> and the tasks commit on the branch they are already on. Never run
> git switch/checkout/branch inside a task.

**Goal:** Refocus the backlog toolkit so a backlog item is a **planned deferral** — an entry exists only with a stated reason not to do the work now (`because:`), reason-less real work is routed (Do now / Plan next) instead of parked, introduced defects are fixed as unfinished work, and vague-and-unimportant observations are dropped with a one-line mention.

**Architecture:** The change is confined to markdown skill docs, one workflow template, ADRs, and the glossary — no scripts change. `CAPTURE-BAR.md` (the shared routing contract in the `backlog` skill) is rewritten wholesale as the single source of truth; every caller (`execute-feature`, `quick-fix`, `easy-work-scan`, `plan-feature`, `explore-idea`) is re-pointed at its new route-first gate with small surgical edits; `groom-backlog` gains reason-cleared / reason-less flags; the `followups` schema in `execute-feature.workflow.js` gains an optional `because` field and an introduced-defect instruction. Four ADRs record the decisions; three existing ADRs get amendment notes.

**Read these first:**
- `plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md` (being replaced — the old contract)
- `plugins/cogniva-dev/skills/backlog/SKILL.md` and `BACKLOG-FORMAT.md`
- `docs/adr/0017-backlog-capture-coverage-and-intent.md`, `docs/adr/0019-capture-candidates-two-tables.md`, `docs/adr/0020-ride-along-promotes-a-backlog-candidate.md`
- `plugins/cogniva-dev/skills/adr/ADR-FORMAT.md` (for writing the candidate ADRs)

## File structure (locked)

```
plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md        # REWRITE — route-first tests + gate (Task 1)
plugins/cogniva-dev/skills/backlog/SKILL.md              # Modify — planned-deferral intent, because input (Task 1)
plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md     # Modify — because: tag grammar, stub template (Task 1)
plugins/cogniva-dev/skills/execute-feature/SKILL.md      # Modify — Do-now gate, route-first backlog gate (Task 2)
plugins/cogniva-dev/templates/execute-feature.workflow.js# Modify — followups schema + prompt line (Task 2)
plugins/cogniva-dev/skills/quick-fix/SKILL.md            # Modify — gate name + follow-ups rule (Task 2)
plugins/cogniva-dev/skills/easy-work-scan/SKILL.md       # Modify — report routing paragraph (Task 2)
plugins/cogniva-dev/skills/plan-feature/SKILL.md         # Modify — handoff-pass routing paragraph (Task 2)
plugins/cogniva-dev/skills/explore-idea/SKILL.md         # Modify — "Park it" because nudge (Task 2)
plugins/cogniva-dev/skills/groom-backlog/GROOMING-CRITERIA.md # Modify — actionable-now extension + reason-less flag (Task 3)
plugins/cogniva-dev/skills/groom-backlog/SKILL.md        # Modify — Step 3 flags line (Task 3)
docs/adr/0017-backlog-capture-coverage-and-intent.md     # Modify — amended-by note (Task 3)
docs/adr/0019-capture-candidates-two-tables.md           # Modify — superseded status (Task 3)
docs/adr/0020-ride-along-promotes-a-backlog-candidate.md # Modify — re-route wording (Task 3)
docs/glossary/README.md                                  # Modify — Backlog + Ride-along entries (Task 3)
docs/plans/BACKLOG.md                                    # Modify — header line only (Task 3)
docs/plans/FeatureLifecycle/BACKLOG.md                   # Modify — header line only (Task 3)
plugins/cogniva-dev/.claude-plugin/plugin.json           # Modify — version 0.7.0 → 0.7.1 (Task 4)
plugins/cogniva-dev/.codex-plugin/plugin.json            # Modify — version 0.7.0 → 0.7.1 (Task 4)
.claude-plugin/marketplace.json                          # Modify — cogniva-dev entry version only (Task 4)
docs/adr/NNNN-*.md (x4 new)                              # Created by Tasks 1–2 per ## Candidate ADRs
```

## Candidate ADRs

### ADR-C1: A backlog item is a planned deferral
**Provenance:** Suggested by human
A backlog entry exists only with a stated reason not to do the work now (`because:` — blocked-on, sequenced-after, decision pending, or an explicit human "later"). Skill-initiated capture requires the reason; direct human capture is encouraged to give one but never blocked. Reason-less real work is routed (Do now / Plan next) or dropped — never parked.
**Write with:** Task 1

### ADR-C3: The confirmation gate is route-first, with Do now as the assumed preference
**Provenance:** Suggested by human
Work surfaced mid-run is presented by proposed route — Do now (in-hand context only) / Plan next (a ready-to-fire invocation, never auto-run) / Backlog (only with `because:`) / Needs a decision — behind the existing single confirmation gate. When a reason-less candidate could honestly go either way between Do now and Plan next, Do now is proposed: the observed failure mode was deferring current-session work. Supersedes ADR 0019's two-table presentation; receipts, confidence separation, and the one-gate rule carry forward.
**Write with:** Task 1

### ADR-C4: Vague-and-unimportant work is dropped, not captured (amends ADR 0017)
**Provenance:** Suggested by human
An observation with no receipt and no importance is not offered at the gate and never backlogged; it gets one throwaway line in the report ("noticed X — dropped; say the word to keep it") so nothing vanishes silently. Importance is the axis — small-but-important still qualifies, and genuinely unclear importance stays a Needs-a-decision row. Amends ADR 0017's "no item is ever rejected for being vague, small, or unimportant"; the coverage and intent tests are unchanged.
**Write with:** Task 1

### ADR-C2: A defect introduced by the current run is unfinished work, not a followup
**Provenance:** Suggested by human
A bug the current run's own work introduced is fixed before the run completes, in the same workspace, with no gate. Two exceptions, both raised immediately rather than deferred: the fix would change what the feature is (or its design), or it is big enough to warrant its own plan — then the run proposes the fix plan instead. An introduced defect is never backlogged and never silently dropped.
**Write with:** Task 2

## Task 1: Rewrite the backlog skill core (CAPTURE-BAR, SKILL, BACKLOG-FORMAT)

**Files:**
- Modify: `plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md` (full replace)
- Modify: `plugins/cogniva-dev/skills/backlog/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md`
- Create: three ADRs under `docs/adr/` (see steps)

- [ ] **Step 1 (replace CAPTURE-BAR.md):** overwrite `plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md` with EXACTLY this content:

````markdown
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
````

- [ ] **Step 2 (backlog SKILL.md — description):** in `plugins/cogniva-dev/skills/backlog/SKILL.md`, replace the frontmatter `description:` line (currently beginning `description: Use to capture deferred or not-yet-planned work`) with:
```
description: Use to capture a planned deferral - work with a stated reason not to do it now ("blocked on X", "after feature Y", a decision pending, an explicit human "later") so it is not lost. Reason-less real work is done now or routed to quick-fix / plan-feature, never parked here. Directly invokable AND the routing gate for any skill that surfaces work mid-run. Direct invocation writes immediately (a because: reason is encouraged, never demanded); skill-initiated capture is proposed and confirmed first. Lightweight, append-only, no subagents. Read with module-status / repo-status.
```
- [ ] **Step 3 (backlog SKILL.md — intent):** replace the line `Park work somewhere durable instead of in prose or in your head. Two tiers:` with:
```
Park work that must WAIT somewhere durable instead of in prose or in your
head. A backlog item is a **planned deferral**: it exists only with a stated
reason not to do it now (its `because:`). Reason-less real work is done now or
handed off as a ready-to-fire plan invocation — see `CAPTURE-BAR.md`'s
route-first tests. Two tiers:
```
- [ ] **Step 4 (backlog SKILL.md — direct mode):** in the `## Two modes` section, after the sentence ending `No gate, no interrogation, no request to refine the wording.` insert: `If the item carries no deferral reason, still write it unchanged — then offer ONCE, in the report line, to add a "because:" tag. Never block a human capture on a reason.` (keep the following sentence about the tier-2 stub exception unchanged).
- [ ] **Step 5 (backlog SKILL.md — skill-initiated mode):** in the same section, replace `qualify each candidate against all three tests, hold them as candidate records, and present them in the three-section gate.` with `route each candidate through the tests (0–3), hold them as candidate records, and present them in the route-first gate.`
- [ ] **Step 6 (backlog SKILL.md — inputs):** in `## Inputs`, after the `- **tier**` bullet, add:
```
- **because** (optional on direct human capture, REQUIRED for a
  skill-initiated deferral) — the reason this waits: blocked-on,
  sequenced-after, decision pending, or the user's "later". Written as a
  `because:` tag per `BACKLOG-FORMAT.md`.
```
- [ ] **Step 7 (backlog SKILL.md — Step 2 of Steps):** replace the entire numbered step that begins `2. **Skill-initiated only — qualify intent, then test for a ride-along.**` (through `...that was itself a ride-along (depth-1).`) with:
```
2. **Skill-initiated only — qualify and route.** Apply the tests in
   `CAPTURE-BAR.md` in order. Test 0: a defect this run introduced is
   unfinished work — the CALLING skill fixes it now; never a candidate.
   Test 2: declined or raised-and-dropped → nothing; vague AND unimportant →
   dropped with a one-line mention in the report; otherwise build a candidate
   record with its receipt and strength. Test 3: give every `clear` candidate
   exactly one route — `do-now` (context in hand; the assumed preference),
   `plan-next` (hold the exact invocation to propose), or `defer` (only with a
   `because:` reason). `ambiguous` candidates stay unrouted for the user. Hold
   them all for the gate and do not touch any file yet. This skill never
   *performs* a do-now — the calling skill does that work in its own
   workspace — and never offers one from inside work that was itself a do-now
   (depth-1).
```
- [ ] **Step 8 (backlog SKILL.md — Step 5 of Steps):** replace the numbered step that begins `5. **Skill-initiated only — the gate.**` (through `...An empty candidate set → say nothing.`) with:
```
5. **Skill-initiated only — the gate.** Present every candidate in ONE pass,
   in the four route-first sections defined in `CAPTURE-BAR.md` — `## Do now —
   in this work`, `## Plan next — fire when ready`, `## Backlog — planned
   deferrals`, `## Needs a decision` — each row showing its receipt, plus the
   one-line note for anything Test 2 dropped, then ask once in
   `CAPTURE-BAR.md`'s words. Never head a table "Capture candidates": the
   user-facing noun is **backlog candidate**. Deliver it as the final text of
   the turn with no tool call after it. Nothing is written or done before the
   reply. An empty candidate set → say nothing.
```
- [ ] **Step 9 (backlog SKILL.md — Step 6 of Steps):** in the step `6. **Write the item(s)**`, replace the Loose bullet's parenthetical `(`size:`, `area:`, `src:`)` with `(`size:`, `area:`, `src:`, `because:`)` and append to that bullet: `A skill-initiated deferral always carries its `because:`.` Then in the Stub bullet, replace `(deferred scope, contracts/requests to use, acceptance criteria,` with `(a "Deferred because" line, deferred scope, contracts/requests to use, acceptance criteria,`.
- [ ] **Step 10 (backlog SKILL.md — Rules):** replace the rule beginning `- A ride-along is a promotion of a backlog candidate,` (through `...the calling skill does the work.`) with:
```
- A do-now (ride-along) is a promotion of a backlog candidate, never a
  separate species: one the user declines is re-routed at the gate (plan next
  / defer / drop) — proposing it can never lose work. This skill proposes
  routes; the calling skill does the work.
```
  and in the rule beginning `- Never demand refinement at capture time.`, replace `the tests filter for coverage and intent, never for quality.` with `the tests filter for coverage, intent, and importance — never for wording quality.`
- [ ] **Step 11 (BACKLOG-FORMAT.md — header + grammar):** in `plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md`:
  - Replace `Deferred and not-yet-planned work lives under `docs/plans/`. Two tiers.` with `Planned deferrals live under `docs/plans/` — work with a stated reason to wait. Two tiers.`
  - In the lazy-create header template, replace `Loose & deferred work, not yet planned. Promote with /cogniva-dev:plan-feature;` with `Planned deferrals — work with a stated reason to wait (`because:` tag). Promote with /cogniva-dev:plan-feature;`
  - Replace the item-grammar example line ``- [ ] <description>  `size:S` `area:UI` `src:CreateOrder` `` with ``- [ ] <description>  `size:S` `area:UI` `src:CreateOrder` `because:after ModelUiFoundation` ``
  - After the `- `src:<Feature>` — the feature this was deferred from` bullet line, add:
```
  - `because:<reason>` — why this waits (spaces are fine inside the backticks,
    e.g. `because:blocked on IExportPort`, `because:decision pending`).
    Encouraged on every item; REQUIRED when a skill proposed the deferral.
    Legacy lines without one stay valid — groom-backlog flags them for
    routing.
```
- [ ] **Step 12 (BACKLOG-FORMAT.md — grooming note + stub template):**
  - After the pick-up verbs code block (the one showing `→ planned:` and `→ done`), add the paragraph: `When an item's `because:` reason has cleared — the blocker landed, the awaited feature merged, the pending decision was made — groom-backlog flags it actionable-now with a ready invocation; the pick-up verbs above then apply.`
  - In the tier-2 `backlog.md` template, directly after the line `**Depends on:** <the MVP / feature this comes after>`, add a line: `**Deferred because:** <the reason this waits — required>`
- [ ] **Step 13 (write ADRs):** scan `docs/adr/` for the next free number, then write these three ADRs (in this order, consecutive numbers) per `plugins/cogniva-dev/skills/adr/ADR-FORMAT.md`, each verbatim from `## Candidate ADRs` above: ADR-C1 → `docs/adr/NNNN-backlog-item-is-a-planned-deferral.md`; ADR-C3 → `docs/adr/NNNN-confirmation-gate-is-route-first.md`; ADR-C4 → `docs/adr/NNNN-vague-and-unimportant-is-dropped.md`. Each file: `# <title>` heading, `**Provenance:** Suggested by human`, then the body sentences.
- [ ] **Step 14 (verify):** `grep -n "route-first" plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md plugins/cogniva-dev/skills/backlog/SKILL.md` → at least one hit in each file. `grep -c "because:" plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md` → 4 or more. `grep -n "not-yet-planned" plugins/cogniva-dev/skills/backlog/SKILL.md plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md` → no matches. `ls docs/adr | grep -c "planned-deferral\|route-first\|vague-and-unimportant"` → 3.
- [ ] **Step 15 (commit):** `git add plugins/cogniva-dev/skills/backlog docs/adr` then `git commit -m "feat(backlog): backlog is a planned deferral - route-first capture bar with because: reasons"`

## Task 2: Re-point the callers (execute-feature, workflow template, quick-fix, easy-work-scan, plan-feature, explore-idea)

**Files:**
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/templates/execute-feature.workflow.js`
- Modify: `plugins/cogniva-dev/skills/quick-fix/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/easy-work-scan/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/plan-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/explore-idea/SKILL.md`
- Create: one ADR under `docs/adr/` (see steps)

- [ ] **Step 1 (execute-feature — Do-now gate):** in `plugins/cogniva-dev/skills/execute-feature/SKILL.md`, in the Step 4 land list, replace the block:
```
2. **Ride-along gate** — only when a `clear` followup passes Test 3 of
   `CAPTURE-BAR.md` (in the `backlog` skill's directory): present the
   three-section gate; one commit per confirmed ride-along under
   `commits=task` ONLY — under `none|final` the ride-along edits stay
   uncommitted in the tree (under `final` they ride the Step 4.7 commit).
   Depth-1, once per run.
```
with:
```
2. **Do-now gate** — only when a `clear` followup routes to Do now under
   Test 3 of `CAPTURE-BAR.md` (in the `backlog` skill's directory): present
   the route-first gate; one commit per confirmed do-now under
   `commits=task` ONLY — under `none|final` the do-now edits stay
   uncommitted in the tree (under `final` they ride the Step 4.7 commit).
   Depth-1, once per run.
```
- [ ] **Step 2 (execute-feature — backlog gate section):** in the same file, replace the whole `## Backlog gate` section body (currently `Never silently write or drop `followups`. Apply `CAPTURE-BAR.md`: drop covered items, present survivors under `## Backlog candidates` (`### Clear intent` / `### Needs a decision`), ask once, write only confirmed items via `/cogniva-dev:backlog`. Empty → say nothing. Deliver the tables as the final text of the turn.` — allow for line wraps) with:
```
Never silently write or drop `followups`. A defect a task introduced is not a
followup — it is unfinished work: fix it before landing (Test 0 of
`CAPTURE-BAR.md`). Apply `CAPTURE-BAR.md` to the rest: drop covered items,
route survivors through the route-first gate (`## Do now — in this work` /
`## Plan next — fire when ready` / `## Backlog — planned deferrals` /
`## Needs a decision`), ask once, write only confirmed deferrals — each with
its `because:` — via `/cogniva-dev:backlog`. Plan-next items are proposals the
user fires; never auto-run them. Empty → say nothing. Deliver the tables as
the final text of the turn.
```
- [ ] **Step 3 (workflow template — followups schema):** in `plugins/cogniva-dev/templates/execute-feature.workflow.js`:
  - Replace the `followups` array `description` string (currently beginning `'Backlog CANDIDATES only — never written to any BACKLOG.md by this agent.`) with: `'Route CANDIDATES only — never written to any BACKLOG.md by this agent. Omit or leave empty unless the task surfaced work that is genuinely not covered by this plan or an open plan folder, AND you can point at a concrete observed fact for it. Speculation and "it would be nice if" do not qualify. A bug introduced by THIS task is never a followup — fix it before returning DONE.'`
  - In the followup item `properties`, after the `size: { type: 'string', enum: ['S', 'M', 'L'] },` line, add:
```javascript
          because: { type: 'string', description: 'Deferral reason ONLY if this work genuinely must wait (blocked on something, sequenced after another feature, decision pending). Omit for work that could simply be done or planned next.' },
```
- [ ] **Step 4 (workflow template — prompt line):** in the same file, replace the prompt line:
```
    `NEVER write to any BACKLOG.md. If this task surfaced real work outside the plan, return it in "followups" with a concrete receipt (a located fact) — the console gates it with the user. No receipt, no followup.`,
```
with:
```
    `NEVER write to any BACKLOG.md. Fix any bug YOUR changes introduced before returning DONE — an introduced defect is unfinished work, not a followup. If this task surfaced real work outside the plan, return it in "followups" with a concrete receipt (a located fact) — the console routes it with the user (do now / plan next / defer with a reason). No receipt, no followup.`,
```
- [ ] **Step 5 (quick-fix):** in `plugins/cogniva-dev/skills/quick-fix/SKILL.md`:
  - In Step 2, replace `→ ride-along gate (`CAPTURE-BAR.md`` with `→ do-now gate (`CAPTURE-BAR.md``
  - In Rules, in the Follow-ups bullet, replace the fragment `(CAPTURE-BAR; write only confirmed items via `/cogniva-dev:backlog`).` (allow for the line wrap) with `(CAPTURE-BAR's route-first gate; write only confirmed deferrals, each with its `because:`, via `/cogniva-dev:backlog`).`
- [ ] **Step 6 (easy-work-scan):** in `plugins/cogniva-dev/skills/easy-work-scan/SKILL.md`, in Step 6 (**Report.**), replace the passage from `Anything the dispatch surfaced but did not do` through `those runs own their own ride-along gates.` with:
```
Anything the dispatch surfaced but did not do
   is routed, never written silently: drop what is already covered by an open
   item or a dispatched fix, then present the rest through the route-first
   gate in `CAPTURE-BAR.md` (in the `backlog` skill's directory) — deferrals
   only with a `because:` — and write only what the user confirms, via
   `/cogniva-dev:backlog`. Nothing surviving → say nothing.
   This scan never does surfaced work itself — it dispatches through
   `quick-fix` / `plan-feature`, and those runs own their own do-now gates.
```
- [ ] **Step 7 (plan-feature):** in `plugins/cogniva-dev/skills/plan-feature/SKILL.md`, in `## Handoff pass`, replace the passage from `then` + `ride-alongs and backlog candidates in `CAPTURE-BAR.md`'s three sections` through `silence is not deferral.` (allow for line wraps) with:
```
then
surfaced work through `CAPTURE-BAR.md`'s route-first gate (file in the
`backlog` skill's directory). Do now in a design session means amending the
plan before it is committed; depth-1, offered once. Plan next is a proposed
invocation the user fires — never auto-run. Deferred-scope rules, in short:
covered-by-the-plan is not deferred; declined scope is gone; a deferral needs
a receipt AND a `because:` reason; silence is not deferral;
vague-and-unimportant is dropped with a one-line mention.
```
  (keep the surrounding sentences — the candidate-ADR list before it and `Write confirmed backlog items via` after it — unchanged.)
- [ ] **Step 8 (explore-idea):** in `plugins/cogniva-dev/skills/explore-idea/SKILL.md`, replace `- **Park it:** drop a `/backlog` item or stub so the thread is not lost.` with `- **Park it:** drop a `/backlog` item or stub so the thread is not lost — parking is a planned deferral, so give it a `because:` (usually `because:exploration parked until <X>`).` (keep the rest of that bullet unchanged). In the same bullet, replace the fragment `Exploration has no ride-along` with `Exploration has no do-now` (the rest of that sentence stays).
- [ ] **Step 9 (write ADR):** scan `docs/adr/` for the next free number and write ADR-C2 from `## Candidate ADRs` verbatim to `docs/adr/NNNN-introduced-defects-are-unfinished-work.md` (`# <title>`, `**Provenance:** Suggested by human`, body).
- [ ] **Step 10 (verify):** `grep -rn "ride-along gate\|Ride-along gate" plugins/cogniva-dev/skills` → no matches. `grep -n "Do-now gate\|do-now gate" plugins/cogniva-dev/skills/execute-feature/SKILL.md plugins/cogniva-dev/skills/quick-fix/SKILL.md` → at least one hit in each. `grep -n "because" plugins/cogniva-dev/templates/execute-feature.workflow.js` → hits in both the schema property and the prompt line. `grep -n "introduced" plugins/cogniva-dev/templates/execute-feature.workflow.js` → 2 hits (description + prompt).
- [ ] **Step 11 (commit):** `git add plugins/cogniva-dev/skills/execute-feature plugins/cogniva-dev/skills/quick-fix plugins/cogniva-dev/skills/easy-work-scan plugins/cogniva-dev/skills/plan-feature plugins/cogniva-dev/skills/explore-idea plugins/cogniva-dev/templates/execute-feature.workflow.js docs/adr` then `git commit -m "feat(backlog): callers route followups - do-now gate, because field, introduced-defect rule"`

## Task 3: Grooming, ADR housekeeping, glossary, backlog headers

**Files:**
- Modify: `plugins/cogniva-dev/skills/groom-backlog/GROOMING-CRITERIA.md`
- Modify: `plugins/cogniva-dev/skills/groom-backlog/SKILL.md`
- Modify: `docs/adr/0017-backlog-capture-coverage-and-intent.md`
- Modify: `docs/adr/0019-capture-candidates-two-tables.md`
- Modify: `docs/adr/0020-ride-along-promotes-a-backlog-candidate.md`
- Modify: `docs/glossary/README.md`
- Modify: `docs/plans/BACKLOG.md`, `docs/plans/FeatureLifecycle/BACKLOG.md`

- [ ] **Step 1 (GROOMING-CRITERIA.md):** in `plugins/cogniva-dev/skills/groom-backlog/GROOMING-CRITERIA.md`:
  - Replace the `### actionable-now` body (from `A stub whose `Depends on:` has landed,` through `Grooming never starts the work.`) with:
```
A stub whose `Depends on:` has landed, a loose item whose blocker is gone, or
an item whose `because:` reason has cleared (the awaited feature merged, the
pending decision was made).
**Receipt:** the evidence the dependency landed / the reason cleared.
Suggest the exact `/cogniva-dev:plan-feature` (feature-sized) or
`/cogniva-dev:quick-fix` (small) invocation. Grooming never starts the work.
```
  - After the `### cryptic` subsection (ending `if the user shrugs.`), add:
```
### reason-less

An open item with no `because:` tag (legacy, or captured without a reason).
Not a closure: offer a route — do or plan it now (name the exact invocation),
add a `because:` via confirmed in-place reword, or close `→ wont-do:`. Low
priority; batch these.
```
- [ ] **Step 2 (groom-backlog SKILL.md):** in Step 3 of `plugins/cogniva-dev/skills/groom-backlog/SKILL.md`, replace the flags bullet (from `- **Flags — no edit proposed:** `actionable-now` items (dependency landed —` through ``cryptic` items (ask the user what they meant).`) with:
```
   - **Flags — no edit proposed:** `actionable-now` items (dependency landed
     or `because:` reason cleared — point at the exact
     `/cogniva-dev:plan-feature` or `/cogniva-dev:quick-fix` invocation),
     `reason-less` items (no `because:` tag — offer a route), and `cryptic`
     items (ask the user what they meant).
```
- [ ] **Step 3 (ADR 0017 amendment note):** find the ADR file written by Task 1 whose name contains `vague-and-unimportant` and note its number. Append to `docs/adr/0017-backlog-capture-coverage-and-intent.md` (blank line, then):
```
**Amended by ADR <number> (2026-08-20):** importance is now an axis — a vague AND unimportant observation is dropped with a one-line mention rather than captured. The coverage and intent tests, and the no-wording-bar rule, are unchanged.
```
- [ ] **Step 4 (ADR 0019 superseded):** find the ADR file written by Task 1 whose name contains `route-first` and note its number. In `docs/adr/0019-capture-candidates-two-tables.md`, insert directly under the `**Provenance:**` line:
```
**Status:** superseded by ADR <number> — the gate is now route-first; receipts, confidence separation, and the single gate carry forward.
```
- [ ] **Step 5 (ADR 0020 re-route wording):** in `docs/adr/0020-ride-along-promotes-a-backlog-candidate.md`, replace `a ride-along the user declines falls through to the backlog rather than being lost` with `a ride-along (presented as "Do now" in the route-first gate) the user declines is re-routed at the gate — plan next, or the backlog with a `because:` — rather than being lost`, and replace `context already paid for (a named path), unchanged goal, a nameable saving, and at most two open decisions` with `context already paid for (a named path), unchanged goal, not plan-sized, and at most two open decisions`.
- [ ] **Step 6 (glossary):** in `docs/glossary/README.md`:
  - Replace the `## Backlog` entry body (the paragraph beginning `Deferred or not-yet-planned work tracked under`) with:
```
Planned-deferral work tracked under `docs/plans/`: an item exists only with a stated reason not to do it now (its `because:` tag — encouraged on human captures, required on skill-initiated ones). Loose one-line items in a `BACKLOG.md` (repo-level, or per-[Module](#module)), or feature-sized [Backlog stubs](#backlog-stub). Captured with the `backlog` skill, whose capture bar routes reason-less work to be done now or planned instead; surfaced by `module-status` / `repo-status`.
```
  - Replace the `## Ride-along` entry body (the paragraph beginning `Work surfaced during planning or execution` and ending `carries no ride-alongs of its own.`) with:
```
Work surfaced during planning or execution that is done as part of the current work rather than deferred to the [Backlog](#backlog) — presented as **Do now** in the route-first confirmation gate, and the assumed preference when the context is in hand (a named path), the goal is unchanged, the work is not plan-sized, and any open decision is small enough to pose in the gate table. Named for the merge it rides. Offered once per run and never recursive: a ride-along carries no ride-alongs of its own.
```
  (keep both entries' `_Avoid_:` lines unchanged.)
- [ ] **Step 7 (backlog headers):** in BOTH `docs/plans/BACKLOG.md` and `docs/plans/FeatureLifecycle/BACKLOG.md`, replace the header line `Loose & deferred work, not yet planned. Promote with /cogniva-dev:plan-feature;` with `Planned deferrals — work with a stated reason to wait (`because:` tag). Promote with /cogniva-dev:plan-feature;` (leave every item line untouched).
- [ ] **Step 8 (verify):** `grep -rn "not-yet-planned" plugins/cogniva-dev/skills docs/glossary/README.md` → no matches. `grep -n "not yet planned" docs/plans/BACKLOG.md docs/plans/FeatureLifecycle/BACKLOG.md` → no matches. `grep -n "reason-less" plugins/cogniva-dev/skills/groom-backlog/GROOMING-CRITERIA.md plugins/cogniva-dev/skills/groom-backlog/SKILL.md` → at least one hit in each. `grep -n "Amended by" docs/adr/0017-backlog-capture-coverage-and-intent.md` → one hit. `grep -n "superseded by" docs/adr/0019-capture-candidates-two-tables.md` → one hit.
- [ ] **Step 9 (commit):** `git add plugins/cogniva-dev/skills/groom-backlog docs/adr/0017-backlog-capture-coverage-and-intent.md docs/adr/0019-capture-candidates-two-tables.md docs/adr/0020-ride-along-promotes-a-backlog-candidate.md docs/glossary/README.md docs/plans/BACKLOG.md docs/plans/FeatureLifecycle/BACKLOG.md` then `git commit -m "feat(backlog): grooming reason-cleared flags, ADR amendments, glossary planned-deferral"`

## Task 4: Version bump and validation

**Files:**
- Modify: `plugins/cogniva-dev/.claude-plugin/plugin.json`
- Modify: `plugins/cogniva-dev/.codex-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1 (bump):** change `"version": "0.7.0"` to `"version": "0.7.1"` in `plugins/cogniva-dev/.claude-plugin/plugin.json`, `plugins/cogniva-dev/.codex-plugin/plugin.json`, and in the **cogniva-dev entry only** of `.claude-plugin/marketplace.json` (the marketplace also lists cogniva-skills at 0.8.0 — do NOT touch that entry). Patch bump, user-approved: this fixes the backlog toolkit's implementation to match its intended behavior without changing what the toolkit is. If cogniva-dev's version is no longer 0.7.0 when this task runs, bump patch from whatever it currently is (all three files identical) and note the actual numbers in the task summary.
- [ ] **Step 2 (confirm parity):** `grep -n "\"version\"" plugins/cogniva-dev/.claude-plugin/plugin.json plugins/cogniva-dev/.codex-plugin/plugin.json .claude-plugin/marketplace.json` → the two plugin.json files and the cogniva-dev marketplace entry all read the new version; the cogniva-skills entry is untouched.
- [ ] **Step 3 (validate):** `claude plugin validate .` → exits 0 / reports valid. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-plugin-manifests.ps1` → passes (manifest parity across each plugin's manifest pair and its marketplace entry).
- [ ] **Step 4 (commit):** `git add plugins/cogniva-dev/.claude-plugin/plugin.json plugins/cogniva-dev/.codex-plugin/plugin.json .claude-plugin/marketplace.json` then `git commit -m "chore(cogniva-dev): bump version - backlog planned-deferral refocus"`
