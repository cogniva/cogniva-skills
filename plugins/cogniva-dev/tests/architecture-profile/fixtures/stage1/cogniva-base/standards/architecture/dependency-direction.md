---
description: Dependencies follow the direction the repository declares; a new dependency edge never bypasses it, and public surfaces stay pure.
---

# Dependency direction

- Follow the dependency direction the repository declares. A new dependency
  edge that bypasses it is a design departure to surface, not a detail to
  implement.
- A unit's public surface (its contracts or interface package) stays a pure
  surface: it is never where implementation lives.
