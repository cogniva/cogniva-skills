# Dependency-free tests for the module-deps legacy Module-layout tool: -Check,
# allowed cycles, cycle-safe deterministic rendering, display-only glossary
# descriptions, kind labels, RepoRoot default, auto-commit, and no project data.
# Windows PowerShell 5.1. ASCII-only source.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = [System.IO.Path]::GetFullPath((Join-Path $here '..\..'))
$script = Join-Path $plugin 'skills\module-deps\module-deps.ps1'
$skill = Join-Path $plugin 'skills\module-deps\SKILL.md'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-module-deps-" + [guid]::NewGuid().ToString('N'))
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
# A project at <Repo>\<Folder>\<Name>\<Name>.csproj. module-deps resolves a
# ProjectReference by its file name, so the relative Include path is cosmetic.
function Add-Project([string]$Repo, [string]$Folder, [string]$Name, [string[]]$Refs) {
    $items = @($Refs | Where-Object { $_ } | ForEach-Object { "    <ProjectReference Include=`"..\$_\$_.csproj`" />" }) -join "`r`n"
    Write-Text (Join-Path $Repo "$Folder\$Name\$Name.csproj") "<Project Sdk=`"Microsoft.NET.Sdk`">`r`n  <ItemGroup>`r`n$items`r`n  </ItemGroup>`r`n</Project>`r`n"
}
function New-Repo([string]$Name) {
    $repo = Join-Path $root $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    & git -C $repo init -q
    & git -C $repo config user.email 'tests@cogniva.invalid'
    & git -C $repo config user.name 'Cogniva Tests'
    & git -C $repo config commit.gpgsign false
    & git -C $repo config core.autocrlf false
    return $repo
}
# Two Modules (A, B), a host, a Shell project and a BuildingBlocks project.
# A reaches B through four different kinds, one of them a qualified project.
function New-Fixture([string]$Name, [switch]$Cyclic) {
    $repo = New-Repo $Name
    Add-Project $repo 'src\Modules\A' 'A.Contracts' @('B.Contracts')
    Add-Project $repo 'src\Modules\A' 'A.Domain' @('App.Common')
    Add-Project $repo 'src\Modules\A' 'A.Application' @('A.Domain', 'A.Contracts', 'B.Contracts')
    Add-Project $repo 'src\Modules\A' 'A.Infrastructure.Store' @('A.Application', 'B.Contracts')
    Add-Project $repo 'src\Modules\A' 'A.Client' @('A.Contracts', 'B.Contracts')
    Add-Project $repo 'src\Modules\A' 'A.UI' @('A.Contracts', 'B.Contracts', 'App.Shell')
    Add-Project $repo 'src\Modules\B' 'B.Contracts' @()
    if ($Cyclic) { Add-Project $repo 'src\Modules\B' 'B.Application' @('B.Contracts', 'A.Contracts') }
    else { Add-Project $repo 'src\Modules\B' 'B.Application' @('B.Contracts') }
    Add-Project $repo 'src\Hosts' 'App.Host' @('A.Application', 'B.Application')
    Add-Project $repo 'src\Shell' 'App.Shell' @()
    Add-Project $repo 'src\BuildingBlocks' 'App.Common' @()
    return $repo
}
function Invoke-ModuleDeps([string[]]$Arguments, [string]$Shell = 'powershell', [string]$WorkingDirectory = $null) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if ($WorkingDirectory) { Push-Location -LiteralPath $WorkingDirectory }
    try {
        $lines = @(& $Shell -NoProfile -ExecutionPolicy Bypass -File $script @Arguments 2>&1)
        $code = $LASTEXITCODE
    }
    finally {
        if ($WorkingDirectory) { Pop-Location }
        $ErrorActionPreference = $previous
    }
    [pscustomobject]@{ Code = $code; Out = (@($lines | ForEach-Object { [string]$_ }) -join "`n") }
}
function Read-Utf8([string]$Path) { return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) }
function Get-CommitCount([string]$Repo) { return [int]((& git -C $Repo rev-list --count HEAD) | Select-Object -First 1) }
# Module -> tier number, read from the tiered Mermaid view of the Markdown.
function Get-Tiers([string]$MdText) {
    $tiers = @{}
    $tier = $null
    foreach ($line in ($MdText -split "`r?`n")) {
        if ($line -match '^\s*subgraph L(\d+)\[') { $tier = [int]$matches[1]; continue }
        if ($line -match '^\s*end\s*$') { $tier = $null; continue }
        if ($null -ne $tier -and $line -match '^\s{4}(\S+)\s*$') { $tiers[$matches[1]] = $tier }
    }
    return $tiers
}

try {
    # --- -Check -------------------------------------------------------------
    $acyclic = New-Fixture 'acyclic'
    $r = Invoke-ModuleDeps @('-RepoRoot', $acyclic, '-Check')
    Check '-Check on an acyclic graph exits 0' ($r.Code -eq 0 -and $r.Out -match 'module-deps check OK')
    Check '-Check writes nothing' (-not (Test-Path (Join-Path $acyclic 'docs\architecture')))

    $cyclic = New-Fixture 'cyclic' -Cyclic
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-Check')
    Check '-Check on a cycle exits 1 and names the pair' ($r.Code -eq 1 -and $r.Out -match 'A <-> B')
    Check '-Check names the kinds that introduce each edge' ($r.Out -match 'B -> A \(introduced by role\(s\): Application\)' -and $r.Out -match 'A -> B \(introduced by role\(s\): Application, Client, Contracts, Infrastructure, UI\)')
    Check '-Check on a cycle still writes nothing' (-not (Test-Path (Join-Path $cyclic 'docs\architecture')))

    $allowFile = Join-Path $cyclic 'docs\architecture\allowed-cycles.txt'
    Write-Text $allowFile "# Approved cycles.`r`nB <-> A   # reviewed: test fixture`r`n"
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-Check')
    Check 'an allowed pair passes in either order, with a trailing comment' ($r.Code -eq 0)
    Write-Text $allowFile "A - B`r`n"
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-Check')
    Check 'a malformed allowed-cycles line allows nothing and is reported' ($r.Code -eq 1 -and $r.Out -match "WARN: allowed-cycles\.txt line 1")
    Remove-Item -LiteralPath (Join-Path $cyclic 'docs') -Recurse -Force

    # A -> B -> C -> A is ONE cycle (one set of mutually reachable Modules),
    # reported and approved as a whole, never as three pairs.
    $tri = New-Repo 'three-cycle'
    Add-Project $tri 'src\Modules\A' 'A.Contracts' @()
    Add-Project $tri 'src\Modules\A' 'A.Application' @('A.Contracts', 'B.Contracts')
    Add-Project $tri 'src\Modules\B' 'B.Contracts' @()
    Add-Project $tri 'src\Modules\B' 'B.Application' @('B.Contracts', 'C.Contracts')
    Add-Project $tri 'src\Modules\C' 'C.Contracts' @()
    Add-Project $tri 'src\Modules\C' 'C.Application' @('C.Contracts', 'A.Contracts')
    $r = Invoke-ModuleDeps @('-RepoRoot', $tri, '-Check')
    Check 'a 3-Module cycle is reported once, as the whole cycle' ($r.Code -eq 1 -and $r.Out -match '(?m)^  A <-> B <-> C\s*$' -and $r.Out -notmatch '(?m)^  A <-> C\s*$' -and $r.Out -match 'C -> A \(introduced by role\(s\): Application\)')
    $triAllow = Join-Path $tri 'docs\architecture\allowed-cycles.txt'
    Write-Text $triAllow "A <-> B`nB <-> C`nA <-> C`n"
    $r = Invoke-ModuleDeps @('-RepoRoot', $tri, '-Check')
    Check 'pairs do not approve a larger cycle' ($r.Code -eq 1)
    Write-Text $triAllow "C <-> A <-> B   # reviewed: test fixture`n"
    $r = Invoke-ModuleDeps @('-RepoRoot', $tri, '-Check')
    Check 'a whole-cycle line approves it, members in any order' ($r.Code -eq 0)
    Write-Text $triAllow "A <-> A`n"
    $r = Invoke-ModuleDeps @('-RepoRoot', $tri, '-Check')
    Check 'a line repeating a Module is malformed' ($r.Code -eq 1 -and $r.Out -match 'WARN: allowed-cycles\.txt line 1')
    Remove-Item -LiteralPath (Join-Path $tri 'docs') -Recurse -Force
    $r = Invoke-ModuleDeps @('-RepoRoot', $tri, '-NoCommit')
    $triMd = Read-Utf8 (Join-Path $tri 'docs\architecture\module-dependencies.md')
    Check 'the Cycles section lists the 3-Module cycle once' ($triMd -match '(?m)^- A <-> B <-> C\s*$' -and $triMd -notmatch '(?m)^- A <-> C\s*$')

    # Descriptions are display-only: an unreadable glossary changes nothing in -Check.
    $glossaryPath = Join-Path $cyclic 'docs\glossary\README.md'
    New-Item -ItemType Directory -Path $glossaryPath -Force | Out-Null   # a directory where the file should be
    $r2 = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-Check')
    Check '-Check never reads the glossary' ($r2.Code -eq 1 -and $r2.Out -notmatch 'glossary')
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-NoCommit')
    Check 'an unreadable glossary only warns during generation' ($r.Code -eq 0 -and $r.Out -match 'WARN: could not read Module descriptions')
    Remove-Item -LiteralPath (Join-Path $cyclic 'docs') -Recurse -Force

    # --- generation on a cyclic graph ---------------------------------------
    $md = Join-Path $cyclic 'docs\architecture\module-dependencies.md'
    $html = Join-Path $cyclic 'docs\architecture\module-dependencies.html'
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-NoCommit')
    Check 'a cyclic graph renders instead of overflowing' ($r.Code -eq 0 -and (Test-Path $md) -and (Test-Path $html))
    $mdText = Read-Utf8 $md
    Check 'the cycle is listed in the Cycles section' ($mdText -match '(?m)^- A <-> B\s*$')
    Check 'Shell and BuildingBlocks projects are outside the graph' ($r.Out -match '(?m)^Modules: A, B\s*$' -and $mdText -notmatch 'App\.Shell' -and $mdText -notmatch '\*\*Shell\*\*')
    Check 'qualified projects roll up to their kind' ($mdText -match '\| Infrastructure \| B \|')
    Check 'Contracts and Client get distinct labels' ($mdText -match 'A -->\|A,Cl,Co,I,U\| B' -and $mdText -match '\*\*Cl\*\* = \.Client' -and $mdText -match '\*\*Co\*\* = \.Contracts')
    $firstMd = [System.IO.File]::ReadAllBytes($md)
    $firstHtml = [System.IO.File]::ReadAllBytes($html)
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-NoCommit')
    Check 'output is byte-identical across runs' (([Convert]::ToBase64String($firstMd) -eq [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($md))) -and ([Convert]::ToBase64String($firstHtml) -eq [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($html))))
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-NoCommit') 'pwsh'
        Check 'PowerShell 7 produces the same bytes as 5.1' ($r.Code -eq 0 -and ([Convert]::ToBase64String($firstMd) -eq [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($md))) -and ([Convert]::ToBase64String($firstHtml) -eq [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($html))))
    }
    else { Write-Host '  SKIP  cross-host determinism (pwsh not installed)' }

    # A <-> B is a cycle, B also uses the leaf C, and D uses A. A cycle is one
    # deployment unit, so its Modules share a tier: C=0, A=B=1, D=2.
    $tiered = New-Repo 'tiers'
    Add-Project $tiered 'src\Modules\A' 'A.Contracts' @()
    Add-Project $tiered 'src\Modules\A' 'A.Application' @('A.Contracts', 'B.Contracts')
    Add-Project $tiered 'src\Modules\B' 'B.Contracts' @()
    Add-Project $tiered 'src\Modules\B' 'B.Application' @('B.Contracts', 'A.Contracts', 'C.Contracts')
    Add-Project $tiered 'src\Modules\C' 'C.Contracts' @()
    Add-Project $tiered 'src\Modules\D' 'D.Application' @('A.Contracts')
    $r = Invoke-ModuleDeps @('-RepoRoot', $tiered, '-NoCommit')
    $tiers = Get-Tiers (Read-Utf8 (Join-Path $tiered 'docs\architecture\module-dependencies.md'))
    Check 'Modules in one cycle share a tier, and depth is measured from that tier' ($r.Code -eq 0 -and $tiers['C'] -eq 0 -and $tiers['A'] -eq 1 -and $tiers['B'] -eq 1 -and $tiers['D'] -eq 2)

    # --- descriptions from the glossary -------------------------------------
    $e = [string][char]0x00E9
    Write-Text (Join-Path $cyclic 'docs\glossary\README.md') "# Glossary`n`n## A (Module)`n`nOwns [things](#thing) | pipes, caf$e.`nSecond line.`n`nNot part of it.`n`n## Other`n`nText.`n"
    $r = Invoke-ModuleDeps @('-RepoRoot', $cyclic, '-NoCommit')
    $mdText = Read-Utf8 $md
    Check 'a glossary entry becomes the description, links reduced to text' ($mdText.Contains("| **A** | Owns things \| pipes, caf$e. Second line. |"))
    Check 'a Module without an entry gets the glossary placeholder' ($mdText.Contains('add a `## B (Module)` entry to docs/glossary/README.md'))
    $bytes = [System.IO.File]::ReadAllBytes($html)
    Check 'output is UTF-8 without a BOM and keeps non-ASCII text' (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) -and (Read-Utf8 $html).Contains("caf$e"))

    # --- RepoRoot default ---------------------------------------------------
    $nested = New-Fixture 'repo-root-default'
    $r = Invoke-ModuleDeps @('-NoCommit') 'powershell' (Join-Path $nested 'src\Modules')
    Check 'RepoRoot defaults to the git top level of the current directory' ($r.Code -eq 0 -and (Test-Path (Join-Path $nested 'docs\architecture\module-dependencies.md')))
    $outside = Join-Path $root 'not-a-repo'
    New-Item -ItemType Directory -Path $outside -Force | Out-Null
    $r = Invoke-ModuleDeps @('-NoCommit') 'powershell' $outside
    Check 'outside a git repo it stops and asks for -RepoRoot' ($r.Code -ne 0 -and $r.Out -match 'pass -RepoRoot')

    # --- commit behaviour ---------------------------------------------------
    $commit = New-Fixture 'commit'
    & git -C $commit add -A
    & git -C $commit commit -q -m 'fixture'
    $before = Get-CommitCount $commit
    $r = Invoke-ModuleDeps @('-RepoRoot', $commit, '-NoCommit')
    Check '-NoCommit creates no commit' ((Get-CommitCount $commit) -eq $before)
    $r = Invoke-ModuleDeps @('-RepoRoot', $commit)
    $subject = (& git -C $commit log -1 --format=%s) | Select-Object -First 1
    Check 'the default run commits only the two graph files' ((Get-CommitCount $commit) -eq ($before + 1) -and $subject -eq 'docs: regenerate module dependency graph' -and @(& git -C $commit show --name-only --format= HEAD | Where-Object { $_ }).Count -eq 2)
    $r = Invoke-ModuleDeps @('-RepoRoot', $commit)
    Check 'an unchanged graph is not committed again' ((Get-CommitCount $commit) -eq ($before + 1) -and $r.Out -match 'Graph unchanged')

    # --- no project data, ASCII source, SKILL contract ----------------------
    $source = [System.IO.File]::ReadAllText($script)
    $leaks = @('NewCogniva', 'CognivaShell', 'Analysis', 'C3Data', 'Connectivity', 'Crawling', 'Destinations', 'DocumentOrchestration', 'DocumentStore', 'GovernanceOrchestration', 'Import', 'Jobs', 'Mapping', 'Migration', 'Reasoning', 'Selections', 'StructureInsights') | Where-Object { $source -cmatch "\b$_\b" }
    Check 'the script carries no project names or data' (@($leaks).Count -eq 0 -and $source -cnotmatch "'Shell'")
    Check 'the script source is ASCII-only' (@([System.IO.File]::ReadAllBytes($script) | Where-Object { $_ -gt 127 }).Count -eq 0)
    $skillText = [System.IO.File]::ReadAllText($skill)
    Check 'SKILL.md calls it the legacy Module-layout tool' ($skillText -match 'legacy Module-layout tool')
    Check 'SKILL.md documents -Check and allowed cycles' ($skillText -match '-Check' -and $skillText -match 'allowed-cycles\.txt')
    Check 'SKILL.md documents glossary descriptions and the opt-in hook' ($skillText -match '## <Name> \(Module\)' -and $skillText -match 'moduleDepsCheck')
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures.Count) { Write-Host ''; Write-Host "FAILED: $($failures.Count) assertion(s)."; exit 1 }
Write-Host ''
Write-Host 'All module-deps assertions passed.'
exit 0
