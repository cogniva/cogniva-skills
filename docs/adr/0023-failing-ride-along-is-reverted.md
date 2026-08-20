# A failing ride-along is repaired once, then reverted — it never blocks the work

**Provenance:** Suggested by agent

If the green gate is red after ride-along commits, the console makes one repair attempt; still red, it reverts every ride-along commit, re-runs the gate, and captures the items to the backlog instead. Reverting all of them and re-gating is also how attribution is decided — green after the revert means the ride-alongs were the cause, still red means an ordinary pre-existing failure. Optional work approved in passing must never hold finished work hostage.

**Amended by ADR 0032 (2026-08-20):** the landing for reverted items changed — they are re-routed at the gate (Plan next, or Defer with a `because:` reason), never captured to the backlog reason-less. The repair-once, revert-all, and attribution mechanics are unchanged.
