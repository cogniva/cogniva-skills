---
status: accepted (stopgap — supersedable; see note)
---

# Deterministic worktree ADR rescue backstop at integration

**Context.** auto-doc's hard gate pushes the agent to write an ADR (`docs/adr/000N-*.md`)
*before* implementing — but inside an execute-feature/quick-fix run that ADR is born in
the isolated worktree, where nothing reliably commits it: the task agent stages only its
own files, the Stop hook (`auto-commit-plans.ps1`) runs against the primary checkout not
the worktree, `integrate-feature.ps1` only moves committed history, and `complete-feature`
then runs `git worktree remove` (which refuses on the dirty tree, or destroys the ADR if
forced). Whether an ADR survives depends on whether the task agent happened to `git add` it.

**Decision.** Add a deterministic, script-level backstop (`scripts/rescue-worktree-adrs.ps1`)
that does NOT depend on the model following a rule. It detects uncommitted **and** untracked
`docs/adr/**` in the worktree, auto-renumbers any file whose number collides with a different
ADR already in the primary checkout (next free number; idempotent — skips files already
present in primary), commits the rescued ADR(s) onto `feature/<slug>` so `integrate-feature.ps1`
carries them into the target as feature history, and emits JSON. It is wired into
`integrate-feature.ps1` (primary site — always runs, covers execute-feature and quick-fix,
runs before the pre-merge so the worktree is left clean) and re-run as an idempotent net in
`complete-feature` just before teardown. It is best-effort: a rescue failure never fails the
integration or the worktree removal. Never pushes to a remote; never branch-switches the
primary checkout; never overwrites an existing ADR.

**Why.** Moves the guarantee from "the agent remembered to stage the file" to "the pipeline
always carries it", at the one step (integration) that already runs for every feature and
quick-fix, with a teardown net for defence in depth.

**Note — supersedable stopgap.** This is a pragmatic patch over a known gap in the current
worktree-based lifecycle, and is explicitly REVERSIBLE. If ADRs later become control-plane
artifacts written straight to the primary checkout (like plan/state.md already are — see
docs/adr/0004), or the worktree/integration model changes, the right move is to REVISIT or
REMOVE this sweep — do not treat "the ADR sweep must exist" as a hard invariant.
