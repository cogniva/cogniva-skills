# Cross-host parity is the default, recorded in one parity record backed by derived checks

**Provenance:** Suggested by human

Every change to skills, hooks, scripts, templates or manifests considers both
Claude Code and Codex; a difference between them lives only in an overlay,
host metadata, a manifest or a hook input adapter, and an intentional
asymmetry is stated with its reason in `docs/host-parity.md`. That record is
the only hand-maintained inventory: the green gate derives the skill, hook and
overlay inventory from the repo and fails on anything uncovered, and a
capability is `verified` for an agent host only when a smoke record from that
host covers it. This extends ADR 0029 from packaging to policy.
