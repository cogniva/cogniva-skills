# Explicit-only invocation metadata only where no skill routes in

**Provenance:** Suggested by human

A lifecycle entry skill that no other skill dispatches or offers to run
carries both `disable-model-invocation: true` (Claude Code) and
`agents/openai.yaml` `policy.allow_implicit_invocation: false` (Codex), always
together, and `check-host-parity.ps1` fails if only one is present. Skills
that other skills route into or offer (quick-fix, plan-feature, backlog, adr,
glossary, groom-backlog, easy-work-scan, applicable-rules, gate-check) stay
model-invocable and state their explicit-start rule in their description, so
approved skill-to-skill dispatch keeps working on both agent hosts.
