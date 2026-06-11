---
name: repo-init
description: Use when starting a brand-new .NET repo with Module (vertical slice) architecture - scaffolds git, solution, folder layout, glossary, CLAUDE.md, and the first Module
---

# Repo Init

Scaffold a new Module-architecture .NET repo. Templates live at
`<skill-base-dir>/../../templates/` (the plugin root's `templates/` folder).

## Gather first (ask the user)

1. Repo/solution name (PascalCase, e.g. `OrderHub`).
2. Hosts to create now: Web (ASP.NET Core), WPF (BlazorWebView), or both.
3. First Module name (PascalCase business capability, e.g. `Orders`).

## Steps

1. Verify the target directory is empty (or contains only `.git`). If not, stop and ask.
2. `git init` (then `git symbolic-ref HEAD refs/heads/main` if git < 2.28).
3. Copy from the plugin `templates/repo/` into the repo root:
   `CLAUDE.md`, `.gitignore`, `.editorconfig`, `.gitattributes`.
4. Copy `templates/glossary/README.md` to `docs/glossary/README.md`.
5. Create empty dirs: `docs/plans/`, `docs/superpowers/specs/`, `docs/superpowers/plans/`. Drop a `.gitkeep` file in each so git tracks them.
6. Create the solution and shared build props:

   dotnet new sln -n <RepoName> (SDK 10+ emits <RepoName>.slnx instead of .sln — fine; all dotnet sln commands work with it)

   Create `Directory.Build.props` at repo root:

   ```xml
   <Project>
     <PropertyGroup>
       <TargetFramework>net8.0</TargetFramework>
       <Nullable>enable</Nullable>
       <ImplicitUsings>enable</ImplicitUsings>
       <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
     </PropertyGroup>
   </Project>
   ```

   Note: every generated .csproj carries its own <TargetFramework> which OVERRIDES this props file — the add-module skill strips them; do the same for any project you create directly.

7. Hosts (as chosen):
   - Web: `dotnet new web -n <RepoName>.Host.Web -o src/Hosts/Web` then `dotnet sln add src/Hosts/Web`
   - WPF: `dotnet new wpf -n <RepoName>.Host.Wpf -o src/Hosts/Wpf` then `dotnet sln add src/Hosts/Wpf`
     and `dotnet add src/Hosts/Wpf package Microsoft.AspNetCore.Components.WebView.Wpf`

   After creating each host, remove the <TargetFramework> line from the Web host's .csproj so Directory.Build.props governs. EXCEPTION: keep the WPF host's own <TargetFramework> (WPF requires the -windows TFM, e.g. net8.0-windows).
8. First Module: invoke the `add-module` skill with the chosen Module name. Skip add-module's build and commit steps — repo-init runs its own build (step 9) and commit (step 11).
9. `dotnet build` - must succeed.
10. Recommend the user install this plugin in the new repo:
    `/plugin marketplace add cogniva/cogniva-skills` (or the path of your local clone) then `/plugin install cogniva-skills@cogniva`
    (enables the plan-to-html hook there).
11. Commit everything: `git add -A && git commit -m "chore: scaffold <RepoName> via cogniva-skills"`.

## Rules baked into the scaffold

Dependency rules live in the copied CLAUDE.md and the glossary - do not restate
them ad hoc; link to [Module](docs/glossary/README.md#module) and friends.
