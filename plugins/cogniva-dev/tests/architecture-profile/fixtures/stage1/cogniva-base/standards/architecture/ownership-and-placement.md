---
description: Every piece of substantive behaviour has one named owner; decide the owner before placing code, and stop when it is unclear.
---

# Ownership and placement

- Substantive behaviour - domain rules, persistence, evaluation, orchestration,
  and reusable logic - belongs to exactly one owning unit (a Module, package, or
  layer, as the repository defines them). Name that owner before placing code.
- A path suggested by a prompt or a plan is never enough to override a
  repository placement rule.
- When the owner is unclear, or two applicable rules disagree about it, stop and
  ask for a human architecture decision instead of choosing one.
