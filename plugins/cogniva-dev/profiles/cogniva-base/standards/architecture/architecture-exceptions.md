---
description: An exception to an architecture rule is narrow, named, and recorded with its reason where the rule lives; existing code never justifies itself.
---

# Architecture exceptions

- An exception to an architecture rule names exactly what it allows (these two
  units, this one edge) and nothing wider.
- It is recorded with its reason where the rule lives: an amendment in the
  repository's own profile, or a decision record that profile points to.
- Existing code is never its own justification. Code that breaks a rule without
  a recorded exception is a departure to surface, not a precedent.
