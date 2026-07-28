# EasyWorkScan — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/EasyWorkScan
> Tasks contain NO git worktree/branch step — execute-feature creates the worktree
> and the tasks commit on the feature branch they are already on. Never run
> git switch/checkout/branch inside a task.

**Goal:** Add an `easy-work-scan` skill to cogniva-dev that turns "scan the backlog for easy things you can tackle without me" into an approval-gated shortlist of low-involvement items, then dispatches the approved ones one at a time through quick-fix / plan-feature.

**Architecture:** New skill folder `plugins/cogniva-dev/skills/easy-work-scan/` in two layers per ADR 0014: a two-sentence frontmatter description, a SKILL.md body carrying only the flow (scope → OFFER a groom → read-only subagent scan → shortlist + disqualified tables behind one approval gate → sequential dispatch → report), and one lazy-loaded companion `EASY-WORK-CRITERIA.md` holding the five-part qualification test, the disqualification reason strings, the tag heuristics, and the routing table. The skill selects and dispatches only — `/cogniva-dev:quick-fix` (loose lines) and `/cogniva-dev:plan-feature` → `/cogniva-dev:execute-feature` (fully-specified stubs) do the actual work, unchanged. It honours ADR 0013's offer-first contract by never invoking `groom-backlog` without an explicit yes.

**Read these first:** `plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md` (item grammar and `size:`/`area:`/`src:` tags), `plugins/cogniva-dev/skills/groom-backlog/SKILL.md` (the offer-first contract and the two-table + one-gate presentation shape this mirrors), `docs/adr/0011-green-gate-is-repo-configured.md` (why an absent green gate must not disqualify everything), `docs/adr/0014-lazy-loaded-skill-companion-files.md` (the companion-file convention).

## File structure (locked)

```
plugins/cogniva-dev/skills/easy-work-scan/SKILL.md               # flow only: scope, groom offer, scan, gate, dispatch, report
plugins/cogniva-dev/skills/easy-work-scan/EASY-WORK-CRITERIA.md  # the five-part test, reason strings, tag heuristics, routing table
plugins/cogniva-dev/skills/groom-backlog/SKILL.md                # modify: name easy-work-scan as the real caller
plugins/cogniva-dev/.claude-plugin/plugin.json                   # modify: description mentions easy-work-scan
.claude-plugin/marketplace.json                                  # modify: cogniva-dev entry description mentions easy-work-scan
CLAUDE.md                                                        # modify: cogniva-dev skill list gains easy-work-scan
docs/glossary/README.md                                          # modify: add Low-involvement work entry
docs/adr/NNNN-*.md                                               # two new ADRs (numbers scanned at execution time)
```

## Candidate ADRs

### ADR-C1: Easy-work scanning is qualify-with-reasons, approval-gated, dispatch-sequential
**Provenance:** Suggested by human
The easy-work scan never starts work unprompted: a read-only pass classifies every open backlog item against a fixed test and presents the qualified shortlist — each with a one-line "why this is safe to hand off" — alongside every disqualified item and its failing criterion, behind ONE approval gate. Approved items are then dispatched ONE AT A TIME through the existing machinery (`quick-fix` for loose lines, `plan-feature` → `execute-feature` for stubs), each fully integrated before the next starts, so no two worktrees race to fast-forward the same branch. The scan selects and dispatches; it never implements, and it never grooms silently.
**Write with:** Task 3

### ADR-C2: "Low-involvement" is a five-part conjunctive test with mechanical verifiability
**Provenance:** Suggested by human
**Relitigation:** Open to discussion
An item qualifies as low-involvement only if ALL of: no pending design decision, wording unambiguous enough to act on, mechanically verifiable, small blast radius, nothing irreversible. Mechanically verifiable means the repo green gate exercises the change OR the item names its own check (command + expected output, a test, a file assertion) — per ADR 0011 an absent gate is normal, so it just shifts the burden onto the item. One failure disqualifies; there is no scoring and no benefit of the doubt, and the failing criterion is reported as the reason.
**Write with:** Task 3

## Task 1: Create the easy-work-scan skill flow (SKILL.md)

**Files:**
- Create: `plugins/cogniva-dev/skills/easy-work-scan/SKILL.md`

- [x] **Step 1 (create file):** Create `plugins/cogniva-dev/skills/easy-work-scan/SKILL.md` with EXACTLY this content:

````markdown
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
   table in `EASY-WORK-CRITERIA.md`, in shortlist order. Wait for each to reach
   `INTEGRATED` on the user's branch before starting the next — concurrent
   worktrees racing to fast-forward one branch is how `QUEUED_DIRTY` and
   conflicts happen. If an item comes back `CONFLICT`, `ERROR`, or `BLOCKED`,
   stop dispatching, report it, and ask before continuing down the list.

6. **Report.** One line per dispatched item — what it did and its integration
   status — then the close-out pointer: "validate, then
   `/cogniva-dev:cleanup-work`". Anything the dispatch surfaced but did not do
   goes to `/cogniva-dev:backlog`, never into prose.

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
````

- [x] **Step 2 (verify):** Read the file back; confirm the frontmatter has exactly `name` and `description` keys, the description is at most two sentences, and the six `## Steps` items plus the `## Rules` section are all present.
- [x] **Step 3 (validate):** `claude plugin validate .` (run at the worktree root) → expect `Validation passed`.
- [x] **Step 4 (commit):** `git add plugins/cogniva-dev/skills/easy-work-scan/SKILL.md` then `git commit -m "feat(cogniva-dev): add easy-work-scan skill flow"`.

## Task 2: Create the qualification criteria companion (EASY-WORK-CRITERIA.md)

**Files:**
- Create: `plugins/cogniva-dev/skills/easy-work-scan/EASY-WORK-CRITERIA.md`

- [x] **Step 1 (create file):** Create `plugins/cogniva-dev/skills/easy-work-scan/EASY-WORK-CRITERIA.md` with EXACTLY this content:

````markdown
# Easy-work criteria

The qualification test for `/easy-work-scan`. The item grammar lives in the
backlog skill's `BACKLOG-FORMAT.md`; this file defines what makes an item safe
to hand off without the user in the loop, why one fails, and where an approved
one goes.

## The test — all five, or it is disqualified

An item is **low-involvement** only if EVERY criterion below holds. There is no
scoring and no majority vote: one failure is a disqualification, and the failing
criterion is the reason reported to the user.

### 1. No pending design decision
The item states what to do, not what to figure out.
**Fails when:** the wording carries an open fork — which library, which UX,
which of two approaches — or a "should we" / "decide whether", or it names a
desired outcome with no mechanism.
**Reason string:** `needs a design decision — <the fork>`

### 2. Unambiguous wording
Someone who has not been in the user's head can act on it as written.
**Fails when:** the referent is unclear ("fix the dropdown" with three dropdowns
in scope), the desired end state is not stated, or the item is a symptom with no
located cause.
**Reason string:** `ambiguous — <what is unclear>`

### 3. Mechanically verifiable
The change can be proven without the user looking at anything. Two ways to
satisfy it:
- the repo green gate (`.claude/cogniva-dev/green-gate.json`) exercises the
  changed surface, or
- the item names its own check — a command with an expected output, a test to
  add, or a file assertion the executor can make.
Per ADR 0011 an absent green gate is normal, not a failure; it just shifts the
burden onto the item to carry its own check.
**Fails when:** the only proof is "look at it and see" — visual, layout, tone,
feel, or anything whose success criterion is the user's judgment.
**Reason string:** `needs your eyes — <what only you can judge>`

### 4. Small blast radius
The change is contained: a handful of files, one Module or one skill, no public
contract change, no cross-Module ripple, no dependency bump.
**Fails when:** it touches a Contract (a cross-Module interface), changes a
shared format, edits build/CI configuration, or the file list cannot be
predicted before starting.
**Reason string:** `blast radius — <what it reaches>`

### 5. Nothing irreversible
No destructive or outward-facing step: no data migration, no deletion of tracked
history, no push, no publish, no version bump the user has not offered.
**Fails when:** undoing it would take more than a `git revert`.
**Reason string:** `irreversible — <the step>`

## Tags are evidence, not gates

The `BACKLOG-FORMAT.md` tags sharpen the judgment where they exist and are never
required — most items carry none.
- `size:S` supports criterion 4; `size:L` is strong evidence against it. An
  untagged item is judged on its content, never assumed large.
- `area:` hints at the blast radius, and `area:UI` often fails criterion 3.
- `src:<Feature>` points at the plan the item was cut from — read that plan
  before judging criterion 2; scope cut from a finished design is usually
  well-specified.

Never disqualify an item merely for having no tags.

## Routing table

| Item | Qualifies when | Route |
|---|---|---|
| Loose line in a `BACKLOG.md` | all five criteria hold | `/cogniva-dev:quick-fix "<the item, restated as an instruction>"` |
| Deferred stub (`state.md` `Status: deferred`, no plan) | all five hold AND its `Depends on:` has landed AND its `backlog.md` already carries deferred scope, contracts, and acceptance criteria | `/cogniva-dev:plan-feature <Module>/<Feature>`, then `/cogniva-dev:execute-feature <Module>/<Feature>` |
| Deferred stub, thinly specified | never | disqualified: `needs a design session — stub scope is incomplete` |
| Already-closed line (`- [x]`) | never | not a candidate; closure is grooming territory |

A stub qualifies ONLY because its design thinking is already done. If
`plan-feature` nonetheless has to ask the user a design question, criterion 1 was
judged wrong: stop after the plan lands, do NOT chain `execute-feature`, and say
so — the item was not as easy as advertised.

## Dispatch order

Shortlist order IS dispatch order: loose items first (cheapest, fastest to
integrate), then stubs. Within each group, smallest blast radius first — so the
run is most-likely-to-succeed first, and an early stop leaves the most value
already landed on the user's branch.

## Reporting

- Every open item in scope appears in exactly one of the two tables. Silence
  about an item reads as "it was not there".
- A qualified item's rationale is one line naming the verification, e.g.
  "green gate proves it — `plugin validate` covers this file".
- An empty shortlist is a real result. Report it plainly and stop.
````

- [x] **Step 2 (verify):** Read the file back; confirm the five numbered criteria each carry a **Fails when:** and a **Reason string:** line, and that the `## Tags are evidence, not gates`, `## Routing table`, `## Dispatch order`, and `## Reporting` sections are all present.
- [x] **Step 3 (commit):** `git add plugins/cogniva-dev/skills/easy-work-scan/EASY-WORK-CRITERIA.md` then `git commit -m "feat(cogniva-dev): add easy-work qualification criteria"`.

## Task 3: Wire easy-work-scan into the repo surfaces + write ADRs

**Files:**
- Modify: `plugins/cogniva-dev/skills/groom-backlog/SKILL.md`
- Modify: `plugins/cogniva-dev/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `CLAUDE.md`
- Modify: `docs/glossary/README.md`
- Create: `docs/adr/NNNN-easy-work-scan-qualify-approve-dispatch.md`, `docs/adr/NNNN-low-involvement-five-part-test.md`

- [x] **Step 1 (groom-backlog — name the real caller):** In `plugins/cogniva-dev/skills/groom-backlog/SKILL.md`, under `## Called by another skill`, replace the exact substring `(e.g. a future easy-work scan)` with `` (`/cogniva-dev:easy-work-scan` does, at its Step 2) ``. Change nothing else in that file.
- [x] **Step 2 (plugin.json description):** In `plugins/cogniva-dev/.claude-plugin/plugin.json`, in the `description` value, replace the exact substring `deferred work capture and grooming (backlog, groom-backlog),` with `deferred work capture and grooming (backlog, groom-backlog), low-involvement work selection (easy-work-scan),`. Do NOT change the `version` field — the bump is offered separately at integration.
- [x] **Step 3 (marketplace.json description):** In `.claude-plugin/marketplace.json`, in the `cogniva-dev` entry's `description`, replace the exact substring `auto-doc, backlog, groom-backlog, repo-init,` with `auto-doc, backlog, groom-backlog, easy-work-scan, repo-init,`. Do NOT change the `version` field.
- [x] **Step 4 (CLAUDE.md skill list):** In `CLAUDE.md`, in the `plugins/cogniva-dev/` bullet under `## Layout`, replace the exact substring `` `groom-backlog`, `repo-init`, `` with `` `groom-backlog`, `easy-work-scan`, `repo-init`, ``.
- [x] **Step 5 (glossary):** In `docs/glossary/README.md`, insert the following entry immediately after the `## Exit verb` entry (i.e. after its `_Avoid_: resolution marker, status tag` line) and immediately before the `## Status` heading, separated by a blank line on each side:

````markdown
## Low-involvement work

A [Backlog](#backlog) item the `easy-work-scan` skill judges safe to hand off without the user in the loop: no pending design decision, unambiguous wording, mechanically verifiable, small blast radius, nothing irreversible — all five, or it is disqualified with the failing reason. Distinct from `size:S`, which measures effort, not autonomy.
_Avoid_: easy work, low-hanging fruit, quick win
````

- [x] **Step 6 (write ADR: Easy-work scanning is qualify-with-reasons, approval-gated, dispatch-sequential):** Scan `docs/adr/` for the highest existing number, increment by one, and write ADR-C1 (see `## Candidate ADRs` above) verbatim to `docs/adr/NNNN-easy-work-scan-qualify-approve-dispatch.md` per auto-doc's ADR-FORMAT — title as the `#` heading, the `**Provenance:**` line, then the body paragraph. ADR-C1 has NO relitigation line; do not add one.
- [x] **Step 7 (write ADR: "Low-involvement" is a five-part conjunctive test with mechanical verifiability):** Same scan (number = the one after Step 6's); write ADR-C2 verbatim to `docs/adr/NNNN-low-involvement-five-part-test.md`, including BOTH its `**Provenance:** Suggested by human` and `**Relitigation:** Open to discussion` lines.
- [x] **Step 8 (validate):** `claude plugin validate .` (run at the worktree root) → expect `Validation passed`.
- [x] **Step 9 (commit):** `git add plugins/cogniva-dev/skills/groom-backlog/SKILL.md plugins/cogniva-dev/.claude-plugin/plugin.json .claude-plugin/marketplace.json CLAUDE.md docs/glossary/README.md docs/adr/` then `git commit -m "docs(cogniva-dev): wire easy-work-scan into repo surfaces, add selection ADRs"`.
