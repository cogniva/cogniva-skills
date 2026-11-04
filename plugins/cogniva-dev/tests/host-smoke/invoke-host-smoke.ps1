#Requires -Version 7.0
# Runs agent-host smoke scenarios headless on Claude Code or Codex, checks each
# outcome with assert-smoke-outcome.ps1 and writes the results to a smoke record
# (docs/host-parity/smoke/<YYYY-MM-DD>-<claude-code|codex>-cli[-N].md).
# Each scenario runs in a fresh throwaway fixture repo (new-smoke-fixture.ps1)
# under -FixtureRoot, with no remote. That is why the agent runs unattended
# there (Claude Code: --permission-mode bypassPermissions; Codex: exec with
# --sandbox workspace-write): it can reach nothing but a temp repo built for it.
# Costs model tokens - not part of the green gate. -DryRun prints the fixture
# path, the command and the prompt for each run, and builds and runs nothing.
#   -Scenario <ID>|all   all = the nine scenarios, plus EF-GATE run again (resume)
#   -Resume              run the same invocation again on the existing fixture
#   -PluginDir <dir>     Claude Code: load the plugin from this folder only
#                        (--plugin-dir, with user settings and plugins off)
#   -CodexExe <path>     default: the newest codex.exe bundled with the VS Code
#                        extension (openai.chatgpt-<version>-win32-x64)
#   -RecordPath <file>   append to this record instead of starting a new one
#   -ExtraArgs <args>    passed to the agent host after the harness's own flags
# Exit 0 = every run passed; 1 = a run failed or did not finish; 2 = usage or
# harness error.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('claude-code', 'codex')][string]$AgentHost,
    [Parameter(Mandatory)][string]$Scenario,
    [string]$CodexExe,
    [string]$PluginDir,
    [switch]$Resume,
    [string]$OutDir,
    [string]$FixtureRoot,
    [string]$RecordPath,
    [string]$PluginSource,
    [string]$Covers = 'none',
    [string[]]$ExtraArgs = @(),
    [int]$TimeoutMinutes = 40,
    [switch]$NoRecord,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$repo = [System.IO.Path]::GetFullPath((Join-Path $plugin '..\..'))
$order = @('QF-NONE', 'QF-FINAL', 'EF-TWO', 'EF-BLOCKED', 'EF-GATE', 'QF-STRUCT', 'POLICY', 'HOOKS', 'INSTR')
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Fail([string]$Message) { [Console]::Error.WriteLine("invoke-host-smoke: $Message"); exit 2 }

if ($Scenario -ceq 'all') {
    if ($Resume) { Fail '-Resume takes one scenario, not all' }
    $ids = $order
}
elseif ($order -ccontains $Scenario) { $ids = @($Scenario) }
else { Fail "unknown scenario '$Scenario' (one of: $($order -join ', '), all)" }

if (-not $FixtureRoot) { $FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "cogniva-smoke-$AgentHost" }
$FixtureRoot = [System.IO.Path]::GetFullPath($FixtureRoot)
if (-not $OutDir) { $OutDir = Join-Path $FixtureRoot 'out' }
$OutDir = [System.IO.Path]::GetFullPath($OutDir)
if ($PluginDir) { $PluginDir = [System.IO.Path]::GetFullPath($PluginDir) }

$runs = @(foreach ($id in $ids) {
    [pscustomobject]@{ Id = $id; Resume = [bool]$Resume }
    if ($Scenario -ceq 'all' -and $id -ceq 'EF-GATE') { [pscustomobject]@{ Id = $id; Resume = $true } }
})

function Get-ScenarioData([string]$Id) {
    $dir = Join-Path $here "scenarios\$Id"
    return [pscustomobject]@{ Dir = $dir; Data = (Get-Content -Raw -LiteralPath (Join-Path $dir 'scenario.json') | ConvertFrom-Json) }
}
# Claude Code: /cogniva-dev:<skill> <args>; Codex: $<skill> <args>; no skill: the args alone.
function Get-Prompt($S) {
    $text = [string]$S.Data.args
    if ($S.Data.PSObject.Properties.Name -contains 'argsFile' -and $S.Data.argsFile) {
        $text += "`n" + ([System.IO.File]::ReadAllText((Join-Path $S.Dir $S.Data.argsFile))).Replace("`r`n", "`n").TrimEnd("`n")
    }
    if (-not $S.Data.skill) { return $text }
    if ($AgentHost -eq 'claude-code') { return "/cogniva-dev:$($S.Data.skill) $text" }
    return "`$$($S.Data.skill) $text"
}
function Resolve-CodexExe {
    if ($CodexExe) { return $CodexExe }
    $best = $null; $bestVersion = $null
    $extensions = Join-Path $env:USERPROFILE '.vscode\extensions'
    foreach ($d in @(Get-ChildItem -LiteralPath $extensions -Directory -Filter 'openai.chatgpt-*-win32-x64' -ErrorAction SilentlyContinue)) {
        if ($d.Name -notmatch '^openai\.chatgpt-(?<v>\d+(\.\d+){1,3})-win32-x64') { continue }
        $exe = Join-Path $d.FullName 'bin\windows-x86_64\codex.exe'
        $v = [version]$Matches['v']
        if ((Test-Path -LiteralPath $exe) -and ($null -eq $bestVersion -or $v -gt $bestVersion)) { $best = $exe; $bestVersion = $v }
    }
    return $best
}
function Get-AgentCommand([string]$Fixture, [string]$FinalFile) {
    if ($AgentHost -eq 'claude-code') {
        $found = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $exe = if ($found) { $found.Source } else { 'claude' }
        $list = @('-p', '--output-format', 'stream-json', '--verbose', '--permission-mode', 'bypassPermissions')
        if ($PluginDir) { $list += @('--plugin-dir', $PluginDir, '--setting-sources', 'project,local') }
    }
    else {
        $exe = Resolve-CodexExe
        $list = @('exec', '--json', '--sandbox', 'workspace-write', '-C', $Fixture, '--output-last-message', $FinalFile)
    }
    $list += @($ExtraArgs)
    if ($AgentHost -eq 'codex') { $list += '-' }
    return [pscustomobject]@{ Exe = $exe; Args = $list }
}
function Format-Command($Cmd) {
    $parts = @($Cmd.Exe) + @($Cmd.Args)
    return (@($parts | ForEach-Object { if ([string]$_ -match '\s') { "`"$_`"" } else { [string]$_ } }) -join ' ')
}
# Runs the agent host from the fixture folder with the prompt on stdin. The
# session variables a running Claude Code session sets for its own children are
# removed, so the run is not treated as nested inside the session that launched it.
function Invoke-Agent($Cmd, [string]$Fixture, [string]$Prompt, [string]$TranscriptFile) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new($Cmd.Exe)
    foreach ($a in $Cmd.Args) { $psi.ArgumentList.Add([string]$a) }
    $psi.WorkingDirectory = $Fixture
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardInputEncoding = $utf8
    $psi.StandardOutputEncoding = $utf8
    $psi.StandardErrorEncoding = $utf8
    foreach ($name in @($psi.Environment.Keys)) { if ($name -match '^(CLAUDECODE|CLAUDE_PID|CLAUDE_AGENT_SDK_VERSION|CLAUDE_CODE_(ENTRYPOINT|SESSION_ID|CHILD_SESSION|SESSION_ATTENDED|MESSAGING_SOCKET|MESSAGING_TOKEN))\z') { [void]$psi.Environment.Remove($name) } }
    $process = [System.Diagnostics.Process]::Start($psi)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    # An agent host that exits before reading its prompt closes the pipe; the run still counts.
    try { $process.StandardInput.Write($Prompt); $process.StandardInput.Close() } catch [System.IO.IOException] { }
    $timedOut = -not $process.WaitForExit($TimeoutMinutes * 60 * 1000)
    if ($timedOut) { try { $process.Kill($true) } catch { }; $process.WaitForExit() }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    [System.IO.File]::WriteAllText($TranscriptFile, $stdout, $utf8)
    if ($stderr) { [System.IO.File]::WriteAllText("$TranscriptFile.stderr.txt", $stderr, $utf8) }
    return [pscustomobject]@{ ExitCode = $(if ($timedOut) { 'timeout' } else { $process.ExitCode }); TimedOut = $timedOut; Stdout = $stdout }
}
# Claude Code stream-json: the final message is the last "result" event's text.
function Get-ClaudeFinal([string]$Stdout) {
    $final = ''
    foreach ($line in ($Stdout -split "`r?`n")) {
        if (-not $line.TrimStart().StartsWith('{')) { continue }
        try { $evt = $line | ConvertFrom-Json } catch { continue }
        if ($evt.type -eq 'result' -and $null -ne $evt.result) { $final = [string]$evt.result }
    }
    return $final
}
function Format-Cell([string]$Text) { return $Text.Replace("`r", '').Replace("`n", ' ').Replace('|', '\|') }

if ($DryRun) {
    foreach ($run in $runs) {
        $s = Get-ScenarioData $run.Id
        $stem = if ($run.Resume) { "$($run.Id).resume" } else { $run.Id }
        $fixture = Join-Path $FixtureRoot $run.Id
        $cmd = Get-AgentCommand $fixture (Join-Path $OutDir "$stem.final.txt")
        if (-not $cmd.Exe) { $cmd.Exe = '<codex.exe not found - pass -CodexExe>' }
        Write-Output ("SCENARIO: {0}{1}" -f $run.Id, $(if ($run.Resume) { ' (resume)' } else { '' }))
        Write-Output "FIXTURE: $fixture"
        Write-Output "COMMAND: $(Format-Command $cmd)  (prompt on stdin; working folder = FIXTURE)"
        Write-Output 'PROMPT:'
        Write-Output (Get-Prompt $s)
        Write-Output 'END PROMPT'
        Write-Output ''
    }
    exit 0
}

if ($FixtureRoot -match '\s') { Fail "-FixtureRoot must not contain spaces (fixture hook commands are written without quotes): $FixtureRoot" }
$probe = Get-AgentCommand '<fixture>' (Join-Path $OutDir '<ID>.final.txt')
if ($AgentHost -eq 'codex' -and (-not $probe.Exe -or -not (Test-Path -LiteralPath $probe.Exe))) { Fail 'codex.exe not found: pass -CodexExe <path>' }
New-Item -ItemType Directory -Path $FixtureRoot, $OutDir -Force | Out-Null

$record = $null
if (-not $NoRecord) {
    if ($RecordPath) { $record = [System.IO.Path]::GetFullPath($RecordPath) }
    else {
        $dir = Join-Path $repo 'docs\host-parity\smoke'
        $base = '{0}-{1}-cli' -f (Get-Date -Format 'yyyy-MM-dd'), $AgentHost
        $rid = $base; $n = 1
        while (Test-Path -LiteralPath (Join-Path $dir "$rid.md")) { $n++; $rid = "$base-$n" }
        $record = Join-Path $dir "$rid.md"
    }
    if (-not (Test-Path -LiteralPath $record)) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $record) -Force | Out-Null
        $rid = [System.IO.Path]::GetFileNameWithoutExtension($record)
        $hostName = if ($AgentHost -eq 'claude-code') { 'Claude Code' } else { 'Codex' }
        $version = 'unknown'
        try { $v = @(& $probe.Exe --version 2>$null) | Select-Object -First 1; if ($v) { $version = ([string]$v).Trim() } } catch { }
        $devVersion = (Get-Content -Raw -LiteralPath (Join-Path $repo 'plugins\cogniva-dev\.claude-plugin\plugin.json') | ConvertFrom-Json).version
        $skillsVersion = (Get-Content -Raw -LiteralPath (Join-Path $repo 'plugins\cogniva-skills\.claude-plugin\plugin.json') | ConvertFrom-Json).version
        $sha = (@(& git -C $repo rev-parse --short HEAD 2>$null) | Select-Object -First 1)
        $source = if ($PluginSource) { $PluginSource } elseif ($AgentHost -eq 'claude-code' -and $PluginDir) { "local marketplace from $repo @ $sha (--plugin-dir $PluginDir)" } else { 'installed marketplace' }
        $lines = @(
            "# Smoke record $rid",
            "Agent host: $hostName",
            "Agent host version: $version",
            'Surface: CLI',
            "OS: Windows 11 $([System.Environment]::OSVersion.Version.Build)",
            "Plugin versions: cogniva-dev $devVersion, cogniva-skills $skillsVersion",
            "Plugin source: $source",
            "Date: $(Get-Date -Format 'yyyy-MM-dd')",
            "Covers: $Covers",
            '',
            '## Scenarios',
            '',
            '| Scenario | Result | Assertion output | Notes |',
            '|---|---|---|---|',
            '',
            '## Observations',
            '',
            "- Command: ``$(Format-Command $probe)`` (prompt on stdin, run from the fixture folder); fixtures under ``$FixtureRoot``, outputs under ``$OutDir``."
        )
        if ($AgentHost -eq 'claude-code' -and $PluginDir) { $lines += '- Isolation: `--setting-sources project,local`, so user-level settings and installed plugins are not loaded; cogniva-dev comes from `--plugin-dir` only.' }
        [System.IO.File]::WriteAllText($record, (($lines -join "`n") + "`n"), $utf8)
    }
}
function Add-RecordRow([string]$Row) {
    $lines = [System.Collections.Generic.List[string]]::new([string[]](([System.IO.File]::ReadAllText($record)).Replace("`r`n", "`n").TrimEnd("`n") -split "`n"))
    $obs = $lines.IndexOf('## Observations')
    if ($obs -lt 0) { Fail "record has no '## Observations' heading: $record" }
    $at = $obs
    for ($i = $obs - 1; $i -ge 0; $i--) { if ($lines[$i].StartsWith('|')) { $at = $i + 1; break } }
    $lines.Insert($at, $Row)
    [System.IO.File]::WriteAllText($record, (($lines -join "`n") + "`n"), $utf8)
}

$summary = @()
foreach ($run in $runs) {
    $s = Get-ScenarioData $run.Id
    $label = if ($run.Resume) { "$($run.Id) (resume)" } else { $run.Id }
    $stem = if ($run.Resume) { "$($run.Id).resume" } else { $run.Id }
    $fixture = Join-Path $FixtureRoot $run.Id
    $finalFile = Join-Path $OutDir "$stem.final.txt"
    $transcript = Join-Path $OutDir "$stem.transcript.jsonl"
    if ($run.Resume) {
        if (-not (Test-Path -LiteralPath (Join-Path $fixture '.smoke\start.txt'))) { Fail "-Resume: no fixture at $fixture - run $($run.Id) without -Resume first" }
    }
    else {
        if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
        $build = @(& pwsh -NoProfile -File (Join-Path $here 'new-smoke-fixture.ps1') -Path $fixture -Scenario $run.Id 2>&1)
        if ($LASTEXITCODE -ne 0) { Fail "building the $($run.Id) fixture failed: $($build -join ' ')" }
    }
    if (Test-Path -LiteralPath $finalFile) { Remove-Item -LiteralPath $finalFile -Force }
    $cmd = Get-AgentCommand $fixture $finalFile
    Write-Output "RUN: $label - $(Format-Command $cmd)"
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $agentRun = Invoke-Agent $cmd $fixture (Get-Prompt $s) $transcript
    $watch.Stop()
    if ($AgentHost -eq 'claude-code') { [System.IO.File]::WriteAllText($finalFile, (Get-ClaudeFinal $agentRun.Stdout), $utf8) }
    elseif (-not (Test-Path -LiteralPath $finalFile)) { [System.IO.File]::WriteAllText($finalFile, '', $utf8) }

    $assertArgs = @('-NoProfile', '-File', (Join-Path $here 'assert-smoke-outcome.ps1'), '-Fixture', $fixture, '-Scenario', $run.Id, '-FinalMessage', $finalFile)
    if ($run.Resume) { $assertArgs += '-Resume' }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $assertOut = @(& pwsh @assertArgs 2>&1 | ForEach-Object { [string]$_ }); $assertCode = $LASTEXITCODE }
    finally { $ErrorActionPreference = $previous }
    [System.IO.File]::WriteAllText((Join-Path $OutDir "$stem.assert.txt"), (($assertOut -join "`n") + "`n"), $utf8)
    $result = switch ($assertCode) { 0 { 'pass' } 1 { 'fail' } default { 'not-run' } }
    if ($agentRun.TimedOut) { $result = 'not-run' }

    $verdict = @($assertOut | Where-Object { $_.StartsWith('SMOKE ') }) | Select-Object -First 1
    $failed = @($assertOut | Where-Object { $_.StartsWith('FAIL ') })
    $cell = (@($verdict) + $failed | Where-Object { $_ }) -join '; '
    if ($cell.Length -gt 400) { $cell = $cell.Substring(0, 400) + '...' }
    $notes = @("exit $($agentRun.ExitCode)", "$([int]$watch.Elapsed.TotalSeconds)s", "final: $stem.final.txt")
    if ($agentRun.TimedOut) { $notes += "timed out after $TimeoutMinutes min" }
    if ($AgentHost -eq 'claude-code') { $notes += $(if ($agentRun.Stdout -match '"name"\s*:\s*"Workflow"') { 'Workflow tool called' } else { 'no Workflow tool call' }) }
    if ($record) { Add-RecordRow ("| {0} | {1} | {2} | {3} |" -f (Format-Cell $label), $result, (Format-Cell $cell), (Format-Cell ($notes -join '; '))) }
    $summary += [pscustomobject]@{ Label = $label; Result = $result }
    Write-Output "SMOKE-RUN $($label): $result"
}
if ($record) { Write-Output "RECORD: $record" }
if (@($summary | Where-Object { $_.Result -ne 'pass' }).Count) { exit 1 }
exit 0
