// Evaluates templates/execute-feature.workflow.js the way the Workflow runtime
// does - top-level await and return inside an async function body, with
// `args`, `phase`, `agent` and `log` as globals - and records every agent()
// call. Self-contained on purpose: the contract tests need the exact prompt
// string and the `schema` option of each call, and must not depend on the
// command-line surface of the smoke-harness template runner.
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const here = path.dirname(fileURLToPath(import.meta.url))
export const pluginRoot = path.resolve(here, '..', '..')
export const templatePath = path.join(pluginRoot, 'templates', 'execute-feature.workflow.js')

export async function runTemplate(args, reply = { status: 'DONE', summary: 'stub' }) {
  const source = readFileSync(templatePath, 'utf8').replace(/^export\s+const\s+meta\s*=/m, 'const meta =')
  const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor
  const body = new AsyncFunction('args', 'phase', 'agent', 'log', source)
  const calls = []
  const logs = []
  const agent = async (prompt, opts) => { calls.push({ prompt, opts }); return reply }
  const result = await body(args, () => {}, agent, line => logs.push(line))
  return { calls, logs, result }
}
