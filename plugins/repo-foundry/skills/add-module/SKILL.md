---
name: add-module
description: Use when adding a new Module (vertical slice) to an existing Module-architecture .NET repo - scaffolds Contracts/Domain/Application/Infrastructure/UI projects, optional Client, wires references and tests, updates the glossary
---

# Add Module

Add one Module named `<M>` (PascalCase, e.g. `Orders`) to an existing repo.

## Gather first (ask the user)

1. Module name `<M>`.
2. Include the optional HTTP `Client` project now? (Default: no - add it when a
   remote deployment actually exists.)
3. One-sentence description of the Module's business capability (for the glossary).

## Steps

1. Create projects (from repo root):

   dotnet new classlib -n <M>.Contracts -o src/Modules/<M>/<M>.Contracts
   dotnet new classlib -n <M>.Domain -o src/Modules/<M>/<M>.Domain
   dotnet new classlib -n <M>.Application -o src/Modules/<M>/<M>.Application
   dotnet new classlib -n <M>.Infrastructure -o src/Modules/<M>/<M>.Infrastructure
   dotnet new razorclasslib -n <M>.UI -o src/Modules/<M>/<M>.UI

   If Client requested: dotnet new classlib -n <M>.Client -o src/Modules/<M>/<M>.Client

2. Delete the template `Class1.cs` from each classlib.
3. Wire references (these ARE the dependency rules - no others allowed):

   dotnet add src/Modules/<M>/<M>.Application reference src/Modules/<M>/<M>.Domain src/Modules/<M>/<M>.Contracts
   dotnet add src/Modules/<M>/<M>.Infrastructure reference src/Modules/<M>/<M>.Application src/Modules/<M>/<M>.Domain
   dotnet add src/Modules/<M>/<M>.UI reference src/Modules/<M>/<M>.Contracts
   If Client: dotnet add src/Modules/<M>/<M>.Client reference src/Modules/<M>/<M>.Contracts

4. Add each new project to the solution explicitly (globbing like `**.csproj` is not expanded by Windows shells or `dotnet sln`): `dotnet sln add src/Modules/<M>/<M>.Contracts src/Modules/<M>/<M>.Domain src/Modules/<M>/<M>.Application src/Modules/<M>/<M>.Infrastructure src/Modules/<M>/<M>.UI` (plus `<M>.Client` if created).
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
