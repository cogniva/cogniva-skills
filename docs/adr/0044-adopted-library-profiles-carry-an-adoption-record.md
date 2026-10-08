# Adopted library profiles carry an adoption record; adopt never writes repo-owned profiles

**Provenance:** Suggested by agent
**Relitigation:** Open to discussion

adopt writes `.cogniva/adopted/<id>.yml` (source, plugin version, content hash)
beside each library profile it copies, so a refresh can tell a library update
(refreshed cleanly) from a local edit (blocked: the change belongs in a
repo-owned profile). A profile without a record is repo-owned and adopt never
writes it. Amends ADR 0040.
