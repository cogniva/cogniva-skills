---
description: Every piece of substantive behaviour has one owning unit, as the repository defines its units; name the owner before placing code, and stop when it is unclear.
---

# Ownership and placement

- Substantive behaviour - domain rules, persistence, evaluation, orchestration,
  and reusable logic - belongs to exactly one owning unit, as the repository
  defines its units (its glossary or its own profile names them). Name that
  owner before placing code.
- A path suggested by a prompt or a plan is never enough to override a
  repository placement rule.
- When the owner is unclear, or two applicable rules disagree about it, stop and
  ask for a human architecture decision instead of choosing one.
