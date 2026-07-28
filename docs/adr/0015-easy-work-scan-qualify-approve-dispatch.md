# Easy-work scanning is qualify-with-reasons, approval-gated, dispatch-sequential

**Provenance:** Suggested by human

The easy-work scan never starts work unprompted: a read-only pass classifies every open backlog item against a fixed test and presents the qualified shortlist — each with a one-line "why this is safe to hand off" — alongside every disqualified item and its failing criterion, behind ONE approval gate. Approved items are then dispatched ONE AT A TIME through the existing machinery (`quick-fix` for loose lines, `plan-feature` → `execute-feature` for stubs), each fully integrated before the next starts, so no two worktrees race to fast-forward the same branch. The scan selects and dispatches; it never implements, and it never grooms silently.
