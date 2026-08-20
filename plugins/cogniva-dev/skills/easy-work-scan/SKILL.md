---
name: easy-work-scan
description: Use when the user wants a shortlist of backlog work that can be tackled with little to no involvement from them ("scan the backlog for easy stuff", "what can you just get on with?") - a read-only scan qualifies every open item against a five-part low-involvement test and presents the shortlist, plus every disqualified item and its reason, behind one approval gate. Approved items are dispatched one at a time through quick-fix / plan-feature; the scan itself never implements anything and never grooms silently.
---

# Easy Work Scan

Turn "what can you just get on with?" into a responsible, approved shortlist. A
read-only scan qualifies every open backlog item against a fixed test, the user
approves the shortlist ONCE, and only then does work start — one item at a time,
through the existing machinery.

Invoke: `/cogniva-dev:easy-work-scan [module=<Module>]`

Read `EASY-WORK-CRITERIA.md` in this skill's directory BEFORE the scan — it is
the qualification test, the disqualification reason strings, and the routing
table. This skill selects and dispatches; it never writes feature code itself.

## Steps

1. **Scope.** Default = every backlog surface in the target repo:
   `docs/plans/BACKLOG.md`, every `docs/plans/<Module>/BACKLOG.md`, and every
   stub folder (`state.md` with `Status: deferred` and no `-plan.md`).
   `module=<Module>` narrows to that Module's file and stubs.

2. **Offer a groom — never run one silently.** Ask in one sentence: "want me to
   groom the backlog first (`/cogniva-dev:groom-backlog`)? An ungroomed backlog
   will offer up stale items as candidates." Invoke groom-backlog ONLY on a yes,
   and let it finish its own confirmation gate before scanning. Whether a groom
   is worth doing is the user's call — they know when they last ran one.

3. **Scan — one read-only subagent.** Spawn ONE general-purpose subagent with:
   the scope list, the absolute path of `EASY-WORK-CRITERIA.md` to read first,
   and an instruction to return ONLY structured records. It classifies EVERY
   open item and returns one record each: location, item text, `qualified` or
   `disqualified`, the failing criterion when disqualified, the one-line
   safety rationale when qualified, the proposed route, and the verification it
   would rely on. It edits NOTHING and starts NOTHING.

4. **Present — shortlist + everything excluded, ONE gate.**
   - **Shortlist** (qualified): numbered; item, proposed route, the verification,
     and one line of *why this is safe to hand off*.
   - **Not this pass** (disqualified): item + the single failing criterion, so
     the user can see what was considered and why it was excluded. List every
     one — a silent omission reads as "nothing else was there".
   Then ask once: run the whole shortlist, or which numbers?

   Deliver both tables as the FINAL text of the turn — a plain chat message with
   NO tool call after it, the approval question as plain text at its end. Never
   ask the gate via a question/prompt tool call in the same turn: text emitted
   before a tool call may not be shown to the user.

5. **Dispatch — approved items only, ONE AT A TIME.** Route each item per the
   table in `EASY-WORK-CRITERIA.md`, in shortlist order. Mode check: worktree
   mode is ON iff the target repo's `.claude/cogniva-dev.local.json` has
   `"worktrees": true`. Worktree mode → wait for each item to reach
   `INTEGRATED` on the user's branch before starting the next — concurrent
   worktrees racing to fast-forward one branch is how `QUEUED_DIRTY` and
   conflicts happen. Lean mode → wait for each dispatched run's final report
   on the current branch before starting the next — concurrent runs editing
   one checkout conflict just as badly. In either mode, if an item comes back
   `CONFLICT`, `ERROR`, or `BLOCKED`, stop dispatching, report it, and ask
   before continuing down the list.

6. **Report.** One line per dispatched item — what it did and, in worktree
   mode, its integration status; in lean mode, what landed on the current
   branch. Worktree mode only: end with the close-out pointer "validate, then
   `/cogniva-dev:cleanup-work`". Lean mode has no cleanup step — each run
   simply finished with its report. Anything the dispatch surfaced but did not do
   is routed, never written silently: drop what is already covered by an open
   item or a dispatched fix, then present the rest through the route-first
   gate in `CAPTURE-BAR.md` (in the `backlog` skill's directory) — deferrals
   only with a `because:` — and write only what the user confirms, via
   `/cogniva-dev:backlog`. Nothing surviving → say nothing.
   This scan never does surfaced work itself — it dispatches through
   `quick-fix` / `plan-feature`, and those runs own their own do-now gates.

## Rules

- Nothing starts before the Step 4 approval — not a worktree, not a groom, not
  a plan. The scan is read-only and the gate is mandatory.
- All five criteria must hold. A near-miss is a disqualification with a reason,
  never a judgment call in the user's favour.
- The scan never implements: `/cogniva-dev:quick-fix` and
  `/cogniva-dev:plan-feature` do the work, unchanged.
- Never groom as a silent pre-step — offer it (ADR 0013's offer-first contract).
- An empty shortlist is a real, useful answer. Say so plainly and stop; never
  relax a criterion to produce candidates.
