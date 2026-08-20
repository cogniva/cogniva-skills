# A defect introduced by the current run is unfinished work, not a followup

**Provenance:** Suggested by human

A bug the current run's own work introduced is fixed before the run completes, in the same workspace, with no gate. Two exceptions, both raised immediately rather than deferred: the fix would change what the feature is (or its design), or it is big enough to warrant its own plan — then the run proposes the fix plan instead. An introduced defect is never backlogged and never silently dropped.
