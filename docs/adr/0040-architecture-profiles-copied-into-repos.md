# Architecture profiles are copied into the repo that uses them

**Provenance:** Suggested by human

The plugin's `profiles/` folder is a library: a repo adopts a profile, and every
profile it inherits from, by copying it into `.cogniva/profiles/` with
`adopt-architecture-profile.ps1`, and every tool reads only that copy. A repo's
standards therefore change only through a deliberate re-adoption that shows up as
an ordinary diff, never silently on a plugin update.
