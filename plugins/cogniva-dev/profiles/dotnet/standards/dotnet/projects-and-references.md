---
description: Projects are the unit of compile-time dependency; the ProjectReference graph is the one internal dependency graph tooling reads, and any other coupling must be explicit.
---

# Projects and references

_Principle: applies to every repository on this profile._

- A project is the unit of compile-time dependency. The `ProjectReference`
  graph is the canonical graph of internal project-to-project compile-time
  dependencies, and the one dependency tooling reads.
- It is not the whole architecture graph. Other coupling - linked source
  (`<Compile Include="..." Link="..." />`), internal packages, reflection or
  assembly scanning, shared files, runtime protocol contracts - must be explicit
  where it exists, and may need separate analysis.
- References point in the direction the repository declares.
- Nothing references a runnable host project except that host's own tests.
