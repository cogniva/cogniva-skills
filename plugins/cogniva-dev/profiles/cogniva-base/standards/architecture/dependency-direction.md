---
description: Dependencies follow the direction the repository declares, a new edge never bypasses it, and the graph between owning units has no cycles.
---

# Dependency direction

- Follow the dependency direction the repository declares. A new dependency
  edge that bypasses it is a design departure to surface, not a detail to
  implement.
- The dependency graph between owning units is acyclic. A cycle is allowed only
  as a recorded exception (`architecture/architecture-exceptions.md`).
