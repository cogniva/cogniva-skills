# The ride-along gate fires on the open worktree, and only when a candidate exists

**Provenance:** Suggested by agent

Confirmed ride-along work is done and committed in the same worktree that just ran the tasks, so it rides the same merge — no second integration, no re-established context. Execution skills pause for the gate only when at least one candidate passes Test 3; a run with none stays fire-and-forget and reports its backlog candidates after integration exactly as before.
