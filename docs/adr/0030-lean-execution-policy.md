# Lean execution policy — commits=none + plan=ephemeral defaults, READY FOR REVIEW finish

**Provenance:** Suggested by human

Lean-mode runs default to `commits=none` and `plan=ephemeral` (plan in gitignored
`.plans-staging/`, ignored via `.git/info/exclude`, checkbox resume preserved) and
end with the detailed `READY FOR REVIEW` handoff — no integration, no push.
`commits=none|final` are rejected loudly in worktree mode because integration is a
fast-forward of commits; worktree mode keeps per-task commits and persisted plans
unchanged.
