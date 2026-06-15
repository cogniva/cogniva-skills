# Project conventions

This repo uses Module (vertical slice) architecture. Definitions: docs/glossary/README.md.

## Architecture rules (enforced in review)

- Vertical slices are **Modules** under `src/Modules/<Name>/`.
- Cross-Module references go through `<Name>.Contracts` ONLY. Never reference
  another Module's Domain, Application, Infrastructure, Client, or UI.
- Per-Module dependency rules:
  - `<Name>.Contracts` -> references nothing
  - `<Name>.Domain` -> references nothing
  - `<Name>.Application` -> Domain, Contracts (implements Contracts in-process)
  - `<Name>.Infrastructure` -> Application, Domain
  - `<Name>.Client` (optional) -> Contracts (HTTP implementation)
  - `<Name>.UI` (Blazor RCL) -> Contracts ONLY
- Hosts (`src/Hosts/*`) are composition roots: each registers either the
  Application (in-process) or the Client (HTTP) implementation per Module.
- UIs are always Blazor. The same Module UI must run under a web host and a
  WPF (BlazorWebView) host - that works only if it depends on Contracts alone.
- Tests mirror modules under `tests/`.

## Glossary protocol

- `docs/glossary/README.md` is the shared glossary. Use its terms in every
  discussion and link them, e.g. [Module](docs/glossary/README.md#module).
- New/changed domain terms: propose the entry, get confirmation, then write it.

## Plans and specs

- Specs: `docs/superpowers/specs/` or `docs/specs/` - Plans: `docs/superpowers/plans/` or `docs/plans/`.
