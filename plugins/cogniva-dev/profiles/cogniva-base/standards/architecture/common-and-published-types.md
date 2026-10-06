---
description: Who owns the types other units use - published types belong to their publisher, common types to a small unit that depends on no owning unit; neither holds implementation.
---

# Common and published types

- Types a unit publishes for others to use are owned by that unit and change
  with it. Consumers depend on the published types, never on the unit's
  implementation.
- Types every unit may use live in a small, slow-changing common unit that
  references no owning unit.
- A published or common surface holds no implementation: no persistence,
  orchestration, or domain behaviour lives there.
