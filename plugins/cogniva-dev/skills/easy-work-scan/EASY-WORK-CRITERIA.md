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
