# ADR numbering stays scan-and-increment at write time

**Provenance:** Suggested by agent
**Relitigation:** Open to discussion

ADR numbers are assigned by scanning `docs/adr/` for the highest existing number at
the moment the file is written; rare collisions from ADRs written in parallel
worktrees are resolved as ordinary merge conflicts rather than pre-reserving numbers,
which keeps the existing 0001-style convention and cross-references intact.
