# A worktree with no validation gate closes itself out

**Provenance:** Suggested by agent (confirmed by human, 2026-07-31)

`plan-feature` closes out its own worktree immediately after a successful
integrate, rather than leaving it `cleanupable` for a later
`/cogniva-dev:cleanup-work`. The cleanupable-await-validation handshake exists so
the user can *run* code before the worktree is destroyed; a plan is a markdown file
that integrate has already fast-forwarded onto their branch, so there is nothing to
validate and the worktree is dead on arrival. Leaving it alive leaked worktrees
across session boundaries — `cleanup-work` is scoped to the session that created
them — and, because plan-feature and execute-feature derive the same slug and
therefore the same worktree path and branch, let execute-feature silently reuse a
stale planning worktree whose ledger record still read `cleanupable`.

**Consequences.** A `QUEUED_DIRTY` integrate is the one case the worktree survives:
it stays `cleanupable`, and `/cogniva-dev:cleanup-work` or
`/cogniva-dev:cleanup-allwork` retries it later. Any future skill that produces only
documents should follow the same rule — the handshake is for work the user must
execute in order to judge it.
