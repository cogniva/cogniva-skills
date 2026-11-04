# Smoke records

One file per real smoke run of the cogniva plugins on one agent host and
surface, named `<YYYY-MM-DD>-<claude-code|codex>-<cli|vscode|desktop>.md`
(add `-2`, `-3` for a repeat on the same day). `scripts/check-host-parity.ps1`
reads the header lines, so they come first, one per line, exactly like this:

    # Smoke record <record-id>
    Agent host: Claude Code | Codex
    Agent host version: <version string>
    Surface: CLI | VS Code | Desktop
    OS: Windows 11 <build>
    Plugin versions: cogniva-dev <x.y.z>, cogniva-skills <x.y.z>
    Plugin source: <installed marketplace | local marketplace from <path> @ <short sha>>
    Date: <YYYY-MM-DD>
    Covers: <comma-separated docs/host-parity.md row IDs this record supports>

Then `## Scenarios`, a table `| Scenario | Result | Assertion output | Notes |`
with Result `pass`, `fail` or `not-run`, and `## Observations` (free bullets:
diagnostic answers, approval and trust prompts, surprises). A record supports
`verified` only for the rows its `Covers:` lists and only when no scenario row
is `fail`. It counts as fresh while its cogniva-dev major.minor matches the
current plugin version; an older record makes the checker warn.
