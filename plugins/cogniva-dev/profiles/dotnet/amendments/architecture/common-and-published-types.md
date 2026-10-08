---
description: In .NET common and published types are projects; a common-types project references no owning project, and published types live in a project the publisher owns.
basis: 164652bcb8be
---

- In .NET common types and published types are projects.
- A common-types project references no project that belongs to an owning unit.
- Published types live in a project owned by the publishing unit. Where those
  projects sit is the repository's decision, so this standard declares no
  `applies-to`; a repository's own profile can add one.
