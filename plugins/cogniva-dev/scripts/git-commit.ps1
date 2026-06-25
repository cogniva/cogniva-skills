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

# Pass the message via a temp file (-F) rather than -m. Windows PowerShell 5.1
# mangles native-exe arguments that contain embedded double-quotes, which would
# split a multi-line/quoted message into stray pathspecs; a message file avoids
# all inline-quoting hazards and preserves the message bytes exactly.
$msgFile = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllText($msgFile, $Message, [System.Text.UTF8Encoding]::new($false))
    & git -C $RepoPath commit -F $msgFile
    if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("git-commit: git commit failed"); exit 1 }
}
finally {
    Remove-Item -LiteralPath $msgFile -Force -ErrorAction SilentlyContinue
}

$sha = (& git -C $RepoPath rev-parse --short HEAD)
Write-Output ($sha | Out-String).Trim()
exit 0
