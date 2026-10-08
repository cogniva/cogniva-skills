---
description: Default layout for new repos - the first folder under src/ names a project's kind, src/Hosts/ is the one fixed kind, and projects and shared code appear only when needed.
---

# Project layout

_Default convention for new repositories. A repository may change it with an amendment in its own profile._

- No project shape or bundle of projects is mandatory. A project is created
  only when it is needed.
- Shared code is extracted only when there is demonstrated reuse and a clear
  shared owner. A second occurrence is evidence to consider extraction, not an
  automatic trigger. Avoid speculative shared projects.
- The first folder under `src/` names a project's kind: `src/<Kind>/<Project>/`.
  `src/Hosts/` is the one fixed kind; the repository's glossary or its own
  profile defines the rest.
- Tests mirror `src/` under `tests/`.
- One solution file (`.slnx`) at the repository root.
