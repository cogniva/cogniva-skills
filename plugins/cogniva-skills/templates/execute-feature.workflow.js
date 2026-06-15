export const meta = {
  name: 'execute-feature',
  description: 'Execute a feature plan task-by-task in an isolated worktree — one fresh agent per task, sequential, lean context.',
  phases: [{ title: 'Execute' }],
}

// The execute-feature / quick-fix skill parses the plan and invokes Workflow with:
//   args = {
//     worktree:      absolute path to the feature worktree (already checked out on featureBranch),
//     featureBranch: 'feature/<slug>',
//     planPath:      absolute path to the plan .md inside the worktree (for ticking checkboxes),
//     statePath:     absolute path to state.md inside the worktree (durable handoff between tasks),
//     tasks: [ { n, title, body, isGate, done } ]   // self-contained task sections, in order
//   }
// Tasks run SEQUENTIALLY (each builds on the previous in the SAME worktree) — do NOT parallelize and
// do NOT use per-agent isolation:'worktree'. Integration into the user's branch happens AFTER this
// workflow returns, via scripts/integrate-feature.ps1 (kept out of the workflow so git stays deterministic).

const TASK_RESULT = {
  type: 'object',
  additionalProperties: false,
  required: ['status', 'summary'],
  properties: {
    status: { type: 'string', enum: ['DONE', 'BLOCKED'] },
    summary: { type: 'string', description: 'One or two lines: what changed.' },
    commitSha: { type: 'string', description: 'Short SHA of the task commit, if committed.' },
    note: { type: 'string', description: 'If BLOCKED: exactly what is missing or needed.' },
  },
}

phase('Execute')

const { worktree, featureBranch, planPath, statePath, tasks } = args
const results = []

for (let i = 0; i < tasks.length; i++) {
  const t = tasks[i]
  if (t.done) { results.push({ n: t.n, status: 'SKIPPED' }); continue }

  const prompt = [
    `Implement EXACTLY ONE task of a feature plan, then stop. Do not start the next task.`,
    `Your only working directory is this git worktree: ${worktree}`,
    `You are already checked out on ${featureBranch}. NEVER run git switch / checkout / branch — work where you are.`,
    `Use absolute paths under the worktree. Follow the task's steps verbatim, TDD-style:`,
    `write the failing test → run it (confirm it fails) → minimal implementation → run until green → run the task's full verification.`,
    `On success: stage ONLY the files you changed, commit with the task's commit message (keep the repo's commit conventions),`,
    `then edit ${planPath} to flip THIS task's checkboxes from "- [ ]" to "- [x]",`,
    `and append one short line to ${statePath}: created/modified paths, key decisions, and the commit SHA.`,
    `If you cannot finish cleanly, return status BLOCKED with a precise note and do NOT leave a partial commit.`,
    ``,
    `=== TASK ${t.n}: ${t.title} ===`,
    t.body,
  ].join('\n')

  const r = await agent(prompt, { label: `task-${t.n}`, phase: 'Execute', schema: TASK_RESULT })
  const res = r || { status: 'BLOCKED', summary: '', note: 'agent returned null (skipped or terminal error)' }
  results.push({ n: t.n, ...res })
  log(`Task ${t.n} (${t.title}): ${res.status}${res.commitSha ? ' @' + res.commitSha : ''}`)

  if (res.status === 'BLOCKED') { log(`Stopping: task ${t.n} is blocked.`); break }
  if (t.isGate) { log(`Stopping: task ${t.n} is a manual-validation gate. Validate the app, then re-run to resume.`); break }
}

const done = results.filter(r => r.status === 'DONE').map(r => r.n)
const blocked = results.find(r => r.status === 'BLOCKED')
const gateHit = (() => { const last = results[results.length - 1]; const t = tasks.find(x => x.n === last?.n); return !!(t && t.isGate && last.status === 'DONE') })()
return { results, done, blocked: blocked ? blocked.n : null, gateHit, allDone: !blocked && done.length === tasks.filter(t => !t.done).length }
