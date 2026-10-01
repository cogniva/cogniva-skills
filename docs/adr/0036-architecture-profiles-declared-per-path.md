# Architecture profiles are declared per path, never inferred into place

**Provenance:** Suggested by human

A path's architecture profile comes from, in order: an explicit choice for the
current run, the nearest `.cogniva-profile.yml` marker above it, then the
repo-root marker. Tools may suggest a profile when none is declared but never
apply or save one on their own, and targets that resolve to different profiles
are reported rather than merged, because architectural intent is a human decision.
