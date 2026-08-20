# Capture candidates are presented in two confidence-separated tables, per ADR 0013

**Provenance:** Suggested by human
**Status:** superseded by ADR 0033 — the gate is now route-first; receipts, confidence separation, and the single gate carry forward.

Candidates are split by receipt strength — clear intent (scan-and-nod) versus ambiguous (needs a decision) — each showing its receipt, behind one gate. This extends the grooming presentation contract to capture, so a user can skim the strong set and spend attention only on the weak one; ambiguous candidates are proposed rather than suppressed, because dropping one is a keystroke and losing one is silent.
