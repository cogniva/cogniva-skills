---
description: In .NET a composition root is a runnable host project under src/Hosts/; a library that needs registration owns its Add<Name>() entry point, and hosts call it.
basis: 82c13f859092
applies-to:
  - "src/Hosts/**"
---

- In .NET a composition root is a runnable host project under `src/Hosts/`.
  Hosts may reference wiring libraries next to them.
- A library or capability that requires composition-time registration owns that
  registration entry point. In .NET the conventional public entry point is named
  `Add<Name>()`. Libraries that require no registration do not need one.
- Hosts compose by calling those entry points.
