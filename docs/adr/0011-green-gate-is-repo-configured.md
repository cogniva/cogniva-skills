# The green gate is repo-configured via `.claude/cogniva-dev/green-gate.json`

**Provenance:** Suggested by human

execute-feature and quick-fix no longer hardcode any build/test command; they run the
ordered `commands` in `.claude/cogniva-dev/green-gate.json` (each must exit 0) before
integrating. A repo with no such file has its gate **skipped** with a one-line note
rather than failing or falling back to a default — absence is expected for docs-only
or early-stage repos, so a missing gate must never become a nuisance.
