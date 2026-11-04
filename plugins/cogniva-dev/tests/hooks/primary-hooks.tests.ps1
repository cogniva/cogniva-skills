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
