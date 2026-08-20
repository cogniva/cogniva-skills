# The ride-along tier is depth-1 and non-recursive

**Provenance:** Suggested by agent

A run offers ride-alongs exactly once, and work admitted as a ride-along returns backlog candidates only — it never carries ride-alongs of its own. This terminates the "just one more thing" chain structurally rather than by a tunable cap or by judgment exercised at the moment of temptation; a genuine second round is a fresh invocation, not a ride-along.

**Amended by ADR 0033 (2026-08-20):** depth-1 and the single offer are unchanged, but the second-order work a do-now (ride-along) surfaces is now routed through the route-first gate — Plan next, Defer (only with a `because:` reason), or drop — never returned as reason-less backlog candidates.
