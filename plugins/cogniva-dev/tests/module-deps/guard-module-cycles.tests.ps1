# Dependency-free tests for the opt-in module-deps PostToolUse hook
# (scripts/guard-module-cycles.js): it returns block feedback only for a confirmed cycle in a repo
# that opted in, and is silent everywhere else. Windows PowerShell 5.1.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$hook = Join-Path $plugin 'scripts\guard-module-cycles.js'
$hooksJson = Join-Path $plugin 'hooks\hooks.json'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-module-cycles-hook-" + [guid]::NewGuid().ToString('N'))
$failures = @()
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Check($label, $condition) {
    if ($condition) { Write-Host "  PASS  $label" }
    else { Write-Host "  FAIL  $label"; $script:failures += $label }
}
function Write-Text([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Text, $script:utf8NoBom)
}
function Add-Project([string]$Repo, [string]$Folder, [string]$Name, [string[]]$Refs) {
    $items = @($Refs | Where-Object { $_ } | ForEach-Object { "    <ProjectReference Include=`"..\$_\$_.csproj`" />" }) -join "`r`n"
    Write-Text (Join-Path $Repo "$Folder\$Name\$Name.csproj") "<Project Sdk=`"Microsoft.NET.Sdk`">`r`n  <ItemGroup>`r`n$items`r`n  </ItemGroup>`r`n</Project>`r`n"
}
function Invoke-Hook([string]$FilePath) {
    $payload = @{ tool_name = 'Edit'; tool_input = @{ file_path = $FilePath } } | ConvertTo-Json -Compress
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = @($payload | & node $hook 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    [pscustomobject]@{ Code = $code; Out = ((@($lines | ForEach-Object { [string]$_ }) -join "`n").Trim()) }
}

# Registration is checked even without node.
$registered = Get-Content -Raw -LiteralPath $hooksJson | ConvertFrom-Json
$post = @($registered.hooks.PostToolUse | Where-Object { $_.matcher -eq 'Write|Edit' } | ForEach-Object { $_.hooks } | Where-Object { $_.command -match 'guard-module-cycles\.js' })
Check 'hooks.json registers guard-module-cycles.js as a Write|Edit PostToolUse hook' ($post.Count -eq 1 -and $post[0].command -match '\$\{CLAUDE_PLUGIN_ROOT\}/scripts/guard-module-cycles\.js')

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host '  SKIP  hook behaviour (node not installed)'
}
else {
    try {
        $repo = Join-Path $root 'repo'
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        & git -C $repo init -q
        Add-Project $repo 'src\Modules\A' 'A.Contracts' @()
        Add-Project $repo 'src\Modules\A' 'A.Application' @('A.Contracts', 'B.Contracts')
        Add-Project $repo 'src\Modules\B' 'B.Contracts' @()
        Add-Project $repo 'src\Modules\B' 'B.Application' @('B.Contracts', 'A.Contracts')
        $csproj = Join-Path $repo 'src\Modules\B\B.Application\B.Application.csproj'
        $policy = Join-Path $repo '.claude\cogniva-dev\policy.json'

        $r = Invoke-Hook (Join-Path $repo 'README.md')
        Check 'a non-.csproj edit is silent' ($r.Code -eq 0 -and -not $r.Out)
        $r = Invoke-Hook $csproj
        Check 'a repo without policy.json is silent, even with a cycle' ($r.Code -eq 0 -and -not $r.Out)
        Write-Text $policy '{ "moduleDepsCheck": false }'
        $r = Invoke-Hook $csproj
        Check 'moduleDepsCheck false is silent' ($r.Code -eq 0 -and -not $r.Out)
        Write-Text $policy '{ "moduleDepsCheck": "yes" }'
        $r = Invoke-Hook $csproj
        Check 'a non-boolean moduleDepsCheck is silent' ($r.Code -eq 0 -and -not $r.Out)
        Write-Text $policy '{ "requiredDevelopmentBranchPrefix": "feature/", "moduleDepsCheck": true }'
        $r = Invoke-Hook $csproj
        $decision = $null
        try { $decision = $r.Out | ConvertFrom-Json } catch { }
        Check 'an opted-in repo with a cycle is blocked with the -Check report' ($r.Code -eq 0 -and $decision -and $decision.decision -eq 'block' -and $decision.reason -match 'A <-> B')
        Write-Text (Join-Path $repo 'docs\architecture\allowed-cycles.txt') "B <-> A  # reviewed`n"
        $r = Invoke-Hook $csproj
        Check 'an allowed cycle is not blocked' ($r.Code -eq 0 -and -not $r.Out)
        Remove-Item -LiteralPath (Join-Path $repo 'docs') -Recurse -Force
        Add-Project $repo 'src\Modules\B' 'B.Application' @('B.Contracts')
        $r = Invoke-Hook $csproj
        Check 'an opted-in repo without a cycle is silent' ($r.Code -eq 0 -and -not $r.Out)

        # The edited path must never pass through a shell: cmd.exe expands
        # %OS% even inside quotes, and /bin/sh runs $(...).
        $odd = Join-Path $root 'sh & %OS% $(echo x) ;q'
        New-Item -ItemType Directory -Path $odd -Force | Out-Null
        & git -C $odd init -q
        Add-Project $odd 'src\Modules\A' 'A.Contracts' @()
        Add-Project $odd 'src\Modules\A' 'A.Application' @('A.Contracts', 'B.Contracts')
        Add-Project $odd 'src\Modules\B' 'B.Contracts' @()
        Add-Project $odd 'src\Modules\B' 'B.Application' @('B.Contracts', 'A.Contracts')
        Write-Text (Join-Path $odd '.claude\cogniva-dev\policy.json') '{ "moduleDepsCheck": true }'
        $r = Invoke-Hook (Join-Path $odd 'src\Modules\B\B.Application\B.Application.csproj')
        $decision = $null
        try { $decision = $r.Out | ConvertFrom-Json } catch { }
        Check 'a repo path with shell-significant characters still gets the -Check report' ($r.Code -eq 0 -and $decision -and $decision.decision -eq 'block' -and $decision.reason -match 'A <-> B')

        $loose = Join-Path $root 'loose\X.csproj'
        Write-Text $loose '<Project />'
        $r = Invoke-Hook $loose
        Check 'a .csproj outside any git repo is silent' ($r.Code -eq 0 -and -not $r.Out)
        $r = Invoke-Hook (Join-Path $repo 'src\Modules\Z\Z.Missing\Z.Missing.csproj')
        Check 'a path whose folder does not exist is silent' ($r.Code -eq 0 -and -not $r.Out)
    }
    finally {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All guard-module-cycles assertions passed.'
exit 0
