# Candidate ADRs live in the plan; concrete ADRs are written at execution

**Provenance:** Suggested by human
**Relitigation:** Compelling reasons only

plan-feature and quick-fix hold ADR-worthy decisions as candidates and confirm them
with a human before handoff; the concrete `docs/adr/` file is written by
execute-feature (or the quick-fix workflow) when it finishes the task the candidate
is attached to. This keeps ADR creation gated on confirmation while tying each record
to the work that realizes it.
