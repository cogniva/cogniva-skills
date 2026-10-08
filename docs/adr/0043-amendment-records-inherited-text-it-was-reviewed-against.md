# An amendment records the inherited text it was reviewed against

**Provenance:** Suggested by agent
**Relitigation:** Open to discussion

Each amendment and replacement standard carries `basis:`, a hash of the
normalised inherited text it was written against. When that text changes, the
delta is reported as needing human review and resolution carries on with it
applied; tooling never tries to infer whether the change contradicts it.
