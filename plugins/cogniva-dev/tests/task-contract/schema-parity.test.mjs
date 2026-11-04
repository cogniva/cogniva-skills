// The Workflow template's TASK_RESULT schema must equal templates/task-result.schema.json.
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { isDeepStrictEqual } from 'node:util'
import { runTemplate, pluginRoot } from './template-loader.mjs'

let failures = 0
function check(label, cond) {
  console.log(`  ${cond ? 'PASS' : 'FAIL'}  ${label}`)
  if (!cond) failures++
}

const schemaFile = path.join(pluginRoot, 'templates', 'task-result.schema.json')
let fileSchema = null
try { fileSchema = JSON.parse(readFileSync(schemaFile, 'utf8').replace(/^\uFEFF/, '')) } catch (e) { fileSchema = null }
check('templates/task-result.schema.json exists and parses', fileSchema !== null)
const { calls } = await runTemplate({
  workspace: 'C:\\work\\repo', branch: 'feature/x', planPath: 'C:\\work\\repo\\plan.md', commits: 'task',
  tasks: [{ n: 1, title: 'One', body: 'Do one thing.', isGate: false, done: false }],
})
check('the template dispatches exactly one agent for one task', calls.length === 1)
const templateSchema = calls[0] && calls[0].opts && calls[0].opts.schema
check('the template passes a schema option to agent()', !!templateSchema)
check('templates/task-result.schema.json equals the template TASK_RESULT schema', fileSchema !== null && isDeepStrictEqual(templateSchema, fileSchema))
check('the schema file has no BOM', fileSchema !== null && !readFileSync(schemaFile).subarray(0, 3).equals(Buffer.from([0xef, 0xbb, 0xbf])))

if (failures) { console.log(`FAILED: ${failures} schema-parity assertion(s).`); process.exit(1) }
console.log('All schema-parity assertions passed.')
