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
against all three tests, hold them as candidate records, and present them in the
three-section gate. Only what the user confirms is written or done.

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

2. **Skill-initiated only — qualify intent, then test for a ride-along.** Apply
   Test 2 in `CAPTURE-BAR.md`. Declined or raised-and-dropped → nothing. Otherwise
   build a candidate record with its receipt and a `clear` / `ambiguous` strength.
   Then apply Test 3 to every `clear` candidate: is doing it now, as part of the
   current work, cheaper than doing it later? Passing candidates get a `rideAlong`
   field; the rest stay plain backlog candidates. Hold them all for the gate and do
   not touch any file yet. This skill never *performs* a ride-along — the calling
   skill does that work in its own worktree — and never offers one from inside work
   that was itself a ride-along (depth-1).

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
   the three sections defined in `CAPTURE-BAR.md` — `## Ride-alongs — do now, in
   this work`, then `## Backlog candidates` with its `### Clear intent` and
   `### Needs a decision` tables — each row showing its receipt, then ask once in
   `CAPTURE-BAR.md`'s words. Never head a table "Capture candidates": the
   user-facing noun is **backlog candidate**. Deliver it as the final text of the
   turn with no tool call after it. Nothing is written or done before the reply. An
   empty candidate set → say nothing.

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
  presents the three sections there. One interruption, not two.
- **Non-interactive caller** (an `execute-feature` or `quick-fix` task agent
  inside a background Workflow) — there is nobody to ask. The agent returns
  candidates in its task result's `followups` array and writes nothing; the
  invoking console applies Test 3 and runs the gate while its worktree is still
  open. A task agent never proposes a ride-along itself: it cannot know what the
  console will do next, and its receipt already names the path criterion 1 needs.

## Rules

- Append-by-default. Never delete existing items here — promotion (ticking an
  item, flipping a stub's `Status`) is done by `plan-feature`/`quick-fix` when the
  work is picked up; closure and confirmed in-place rewording are done by
  `groom-backlog`.
- Nothing a skill decided on its own reaches a `BACKLOG.md` unconfirmed. A direct
  human invocation is already confirmed and needs no gate.
- A ride-along is a promotion of a backlog candidate, never a separate species: one
  the user declines falls through to the backlog untouched. This skill proposes
  ride-alongs; the calling skill does the work.
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
