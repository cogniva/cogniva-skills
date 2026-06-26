# Per-script, version-glob permission allowlisting for cogniva-dev tooling

**Context.** cogniva-dev skills shell out to bundled PowerShell scripts from the
plugin cache (`.../cogniva-dev/<version>/scripts/...`). Permission allow rules
that named these scripts hardcoded the version segment (`0.1.0`), so every plugin
bump silently broke the rules and re-introduced prompts. A blanket
`Bash(powershell ... -File:*)` runner would dodge both problems but allow *any*
script with *any* args.

**Decision.** Allowlist each cogniva-dev script **individually by absolute path**,
and write the cache path with a **glob on the version segment**
(`.../cogniva-dev/*/scripts/parse-plan-tasks.ps1`) rather than a fixed version.
We deliberately do **not** ship or rely on a generic `-File:*` runner wildcard.

**Why.** Per-script rules keep the executable surface narrow (only our reviewed
scripts run unprompted) and match the existing settings pattern; the version glob
makes those rules survive plugin version bumps, which was the actual recurring
breakage. The narrower surface was chosen over the convenience of a blanket runner.
