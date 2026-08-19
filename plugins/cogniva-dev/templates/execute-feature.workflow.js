export const meta = {
  name: 'execute-feature',
  description: 'Execute a feature plan task-by-task in an isolated worktree — one fresh agent per task, sequential, lean context.',
  phases: [{ title: 'Execute' }],
}

// The execute-feature skill (or any ad-hoc run) parses the plan and invokes Workflow with:
//   args = {
//     workspace:     absolute path to the workspace the run happens in — the repo checkout in lean mode,
//                    the feature worktree in worktree mode (legacy alias: `worktree`, still accepted),
//     branch:        the branch the run commits on — the user's current branch in lean
//                    mode, 'feature/<slug>' in worktree mode (legacy alias: `featureBranch`),
//     planPath:      absolute path to the manifest/flat plan .md inside the workspace (FALLBACK tick target),
//     statePath:     OPTIONAL absolute path to state.md inside the workspace (durable handoff between
//                    tasks); omit it and no state-log instruction is emitted,
//     commits:       OPTIONAL commit policy — 'none' | 'task' | 'final' (default 'task' for backward
//                    compatibility). 'task' = one checkpoint commit per task, checkboxes ticked BEFORE
//                    the commit so the SHA represents the completed task state. 'none' / 'final' = the
//                    task agent stages and commits nothing and leaves its work in the tree (under
//                    'final' the ONE implementation commit is made by the console at SKILL.md Step 4),
//     tasks: [ { n, title, body, isGate, done, planPath?, subplan? } ]  // self-contained task sections, in order
//   }
// A flat plan yields tasks with no per-task planPath (they tick the global planPath). A multi-plan feature
// flattens every sub-plan's tasks, in dependency order, into this ONE array — each task carries its own
// planPath (its subplans/NN-<slug>.md) and a subplan label. Either way tasks run SEQUENTIALLY in the SAME
// workspace (each builds on the previous) — do NOT parallelize and do NOT use per-agent isolation:'worktree'.
// In worktree mode, integration into the user's branch happens ONCE, AFTER this workflow returns, via
// scripts/integrate-feature.ps1 (kept out of the workflow so git stays deterministic).

const TASK_RESULT = {
  type: 'object',
  additionalProperties: false,
  required: ['status', 'summary'],
  properties: {
    status: { type: 'string', enum: ['DONE', 'BLOCKED'] },
    summary: { type: 'string', description: 'One or two lines: what changed.' },
    commitSha: { type: 'string', description: 'Short SHA of the task commit, if committed.' },
    note: { type: 'string', description: 'If BLOCKED: exactly what is missing or needed.' },
    followups: {
      type: 'array',
      description: 'Backlog CANDIDATES only — never written to any BACKLOG.md by this agent. Omit or leave empty unless the task surfaced work that is genuinely not covered by this plan or an open plan folder, AND you can point at a concrete observed fact for it. Speculation and "it would be nice if" do not qualify.',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['description', 'receipt', 'strength'],
        properties: {
          description: { type: 'string', description: 'One line, as it would appear in BACKLOG.md.' },
          receipt: { type: 'string', description: 'The concrete observed fact, with a location: "same off-by-one at handler.ts:88", "blocked needing IExportPort, which the plan never defines".' },
          strength: { type: 'string', enum: ['clear', 'ambiguous'], description: 'clear = the fact is unambiguous; ambiguous = a passing observation. When unsure, use ambiguous.' },
          size: { type: 'string', enum: ['S', 'M', 'L'] },
        },
      },
    },
  },
}

phase('Execute')

// Some Workflow runtimes deliver `args` as a JSON string rather than a parsed
// object; normalize so destructuring works either way (otherwise this throws
// "undefined is not an object (evaluating 'tasks.length')").
const _args = typeof args === 'string' ? JSON.parse(args) : args
const { planPath, statePath, tasks } = _args
// `workspace` and `branch` are the arg names in both modes; `worktree` and
// `featureBranch` stay as legacy aliases so older callers keep working.
const workspace = _args.workspace ?? _args.worktree
const branch = _args.branch ?? _args.featureBranch
// Commit policy; defaults to 'task' so pre-flag callers behave exactly as before.
const commits = _args.commits ?? 'task'
const results = []
// Task numbers restart per sub-plan, so anything identifying a task must use
// (subplan, n) — the tag qualifies with the subplan where one exists.
const tagOf = t => t.subplan ? `${t.subplan}/task-${t.n}` : `task-${t.n}`

for (let i = 0; i < tasks.length; i++) {
  const t = tasks[i]
  const tag = tagOf(t)
  if (t.done) { results.push({ n: t.n, subplan: t.subplan, status: 'SKIPPED' }); continue }

  const taskPlanPath = t.planPath || planPath
  const prompt = [
    `Implement EXACTLY ONE task of a feature plan, then stop. Do not start the next task.`,
    `Your only working directory is: ${workspace}`,
    `You are already checked out on ${branch}. NEVER run git switch / checkout / branch — work where you are.`,
    `Use absolute paths under the workspace. Follow the task's steps verbatim, TDD-style:`,
    `write the failing test → run it (confirm it fails) → minimal implementation → run until green → run the task's full verification.`,
    // Commit policy. planPath and statePath are both OPTIONAL (planless quick-fix runs;
    // plans with no state.md) — omit the instruction entirely rather than interpolating
    // "undefined". Under 'task' the checkboxes are ticked BEFORE the commit, so the SHA
    // represents the completed task state.
    ...(commits === 'task'
      ? [
          taskPlanPath ? `On success: FIRST edit ${taskPlanPath} to flip THIS task's checkboxes from "- [ ]" to "- [x]".` : null,
          `Then stage ONLY the files you changed and commit with the task's commit message (keep the repo's commit conventions).`,
        ]
      : [
          `Do NOT stage or commit anything: leave the files you changed in the working tree.`,
          taskPlanPath ? `On success: edit ${taskPlanPath} to flip THIS task's checkboxes from "- [ ]" to "- [x]".` : null,
        ]),
    statePath ? `Append one short line to ${statePath}: created/modified paths, key decisions, and the commit SHA.` : null,
    `If you cannot finish cleanly, return status BLOCKED with a precise note and do NOT leave a partial commit.`,
    `NEVER write to any BACKLOG.md. If this task surfaced real work outside the plan, return it in "followups" with a concrete receipt (a located fact) — the console gates it with the user. No receipt, no followup.`,
    ``,
    `=== TASK ${t.n}: ${t.title} ===`,
    t.body,
  ].filter(l => l !== null).join('\n')

  const r = await agent(prompt, { label: tag, phase: 'Execute', schema: TASK_RESULT })
  const res = r || { status: 'BLOCKED', summary: '', note: 'agent returned null (skipped or terminal error)' }
  results.push({ n: t.n, subplan: t.subplan, ...res })
  log(`${tag} (${t.title}): ${res.status}${res.commitSha ? ' @' + res.commitSha : ''}`)

  if (res.status === 'BLOCKED') { log(`Stopping: ${tag} is blocked.`); break }
  if (t.isGate) { log(`Stopping: ${tag} is a manual-validation gate. Validate the app, then re-run to resume.`); break }
}

const done = results.filter(r => r.status === 'DONE').map(tagOf)
const blocked = results.find(r => r.status === 'BLOCKED')
const gateHit = (() => { const last = results[results.length - 1]; const t = tasks.find(x => x.n === last?.n && x.subplan === last?.subplan); return !!(t && t.isGate && last.status === 'DONE') })()
const followups = results.flatMap(r => (r.followups || []).map(f => ({ ...f, task: r.n, subplan: r.subplan })))
return { results, done, blocked: blocked ? tagOf(blocked) : null, gateHit, allDone: !blocked && done.length === tasks.filter(t => !t.done).length, followups }
