// scripts/new-task-prompt.ps1 must print byte-for-byte the prompt the Workflow
// template builds, for every commits x planPath x statePath combination.
// Only the PowerShell side is normalised, and only by dropping ONE trailing
// newline ("\n" or "\r\n") if present.
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { spawnSync } from 'node:child_process'
import { runTemplate, pluginRoot } from './template-loader.mjs'

let failures = 0
function check(label, cond, detail) {
  console.log(`  ${cond ? 'PASS' : 'FAIL'}  ${label}`)
  if (!cond) { failures++; if (detail) console.log(detail) }
}
function firstDifference(a, b) {
  let i = 0
  while (i < a.length && i < b.length && a[i] === b[i]) i++
  return `    first difference at char ${i}:\n    template:   ${JSON.stringify(a.slice(i, i + 60))}\n    powershell: ${JSON.stringify(b.slice(i, i + 60))}`
}

const script = path.join(pluginRoot, 'scripts', 'new-task-prompt.ps1')
const workspace = 'C:\\work\\repo café'
const branch = 'feature/cross-host'
const planPath = 'C:\\work\\repo café\\docs\\plans\\M\\F\\F-plan.md'
const statePath = 'C:\\work\\repo café\\docs\\plans\\M\\F\\state.md'
const task = {
  n: 7,
  title: 'Quote "this" and `that` — naïve $HOME',
  body: 'Line one with "double" and \'single\' quotes.\r\nA `backtick` and $env:PATH and ${x} and $(whoami).\r\nNon-ASCII: café, naïve, 日本語, emoji 🚀, arrows → ←.\r\n\r\n- [ ] **Step 1:** run `pwsh -NoProfile -File x.ps1` → expect "ok"\r\nlast line without newline',
}

const tmp = mkdtempSync(path.join(tmpdir(), 'cogniva-task-contract-'))
try {
  const taskFile = path.join(tmp, 'task.json')
  writeFileSync(taskFile, JSON.stringify(task), 'utf8')
  for (const commits of ['none', 'task', 'final']) {
    for (const withPlan of [true, false]) {
      for (const withState of [true, false]) {
        const label = `commits=${commits} planPath=${withPlan ? 'set' : 'absent'} statePath=${withState ? 'set' : 'absent'}`
        const args = { workspace, branch, commits, tasks: [{ ...task, isGate: false, done: false }] }
        if (withPlan) args.planPath = planPath
        if (withState) args.statePath = statePath
        const { calls } = await runTemplate(args)
        const expected = calls[0].prompt
        const psArgs = ['-NoProfile', '-File', script, '-Workspace', workspace, '-Branch', branch, '-Commits', commits, '-TaskFile', taskFile]
        if (withPlan) psArgs.push('-PlanPath', planPath)
        if (withState) psArgs.push('-StatePath', statePath)
        const run = spawnSync('pwsh', psArgs, { encoding: 'utf8' })
        const actual = (run.stdout || '').replace(/\r?\n$/, '')
        check(`${label}: exit 0`, run.status === 0, run.stderr)
        check(`${label}: prompt identical to the template`, actual === expected, actual === expected ? '' : firstDifference(expected, actual))
      }
    }
  }

  // -ResultContract: the template prompt, then a blank line and the RESULT section.
  const { calls } = await runTemplate({ workspace, branch, commits: 'none', tasks: [{ ...task, isGate: false, done: false }] })
  const run = spawnSync('pwsh', ['-NoProfile', '-File', script, '-Workspace', workspace, '-Branch', branch, '-Commits', 'none', '-TaskFile', taskFile, '-ResultContract'], { encoding: 'utf8' })
  const out = (run.stdout || '').replace(/\r?\n$/, '')
  check('-ResultContract: starts with the template prompt, then a blank line and "=== RESULT ==="', out.startsWith(calls[0].prompt + '\n\n=== RESULT ===\n'))
  check('-ResultContract: names the schema file and the fenced json block', out.includes('task-result.schema.json') && out.includes('```json'))
  check('-ResultContract: states the status enum and the BLOCKED-on-malformed rule', out.includes('exactly "DONE" or "BLOCKED"') && out.includes('is treated as BLOCKED'))

  // Usage errors exit 2.
  const missing = spawnSync('pwsh', ['-NoProfile', '-File', script, '-Workspace', workspace, '-Branch', branch, '-Commits', 'none', '-TaskFile', path.join(tmp, 'missing.json')], { encoding: 'utf8' })
  check('a missing task file exits 2', missing.status === 2)
  const bad = path.join(tmp, 'bad.json')
  writeFileSync(bad, '{"n": 1, "title": "t"}', 'utf8')
  const noBody = spawnSync('pwsh', ['-NoProfile', '-File', script, '-Workspace', workspace, '-Branch', branch, '-Commits', 'none', '-TaskFile', bad], { encoding: 'utf8' })
  check('a task file without body exits 2', noBody.status === 2)
}
finally { rmSync(tmp, { recursive: true, force: true }) }

if (failures) { console.log(`FAILED: ${failures} prompt-parity assertion(s).`); process.exit(1) }
console.log('All prompt-parity assertions passed.')
