# Cogniva-dev workflow instructions (repo-scoped)

Phase blocks that Cogniva lifecycle skills and workflow-neutral checks honour
at named phases. Resolve AGENTS.md first and fall back to CLAUDE.md only for a
phase block absent here; see `docs/strategy.md` for the convention.

## Cogniva-dev workflow instructions

### before-integrate

- If an integration changed a plugin's skills, scripts, or templates, offer
  the plugin-version bump required by the `## Rules` in CLAUDE.md while the
  worktree is still open so it can ride the same merge.
