# New scripts target PowerShell 7

**Provenance:** Suggested by human

New scripts in this repo, in the plugin's `scripts/` and the repo's own, assume
PowerShell 7 (`pwsh`); existing Windows PowerShell 5.1 scripts stay as they are
until deliberately migrated. Where 5.1 code needs a new script it runs it as a
separate `pwsh` process rather than loading it, and degrades visibly when `pwsh`
is absent.
