# "Low-involvement" is a five-part conjunctive test with mechanical verifiability

**Provenance:** Suggested by human

**Relitigation:** Open to discussion

An item qualifies as low-involvement only if ALL of: no pending design decision, wording unambiguous enough to act on, mechanically verifiable, small blast radius, nothing irreversible. Mechanically verifiable means the repo green gate exercises the change OR the item names its own check (command + expected output, a test, a file assertion) — per ADR 0011 an absent gate is normal, so it just shifts the burden onto the item. One failure disqualifies; there is no scoring and no benefit of the doubt, and the failing criterion is reported as the reason.
