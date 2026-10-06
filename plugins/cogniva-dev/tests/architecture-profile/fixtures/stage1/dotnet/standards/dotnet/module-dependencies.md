---
description: Which projects may reference which - cross-Module references go through Contracts only, plus the per-Module reference rules.
---

# Module dependencies

- Cross-Module references go through `<Name>.Contracts` ONLY. Never reference
  another Module's Domain, Application, Infrastructure, Client, or UI.
- Per-Module dependency rules:
  - `<Name>.Contracts` -> references nothing
  - `<Name>.Domain` -> references nothing
  - `<Name>.Application` -> Domain, Contracts (implements Contracts in-process)
  - `<Name>.Infrastructure` -> Application, Domain
  - `<Name>.Client` (optional) -> Contracts (HTTP implementation)
  - `<Name>.UI` (Blazor RCL) -> Contracts ONLY
