# The green gate is the last step before integration; everything that rides the merge is finished first

**Provenance:** Suggested by human

Ride-along work, the repo's `before-integrate` obligations, and the ADR check all run *before* the green gate, so every change that will ride the merge is verified by it. The previous order gated the plan's tasks and then admitted un-gated edits after the gate had gone green — a repo obligation writing code, or an ADR renumber rewriting a code reference — which made "it passed" a claim about a tree that no longer existed. The `before-integrate` phase keeps its name: its contract was always "on the worktree, so it rides the merge", not "immediately adjacent to the merge command".
