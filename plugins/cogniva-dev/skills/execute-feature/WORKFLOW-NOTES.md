# execute-feature — workflow / resume / integration contract

## Why a Workflow (not an orchestrator skill)
The control loop is plain JS → ~0 model tokens, deterministic task order, and
`resumeFromRunId`. Each task is ONE fresh subagent → lean context per task with no
manual `/clear` and no reviewer fan-out (the thing that previously dominated token
usage). Compare: a single continuous session would avoid subagents but grow
context across all tasks; an orchestrator skill would spend model tokens reasoning
each iteration. The Workflow gives lean + cheap + deterministic at once.

## Sequential, one shared worktree
All task-agents operate in the SAME feature worktree on `feature/<slug>`, in
order — each builds on the previous. Therefore:
- Do NOT parallelize tasks.
- Do NOT use the Workflow per-agent `isolation:'worktree'` option (that gives each
  agent its own tree; we want them to share one).
Isolation between *different* execute-feature runs comes from each run having its
own worktree+branch (see `scripts/new-feature-worktree.ps1`).

## Multi-plan features (one feature, several ordered sub-plans)
A large feature may be planned as an orchestration manifest (`<Feature>-plan.md`
with a `## Sub-plans (execution order)` table) plus `subplans/NN-<slug>.md` files.
The skill flattens every sub-plan's tasks, IN LISTED (dependency-sorted) ORDER,
into the single `tasks` array — so the workflow is unchanged: same sequential
one-agent-per-task loop in the SAME worktree. The only difference is that each task
carries its own `planPath` (the sub-plan file whose checkboxes it ticks) and a
`subplan` label. There is still exactly ONE integration, after ALL sub-plans
complete and the worktree is green — the user validates the whole feature once,
never per sub-plan. The split is invisible to the user (plan-feature never reveals
it).

## State / resume
- Progress lives in the plan's checkboxes (`- [x]`) and `state.md`, both inside
  the worktree — durable across crashes and gate stops.
- Re-running the skill re-parses the plan: tasks whose checkboxes are all ticked
  are passed `done:true` and skipped. The Workflow can also be resumed with
  `resumeFromRunId` to replay completed agents instantly.
- ⛔ gate tasks stop the run for human validation; re-run to continue.

## Integration (after the workflow, in the skill — not in the workflow)
`scripts/integrate-feature.ps1`:
1. Pre-merge target → feature inside the worktree (conflicts surface in the
   sandbox, never the user's tree).
2. Serialize via `<git-common-dir>/cogniva-integration.lock`.
3. Fast-forward LOCAL push `git push . feature/<slug>:<target>` with
   `receive.denyCurrentBranch=updateInstead` set in the target repo. Updates the
   target's working tree IFF clean; if dirty → `QUEUED_DIRTY` (WIP preserved).
Never contacts a remote. The user pushes to remote themselves.

## Prerequisites in the TARGET repo (one-time)
- `git config receive.denyCurrentBranch updateInstead`
- PreToolUse hook must ALLOW `git worktree add/remove`, `git merge`, `git push .`
  while keeping `git switch/checkout/branch` denied in the primary checkout.
