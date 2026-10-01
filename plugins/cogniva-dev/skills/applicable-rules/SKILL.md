---
name: applicable-rules
description: Discover the repository instruction chain, placement constraints, and relevant obligations for intended target paths before implementation. Read-only; never changes repository or lifecycle state.
---

# Applicable Rules

Use this before substantive implementation when a target repository path is
known. It is a workflow-neutral preflight: it identifies authority and reports
constraints, but does not plan, edit, create branches or worktrees, or perform
any lifecycle action.

`<plugin>` is this plugin's root (the parent of `skills/`), not the repository
being examined. `<repo>` is the target repository root.

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/resolve-applicable-rules.ps1" -Repo "<repo>" -Target "<target-path>" -Purpose "<brief requested behavior>"
```

For more than one planned path, pass a comma-separated `-Target` value (or run
the command once per path). The resolver walks from the repository root through
each existing target parent, reports all applicable `AGENTS.md` files
first-class, preserves applicable substantive `CLAUDE.md` authority, and
highlights Host and Contracts placement risks. Its machine-readable result
states the effective authority order and the AGENTS precedence rule: a
more-specific AGENTS.md adds to or explicitly overrides broader instructions,
but cannot silently weaken broader safety or architecture guardrails.

Read the reported instruction files before acting. State the intended owning
Module or layer, permitted dependency direction, and validation obligations.
If `Decision` is `REVIEW_REQUIRED`, do not derive placement or ownership
conclusions automatically. Stop before implementation and request a human
architecture decision. The conservative conflict heuristic is a review aid, not
a natural-language policy engine.

Each target also reports `ArchitectureProfile`: the profile that applies there
and the `.cogniva-profile.yml` marker it came from, or `UNDECLARED`, `NONE`,
`UNAVAILABLE` (PowerShell 7 is not installed), or `ERROR`. An `ERROR` makes that
target's decision `REVIEW_REQUIRED`. For a resolved profile's standards index, run
`pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo "<repo>" -Target "<target-path>"`
and read the standards that bear on the change.

For automation, add `-Format Json`; its output is a read-only handoff rather
than a substitute for reading the authority documents.
