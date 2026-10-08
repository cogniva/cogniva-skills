---
name: repo-init
description: Use when starting a brand-new .NET repo - scaffolds git, the solution, Directory.Build.props, the chosen hosts, AGENTS.md and a seed glossary, and adopts and declares the dotnet architecture profile
---

# Repo Init

Scaffold a new .NET repo on the `dotnet` architecture profile: the minimal
skeleton its default conventions describe, and nothing speculative. Templates
live at `<skill-base-dir>/../../templates/` (the plugin root's `templates/`
folder); `<plugin>` below is that plugin root.

## Gather first (ask the user)

1. Repo/solution name `<Repo>` (PascalCase, e.g. `OrderHub`).
2. Hosts to create now: Web (ASP.NET Core), Desktop (WPF + BlazorWebView), or both.
3. Target framework: the template's default (`net10.0`, in
   `templates/repo/Directory.Build.props`) unless the user passes `tfm=<tfm>`.
4. Say that repo-init adopts the `dotnet` architecture profile and declares it
   at the repo root, and that they can opt out.

repo-init creates no first unit, shared-types project, engine or adapter: under
the profile, a project is created only when it is needed.

## Steps

1. Verify the target directory is empty (or contains only `.git`). If not, stop and ask.
2. Check the SDK before writing anything: run `dotnet --list-sdks`. With no
   `global.json` (repo-init never writes one), every `dotnet` command uses the
   newest listed SDK, so check that one. It must satisfy both:
   - its major version is at least the target framework's major version (the
     `10` in `net10.0`), so it can build that framework; and
   - it is 9.0.200 or later, so it can write the `.slnx` solution the
     profile requires.

   If either fails, stop with: "The newest installed .NET SDK (<version>)
   cannot scaffold this repo: it needs SDK <major> or later to build <tfm>, and
   9.0.200 or later for a .slnx solution. Install a newer SDK." An older
   `tfm=` (e.g. .NET 8) is fine when a newer SDK is installed: SDK 10 builds
   older target frameworks too.
3. `git init` (then `git symbolic-ref HEAD refs/heads/main` if git < 2.28).
4. Copy the whole plugin `templates/repo/` folder into the repo root:
   `AGENTS.md` (the canonical instructions), `CLAUDE.md` (exactly `@AGENTS.md`),
   `Directory.Build.props`, `docs/glossary/README.md`, `.gitignore`,
   `.editorconfig`, `.gitattributes`, and the whole `.claude/` folder. The
   tracked `.claude/cogniva-dev/` directory is repo **config**
   (`green-gate.json`), NOT a mode switch. Lean mode is the default - skills
   work directly on the checkout. Worktree mode (isolated-worktree execution +
   the `guard-primary-edit` / `guard-primary-git` guards) is a per-clone
   opt-in: an untracked `.claude/cogniva-dev.local.json` containing
   `{ "worktrees": true }`; absent/false/unreadable means lean.
   `.claude/settings.json` carries no unconditional branch-switch denies. An
   optional `.claude/cogniva-dev/policy.json` can require a development-branch
   prefix in lean mode (see the template README); it is absent by default. The
   `.gitignore` already ignores the AI's scratch dirs (`.explore/`,
   `.plans-staging/`). (The guards require `node` on PATH; without it they fail
   open - allow.)
5. If the user passed `tfm=`, replace the `<TargetFramework>` value in the
   copied `Directory.Build.props`.
6. Create `docs/plans/` with a `.gitkeep` file so git tracks it.
7. `dotnet new sln -n <Repo> --format slnx` (always ask for `.slnx` explicitly;
   the default format differs between SDKs). Every `dotnet sln` command works
   with it.
8. Hosts, as chosen. Each lives in `src/Hosts/<Repo>.<Host>/`:
   - Web: `dotnet new web -n <Repo>.Web -o src/Hosts/<Repo>.Web`; delete the
     `<TargetFramework>` line from `src/Hosts/<Repo>.Web/<Repo>.Web.csproj` so
     `Directory.Build.props` governs; `dotnet sln add src/Hosts/<Repo>.Web`.
   - Desktop: `dotnet new wpf -n <Repo>.Desktop -o src/Hosts/<Repo>.Desktop`;
     set its `<TargetFramework>` to `<tfm>-windows` (a platform host is the one
     allowed override);
     `dotnet add src/Hosts/<Repo>.Desktop package Microsoft.AspNetCore.Components.WebView.Wpf`;
     `dotnet sln add src/Hosts/<Repo>.Desktop`.

   `tests/` mirrors `src/` as projects appear; create no test project now.
9. Architecture profile, unless the user opted out:
   - With `pwsh` on PATH: run
     `pwsh -NoProfile -File "<plugin>/scripts/adopt-architecture-profile.ps1" -Repo . -Profile dotnet`,
     then write `.cogniva-profile.yml` at the repo root containing
     `profile: dotnet`, then confirm with
     `pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo . -Target src -Require "dotnet/project-layout.md,dotnet/build-settings.md,architecture/composition-roots.md"`:
     it must exit 0 and print `PROFILE: dotnet` with no `NEEDS HUMAN REVIEW`.
     (A fresh adoption always passes; the `-Require` call keeps repo-init
     consistent with the other skills that change architecture.)
   - Without `pwsh`: write neither. Print both commands and the one-line
     marker for the user to run once PowerShell 7 is installed. A marker
     without an adopted profile would make every path an ERROR.
10. `dotnet build` - must succeed.
11. Recommend the user install this plugin in the new repo:
    `/plugin marketplace add cogniva/cogniva-skills` (or the path of your local clone) then `/plugin install cogniva-skills@cogniva`.
12. Commit everything: `git add -A && git commit -m "chore: scaffold <Repo> via cogniva-skills"`.

## Rules baked into the scaffold

The architecture rules live in the adopted profile under `.cogniva/profiles/`.
`AGENTS.md` points to them and states none itself. Do not restate them ad hoc;
link glossary terms such as [Host](docs/glossary/README.md#host).
