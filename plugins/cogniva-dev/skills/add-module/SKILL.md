---
name: add-module
description: Use when adding a new Module to a repo on the Module bundle layout (src/Modules/<Name>/ with Contracts/Domain/Application/Infrastructure/UI projects, optional Client) - scaffolds the projects, wires references and tests, updates the glossary. Not for repos that follow the dotnet profile's default kind-first layout.
---

# Add Module

Add one Module named `<M>` (PascalCase, e.g. `Orders`) to a repo on the
Module bundle layout. This skill scaffolds that layout only; it is not how
projects are added to a repo that follows the `dotnet` profile's default
layout. `<plugin>` is this plugin's root (the parent of `skills/`).

## First: which layout does this repo use?

Run `pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo . -Target src/Modules`.

| Result | What to do |
|---|---|
| No `pwsh`, or `PROFILE: undeclared` | Use the steps below unchanged. |
| `PROFILE: none` or `PROFILE: error - ...` | Stop and report the reason. |
| A resolved profile | Run the same command with `-Show dotnet/project-layout.md`. If the effective text declares a `src/Modules/` kind, follow **Declared repos** below. If it does not, stop: "This repo does not use the Module bundle layout. Add projects per `dotnet/project-layout.md`." |

### Declared repos

1. Gate on the standards this change depends on:
   `pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo . -Target src/Modules -Require "dotnet/project-layout.md,dotnet/projects-and-references.md,architecture/composition-roots.md,architecture/common-and-published-types.md"`.
   Exit 3 means one of them needs human review: stop, show the
   `REQUIRE BLOCKED:` lines, and say that a human must review those standards
   and then run `accept-profile-delta.ps1` for the repo's own profile. Review
   items on other standards do not block this skill.
2. Read the effective layout text and every repo standard it names for the
   Module kind (the bundle, its edges, its UI). Re-run the `-Require` call with
   those standard ids added before writing any file; exit 3 means stop, as above.
3. Offer the layer projects the repo's standards name. The full set in the
   steps below is the default scaffold, not a requirement: the user may skip
   layers. Offer variants (for example a split UI) only if the effective text
   names them; if it is ambiguous about a variant, stop and ask.
4. Run the steps below for the selected projects only. Steps 1, 2 and 4
   create, clean up and add to the solution just the projects the user chose;
   step 3 wires only edges between chosen projects, following the repo's own
   edge standards (where they differ from the list there, the repo's
   standards win); step 5 creates `<M>.Application.Tests` only if
   Application was chosen - otherwise ask which chosen project the tests
   target, or skip tests if the user says so; step 8 names only the
   registration the chosen projects allow. In an undeclared repo the
   selected projects are always the full set.

## Gather first (ask the user)

1. Module name `<M>`.
2. Include the optional HTTP `Client` project now? (Default: no - add it when a
   remote deployment actually exists.)
3. One-sentence description of the Module's business capability (for the glossary).

## Steps

1. Create the selected projects (in an undeclared repo, all of these) from repo root:

   dotnet new classlib -n <M>.Contracts -o src/Modules/<M>/<M>.Contracts
   dotnet new classlib -n <M>.Domain -o src/Modules/<M>/<M>.Domain
   dotnet new classlib -n <M>.Application -o src/Modules/<M>/<M>.Application
   dotnet new classlib -n <M>.Infrastructure -o src/Modules/<M>/<M>.Infrastructure
   dotnet new razorclasslib -n <M>.UI -o src/Modules/<M>/<M>.UI

   If Client requested: dotnet new classlib -n <M>.Client -o src/Modules/<M>/<M>.Client

2. Delete the template Class1.cs from each classlib (e.g. rm src/Modules/<M>/<M>.Contracts/Class1.cs, repeat for Domain/Application/Infrastructure and Client if created), and remove the <TargetFramework> line from every new .csproj (including <M>.UI and the test project) so the repo's Directory.Build.props controls the target framework centrally.
3. Wire references between the selected projects (in an undeclared repo these ARE the dependency rules - no others allowed; in a declared repo, wire per the repo's edge standards instead):

   dotnet add src/Modules/<M>/<M>.Application reference src/Modules/<M>/<M>.Domain src/Modules/<M>/<M>.Contracts
   dotnet add src/Modules/<M>/<M>.Infrastructure reference src/Modules/<M>/<M>.Application src/Modules/<M>/<M>.Domain
   dotnet add src/Modules/<M>/<M>.UI reference src/Modules/<M>/<M>.Contracts
   If Client: dotnet add src/Modules/<M>/<M>.Client reference src/Modules/<M>/<M>.Contracts

4. Add each new project to the solution explicitly (only the projects you created) (globbing like `**.csproj` is not expanded by Windows shells or `dotnet sln`): `dotnet sln add src/Modules/<M>/<M>.Contracts src/Modules/<M>/<M>.Domain src/Modules/<M>/<M>.Application src/Modules/<M>/<M>.Infrastructure src/Modules/<M>/<M>.UI` (plus `<M>.Client` if created).
5. Test project:

   dotnet new xunit -n <M>.Application.Tests -o tests/Modules/<M>/<M>.Application.Tests
   dotnet add tests/Modules/<M>/<M>.Application.Tests reference src/Modules/<M>/<M>.Application
   dotnet sln add tests/Modules/<M>/<M>.Application.Tests

6. `dotnet build` - must succeed before continuing.
7. Glossary: append to `docs/glossary/README.md` (propose to the user first):

   ## <M> (Module)

   <one-sentence business capability description>. A [Module](#module); public
   surface is `<M>.Contracts`.

8. Register in Hosts: remind the user (or do it if asked) that each Host must
   register `<M>.Application` (in-process) or `<M>.Client` (HTTP) against the
   `<M>.Contracts` interfaces.
9. Commit: `git add -A && git commit -m "feat: add <M> module"`.
