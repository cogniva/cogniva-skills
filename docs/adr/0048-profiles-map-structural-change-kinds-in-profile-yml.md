# Profiles map structural change kinds to the standards they require in profile.yml

**Provenance:** Suggested by agent

A profile lists change kinds (`structure-kinds`), the detectors it selects
(`structure-detectors`) and the standards each kind requires
(`structure-requires: "<kind> <standard id>"`) in its `profile.yml`. These
lists add up down the inheritance chain, root first, and a child removes an
inherited pair with `structure-requires-dropped`. The mapping is kept out of
standard frontmatter because frontmatter is part of the text an amendment's
`basis` hashes: changing the list there would make every amendment of that
standard STALE.
