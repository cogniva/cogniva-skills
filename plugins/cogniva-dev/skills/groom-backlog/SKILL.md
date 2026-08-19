---
name: groom-backlog
description: Use to groom the backlog - an evidence-gathering scan proposes closures (already-done, obsolete, superseded, duplicate) for loose BACKLOG.md items and deferred stubs, and the user confirms everything once before any edit happens. Deep pass (still-wanted?, merge/split, tier/size review) is opt-in; other skills OFFER a groom before backlog-driven work, never run it silently.
---

# Groom Backlog

Reconcile an aging backlog with reality. A read-only scan gathers evidence, the
verdicts are presented in two confidence-separated tables, the user confirms
ONCE, and only then are edits made — using the exit verbs defined in the backlog
skill's `BACKLOG-FORMAT.md`.

Invoke: `/cogniva-dev:groom-backlog [module=<Module>] [deep]`

Read `GROOMING-CRITERIA.md` in this skill's directory BEFORE the scan — it is
the verdict catalog, the evidence each verdict requires, and the edit mechanics.
Do NOT read `DEEP-GROOM.md` unless the deep pass is actually requested (Step 5);
it is deliberately lazy-loaded so ordinary sessions never pay for it.

## Steps

1. **Scope.** Default = every backlog surface in the target repo:
   `docs/plans/BACKLOG.md`, every `docs/plans/<Module>/BACKLOG.md`, and every
   stub folder (`state.md` with `Status: deferred` and no `-plan.md`).
   `module=<Module>` narrows to that Module's file and stubs.

2. **Scan — one read-only subagent.** Spawn ONE general-purpose subagent with:
   the scope list, the absolute path of `GROOMING-CRITERIA.md` to read first,
   and an instruction to return ONLY structured verdicts. The subagent
   inventories every OPEN item, gathers receipts (git log, plan folders and
   their `state.md` statuses, the code itself), and returns one record per
   finding: location, item text, verdict, proposed exit verb + annotation,
   receipt, and confidence (`confirmed` = verifiable receipt, `inferred` =
   judgment call). It edits NOTHING. Items with no finding are not reported.

3. **Present — two tables + flags, ONE gate.**
   - **Table 1 — receipt-backed** (confidence `confirmed`): numbered; item,
     verdict, receipt. The user should be able to scan and nod.
   - **Table 2 — needs a decision** (confidence `inferred`): numbering
     continues from Table 1; item, proposed verdict, the reasoning, and the
     open question (e.g. which of a conflicting pair survives).
   - **Flags — no edit proposed:** `actionable-now` items (dependency landed —
     point at `/cogniva-dev:plan-feature` or `/cogniva-dev:quick-fix`) and
     `cryptic` items (ask the user what they meant).
   Then ask once: apply Table 1 as-is? Table 2 by number. Nothing is edited
   before this reply.

   Deliver the tables + flags as the FINAL text of the turn — a plain chat
   message with NO tool call after it, the confirmation question as plain text
   at its end. Never ask the gate via a question/prompt tool call in the same
   turn: text emitted before a tool call may not be shown to the user.

4. **Apply — only what was confirmed.** Follow the edit mechanics in
   `GROOMING-CRITERIA.md`: tick-and-annotate loose lines, flip stub `state.md`
   statuses, reword items in place where that was the confirmed verdict, and
   add remainder/merged items via `/cogniva-dev:backlog`. Grooming edits only
   `BACKLOG.md` files and plan stubs, and it edits them in your workspace — the
   worktree you are working in, when one is active; otherwise the checkout. In
   worktree mode those edits follow the same tier-1 / worktree rules the backlog
   skill states: loose `BACKLOG.md` edits are exempt from the primary-edit guard
   (direct); stub `state.md` edits are NOT — batch them through ONE
   `/cogniva-dev:quick-fix`. Report one line per applied verdict.
   If the directly-edited backlog file(s) are git-tracked and left uncommitted,
   OFFER to commit them — never auto-commit — suggesting a one-line
   message, e.g. `chore(backlog): groom <scope> — close N items`.

5. **Deep pass — opt-in only.** If invoked with `deep`, or the user asks after
   seeing the standard results, read `DEEP-GROOM.md` and follow it. Otherwise,
   when the standard pass suggests restructuring would pay (many survivors,
   several near-miss duplicates), offer it in one sentence and stop.

## Called by another skill

A skill that wants a groomed backlog (`/cogniva-dev:easy-work-scan` does, at its Step 2) must OFFER
the groom — "want me to groom the backlog first?" — and invoke
`/cogniva-dev:groom-backlog [module=<Module>]` only on a yes. Never auto-groom
as a silent pre-step: whether a groom is worth doing is the user's call (they
know when they last ran one).

## Rules

- No edit of any kind before the Step 3 confirmation — the scan is read-only
  and the gate is mandatory even for "obviously done" items.
- Every closure written to a file carries its receipt in the annotation.
- Append-by-default; in-place rewording only as a confirmed verdict; NEVER
  delete or reorder lines; never delete a stub folder.
- Grooming closes and reconciles items only — actually starting surviving work
  (plan-feature / quick-fix) stays with the user.
- Keep it lean: no glossary work, no version bumps, no code changes.
