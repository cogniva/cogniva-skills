# Architecture-dependent changes stop only on review items they depend on

**Provenance:** Suggested by agent
**Relitigation:** Open to discussion

A skill that makes an architecture-dependent change passes the standards it
depends on to the resolver's `-Require`, which exits 3 when any of them needs
human review, and it stops then and only then. Review items on other standards
never block it, so one stale amendment cannot halt unrelated work.
