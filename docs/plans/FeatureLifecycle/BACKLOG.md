# FeatureLifecycle — Backlog

Loose & deferred work, not yet planned. Promote with /cogniva-dev:plan-feature;
trivial fixes can go straight to /cogniva-dev:quick-fix.

- [ ] plan-feature should write verification commands that can actually match the text they check — no `$`-anchored greps (the working tree is CRLF), no phrases its own replacement text wraps across a line break  `size:S` `area:tooling` `src:RideAlongCandidates`
- [ ] adr/ADR-FORMAT.md line 82 still cites "execute-feature Step 3.4" — that step is now 3.1c, so the pointer dangles  `size:S` `area:docs` `src:RideAlongCandidates`
- [ ] cleanup-worktrees.ps1's recipe commit needs `git add -f` — plain `git add` fails to close out any repo whose `docs/plans/**` is gitignored, leaving the worktree `kept`  `size:S` `area:tooling` `src:RideAlongCandidates`
- [ ] Fix `git-commit.ps1` so a message containing `"` survives the `powershell -File` hop (passing arbitrary multi-line messages is the script's whole purpose; today the child sees the message split into stray positional args), THEN wire all five `plugins/cogniva-dev/tests/*/*.tests.ps1` suites into `.claude/cogniva-dev/green-gate.json` — git-commit is the last red suite and nothing runs any of them today  `size:M` `area:tooling` `src:LeanWorktreeSplit`
- [ ] Guard hooks may fail open under 8.3 short paths: `rev-parse --absolute-git-dir` returns the long form while `--git-common-dir` can resolve short, so the linked-worktree compare in guard-primary-edit.js:62 / guard-primary-git.js:58 / nudge-backlog-commit.js:59 mismatches and a genuine primary checkout is treated as a worktree (pre-existing, not introduced by the lean/worktree split; only ever reproduced in a synthetic short-name harness, never in normal use)  `size:S` `area:tooling` `src:LeanWorktreeSplit`
