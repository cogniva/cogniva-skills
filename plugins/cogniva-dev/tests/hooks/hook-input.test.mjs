// Unit tests for scripts/hook-input.js (no dependencies; PASS/FAIL lines,
// exit 1 on any failure). Run through hook-input.tests.ps1 in the green gate.
import { createRequire } from 'node:module'
import { readFileSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const require = createRequire(import.meta.url)
const here = path.dirname(fileURLToPath(import.meta.url))
const plugin = path.resolve(here, '..', '..')
const { readHookInput, editedPaths, shellCommand } = require(path.join(plugin, 'scripts', 'hook-input.js'))

let failures = 0
function check(label, cond, detail) {
  console.log(`  ${cond ? 'PASS' : 'FAIL'}  ${label}`)
  if (!cond) { failures++; if (detail !== undefined) console.log(`    got: ${JSON.stringify(detail)}`) }
}
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b)
const cwd = path.resolve(path.sep, 'work', 'repo')
const at = (...p) => path.resolve(cwd, ...p)

// --- readHookInput ---
check('readHookInput: empty string is {}', same(readHookInput(''), {}))
check('readHookInput: whitespace is {}', same(readHookInput('  \r\n'), {}))
check('readHookInput: strips a UTF-8 BOM', readHookInput('\uFEFF{"tool_name":"Edit"}').tool_name === 'Edit')
let threw = false
try { readHookInput('{not json') } catch (e) { threw = true }
check('readHookInput: invalid JSON throws', threw)
check('readHookInput: a JSON non-object is {}', same(readHookInput('[1,2]'), {}) && same(readHookInput('5'), {}))

// --- Claude Code payloads ---
check('Claude Write: file_path', same(editedPaths({ tool_name: 'Write', cwd, tool_input: { file_path: at('src', 'a.ts'), content: 'x' } }), [at('src', 'a.ts')]))
check('Claude Edit: file_path', same(editedPaths({ tool_name: 'Edit', cwd, tool_input: { file_path: at('README.md'), old_string: 'a', new_string: 'b' } }), [at('README.md')]))
check('Claude NotebookEdit: notebook_path', same(editedPaths({ tool_name: 'NotebookEdit', cwd, tool_input: { notebook_path: at('nb.ipynb'), new_source: 'x' } }), [at('nb.ipynb')]))
check('Claude Edit: a relative file_path resolves against cwd', same(editedPaths({ tool_name: 'Edit', cwd, tool_input: { file_path: 'src/a.ts' } }), [at('src', 'a.ts')]))

// --- Codex apply_patch payloads ---
const patch = lines => ['*** Begin Patch', ...lines, '*** End Patch'].join('\n')
const codex = (text, extra = {}) => ({ tool_name: 'apply_patch', cwd, tool_input: { command: text }, ...extra })
check('Codex: single Update File', same(editedPaths(codex(patch(['*** Update File: src/app.ts', '@@', '-a', '+b']))), [at('src', 'app.ts')]))
check('Codex: Add + Update + Delete in one patch', same(
  editedPaths(codex(patch(['*** Add File: docs/new.md', '+hello', '*** Update File: src/app.ts', '@@', '-a', '+b', '*** Delete File: old/gone.txt']))),
  [at('docs', 'new.md'), at('src', 'app.ts'), at('old', 'gone.txt')]))
check('Codex: Move to reports both the source and the destination', same(
  editedPaths(codex(patch(['*** Update File: src/old.ts', '*** Move to: src/new.ts', '@@', '-a', '+b']))),
  [at('src', 'old.ts'), at('src', 'new.ts')]))
const crlf = editedPaths(codex(['*** Begin Patch', '*** Update File: src/a.ts', '@@', '-x', '+y', '*** Add File: src/b.ts', '+z', '*** End Patch'].join('\r\n')))
check('Codex: CRLF patch text', same(crlf, [at('src', 'a.ts'), at('src', 'b.ts')]), crlf)
const absTarget = path.resolve(path.sep, 'elsewhere', 'abs.txt')
check('Codex: an absolute path in the patch stays as is', same(editedPaths(codex(patch([`*** Add File: ${absTarget}`, '+x']))), [absTarget]))
check('Codex: duplicate paths are reported once', same(editedPaths(codex(patch(['*** Update File: src/a.ts', '@@', '*** Update File: src/a.ts', '@@']))), [at('src', 'a.ts')]))
check('Codex: patch text under tool_input.input is read', same(editedPaths({ tool_name: 'apply_patch', cwd, tool_input: { input: patch(['*** Update File: x.md']) } }), [at('x.md')]))
check('Codex: patch text under tool_input.patch is read', same(editedPaths({ tool_name: 'apply_patch', cwd, tool_input: { patch: patch(['*** Update File: y.md']) } }), [at('y.md')]))
check('Codex: a patch sent through a shell-style command array is read', same(editedPaths({ tool_name: 'Bash', cwd, tool_input: { command: ['apply_patch', patch(['*** Update File: z.md'])] } }), [at('z.md')]))
check('Codex: a Bash command string that is a patch is read', same(editedPaths({ tool_name: 'Bash', cwd, tool_input: { command: patch(['*** Delete File: w.md']) } }), [at('w.md')]))
check('Codex: a file content line that merely mentions a marker is not a path', same(editedPaths(codex(patch(['*** Add File: a.md', '+*** Update File: not-a-path.md']))), [at('a.md')]))
const noCwd = editedPaths({ tool_name: 'apply_patch', tool_input: { command: patch(['*** Update File: rel.txt']) } })
check('Codex: without cwd, paths resolve against the process cwd', same(noCwd, [path.resolve(process.cwd(), 'rel.txt')]), noCwd)

// --- captured fixture (Codex diagnostics) ---
const fixture = path.join(here, 'fixtures', 'codex-apply-patch.captured.json')
if (!existsSync(fixture)) {
  check('captured Codex apply_patch fixture exists', false)
} else {
  const raw = readFileSync(fixture, 'utf8')
  const captured = readHookInput(raw)
  const paths = editedPaths(captured)
  check('captured fixture: at least one edited path', paths.length >= 1, paths)
  check('captured fixture: every path is absolute', paths.every(p => path.isAbsolute(p)), paths)
  check('captured fixture: every path names a file the patch mentions', paths.every(p => raw.includes(path.basename(p))), paths)
}

// --- non-edit and garbage input ---
check('no tool_input: no paths', same(editedPaths({ tool_name: 'Edit' }), []))
check('tool_input not an object: no paths', same(editedPaths({ tool_name: 'Edit', tool_input: 42 }), []))
check('null input: no paths', same(editedPaths(null), []))
check('a non-patch Bash command: no paths', same(editedPaths({ tool_name: 'Bash', cwd, tool_input: { command: 'git status' } }), []))

// --- shellCommand ---
check('shellCommand: Bash string command', shellCommand({ tool_name: 'Bash', tool_input: { command: 'git switch main' } }) === 'git switch main')
check('shellCommand: array command is joined with spaces', shellCommand({ tool_name: 'Bash', tool_input: { command: ['git', 'checkout', 'dev'] } }) === 'git checkout dev')
check('shellCommand: apply_patch is never a shell command', shellCommand(codex(patch(['*** Update File: a.md', '+git checkout main']))) === '')
check('shellCommand: a patch sent as a command is never a shell command', shellCommand({ tool_name: 'Bash', tool_input: { command: ['apply_patch', patch(['*** Update File: a.md'])] } }) === '')
check('shellCommand: missing command is empty', shellCommand({ tool_name: 'Bash', tool_input: {} }) === '' && shellCommand({}) === '' && shellCommand(null) === '')

if (failures) { console.log(`FAILED: ${failures} hook-input assertion(s).`); process.exit(1) }
console.log('All hook-input assertions passed.')
