# 07 ExecutorContract — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/CrossHostParity
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** Both executors hand task agents the same prompt and read the same
result shape: the Codex `CODEX.md` loop builds each prompt with a script that is
proven byte-identical to the Workflow template's prompt, and validates each
reply against the template's own result schema.

**Architecture:** The Workflow template (`templates/execute-feature.workflow.js`)
stays self-contained, because it is copied verbatim into the Workflow runtime;
the green gate proves the shared pieces equal it. `templates/task-result.schema.json`
is the template's `TASK_RESULT` as a JSON file (deep-equal by test).
`scripts/new-task-prompt.ps1` (pwsh 7) reproduces the template's prompt lines
and `\n` joining, optionally followed by a `=== RESULT ===` section that asks
for one fenced json block. `scripts/test-task-result.ps1` (pwsh 7, no modules)
extracts the last fenced json block and validates it, driven by the schema
file. `CODEX.md` then runs: task JSON file → prompt script → one fresh
subagent → validator → tick/stop. A malformed reply is `BLOCKED`, like the
template's null result. The node tests evaluate the template with their own
small loader (strip `export`, run the body as an `AsyncFunction` with stub
`args`/`phase`/`agent`/`log`). They do not use the smoke harness's
`run-template.mjs`, because they need the exact `schema` option and prompt of
every `agent()` call for a 12-case input matrix, and should not depend on that
runner's command-line surface.

**Read these first:** `plugins/cogniva-dev/templates/execute-feature.workflow.js`,
`plugins/cogniva-dev/skills/execute-feature/CODEX.md`,
`plugins/cogniva-dev/skills/execute-feature/SKILL.md` (Steps 2–3, Backlog gate),
`plugins/cogniva-dev/docs/codex.md` (§ Backend selection),
`plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`,
`docs/host-parity.md`, `docs/host-parity/codex-diagnostics.md`,
`docs/adr/0029-*.md`, `docs/adr/0039-new-scripts-target-powershell-7.md`.

## File structure (locked)

```
plugins/cogniva-dev/templates/task-result.schema.json            # canonical worker result schema (= template TASK_RESULT)
plugins/cogniva-dev/scripts/new-task-prompt.ps1                  # pwsh 7: the template's task prompt, optional RESULT section
plugins/cogniva-dev/scripts/test-task-result.ps1                 # pwsh 7: last fenced json block -> schema-validated result
plugins/cogniva-dev/tests/task-contract/template-loader.mjs      # evaluates the template with a stub agent(), records calls
plugins/cogniva-dev/tests/task-contract/schema-parity.test.mjs   # schema file == template schema
plugins/cogniva-dev/tests/task-contract/prompt-parity.test.mjs   # new-task-prompt.ps1 == template prompt, 12-case matrix
plugins/cogniva-dev/tests/task-contract/task-contract.tests.ps1  # gate suite: node tests + validator cases
.claude/cogniva-dev/green-gate.json                              # + task-contract entry
plugins/cogniva-dev/skills/execute-feature/CODEX.md              # loop on the shared prompt + result contract
plugins/cogniva-dev/docs/codex.md                                # Backend selection: shared JSON result contract
plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1  # pins for the new CODEX.md / codex.md text
docs/host-parity.md                                              # execution rows: Codex mechanism text, task-contract evidence
docs/adr/NNNN-both-executors-share-one-worker-prompt-and-result-contract.md  # ADR C4
```

## Candidate ADRs

### ADR-C4: Both executors share one worker prompt and result contract
**Provenance:** Suggested by agent
The task-agent prompt is built by `scripts/new-task-prompt.ps1`, kept identical by test to the prompt the Workflow template builds, and the result shape is `templates/task-result.schema.json`, which the template's schema must equal by test; the Codex loop validates every reply with `scripts/test-task-result.ps1` and treats a malformed reply as `BLOCKED`. Orchestration stays native to each agent host — the Workflow template under Claude Code, the `CODEX.md` sequential loop under Codex — and the Workflow runtime is still never emulated (ADR 0029).
**Write with:** Task 3

## Task 1: Canonical result schema and the shared prompt builder

**Files:**
- Create: `plugins/cogniva-dev/templates/task-result.schema.json`
- Create: `plugins/cogniva-dev/scripts/new-task-prompt.ps1`
- Create: `plugins/cogniva-dev/tests/task-contract/template-loader.mjs`
- Create: `plugins/cogniva-dev/tests/task-contract/schema-parity.test.mjs`
- Create: `plugins/cogniva-dev/tests/task-contract/prompt-parity.test.mjs`
- Create: `plugins/cogniva-dev/tests/task-contract/task-contract.tests.ps1`
- Modify: `.claude/cogniva-dev/green-gate.json`

Constraints: new scripts are PowerShell 7 (`#Requires -Version 7.0`, run as
`pwsh -NoProfile -File ...`). Write every new file as UTF-8 **without a BOM**,
LF line endings. Do NOT modify `templates/execute-feature.workflow.js`: it is
copied verbatim into the Workflow runtime, so it stays self-contained, and the
tests below prove the new files equal it.

- [x] **Step 1 (failing tests):** Create `plugins/cogniva-dev/tests/task-contract/template-loader.mjs`:
  ```js
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
  ```
  Create `plugins/cogniva-dev/tests/task-contract/schema-parity.test.mjs`:
  ```js
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
  ```
  Create `plugins/cogniva-dev/tests/task-contract/prompt-parity.test.mjs` (keep the non-ASCII characters exactly; save as UTF-8 without BOM):
  ```js
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
  ```
  Create `plugins/cogniva-dev/tests/task-contract/task-contract.tests.ps1`:
  ```powershell
  #Requires -Version 7.0
  # Dependency-free suite for the shared task-agent contract (no Pester):
  # - schema-parity.test.mjs: templates/task-result.schema.json equals the
  #   Workflow template's TASK_RESULT schema;
  # - prompt-parity.test.mjs: scripts/new-task-prompt.ps1 prints the template's
  #   prompt byte-for-byte across the commits x planPath x statePath matrix;
  # - scripts/test-task-result.ps1 accepts valid replies and rejects malformed ones.
  $ErrorActionPreference = 'Stop'
  $here = Split-Path -Parent $MyInvocation.MyCommand.Path
  $plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  [Console]::OutputEncoding = $utf8
  $failures = @()

  function Check($label, $condition) {
      if ($condition) { Write-Host "  PASS  $label" }
      else { Write-Host "  FAIL  $label"; $script:failures += $label }
  }
  function Invoke-Node([string]$Test) {
      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try { $lines = @(& node (Join-Path $here $Test) 2>&1 | ForEach-Object { [string]$_ }); $code = $LASTEXITCODE }
      finally { $ErrorActionPreference = $previous }
      foreach ($line in $lines) { Write-Host $line }
      return $code
  }

  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
      Check 'node is installed (the contract parity tests need it)' $false
  }
  else {
      Check 'schema parity (node)' ((Invoke-Node 'schema-parity.test.mjs') -eq 0)
      Check 'prompt parity (node)' ((Invoke-Node 'prompt-parity.test.mjs') -eq 0)
  }

  if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
  Write-Host ''
  Write-Host 'All task-contract assertions passed.'
  exit 0
  ```
- [x] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/task-contract/task-contract.tests.ps1` → `FAIL  templates/task-result.schema.json exists and parses`, every `prompt identical to the template` line FAILs (the script does not exist), then `FAILED: 2 assertion(s).`, exit 1.
- [x] **Step 3 (implement the schema):** Create `plugins/cogniva-dev/templates/task-result.schema.json` with exactly this content (the template's `TASK_RESULT`, same properties, descriptions, enums, required and `additionalProperties`; keep the em dashes; no BOM):
  ```json
  {
    "type": "object",
    "additionalProperties": false,
    "required": ["status", "summary"],
    "properties": {
      "status": { "type": "string", "enum": ["DONE", "BLOCKED"] },
      "summary": { "type": "string", "description": "One or two lines: what changed." },
      "commitSha": { "type": "string", "description": "Short SHA of the task commit, if committed." },
      "note": { "type": "string", "description": "If BLOCKED: exactly what is missing or needed." },
      "followups": {
        "type": "array",
        "description": "Route CANDIDATES only — never written to any BACKLOG.md by this agent. Omit or leave empty unless the task surfaced work that is genuinely not covered by this plan or an open plan folder, AND you can point at a concrete observed fact for it. Speculation and \"it would be nice if\" do not qualify. A bug introduced by THIS task is never a followup — fix it before returning DONE.",
        "items": {
          "type": "object",
          "additionalProperties": false,
          "required": ["description", "receipt", "strength"],
          "properties": {
            "description": { "type": "string", "description": "One line, as it would appear in BACKLOG.md." },
            "receipt": { "type": "string", "description": "The concrete observed fact, with a location: \"same off-by-one at handler.ts:88\", \"blocked needing IExportPort, which the plan never defines\"." },
            "strength": { "type": "string", "enum": ["clear", "ambiguous"], "description": "clear = the fact is unambiguous; ambiguous = a passing observation. When unsure, use ambiguous." },
            "size": { "type": "string", "enum": ["S", "M", "L"] },
            "because": { "type": "string", "description": "Deferral reason ONLY if this work genuinely must wait (blocked on something, sequenced after another feature, decision pending). Omit for work that could simply be done or planned next." }
          }
        }
      }
    }
  }
  ```
  If the schema-parity test later reports a difference, the template is the source of truth: copy the differing text from `TASK_RESULT` in `templates/execute-feature.workflow.js` into this file, never the other way round.
- [x] **Step 4 (implement the prompt builder):** Create `plugins/cogniva-dev/scripts/new-task-prompt.ps1`. The file is pure ASCII on purpose (the em dash and arrows the template uses are built with `[char]0x2014` / `[char]0x2192`), so its encoding can never change the bytes it prints:
  ```powershell
  #Requires -Version 7.0
  # Builds the task-agent prompt for ONE task - byte-for-byte the prompt that
  # templates/execute-feature.workflow.js builds for the same inputs (the
  # task-contract suite proves it). Used by the sequential executor in
  # skills/execute-feature/CODEX.md, so both executors hand workers the same text.
  # -TaskFile: a UTF-8 JSON file holding { "n", "title", "body" } for the task
  #   (other fields, such as parse-plan-tasks.ps1's isGate/done, are ignored).
  # -ResultContract: append the "=== RESULT ===" section that asks the worker to
  #   end its reply with one fenced json block conforming to
  #   templates/task-result.schema.json (the Workflow runtime enforces the schema
  #   itself, so the template has no such section).
  # Writes the prompt to stdout as UTF-8 without a BOM and without a trailing
  # newline. Exit 0 on success, 2 on a usage error.
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)][string]$Workspace,
      [Parameter(Mandatory)][string]$Branch,
      [Parameter(Mandatory)][ValidateSet('none', 'task', 'final')][string]$Commits,
      [string]$PlanPath,
      [string]$StatePath,
      [Parameter(Mandatory)][string]$TaskFile,
      [switch]$ResultContract
  )
  $ErrorActionPreference = 'Stop'

  function Fail([string]$Message) { [Console]::Error.WriteLine("new-task-prompt: $Message"); exit 2 }

  if (-not (Test-Path -LiteralPath $TaskFile -PathType Leaf)) { Fail "task file not found: $TaskFile" }
  try {
      $raw = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $TaskFile).ProviderPath, [System.Text.UTF8Encoding]::new($false))
      # System.Text.Json, not ConvertFrom-Json: it never turns date-like strings into dates.
      $task = [System.Text.Json.JsonDocument]::Parse($raw.TrimStart([char]0xFEFF)).RootElement
  }
  catch { Fail "task file is not valid JSON: $TaskFile" }

  function Get-TaskText([string]$Name) {
      $value = [System.Text.Json.JsonElement]::new()
      if (-not $task.TryGetProperty($Name, [ref]$value)) { Fail "task file has no '$Name'" }
      switch ($value.ValueKind) {
          'String' { return $value.GetString() }
          'Number' { return [string]$value.GetDouble() }
          default { Fail "task file '$Name' must be a string or a number" }
      }
  }
  $n = Get-TaskText 'n'
  $title = Get-TaskText 'title'
  $body = Get-TaskText 'body'

  # Mirrors the template's line array; $null entries are dropped like its
  # .filter(l => l !== null), and the lines are joined with "\n".
  $lines = [System.Collections.Generic.List[string]]::new()
  $lines.Add('Implement EXACTLY ONE task of a feature plan, then stop. Do not start the next task.')
  $lines.Add("Your only working directory is: $Workspace")
  $lines.Add("You are already checked out on $Branch. NEVER run git switch / checkout / branch " + [char]0x2014 + ' work where you are.')
  $lines.Add("Use absolute paths under the workspace. Follow the task's steps verbatim, TDD-style:")
  $lines.Add('write the failing test ' + [char]0x2192 + ' run it (confirm it fails) ' + [char]0x2192 + ' minimal implementation ' + [char]0x2192 + ' run until green ' + [char]0x2192 + " run the task's full verification.")
  if ($Commits -eq 'task') {
      if ($PlanPath) { $lines.Add("On success: FIRST edit $PlanPath to flip THIS task's checkboxes from `"- [ ]`" to `"- [x]`".") }
      $lines.Add("Then stage ONLY the files you changed and commit with the task's commit message (keep the repo's commit conventions).")
  }
  else {
      $lines.Add('Do NOT stage or commit anything: leave the files you changed in the working tree.')
      if ($PlanPath) { $lines.Add("On success: edit $PlanPath to flip THIS task's checkboxes from `"- [ ]`" to `"- [x]`".") }
  }
  if ($StatePath) { $lines.Add("Append one short line to ${StatePath}: created/modified paths, key decisions, and the commit SHA.") }
  $lines.Add('If you cannot finish cleanly, return status BLOCKED with a precise note and do NOT leave a partial commit.')
  $lines.Add('NEVER write to any BACKLOG.md. Fix any bug YOUR changes introduced before returning DONE ' + [char]0x2014 + ' an introduced defect is unfinished work, not a followup. If this task surfaced real work outside the plan, return it in "followups" with a concrete receipt (a located fact) ' + [char]0x2014 + ' the console routes it with the user (do now / plan next / defer with a reason). No receipt, no followup.')
  $lines.Add('')
  $lines.Add("=== TASK ${n}: $title ===")
  $lines.Add($body)
  $prompt = [string]::Join("`n", $lines)

  if ($ResultContract) {
      $schemaPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\templates\task-result.schema.json'))
      $contract = @(
          ''
          '=== RESULT ==='
          "End your reply with exactly one fenced ``````json block - the last fenced block in your reply - holding one JSON object that conforms to $schemaPath :"
          '- "status": required; exactly "DONE" or "BLOCKED".'
          '- "summary": required string; one or two lines: what changed.'
          '- "commitSha": string; the short SHA of the task commit. Include it only if you committed.'
          '- "note": string; exactly what is missing or needed. Include it only when "status" is "BLOCKED".'
          '- "followups": optional array; omit it or leave it empty unless this task surfaced real work outside the plan that you can tie to a concrete observed fact. Each item is an object with "description" (required; one line, as it would appear in BACKLOG.md), "receipt" (required; the observed fact, with a location), "strength" (required; "clear" or "ambiguous" - when unsure, "ambiguous"), "size" (optional; "S", "M" or "L") and "because" (optional; a deferral reason, only if the work genuinely must wait).'
          '- No other properties, at the top level or inside a followups item.'
          'A reply without that block, or whose block breaks these rules, is treated as BLOCKED.'
      )
      $prompt = $prompt + "`n" + [string]::Join("`n", $contract)
  }

  $stdout = [Console]::OpenStandardOutput()
  $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($prompt)
  $stdout.Write($bytes, 0, $bytes.Length)
  $stdout.Flush()
  exit 0
  ```
  If a prompt-parity case fails, the printed `first difference` shows the template text to copy; the template is the source of truth.
- [x] **Step 5 (wire the gate):** In `.claude/cogniva-dev/green-gate.json`, add a comma after the current LAST object of the `commands` array and append this object as the new last entry (after the `workflow-template` entry that the smoke-harness sub-plan added):
  ```json
      { "run": "pwsh -NoProfile -File plugins/cogniva-dev/tests/task-contract/task-contract.tests.ps1", "label": "task-contract", "note": "Pins the shared worker contract: the task-result schema equals the Workflow template's, new-task-prompt.ps1 prints the template's prompt byte-for-byte, and test-task-result.ps1 accepts only conforming replies; needs PowerShell 7 and node." }
  ```
  Validate the file: `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/validate-json.ps1 .claude/cogniva-dev/green-gate.json` → `OK   .claude/cogniva-dev/green-gate.json`.
- [x] **Step 6 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/task-contract/task-contract.tests.ps1` → all 24 matrix lines PASS (12 cases × exit 0 + identical prompt), the 5 extra prompt-parity checks PASS, `All task-contract assertions passed.`, exit 0. The comparison normalises only one trailing newline on the PowerShell side; nothing else.
- [x] **Step 7 (commit):** `git add plugins/cogniva-dev/templates/task-result.schema.json plugins/cogniva-dev/scripts/new-task-prompt.ps1 plugins/cogniva-dev/tests/task-contract/template-loader.mjs plugins/cogniva-dev/tests/task-contract/schema-parity.test.mjs plugins/cogniva-dev/tests/task-contract/prompt-parity.test.mjs plugins/cogniva-dev/tests/task-contract/task-contract.tests.ps1 .claude/cogniva-dev/green-gate.json` then `git commit -m "feat(execute-feature): shared task-result schema and prompt builder, parity-tested against the Workflow template"`

## Task 2: Result validator

**Files:**
- Create: `plugins/cogniva-dev/scripts/test-task-result.ps1`
- Modify: `plugins/cogniva-dev/tests/task-contract/task-contract.tests.ps1`

Constraints: PowerShell 7, no external modules (no Pester, no JSON-schema
module). `scripts/validate-json.ps1` only checks that a file parses, so it is
not reused. Validation is driven by `templates/task-result.schema.json` (the
keywords that file uses: `type`, `enum`, `required`, `properties`,
`additionalProperties`, `items`). Use `System.Text.Json`, not
`ConvertFrom-Json`, which turns date-like strings into dates. UTF-8 without a
BOM.

- [x] **Step 1 (failing tests):** In `plugins/cogniva-dev/tests/task-contract/task-contract.tests.ps1`, insert this block immediately BEFORE the line `if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }`:
  ```powershell
  # --- scripts/test-task-result.ps1 --------------------------------------------
  $validator = Join-Path $plugin 'scripts\test-task-result.ps1'
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-task-result-" + [guid]::NewGuid().ToString('N'))
  function Invoke-Validator([string]$Reply) {
      $file = Join-Path $root ("reply-" + [guid]::NewGuid().ToString('N') + '.md')
      [System.IO.File]::WriteAllText($file, $Reply, $script:utf8)
      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try { $lines = @(& pwsh -NoProfile -File $validator -ReplyFile $file 2>&1 | ForEach-Object { [string]$_ }); $code = $LASTEXITCODE }
      finally { $ErrorActionPreference = $previous }
      [pscustomobject]@{ Code = $code; Out = (($lines -join "`n").Trim()) }
  }
  $fence = '```'
  try {
      New-Item -ItemType Directory -Path $root -Force | Out-Null

      $r = Invoke-Validator "Done.`n`n${fence}json`n{ `"status`": `"DONE`", `"summary`": `"Added the parser.`", `"commitSha`": `"abc1234`" }`n${fence}`n"
      Check 'valid DONE: exit 0 and normalised JSON' ($r.Code -eq 0 -and $r.Out -eq '{"status":"DONE","summary":"Added the parser.","commitSha":"abc1234"}')

      $r = Invoke-Validator "${fence}json`n{ `"status`": `"BLOCKED`", `"summary`": `"`", `"note`": `"The plan never defines IExportPort.`" }`n${fence}"
      Check 'valid BLOCKED with note: exit 0' ($r.Code -eq 0 -and ($r.Out | ConvertFrom-Json).note -eq 'The plan never defines IExportPort.')

      $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"ok`", `"followups`": [ { `"description`": `"Same off-by-one in the exporter`", `"receipt`": `"exporter.ts:88`", `"strength`": `"clear`", `"size`": `"S`" }, { `"description`": `"Retry policy`", `"receipt`": `"client.ts:12 has none`", `"strength`": `"ambiguous`", `"because`": `"after FeatureX`" } ] }`n${fence}"
      Check 'valid followups: exit 0' ($r.Code -eq 0 -and @(($r.Out | ConvertFrom-Json).followups).Count -eq 2)

      $r = Invoke-Validator "${fence}json`n{ `"summary`": `"no status`" }`n${fence}"
      Check 'missing status: MALFORMED' ($r.Code -eq 1 -and $r.Out -match "^MALFORMED: .*missing required property 'status'")

      $r = Invoke-Validator "${fence}json`n{ `"status`": `"FINISHED`", `"summary`": `"x`" }`n${fence}"
      Check 'bad status enum: MALFORMED' ($r.Code -eq 1 -and $r.Out -match '^MALFORMED: result\.status is "FINISHED"')

      $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"x`", `"extra`": 1 }`n${fence}"
      Check 'extra top-level property: MALFORMED' ($r.Code -eq 1 -and $r.Out -match "^MALFORMED: .*'extra'")

      $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"x`", `"followups`": [ { `"description`": `"d`", `"receipt`": `"r`", `"strength`": `"clear`", `"owner`": `"me`" } ] }`n${fence}"
      Check 'extra followups item property: MALFORMED' ($r.Code -eq 1 -and $r.Out -match "^MALFORMED: result\.followups\[0\] has a property .*'owner'")

      $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"x`", `"followups`": [ { `"description`": `"d`", `"strength`": `"clear`" } ] }`n${fence}"
      Check 'followups item missing receipt: MALFORMED' ($r.Code -eq 1 -and $r.Out -match "^MALFORMED: result\.followups\[0\] is missing required property 'receipt'")

      $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": 5 }`n${fence}"
      Check 'wrong type: MALFORMED' ($r.Code -eq 1 -and $r.Out -match '^MALFORMED: result\.summary must be a string')

      $r = Invoke-Validator "DONE`nsummary: added the parser`n"
      Check 'no fenced block: MALFORMED' ($r.Code -eq 1 -and $r.Out -match '^MALFORMED: no fenced')

      $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"x`", }`n${fence}"
      Check 'invalid JSON: MALFORMED' ($r.Code -eq 1 -and $r.Out -match '^MALFORMED: the last json block is not valid JSON')

      $r = Invoke-Validator "First try:`n${fence}json`n{ `"status`": `"BLOCKED`", `"summary`": `"first`", `"note`": `"n`" }`n${fence}`nThen:`n${fence}json`n{ `"status`": `"DONE`", `"summary`": `"second`" }`n${fence}`n"
      Check 'two blocks: the last one wins' ($r.Code -eq 0 -and ($r.Out | ConvertFrom-Json).summary -eq 'second')

      $r = Invoke-Validator "I changed two files.`r`n`r`nHere is the result:`r`n${fence}JSON`r`n{`r`n  `"status`": `"DONE`",`r`n  `"summary`": `"caf$([char]0xE9) prose around the block`"`r`n}`r`n${fence}`r`nThanks.`r`n"
      Check 'prose around the block, CRLF and non-ASCII: exit 0' ($r.Code -eq 0 -and ($r.Out | ConvertFrom-Json).summary -eq "caf$([char]0xE9) prose around the block")

      $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"x`" }`n"
      Check 'an unclosed block is not a result: MALFORMED' ($r.Code -eq 1 -and $r.Out -match '^MALFORMED: no fenced')

      $r = Invoke-Validator "${fence}json`n{ `"status`": `"DONE`", `"summary`": `"2026-10-09T10:00:00`" }`n${fence}"
      Check 'a date-like summary stays a string' ($r.Code -eq 0 -and $r.Out -eq '{"status":"DONE","summary":"2026-10-09T10:00:00"}')

      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try { & pwsh -NoProfile -File $validator -ReplyFile (Join-Path $root 'missing.md') 2>&1 | Out-Null; $code = $LASTEXITCODE }
      finally { $ErrorActionPreference = $previous }
      Check 'a missing reply file is a usage error (exit 2)' ($code -eq 2)
  }
  finally {
      if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
  }

  ```
- [x] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/task-contract/task-contract.tests.ps1` → the two node checks still PASS; all 16 validator cases FAIL (the script does not exist yet, so `pwsh` exits non-zero with a "does not exist" error); `FAILED: 16 assertion(s).`, exit 1.
- [x] **Step 3 (implement):** Create `plugins/cogniva-dev/scripts/test-task-result.ps1`:
  ```powershell
  #Requires -Version 7.0
  # Validates a task agent's reply against the shared result contract
  # (templates/task-result.schema.json). Used by the sequential executor in
  # skills/execute-feature/CODEX.md; the Workflow runtime enforces the same
  # schema itself.
  # Takes the LAST closed fenced json block in -ReplyFile, parses it, and checks
  # it against the schema file: type, enum, required, properties,
  # additionalProperties false, and array items - the keywords that file uses.
  # No external modules.
  # Exit 0 + the normalised JSON (one line) on stdout when valid.
  # Exit 1 + "MALFORMED: <reason>" on stdout when there is no closed json block,
  #   the block is not valid JSON, or it breaks the schema.
  # Exit 2 on a usage error (reply file or schema file missing).
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)][string]$ReplyFile,
      [string]$SchemaPath
  )
  $ErrorActionPreference = 'Stop'

  function Fail([string]$Message) { [Console]::Error.WriteLine("test-task-result: $Message"); exit 2 }
  function Malformed([string]$Reason) { [Console]::Out.WriteLine("MALFORMED: $Reason"); exit 1 }

  if (-not $SchemaPath) { $SchemaPath = Join-Path $PSScriptRoot '..\templates\task-result.schema.json' }
  if (-not (Test-Path -LiteralPath $ReplyFile -PathType Leaf)) { Fail "reply file not found: $ReplyFile" }
  if (-not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) { Fail "schema file not found: $SchemaPath" }

  $utf8 = [System.Text.UTF8Encoding]::new($false)
  $reply = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $ReplyFile).ProviderPath, $utf8).TrimStart([char]0xFEFF)
  $schema = [System.Text.Json.JsonDocument]::Parse([System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $SchemaPath).ProviderPath, $utf8).TrimStart([char]0xFEFF)).RootElement

  # The last CLOSED fenced block whose opening fence is ```json (any case).
  $blocks = [System.Collections.Generic.List[string]]::new()
  $current = $null
  foreach ($line in ($reply -split "\r?\n")) {
      if ($null -eq $current) {
          if ($line -match '^\s*```\s*json\s*$') { $current = [System.Collections.Generic.List[string]]::new() }
      }
      elseif ($line -match '^\s*```\s*$') { $blocks.Add([string]::Join("`n", $current)); $current = $null }
      else { $current.Add($line) }
  }
  if ($blocks.Count -eq 0) { Malformed 'no fenced ```json block in the reply' }
  $text = $blocks[$blocks.Count - 1]

  try { $doc = [System.Text.Json.JsonDocument]::Parse($text) }
  catch { Malformed "the last json block is not valid JSON ($($_.Exception.InnerException.Message ?? $_.Exception.Message))" }

  function Get-Prop($Element, [string]$Name) {
      $value = [System.Text.Json.JsonElement]::new()
      if ($Element.ValueKind -eq 'Object' -and $Element.TryGetProperty($Name, [ref]$value)) { return , $value }
      return $null
  }
  function Test-Node($Value, $Rule, [string]$Where) {
      $type = Get-Prop $Rule 'type'
      if ($null -ne $type) {
          $expected = $type.GetString()
          $actual = switch ($Value.ValueKind) { 'Object' { 'object' } 'Array' { 'array' } 'String' { 'string' } 'Number' { 'number' } 'True' { 'boolean' } 'False' { 'boolean' } default { 'null' } }
          if ($actual -ne $expected) { Malformed "$Where must be a $expected, not a $actual" }
      }
      $enum = Get-Prop $Rule 'enum'
      if ($null -ne $enum) {
          $allowed = @($enum.EnumerateArray() | ForEach-Object { $_.GetRawText() })
          if ($allowed -notcontains $Value.GetRawText()) { Malformed "$Where is $($Value.GetRawText()); allowed: $($allowed -join ', ')" }
      }
      if ($Value.ValueKind -eq 'Object') {
          $properties = Get-Prop $Rule 'properties'
          $required = Get-Prop $Rule 'required'
          if ($null -ne $required) {
              foreach ($name in $required.EnumerateArray()) {
                  if ($null -eq (Get-Prop $Value $name.GetString())) { Malformed "$Where is missing required property '$($name.GetString())'" }
              }
          }
          $additional = Get-Prop $Rule 'additionalProperties'
          foreach ($property in $Value.EnumerateObject()) {
              $propertyRule = if ($null -ne $properties) { Get-Prop $properties $property.Name } else { $null }
              if ($null -eq $propertyRule) {
                  if ($null -ne $additional -and $additional.ValueKind -eq 'False') { Malformed "$Where has a property the contract does not allow: '$($property.Name)'" }
                  continue
              }
              Test-Node $property.Value $propertyRule "$Where.$($property.Name)"
          }
      }
      if ($Value.ValueKind -eq 'Array') {
          $items = Get-Prop $Rule 'items'
          if ($null -ne $items) {
              $index = 0
              foreach ($item in $Value.EnumerateArray()) { Test-Node $item $items "$Where[$index]"; $index++ }
          }
      }
  }

  Test-Node $doc.RootElement $schema 'result'

  $options = [System.Text.Json.JsonSerializerOptions]::new()
  $options.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
  $normalised = [System.Text.Json.JsonSerializer]::Serialize($doc.RootElement, $options)
  $stdout = [Console]::OpenStandardOutput()
  $bytes = $utf8.GetBytes($normalised + "`n")
  $stdout.Write($bytes, 0, $bytes.Length)
  $stdout.Flush()
  exit 0
  ```
- [x] **Step 4 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/task-contract/task-contract.tests.ps1` → every line PASS, `All task-contract assertions passed.`, exit 0. Also run the gate entry the way the green gate does: `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → the `[task-contract]` command exits 0 (the rest of the gate is expected to stay green too).
- [x] **Step 5 (commit):** `git add plugins/cogniva-dev/scripts/test-task-result.ps1 plugins/cogniva-dev/tests/task-contract/task-contract.tests.ps1` then `git commit -m "feat(execute-feature): test-task-result.ps1 validates worker replies against the shared result schema"`

## Task 3: CODEX.md loop on the shared contract, docs, pins, parity record, ADR

**Files:**
- Modify: `plugins/cogniva-dev/skills/execute-feature/CODEX.md`
- Modify: `plugins/cogniva-dev/docs/codex.md`
- Modify: `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`
- Modify: `docs/host-parity.md`
- Create: `docs/adr/NNNN-both-executors-share-one-worker-prompt-and-result-contract.md`

Context the task needs: `plugins/cogniva-dev/scripts/new-task-prompt.ps1`
(pwsh 7) prints the exact prompt the Workflow template builds for one task
(`-Workspace -Branch -Commits none|task|final [-PlanPath] [-StatePath]
-TaskFile <json with n,title,body> [-ResultContract]`); with `-ResultContract`
it appends a `=== RESULT ===` section asking for one fenced json block.
`plugins/cogniva-dev/scripts/test-task-result.ps1 -ReplyFile <path>` exits 0
with the normalised result JSON, 1 with `MALFORMED: <reason>`, 2 on a usage
error. The template logs one line per task:
`` `${tag} (${t.title}): ${res.status}${res.commitSha ? ' @' + res.commitSha : ''}` ``
where tag is `<subplan>/task-<n>` or `task-<n>`. The skill-semantics suite
runs under Windows PowerShell 5.1, which reads it as ANSI: every regex you add
must be ASCII-only. Do not use a bare "host" for Claude Code/Codex in new text:
say "agent host", or name the product.

- [x] **Step 1 (failing pins):** In `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`:
  1. Replace the assertion
     ```powershell
     Check 'Codex parity: both backends pass the task body verbatim' ($codexFlat -match 'full `body` VERBATIM' -and $tpl -match 't\.body')
     ```
     with
     ```powershell
     Check 'Codex parity: both backends send the same prompt, task body verbatim inside it' ($codexFlat -match '`body` VERBATIM' -and $codexFlat -match 'new-task-prompt\.ps1' -and $codexFlat -match 'stdout as its prompt VERBATIM' -and $tpl -match 't\.body')
     ```
  2. Immediately BEFORE the line `if ($failures.Count -gt 0) {`, add:
     ```powershell
     # --- shared worker prompt + result contract (both executors) ------------------
     Check 'CODEX.md builds every worker prompt with new-task-prompt.ps1 -ResultContract' ($codexFlat -match 'new-task-prompt\.ps1' -and $codexFlat -match '-ResultContract')
     Check 'CODEX.md sends the prompt verbatim with no added frame' ($codexFlat -match 'no paraphrase, no summary, no added frame or preamble')
     Check 'CODEX.md starts one fresh subagent per task without this conversation where it can' ($codexFlat -match 'Spawn ONE fresh subagent' -and $codexFlat -match 'WITHOUT this conversation''s history')
     Check 'CODEX.md validates every reply with test-task-result.ps1' ($codexFlat -match 'test-task-result\.ps1" -ReplyFile')
     Check 'CODEX.md: a malformed worker result is BLOCKED, never retried' ($codexFlat -match 'malformed worker result: <reason>' -and $codexFlat -match 'No retry, no re-prompt')
     Check 'CODEX.md prints the template status line after every task' ($codex -match '<tag> \(<title>\): <STATUS>\[ @<commitSha>\]')
     Check 'CODEX.md: under commits=task the worker ticked before committing; the executor verifies' ($codexFlat -match 'under `commits=task` it ticked them before its commit')
     Check 'CODEX.md: structured followups feed the backlog gate' ($codexFlat -match '`followups` arrive structured' -and $codexFlat -match 'backlog gate')
     Check 'CODEX.md no longer parses a textual first line' ($codex -notmatch 'first line of exactly' -and $codex -notmatch 'Parse the subagent''s first line')
     Check 'docs/codex.md: the Codex backend uses the shared JSON result contract' ($docs -match 'task-result\.schema\.json' -and $docs -match 'new-task-prompt\.ps1' -and $docs -notmatch 'textual `DONE` / `BLOCKED` result contract')
     ```
  3. Find every other assertion that reads `$codex` or `$codexFlat` (`Select-String -Path plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1 -Pattern 'codex'`). The ones present at planning time — `PLANLESS tasks`, `quick-fix ... its own Step 2`, `task with no planPath ... nothing to tick`, `## Repository CLAUDE.md under Codex`, `ever overrides commits=`, `quick-fix also runs its structural check` — match text this task keeps, so they stay unchanged. If an earlier sub-plan added a pin on wording that Step 3 below replaces (the textual `DONE`/`BLOCKED` reply, "Parse the subagent's first line", "full `body` VERBATIM", the frame bullets), replace that assertion with one on the new text in the same way as item 1 — never just delete it. Assertions on `$docs` that the parity-record sub-plan added (`docs/codex.md no longer claims runtime verification`, `docs/codex.md: hooks under Codex …`) cover text this task does not touch and stay unchanged.
- [x] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → FAIL on the replaced parity pin and on each new pin except possibly none; `FAILED: 11 assertion(s).`, exit 1.
- [x] **Step 3 (rewrite the loop in CODEX.md):** In `plugins/cogniva-dev/skills/execute-feature/CODEX.md`, replace everything from the line `## Replaces Step 3 — sequential subagent loop` up to (NOT including) the line `## Sequencing rules` with the text below. Keep the file's introduction and every later section (`## Sequencing rules`, `## After the loop`, `## Resume`, `## Repository CLAUDE.md under Codex`, `## Never emulate the missing runtime`) exactly as they are.
  ````markdown
  ## Replaces Step 3 — sequential subagent loop

  You are the executor. Both executors hand task agents the same prompt and
  read the same result shape: the prompt comes from
  `<plugin>/scripts/new-task-prompt.ps1`, kept identical by test to the prompt
  the Workflow template builds, and the result is one JSON object conforming
  to `<plugin>/templates/task-result.schema.json` — the schema the template
  passes to its agents — checked by `<plugin>/scripts/test-task-result.ps1`.
  `<plugin>` = this plugin's root (the parent of `skills/`).

  For each task in the parsed array that is not `done`, in order:

  1. Write the task as JSON — `{ "n": <n>, "title": "<title>", "body": "<body>" }`
     with the task's full `body` VERBATIM (the parser's own object for the
     task works as is; extra fields are ignored) — to a temp file in the
     system temp directory, never inside the repo.
  2. Build the prompt:
     `pwsh -NoProfile -File "<plugin>/scripts/new-task-prompt.ps1" -Workspace "<WORKSPACE>" -Branch "<BRANCH>" -Commits <policy> -TaskFile "<task file>" -ResultContract`,
     adding `-PlanPath "<the task's planPath>"` when the task has one (a
     planless quick-fix task has none) and `-StatePath "<state.md>"` only
     when the run has one. `<policy>` is the ACTIVE commit policy resolved
     from `## Flags` in `SKILL.md` (lean default `none`); the script writes
     the matching rule into the prompt — under `task`: tick this task's
     checkboxes in its `planPath` first, then stage only its own files and
     commit; under `none`/`final`: stage and commit nothing. A non-zero exit
     → stop and show its output; never hand-write a prompt instead.
  3. Spawn ONE fresh subagent and send the script's stdout as its prompt
     VERBATIM — no paraphrase, no summary, no added frame or preamble. Where
     the agent host lets you choose, start it WITHOUT this conversation's
     history.
  4. Wait for that subagent to finish before doing anything else. A git
     failure under `task`/`final` comes back as the worker's `BLOCKED`, with
     the git error as its `note`; no retry loops.

  ## After each task

  Save the subagent's whole reply to a temp file in the system temp
  directory and run
  `pwsh -NoProfile -File "<plugin>/scripts/test-task-result.ps1" -ReplyFile "<reply file>"`.
  Delete both temp files once the task's result is recorded.

  - Exit 1 (`MALFORMED: <reason>`) → the task is `BLOCKED` with the note
    `malformed worker result: <reason>`. No retry, no re-prompt — the same
    rule as the Workflow template's null result. Exit 2 means the validator
    command itself was wrong: fix the command and re-run the validator, never
    the task.
  - Exit 0 → stdout is the result (`status`, `summary`, and where present
    `commitSha`, `note`, `followups`). Then:
    - `DONE` → the worker's prompt told it to tick its own checkboxes in its
      `planPath` (under `commits=task` it ticked them before its commit):
      verify they are all `- [x]` and tick any it missed, record the result,
      and dispatch the next task. A task with no `planPath` (planless
      quick-fix) has nothing to tick — just record the result and move on.
    - `BLOCKED` → stop the loop; report which task and its `note`.
    - Task `isGate` (`⛔`) and `DONE` → stop the loop after it and report the
      gate. The user resolves it and re-runs the skill to continue.
  - After every task print one status line, the line the Workflow template
    logs: `<tag> (<title>): <STATUS>[ @<commitSha>]` — `<tag>` is
    `<subplan>/task-<n>` for a sub-plan task, else `task-<n>`; the
    ` @<commitSha>` part only when the result carries one.
  - `followups` arrive structured (`description`, `receipt`, `strength`, and
    optionally `size` and `because`). Collect them from every result and run
    the backlog gate on them exactly as `SKILL.md` defines it: at a ⛔ gate or
    `BLOCKED` stop as its Step 3 says, otherwise at landing.

  ````
- [x] **Step 4 (apply the diagnostics remedies that belong here, and only those):** Open `docs/host-parity/codex-diagnostics.md` and find its triage table (the decision table whose rows name a finding, a remedy and a `Where` column giving the sub-plan that applies it). Apply exactly the rows whose `Where` is `07`, as follows, and skip every other row. If no row says `07`, change nothing in this step and note "no 07 remedies selected" in the commit message body.
  - A selected row whose remedy is an **inline fallback** (the agent host cannot start subagents on that surface, e.g. Codex in VS Code) → insert this paragraph at the END of the `## Replaces Step 3 — sequential subagent loop` section (after item 4, before `## After each task`):
    ```markdown
    **Inline fallback (no subagents on this surface).** If this agent host
    cannot start a subagent here, run each task yourself, in order, from the
    exact prompt `new-task-prompt.ps1` printed: do the task, end your work
    with the fenced json block that prompt asks for, save it to a temp file,
    and validate it with `test-task-result.ps1` exactly as below. Say
    `inline execution — no fresh context per task` in the run's first status
    line and list it under Risks / limitations / assumptions in the handoff.
    The Codex CLI is the recommended surface for execution.
    ```
  - A selected row whose remedy is about subagents **inheriting this conversation's history** → append this sentence to the end of item 3 of that section (after "…start it WITHOUT this conversation's history."):
    ```markdown
    If this surface offers no way to start a subagent without this
    conversation's history, say so in the run's first status line and list
    `workers saw the executor's conversation` under Risks / limitations /
    assumptions in the handoff.
    ```
  For each paragraph inserted, add one pin immediately before `if ($failures.Count -gt 0) {` in the skill-semantics suite: `Check 'CODEX.md carries the inline fallback (diagnostics remedy)' ($codexFlat -match 'Inline fallback \(no subagents on this surface\)')` and/or `Check 'CODEX.md reports workers that saw the executor conversation (diagnostics remedy)' ($codexFlat -match 'workers saw the executor''s conversation')`.
- [x] **Step 5 (docs/codex.md):** In `plugins/cogniva-dev/docs/codex.md`, under `## Backend selection`, replace the whole bullet that begins `- **Codex** — the Workflow tool does not exist.` (through its last line, `no parallelism.`) with:
  ```markdown
  - **Codex** — the Workflow tool does not exist. When a skill detects that the
    Workflow tool is unavailable in the session, it follows its `CODEX.md` overlay
    instead: a **sequential loop of fresh subagents**, one per task. Both
    executors share one worker contract: each prompt is built by
    `scripts/new-task-prompt.ps1` (kept byte-identical by test to the prompt the
    Workflow template builds), and each reply ends with one JSON result that
    conforms to `templates/task-result.schema.json` (kept equal by test to the
    schema the Workflow template passes to its agents) and is checked by
    `scripts/test-task-result.ps1`; a malformed reply counts as `BLOCKED`. Tasks
    run strictly in order in the same workspace; there is no reviewer fan-out
    and no parallelism.
  ```
  If an earlier sub-plan reworded that bullet, replace the bullet under `## Backend selection` that describes the Codex backend, whatever its current wording.
- [x] **Step 6 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`, exit 0.
- [x] **Step 7 (write ADR):** scan `docs/adr/` for the next free number (the highest at planning time was 0050; earlier sub-plans of this feature add more) and write ADR-C4 from this sub-plan's `## Candidate ADRs` verbatim — heading `# Both executors share one worker prompt and result contract` (no `ADR-C4` label), the `**Provenance:** Suggested by agent` line, then the body paragraph — to `docs/adr/NNNN-both-executors-share-one-worker-prompt-and-result-contract.md` per `plugins/cogniva-dev/skills/adr/ADR-FORMAT.md`. Run `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/check-adrs.ps1 -Workspace .` → exit 0.
- [x] **Step 8 (parity record):** In `docs/host-parity.md` `## Capabilities` (columns `| ID | Capability | Kind | Covers | Claude Code | Codex | Evidence | Notes |`; a status cell is `<status> — <mechanism>`), edit the rows `lean-mode`, `execute-feature` and `quick-fix` (the rows whose `Covers` are `mode:lean`, `skill:cogniva-dev/execute-feature`, `skill:cogniva-dev/quick-fix`). Do not change any status word in this sub-plan — statuses are earned from smoke evidence at the acceptance gate.
  - `Codex` cell: keep the status word; replace the mechanism after ` — ` with `CODEX.md loop on the shared prompt/result contract`.
  - `Claude Code` cell: keep the status word; replace the mechanism with `Workflow template (same prompt/result contract)`.
  - `Evidence`: append `, gate:task-contract`.
  - `execute-feature` row `Notes`: replace the sentence that begins `Task results differ by agent host` (through the end of that sentence) with `Both agent hosts give workers the same prompt (new-task-prompt.ps1) and check the same result schema (task-result.schema.json); a malformed Codex reply is BLOCKED (ADR NNNN).` using the number from Step 7. If that sentence is not there, append the new sentence to the row's Notes instead.
  In `## Intentional asymmetries`, in the bullet for `lean-mode`, `execute-feature`, `quick-fix`, add after its first sentence: ` Both use the same worker prompt and result schema, kept equal by the task-contract suite (ADR NNNN).`
  Then `pwsh -NoProfile -File scripts/check-host-parity.ps1` → a `host-parity: OK - …` line, exit 0.
- [x] **Step 9 (host-neutrality ratchet):** `pwsh -NoProfile -File scripts/check-host-neutrality.ps1` → `host-neutrality: OK - …`, exit 0. It counts host-specific tokens (`AskUserQuestion`, `Workflow(`, `subagent_type`, `apply_patch`, `/cogniva-dev:`, …) in shared skill Markdown and plugin `scripts/*.ps1`, and leaves out `CODEX.md` and `docs/`, so this task's new scripts are the only files in scope. A `FAIL host-token-…` line for `new-task-prompt.ps1` or `test-task-result.ps1` → reword the comment or text it names. An `INFO lower the baseline` line → run `pwsh -NoProfile -File scripts/check-host-neutrality.ps1 -Update` and stage `scripts/host-neutrality-baseline.json` with this commit.
- [x] **Step 10 (commit):** `git add plugins/cogniva-dev/skills/execute-feature/CODEX.md plugins/cogniva-dev/docs/codex.md plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1 docs/host-parity.md docs/adr` (plus `scripts/host-neutrality-baseline.json` if Step 9 updated it) then `git commit -m "feat(execute-feature): Codex loop uses the shared worker prompt and validates JSON results"`
