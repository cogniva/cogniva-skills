---
description: Where Modules, Hosts, UIs and tests live in a .NET Module-architecture repo.
---

# Module layout

- Vertical slices are **Modules** under `src/Modules/<Name>/`.
- Hosts (`src/Hosts/*`) are composition roots: each registers either the
  Application (in-process) or the Client (HTTP) implementation per Module.
- UIs are always Blazor. The same Module UI must run under a web host and a
  WPF (BlazorWebView) host - that works only if it depends on Contracts alone.
- Tests mirror modules under `tests/`.
