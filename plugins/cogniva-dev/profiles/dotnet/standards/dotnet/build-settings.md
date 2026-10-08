---
description: One target framework set centrally in Directory.Build.props, nullable on, warnings as errors; only a platform host overrides the target framework.
---

# Build settings

_Principle: applies to every repository on this profile._

- One target framework for the repository, set centrally in
  `Directory.Build.props` (`TargetFramework`). Projects do not repeat it.
- Nullable reference types are on (`Nullable` is `enable`) and warnings are
  errors (`TreatWarningsAsErrors` is `true`).
- A project overrides the target framework only when its platform requires it,
  such as a Windows desktop host (`<tfm>-windows`).
- The framework value itself is chosen when the repository is created; this
  standard does not fix it.
