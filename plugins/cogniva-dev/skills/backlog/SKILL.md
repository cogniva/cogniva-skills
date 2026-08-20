---
name: backlog
description: Use to capture a planned deferral - work with a stated reason not to do it now ("blocked on X", "after feature Y", a decision pending, an explicit human "later") so it is not lost. Reason-less real work is done now or routed to quick-fix / plan-feature, never parked here. Directly invokable AND the routing gate for any skill that surfaces work mid-run. Direct invocation writes immediately (a because: reason is encouraged, never demanded); skill-initiated capture is proposed and confirmed first. Lightweight, append-only, no subagents. Read with module-status / repo-status.
---

# Backlog

Park work that must WAIT somewhere durable instead of in prose or in your
head. A backlog item is a **planned deferral**: it exists only with a stated
reason not to do it now (its `because:`). Reason-less real work is done now or
handed off as a ready-to-fire plan invocation — see `CAPTURE-BAR.md`'s
route-first tests. Two tiers:

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
Run the coverage check (Test 1 in `CAPTURE-BAR.md`), then write, commit, and report. No
gate, no interrogation, no request to refine the wording. The invocation itself
is the deferral decision, so an item with no stated reason is written with
`because:human later` — then offer ONCE, in the report line, to replace that
with a specific reason. Never block a human capture on a reason. The one
exception is a tier-2 stub: confirm the tier before creating a folder.

**Skill-initiated** — you surfaced the work yourself while doing something else.
**Propose; do not write.** Read `CAPTURE-BAR.md` (lazy-loaded — do not read it
for a direct invocation of an already-covered item), route each candidate
through the tests (0–3), hold them as candidate records, and present them in the
route-first gate. Only what the user confirms is written or done.

## Inputs

- **description** — what the work is, in one line.
- **module** (optional) — the owning Module. If the item clearly belongs to one,
  use it; otherwise the item is repo-level.
- **size** (optional) — `S` | `M` | `L`.
- **src** (optional) — the `<Feature>` this was deferred from, if any.
- **tier** (optional) — `loose` | `stub`. If absent, you decide (see below).
- **because** (REQUIRED with a concrete reason for a skill-initiated
  deferral; a direct human capture that states none defaults to
  `human later` — the invocation is the deferral decision) — the reason this
  waits: blocked-on, sequenced-after, decision pending, or the user's
  "later". Written as a `because:` tag per `BACKLOG-FORMAT.md`.

## Steps

1. **Coverage check (always, both modes).** Apply Test 1 in `CAPTURE-BAR.md`: is
   this already handled by the plan being written, an open plan folder, the change
   in flight, an active exploration, or an existing open item? If yes, do NOT
   capture — say so in one line, naming what covers it, and stop.

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

3. **Pick the tier.** A one-liner or small fix → **loose**. A cohesive future
   capability with its own scope, contracts, and acceptance criteria → **stub**.
   When another skill called you with a `tier=`, honor it. A stub is a folder plus
   two files and shows up in `module-status` as a real deferred feature — confirm
   before creating one, even on a direct invocation.

4. **Resolve the write root, then the path.**

   **(a) The write root — which workspace.** Decide this BEFORE the path. Every
   item is written in **your workspace**: the worktree you are working in, when
   one is active; otherwise the checkout you were invoked from. In worktree mode
   a worktree is open for the current work — skill-initiated capture from
   `plan-feature`, `execute-feature`, or `quick-fix`, or any session with an open
   worktree on this repo — so the item is written under
   `<worktree>/docs/plans/...` and rides that worktree's existing commit; it
   never goes to the primary checkout. Only a **direct** human invocation with no
   worktree in play writes to the primary.

   **(b) The path — which file.**
   - Belongs to a Module → `docs/plans/<Module>/BACKLOG.md` (loose) or
     `docs/plans/<Module>/<Idea>/` (stub, `<Idea>` PascalCase).
   - Cross-cutting / no Module → `docs/plans/BACKLOG.md` (loose only).
   - **Lazy-create**: if `BACKLOG.md` does not exist, create it from the header in
     `BACKLOG-FORMAT.md`.

5. **Skill-initiated only — the gate.** Present every candidate in ONE pass,
   in the four route-first sections defined in `CAPTURE-BAR.md` — `## Do now —
   in this work`, `## Plan next — fire when ready`, `## Backlog — planned
   deferrals`, `## Needs a decision` — each row showing its receipt, plus the
   one-line note for anything Test 2 dropped, then ask once in
   `CAPTURE-BAR.md`'s words. Never head a table "Capture candidates": the
   user-facing noun is **backlog candidate**. Deliver it as the final text of
   the turn with no tool call after it. Nothing is written or done before the
   reply. An empty candidate set → say nothing.

6. **Write the item(s)** — confirmed candidates only, or the direct invocation.
   - **Loose:** append one `- [ ] <description>` line with optional trailing
     backtick tags (`size:`, `area:`, `src:`, `because:`) per `BACKLOG-FORMAT.md`.
     A skill-initiated deferral always carries its `because:`.
   - **Stub:** create the folder with `state.md` (`Status: deferred`) and
     `backlog.md` (a "Deferred because" line, deferred scope, contracts/requests
     to use, acceptance criteria,
     the MVP it depends on, and a one-line "expand with /cogniva-dev:plan-feature"
     pointer).

7. **Commit — direct invocation only.** A capture that lands in a tracked file
   must not be left dirty: an uncommitted `BACKLOG.md` leaves the user's tree
   dirty, and in worktree mode it blocks the next `integrate-feature` run with
   `QUEUED_DIRTY`. Commit only when both hold — mode is **direct** and tier is
   **loose** — and, in worktree mode, the write landed in the **primary
   checkout**. Any one false → no commit.
   - **Before appending**, run `git status --porcelain -- <the BACKLOG.md>`. If it
     is already dirty, those are the user's own edits: append, do NOT commit, and
     say plainly in the report that the file had pre-existing uncommitted changes
     and was left for them.
   - Otherwise commit path-scoped:
     `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/git-commit.ps1" -RepoPath <the repo root you wrote in> -Path <the BACKLOG.md> -Message "chore(backlog): <short item text>"`.
     Path-scoped is the whole point — it stages that one file and never sweeps up
     the user's other uncommitted work. Report the short SHA the script prints.
   - **Skill-initiated capture never commits.** Its write rides the caller's
     commit — in worktree mode, inside that worktree; a separate commit here
     would fragment that.
   - Tier-2 stubs are unaffected — in worktree mode they were never guard-exempt
     and are still created inside a worktree.

8. **Report** one line per item: tier, path, and the item text — plus the commit
   SHA when Step 7 committed, or a note that a pre-existing dirty file was left
   alone. No HTML, no glossary work, minimal ceremony.

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
  presents the four route-first sections there. One interruption, not two.
- **Non-interactive caller** (an `execute-feature` or `quick-fix` task agent
  inside a background Workflow) — there is nobody to ask. The agent returns
  candidates in its task result's `followups` array and writes nothing; the
  invoking console applies Test 3 and runs the gate while the work is still open
  in its workspace. A task agent never proposes a do-now itself: it cannot
  know what the console will do next, and its receipt already names the path
  criterion 1 needs.

## Rules

- Append-by-default. Never delete existing items here — promotion (ticking an
  item, flipping a stub's `Status`) is done by `plan-feature`/`quick-fix` when the
  work is picked up; closure and confirmed in-place rewording are done by
  `groom-backlog`.
- Nothing a skill decided on its own reaches a `BACKLOG.md` unconfirmed. A direct
  human invocation is already confirmed and needs no gate.
- A do-now (ride-along) is a promotion of a backlog candidate, never a
  separate species: one the user declines is re-routed at the gate (plan next
  / defer / drop) — proposing it can never lose work. This skill proposes
  routes; the calling skill does the work.
- Never demand refinement at capture time. A vague one-liner from someone
  mid-task is a good item; the tests filter for coverage, intent, and importance
  — never for wording quality.
- Keep it lightweight: one line or one small folder, then stop. This skill never
  writes feature code and never runs subagents.
- **Routing carries a commit obligation.** Captures land in your workspace — the
  worktree you are working in, when one is active; otherwise the checkout. A
  worktree open for the current work → write there; the item reaches the branch
  via the merge, like everything else. A direct human invocation with no worktree
  in play → append to the tier-1 `BACKLOG.md` (`docs/plans/BACKLOG.md`,
  `docs/plans/<Module>/BACKLOG.md`) and then commit it path-scoped yourself
  (Step 7). In worktree mode those tier-1 files are the ONLY tracked files
  captured directly in the primary checkout: they are exempt from the
  primary-edit guard, and the exemption is not a licence to leave the tree dirty
  — an exempt append nobody commits blocks the next integrate. Tier-2 stub
  creation is NOT exempt — create stubs inside a worktree (e.g. while other
  worktree work is open, or via `/cogniva-dev:quick-fix`).
