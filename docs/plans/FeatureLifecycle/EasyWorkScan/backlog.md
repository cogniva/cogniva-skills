# EasyWorkScan — Backlog (deferred)

**Depends on:** FeatureLifecycle/BacklogGrooming (the groom-backlog skill must land first — an easy-work scan over an ungroomed backlog surfaces stale work)

## Deferred scope
- A skill (working name: easy-work-scan) that scans the open backlog for items doable with little to no user involvement, so the user can say "tackle the easy stuff" and get a sane, responsible selection.
- Defines what "little to no involvement" means operationally: no design decisions pending, no ambiguity in the item wording, testable without manual validation, small blast radius, no ⛔-style irreversible steps.
- OFFERS a groom-backlog pass first (never runs it silently — the user knows if they groomed yesterday), then proposes a candidate list with per-item rationale for the user to approve before any work starts.
- Approved items route through existing machinery: quick-fix for loose items, plan-feature/execute-feature for stubs.

## Contracts / requests to use
- /cogniva-dev:groom-backlog (offer-first pre-step)
- /cogniva-dev:quick-fix and /cogniva-dev:plan-feature (execution routes)
- BACKLOG-FORMAT.md item grammar (size:/area:/src: tags feed the selection heuristics)

## Acceptance criteria
- Given a groomed backlog, produces a shortlist of low-involvement items with a one-line "why this is safe to hand off" per item.
- Never starts work without explicit user approval of the shortlist.
- Items it deems NOT low-involvement are listed with the disqualifying reason (decision needed, manual validation, size, ambiguity).

## Expand
Run `/cogniva-dev:plan-feature` for FeatureLifecycle/EasyWorkScan when FeatureLifecycle/BacklogGrooming has landed.
