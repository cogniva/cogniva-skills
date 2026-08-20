# Repo branch policy — requiredDevelopmentBranchPrefix in tracked policy.json

**Provenance:** Suggested by human

An optional tracked `.claude/cogniva-dev/policy.json` may set
`{"requiredDevelopmentBranchPrefix": "feature/"}`. Lean lifecycle skills validate
the current branch against it BEFORE mutating anything and stop with a clear
message on mismatch — they never auto-create or switch branches. Absent/unreadable
file = no policy, no behavior change.
