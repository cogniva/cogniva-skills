export const meta = {
  name: 'execute-feature',
  description: 'Execute a feature plan task-by-task in an isolated worktree — one fresh agent per task, sequential, lean context.',
  phases: [{ title: 'Execute' }],
}

// The execute-feature / quick-fix skill parses the plan and invokes Workflow with:
//   args = {
//     worktree:      absolute path to the feature worktree (already checked out on featureBranch),
//     pluginRoot:    absolute path to this plugin's root (parent of skills/), for invoking scripts/git-commit.ps1,
//     featureBranch: 'feature/<slug>',
//     planPath:      absolute path to the plan .md in the PRIMARY checkout (control-plane; for ticking checkboxes),
//     statePath:     absolute path to state.md in the PRIMARY checkout (control-plane; durable handoff between tasks),
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

// Some Workflow runtimes deliver `args` as a JSON string rather than a parsed
// object; normalize so destructuring works either way (otherwise this throws
// "undefined is not an object (evaluating 'tasks.length')").
const _args = typeof args === 'string' ? JSON.parse(args) : args
const { worktree, featureBranch, planPath, statePath, tasks, pluginRoot } = _args
const results = []

for (let i = 0; i < tasks.length; i++) {
  const t = tasks[i]
  if (t.done) { results.push({ n: t.n, status: 'SKIPPED' }); continue }

  const prompt = [
    `Implement EXACTLY ONE task of a feature plan, then stop. Do not start the next task.`,
    `Your working directory for ALL CODE is this git worktree: ${worktree}`,
    `You are already checked out on ${featureBranch}. NEVER run git switch / checkout / branch — work where you are.`,
    `Use absolute paths under the worktree. Follow the task's steps verbatim, TDD-style:`,
    `write the failing test → run it (confirm it fails) → minimal implementation → run until green → run the task's full verification.`,
    `On success, commit with the cogniva-dev wrapper (ONE call, not a chain) — it stages, commits, and prints the short SHA:`,
    `  powershell -NoProfile -ExecutionPolicy Bypass -File "${pluginRoot}/scripts/git-commit.ps1" -RepoPath "${worktree}" -Path <only this task's files> -Message "<the task's commit message>"`,
    `Capture the short SHA it prints on stdout. Do NOT run \`git add\`/\`git commit\`/\`git rev-parse\` yourself, and never chain commands with && or prefix them with cd — run each command as its own Bash call (your cwd is already the worktree; use absolute paths).`,
    `Two control files live in the PRIMARY checkout, OUTSIDE your worktree — edit them in place by absolute path; they are untracked metadata, NOT part of your commit, and must NEVER be passed to git-commit.ps1:`,
    `  - plan:  ${planPath}  — flip THIS task's checkboxes from "- [ ]" to "- [x]".`,
    `  - state: ${statePath} — append one short line: created/modified paths, key decisions, and the commit SHA.`,
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
