# Placement warnings come from the resolved profile

**Provenance:** Suggested by agent
**Relitigation:** Open to discussion

applicable-rules raises a placement warning for a path only when a standard's
`applies-to` globs match it in the path's resolved architecture profile, and a
review item stops preflight only for the targets whose matched standards it
affects. Undeclared paths keep the old path heuristics, so a repository that
declares nothing sees no change.
