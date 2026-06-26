# PermissionNoise — Feature Plan

> REQUIRED EXECUTOR: /cogniva-dev:execute-feature ExecuteFeature/PermissionNoise
> Tasks contain NO git worktree/branch step — execute-feature creates the worktree
> and the tasks commit on the feature branch they are already on. Never run
> git switch/checkout/branch inside a task.
>
> **Two task kinds in this plan.** Tasks 1–6 are ordinary repo-local commits.
> Tasks 7–8 are ⛔ manual gates that touch the **environment, not the repo**
> (`~/.claude/settings.json`, which cannot be committed; and a plugin refresh +
> real-run validation). execute-feature will stop at each gate; the human applies
> the change and re-runs. The gate tasks produce **no commit**.

**Goal:** Stop the cogniva-dev plan/execute machinery from generating permission
prompts for already-approved work, by (a) routing subagent git/JSON operations
through allowlistable wrapper scripts, (b) steering the plan/execute prompts away
from `&&`-chained, `cd`-prefixed, inline-`pwsh -Command` commands, and (c) fixing
and future-proofing the permission allowlist.

**Architecture:** Root cause (from two session analyses): Claude Code matches each
`&&`/`;`/`|` segment of a compound Bash line against the allowlist; any unlisted
segment — or a multi-line quoted commit message it can't decompose — prompts the
whole line, so approved `git add`/`git commit` keep re-prompting. Fix at the
source: two committed PowerShell wrappers (`git-commit.ps1`, `validate-json.ps1`)
give subagents a single fixed, allowlistable command prefix; `git-commit.ps1` also
captures the short SHA internally, removing the per-task `git rev-parse` prompts.
The workflow agent prompt and PLAN-FORMAT are updated to use the wrappers and ban
chaining. Allowlist policy (ADR 0002): per-script absolute-path rules with a
**version-glob** segment (`.../cogniva-dev/*/scripts/...`) so rules survive plugin
bumps — no generic `-File:*` runner. Read-only + scoped-write verbs go to **user**
settings (global payoff); **project** settings only sheds its dead rule.

**Read these first:**
- [docs/adr/0002-per-script-versionglob-allowlist.md](../../../adr/0002-per-script-versionglob-allowlist.md)
- [docs/adr/0003-wrapper-scripts-for-subagent-git-and-json.md](../../../adr/0003-wrapper-scripts-for-subagent-git-and-json.md)
- [docs/scratchpad/permission-noise-summary.md](../../../scratchpad/permission-noise-summary.md)
- [docs/scratchpad/permission-prompt-analysis-FileCleanup.md](../../../scratchpad/permission-prompt-analysis-FileCleanup.md)
- Existing test-harness style to mirror: [plugins/cogniva-dev/tests/parse-plan-tasks/parse-plan-tasks.tests.ps1](../../../../plugins/cogniva-dev/tests/parse-plan-tasks/parse-plan-tasks.tests.ps1)
- [plugins/cogniva-dev/templates/execute-feature.workflow.js](../../../../plugins/cogniva-dev/templates/execute-feature.workflow.js)
- [plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md](../../../../plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md)

## File structure (locked)

```
plugins/cogniva-dev/scripts/git-commit.ps1                         CREATE  — stage given paths + commit + print short SHA (one allowlistable prefix)
plugins/cogniva-dev/scripts/validate-json.ps1                      CREATE  — validate one+ files parse as JSON; exit 0/1
plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1          CREATE  — dependency-free regression test for git-commit.ps1
plugins/cogniva-dev/tests/validate-json/validate-json.tests.ps1    CREATE  — dependency-free regression test for validate-json.ps1
plugins/cogniva-dev/templates/execute-feature.workflow.js          MODIFY  — agent prompt: commit via wrapper, no &&/cd, capture SHA from wrapper stdout
plugins/cogniva-dev/skills/execute-feature/SKILL.md                MODIFY  — add a Rule banning command chaining / cd-prefix in tasks
plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md             MODIFY  — commit step + verification-vocab guidance (no &&, no inline pwsh -Command)
plugins/cogniva-dev/.claude-plugin/plugin.json                     MODIFY  — version 0.2.0 → 0.3.0
.claude-plugin/marketplace.json                                    MODIFY  — cogniva-dev entry version 0.2.0 → 0.3.0
.claude/settings.json                                              MODIFY  — remove the dead powershell.exe -File rule
~/.claude/settings.json                                            GATE 7  — (NOT in repo, NOT committed) add verbs + version-glob script rules
(plugin refresh + real execute-feature run)                        GATE 8  — confirm prompts are gone
```

## Task 1: Create the git-commit.ps1 wrapper (with test)

**Files:**
- Create: `plugins/cogniva-dev/scripts/git-commit.ps1`
- Test:   `plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1`

- [ ] **Step 1 (failing test):** Create `plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1` with exactly:

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
    $msg = "feat(x): add a thing`n`nBody line with a quote \" and an em-dash —."
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $script -RepoPath $repo -Path 'a.txt' -Message $msg
    $sha = ($out | Select-Object -Last 1).Trim()

    Check 'exit 0'                       ($LASTEXITCODE -eq 0)
    Check 'prints a short sha (7-12 hex)' ($sha -match '^[0-9a-f]{7,12}$')
    $log = (& git -C $repo log --oneline) -join "`n"
    Check 'one commit exists'            (($log -split "`n").Count -eq 1)
    Check 'subject is the first msg line' ($log -match 'feat\(x\): add a thing')
    $status = (& git -C $repo status --porcelain) -join "`n"
    Check 'working tree clean after commit' ([string]::IsNullOrWhiteSpace($status))

    # Error path: no -Path and no -All -> non-zero exit.
    & powershell -NoProfile -ExecutionPolicy Bypass -File $script -RepoPath $repo -Message 'x' 2>$null
    Check 'errors when neither -Path nor -All given' ($LASTEXITCODE -ne 0)
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

- [ ] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1"` → fails (script does not exist yet — error or FAILED assertions, non-zero exit).
- [ ] **Step 3 (implement):** Create `plugins/cogniva-dev/scripts/git-commit.ps1` with exactly:

```powershell
# Stage a set of paths in a repo/worktree and commit them with ONE allowlistable
# command, then print the short commit SHA on stdout.
#
# Why this exists: Claude Code matches each segment of a compound Bash line against
# the permission allowlist; `git add ... && git commit -m "<multi-line msg>"` is a
# single un-decomposable line, so it re-prompts even when git add/commit are allowed.
# A fixed `powershell ... -File ".../git-commit.ps1"` prefix (args matched by :*)
# is allowlistable once and matches regardless of how long/multi-line the message is.
# Capturing the SHA here also removes the per-task `git rev-parse` prompt.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoPath,
    [Parameter(Mandatory)][string]$Message,
    [string[]]$Path,
    [switch]$All
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $RepoPath)) {
    [Console]::Error.WriteLine("git-commit: repo path not found: $RepoPath"); exit 2
}
if (-not $All -and (-not $Path -or @($Path).Count -eq 0)) {
    [Console]::Error.WriteLine("git-commit: supply -Path <files...> or -All"); exit 2
}

if ($All) {
    & git -C $RepoPath add -A
} else {
    & git -C $RepoPath add -- @Path
}
if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("git-commit: git add failed"); exit 1 }

& git -C $RepoPath commit -m $Message
if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("git-commit: git commit failed"); exit 1 }

$sha = (& git -C $RepoPath rev-parse --short HEAD)
Write-Output ($sha | Out-String).Trim()
exit 0
```

- [ ] **Step 4 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1"` → ends with `All git-commit assertions passed.` and exit 0.
- [ ] **Step 5 (commit):** Commit the two new files with message
      `feat(cogniva-dev): add git-commit.ps1 wrapper for allowlistable subagent commits`.
      (execute-feature commits via its git-commit wrapper if available; otherwise stage `plugins/cogniva-dev/scripts/git-commit.ps1` and `plugins/cogniva-dev/tests/git-commit/git-commit.tests.ps1` and commit with that message.)

## Task 2: Create the validate-json.ps1 wrapper (with test)

**Files:**
- Create: `plugins/cogniva-dev/scripts/validate-json.ps1`
- Test:   `plugins/cogniva-dev/tests/validate-json/validate-json.tests.ps1`

- [ ] **Step 1 (failing test):** Create `plugins/cogniva-dev/tests/validate-json/validate-json.tests.ps1` with exactly:

```powershell
# Dependency-free regression test for validate-json.ps1 (no Pester).
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\scripts\validate-json.ps1'))

$failures = @()
function Check($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("vj-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $good = Join-Path $tmp 'good.json'
    $bad  = Join-Path $tmp 'bad.json'
    Set-Content -LiteralPath $good -Value '{ "a": 1, "b": [2, 3] }'
    Set-Content -LiteralPath $bad  -Value '{ this is : not json'

    & powershell -NoProfile -ExecutionPolicy Bypass -File $script $good 2>$null
    Check 'exit 0 for a single valid file' ($LASTEXITCODE -eq 0)

    & powershell -NoProfile -ExecutionPolicy Bypass -File $script $bad 2>$null
    Check 'exit 1 for an invalid file' ($LASTEXITCODE -eq 1)

    & powershell -NoProfile -ExecutionPolicy Bypass -File $script $good $bad 2>$null
    Check 'exit 1 when any file is invalid' ($LASTEXITCODE -eq 1)

    & powershell -NoProfile -ExecutionPolicy Bypass -File $script (Join-Path $tmp 'missing.json') 2>$null
    Check 'exit 1 for a missing file' ($LASTEXITCODE -eq 1)
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED: $($failures.Count) assertion(s)."
    exit 1
}
Write-Host ""
Write-Host "All validate-json assertions passed."
exit 0
```

- [ ] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/tests/validate-json/validate-json.tests.ps1"` → fails (script does not exist yet).
- [ ] **Step 3 (implement):** Create `plugins/cogniva-dev/scripts/validate-json.ps1` with exactly:

```powershell
# Validate that each given file parses as JSON. Exit 0 if all valid, 1 if any
# invalid or missing. Replaces inline `Get-Content ... | ConvertFrom-Json` checks
# (each a unique, un-allowlistable string) with one fixed allowlistable command.
[CmdletBinding()]
param(
    [Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Path
)
$ErrorActionPreference = 'Stop'

$bad = @()
foreach ($p in $Path) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        [Console]::Error.WriteLine("validate-json: not found: $p"); $bad += $p; continue
    }
    try {
        Get-Content -LiteralPath $p -Raw | ConvertFrom-Json -ErrorAction Stop | Out-Null
        Write-Output "OK   $p"
    } catch {
        [Console]::Error.WriteLine("validate-json: invalid JSON: $p"); $bad += $p
    }
}
if ($bad.Count -gt 0) { exit 1 }
exit 0
```

- [ ] **Step 4 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/tests/validate-json/validate-json.tests.ps1"` → ends with `All validate-json assertions passed.` and exit 0.
- [ ] **Step 5 (commit):** Commit the two new files with message
      `feat(cogniva-dev): add validate-json.ps1 wrapper for allowlistable JSON checks`.

## Task 3: Wire the wrappers + no-chaining rule into execute-feature

**Files:**
- Modify: `plugins/cogniva-dev/templates/execute-feature.workflow.js`
- Modify: `plugins/cogniva-dev/skills/execute-feature/SKILL.md`

Context: the per-task agent prompt currently says *"stage ONLY the files you changed,
commit … append … the commit SHA"* with no guidance against chaining, so agents emit
`git add … && git commit -m "<multi-line>"` and `git rev-parse`. `<plugin>` at run
time resolves to the plugin cache root, so the wrapper is at
`<plugin>/scripts/git-commit.ps1`.

- [ ] **Step 1 (modify the agent prompt):** In `plugins/cogniva-dev/templates/execute-feature.workflow.js`, replace this exact block:

```js
    `On success: stage ONLY the files you changed, commit with the task's commit message (keep the repo's commit conventions),`,
    `then edit ${planPath} to flip THIS task's checkboxes from "- [ ]" to "- [x]",`,
    `and append one short line to ${statePath}: created/modified paths, key decisions, and the commit SHA.`,
```

with:

```js
    `On success, commit with the cogniva-dev wrapper (ONE call, not a chain) — it stages, commits, and prints the short SHA:`,
    `  powershell -NoProfile -ExecutionPolicy Bypass -File "${pluginRoot}/scripts/git-commit.ps1" -RepoPath "${worktree}" -Path <only this task's files> -Message "<the task's commit message>"`,
    `Capture the short SHA it prints on stdout. Do NOT run \`git add\`/\`git commit\`/\`git rev-parse\` yourself, and never chain commands with && or prefix them with cd — run each command as its own Bash call (your cwd is already the worktree; use absolute paths).`,
    `Then edit ${planPath} to flip THIS task's checkboxes from "- [ ]" to "- [x]",`,
    `and append one short line to ${statePath}: created/modified paths, key decisions, and the commit SHA.`,
```

- [ ] **Step 2 (thread the plugin root into args):** The prompt above references `${pluginRoot}`, which must come from `args`. In the same file, update the destructuring line. Replace:

```js
const { worktree, featureBranch, planPath, statePath, tasks } = _args
```

with:

```js
const { worktree, featureBranch, planPath, statePath, tasks, pluginRoot } = _args
```

- [ ] **Step 3 (document the new arg):** In the same file's top comment block, in the `args = {` list, add a line after the `worktree:` line so the contract records it. Replace:

```js
//     worktree:      absolute path to the feature worktree (already checked out on featureBranch),
```

with:

```js
//     worktree:      absolute path to the feature worktree (already checked out on featureBranch),
//     pluginRoot:    absolute path to this plugin's root (parent of skills/), for invoking scripts/git-commit.ps1,
```

- [ ] **Step 4 (have the skill pass pluginRoot):** In `plugins/cogniva-dev/skills/execute-feature/SKILL.md`, in the Step 2 `args = { … }` example, add `pluginRoot`. Replace:

```
args = { worktree, featureBranch: "feature/<slug>",
         planPath:  "<worktree>/docs/plans/<Module>/<Feature>/<Feature>-plan.md",
         statePath: "<worktree>/docs/plans/<Module>/<Feature>/state.md",
         tasks: [ ...parsed... ] }
```

with:

```
args = { worktree, featureBranch: "feature/<slug>",
         pluginRoot: "<plugin>",   // parent of this skills/ dir — lets tasks commit via scripts/git-commit.ps1
         planPath:  "<worktree>/docs/plans/<Module>/<Feature>/<Feature>-plan.md",
         statePath: "<worktree>/docs/plans/<Module>/<Feature>/state.md",
         tasks: [ ...parsed... ] }
```

- [ ] **Step 5 (add the no-chaining Rule):** In `plugins/cogniva-dev/skills/execute-feature/SKILL.md`, under `## Rules`, add this as a new bullet immediately after the `- NEVER push to a remote…` bullet:

```
- Tasks commit via `scripts/git-commit.ps1` (one call, stages+commits+prints SHA),
  not `git add && git commit`. Never chain shell commands with `&&`/`;` or prefix
  with `cd` — each command is its own call; cwd is already the worktree. This keeps
  every command matchable against the permission allowlist (see docs/adr/0003).
```

- [ ] **Step 6 (verify the edits landed):** Run these and confirm the matches:
      `grep -c "git-commit.ps1" "plugins/cogniva-dev/templates/execute-feature.workflow.js"` → `1` or more;
      `grep -c "pluginRoot" "plugins/cogniva-dev/templates/execute-feature.workflow.js"` → `3` (comment, destructure, prompt);
      `grep -c "git-commit.ps1" "plugins/cogniva-dev/skills/execute-feature/SKILL.md"` → `1` or more.
- [ ] **Step 7 (commit):** Commit both modified files with message
      `feat(execute-feature): commit via git-commit.ps1, ban command chaining in tasks`.

## Task 4: Steer PLAN-FORMAT.md toward allowlistable commands

**Files:**
- Modify: `plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md`

Context: PLAN-FORMAT's template renders the commit step as `git add <files>` then
`git commit -m "<message>"` (nudges `&&`-chaining) and its "exact commands" rule
produces inline `pwsh -Command "…"` and `&&`-chained diagnostics that cannot be
allowlisted. Re-aim both.

- [ ] **Step 1 (relax the commit step):** In `plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md`, replace this exact template line:

```
- [ ] **Step 5 (commit):** `git add <only this task's files>` then
      `git commit -m "<conventional message>"`
```

with:

```
- [ ] **Step 5 (commit):** Commit only this task's files with message
      `<conventional message>`. (execute-feature commits via `scripts/git-commit.ps1`
      — describe the message and the files; do NOT write a `git add && git commit` chain.)
```

- [ ] **Step 2 (add a verification-vocab rule):** In the same file, under `## Rules`, add these two bullets at the end of the list:

```
- Verification commands must be **allowlistable**: prefer single read-only verbs
  (`grep`, `cat`, `test`, `ls`, `head`) or a named script run via
  `powershell -NoProfile -ExecutionPolicy Bypass -File "<path>.ps1" …`. Do NOT write
  `&&`/`;`-chained command lines or inline `pwsh -Command "…"` / `powershell -Command "…"`
  — each is a unique, un-allowlistable string that prompts at execute time (see docs/adr/0003).
- One command per `- [ ]` step. If a step needs two commands, make it two steps.
```

- [ ] **Step 3 (verify):** `grep -c "allowlistable" "plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md"` → `1` or more, and
      `grep -c "git add && git commit\|do NOT write a \`git add" "plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md"` → `1` or more.
- [ ] **Step 4 (commit):** Commit the modified file with message
      `docs(plan-feature): steer PLAN-FORMAT verification toward allowlistable commands`.

## Task 5: Remove the dead rule from project settings

**Files:**
- Modify: `.claude/settings.json`

Context: `.claude/settings.json` allows `Bash(powershell.exe -NoProfile
-ExecutionPolicy Bypass -File *)`, but every real invocation uses `powershell`
(no `.exe`), so this rule never fires — dead cruft. The live per-script rules live
in user settings (Task 7). Per the split decision, project settings sheds the dead
rule and keeps only what's project-specific. `Bash(rm:*)` is left as-is (not in scope).

- [ ] **Step 1 (remove the dead rule):** Edit `.claude/settings.json` so the `allow` array no longer contains the line
      `"Bash(powershell.exe -NoProfile -ExecutionPolicy Bypass -File *)"`. The file must become exactly:

```json
{
  "permissions": {
    "allow": [
      "Bash(rm:*)"
    ]
  }
}
```

- [ ] **Step 2 (verify it is valid JSON):** `powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/scripts/validate-json.ps1" ".claude/settings.json"` → exit 0 (prints `OK   .claude/settings.json`).
- [ ] **Step 3 (verify the dead rule is gone):** `grep -c "powershell.exe" ".claude/settings.json"` → `0`.
- [ ] **Step 4 (commit):** Commit the modified file with message
      `chore(settings): drop dead powershell.exe -File allow rule (never fired)`.

## Task 6: Bump cogniva-dev version (plugin.json + marketplace.json)

**Files:**
- Modify: `plugins/cogniva-dev/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

Context: project rule — bump the plugin `version` whenever its skills/scripts/
templates change; the marketplace entry mirrors it. This change added scripts and
edited skills/templates, so 0.2.0 → 0.3.0.

- [ ] **Step 1 (bump plugin.json):** In `plugins/cogniva-dev/.claude-plugin/plugin.json`, change `"version": "0.2.0"` to `"version": "0.3.0"`.
- [ ] **Step 2 (bump marketplace.json):** In `.claude-plugin/marketplace.json`, in the `cogniva-dev` entry, change `"version": "0.2.0"` to `"version": "0.3.0"`. Leave the `cogniva-skills` entry untouched.
- [ ] **Step 3 (verify both are valid JSON and bumped):**
      `powershell -NoProfile -ExecutionPolicy Bypass -File "plugins/cogniva-dev/scripts/validate-json.ps1" "plugins/cogniva-dev/.claude-plugin/plugin.json" ".claude-plugin/marketplace.json"` → exit 0;
      `grep -c "0.3.0" "plugins/cogniva-dev/.claude-plugin/plugin.json"` → `1`.
- [ ] **Step 4 (commit):** Commit both modified files with message
      `chore(cogniva-dev): bump version to 0.3.0 (git/json wrappers, prompt + format fixes)`.

## ⛔ Task 7: Apply user-settings allowlist additions  (manual gate — NOT committed)

This edits `~/.claude/settings.json` (i.e. `C:/Users/canuc/.claude/settings.json`),
which is **outside the repo and is never committed**. execute-feature stops here;
the human applies the change (directly, or by approving the agent's Edit of that
file), then re-runs to continue. Use the version-glob form so rules survive plugin
bumps (ADR 0002).

- [ ] **Step 1:** Add these entries to the `permissions.allow` array in `~/.claude/settings.json` (read-only verbs + scoped writes; global payoff across all repos):

```
"Bash(echo:*)", "Bash(ls:*)", "Bash(cat:*)", "Bash(grep:*)", "Bash(head:*)",
"Bash(tail:*)", "Bash(wc:*)", "Bash(sort:*)", "Bash(uniq:*)", "Bash(cut:*)",
"Bash(test:*)", "Bash(xxd:*)", "Bash(git rev-parse:*)",
"Bash(mkdir:*)", "Bash(sed -n:*)",
```

- [ ] **Step 2:** Add these per-script rules (new wrappers + the plan parser), using `*` for the version segment so they survive plugin bumps:

```
"Bash(powershell -NoProfile -ExecutionPolicy Bypass -File \"C:/Users/canuc/.claude/plugins/cache/cogniva/cogniva-dev/*/scripts/git-commit.ps1\":*)",
"Bash(powershell -NoProfile -ExecutionPolicy Bypass -File \"C:/Users/canuc/.claude/plugins/cache/cogniva/cogniva-dev/*/scripts/validate-json.ps1\":*)",
"Bash(powershell -NoProfile -ExecutionPolicy Bypass -File \"C:/Users/canuc/.claude/plugins/cache/cogniva/cogniva-dev/*/scripts/parse-plan-tasks.ps1\":*)",
```

- [ ] **Step 3:** Migrate the three existing per-script rules from the hardcoded `0.1.0` segment to `*`, so they too survive bumps. Change the version segment `/0.1.0/` to `/*/` in these existing entries: `integrate-feature.ps1`, `new-feature-worktree.ps1`, `cleanup-session-worktrees.ps1`. (Leave the trailing `:*` and any `-Slug …` exact variants as-is, or replace the exact variants with the `:*` form.)
- [ ] **Step 4:** Save, then confirm the file is still valid JSON:
      `powershell -NoProfile -ExecutionPolicy Bypass -File "<repo>/plugins/cogniva-dev/scripts/validate-json.ps1" "C:/Users/canuc/.claude/settings.json"` → exit 0.
- [ ] **Step 5:** Wait for the user to confirm the edits look right before proceeding to the validation gate. (No commit — this file is not in the repo.)

## ⛔ Task 8: Refresh the installed plugin and validate prompts are gone  (manual gate)

The repo source is now at 0.3.0, but the live plugin cache still serves the old
version — so the new wrappers and prompt edits are NOT active in real sessions until
the installed plugin refreshes. This gate confirms the whole change actually
de-noises a real run.

- [ ] **Step 1:** Refresh the installed cogniva-dev plugin so the cache reflects 0.3.0 and contains `scripts/git-commit.ps1` + `scripts/validate-json.ps1`. (Update via the plugin/marketplace mechanism you use for this local marketplace; confirm a `.../cogniva-dev/0.3.0/scripts/git-commit.ps1` path now exists.)
- [ ] **Step 2:** Verify the version-glob allowlist actually matches. In a normal session run:
      `powershell -NoProfile -ExecutionPolicy Bypass -File "C:/Users/canuc/.claude/plugins/cache/cogniva/cogniva-dev/0.3.0/scripts/parse-plan-tasks.ps1" -PlanPath "<any plan>"` and confirm it runs **without a permission prompt**. If it DOES prompt, the `*` version glob is not matching — fall back to exact `0.3.0` per-script rules in `~/.claude/settings.json` and re-test.
- [ ] **Step 3:** Run a small `/cogniva-dev:execute-feature` (or `/cogniva-dev:quick-fix`) on a throwaway change and confirm: no prompts for `git add`/`git commit` (commits go through `git-commit.ps1`), no `git rev-parse` prompts, and read-only verbs (`grep`/`ls`/`cat`) run unprompted.
- [ ] **Step 4:** Wait for the user to confirm the prompt noise is gone. If residual prompts remain, capture them with
      `/cogniva-dev:backlog module=ExecuteFeature tier=loose src=PermissionNoise — <the still-prompting command>` and report. (No commit.)
