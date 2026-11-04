# Dependency-free tests for the primary-checkout hooks (no Pester):
# guard-primary-edit.js, guard-primary-git.js and nudge-backlog-commit.js.
# Claude Code payloads and Codex apply_patch payloads are both asserted against
# the intended behaviour: every hook reads its input through scripts/hook-input.js.
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

        # --- Codex apply_patch payloads (read through scripts/hook-input.js) --------
        # Worktree mode is on and BACKLOG.md is still uncommitted: the edit guard denies
        # the first patch and the nudge fires on the second.
        Set-WorktreeMode $repo $true
        $r = Invoke-Hook $editHook @{ tool_name = 'apply_patch'; tool_input = @{ command = (New-Patch '*** Update File: src/a.txt') }; cwd = $repo } $repo
        Check 'Codex payload: edit guard denies a Codex apply_patch to a primary-checkout file' (Test-Denied $r)
        $r = Invoke-Hook $nudgeHook @{ tool_name = 'apply_patch'; tool_input = @{ command = (New-Patch '*** Update File: docs/plans/BACKLOG.md') }; cwd = $repo } $repo
        Check 'Codex payload: nudge fires for a Codex apply_patch to an uncommitted BACKLOG.md' ($r.Code -eq 0 -and $r.Json -and $r.Json.hookSpecificOutput.hookEventName -eq 'PostToolUse' -and $r.Json.hookSpecificOutput.additionalContext -match 'UNCOMMITTED in the PRIMARY checkout')
    }
    finally {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    }
}

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

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All primary-hooks assertions passed.'
exit 0
