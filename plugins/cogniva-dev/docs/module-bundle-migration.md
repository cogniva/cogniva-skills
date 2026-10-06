# Moving a Module bundle layout repo onto dotnet

## Who this is for

A repo laid out as `src/Modules/<Name>/`, each Module a bundle of layer
projects (the Module bundle layout that `add-module` scaffolds), that wants the
`dotnet` library profile plus its own rules. `dotnet` carries Cogniva's shared
.NET principles and the default conventions for new repos; it says nothing
about Modules. The Module bundle layout lives in a repo-owned profile that
inherits `dotnet`. See [architecture-profiles.md](architecture-profiles.md)
for how profiles, amendments and review state work.

Below, `<id>` is the repo-owned profile's id (lowercase letters, digits and
`-`), and `<plugin>` is the cogniva-dev plugin's root.

## Steps

1. **Adopt `dotnet`.**

   ```powershell
   pwsh -NoProfile -File "<plugin>/scripts/adopt-architecture-profile.ps1" -Repo . -Profile dotnet
   ```

   A Stage 1 adoption refreshes the same way. The refresh removes
   `dotnet/module-layout.md` and `dotnet/module-dependencies.md` from the
   library copy; their text is under
   [Retired Stage 1 standards](#retired-stage-1-standards-starting-text) below.

2. **Create the repo-owned profile** at `.cogniva/profiles/<id>/profile.yml`:

   ```yaml
   description: <Repo>'s Module bundle layout on dotnet.
   inherits: dotnet
   ```

3. **Declare the Modules kind** in
   `.cogniva/profiles/<id>/amendments/dotnet/project-layout.md`: that
   `src/Modules/<Name>/` is a kind holding one folder per Module (and, if the
   repo groups Modules into regions, that `src/Modules/<Region>/<Name>/` is
   also valid). Name the repo standards that govern the Module kind (step 4),
   so `add-module` can find them from the layout text.

   ```markdown
   ---
   description: <Repo> adds a Modules kind - one folder per Module under src/Modules/.
   ---

   - `src/Modules/<Name>/` is a kind: one folder per Module, holding its layer
     projects. See `<id>/module-bundle.md`, `<id>/module-edges.md` and
     `<id>/module-ui.md`.
   ```

4. **Add the repo's own standards** under `.cogniva/profiles/<id>/standards/<id>/`,
   starting from the retired text below:
   - the Module bundle (which layer projects a Module has, where hosts and
     tests live), for example `module-bundle.md`;
   - its per-layer edges (which project may reference which, inside and
     between Modules), for example `module-edges.md`;
   - the Module UI rule (what a Module's UI may reference), for example
     `module-ui.md`.

   Each needs a one-line `description:` in its frontmatter. These ids are new,
   so they go in `standards/`, not `amendments/`.

5. **Place the published-types standard on Contracts projects** with
   `.cogniva/profiles/<id>/amendments/architecture/common-and-published-types.md`:

   ```markdown
   ---
   description: <Repo>'s published types are each Module's Contracts project.
   applies-to:
     - "src/Modules/*/*.Contracts"
     - "src/Modules/*/*.Contracts/**"
   ---

   - A Module's published types live in its Contracts project.
   ```

   `applicable-rules` then warns when a change puts implementation in a
   Contracts project. If the repo uses regions, add the matching
   `src/Modules/*/*/*.Contracts` globs.

6. **Record allowed cycles** in
   `.cogniva/profiles/<id>/amendments/architecture/architecture-exceptions.md`,
   naming each pair of Modules that may reference each other and why. Point at
   `docs/architecture/allowed-cycles.txt`, the file `module-deps` reads, so the
   two stay in step. Skip this step if the repo allows no cycles.

7. **Review, then accept** every amendment against the text it changes:

   ```powershell
   pwsh -NoProfile -File "<plugin>/scripts/accept-profile-delta.ps1" -Repo . -Profile <id> -All
   ```

8. **Declare the profile.** The root `.cogniva-profile.yml` contains
   `profile: <id>`. Add a `.cogniva-profile.yml` containing `profile: none` at
   the top of every tree that is not .NET (for example `docs/` or a web
   front end).

9. **Point `AGENTS.md` at the profile.** Replace any architecture rule lines in
   `AGENTS.md` with a pointer: the rules live in `.cogniva/profiles/<id>/`,
   read with `resolve-architecture-profile.ps1 -Show <standard>`.

10. **Optionally** turn on the cycle check hook with `"moduleDepsCheck": true`
    in `.claude/cogniva-dev/policy.json`.

Check the result:

```powershell
pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo . -Target src/Modules
```

It should print `PROFILE: <id>` with no `NEEDS HUMAN REVIEW`.

## Retired Stage 1 standards (starting text)

Stage 1's `dotnet` profile carried these two standards. They describe one
repo shape, not Cogniva's shared .NET principles, so they left the library.
Copy them into the repo-owned profile's standards (step 4) and adjust them to
the repo.

### dotnet/module-layout.md

```markdown
# Module layout

- Vertical slices are **Modules** under `src/Modules/<Name>/`.
- Hosts (`src/Hosts/*`) are composition roots: each registers either the
  Application (in-process) or the Client (HTTP) implementation per Module.
- UIs are always Blazor. The same Module UI must run under a web host and a
  WPF (BlazorWebView) host - that works only if it depends on Contracts alone.
- Tests mirror modules under `tests/`.
```

### dotnet/module-dependencies.md

```markdown
# Module dependencies

- Cross-Module references go through `<Name>.Contracts` ONLY. Never reference
  another Module's Domain, Application, Infrastructure, Client, or UI.
- Per-Module dependency rules:
  - `<Name>.Contracts` -> references nothing
  - `<Name>.Domain` -> references nothing
  - `<Name>.Application` -> Domain, Contracts (implements Contracts in-process)
  - `<Name>.Infrastructure` -> Application, Domain
  - `<Name>.Client` (optional) -> Contracts (HTTP implementation)
  - `<Name>.UI` (Blazor RCL) -> Contracts ONLY
```
