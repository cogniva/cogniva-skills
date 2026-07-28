# BacklogCaptureDiscipline — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/BacklogCaptureDiscipline
> Tasks contain NO git worktree/branch step — execute-feature creates the worktree
> and the tasks commit on the feature branch they are already on. Never run
> git switch/checkout/branch inside a task.

**Goal:** Stop the backlog filling with items nobody deferred — gate capture on
coverage and evidence of intent, and make every skill-initiated write
propose-then-confirm instead of silent.

**Architecture:** All changes are to the `cogniva-dev` plugin's skill markdown plus
one workflow template. A new lazy-loaded companion `CAPTURE-BAR.md` in the
`backlog` skill holds the whole policy — the coverage test, the intent/receipt
test, the candidate record shape, and the two-table confirmation format — so the
callers only need a one-paragraph contract plus a pointer. `backlog/SKILL.md` gains
two invocation modes (direct = write immediately; skill-initiated = propose). The
five calling skills (`plan-feature`, `execute-feature`, `quick-fix`,
`easy-work-scan`, `explore-idea`) switch from writing to proposing, and
`execute-feature.workflow.js` grows a `followups` field on its task-result schema so
non-interactive task agents can return candidates to the console instead of writing
them.

**Read these first:**
- `plugins/cogniva-dev/skills/backlog/SKILL.md` — the skill being changed
- `plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md` — line grammar (unchanged by this feature)
- `plugins/cogniva-dev/skills/groom-backlog/SKILL.md` — the two-table + one-gate pattern being mirrored
- `docs/adr/0013-backlog-grooming-propose-with-receipts.md` — the receipts contract this extends
- `docs/adr/0014-lazy-loaded-skill-companion-files.md` — why `CAPTURE-BAR.md` is a companion file
- `plugins/cogniva-dev/templates/execute-feature.workflow.js` — the task-result schema

## File structure (locked)

```
plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md          # NEW — coverage test, intent/receipt test, candidate record, two-table gate format
plugins/cogniva-dev/skills/backlog/SKILL.md                # MODIFY — direct vs skill-initiated modes, coverage pre-check, caller contract
plugins/cogniva-dev/skills/plan-feature/SKILL.md           # MODIFY — deferrals become candidates folded into the ADR handoff pass
plugins/cogniva-dev/skills/execute-feature/SKILL.md        # MODIFY — BLOCKED-task scope proposed via followups, gated in the console report
plugins/cogniva-dev/templates/execute-feature.workflow.js  # MODIFY — followups[] on TASK_RESULT, surfaced in the return value
plugins/cogniva-dev/skills/quick-fix/SKILL.md              # MODIFY — surfaced follow-ups proposed, not written
plugins/cogniva-dev/skills/easy-work-scan/SKILL.md         # MODIFY — Step 6 proposes instead of writing
plugins/cogniva-dev/skills/explore-idea/SKILL.md           # MODIFY — no capture mid-exploration; park only when the user asks
docs/adr/NNNN-*.md                                         # NEW x3 — written by tasks 1 and 2
```

## Candidate ADRs

### ADR-C1: Backlog capture is gated on coverage and evidence of intent, not on quality
**Provenance:** Suggested by human
**Relitigation:** Open to discussion
Capture must stay cheap at the moment of capture — a quality bar that makes a human stop and refine wording mid-task is counterproductive and suppresses real items. Two filters apply instead, both resolvable without asking the human anything: coverage (do not capture what in-flight work already covers — the plan being written, an open plan folder, the change being made, an active exploration, an existing open item) and intent (an out-of-scope idea qualifies only with a concrete receipt: something the user said, or an observed fact — never the agent's read of enthusiasm). No item is ever rejected for being vague, small, or unimportant.
**Write with:** Task 1

### ADR-C2: Skill-initiated backlog capture is propose-then-confirm; direct invocation writes immediately
**Provenance:** Suggested by human
A human typing `/cogniva-dev:backlog` has already consented, so it writes and reports. A skill that noticed the work itself proposes instead: interactive callers batch candidates into their existing end-of-run confirmation pass, and non-interactive workflow agents return candidates through the task result for the invoking console to gate. Nothing a skill decided on its own reaches a `BACKLOG.md` unconfirmed.
**Write with:** Task 2

### ADR-C3: Capture candidates are presented in two confidence-separated tables, per ADR 0013
**Provenance:** Suggested by human
Candidates are split by receipt strength — clear intent (scan-and-nod) versus ambiguous (needs a decision) — each showing its receipt, behind one gate. This extends the grooming presentation contract to capture, so a user can skim the strong set and spend attention only on the weak one; ambiguous candidates are proposed rather than suppressed, because dropping one is a keystroke and losing one is silent.
**Write with:** Task 2

## Task 1: Write the CAPTURE-BAR.md companion

**Files:**
- Create: `plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md`
- Create: `docs/adr/NNNN-backlog-capture-coverage-and-intent.md` (number resolved in Step 4)

- [x] **Step 1 (create the companion):** Write `plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md` with EXACTLY this content:

````markdown
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
````

- [x] **Step 2 (verify the file exists and is non-trivial):** run
      `bash -c 'wc -l < plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md'`
      → a number greater than `100`.

- [x] **Step 3 (verify the two tests are named):** run
      `bash -c 'grep -c "^## Test [12] —" plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md'`
      → `2`.

- [x] **Step 4 (write ADR):** scan `docs/adr/` for the highest existing number,
      increment by one, and write the confirmed candidate ADR-C1 verbatim to
      `docs/adr/NNNN-backlog-capture-coverage-and-intent.md` per auto-doc's
      ADR-FORMAT — title as the `#` heading, then the `**Provenance:**` and
      `**Relitigation:**` lines, then the body paragraph:

```markdown
# Backlog capture is gated on coverage and evidence of intent, not on quality

**Provenance:** Suggested by human
**Relitigation:** Open to discussion

Capture must stay cheap at the moment of capture — a quality bar that makes a human stop and refine wording mid-task is counterproductive and suppresses real items. Two filters apply instead, both resolvable without asking the human anything: coverage (do not capture what in-flight work already covers — the plan being written, an open plan folder, the change being made, an active exploration, an existing open item) and intent (an out-of-scope idea qualifies only with a concrete receipt: something the user said, or an observed fact — never the agent's read of enthusiasm). No item is ever rejected for being vague, small, or unimportant.
```

- [x] **Step 5 (commit):** `git add plugins/cogniva-dev/skills/backlog/CAPTURE-BAR.md docs/adr/` then
      `git commit -m "feat(backlog): add the capture bar companion (coverage + intent tests)"`

## Task 2: Rewrite backlog/SKILL.md for two invocation modes

**Files:**
- Modify: `plugins/cogniva-dev/skills/backlog/SKILL.md`
- Create: `docs/adr/NNNN-skill-initiated-capture-is-propose-then-confirm.md` (number resolved in Step 5)
- Create: `docs/adr/NNNN-capture-candidates-two-tables.md` (number resolved in Step 5)

- [x] **Step 1 (replace the whole file):** Overwrite
      `plugins/cogniva-dev/skills/backlog/SKILL.md` with EXACTLY this content:

````markdown
---
name: backlog
description: Use to capture deferred or not-yet-planned work so it is not lost - a loose idea ("dropdown should be a treeview", "slight UI issue"), scope intentionally cut from a plan, or a feature-sized idea worth tracking before it earns a full plan. Directly invokable AND meant to be called by any skill that surfaces work it is not doing right now. Direct invocation writes immediately; skill-initiated capture is proposed and confirmed first. Lightweight, append-only, no subagents. Read with module-status / repo-status.
---

# Backlog

Park work somewhere durable instead of in prose or in your head. Two tiers:

- **Tier 1 — loose item:** one checklist line in a `BACKLOG.md`. For small things
  not worth a folder (a UI tweak, a bug, a "should be X later").
- **Tier 2 — feature-sized stub:** a folder under a Module with `state.md`
  (`Status: deferred`) + `backlog.md`. For a cohesive chunk of future capability
  that will eventually earn a full `/cogniva-dev:plan-feature` plan.

Read `BACKLOG-FORMAT.md` in this skill's directory for the exact line grammar and
stub layout. This skill is **model-driven** (you edit markdown directly — no
script) and **append-by-default**: never delete or reorder existing items (grooming
may close or reword them — see the groom-backlog skill).

Invoke: `/cogniva-dev:backlog [<item description>]` (omit to be asked).

## Two modes — who decided to capture this?

**Direct** — a human invoked `/cogniva-dev:backlog`. They have already consented.
Run the coverage check (Test 1 in `CAPTURE-BAR.md`), then write and report. No
gate, no interrogation, no request to refine the wording. The one exception is a
tier-2 stub: confirm the tier before creating a folder.

**Skill-initiated** — you surfaced the work yourself while doing something else.
**Propose; do not write.** Read `CAPTURE-BAR.md` (lazy-loaded — do not read it
for a direct invocation of an already-covered item), qualify each candidate
against both tests, hold them as candidate records, and present them in the
two-table gate. Only what the user confirms is written.

## Inputs

- **description** — what the work is, in one line.
- **module** (optional) — the owning Module. If the item clearly belongs to one,
  use it; otherwise the item is repo-level.
- **size** (optional) — `S` | `M` | `L`.
- **src** (optional) — the `<Feature>` this was deferred from, if any.
- **tier** (optional) — `loose` | `stub`. If absent, you decide (see below).

## Steps

1. **Coverage check (always, both modes).** Apply Test 1 in `CAPTURE-BAR.md`: is
   this already handled by the plan being written, an open plan folder, the change
   in flight, an active exploration, or an existing open item? If yes, do NOT
   capture — say so in one line, naming what covers it, and stop.

2. **Skill-initiated only — qualify intent.** Apply Test 2 in `CAPTURE-BAR.md`.
   Declined or raised-and-dropped → nothing. Otherwise build a candidate record
   with its receipt and a `clear` / `ambiguous` strength, and hold it for the gate.
   Do not touch any file yet.

3. **Pick the tier.** A one-liner or small fix → **loose**. A cohesive future
   capability with its own scope, contracts, and acceptance criteria → **stub**.
   When another skill called you with a `tier=`, honor it. A stub is a folder plus
   two files and shows up in `module-status` as a real deferred feature — confirm
   before creating one, even on a direct invocation.

4. **Pick the file / folder.**
   - Belongs to a Module → `docs/plans/<Module>/BACKLOG.md` (loose) or
     `docs/plans/<Module>/<Idea>/` (stub, `<Idea>` PascalCase).
   - Cross-cutting / no Module → `docs/plans/BACKLOG.md` (loose only).
   - **Lazy-create**: if `BACKLOG.md` does not exist, create it from the header in
     `BACKLOG-FORMAT.md`.

5. **Skill-initiated only — the gate.** Present every candidate in ONE pass, in
   the two tables defined in `CAPTURE-BAR.md` (clear intent / needs a decision),
   each row showing its receipt, then ask once: capture Table 1 as-is, Table 2 by
   number. Deliver it as the final text of the turn with no tool call after it.
   Nothing is written before the reply. An empty candidate set → say nothing.

6. **Write the item(s)** — confirmed candidates only, or the direct invocation.
   - **Loose:** append one `- [ ] <description>` line with optional trailing
     backtick tags (`size:`, `area:`, `src:`) per `BACKLOG-FORMAT.md`.
   - **Stub:** create the folder with `state.md` (`Status: deferred`) and
     `backlog.md` (deferred scope, contracts/requests to use, acceptance criteria,
     the MVP it depends on, and a one-line "expand with /cogniva-dev:plan-feature"
     pointer).

7. **Report** one line per item: tier, path, and the item text. No HTML, no
   glossary work, minimal ceremony.

## Called by another skill

Any skill that finds work it is not doing now routes it here rather than burying
it in prose — but as a **proposal**, never a write. The caller invokes:

```
/cogniva-dev:backlog  module=<Module> tier=loose|stub size=<S> src=<Feature> — <description>
```

Honor the passed `tier`/`module`; run the coverage check; qualify intent; return
the candidate record. Where the gate happens depends on the caller's context:

- **Interactive caller** (`plan-feature`, `groom-backlog`, `easy-work-scan`) —
  the caller batches candidates into its own end-of-run confirmation pass and
  presents the two tables there. One interruption, not two.
- **Non-interactive caller** (an `execute-feature` or `quick-fix` task agent
  inside a background Workflow) — there is nobody to ask. The agent returns
  candidates in its task result's `followups` array and writes nothing; the
  invoking console runs the gate in its end-of-run report.

## Rules

- Append-by-default. Never delete existing items here — promotion (ticking an
  item, flipping a stub's `Status`) is done by `plan-feature`/`quick-fix` when the
  work is picked up; closure and confirmed in-place rewording are done by
  `groom-backlog`.
- Nothing a skill decided on its own reaches a `BACKLOG.md` unconfirmed. A direct
  human invocation is already confirmed and needs no gate.
- Never demand refinement at capture time. A vague one-liner from someone
  mid-task is a good item; the tests filter for coverage and intent, never for
  quality.
- Keep it lightweight: one line or one small folder, then stop. This skill never
  writes feature code and never runs subagents.
- In a guard-opted-in repo's primary checkout, tier-1 loose appends work directly:
  `BACKLOG.md` files (`docs/plans/BACKLOG.md`, `docs/plans/<Module>/BACKLOG.md`)
  are exempt from the primary-edit guard. Tier-2 stub creation is NOT exempt —
  create stubs inside a worktree (e.g. while other worktree work is open, or via
  `/cogniva-dev:quick-fix`).
````

- [x] **Step 2 (verify both modes are documented):** run
      `bash -c 'grep -c "Skill-initiated" plugins/cogniva-dev/skills/backlog/SKILL.md'`
      → a number `4` or greater.

- [x] **Step 3 (verify the companion is referenced):** run
      `bash -c 'grep -c "CAPTURE-BAR.md" plugins/cogniva-dev/skills/backlog/SKILL.md'`
      → a number `5` or greater.

- [x] **Step 4 (validate the plugin):** run `claude plugin validate .` → exits 0.

- [x] **Step 5 (write ADRs):** scan `docs/adr/` for the highest existing number.
      Write the next number to
      `docs/adr/NNNN-skill-initiated-capture-is-propose-then-confirm.md`:

```markdown
# Skill-initiated backlog capture is propose-then-confirm; direct invocation writes immediately

**Provenance:** Suggested by human

A human typing `/cogniva-dev:backlog` has already consented, so it writes and reports. A skill that noticed the work itself proposes instead: interactive callers batch candidates into their existing end-of-run confirmation pass, and non-interactive workflow agents return candidates through the task result for the invoking console to gate. Nothing a skill decided on its own reaches a `BACKLOG.md` unconfirmed.
```

      Then increment again and write
      `docs/adr/NNNN-capture-candidates-two-tables.md`:

```markdown
# Capture candidates are presented in two confidence-separated tables, per ADR 0013

**Provenance:** Suggested by human

Candidates are split by receipt strength — clear intent (scan-and-nod) versus ambiguous (needs a decision) — each showing its receipt, behind one gate. This extends the grooming presentation contract to capture, so a user can skim the strong set and spend attention only on the weak one; ambiguous candidates are proposed rather than suppressed, because dropping one is a keystroke and losing one is silent.
```

- [x] **Step 6 (commit):** `git add plugins/cogniva-dev/skills/backlog/SKILL.md docs/adr/` then
      `git commit -m "feat(backlog): split direct and skill-initiated capture modes"`

## Task 3: Fold plan-feature deferrals into the ADR handoff pass

**Files:**
- Modify: `plugins/cogniva-dev/skills/plan-feature/SKILL.md`

- [x] **Step 1 (replace the deferral section):** In
      `plugins/cogniva-dev/skills/plan-feature/SKILL.md`, find the section that
      begins with the heading `## Capture deferrals (don't bury cut scope in prose)`
      and replace that heading and its whole body (up to but NOT including the next
      `## ` heading, which is `## Promotion (when this plan fulfills an existing backlog item)`)
      with EXACTLY this:

````markdown
## Capture deferrals (propose, don't write)

A focused design always cuts scope — but most cut scope is not backlog material.
Do NOT write anything to a `BACKLOG.md` from this session. Hold cut items as
**capture candidates** and confirm them at handoff, in the same pass as the
candidate ADRs (below).

Read `CAPTURE-BAR.md` in the `backlog` skill's directory for the full tests. In
short:

- **Coverage first.** If the plan you just wrote actually delivers it — its Goal,
  a task, a sub-plan — it is not deferred scope. Neither is anything already
  covered by an open plan folder (`state.md` `Status:` `planned` /
  `in-progress` / `blocked`), an active `.explore/` thread, or an existing open
  backlog item. This is the single biggest source of backlog churn: items written
  during planning and closed during execution, having never been deferred at all.
- **Then intent.** Scope the user declined ("no", "wrong approach") is gone —
  never a candidate. Scope with a receipt — their words ("let's do that soon but
  not today", "next one"), or substantive engagement — is a `clear` candidate.
  Scope you floated that they did not engage with is nothing: silence is not
  deferral. Anything in between is `ambiguous`; when you cannot tell, use
  `ambiguous` rather than dropping it.

Hold each survivor as a candidate record (`description`, `module`, `tier`, `size`,
`src`, `receipt`, `strength`). They are presented at handoff, not now.
````

- [x] **Step 2 (extend the ADR handoff heading):** In the same file, find the
      heading `## Confirm candidate ADRs (once, at handoff)` and replace that exact
      line with:

```markdown
## Confirm candidate ADRs and capture candidates (once, at handoff)
```

- [x] **Step 3 (add the capture half to the handoff pass):** In the same file,
      inside that handoff section, find the bullet that begins
      `- If there are no candidate ADRs, skip this` and insert the following text
      immediately AFTER that bullet's line, as a new paragraph block:

````markdown
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
````

- [x] **Step 4 (verify the old auto-write instruction is gone):** run
      `bash -c 'grep -c "tier=loose src=" plugins/cogniva-dev/skills/plan-feature/SKILL.md'`
      → `0`.

- [x] **Step 5 (verify the new section landed):** run
      `bash -c 'grep -c "Capture deferrals (propose, don.t write)" plugins/cogniva-dev/skills/plan-feature/SKILL.md'`
      → `1`.

- [x] **Step 6 (validate the plugin):** run `claude plugin validate .` → exits 0.

- [x] **Step 7 (commit):** `git add plugins/cogniva-dev/skills/plan-feature/SKILL.md` then
      `git commit -m "feat(plan-feature): propose cut scope at handoff instead of writing it"`

## Task 4: Thread followups through the workflow and the two execution skills

**Files:**
- Modify: `plugins/cogniva-dev/templates/execute-feature.workflow.js`
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/quick-fix/SKILL.md`

This file is pinned to LF by `.gitattributes` — do not introduce CRLF line endings.

- [x] **Step 1 (extend the task-result schema):** In
      `plugins/cogniva-dev/templates/execute-feature.workflow.js`, replace the whole
      `const TASK_RESULT = { ... }` declaration (currently ending with the line
      `}` after the `note` property) with EXACTLY:

```javascript
const TASK_RESULT = {
  type: 'object',
  additionalProperties: false,
  required: ['status', 'summary'],
  properties: {
    status: { type: 'string', enum: ['DONE', 'BLOCKED'] },
    summary: { type: 'string', description: 'One or two lines: what changed.' },
    commitSha: { type: 'string', description: 'Short SHA of the task commit, if committed.' },
    note: { type: 'string', description: 'If BLOCKED: exactly what is missing or needed.' },
    followups: {
      type: 'array',
      description: 'Backlog CANDIDATES only — never written to any BACKLOG.md by this agent. Omit or leave empty unless the task surfaced work that is genuinely not covered by this plan or an open plan folder, AND you can point at a concrete observed fact for it. Speculation and "it would be nice if" do not qualify.',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['description', 'receipt', 'strength'],
        properties: {
          description: { type: 'string', description: 'One line, as it would appear in BACKLOG.md.' },
          receipt: { type: 'string', description: 'The concrete observed fact, with a location: "same off-by-one at handler.ts:88", "blocked needing IExportPort, which the plan never defines".' },
          strength: { type: 'string', enum: ['clear', 'ambiguous'], description: 'clear = the fact is unambiguous; ambiguous = a passing observation. When unsure, use ambiguous.' },
          size: { type: 'string', enum: ['S', 'M', 'L'] },
        },
      },
    },
  },
}
```

- [x] **Step 2 (tell the task agent about it):** In the same file, in the
      `const prompt = [ ... ]` array, find the line ending
      `` `If you cannot finish cleanly, return status BLOCKED with a precise note and do NOT leave a partial commit.`, ``
      and insert this line immediately after it:

```javascript
    `NEVER write to any BACKLOG.md. If this task surfaced real work outside the plan, return it in "followups" with a concrete receipt (a located fact) — the console gates it with the user. No receipt, no followup.`,
```

- [x] **Step 3 (collect followups in the return value):** In the same file, replace
      the final `return { results, done, ... }` line with EXACTLY these two lines:

```javascript
const followups = results.flatMap(r => (r.followups || []).map(f => ({ ...f, task: r.n, subplan: r.subplan })))
return { results, done, blocked: blocked ? blocked.n : null, gateHit, allDone: !blocked && done.length === tasks.filter(t => !t.done).length, followups }
```

- [x] **Step 4 (verify LF endings and syntax):** run
      `bash -c "tr -cd '\r' < plugins/cogniva-dev/templates/execute-feature.workflow.js | wc -c"`
      → `0`, then run
      `bash -c 'node --check plugins/cogniva-dev/templates/execute-feature.workflow.js && echo SYNTAX_OK'`
      → `SYNTAX_OK`.

- [x] **Step 5 (update execute-feature's BLOCKED handling):** In
      `plugins/cogniva-dev/skills/execute-feature/SKILL.md`, find this text inside
      the Step 3 "Blocked / gate hit" bullet:

```
If a BLOCKED task surfaced leftover
  scope that won't be done here, capture it:
  `/backlog module=<Module> tier=loose src=<Feature> — <description>`.
```

      and replace it with EXACTLY:

```
If the workflow returned any
  `followups`, run the capture gate below before stopping.
```

- [x] **Step 6 (add the capture gate section):** In the same file, insert a new
      section immediately BEFORE the line `## ADRs during execution`, containing
      EXACTLY:

````markdown
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
````

- [x] **Step 7 (update quick-fix):** In
      `plugins/cogniva-dev/skills/quick-fix/SKILL.md`, find the final rule bullet:

```
- If the fix surfaces a follow-up you are NOT doing now, don't drop it — capture
  it: `/cogniva-dev:backlog module=<Module> tier=loose — <description>`. If this
  fix resolved a loose `BACKLOG.md` item, tick it and append `→ done`.
```

      and replace it with EXACTLY:

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

- [x] **Step 8 (verify all three edits):** run
      `bash -c 'grep -c "followups" plugins/cogniva-dev/templates/execute-feature.workflow.js plugins/cogniva-dev/skills/execute-feature/SKILL.md plugins/cogniva-dev/skills/quick-fix/SKILL.md'`
      → three lines, each with a count of `1` or greater.

- [x] **Step 9 (validate the plugin):** run `claude plugin validate .` → exits 0.

- [x] **Step 10 (commit):** `git add plugins/cogniva-dev/templates/execute-feature.workflow.js plugins/cogniva-dev/skills/execute-feature/SKILL.md plugins/cogniva-dev/skills/quick-fix/SKILL.md` then
      `git commit -m "feat(execute-feature): return backlog candidates as followups instead of writing them"`

## Task 5: Update easy-work-scan and explore-idea

**Files:**
- Modify: `plugins/cogniva-dev/skills/easy-work-scan/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/explore-idea/SKILL.md`

- [x] **Step 1 (easy-work-scan Step 6):** In
      `plugins/cogniva-dev/skills/easy-work-scan/SKILL.md`, find this text at the
      end of the Step 6 bullet:

```
Anything the dispatch surfaced but did not do
   goes to `/cogniva-dev:backlog`, never into prose.
```

      and replace it with EXACTLY:

```
Anything the dispatch surfaced but did not do
   is a capture CANDIDATE, not a write: drop what is already covered by an open
   item or a dispatched fix, then present the rest in the two tables from
   `CAPTURE-BAR.md` (in the `backlog` skill's directory) and write only what the
   user confirms, via `/cogniva-dev:backlog`. Nothing surviving → say nothing.
```

- [x] **Step 2 (explore-idea parking):** In
      `plugins/cogniva-dev/skills/explore-idea/SKILL.md`, find this bullet:

```
- **Park it:** drop a `/backlog` item or stub so the thread is not lost.
```

      and replace it with EXACTLY:

```
- **Park it:** drop a `/backlog` item or stub so the thread is not lost. This is
  the ONLY point at which an exploration writes to the backlog, and only because
  the user asked for it. Never capture side-ideas mid-exploration: an active
  `.explore/<slug>/` thread covers everything raised inside it (Test 1 in
  `CAPTURE-BAR.md`), and an idea you floated that the user did not engage with is
  not deferred work — it is just a thing you said.
```

- [x] **Step 3 (verify both edits):** run
      `bash -c 'grep -c "CAPTURE-BAR.md" plugins/cogniva-dev/skills/easy-work-scan/SKILL.md plugins/cogniva-dev/skills/explore-idea/SKILL.md'`
      → two lines, each with a count of `1` or greater.

- [x] **Step 4 (verify no skill still writes silently):** run
      `bash -c 'grep -rn "goes to .\`*/cogniva-dev:backlog" plugins/cogniva-dev/skills/ | wc -l'`
      → `0`.

- [x] **Step 5 (validate the plugin):** run `claude plugin validate .` → exits 0.

- [x] **Step 6 (commit):** `git add plugins/cogniva-dev/skills/easy-work-scan/SKILL.md plugins/cogniva-dev/skills/explore-idea/SKILL.md` then
      `git commit -m "feat(backlog): make easy-work-scan and explore-idea propose rather than write"`
