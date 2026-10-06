---
description: In .NET the adapter for an outside system is a separate project that references only its owner's projects and that system's SDK; naming is the repository's choice.
basis: 3004e246ff97
---

- In .NET the isolated unit is a separate project. It references only the
  owning unit's projects and the outside system's SDK.
- Its name and location are the repository's choice (for example
  `<Owner>.<System>` or `Connectors.<System>`).
