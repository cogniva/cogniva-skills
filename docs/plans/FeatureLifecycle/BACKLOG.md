# FeatureLifecycle — Backlog

Loose & deferred work, not yet planned. Promote with /cogniva-dev:plan-feature;
trivial fixes can go straight to /cogniva-dev:quick-fix.

- [ ] plan-feature should write verification commands that can actually match the text they check — no `$`-anchored greps (the working tree is CRLF), no phrases its own replacement text wraps across a line break  `size:S` `area:tooling` `src:RideAlongCandidates`
- [ ] adr/ADR-FORMAT.md line 82 still cites "execute-feature Step 3.4" — that step is now 3.1c, so the pointer dangles  `size:S` `area:docs` `src:RideAlongCandidates`
- [ ] cleanup-worktrees.ps1's recipe commit needs `git add -f` — plain `git add` fails to close out any repo whose `docs/plans/**` is gitignored, leaving the worktree `kept`  `size:S` `area:tooling` `src:RideAlongCandidates`
