# 08 HookAdapters — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/CrossHostParity
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** The four plugin hooks read Codex's edit and shell payloads as well
as Claude Code's, so a Codex `apply_patch` to the primary checkout is denied
the same way a Claude Code `Edit` is, and the hooks' limits on both agent hosts
are documented in one place.

**Architecture:** A dependency-free CommonJS adapter,
`plugins/cogniva-dev/scripts/hook-input.js`, turns a hook's stdin into
`editedPaths(input)` (absolute paths: Claude Code `file_path`/`notebook_path`,
every `*** Add/Update/Delete File:` and `*** Move to:` path of a Codex patch,
relative paths resolved against the payload's `cwd`) and `shellCommand(input)`.
`guard-primary-edit.js`, `nudge-backlog-commit.js` and `guard-module-cycles.js`
act if ANY edited path qualifies; `guard-primary-git.js` reads the shell command
through the adapter. Every hook keeps its "on any uncertainty, ALLOW" contract
and exit 0; a missing adapter makes a hook stand down. `hooks.json` matchers
stay as they are (Codex routes `apply_patch` to `Write`/`Edit` matchers) unless
the Codex diagnostics report recorded otherwise. Hooks remain best-effort:
shell-mediated writes are not seen, and Codex runs a plugin hook only after the
user trusts it.

**Read these first:** `plugins/cogniva-dev/hooks/hooks.json`, the hook scripts
`plugins/cogniva-dev/scripts/guard-primary-edit.js`, `nudge-backlog-commit.js`,
`guard-module-cycles.js`, `guard-primary-git.js`, `worktree-mode.js`;
`plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1`,
`plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1`,
`plugins/cogniva-dev/tests/hooks/fixtures/codex-apply-patch.captured.json`,
`plugins/cogniva-dev/tests/hooks/fixtures/codex-shell.captured.json`,
`docs/host-parity/codex-diagnostics.md`, `docs/host-parity.md`,
`plugins/cogniva-dev/docs/codex.md`, `docs/adr/0006-*.md`.

## File structure (locked)

```
plugins/cogniva-dev/scripts/hook-input.js                         # adapter: readHookInput, editedPaths, shellCommand
plugins/cogniva-dev/tests/hooks/hook-input.test.mjs               # node unit tests for the adapter
plugins/cogniva-dev/tests/hooks/hook-input.tests.ps1              # gate wrapper (label hook-input)
.claude/cogniva-dev/green-gate.json                               # + hook-input entry
plugins/cogniva-dev/scripts/guard-primary-edit.js                 # any guarded path -> deny, lists them, host-neutral message
plugins/cogniva-dev/scripts/nudge-backlog-commit.js               # any dirty tier-1 backlog path -> nudge
plugins/cogniva-dev/scripts/guard-module-cycles.js                # any .csproj path -> -Check per opted-in repo
plugins/cogniva-dev/scripts/guard-primary-git.js                  # shell command via the adapter
plugins/cogniva-dev/hooks/hooks.json                              # unchanged unless the diagnostics report requires it
plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1           # KNOWN GAP assertions flipped; Codex/multi-path cases
plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1  # + Codex apply_patch cases
plugins/cogniva-dev/docs/codex.md                                 # Hooks under Codex: parsed payloads, trust, limits
docs/host-parity.md                                               # hook rows: Codex scripts-tested (or partial), notes
docs/adr/NNNN-hooks-read-both-hosts-edit-payloads-and-remain-best-effort.md  # ADR C5
```

## Candidate ADRs

### ADR-C5: Hooks read both hosts' edit payloads and remain best-effort
**Provenance:** Suggested by agent
The plugin hooks take their target paths from `scripts/hook-input.js`, which reads Claude Code's `tool_input.file_path`/`notebook_path` and every path in a Codex `apply_patch` payload, and a hook acts if any of those paths qualifies. Hooks are a best-effort guardrail on both agent hosts — shell-mediated writes are not seen, and Codex runs a plugin hook only after the user trusts it — so guarantees live in the landing checks (structural check, `git diff --check`, green gate), and the parity record states each hook's per-host limits.
**Write with:** Task 3

## Task 1: hook-input.js adapter (test-first)

**Files:**
- Create: `plugins/cogniva-dev/scripts/hook-input.js`
- Create: `plugins/cogniva-dev/tests/hooks/hook-input.test.mjs`
- Create: `plugins/cogniva-dev/tests/hooks/hook-input.tests.ps1`
- Modify: `.claude/cogniva-dev/green-gate.json`

Constraints: the adapter is CommonJS with NO npm dependencies (Node built-ins
only). `readHookInput` THROWS on invalid JSON — every caller keeps its own
"on any uncertainty, ALLOW" try/catch. The PowerShell wrapper is pwsh 7. Write
files as UTF-8 without a BOM, LF line endings. Codex documents its
`apply_patch` hook input as `tool_name: "apply_patch"` with the patch text in
`tool_input.command` (lines `*** Begin Patch`, `*** Add File: <path>`,
`*** Update File: <path>`, `*** Move to: <path>`, `*** Delete File: <path>`,
`*** End Patch`), paths relative to the payload's `cwd`; Codex reports shell
calls as `tool_name: "Bash"` with `tool_input.command`.

- [x] **Step 1 (read the captured payload):** Open `plugins/cogniva-dev/tests/hooks/fixtures/codex-apply-patch.captured.json` and find where the patch text sits. The adapter below reads it from `tool_input.command`, `tool_input.input` or `tool_input.patch` (a string, or a string element of an array), or from `tool_input` itself when that is a string. If the fixture puts the patch text in any OTHER field of `tool_input`, add that field's name to the `PATCH_FIELDS` array in Step 4 and add one test line for it in Step 2, copying the `tool_input.input` test with the field name changed. If the fixture carries `"_source": "documented, not captured"`, it is the documented shape; use it as is.
- [x] **Step 2 (failing tests):** Create `plugins/cogniva-dev/tests/hooks/hook-input.test.mjs`:
  ```js
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
  ```
  Create `plugins/cogniva-dev/tests/hooks/hook-input.tests.ps1`:
  ```powershell
  #Requires -Version 7.0
  # Green-gate wrapper for the hook input adapter's unit tests
  # (hook-input.test.mjs -> scripts/hook-input.js). Dependency-free; needs node,
  # which the plugin hooks need anyway.
  $ErrorActionPreference = 'Stop'
  $here = Split-Path -Parent $MyInvocation.MyCommand.Path
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
      Write-Host '  FAIL  node is installed (the hook-input tests need it)'
      Write-Host ''
      Write-Host 'FAILED: 1 assertion(s).'
      exit 1
  }
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & node (Join-Path $here 'hook-input.test.mjs') 2>&1 | ForEach-Object { Write-Host ([string]$_) }; $code = $LASTEXITCODE }
  finally { $ErrorActionPreference = $previous }
  if ($code -ne 0) { Write-Host ''; Write-Host 'FAILED: hook-input assertions (see FAIL lines above).'; exit 1 }
  Write-Host ''
  Write-Host 'All hook-input assertions passed.'
  exit 0
  ```
- [x] **Step 3 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/hooks/hook-input.tests.ps1` → node fails with `Cannot find module` for `scripts/hook-input.js`, then `FAILED: hook-input assertions (see FAIL lines above).`, exit 1.
- [x] **Step 4 (implement):** Create `plugins/cogniva-dev/scripts/hook-input.js` (keep `\uFEFF` as the six-character escape, not a literal BOM character):
  ```js
  // Shared hook-input adapter for the cogniva-dev hooks: ONE place that knows
  // how each agent host describes a tool call, so every hook reads Claude Code
  // and Codex payloads identically.
  //   - Claude Code: Write/Edit carry tool_input.file_path, NotebookEdit carries
  //     tool_input.notebook_path.
  //   - Codex: apply_patch carries the whole patch text (tool_input.command);
  //     every "*** Add File: ", "*** Update File: ", "*** Delete File: " and
  //     "*** Move to: " line names a path, relative to the payload's cwd. Codex
  //     shell calls arrive as tool_name "Bash" with tool_input.command.
  // No dependencies. readHookInput THROWS on invalid JSON - callers keep their
  // own "on any uncertainty, allow" contract around it.
  const path = require('path');

  // tool_input fields that may hold apply_patch text. Codex documents `command`;
  // `input` and `patch` are accepted in case a surface uses them.
  const PATCH_FIELDS = ['command', 'input', 'patch'];
  const PATCH_LINE = /^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)$/;
  const BEGIN_PATCH = /^\s*\*\*\* Begin Patch\s*$/m;

  function readHookInput(raw) {
    const text = String(raw == null ? '' : raw).replace(/^\uFEFF/, '').trim();
    if (!text) return {};
    const parsed = JSON.parse(text);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  }

  function isPatchText(value) {
    return typeof value === 'string' && BEGIN_PATCH.test(value);
  }

  // Every patch text the payload carries (a string field, or an element of an
  // array field such as ["apply_patch", "<patch>"]).
  function patchTexts(input) {
    const ti = input.tool_input;
    if (typeof ti === 'string') return isPatchText(ti) || input.tool_name === 'apply_patch' ? [ti] : [];
    if (!ti || typeof ti !== 'object') return [];
    const found = [];
    for (const field of PATCH_FIELDS) {
      const value = ti[field];
      if (typeof value === 'string') {
        if (isPatchText(value) || (input.tool_name === 'apply_patch' && found.length === 0)) found.push(value);
      }
      else if (Array.isArray(value)) {
        for (const part of value) if (isPatchText(part)) found.push(part);
      }
    }
    return found;
  }

  function editedPaths(input) {
    if (!input || typeof input !== 'object') return [];
    const base = typeof input.cwd === 'string' && input.cwd ? input.cwd : process.cwd();
    const raw = [];
    const ti = input.tool_input && typeof input.tool_input === 'object' ? input.tool_input : {};
    if (typeof ti.file_path === 'string' && ti.file_path) raw.push(ti.file_path);
    if (typeof ti.notebook_path === 'string' && ti.notebook_path) raw.push(ti.notebook_path);
    for (const text of patchTexts(input)) {
      for (const line of text.split(/\r?\n/)) {
        const m = line.match(PATCH_LINE);
        if (m && m[1].trim()) raw.push(m[1].trim());
      }
    }
    const seen = new Set();
    const out = [];
    for (const p of raw) {
      const abs = path.resolve(base, p);
      const key = process.platform === 'win32' ? abs.toLowerCase() : abs;
      if (!seen.has(key)) { seen.add(key); out.push(abs); }
    }
    return out;
  }

  // The shell command a Bash-style call runs, or '' (never a patch text).
  function shellCommand(input) {
    if (!input || typeof input !== 'object') return '';
    if (input.tool_name === 'apply_patch') return '';
    const ti = input.tool_input && typeof input.tool_input === 'object' ? input.tool_input : {};
    let cmd = '';
    if (typeof ti.command === 'string') cmd = ti.command;
    else if (Array.isArray(ti.command)) cmd = ti.command.map(String).join(' ');
    return cmd.includes('*** Begin Patch') ? '' : cmd;
  }

  module.exports = { readHookInput, editedPaths, shellCommand };
  ```
- [x] **Step 5 (wire the gate):** In `.claude/cogniva-dev/green-gate.json`, add a comma after the current LAST object of `commands` (the `task-contract` entry) and append as the new last entry:
  ```json
      { "run": "pwsh -NoProfile -File plugins/cogniva-dev/tests/hooks/hook-input.tests.ps1", "label": "hook-input", "note": "Pins the hook input adapter: Claude Code file_path/notebook_path, every path of a Codex apply_patch (multi-file, move, CRLF, captured payload), shell commands, garbage input; needs PowerShell 7 and node." }
  ```
  Then `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/validate-json.ps1 .claude/cogniva-dev/green-gate.json` → `OK   .claude/cogniva-dev/green-gate.json`.
- [x] **Step 6 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/hooks/hook-input.tests.ps1` → every line PASS, `All hook-input assertions passed.`, exit 0.
- [x] **Step 7 (commit):** `git add plugins/cogniva-dev/scripts/hook-input.js plugins/cogniva-dev/tests/hooks/hook-input.test.mjs plugins/cogniva-dev/tests/hooks/hook-input.tests.ps1 .claude/cogniva-dev/green-gate.json` then `git commit -m "feat(hooks): hook-input.js reads Claude Code and Codex apply_patch payloads"`

## Task 2: Hooks on the adapter; Codex gaps flipped to deny/nudge

**Files:**
- Modify: `plugins/cogniva-dev/scripts/guard-primary-edit.js`
- Modify: `plugins/cogniva-dev/scripts/nudge-backlog-commit.js`
- Modify: `plugins/cogniva-dev/scripts/guard-module-cycles.js`
- Modify: `plugins/cogniva-dev/scripts/guard-primary-git.js`
- Modify (only if Step 1 says so): `plugins/cogniva-dev/hooks/hooks.json`
- Test: `plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1`
- Test: `plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1`

Constraints: `plugins/cogniva-dev/scripts/hook-input.js` exists and exports
`readHookInput(raw)` (strips a BOM, `{}` on empty, throws on invalid JSON),
`editedPaths(input)` (absolute, de-duplicated paths from Claude Code
`file_path`/`notebook_path` and every Codex patch path, resolved against
`input.cwd`) and `shellCommand(input)` (the Bash command, `''` for
`apply_patch` and patch text). Every hook keeps its contract: only ever deny
(or nudge, or `decision: block`) on a confirmed case, exit 0 always, and on any
uncertainty or error ALLOW silently; a hook that cannot load the adapter stands
down. Keep `guard-primary-edit.js`'s exemption list (`.explore/**`,
`.plans-staging/**`, tier-1 `docs/plans/BACKLOG.md` and
`docs/plans/<Module>/BACKLOG.md`) and the linked-worktree / worktree-mode logic
unchanged. Both test suites are Windows PowerShell 5.1 compatible and must stay
so (no `??`, no `?:`, no pwsh-only APIs). The deny message must not use a bare
"host" for Claude Code or Codex.

- [ ] **Step 1 (matchers — read the diagnostics report):** Open `docs/host-parity/codex-diagnostics.md` and find what it recorded about which `hooks.json` matcher Codex's `apply_patch` reached. Codex's docs say the `Edit`/`Write` matchers match `apply_patch`, so the default is: **leave `plugins/cogniva-dev/hooks/hooks.json` unchanged.** Only if the report recorded that a Codex `apply_patch` did NOT trigger the `Write|Edit|NotebookEdit` / `Write|Edit` hooks (and named `apply_patch` as the matcher that does), change the two edit matchers to `"Write|Edit|NotebookEdit|apply_patch"` (PreToolUse) and `"Write|Edit|apply_patch"` (PostToolUse), and in `plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1` change `Where-Object { $_.matcher -eq 'Write|Edit' }` to `Where-Object { $_.matcher -eq 'Write|Edit|apply_patch' }` and the label's `Write|Edit` to `Write|Edit|apply_patch`. Write down which case applied; Task 3 needs it.
- [ ] **Step 2 (flip the KNOWN GAP assertions):** In `plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1` (pwsh 7; helpers `Invoke-Hook <hook> <payload> <cwd>`, `Test-Denied`, `Test-Silent`, `New-Patch <header>`):
  1. In the header comment, replace the lines
     ```powershell
     # Claude Code payloads are asserted against their real behaviour. Codex
     # apply_patch payloads are pinned at today's behaviour under 'KNOWN GAP' labels:
     # the edit hooks read only tool_input.file_path, so they do not see a Codex patch.
     ```
     with
     ```powershell
     # Claude Code payloads and Codex apply_patch payloads are both asserted against
     # the intended behaviour: every hook reads its input through scripts/hook-input.js.
     ```
  2. Replace the comment line `# --- Codex apply_patch payloads: today's behaviour, pinned -----------------` with `# --- Codex apply_patch payloads (read through scripts/hook-input.js) --------`, and the two comment lines under it (`# Worktree mode is on and BACKLOG.md is still uncommitted, so a hook that read` / `# the patch WOULD deny the first and nudge on the second.`) with `# Worktree mode is on and BACKLOG.md is still uncommitted: the edit guard denies` / `# the first patch and the nudge fires on the second.`
  3. Replace
     ```powershell
     Check 'KNOWN GAP (fixed in sub-plan 08): edit guard returns no decision for a Codex apply_patch to a primary-checkout file' (Test-Silent $r)
     ```
     with
     ```powershell
     Check 'Codex payload: edit guard denies a Codex apply_patch to a primary-checkout file' (Test-Denied $r)
     ```
  4. Replace
     ```powershell
     Check 'KNOWN GAP (fixed in sub-plan 08): nudge is silent for a Codex apply_patch to an uncommitted BACKLOG.md' (Test-Silent $r)
     ```
     with
     ```powershell
     Check 'Codex payload: nudge fires for a Codex apply_patch to an uncommitted BACKLOG.md' ($r.Code -eq 0 -and $r.Json -and $r.Json.hookSpecificOutput.hookEventName -eq 'PostToolUse' -and $r.Json.hookSpecificOutput.additionalContext -match 'UNCOMMITTED in the PRIMARY checkout')
     ```
  If `Select-String -Path plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1 -Pattern 'KNOWN GAP'` still finds a line (an assertion added after planning), flip it the same way: keep its payload, assert the intended deny/nudge/block, and relabel it `Codex payload: <new expectation>`. Afterwards that command must return nothing. (The suite asserts deny decisions, not the deny message's wording, so the new message needs no other change here.)
- [ ] **Step 3 (add the Codex and multi-path cases):** In `plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1`, insert this self-contained block immediately BEFORE the suite's final failure-count check (the line `if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }`). It uses the suite's `Check` function (if the suite's assertion function has another name, use that name for every `Check` below) and builds its own fixture:
  ```powershell
  # --- Codex payloads and multi-path edits (scripts/hook-input.js adapter) -----
  # Self-contained: its own worktree-mode fixture repo, removed in finally.
  # Windows PowerShell 5.1 compatible.
  $adapterPlugin = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
  function Invoke-AdapterHook([string]$Hook, $Payload) {
      $json = $Payload | ConvertTo-Json -Compress -Depth 6
      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try {
          $lines = @($json | & node (Join-Path $adapterPlugin "scripts\$Hook") 2>&1)
          $code = $LASTEXITCODE
      }
      finally { $ErrorActionPreference = $previous }
      $out = ((@($lines | ForEach-Object { [string]$_ }) -join "`n").Trim())
      $parsed = $null
      if ($out) { try { $parsed = $out | ConvertFrom-Json } catch { $parsed = $null } }
      [pscustomobject]@{ Code = $code; Out = $out; Json = $parsed }
  }
  function Test-AdapterDenied($Result) {
      return ($Result.Code -eq 0 -and $Result.Json -and $Result.Json.hookSpecificOutput.permissionDecision -eq 'deny')
  }
  function New-CodexPatch([string[]]$Lines) {
      return ((@('*** Begin Patch') + $Lines + @('*** End Patch')) -join "`n") + "`n"
  }
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
      Write-Host '  SKIP  Codex payload hook behaviour (node not installed)'
  }
  else {
      $adapterRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-hook-adapter-" + [guid]::NewGuid().ToString('N'))
      try {
          $repo = Join-Path $adapterRoot 'repo'
          New-Item -ItemType Directory -Path (Join-Path $repo 'src') -Force | Out-Null
          New-Item -ItemType Directory -Path (Join-Path $repo 'docs\plans\M') -Force | Out-Null
          & git -C $repo init -q
          & git -C $repo config user.email 'hook-adapter-test@example.invalid'
          & git -C $repo config user.name 'Hook Adapter Test'
          & git -C $repo config core.autocrlf false
          [System.IO.File]::WriteAllText((Join-Path $repo 'src\a.txt'), "a`n")
          [System.IO.File]::WriteAllText((Join-Path $repo 'src\old.txt'), "old`n")
          [System.IO.File]::WriteAllText((Join-Path $repo 'docs\plans\M\BACKLOG.md'), "# Backlog`n")
          & git -C $repo add -A
          & git -C $repo commit -qm 'fixture'
          New-Item -ItemType Directory -Path (Join-Path $repo '.claude') -Force | Out-Null
          [System.IO.File]::WriteAllText((Join-Path $repo '.claude\cogniva-dev.local.json'), '{"worktrees": true}')
          $codexEdit = { param([string[]]$Lines) @{ tool_name = 'apply_patch'; cwd = $repo; hook_event_name = 'PreToolUse'; tool_input = @{ command = (New-CodexPatch $Lines) } } }

          $r = Invoke-AdapterHook 'guard-primary-edit.js' (& $codexEdit @('*** Update File: src/a.txt', '@@', '-a', '+b'))
          Check 'Codex apply_patch Update File in the primary checkout is denied' (Test-AdapterDenied $r)
          Check 'the deny message is agent-host-neutral and names the path' ($r.Json.hookSpecificOutput.permissionDecisionReason -match 'agents must not edit the primary checkout directly' -and $r.Json.hookSpecificOutput.permissionDecisionReason -match 'a\.txt')

          $r = Invoke-AdapterHook 'guard-primary-edit.js' (& $codexEdit @('*** Add File: .plans-staging/M/F/F-plan.md', '+x', '*** Update File: src/a.txt', '@@', '-a', '+b'))
          $reason = [string]$r.Json.hookSpecificOutput.permissionDecisionReason
          Check 'a multi-file patch with one exempt and one guarded path is denied' (Test-AdapterDenied $r)
          Check 'the deny lists only the guarded path' ($reason -match 'a\.txt' -and $reason -notmatch 'F-plan\.md')

          $r = Invoke-AdapterHook 'guard-primary-edit.js' (& $codexEdit @('*** Add File: .explore/idea.md', '+x', '*** Update File: docs/plans/M/BACKLOG.md', '@@', '+- [ ] item'))
          Check 'a patch touching only exempt paths is allowed' ($r.Code -eq 0 -and -not $r.Out)

          $r = Invoke-AdapterHook 'guard-primary-edit.js' (& $codexEdit @('*** Add File: src/new/b.txt', '+b'))
          Check 'Codex Add File in a new folder of the primary checkout is denied' (Test-AdapterDenied $r)
          $r = Invoke-AdapterHook 'guard-primary-edit.js' (& $codexEdit @('*** Delete File: src/old.txt'))
          Check 'Codex Delete File in the primary checkout is denied' (Test-AdapterDenied $r)
          $r = Invoke-AdapterHook 'guard-primary-edit.js' (& $codexEdit @('*** Update File: .explore/x.md', '*** Move to: src/moved.txt', '@@', '-a', '+b'))
          Check 'Codex Move to a guarded path is denied' ((Test-AdapterDenied $r) -and $r.Json.hookSpecificOutput.permissionDecisionReason -match 'moved\.txt')

          $r = Invoke-AdapterHook 'guard-primary-edit.js' @{ tool_name = 'Edit'; tool_input = @{ file_path = (Join-Path $repo 'src\a.txt'); old_string = 'a'; new_string = 'b' } }
          Check 'Claude Edit in the primary checkout is still denied' (Test-AdapterDenied $r)

          [System.IO.File]::AppendAllText((Join-Path $repo 'docs\plans\M\BACKLOG.md'), "- [ ] new item`n")
          $r = Invoke-AdapterHook 'nudge-backlog-commit.js' @{ tool_name = 'apply_patch'; cwd = $repo; hook_event_name = 'PostToolUse'; tool_input = @{ command = (New-CodexPatch @('*** Update File: docs/plans/M/BACKLOG.md', '@@', '+- [ ] new item')) } }
          Check 'Codex apply_patch to a dirty tier-1 BACKLOG.md is nudged' ($r.Code -eq 0 -and $r.Json -and $r.Json.hookSpecificOutput.additionalContext -match 'UNCOMMITTED')
          $r = Invoke-AdapterHook 'nudge-backlog-commit.js' @{ tool_name = 'apply_patch'; cwd = $repo; hook_event_name = 'PostToolUse'; tool_input = @{ command = (New-CodexPatch @('*** Update File: src/a.txt', '@@', '-a', '+b', '*** Update File: docs/plans/M/BACKLOG.md', '@@', '+- [ ] new item')) } }
          Check 'a multi-file Codex patch that includes a dirty tier-1 BACKLOG.md is nudged' ($r.Code -eq 0 -and $r.Json -and $r.Json.hookSpecificOutput.additionalContext -match 'BACKLOG\.md')

          $r = Invoke-AdapterHook 'guard-primary-git.js' @{ tool_name = 'Bash'; cwd = $repo; tool_input = @{ command = 'git switch -c feature/x' } }
          Check 'Codex Bash git switch in the primary checkout is denied' (Test-AdapterDenied $r)
          $r = Invoke-AdapterHook 'guard-primary-git.js' @{ tool_name = 'Bash'; cwd = $repo; tool_input = @{ command = @('git', 'checkout', 'main') } }
          Check 'a shell command given as an array is checked too' (Test-AdapterDenied $r)
          $r = Invoke-AdapterHook 'guard-primary-git.js' @{ tool_name = 'apply_patch'; cwd = $repo; tool_input = @{ command = (New-CodexPatch @('*** Update File: notes.md', '@@', '+run git checkout main later')) } }
          Check 'patch text that mentions git checkout is not a shell command' ($r.Code -eq 0 -and -not $r.Out)

          # A shell-mediated write never reaches the edit guard: it arrives on the Bash
          # matcher, where only the git guard runs (and allows it), and the adapter
          # finds no edited path in it.
          $shellWrite = @{ tool_name = 'Bash'; cwd = $repo; tool_input = @{ command = 'Set-Content src/a.txt x' } }
          $r = Invoke-AdapterHook 'guard-primary-git.js' $shellWrite
          $editMatcher = @((Get-Content -Raw -LiteralPath (Join-Path $adapterPlugin 'hooks\hooks.json') | ConvertFrom-Json).hooks.PreToolUse | Where-Object { @($_.hooks | Where-Object { $_.command -match 'guard-primary-edit\.js' }).Count -gt 0 })
          $shellPaths = [string](($shellWrite | ConvertTo-Json -Compress) | & node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const h=require(process.argv[1]);process.stdout.write(String(h.editedPaths(h.readHookInput(s)).length))})" (Join-Path $adapterPlugin 'scripts\hook-input.js'))
          Check 'LIMITATION (documented): shell writes are not seen by the edit guard' ($r.Code -eq 0 -and -not $r.Out -and $editMatcher.Count -eq 1 -and $editMatcher[0].matcher -notmatch 'Bash' -and $shellPaths -eq '0')
      }
      finally {
          if (Test-Path -LiteralPath $adapterRoot) { Remove-Item -LiteralPath $adapterRoot -Recurse -Force }
      }
  }

  ```
- [ ] **Step 4 (Codex case for the module-deps hook):** In `plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1`:
  1. Replace
     ```powershell
     function Invoke-Hook([string]$FilePath) {
         $payload = @{ tool_name = 'Edit'; tool_input = @{ file_path = $FilePath } } | ConvertTo-Json -Compress
         $previous = $ErrorActionPreference
     ```
     with
     ```powershell
     function Invoke-Hook([string]$FilePath) {
         Invoke-HookJson (@{ tool_name = 'Edit'; tool_input = @{ file_path = $FilePath } } | ConvertTo-Json -Compress)
     }
     function Invoke-HookJson([string]$payload) {
         $previous = $ErrorActionPreference
     ```
  2. Immediately after the line `Check 'an opted-in repo with a cycle is blocked with the -Check report' (...)`, insert:
     ```powershell
             # Codex reports an edit as apply_patch with the patch text in tool_input.command,
             # paths relative to the payload's cwd.
             $patch = "*** Begin Patch`n*** Update File: README.md`n@@`n-a`n+b`n*** Update File: src/Modules/B/B.Application/B.Application.csproj`n@@`n-x`n+y`n*** End Patch`n"
             $r = Invoke-HookJson (@{ tool_name = 'apply_patch'; cwd = $repo; tool_input = @{ command = $patch } } | ConvertTo-Json -Compress)
             $decision = $null
             try { $decision = $r.Out | ConvertFrom-Json } catch { }
             Check 'a Codex apply_patch that updates a .csproj in an opted-in repo with a cycle is blocked' ($r.Code -eq 0 -and $decision -and $decision.decision -eq 'block' -and $decision.reason -match 'A <-> B')
             $patch = "*** Begin Patch`n*** Update File: README.md`n@@`n-a`n+b`n*** End Patch`n"
             $r = Invoke-HookJson (@{ tool_name = 'apply_patch'; cwd = $repo; tool_input = @{ command = $patch } } | ConvertTo-Json -Compress)
             Check 'a Codex apply_patch that touches no .csproj is silent' ($r.Code -eq 0 -and -not $r.Out)
     ```
- [ ] **Step 5 (run them, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1` → FAIL on both flipped `Codex payload:` assertions and on 11 of the 15 new assertions (`Claude Edit ... still denied`, `a patch touching only exempt paths is allowed`, `Codex Bash git switch ... denied` and the `LIMITATION` check already PASS). `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1` → `FAIL  a Codex apply_patch that updates a .csproj in an opted-in repo with a cycle is blocked`, exit 1.
- [ ] **Step 6 (guard-primary-edit.js):** Replace the WHOLE content of `plugins/cogniva-dev/scripts/guard-primary-edit.js` with:
  ```js
  // PreToolUse guard (Write|Edit|NotebookEdit; Codex routes apply_patch to the
  // same matcher): block ALL direct edits to the PRIMARY checkout of a clone
  // running in worktree mode. Every change an agent makes - code, docs, .claude,
  // anything - must happen in a git worktree, which fast-forward-merges into your
  // branch. This keeps the shared primary checkout's tree clean: no agent lands on
  // your branch except via a worktree merge (see docs/adr/0006).
  //
  // The edited paths come from scripts/hook-input.js: Claude Code's
  // file_path/notebook_path, or EVERY path in a Codex apply_patch. The edit is
  // denied if ANY of them is guarded; the message names only the guarded ones.
  // Shell-mediated writes (a Bash/PowerShell command that writes a file) are not
  // seen by this hook - it is a best-effort guardrail, not a guarantee.
  //
  // ALLOWED in the primary (no worktree) - ONLY gitignored disposable scratch dirs,
  // which never appear on your branch so they cannot dirty it:
  //   - .explore/**       (explore-idea's brainstorm docs)
  //   - .plans-staging/** (general gitignored scratch staging)
  // ...plus tier-1 backlog capture, which IS tracked but append-only bookkeeping:
  //   - docs/plans/BACKLOG.md and docs/plans/<Module>/BACKLOG.md
  //     (deferred stubs' backlog.md, plans, and state.md remain guarded)
  // ALWAYS ALLOWED:
  //   - any file inside a LINKED worktree (that is where all work belongs)
  //   - any clone NOT in worktree mode (no .claude/cogniva-dev.local.json with
  //     worktrees: true at the repo root) - lean mode is the default
  //
  // Contract: only ever DENY a primary-checkout edit; on any uncertainty or
  // error, ALLOW (never hard-fail a tool because of this hook).
  const { execSync } = require('child_process');
  const path = require('path');
  const fs = require('fs');

  function git(dir, args) {
    return execSync(`git -C "${dir}" ${args}`, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  }
  function allow() { process.exit(0); }
  function deny(reason) {
    process.stdout.write(JSON.stringify({
      hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: reason },
    }));
    process.exit(0);
  }
  // Worktree-mode predicate is shared (scripts/worktree-mode.js) so all hooks
  // read the switch identically. A missing/broken lib degrades to lean mode =>
  // this hook stands down (contract: on any uncertainty, allow).
  let worktreesOn;
  try { ({ worktreesOn } = require(path.join(__dirname, 'worktree-mode.js'))); }
  catch (e) { worktreesOn = () => false; }
  // Payload parsing is shared (scripts/hook-input.js). A missing/broken lib =>
  // no paths => this hook stands down (contract: on any uncertainty, allow).
  let hookInput;
  try { hookInput = require(path.join(__dirname, 'hook-input.js')); }
  catch (e) { hookInput = null; }

  // Returns abs when it is a guarded PRIMARY-checkout path, else null (linked
  // worktree, lean mode, exempt scratch/backlog, not a git repo, or unsure).
  function guardedPath(abs) {
    // Use the nearest EXISTING ancestor dir so new files in new dirs still resolve a repo.
    let dir = path.dirname(abs);
    while (dir && !fs.existsSync(dir)) { const up = path.dirname(dir); if (up === dir) break; dir = up; }
    if (!fs.existsSync(dir)) return null;

    let topo, gitDir, commonRaw;
    try {
      topo = git(dir, 'rev-parse --show-toplevel');
      gitDir = git(dir, 'rev-parse --absolute-git-dir');
      commonRaw = git(dir, 'rev-parse --git-common-dir');
    } catch (e) { return null; } // not a git repo

    // --git-common-dir is relative to the -C dir (where git ran), NOT to topo.
    const commonAbs = path.isAbsolute(commonRaw) ? commonRaw : path.resolve(dir, commonRaw);
    // Linked worktree => git-dir (.../worktrees/<name>) differs from common-dir => ALLOW.
    if (path.resolve(gitDir).toLowerCase() !== path.resolve(commonAbs).toLowerCase()) return null;

    // Opt-in: only enforce in clones running in worktree mode.
    if (!worktreesOn(topo)) return null;

    // We are in the PRIMARY checkout. Allow ONLY gitignored disposable scratch dirs.
    const rel = path.relative(topo, abs).split(path.sep).join('/');
    const first = rel.split('/')[0];
    const exempt = first === '.explore' || first === '.plans-staging';
    if (exempt) return null;

    // Tier-1 backlog capture is exempt: appending a loose item to a BACKLOG.md is
    // append-only bookkeeping, not workflow output, and a worktree round-trip for a
    // one-line append defeats the backlog skill's purpose (see ADR 0006 addendum).
    // Depth is enforced (docs/plans/BACKLOG.md or docs/plans/<Module>/BACKLOG.md)
    // so a deferred stub's docs/plans/<Module>/<Idea>/backlog.md - the same name on
    // a case-insensitive filesystem - stays guarded along with plans and state.md.
    const parts = rel.toLowerCase().split('/');
    const backlogExempt =
      parts[0] === 'docs' && parts[1] === 'plans' &&
      (parts.length === 3 || parts.length === 4) &&
      parts[parts.length - 1] === 'backlog.md';
    if (backlogExempt) return null;

    return abs;
  }

  let raw = '';
  process.stdin.on('data', d => (raw += d)).on('end', () => {
    try {
      if (!hookInput) return allow();
      const paths = hookInput.editedPaths(hookInput.readHookInput(raw));
      if (paths.length === 0) return allow();

      const blocked = [];
      for (const abs of paths) {
        let hit = null;
        try { hit = guardedPath(abs); } catch (e) { hit = null; }
        if (hit) blocked.push(hit);
      }
      if (blocked.length === 0) return allow();

      return deny(
        'Blocked: this is the shared PRIMARY checkout - agents must not edit the primary checkout directly ' +
        '(code, docs, or .claude). Blocked path(s): ' + blocked.join(', ') + '. ' +
        'Every change must go through a git worktree that fast-forward-merges into your branch. ' +
        'Use the quick-fix skill for a small change, or the execute-feature skill for planned work - ' +
        'both create the worktree, integrate, and mark it cleanupable for you (worktree mode requires Claude Code). ' +
        'The ONLY paths editable directly here are gitignored scratch (.explore/**, .plans-staging/**) ' +
        'and tier-1 backlog files (docs/plans/BACKLOG.md, docs/plans/<Module>/BACKLOG.md).'
      );
    } catch (e) { return allow(); }
  });
  ```
- [ ] **Step 7 (nudge-backlog-commit.js):** Replace the WHOLE content of `plugins/cogniva-dev/scripts/nudge-backlog-commit.js` with the code below. One exception: if the message text inside the current file's `nudge(...)` call differs from the one below (an earlier sub-plan reworded it), keep the CURRENT message text and change only the structure.
  ```js
  // PostToolUse nudge (Write|Edit; Codex routes apply_patch to the same
  // matcher): a tier-1 BACKLOG.md was just written in the PRIMARY checkout and
  // left uncommitted. The primary-edit guard deliberately
  // EXEMPTS tier-1 backlog capture (docs/plans/BACKLOG.md and
  // docs/plans/<Module>/BACKLOG.md) so a one-line append does not need a worktree
  // round-trip - but an exempt write still dirties the shared primary tree, and a
  // dirty primary is exactly what makes the next integrate-feature run park itself
  // as QUEUED_DIRTY. So we remind the caller to close the loop.
  //
  // The edited paths come from scripts/hook-input.js (Claude Code's file_path /
  // notebook_path, or every path in a Codex apply_patch); the nudge names the
  // first edited path that qualifies.
  //
  // ADVISORY ONLY. This hook never denies, never fails the tool, and prints
  // NOTHING unless ALL of the following hold for some edited path:
  //   1. the edited path is a tier-1 BACKLOG.md (same depth test the guard uses)
  //   2. we are in the PRIMARY checkout (a linked worktree is silent)
  //   3. worktree mode is on in this clone (.claude/cogniva-dev.local.json with
  //      worktrees: true at the repo root); lean mode is the default and silent
  //   4. the file is actually dirty (git status --porcelain is non-empty)
  // On any uncertainty or error: exit 0, silently. A hook that chatters on
  // unrelated writes is worse than no hook.
  const { execSync } = require('child_process');
  const path = require('path');
  const fs = require('fs');

  function git(dir, args) {
    return execSync(`git -C "${dir}" ${args}`, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  }
  function quiet() { process.exit(0); }
  function nudge(message) {
    process.stdout.write(JSON.stringify({
      hookSpecificOutput: { hookEventName: 'PostToolUse', additionalContext: message },
    }));
    process.exit(0);
  }
  // Worktree-mode predicate is shared (scripts/worktree-mode.js) so all hooks
  // read the switch identically. A missing/broken lib degrades to lean mode =>
  // this hook stands down (contract: on any uncertainty, allow).
  let worktreesOn;
  try { ({ worktreesOn } = require(path.join(__dirname, 'worktree-mode.js'))); }
  catch (e) { worktreesOn = () => false; }
  // Payload parsing is shared (scripts/hook-input.js). A missing/broken lib =>
  // no paths => silent.
  let hookInput;
  try { hookInput = require(path.join(__dirname, 'hook-input.js')); }
  catch (e) { hookInput = null; }

  // Returns the repo top when abs is an uncommitted tier-1 backlog file in the
  // PRIMARY checkout of a worktree-mode clone, else null.
  function dirtyTier1Backlog(abs) {
    // Use the nearest EXISTING ancestor dir so new files in new dirs still resolve a repo.
    let dir = path.dirname(abs);
    while (dir && !fs.existsSync(dir)) { const up = path.dirname(dir); if (up === dir) break; dir = up; }
    if (!fs.existsSync(dir)) return null;

    let topo, gitDir, commonRaw;
    try {
      topo = git(dir, 'rev-parse --show-toplevel');
      gitDir = git(dir, 'rev-parse --absolute-git-dir');
      commonRaw = git(dir, 'rev-parse --git-common-dir');
    } catch (e) { return null; } // not a git repo

    // Tier-1 depth test, IDENTICAL to guard-primary-edit.js's backlogExempt:
    // docs/plans/BACKLOG.md (3) or docs/plans/<Module>/BACKLOG.md (4) only. A
    // deferred stub's docs/plans/<Module>/<Idea>/backlog.md (5) is NOT tier-1.
    const rel = path.relative(topo, abs).split(path.sep).join('/');
    const parts = rel.toLowerCase().split('/');
    const isTier1Backlog =
      parts[0] === 'docs' && parts[1] === 'plans' &&
      (parts.length === 3 || parts.length === 4) &&
      parts[parts.length - 1] === 'backlog.md';
    if (!isTier1Backlog) return null;

    // --git-common-dir is relative to the -C dir (where git ran), NOT to topo.
    const commonAbs = path.isAbsolute(commonRaw) ? commonRaw : path.resolve(dir, commonRaw);
    // Linked worktree => git-dir (.../worktrees/<name>) differs from common-dir.
    // The capture already rides that worktree's commit - nothing to nudge about.
    if (path.resolve(gitDir).toLowerCase() !== path.resolve(commonAbs).toLowerCase()) return null;

    // Opt-in: only nudge in clones running in worktree mode.
    if (!worktreesOn(topo)) return null;

    // Only nudge if the file is genuinely uncommitted right now.
    let status;
    try {
      status = git(topo, `status --porcelain -- "${abs}"`);
    } catch (e) { return null; }
    return status ? topo : null;
  }

  let raw = '';
  process.stdin.on('data', d => (raw += d)).on('end', () => {
    try {
      if (!hookInput) return quiet();
      const paths = hookInput.editedPaths(hookInput.readHookInput(raw));
      for (const abs of paths) {
        let topo = null;
        try { topo = dirtyTier1Backlog(abs); } catch (e) { topo = null; }
        if (!topo) continue;
        return nudge(
          `The tier-1 backlog file ${abs} is now UNCOMMITTED in the PRIMARY checkout. ` +
          'Leaving it dirty blocks the next integrate-feature run, which parks itself as QUEUED_DIRTY ' +
          'until the primary tree is clean. Close the loop now, one of two ways. ' +
          'If this was a DIRECT /cogniva-dev:backlog capture, commit it path-scoped straight away: ' +
          `scripts/git-commit.ps1 -RepoPath "${topo}" -Path "${abs}" -Message "chore(backlog): <what you captured>" ` +
          '- path-scoped so it never sweeps up unrelated uncommitted work. ' +
          'If this was SKILL-INITIATED capture during plan-feature / execute-feature / quick-fix, it does not ' +
          'belong in the primary at all: move the entry into the open worktree\'s copy of the file so it rides ' +
          'that feature\'s commit, and revert the primary back to clean.'
        );
      }
      return quiet();
    } catch (e) { return quiet(); }
  });
  ```
- [ ] **Step 8 (guard-module-cycles.js):** In `plugins/cogniva-dev/scripts/guard-module-cycles.js`, replace this block (from `let raw = '';` through the line `    process.stdout.write(JSON.stringify({`):
  ```js
  let raw = '';
  process.stdin.on('data', d => (raw += d)).on('end', () => {
    try {
      // Windows PowerShell 5.1 can prefix piped stdin with a UTF-8 BOM.
      const input = JSON.parse((raw || '{}').replace(/^\uFEFF/, ''));
      const fp = (input.tool_input || {}).file_path;
      if (!fp || !/\.csproj$/i.test(fp)) return allow();

      const dir = path.dirname(path.resolve(fp));
      if (!fs.existsSync(dir)) return allow();

      let top;
      try {
        // execFileSync, not execSync: the edited path must never pass through a shell.
        top = execFileSync('git', ['-C', dir, 'rev-parse', '--show-toplevel'], {
          encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
        }).trim();
      } catch (e) { return allow(); } // not a git repo
      if (!top || !optedIn(top) || !fs.existsSync(SCRIPT)) return allow();

      const report = runCheck(top);
      if (!report) return allow();
      process.stdout.write(JSON.stringify({
  ```
  with:
  ```js
  // Payload parsing is shared (scripts/hook-input.js): Claude Code's file_path
  // or every path in a Codex apply_patch. It also strips the UTF-8 BOM Windows
  // PowerShell 5.1 can prefix to piped stdin. A missing/broken lib => silent.
  let hookInput;
  try { hookInput = require(path.join(__dirname, 'hook-input.js')); }
  catch (e) { hookInput = null; }

  // The repo top of an opted-in repo holding this .csproj, else null.
  function optedInTop(fp) {
    const dir = path.dirname(fp);
    if (!fs.existsSync(dir)) return null;
    let top;
    try {
      // execFileSync, not execSync: the edited path must never pass through a shell.
      top = execFileSync('git', ['-C', dir, 'rev-parse', '--show-toplevel'], {
        encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
      }).trim();
    } catch (e) { return null; } // not a git repo
    return top && optedIn(top) ? top : null;
  }

  let raw = '';
  process.stdin.on('data', d => (raw += d)).on('end', () => {
    try {
      if (!hookInput || !fs.existsSync(SCRIPT)) return allow();
      const csprojs = hookInput.editedPaths(hookInput.readHookInput(raw)).filter(p => /\.csproj$/i.test(p));
      if (csprojs.length === 0) return allow();

      // One -Check per opted-in repo, however many of its .csproj files the edit touched.
      const tops = [];
      for (const fp of csprojs) {
        const top = optedInTop(fp);
        if (top && !tops.includes(top)) tops.push(top);
      }
      let report = null;
      for (const top of tops) { report = runCheck(top); if (report) break; }
      if (!report) return allow();
      process.stdout.write(JSON.stringify({
  ```
  Leave the rest of the file (the `decision: 'block'` reason text and the closing lines) unchanged.
- [ ] **Step 9 (guard-primary-git.js):** In `plugins/cogniva-dev/scripts/guard-primary-git.js`, replace
  ```js
  let raw = '';
  process.stdin.on('data', d => (raw += d)).on('end', () => {
    try {
      const input = JSON.parse(raw || '{}');
      const cmd = (input.tool_input || {}).command || '';
      if (!SWITCH_RE.test(cmd)) return allow();
  ```
  with
  ```js
  // Payload parsing is shared (scripts/hook-input.js): shellCommand() reads a
  // Claude Code or Codex Bash call's command (string, or array joined with
  // spaces) and never returns apply_patch text. A missing/broken lib => allow.
  let hookInput;
  try { hookInput = require(path.join(__dirname, 'hook-input.js')); }
  catch (e) { hookInput = null; }

  let raw = '';
  process.stdin.on('data', d => (raw += d)).on('end', () => {
    try {
      if (!hookInput) return allow();
      const input = hookInput.readHookInput(raw);
      const cmd = hookInput.shellCommand(input);
      if (!SWITCH_RE.test(cmd)) return allow();
  ```
  Leave the rest unchanged (it still resolves the repo from `git -C` or `input.cwd`, and keeps its deny message).
- [ ] **Step 10 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1` → every line PASS, `All primary-hooks assertions passed.`, exit 0; `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1` → `All guard-module-cycles assertions passed.`; `pwsh -NoProfile -File plugins/cogniva-dev/tests/hooks/hook-input.tests.ps1` → `All hook-input assertions passed.`; `pwsh -NoProfile -File scripts/check-host-neutrality.ps1` → `host-neutrality: OK - …` (the hook scripts are `.js`, outside the ratchet's scope, so nothing here should move it).
- [ ] **Step 11 (commit):** `git add plugins/cogniva-dev/scripts/guard-primary-edit.js plugins/cogniva-dev/scripts/nudge-backlog-commit.js plugins/cogniva-dev/scripts/guard-module-cycles.js plugins/cogniva-dev/scripts/guard-primary-git.js plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1 plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1` (plus `plugins/cogniva-dev/hooks/hooks.json` if Step 1 changed it) then `git commit -m "feat(hooks): all four hooks read Codex apply_patch and shell payloads through hook-input.js"`

## Task 3: Hook docs, parity record, ADR

**Files:**
- Modify: `plugins/cogniva-dev/docs/codex.md`
- Modify: `docs/host-parity.md`
- Modify: `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`
- Create: `docs/adr/NNNN-hooks-read-both-hosts-edit-payloads-and-remain-best-effort.md`

Context: the four hooks (`guard-primary-edit.js`, `guard-primary-git.js`,
`nudge-backlog-commit.js`, `guard-module-cycles.js`) now read their input
through `scripts/hook-input.js`, which parses Claude Code's
`file_path`/`notebook_path` and every path of a Codex `apply_patch`; the gate
suites `primary-hooks`, `hook-input` and `module-deps-hook` cover them.
Unresolved decision 4 of this feature (Codex re-trust after every plugin
update) keeps its default: accept the churn and document it.
`docs/codex.md` has a `## Hooks under Codex` section, written when the parity
record was created, that still says the hooks do not see `apply_patch` edits.
The skill-semantics suite runs under Windows PowerShell 5.1: regexes you add
must be ASCII-only. Do not use a bare "host" for Claude Code/Codex in new text.

- [ ] **Step 1 (failing pins):** In `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`, replace the assertion (two lines, joined by a backtick continuation)
  ```powershell
  Check 'docs/codex.md: hooks under Codex need trust and miss apply_patch edits' `
      ($docs -match '## Hooks under Codex' -and $docsFlat -match 'only after you trust it in `/hooks`' -and $docsFlat -match 'do not see edits Codex makes with `apply_patch`' -and $docsFlat -match 'best-effort on both agent hosts')
  ```
  with
  ```powershell
  Check 'docs/codex.md: hooks under Codex need trust and read apply_patch edits' `
      ($docs -match '## Hooks under Codex' -and $docsFlat -match 'only after you trust it in `/hooks`' -and $docsFlat -match 'reads its input through `scripts/hook-input\.js`' -and $docsFlat -notmatch 'do not see edits Codex makes with `apply_patch`' -and $docsFlat -match 'best-effort on both agent hosts')
  Check 'docs/codex.md: Codex hooks need trust again after every update' `
      ($docsFlat -match 'Re-trust after every cogniva-dev update')
  Check 'docs/codex.md: shell writes are unseen; guarantees live in the landing checks' `
      ($docsFlat -match 'not seen by the edit guard' -and $docsFlat -match 'guarantees live in the landing checks')
  ```
  (`$docsFlat` is defined just above that assertion.) Run `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → the three checks FAIL, exit 1.
- [ ] **Step 2 (docs/codex.md):** In `plugins/cogniva-dev/docs/codex.md`, replace the body of the `## Hooks under Codex` section (everything between that heading and the next `## ` heading; keep both headings) with the text below. If Task 2 Step 1 changed the `hooks.json` matchers, use the first variant of the bracketed sentence in the **Edits** bullet; otherwise the second.
  ```markdown
  cogniva-dev ships four hooks in `hooks/hooks.json`: the primary-checkout edit
  guard and branch-switch guard (worktree mode), the backlog-commit nudge, and
  the opt-in Module-cycle check. Codex loads that file when
  `[features] hooks = true` is set in `~/.codex/config.toml`. Every hook reads its
  input through `scripts/hook-input.js`, so Codex payloads are parsed, not only
  Claude Code's:

  - **Edits.** Codex reports an edit as `apply_patch`, with the whole patch text
    in `tool_input.command`. The adapter reads every `*** Add File:`,
    `*** Update File:`, `*** Delete File:` and `*** Move to:` path, relative to
    the payload's `cwd`. The edit guard denies the patch if ANY of its paths is
    a guarded primary-checkout path, and names only those; the backlog nudge and
    the Module-cycle check act if any path qualifies. [The edit hooks' matchers
    also name `apply_patch`, because Codex did not route it to `Write`/`Edit`. |
    Codex routes `apply_patch` to the `Write`/`Edit` matchers, so the matchers
    are the same for both agent hosts.]
  - **Shell commands.** Codex reports shell calls as `Bash` with
    `tool_input.command`; the branch-switch guard reads them the same way on
    both agent hosts.
  - **Trust.** Codex runs each hook only after you trust it in `/hooks`, again
    after any change to `hooks.json` (a plugin update can bring one). Re-trust
    after every cogniva-dev update; until then the hooks do not run. This churn
    is accepted and documented rather than avoided by not shipping hooks to
    Codex.
  - **Best-effort.** Hooks are best-effort on both agent hosts: they see tool
    payloads, not effects, so a file written by a shell command
    (`Set-Content`, `echo >`, a script) is not seen by the edit guard. The
    guarantees live in the landing checks — the structural check,
    `git diff --check` and the green gate — not in hooks.
  ```
  Write only the chosen sentence of the bracketed pair, without the brackets or the `|`.
- [ ] **Step 3 (write ADR):** scan `docs/adr/` for the next free number and write ADR-C5 from this sub-plan's `## Candidate ADRs` verbatim — heading `# Hooks read both hosts' edit payloads and remain best-effort` (no `ADR-C5` label), `**Provenance:** Suggested by agent`, then the body paragraph — to `docs/adr/NNNN-hooks-read-both-hosts-edit-payloads-and-remain-best-effort.md` per `plugins/cogniva-dev/skills/adr/ADR-FORMAT.md`. Run `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/check-adrs.ps1 -Workspace .` → exit 0.
- [ ] **Step 4 (parity record):** Read `docs/host-parity/codex-diagnostics.md` for whether Codex hooks fired on each surface it tested (CLI, VS Code). In `docs/host-parity.md` `## Capabilities` (columns `| ID | Capability | Kind | Covers | Claude Code | Codex | Evidence | Notes |`), edit the four hook rows; `NNNN` below is the number from Step 3:
  - `Codex` cell of each row: `scripts-tested — hook-input adapter` when the report shows Codex hooks fired on every surface it tested; `partial — hook-input adapter` when it shows a surface where they never fired. A `verified` status already earned from a smoke record stays as it is. Leave the `Claude Code` cells unchanged.
  - `Evidence`: `primary-edit-guard`, `branch-switch-guard` and `backlog-commit-nudge` → `gate:primary-hooks, gate:hook-input`; `module-cycle-hook` → `gate:module-deps-hook, gate:hook-input` (keep any `smoke:` items already there).
  - `Notes`, replacing the whole cell:
    - `primary-edit-guard`: `Reads Claude Code file_path/notebook_path and every path of a Codex apply_patch through hook-input.js, and denies if any path is guarded (ADR NNNN). Codex runs it only after the user trusts it in /hooks, again after any change to hooks.json. Both agent hosts: writes made through a shell command are not seen; the guarantees live in the landing checks.`
    - `branch-switch-guard`: `Reads the Bash command through hook-input.js on both agent hosts, never apply_patch text (ADR NNNN). Codex runs it only after the user trusts it in /hooks, again after any change to hooks.json. Both agent hosts: a command the guard does not recognise passes.`
    - `backlog-commit-nudge`: `Reads Claude Code file_path and every path of a Codex apply_patch through hook-input.js (ADR NNNN). Codex runs it only after the user trusts it in /hooks, again after any change to hooks.json. Both agent hosts: writes made through a shell command are not seen.`
    - `module-cycle-hook`: `Reads every .csproj path of a Claude Code edit or a Codex apply_patch through hook-input.js (ADR NNNN). Codex runs it only after the user trusts it in /hooks, again after any change to hooks.json. Both agent hosts: writes made through a shell command are not seen; module-deps -Check in a completion gate is the guarantee.`
    - For a row set to `partial`, append ` Codex hooks did not fire on <surface> in the diagnostics.` naming the surface from the report.
  Under `## Intentional asymmetries`, add the bullet: `- primary-edit-guard, branch-switch-guard, backlog-commit-nudge, module-cycle-hook — Codex runs plugin hooks only after the user trusts them in /hooks, again after each hooks.json change; this re-trust is accepted and documented rather than not shipping hooks to Codex (ADR NNNN).` Then `pwsh -NoProfile -File scripts/check-host-parity.ps1` → a `host-parity: OK - …` line, exit 0.
- [ ] **Step 5 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`, exit 0; `pwsh -NoProfile -File scripts/check-host-neutrality.ps1` → `host-neutrality: OK - …` (`docs/` is outside its scope).
- [ ] **Step 6 (commit):** `git add plugins/cogniva-dev/docs/codex.md docs/host-parity.md plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1 docs/adr` then `git commit -m "docs(hooks): Codex hook payloads, trust and limits; parity record and ADR"`
