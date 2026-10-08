# Glossary

One agreed meaning per domain term. Reference these in every discussion; propose new entries as terms emerge.

## Host

A runnable project under `src/Hosts/` (a web app, or a WPF app with BlazorWebView), and the place where the application is wired together: its composition root. A Host composes libraries by calling their registration entry points (`Add<Name>()`) and holds no behaviour of its own; see [composition roots](../../.cogniva/profiles/cogniva-base/standards/architecture/composition-roots.md).
_Avoid_: app shell, launcher

## Common types

A small, slow-changing project of types used across the codebase. It references no project that owns behaviour, so anything may depend on it. It is an ordinary referenced project, not a Visual Studio Shared Project (`.shproj`) or linked source; see [common and published types](../../.cogniva/profiles/cogniva-base/standards/architecture/common-and-published-types.md).
_Avoid_: shared types, shared project, utilities
