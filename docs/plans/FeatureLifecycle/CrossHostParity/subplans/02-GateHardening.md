# 02 GateHardening — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/CrossHostParity
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** The green gate runs every existing plugin suite, catches a plugin
that ships only one agent host's manifest or a skill folder that does not match
its `SKILL.md`, reports a single `AGENTS.md`/`CLAUDE.md` correctly, and pins the
primary-checkout hooks' real behaviour for Claude Code payloads while recording
today's Codex `apply_patch` gap as an explicit, labelled assertion.

**Architecture:** Four independent hardening steps, each ending in new
green-gate entries. (1) The `git-commit` suite's Windows PowerShell 5.1 failure
is a test-harness quoting bug, not a script bug; the test is fixed and five
existing suites are gated. (2) `resolve-applicable-rules.ps1` (stays 5.1) wraps
its authority-chain call sites in `@()` so a one-file chain stays an array.
(3) `scripts/check-plugin-manifests.ps1` (stays 5.1) gains `-Root` and three
new failure classes, proven by a new pwsh 7 fixture suite. (4) A new pwsh 7
suite drives `guard-primary-edit.js`, `guard-primary-git.js` and
`nudge-backlog-commit.js` with stdin payloads against a temp repo and a linked
worktree.

**Read these first:** `plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1`,
`plugins/cogniva-dev/scripts/git-commit.ps1`,
`plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1` (`Get-AuthorityChain`, the per-target loop, the text output),
`plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1`,
`scripts/check-plugin-manifests.ps1`, `plugins/cogniva-dev/hooks/hooks.json`,
`plugins/cogniva-dev/scripts/guard-primary-edit.js`, `guard-primary-git.js`,
`nudge-backlog-commit.js`, `worktree-mode.js`,
`plugins/cogniva-dev/tests/module-deps/guard-module-cycles.tests.ps1` (stdin-payload pattern),
`.claude/cogniva-dev/green-gate.json`.

Facts verified while planning (2026-10-09, HEAD 0c499d1):
- `git-commit.tests.ps1` under Windows PowerShell 5.1 stops with `A positional parameter cannot be found that accepts argument 'and'.` (5.1 passes the message's embedded `"` to the child unescaped). A second 5.1-only failure hides behind it: the error-path case runs `& powershell … 2>$null` under `$ErrorActionPreference = 'Stop'`, and 5.1 turns the redirected stderr line into a terminating `NativeCommandError`. Under pwsh 7 all six assertions pass. `git-commit.ps1` is correct (it already writes the message to a file and commits with `-F`).
- `integrate-feature`, `ledger`, `parse-plan-tasks`, `validate-json` suites pass under Windows PowerShell 5.1 today; their files are `plugins/cogniva-dev/tests/<suite>/<suite>.tests.ps1`.
- In Windows PowerShell 5.1, `return ,$result` combined with `@(...)` at the call site NESTS a multi-element array (`@(f).Count` is 1 when `f` returns `,@('a','b')`), which would break the existing two-AGENTS.md case. So the singleton fix uses `@()` at the two call sites only.
- The hooks allow by exiting 0 with NO stdout; they deny by printing `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny",…}}` and exiting 0; the nudge prints `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"The tier-1 backlog file … is now UNCOMMITTED in the PRIMARY checkout. …"}}`. The edit hooks read only `tool_input.file_path`/`notebook_path`, so a Codex `apply_patch` payload (patch text in `tool_input.command`) gets no decision.

## File structure (locked)

```
plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1              # 5.1-safe quoting + stderr case; body-quote assertion
plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1  # single AGENTS.md + CLAUDE.md regression
plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1               # @() at the authority-chain call sites (stays 5.1)
scripts/check-plugin-manifests.ps1                                     # -Root; both manifests; Codex skills path; skill folder = SKILL.md name (stays 5.1)
plugins/cogniva-dev/tests/manifests/check-plugin-manifests.tests.ps1   # NEW pwsh 7 fixture suite for the checker
plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1                # NEW pwsh 7 suite: primary-checkout hooks, Codex gap pinned
.claude/cogniva-dev/green-gate.json                                    # + git-commit, integrate-feature, ledger, parse-plan-tasks, validate-json, manifest-checker, primary-hooks
```

## Task 1: Fix the git-commit suite under Windows PowerShell 5.1 and gate the five ungated suites

**Files:**
- Modify: `plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1`
- Modify: `.claude/cogniva-dev/green-gate.json`

Why this fix: real callers (the backlog skill and the nudge hook's suggested command) run `git-commit.ps1` as a separate `powershell -File` process, so the test must keep doing that rather than calling the script in-process (`& $script`), which would skip command-line parsing entirely and stop exercising the path callers use. The test instead escapes the message the way the Windows command-line convention expects (`\"`, with any backslashes before a quote doubled) — only under Windows PowerShell 5.1, because PowerShell 7 already does that escaping itself. `git-commit.ps1` is NOT changed. Do not touch any `BACKLOG.md`.

- [ ] **Step 1 (confirm the failure):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1` → exit 1 with `A positional parameter cannot be found that accepts argument 'and'.` and `You cannot call a method on a null-valued expression.`; `pwsh -NoProfile -File plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1` → `All git-commit assertions passed.`
- [ ] **Step 2 (fix the test):** Replace the whole of `plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1` with the text below. Save it as UTF-8 WITH a byte-order mark (the file has one today): the message literal contains an em-dash, which Windows PowerShell 5.1 misreads without the BOM.
  ```powershell
  # Dependency-free regression test for git-commit.ps1 (no Pester).
  # Exits 0 only if every assertion passes; exits 1 and prints failures otherwise.
  $ErrorActionPreference = 'Stop'
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

  $here   = Split-Path -Parent $MyInvocation.MyCommand.Path
  $script = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\scripts\git-commit.ps1'))

  $failures = @()
  function Check($label, $cond) {
      if ($cond) { Write-Host "  PASS  $label" }
      else { Write-Host "  FAIL  $label"; $script:failures += $label }
  }

  # Throwaway git repo under TEMP.
  $repo = Join-Path ([System.IO.Path]::GetTempPath()) ("gc-test-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $repo | Out-Null
  try {
      & git -C $repo init -q
      & git -C $repo config user.name  'Test'
      & git -C $repo config user.email 'test@example.com'
      Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'hello' -NoNewline

      # Multi-line commit message — the exact shape that defeats the raw matcher.
      $msg = "feat(x): add a thing`n`nBody line with a quote `" and an em-dash —."
      # Windows PowerShell 5.1 hands a native child an embedded `"` without escaping it,
      # so the child's command line would end the argument there. Escape it the way the
      # Windows command-line convention expects (backslashes before a quote are doubled,
      # the quote becomes \"). PowerShell 7 does this itself, so leave it alone there.
      # The script still runs as a separate `powershell -File` process, as real callers run it.
      $msgArg = $msg
      if ($PSVersionTable.PSVersion.Major -lt 7) { $msgArg = $msg -replace '(\\*)"', '$1$1\"' }
      $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $script -RepoPath $repo -Path 'a.txt' -Message $msgArg
      $sha = ($out | Select-Object -Last 1).Trim()

      Check 'exit 0'                       ($LASTEXITCODE -eq 0)
      Check 'prints a short sha (7-12 hex)' ($sha -match '^[0-9a-f]{7,12}$')
      $log = (& git -C $repo log --oneline) -join "`n"
      Check 'one commit exists'            (($log -split "`n").Count -eq 1)
      Check 'subject is the first msg line' ($log -match 'feat\(x\): add a thing')
      $body = (& git -C $repo log -1 --format=%B) -join "`n"
      Check 'body keeps the embedded quote' ($body -match 'Body line with a quote " and an em-dash')
      $status = (& git -C $repo status --porcelain) -join "`n"
      Check 'working tree clean after commit' ([string]::IsNullOrWhiteSpace($status))

      # Error path: no -Path and no -All -> non-zero exit.
      # Windows PowerShell 5.1 turns redirected native stderr into an error record, which
      # 'Stop' would throw on; the exit code is what this case asserts.
      $ErrorActionPreference = 'Continue'
      & powershell -NoProfile -ExecutionPolicy Bypass -File $script -RepoPath $repo -Message 'x' 2>$null
      $code = $LASTEXITCODE
      $ErrorActionPreference = 'Stop'
      Check 'errors when neither -Path nor -All given' ($code -ne 0)
  }
  finally {
      Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
  }

  if ($failures.Count -gt 0) {
      Write-Host ""
      Write-Host "FAILED: $($failures.Count) assertion(s)."
      exit 1
  }
  Write-Host ""
  Write-Host "All git-commit assertions passed."
  exit 0
  ```
- [ ] **Step 3 (run until green, both shells):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1` → seven PASS lines and `All git-commit assertions passed.`; `pwsh -NoProfile -File plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1` → the same.
- [ ] **Step 4 (gate the five suites):** In `.claude/cogniva-dev/green-gate.json`, append these five entries, in this order, at the END of the `commands` array: add a comma after the closing `}` of the current last entry, then insert these lines before the array's closing `  ]` (no comma after the last one):
  ```json
      { "run": "powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1", "label": "git-commit", "note": "Pins git-commit.ps1: a path-scoped commit whose multi-line message, embedded quote included, survives a separate Windows PowerShell process." },
      { "run": "powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/integrate-feature/integrate-feature.tests.ps1", "label": "integrate-feature", "note": "Pins worktree integration: fast-forward or worktree-side merge, a conflict leaves both branches untouched, and no remote is used." },
      { "run": "powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/ledger/ledger.tests.ps1", "label": "ledger", "note": "Pins the worktree ledger: comma-joined cleanup scopes, path normalisation without duplicate records, UTF-8 writes." },
      { "run": "powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/parse-plan-tasks/parse-plan-tasks.tests.ps1", "label": "parse-plan-tasks", "note": "Pins plan parsing for execution and resume: task boundaries, checkbox state, nested fences." },
      { "run": "powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/validate-json/validate-json.tests.ps1", "label": "validate-json", "note": "Pins validate-json.ps1 exit codes for valid, invalid and missing files." }
  ```
  Then `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/validate-json.ps1 .claude/cogniva-dev/green-gate.json` → exit 0.
- [ ] **Step 5 (run the gated subset):** run each of the five `run` commands above from the repo root, one at a time → each exits 0 and ends with its all-passed line (`All git-commit assertions passed.`, `integrate-feature tests passed`, `All ledger assertions passed.`, `All parse-plan-tasks assertions passed.`, `All validate-json assertions passed.`).
- [ ] **Step 6 (commit):** `git add plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1 .claude/cogniva-dev/green-gate.json` then `git commit -m "test(git-commit): escape the message for Windows PowerShell 5.1; gate five existing suites"`

## Task 2: applicable-rules reports a single AGENTS.md or CLAUDE.md by its whole path

**Files:**
- Modify: `plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1`
- Test: `plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1`

`resolve-applicable-rules.ps1` must stay Windows PowerShell 5.1-compatible (no `??`, `?:`, `-Parallel`, or pwsh-only APIs). Today `Get-AuthorityChain` ends `return $result`; a one-file chain unrolls to a string, `$agents[$index]` takes its first character, and the text output prints `EFFECTIVE AUTHORITY: [1] AGENTS.md: C; [2] CLAUDE.md: C`. The existing suite only covers a two-AGENTS.md chain.

- [ ] **Step 1 (failing test):** In `plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1`, insert this block inside the outer `try`, directly after the line `    Check 'without pwsh the profile is UNAVAILABLE and the decision is unchanged' (…)` and before the line `    # --- profile-driven placement (needs pwsh to adopt the shipped dotnet profile) ---`:
  ```powershell
      # --- a single AGENTS.md and a single CLAUDE.md are reported by their whole paths ---
      $single = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-applicable-single-" + [guid]::NewGuid().ToString('N'))
      try {
          New-Item -ItemType Directory -Path $single -Force | Out-Null
          & git -C $single init -q
          Set-Content -LiteralPath (Join-Path $single 'AGENTS.md') -Encoding UTF8 -Value "# Rules`n`n- Hosts are composition roots only."
          Set-Content -LiteralPath (Join-Path $single 'CLAUDE.md') -Encoding UTF8 -Value "@AGENTS.md"
          $singleFull = (Get-Item -LiteralPath $single).FullName
          $singleAgents = Join-Path $singleFull 'AGENTS.md'
          $singleClaude = Join-Path $singleFull 'CLAUDE.md'
          $s = (& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $single -Target 'docs/readme.md' -Purpose 'documentation' -Format Json) | ConvertFrom-Json
          Check 'one AGENTS.md and one CLAUDE.md: two authority entries' (@($s.Targets[0].EffectiveAuthority).Count -eq 2)
          Check 'a single AGENTS.md is reported by its whole path' ($s.Targets[0].EffectiveAuthority[0].Source -eq 'AGENTS.md' -and $s.Targets[0].EffectiveAuthority[0].Path -eq $singleAgents)
          Check 'a single CLAUDE.md is reported by its whole path' ($s.Targets[0].EffectiveAuthority[1].Source -eq 'CLAUDE.md' -and $s.Targets[0].EffectiveAuthority[1].Path -eq $singleClaude -and $s.Targets[0].EffectiveAuthority[1].Order -eq 2)
          $singleLines = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $single -Target 'docs/readme.md' -Purpose 'documentation')
          Check 'text output names both files whole' ($singleLines -contains "  EFFECTIVE AUTHORITY: [1] AGENTS.md: $singleAgents; [2] CLAUDE.md: $singleClaude")
          Check 'text output has no first-character path' (@($singleLines | Where-Object { $_ -match '\.md: C(;|\s*$)' }).Count -eq 0)
      }
      finally { if (Test-Path -LiteralPath $single) { Remove-Item -LiteralPath $single -Recurse -Force } }

  ```
  (The resolver reports `Path` as the full file path: `Join-Path <repo FullName> 'AGENTS.md'`, the same form the existing nested-AGENTS.md assertion matches.)
- [ ] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1` → exit 1 with `PASS  one AGENTS.md and one CLAUDE.md: two authority entries` and FAIL on `a single AGENTS.md is reported by its whole path`, `a single CLAUDE.md is reported by its whole path`, `text output names both files whole`, `text output has no first-character path`; every other check still PASSes.
- [ ] **Step 3 (implement):** In `plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1`, in the per-target loop, replace
  ```powershell
      $agents = Get-AuthorityChain $repoFull $directory 'AGENTS.md'
      $claudes = Get-AuthorityChain $repoFull $directory 'CLAUDE.md'
  ```
  with
  ```powershell
      # @() keeps a one-file chain an array; unrolled to a string, $agents[$index]
      # would be its first character. (Do not also return ,$result from
      # Get-AuthorityChain: with @() here that nests a multi-file chain.)
      $agents = @(Get-AuthorityChain $repoFull $directory 'AGENTS.md')
      $claudes = @(Get-AuthorityChain $repoFull $directory 'CLAUDE.md')
  ```
  Leave `Get-AuthorityChain` itself (`return $result`) unchanged.
- [ ] **Step 4 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1` → every line PASS, ending `All applicable-rules assertions passed.` (the existing `resolver reports effective authority order and nested precedence` check, with two AGENTS.md files, still passes — it is the guard against nesting). Also `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/run-gate-check/run-gate-check.tests.ps1` → exit 0 (gate-check calls applicable-rules).
- [ ] **Step 5 (commit):** `git add plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1 plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1` then `git commit -m "fix(applicable-rules): report a single AGENTS.md or CLAUDE.md by its whole path"`

## Task 3: The manifest checker requires both manifests and checks skill coverage

**Files:**
- Modify: `scripts/check-plugin-manifests.ps1`
- Create: `plugins/cogniva-dev/tests/manifests/check-plugin-manifests.tests.ps1`
- Modify: `.claude/cogniva-dev/green-gate.json`

`scripts/check-plugin-manifests.ps1` stays Windows PowerShell 5.1-compatible (no `??`, `?:`, pwsh-only APIs) because the gate's `manifest-parity` command runs it with `powershell`. The new suite is PowerShell 7 and runs the checker under `powershell` (5.1), as the gate does.

- [ ] **Step 1 (failing test):** Create `plugins/cogniva-dev/tests/manifests/check-plugin-manifests.tests.ps1` with exactly:
  ```powershell
  # Dependency-free tests for scripts/check-plugin-manifests.ps1 (no Pester).
  # Builds fixture marketplaces under TEMP and runs the checker against each with
  # -Root, under Windows PowerShell 5.1 (the shell the green gate runs it in).
  # PowerShell 7.
  $ErrorActionPreference = 'Stop'
  $here = Split-Path -Parent $MyInvocation.MyCommand.Path
  $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\..\..'))
  $checker = Join-Path $repoRoot 'scripts\check-plugin-manifests.ps1'
  $base = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-manifests-" + [guid]::NewGuid().ToString('N'))
  $failures = @()
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

  function Check($label, $condition) {
      if ($condition) { Write-Host "  PASS  $label" }
      else { Write-Host "  FAIL  $label"; $script:failures += $label }
  }
  function Write-Text([string]$Path, [string]$Text) {
      New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
      [System.IO.File]::WriteAllText($Path, $Text, $script:utf8NoBom)
  }
  # A clean one-plugin marketplace: both manifests, a matching marketplace entry, one skill.
  function New-Fixture([string]$Name) {
      $root = Join-Path $script:base $Name
      Write-Text (Join-Path $root '.claude-plugin\marketplace.json') '{ "name": "fixture", "plugins": [ { "name": "demo", "source": "./plugins/demo", "version": "1.2.0" } ] }'
      Write-Text (Join-Path $root 'plugins\demo\.claude-plugin\plugin.json') '{ "name": "demo", "version": "1.2.0", "description": "Demo plugin.", "keywords": ["a", "b"] }'
      Write-Text (Join-Path $root 'plugins\demo\.codex-plugin\plugin.json') '{ "name": "demo", "version": "1.2.0", "description": "Demo plugin.", "keywords": ["a", "b"], "skills": "./skills/" }'
      Write-Text (Join-Path $root 'plugins\demo\skills\hello\SKILL.md') "---`nname: hello`ndescription: Says hello.`n---`n`n# Hello`n"
      return $root
  }
  function Invoke-Checker([string]$Root) {
      $previous = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try {
          $lines = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $script:checker -Root $Root 2>&1)
          $code = $LASTEXITCODE
      }
      finally { $ErrorActionPreference = $previous }
      [pscustomobject]@{ Code = $code; Out = ((@($lines | ForEach-Object { [string]$_ }) -join "`n").Trim()) }
  }

  try {
      $r = Invoke-Checker (New-Fixture 'clean')
      Check 'a clean fixture passes' ($r.Code -eq 0 -and $r.Out -match 'manifest parity OK: 1 plugin\(s\) checked')

      $root = New-Fixture 'no-codex'
      Remove-Item -LiteralPath (Join-Path $root 'plugins\demo\.codex-plugin') -Recurse -Force
      $r = Invoke-Checker $root
      Check 'a missing Codex manifest fails' ($r.Code -eq 1 -and $r.Out -match 'demo: missing \.codex-plugin/plugin\.json')

      $root = New-Fixture 'bad-skills-path'
      Write-Text (Join-Path $root 'plugins\demo\.codex-plugin\plugin.json') '{ "name": "demo", "version": "1.2.0", "description": "Demo plugin.", "keywords": ["a", "b"], "skills": "./skill/" }'
      $r = Invoke-Checker $root
      Check 'a Codex skills path that misses skills/ fails' ($r.Code -eq 1 -and $r.Out -match 'does not resolve to the plugin''s skills/ directory')

      $root = New-Fixture 'no-skills-key'
      Write-Text (Join-Path $root 'plugins\demo\.codex-plugin\plugin.json') '{ "name": "demo", "version": "1.2.0", "description": "Demo plugin.", "keywords": ["a", "b"] }'
      $r = Invoke-Checker $root
      Check 'a Codex manifest without skills fails' ($r.Code -eq 1 -and $r.Out -match 'has no "skills" path')

      $root = New-Fixture 'name-mismatch'
      Write-Text (Join-Path $root 'plugins\demo\skills\hello\SKILL.md') "---`nname: hello-world`ndescription: Says hello.`n---`n"
      $r = Invoke-Checker $root
      Check 'a skill whose frontmatter name differs from its folder fails' ($r.Code -eq 1 -and $r.Out -match "skills/hello/SKILL\.md frontmatter name is 'hello-world', expected 'hello'")

      $root = New-Fixture 'no-skill-file'
      New-Item -ItemType Directory -Path (Join-Path $root 'plugins\demo\skills\empty') -Force | Out-Null
      $r = Invoke-Checker $root
      Check 'a skill folder without SKILL.md fails' ($r.Code -eq 1 -and $r.Out -match 'skills/empty/ has no SKILL\.md')

      $root = New-Fixture 'version-mismatch'
      Write-Text (Join-Path $root 'plugins\demo\.codex-plugin\plugin.json') '{ "name": "demo", "version": "1.3.0", "description": "Demo plugin.", "keywords": ["a", "b"], "skills": "./skills/" }'
      $r = Invoke-Checker $root
      Check 'a version mismatch still fails' ($r.Code -eq 1 -and $r.Out -match 'demo: version mismatch')

      $r = Invoke-Checker $repoRoot
      Check 'this repository passes' ($r.Code -eq 0)
  }
  finally {
      if (Test-Path -LiteralPath $base) { Remove-Item -LiteralPath $base -Recurse -Force }
  }

  if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
  Write-Host ''
  Write-Host 'All manifest-checker assertions passed.'
  exit 0
  ```
- [ ] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/manifests/check-plugin-manifests.tests.ps1` → exit 1, `FAILED: 7 assertion(s).`: every fixture check FAILs (today's checker has no `-Root`, so it ignores the argument and reports `manifest parity OK: 2 plugin(s) checked` for this repo every time); `this repository passes` PASSes.
- [ ] **Step 3 (implement):** Replace the whole of `scripts/check-plugin-manifests.ps1` with the text below. Save it as UTF-8 WITH a byte-order mark (the file has one today): its messages contain em-dashes, which Windows PowerShell 5.1 misparses without the BOM.
  ```powershell
  # check-plugin-manifests.ps1 — repo green-gate manifest parity checker.
  # For every plugin under plugins/ with a .claude-plugin/plugin.json:
  #   - its marketplace entry must exist and match the version;
  #   - it must ship a .codex-plugin/plugin.json whose version, description, and
  #     keywords (element-wise, order-sensitive) equal the .claude-plugin
  #     manifest's, and whose "skills" value resolves to the plugin's skills/
  #     directory;
  #   - every skills/<dir>/ must hold a SKILL.md whose frontmatter name: is <dir>.
  # Exits 1 with one line per failure; exits 0 with a summary when clean.
  # Windows PowerShell 5.1-compatible. -Root defaults to the repo this script
  # lives in (the parent of scripts/); tests pass a fixture root.
  [CmdletBinding()]
  param([string]$Root)
  $ErrorActionPreference = 'Stop'

  if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
  $repoRoot = [System.IO.Path]::GetFullPath($Root)
  $failures = @()
  $checked = 0

  function Get-FrontmatterName([string]$Path) {
      $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
      if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $null }
      for ($i = 1; $i -lt $lines.Count; $i++) {
          if ($lines[$i].Trim() -eq '---') { return $null }
          if ($lines[$i] -match '^name:\s*(.+)') { return $Matches[1].Trim().Trim('"').Trim("'") }
      }
      return $null
  }

  $marketplacePath = Join-Path $repoRoot '.claude-plugin\marketplace.json'
  $marketplace = Get-Content -Raw -LiteralPath $marketplacePath | ConvertFrom-Json

  $pluginsDir = Join-Path $repoRoot 'plugins'
  $pluginDirs = Get-ChildItem -LiteralPath $pluginsDir -Directory |
      Where-Object { Test-Path (Join-Path $_.FullName '.claude-plugin\plugin.json') }

  foreach ($dir in $pluginDirs) {
      $checked++
      $claude = Get-Content -Raw -LiteralPath (Join-Path $dir.FullName '.claude-plugin\plugin.json') | ConvertFrom-Json
      $name = $claude.name

      # Marketplace entry: must exist, version must match.
      $entry = $marketplace.plugins | Where-Object { $_.name -eq $name }
      if (-not $entry) {
          $failures += "${name}: missing marketplace entry in .claude-plugin/marketplace.json"
      }
      elseif ($entry.version -ne $claude.version) {
          $failures += "${name}: version mismatch — claude=$($claude.version) codex/marketplace=$($entry.version)"
      }

      # Codex manifest: required; version, description, keywords must match; skills must resolve.
      $codexPath = Join-Path $dir.FullName '.codex-plugin\plugin.json'
      if (-not (Test-Path -LiteralPath $codexPath)) {
          $failures += "${name}: missing .codex-plugin/plugin.json (every plugin ships both manifests)"
      }
      else {
          $codex = Get-Content -Raw -LiteralPath $codexPath | ConvertFrom-Json

          if ($codex.version -ne $claude.version) {
              $failures += "${name}: version mismatch — claude=$($claude.version) codex/marketplace=$($codex.version)"
          }
          if ($codex.description -ne $claude.description) {
              $failures += "${name}: description mismatch — claude=$($claude.description) codex/marketplace=$($codex.description)"
          }

          $claudeKeywords = @($claude.keywords)
          $codexKeywords = @($codex.keywords)
          if ($claudeKeywords.Count -ne $codexKeywords.Count) {
              $failures += "${name}: keywords mismatch — claude=$($claudeKeywords -join ',') codex/marketplace=$($codexKeywords -join ',')"
          }
          else {
              for ($i = 0; $i -lt $claudeKeywords.Count; $i++) {
                  if ($claudeKeywords[$i] -cne $codexKeywords[$i]) {
                      $failures += "${name}: keywords mismatch — claude=$($claudeKeywords -join ',') codex/marketplace=$($codexKeywords -join ',')"
                      break
                  }
              }
          }

          $skillsDir = [System.IO.Path]::GetFullPath((Join-Path $dir.FullName 'skills')).TrimEnd('\', '/')
          if (-not ($codex.skills -is [string]) -or -not $codex.skills) {
              $failures += "${name}: .codex-plugin/plugin.json has no ""skills"" path"
          }
          else {
              $resolved = [System.IO.Path]::GetFullPath((Join-Path $dir.FullName $codex.skills)).TrimEnd('\', '/')
              if (-not [string]::Equals($resolved, $skillsDir, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $skillsDir -PathType Container)) {
                  $failures += "${name}: .codex-plugin/plugin.json ""skills"" is '$($codex.skills)', which does not resolve to the plugin's skills/ directory"
              }
          }
      }

      # Skills: each skills/<dir>/ holds a SKILL.md whose frontmatter name: is <dir>.
      $skillsRoot = Join-Path $dir.FullName 'skills'
      if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
          foreach ($skill in @(Get-ChildItem -LiteralPath $skillsRoot -Directory)) {
              $skillFile = Join-Path $skill.FullName 'SKILL.md'
              if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
                  $failures += "${name}: skills/$($skill.Name)/ has no SKILL.md"
                  continue
              }
              $skillName = Get-FrontmatterName $skillFile
              if ($skillName -cne $skill.Name) {
                  $failures += "${name}: skills/$($skill.Name)/SKILL.md frontmatter name is '$skillName', expected '$($skill.Name)'"
              }
          }
      }
  }

  if ($failures.Count -gt 0) {
      foreach ($f in $failures) { Write-Output $f }
      exit 1
  }

  Write-Output "manifest parity OK: $checked plugin(s) checked"
  exit 0
  ```
- [ ] **Step 4 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/manifests/check-plugin-manifests.tests.ps1` → eight PASS lines and `All manifest-checker assertions passed.`; `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-plugin-manifests.ps1` (no `-Root`, as the gate runs it) → `manifest parity OK: 2 plugin(s) checked`, exit 0.
- [ ] **Step 5 (gate):** In `.claude/cogniva-dev/green-gate.json`:
  1. In the `"label": "manifest-parity"` entry, replace the note `version/description/keywords must match across each plugin's manifest pair and its marketplace entry; claude plugin validate does not check this.` with `Both manifests required per plugin; version/description/keywords match across the pair and the marketplace entry; the Codex skills path resolves to skills/; every skill folder's SKILL.md name matches it. claude plugin validate only warns on a version mismatch.`
  2. Append at the END of the `commands` array (comma after the current last entry's closing `}`, new line before the closing `  ]`):
  ```json
      { "run": "pwsh -NoProfile -File plugins/cogniva-dev/tests/manifests/check-plugin-manifests.tests.ps1", "label": "manifest-checker", "note": "Proves check-plugin-manifests.ps1 fails on a missing Codex manifest, a bad Codex skills path, a skill folder/name mismatch and a version mismatch; needs PowerShell 7." }
  ```
  Then `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/validate-json.ps1 .claude/cogniva-dev/green-gate.json` → exit 0.
- [ ] **Step 6 (commit):** `git add scripts/check-plugin-manifests.ps1 plugins/cogniva-dev/tests/manifests/check-plugin-manifests.tests.ps1 .claude/cogniva-dev/green-gate.json` then `git commit -m "feat(manifests): require both manifests and check skill coverage; fixture suite"`

## Task 4: Primary-checkout hook suite (Claude Code payloads asserted, Codex gap pinned)

**Files:**
- Create: `plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1`
- Modify: `.claude/cogniva-dev/green-gate.json`

No hook script changes in this task. The suite asserts today's behaviour. The two Codex `apply_patch` checks are labelled `KNOWN GAP (fixed in sub-plan 08): …` and assert that the hooks currently return NO decision. Sub-plan 08 must flip them deliberately to the fixed behaviour. `guard-module-cycles.js` already has its own suite and is not covered here.

- [ ] **Step 1 (write the suite):** Create `plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1` with exactly:
  ```powershell
  # Dependency-free tests for the primary-checkout hooks (no Pester):
  # guard-primary-edit.js, guard-primary-git.js and nudge-backlog-commit.js.
  # Claude Code payloads are asserted against their real behaviour. Codex
  # apply_patch payloads are pinned at today's behaviour under 'KNOWN GAP' labels:
  # the edit hooks read only tool_input.file_path, so they do not see a Codex patch.
  # PowerShell 7. Payloads go to `node <hook>` on stdin, run from the payload's cwd.
  $ErrorActionPreference = 'Stop'
  $here = Split-Path -Parent $MyInvocation.MyCommand.Path
  $plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
  $scripts = Join-Path $plugin 'scripts'
  $editHook = Join-Path $scripts 'guard-primary-edit.js'
  $gitHook = Join-Path $scripts 'guard-primary-git.js'
  $nudgeHook = Join-Path $scripts 'nudge-backlog-commit.js'
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-primary-hooks-" + [guid]::NewGuid().ToString('N'))
  $failures = @()
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

  function Check($label, $condition) {
      if ($condition) { Write-Host "  PASS  $label" }
      else { Write-Host "  FAIL  $label"; $script:failures += $label }
  }
  function Write-Text([string]$Path, [string]$Text) {
      New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
      [System.IO.File]::WriteAllText($Path, $Text, $script:utf8NoBom)
  }
  # Pipes one JSON payload to a hook on stdin, from -Cwd, and returns its exit code,
  # its stdout, and the parsed JSON ($null when stdout is empty or not JSON).
  function Invoke-Hook([string]$Hook, [hashtable]$Payload, [string]$Cwd) {
      $json = $Payload | ConvertTo-Json -Compress -Depth 5
      Push-Location -LiteralPath $Cwd
      try {
          $lines = @($json | & node $Hook 2>$null)
          $code = $LASTEXITCODE
      }
      finally { Pop-Location }
      $out = ((@($lines | ForEach-Object { [string]$_ }) -join "`n").Trim())
      $parsed = $null
      if ($out) { try { $parsed = $out | ConvertFrom-Json } catch { } }
      [pscustomobject]@{ Code = $code; Out = $out; Json = $parsed }
  }
  function Test-Denied($r) { $r.Code -eq 0 -and $r.Json -and $r.Json.hookSpecificOutput.hookEventName -eq 'PreToolUse' -and $r.Json.hookSpecificOutput.permissionDecision -eq 'deny' }
  function Test-Silent($r) { $r.Code -eq 0 -and -not $r.Out }
  function Set-WorktreeMode([string]$Repo, [bool]$On) {
      Write-Text (Join-Path $Repo '.claude\cogniva-dev.local.json') ('{ "worktrees": ' + $(if ($On) { 'true' } else { 'false' }) + ' }')
  }
  function New-Patch([string]$Header) { "*** Begin Patch`n$Header`n@@`n-old`n+new`n*** End Patch`n" }

  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
      Write-Host '  SKIP  primary-checkout hooks (node not installed)'
  }
  else {
      try {
          $repo = Join-Path $root 'repo'
          $wt = Join-Path $root 'wt'
          New-Item -ItemType Directory -Path $repo -Force | Out-Null
          & git -C $repo init -q -b main
          & git -C $repo config user.name 'Test'
          & git -C $repo config user.email 'test@example.com'
          & git -C $repo config core.autocrlf false
          Write-Text (Join-Path $repo 'src\a.txt') "old`n"
          Write-Text (Join-Path $repo 'docs\plans\BACKLOG.md') "# Backlog`n"
          Add-Content -LiteralPath (Join-Path $repo '.git\info\exclude') -Value '.claude/cogniva-dev.local.json'
          & git -C $repo add -A
          & git -C $repo commit -q -m 'seed'
          & git -C $repo worktree add -q -b feature/wt $wt 2>$null
          $primaryFile = Join-Path $repo 'src\a.txt'
          $backlog = Join-Path $repo 'docs\plans\BACKLOG.md'

          # --- guard-primary-edit: Claude Code payloads -----------------------------
          Set-WorktreeMode $repo $true
          $r = Invoke-Hook $editHook @{ tool_name = 'Write'; tool_input = @{ file_path = $primaryFile; content = 'x' } } $repo
          Check 'edit guard: worktree mode, a Claude Write to a primary-checkout file is denied' (Test-Denied $r)
          $r = Invoke-Hook $editHook @{ tool_name = 'Write'; tool_input = @{ file_path = (Join-Path $repo '.plans-staging\x.md'); content = 'x' } } $repo
          Check 'edit guard: .plans-staging/x.md is allowed (exit 0, no output)' (Test-Silent $r)
          $r = Invoke-Hook $editHook @{ tool_name = 'Edit'; tool_input = @{ file_path = $backlog; old_string = 'a'; new_string = 'b' } } $repo
          Check 'edit guard: docs/plans/BACKLOG.md is allowed (exit 0, no output)' (Test-Silent $r)
          $r = Invoke-Hook $editHook @{ tool_name = 'Write'; tool_input = @{ file_path = (Join-Path $wt 'src\a.txt'); content = 'x' } } $wt
          Check 'edit guard: the same path inside a linked worktree is allowed' (Test-Silent $r)
          Set-WorktreeMode $repo $false
          $r = Invoke-Hook $editHook @{ tool_name = 'Write'; tool_input = @{ file_path = $primaryFile; content = 'x' } } $repo
          Check 'edit guard: lean mode allows a primary-checkout Write' (Test-Silent $r)

          # --- guard-primary-git: Bash payloads (Claude Code and Codex share this shape) ---
          Set-WorktreeMode $repo $true
          $r = Invoke-Hook $gitHook @{ tool_name = 'Bash'; tool_input = @{ command = 'git switch main' }; cwd = $repo } $repo
          Check 'git guard: worktree mode, git switch in the primary checkout is denied' (Test-Denied $r)
          $r = Invoke-Hook $gitHook @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $repo } $repo
          Check 'git guard: git status is allowed' (Test-Silent $r)
          $r = Invoke-Hook $gitHook @{ tool_name = 'Bash'; tool_input = @{ command = 'git switch main' }; cwd = $wt } $wt
          Check 'git guard: git switch inside a linked worktree is allowed' (Test-Silent $r)
          $r = Invoke-Hook $gitHook @{ tool_name = 'Bash'; tool_input = @{ command = 'git switch main' }; cwd = $repo; session_id = 'codex-session'; turn_id = 'turn-1'; hook_event_name = 'PreToolUse' } $repo
          Check 'git guard: a Codex-shaped Bash payload (cwd set) is denied too' (Test-Denied $r)
          Set-WorktreeMode $repo $false
          $r = Invoke-Hook $gitHook @{ tool_name = 'Bash'; tool_input = @{ command = 'git switch main' }; cwd = $repo } $repo
          Check 'git guard: lean mode allows git switch' (Test-Silent $r)

          # --- nudge-backlog-commit: Claude Code payloads -----------------------------
          Set-WorktreeMode $repo $true
          $r = Invoke-Hook $nudgeHook @{ tool_name = 'Edit'; tool_input = @{ file_path = $backlog } } $repo
          Check 'nudge: a clean BACKLOG.md is silent' (Test-Silent $r)
          Write-Text $backlog "# Backlog`n`n- [ ] new item because:human later`n"
          $r = Invoke-Hook $nudgeHook @{ tool_name = 'Edit'; tool_input = @{ file_path = $backlog } } $repo
          Check 'nudge: an uncommitted BACKLOG.md edit in worktree mode returns PostToolUse additionalContext' ($r.Code -eq 0 -and $r.Json -and $r.Json.hookSpecificOutput.hookEventName -eq 'PostToolUse' -and $r.Json.hookSpecificOutput.additionalContext -match 'UNCOMMITTED in the PRIMARY checkout')
          $r = Invoke-Hook $nudgeHook @{ tool_name = 'Edit'; tool_input = @{ file_path = $primaryFile } } $repo
          Check 'nudge: a non-backlog file is silent' (Test-Silent $r)
          Set-WorktreeMode $repo $false
          $r = Invoke-Hook $nudgeHook @{ tool_name = 'Edit'; tool_input = @{ file_path = $backlog } } $repo
          Check 'nudge: lean mode is silent' (Test-Silent $r)

          # --- Codex apply_patch payloads: today's behaviour, pinned -----------------
          # Worktree mode is on and BACKLOG.md is still uncommitted, so a hook that read
          # the patch WOULD deny the first and nudge on the second.
          Set-WorktreeMode $repo $true
          $r = Invoke-Hook $editHook @{ tool_name = 'apply_patch'; tool_input = @{ command = (New-Patch '*** Update File: src/a.txt') }; cwd = $repo } $repo
          Check 'KNOWN GAP (fixed in sub-plan 08): edit guard returns no decision for a Codex apply_patch to a primary-checkout file' (Test-Silent $r)
          $r = Invoke-Hook $nudgeHook @{ tool_name = 'apply_patch'; tool_input = @{ command = (New-Patch '*** Update File: docs/plans/BACKLOG.md') }; cwd = $repo } $repo
          Check 'KNOWN GAP (fixed in sub-plan 08): nudge is silent for a Codex apply_patch to an uncommitted BACKLOG.md' (Test-Silent $r)
      }
      finally {
          if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
      }
  }

  if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
  Write-Host ''
  Write-Host 'All primary-hooks assertions passed.'
  exit 0
  ```
- [ ] **Step 2 (run it):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1` → sixteen PASS lines (five edit-guard, five git-guard, four nudge, two `KNOWN GAP`) and `All primary-hooks assertions passed.` This suite pins existing behaviour, so it passes on first run. To prove it can fail, temporarily change `return deny(` to `return allow(` near the end of `plugins/cogniva-dev/scripts/guard-primary-edit.js`, re-run → `FAIL  edit guard: worktree mode, a Claude Write to a primary-checkout file is denied` and exit 1, then restore the file exactly (`git diff --exit-code plugins/cogniva-dev/scripts/guard-primary-edit.js` → exit 0).
- [ ] **Step 3 (gate):** In `.claude/cogniva-dev/green-gate.json`, append at the END of the `commands` array (comma after the current last entry's closing `}`, new line before the closing `  ]`):
  ```json
      { "run": "pwsh -NoProfile -File plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1", "label": "primary-hooks", "note": "Pins the primary-checkout edit/git guards and the backlog nudge for Claude Code payloads; the Codex apply_patch gap is pinned under KNOWN GAP labels until the hook input adapter lands; needs PowerShell 7 and node." }
  ```
  Then `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/validate-json.ps1 .claude/cogniva-dev/green-gate.json` → exit 0.
- [ ] **Step 4 (run the full green gate):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` → last line `green-gate: GREEN - all 20 command(s) exited 0.` (the 12 original commands, `instruction-governance` from sub-plan 01, and this sub-plan's `git-commit`, `integrate-feature`, `ledger`, `parse-plan-tasks`, `validate-json`, `manifest-checker`, `primary-hooks`). If `instruction-governance` is absent because sub-plan 01 has not run, the count is 19.
- [ ] **Step 5 (commit):** `git add plugins/cogniva-dev/tests/hooks/primary-hooks.tests.ps1 .claude/cogniva-dev/green-gate.json` then `git commit -m "test(hooks): pin the primary-checkout hooks; record the Codex apply_patch gap"`
