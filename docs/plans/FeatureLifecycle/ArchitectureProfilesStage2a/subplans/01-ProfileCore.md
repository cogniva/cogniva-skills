# 01 ProfileCore — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/ArchitectureProfilesStage2a
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** Make repo-owned profiles a tested contract: a profile adds standards,
amends or replaces inherited ones, records the inherited text each change was
reviewed against, and the tools report, gate on and clear review state.

**Architecture:** All composition lives in `plugins/cogniva-dev/scripts/profile-lib.ps1`
(PowerShell 7). `resolve-architecture-profile.ps1` reports it (JSON + text,
`-Show`, `-Require`), `adopt-architecture-profile.ps1` gains adoption records
and `-Refresh`, and the new `accept-profile-delta.ps1` rewrites `basis:` lines.
Everything stays read-only except adopt and accept. The existing strict YAML
subset (ADR 0038) is unchanged: `applies-to` is a block list of quoted globs.

**Read these first:** `plugins/cogniva-dev/scripts/profile-lib.ps1`,
`plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1`,
`plugins/cogniva-dev/scripts/adopt-architecture-profile.ps1`,
`plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1`,
`docs/adr/0038-profile-files-use-strict-yaml-subset.md`,
`docs/adr/0040-architecture-profiles-copied-into-repos.md`.

**Terms (from `docs/glossary/README.md`, written in Sub-plan 04):** an
**Amendment** is `amendments/<inherited id>.md`; a **Replacement standard** is
`replacements/<inherited id>.md`; together they are "deltas" in code and output
only (not a glossary term). A **Library profile** is a profile shipped in the
plugin's `profiles/` — in a repo, its adopted copy has an adoption record at
`.cogniva/adopted/<id>.yml`. A **Repo-owned profile** is any profile in
`.cogniva/profiles/` without a record. Never call either a "managed" or "child"
profile in code, output or docs.

## File structure (locked)

```
plugins/cogniva-dev/scripts/profile-lib.ps1                 # normalisation, hashing, frontmatter, globs, ownership, delta composition
plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1 # new JSON fields, review text, -Show, -Require (exit 3)
plugins/cogniva-dev/scripts/adopt-architecture-profile.ps1   # adoption records, refresh outcomes, -Refresh, Stage 1 migration, REVIEW lines
plugins/cogniva-dev/scripts/accept-profile-delta.ps1         # NEW (pwsh 7): rewrite basis: lines of a repo-owned profile's deltas
plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1  # updated + new assertions
plugins/cogniva-dev/tests/architecture-profile/fixtures/stage1/cogniva-base/** # NEW: frozen copy of the Stage 1 library profile
plugins/cogniva-dev/tests/architecture-profile/fixtures/stage1/dotnet/**       # NEW: frozen copy of the Stage 1 library profile
docs/adr/NNNN-*.md                                            # ADRs C1, C2, C3, C6 (Task 4)
```

## Candidate ADRs

### ADR-C1: Repo-owned profiles change inherited standards by amendment; a same-id standard is an error
**Provenance:** Suggested by agent
**Relitigation:** Open to discussion
A profile adds new standards under `standards/`, changes an inherited one with
`amendments/<id>` (layered on the inherited text), or supersedes it outright
with `replacements/<id>`, which every resolver output flags. A same-id file in
`standards/` is an error rather than a silent override, because Stage 1's
silent replacement let a profile drop its parent's rules without anyone seeing it.
**Write with:** Task 4

### ADR-C2: An amendment records the inherited text it was reviewed against
**Provenance:** Suggested by agent
**Relitigation:** Open to discussion
Each amendment and replacement standard carries `basis:`, a hash of the
normalised inherited text it was written against. When that text changes, the
delta is reported as needing human review and resolution carries on with it
applied; tooling never tries to infer whether the change contradicts it.
**Write with:** Task 4

### ADR-C3: Adopted library profiles carry an adoption record; adopt never writes repo-owned profiles
**Provenance:** Suggested by agent
**Relitigation:** Open to discussion
adopt writes `.cogniva/adopted/<id>.yml` (source, plugin version, content hash)
beside each library profile it copies, so a refresh can tell a library update
(refreshed cleanly) from a local edit (blocked: the change belongs in a
repo-owned profile). A profile without a record is repo-owned and adopt never
writes it. Amends ADR 0040.
**Write with:** Task 4

### ADR-C6: Architecture-dependent changes stop only on review items they depend on
**Provenance:** Suggested by agent
**Relitigation:** Open to discussion
A skill that makes an architecture-dependent change passes the standards it
depends on to the resolver's `-Require`, which exits 3 when any of them needs
human review, and it stops then and only then. Review items on other standards
never block it, so one stale amendment cannot halt unrelated work.
**Write with:** Task 4

## Task 1: Delta composition, basis and review state in the resolver

**Files:**
- Modify: `plugins/cogniva-dev/scripts/profile-lib.ps1`
- Modify: `plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1`
- Test: `plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1`

Rules this task implements (restate them in code comments where useful):
- A profile folder holds `profile.yml`, `standards/`, `amendments/`, `replacements/`. A standard's id is its path relative to that folder (`architecture/owner.md`), compared case-insensitively.
- `standards/` takes **new ids only**. A file there whose id an ancestor already provides is an ERROR whose message contains `ambiguous` and names `amendments/<id>` and `replacements/<id>`.
- A profile may not both amend and replace one id (ERROR containing `both amends and replaces`). A delta may not target an id defined in the same profile's own `standards/` (ERROR containing `edit it there`).
- Composition runs root ancestor first. `replacements/<id>` supersedes the inherited text **and every ancestor amendment**; `amendments/<id>` is appended to the inherited text. Every level can amend, including library profiles.
- Every standard, amendment and replacement needs a frontmatter `description` (ERROR otherwise). Allowed frontmatter keys: `description`, `basis` (amendments/replacements only — in `standards/` it is ignored with a warning), `applies-to` (a scalar or block list of quoted globs). Other keys: warning, as today. A `basis` that is not 12 lowercase hex characters is an ERROR.
- `applies-to`: the most-derived part that declares it wins (a replacement uses only its own). Globs are repo-relative; `*` matches within one path segment, `**` matches zero or more whole segments; case follows the platform rule already in `$script:PathComparison`.
- **Normalisation** (exactly): strip a leading BOM; CRLF and lone CR become LF; drop every line that starts with `basis:`; trim trailing whitespace on each line; drop trailing blank lines; join with LF (no final newline).
- **basis** = first 12 lowercase hex characters of SHA-256 (UTF-8) over the normalised texts of the inherited parts (the base standard or nearest replacement, then each ancestor amendment, in chain order, frontmatter included), joined with a single LF.
- **States:** `ORPHANED` (no inherited text: the id no longer exists upstream) wins first; then `UNREVIEWED` (no `basis:`); `CURRENT` (basis matches); `STALE` (it does not). Any non-`CURRENT` delta still applies; the target stays `RESOLVED`. ORPHANED deltas still appear as standards so their guidance is not lost.
- **Ownership:** `library` when the source is the plugin library or `.cogniva/adopted/<id>.yml` exists in the repo; otherwise `repo-owned`.

- [x] **Step 1 (failing tests):** In `architecture-profile.tests.ps1`:
  1. Directly below `$failures = @()`, dot-source the library so tests can use its primitives:
     ```powershell
     . (Join-Path $plugin 'scripts\profile-lib.ps1')
     ```
  2. Replace the `Add-Profile` function with:
     ```powershell
     function Add-Profile([string]$Repo, [string]$Id, [string]$Yaml, [hashtable]$Standards) {
         Write-Fixture $Repo ".cogniva/profiles/$Id/profile.yml" $Yaml
         foreach ($key in $Standards.Keys) {
             $relative = if ($key -match '^(amendments|replacements)/') { $key } else { "standards/$key" }
             Write-Fixture $Repo ".cogniva/profiles/$Id/$relative" $Standards[$key]
         }
     }
     ```
  3. Below `function Std`, add:
     ```powershell
     function Delta([string]$Description, [string]$Basis, [string[]]$AppliesTo, [string]$Body = '# Delta body') {
         $fm = "---`ndescription: $Description`n"
         if ($Basis) { $fm += "basis: $Basis`n" }
         if ($AppliesTo) { $fm += "applies-to:`n" + (($AppliesTo | ForEach-Object { "  - `"$_`"" }) -join "`n") + "`n" }
         return "$fm---`n`n$Body`n"
     }
     function Basis([string[]]$Texts) { return Get-TextHash ((@($Texts | ForEach-Object { Get-NormalisedText $_ })) -join "`n") }
     ```
  4. In the `precedence` fixture, change the python profile line to:
     ```powershell
     Add-Profile $repo 'python' "description: Python.`ninherits: base`n" @{ 'amendments/architecture/owner.md' = (Delta 'Python owner.' (Basis @((Std 'Base owner.')))); 'python/layout.md' = (Std 'Python layout.') }
     ```
     and replace the check `'child same-path standard overrides the parent (case-insensitive)'` with:
     ```powershell
     Check 'an amendment composes onto the inherited standard' ($owner.Count -eq 1 -and $owner[0].From -eq 'base' -and @($owner[0].Amendments).Count -eq 1 -and $owner[0].Amendments[0].From -eq 'python' -and $owner[0].Amendments[0].State -eq 'CURRENT')
     ```
  5. Insert a new section directly above `# --- undeclared repos and suggestions`:
     ```powershell
     # --- deltas: amendments, replacements, basis and review state -------------
     Check 'normalisation: CRLF, trailing whitespace, trailing blank lines' ((Get-NormalisedText "a  `r`nb`r`n`r`n") -ceq "a`nb")
     Check 'normalisation: BOM and lone CR' ((Get-NormalisedText ([string][char]0xFEFF + "a`rb")) -ceq "a`nb")
     Check 'normalisation drops basis: lines' ((Get-NormalisedText "description: x`nbasis: 0123456789ab`ny") -ceq "description: x`ny")
     Check 'basis is 12 lowercase hex characters' ((Get-TextHash 'x') -cmatch '^[0-9a-f]{12}$')
     Check 'glob ** matches zero segments' (Test-GlobMatch 'src/Hosts/**' 'src/Hosts')
     Check 'glob ** matches several segments' (Test-GlobMatch 'src/Hosts/**' 'src/Hosts/Web/Program.cs')
     Check 'glob * stays within one segment' (-not (Test-GlobMatch 'src/*/x' 'src/a/b/x'))
     Check 'glob segment patterns match' (Test-GlobMatch 'src/Modules/*/*.Contracts/**' 'src/Modules/Orders/Orders.Contracts/IOrders.cs')
     Check 'glob does not match a longer segment name' (-not (Test-GlobMatch 'src/Hosts/**' 'src/HostsX/a.cs'))

     $d = New-Repo 'deltas'
     $baseOwner = Std 'Base owner.'
     $baseEdges = Std 'Base edges.'
     Add-Profile $d 'base' "description: Base.`n" @{ 'architecture/owner.md' = $baseOwner; 'architecture/edges.md' = $baseEdges }
     $midOwner = Delta 'Mid narrows owner.' (Basis @($baseOwner)) @('src/Hosts/**')
     $midEdges = Delta 'Mid edges.' (Basis @($baseEdges))
     Add-Profile $d 'mid' "description: Mid.`ninherits: base`n" @{ 'amendments/architecture/owner.md' = $midOwner; 'replacements/architecture/edges.md' = $midEdges }
     $leafOwner = Delta 'Leaf adds to owner.' (Basis @($baseOwner, $midOwner))
     Add-Profile $d 'leaf' "description: Leaf.`ninherits: mid`n" @{ 'amendments/architecture/owner.md' = $leafOwner; 'amendments/architecture/edges.md' = (Delta 'Leaf on mid edges.' (Basis @($midEdges))); 'leaf/own.md' = (Std 'Leaf own.') }
     Write-Fixture $d '.cogniva-profile.yml' "profile: leaf`n"
     Write-Fixture $d 'tools/.cogniva-profile.yml' "profile: base`n"
     $dBefore = @(& git -C $d status --porcelain)

     $r = Resolve-Json $d @('-Target', 'src/Hosts/Web/Program.cs,src/Lib/x.cs,tools/t.py')
     $leaf = $r.Json.Profiles.leaf
     $owner = @($leaf.Standards | Where-Object Id -eq 'architecture/owner.md')[0]
     $edges = @($leaf.Standards | Where-Object Id -eq 'architecture/edges.md')[0]
     Check 'three-level amendments compose root first' ($r.Code -eq 0 -and $owner.From -eq 'base' -and (@($owner.Amendments.From) -join '>') -eq 'mid>leaf' -and @($owner.Amendments | Where-Object State -ne 'CURRENT').Count -eq 0)
     Check 'the most-derived applies-to wins' ((@($owner.AppliesTo) -join ',') -eq 'src/Hosts/**')
     Check 'a replacement supersedes the inherited standard' ($edges.From -eq 'mid' -and $edges.ReplacedBy -eq 'mid' -and @($edges.Overrides) -contains 'base' -and @($edges.Amendments).Count -eq 1 -and $edges.Amendments[0].State -eq 'CURRENT')
     Check 'a current profile needs no review' ($r.Json.Targets[0].NeedsReview -eq $false -and @($leaf.Review).Count -eq 0)
     Check 'MatchedStandards lists only applies-to matches' ((@($r.Json.Targets[0].MatchedStandards) -join ',') -eq 'architecture/owner.md' -and @($r.Json.Targets[1].MatchedStandards).Count -eq 0)
     Check 'ChainDetail carries ownership' ((@($leaf.ChainDetail | ForEach-Object { "$($_.Id)=$($_.Ownership)" }) -join ',') -eq 'leaf=repo-owned,mid=repo-owned,base=repo-owned')
     Check 'a subtree marker resolves its own chain' ($r.Json.Targets[2].Profile -eq 'base' -and @(@($r.Json.Profiles.base.Standards | Where-Object Id -eq 'architecture/owner.md')[0].Amendments).Count -eq 0)
     $text = Invoke-Script $resolver @('-Repo', $d, '-Target', 'src/Hosts/Web/Program.cs', '-LibraryRoot', $library)
     Check 'text output flags a replacement' ($text.Out -match 'REPLACED - no longer receives base updates')
     Check 'text output lists amendments with ownership and state' ($text.Out -match 'AMENDED BY mid \(repo-owned, CURRENT\)' -and $text.Out -match 'AMENDED BY leaf \(repo-owned, CURRENT\)')
     Check 'index still carries descriptions, not bodies' (-not ($r.Raw -match '# Delta body'))
     $again = Resolve-Json $d @('-Target', 'src/Hosts/Web/Program.cs,src/Lib/x.cs,tools/t.py')
     Check 'delta resolution is deterministic' ($again.Raw -eq $r.Raw)

     Write-Fixture $d '.cogniva/profiles/mid/amendments/architecture/owner.md' ([string][char]0xFEFF + $midOwner.Replace("`n", "  `r`n"))
     $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs')
     Check 'BOM, CRLF and trailing whitespace keep a delta CURRENT' (@(@($r.Json.Profiles.leaf.Standards | Where-Object Id -eq 'architecture/owner.md')[0].Amendments | Where-Object State -ne 'CURRENT').Count -eq 0)

     Write-Fixture $d '.cogniva/profiles/base/standards/architecture/owner.md' (Std 'Base owner, changed.')
     $r = Resolve-Json $d @('-Target', 'src/Hosts/Web/Program.cs')
     $owner = @($r.Json.Profiles.leaf.Standards | Where-Object Id -eq 'architecture/owner.md')[0]
     Check 'a changed parent makes every delta below it STALE' ((@($owner.Amendments.State) -join ',') -eq 'STALE,STALE')
     Check 'STALE stays RESOLVED and marks the target and standard' ($r.Code -eq 0 -and $r.Json.Targets[0].Status -eq 'RESOLVED' -and $r.Json.Targets[0].NeedsReview -eq $true -and $owner.NeedsReview -eq $true)
     $item = @($r.Json.Profiles.leaf.Review | Where-Object Profile -eq 'mid')[0]
     Check 'a Review entry names profile, ownership, delta and both bases' ($item.Standard -eq 'architecture/owner.md' -and $item.Ownership -eq 'repo-owned' -and $item.Delta -eq 'amendment' -and $item.State -eq 'STALE' -and $item.Basis -eq (Basis @($baseOwner)) -and $item.Inherited -eq (Basis @((Std 'Base owner, changed.'))))
     $text = Invoke-Script $resolver @('-Repo', $d, '-Target', 'src/Hosts/Web/Program.cs', '-LibraryRoot', $library)
     Check 'text output says NEEDS HUMAN REVIEW under the profile line' ($text.Out -match "PROFILE: leaf[^`n]*`n  NEEDS HUMAN REVIEW" -and $text.Out -match 'REVIEW: architecture/owner\.md - mid \(repo-owned\) amendment is STALE')
     Write-Fixture $d '.cogniva/profiles/base/standards/architecture/owner.md' $baseOwner

     Write-Fixture $d '.cogniva/profiles/mid/amendments/architecture/owner.md' ($midOwner -replace 'basis: [0-9a-f]{12}', 'basis: ffffffffffff')
     $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs')
     $owner = @($r.Json.Profiles.leaf.Standards | Where-Object Id -eq 'architecture/owner.md')[0]
     Check "editing an ancestor's basis line does not make descendants STALE" ((@($owner.Amendments.State) -join ',') -eq 'STALE,CURRENT')
     Write-Fixture $d '.cogniva/profiles/mid/amendments/architecture/owner.md' $midOwner

     Write-Fixture $d '.cogniva/profiles/leaf/amendments/architecture/owner.md' (Delta 'Leaf adds to owner.' $null)
     Write-Fixture $d '.cogniva/profiles/leaf/amendments/architecture/missing.md' (Delta 'Amends nothing.' 'aaaaaaaaaaaa')
     $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs')
     $states = @($r.Json.Profiles.leaf.Review | ForEach-Object { "$($_.Standard)=$($_.State)" }) -join ','
     Check 'no basis is UNREVIEWED and a vanished target is ORPHANED; both stay RESOLVED' ($r.Code -eq 0 -and $r.Json.Targets[0].Status -eq 'RESOLVED' -and $states -match 'architecture/owner\.md=UNREVIEWED' -and $states -match 'architecture/missing\.md=ORPHANED')
     Check 'an ORPHANED amendment still appears as a standard' (@($r.Json.Profiles.leaf.Standards | Where-Object Id -eq 'architecture/missing.md').Count -eq 1)
     Remove-Item -LiteralPath (Join-Path $d '.cogniva/profiles/leaf/amendments/architecture/missing.md')
     Write-Fixture $d '.cogniva/profiles/leaf/amendments/architecture/owner.md' $leafOwner

     Write-Fixture $d '.cogniva/adopted/base.yml' "source: plugin-library/base`nplugin-version: 0.0.0`ncontent: aaaaaaaaaaaa`n"
     $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs')
     Check 'an adoption record makes a profile library-owned' ((@($r.Json.Profiles.leaf.ChainDetail | Where-Object Id -eq 'base')[0].Ownership) -eq 'library')
     Remove-Item -LiteralPath (Join-Path $d '.cogniva/adopted') -Recurse -Force

     $dAfter = @(& git -C $d status --porcelain)
     Check 'delta resolution leaves the repository unchanged' (($dBefore -join "`n") -eq ($dAfter -join "`n"))

     Write-Fixture $d '.cogniva/profiles/leaf/standards/architecture/owner.md' (Std 'Same id.')
     $r = Resolve-Json $d @('-Target', 'x')
     Check 'a same-id file in standards/ is an ambiguous ERROR pointing at amendments/ and replacements/' (Test-TargetError $r 'ambiguous.*amendments/architecture/owner\.md.*replacements/architecture/owner\.md')
     Remove-Item -LiteralPath (Join-Path $d '.cogniva/profiles/leaf/standards/architecture/owner.md')
     Write-Fixture $d '.cogniva/profiles/leaf/replacements/architecture/owner.md' (Delta 'Also replaces.' 'aaaaaaaaaaaa')
     $r = Resolve-Json $d @('-Target', 'x')
     Check 'amending and replacing one id in one profile is an ERROR' (Test-TargetError $r 'both amends and replaces')
     Remove-Item -LiteralPath (Join-Path $d '.cogniva/profiles/leaf/replacements') -Recurse -Force
     Write-Fixture $d '.cogniva/profiles/leaf/amendments/leaf/own.md' (Delta 'Own.' 'aaaaaaaaaaaa')
     $r = Resolve-Json $d @('-Target', 'x')
     Check "amending the profile's own standard is an ERROR" (Test-TargetError $r 'edit it there')
     Remove-Item -LiteralPath (Join-Path $d '.cogniva/profiles/leaf/amendments/leaf') -Recurse -Force
     Write-Fixture $d '.cogniva/profiles/leaf/amendments/architecture/edges.md' "# no frontmatter`n"
     $r = Resolve-Json $d @('-Target', 'x')
     Check 'an amendment without a description is an ERROR' (Test-TargetError $r "amendments/architecture/edges\.md: missing frontmatter 'description'")
     Write-Fixture $d '.cogniva/profiles/leaf/amendments/architecture/edges.md' (Delta 'Bad basis.' 'XYZ')
     $r = Resolve-Json $d @('-Target', 'x')
     Check 'a malformed basis is an ERROR' (Test-TargetError $r "'basis' must be 12 lowercase hex characters")
     Write-Fixture $d '.cogniva/profiles/leaf/amendments/architecture/edges.md' (Delta 'Leaf on mid edges.' (Basis @($midEdges)))
     ```
- [x] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → FAIL lines (the new functions do not exist yet; the run may stop at the first missing function — that counts as the expected failure).
- [x] **Step 3 (implement, `profile-lib.ps1`):**
  - Add `$script:AdoptedRelative = '.cogniva/adopted'` and `$script:BasisPattern = '^[0-9a-f]{12}$'` beside the existing `$script:` settings.
  - Add these functions:
    ```powershell
    # Normalised text, the input to every basis and adoption hash: no BOM, LF line
    # endings, no `basis:` lines (so re-acknowledging an ancestor never makes its
    # descendants stale), no trailing whitespace, no trailing blank lines.
    function Get-NormalisedText([string]$Text) {
        if ($Text.Length -gt 0 -and $Text[0] -eq [char]0xFEFF) { $Text = $Text.Substring(1) }
        $lines = [System.Collections.Generic.List[string]]::new()
        foreach ($line in (($Text -replace "`r`n", "`n") -replace "`r", "`n") -split "`n") {
            if ($line -cmatch '^basis:') { continue }
            $lines.Add($line.TrimEnd())
        }
        while ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Length -eq 0) { $lines.RemoveAt($lines.Count - 1) }
        return ($lines -join "`n")
    }

    function Get-TextHash([string]$Text) {
        $hash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($Text))
        return [System.Convert]::ToHexString($hash).ToLowerInvariant().Substring(0, 12)
    }

    function Read-NormalisedFile([string]$Path) {
        return Get-NormalisedText ([System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false)))
    }

    # One hash for a whole profile folder: every file, ordinal path order.
    function Get-TreeHash([string]$Root) {
        $files = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
        foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File -Force) { $files[(Get-RelativeDisplay $Root $file.FullName)] = $file.FullName }
        $names = [string[]]@($files.Keys)
        [System.Array]::Sort($names, [System.StringComparer]::Ordinal)
        return Get-TextHash ((@($names | ForEach-Object { "$_`n$(Read-NormalisedFile $files[$_])" })) -join "`n`0`n")
    }

    # Repo-relative glob: '*' within one segment, '**' zero or more whole segments.
    function Test-GlobMatch([string]$Glob, [string]$Path) {
        $g = @($Glob.Replace('\', '/').Trim('/') -split '/' | Where-Object { $_ })
        $p = @($Path.Replace('\', '/').Trim('/') -split '/' | Where-Object { $_ -and $_ -ne '.' })
        return (Test-GlobSegments $g 0 $p 0)
    }
    function Test-GlobSegments([string[]]$G, [int]$GIndex, [string[]]$P, [int]$PIndex) {
        if ($GIndex -eq $G.Count) { return $PIndex -eq $P.Count }
        if ($G[$GIndex] -eq '**') {
            for ($k = $PIndex; $k -le $P.Count; $k++) { if (Test-GlobSegments $G ($GIndex + 1) $P $k) { return $true } }
            return $false
        }
        if ($PIndex -eq $P.Count) { return $false }
        $pattern = '^' + ([regex]::Escape($G[$GIndex]) -replace '\\\*', '[^/]*') + '$'
        $options = if ($IsLinux) { [System.Text.RegularExpressions.RegexOptions]::None } else { [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
        if (-not [regex]::IsMatch($P[$PIndex], $pattern, $options)) { return $false }
        return (Test-GlobSegments $G ($GIndex + 1) $P ($PIndex + 1))
    }

    function Get-ProfileOwnership($Source, [string]$Id) {
        if ($Source.IsLibrary) { return 'library' }
        if ($Source.RecordsRoot -and (Test-Path -LiteralPath (Join-Path $Source.RecordsRoot "$Id.yml") -PathType Leaf)) { return 'library' }
        return 'repo-owned'
    }
    ```
  - Change `New-ProfileSource` to `function New-ProfileSource([string]$Root, [string]$DisplayRoot, [string]$RecordsRoot, [switch]$IsLibrary)` returning `[pscustomobject]@{ Root = $Root; Display = $DisplayRoot; RecordsRoot = $RecordsRoot; IsLibrary = [bool]$IsLibrary; Cache = @{} }`.
  - Replace `Read-StandardDescription` with `Read-StandardFrontmatter([string]$Path, [string]$Display, [System.Collections.Generic.List[string]]$Warnings, [switch]$Delta)` returning `[pscustomobject]@{ Description; Basis; AppliesTo }` (Description `$null` when absent, Basis `$null`, AppliesTo `@()`). Keep today's frontmatter parsing (`---` … `---`, `ConvertFrom-CognivaYaml $body $Display 1`). For each key: `description` (string) → Description; `basis` → when not `-Delta` add warning `"${Display}: frontmatter key 'basis' is ignored outside amendments/ and replacements/"`, else require a string matching `$script:BasisPattern` (`-cmatch`) or `Throw-ProfileError "${Display}: 'basis' must be 12 lowercase hex characters"`; `applies-to` → `@($data['applies-to'])`, and `Throw-ProfileError "${Display}: applies-to globs are repo-relative"` for any glob that is rooted or contains `..`; any other key → today's "is ignored" warning. Use if/elseif, not `switch` with `continue`.
  - Add `Get-ProfileFiles($Entry, [string]$Folder, [System.Collections.Generic.List[string]]$Warnings)` returning an `[ordered]@{}` keyed by lowercased id → `[pscustomobject]@{ Id; Path; Display }` for every `*.md` under `<profile>/<Folder>` (`Sort-Object FullName`), throwing today's `collides with … (standard paths are compared case-insensitively)` error on a case collision, and returning an empty map when the folder is absent. `Display` is `"$($Entry.Display)/$Folder/$id"`.
  - Replace `Get-MergedStandards` with `Get-EffectiveStandards([string[]]$Chain, $Source, [System.Collections.Generic.List[string]]$Warnings)` that returns `[pscustomobject]@{ Standards = @(...sorted by lowercased Id...); Review = @(...) }`. For each profile, root ancestor first:
    1. Load the three folders with `Get-ProfileFiles`. Throw the "both amends and replaces" error (`"$display: $($entry.Display) both amends and replaces '$id'; keep one"`) and the "edit it there" error (`"$display: '$id' is defined in this profile's own standards/; edit it there"`) before composing.
    2. `standards/`: an id already in the merged map → `Throw-ProfileError "$($file.Display): ambiguous - '$($file.Id)' is inherited from $($merged[$key].From); put a narrow change in amendments/$($file.Id) or a whole-standard replacement in replacements/$($file.Id)"`. Otherwise add an entry `@{ Id; Description; From = profile; Path; Overrides = @(); ReplacedBy = $null; Amendments = @(); AppliesTo; NeedsReview = $false; Parts = @(part) }` where a part is `[pscustomobject]@{ Role = 'standard'|'replacement'|'amendment'; Standard = <the standard id>; From; Ownership; Path; Display; Description; State; Basis; Inherited }` (State/Basis/Inherited `$null` for `standard`). A missing description keeps today's error text: `missing frontmatter 'description' (agents choose which standards to open from it)`.
    3. For each delta (`replacements/` first, then `amendments/`), read its frontmatter with `-Delta`; require a description; compute `$inherited = if ($merged.Contains($key)) { @($merged[$key].Parts) } else { @() }`, `$computed = if ($inherited.Count) { Get-TextHash ((@($inherited | ForEach-Object { Read-NormalisedFile $_.Path })) -join "`n") } else { $null }`, and `$state = if (-not $inherited.Count) { 'ORPHANED' } elseif (-not $fm.Basis) { 'UNREVIEWED' } elseif ($fm.Basis -ceq $computed) { 'CURRENT' } else { 'STALE' }`.
       - Replacement on an existing entry: `Overrides += From`, `From = profile`, `ReplacedBy = profile`, `Path`, `Description`, `AppliesTo` = its own (or `@()`), `Amendments = @()`, `Parts = @(part)`. Orphaned replacement: a new entry with `From = ReplacedBy = profile`.
       - Amendment on an existing entry: `Amendments += [pscustomobject]@{ From; Ownership; Path; Description; State }`, `Parts += part`, and `AppliesTo` = its own when it declares any. Orphaned amendment: a new entry whose Description/Path are the amendment's, `From = profile`, `Amendments = @(that one)`, `Parts = @(part)`.
    4. Finally set each entry's `NeedsReview` to whether any part has a State other than `CURRENT` (`$null` States are base parts), and build `Review` from those parts: `[pscustomobject]@{ Standard = Id; Profile = part.From; Ownership; Delta = part.Role; State; Basis = part.Basis; Inherited = part.Inherited; Path = part.Display }`, sorted by Standard then Profile.
- [x] **Step 4 (implement, resolver):** In `resolve-architecture-profile.ps1`:
  - `$repoProfiles = New-ProfileSource (Join-Path $repoFull $script:RepoProfilesRelative) $script:RepoProfilesRelative (Join-Path $repoFull $script:AdoptedRelative)` and `$library = New-ProfileSource $LibraryRoot 'plugin-library' $null -IsLibrary`.
  - `Get-ProfileResult` stores `Effective = Get-EffectiveStandards …`, `Standards = $effective.Standards`, `Review = $effective.Review`, and `ChainDetail = @($chain | ForEach-Object { [pscustomobject]@{ Id = $_; Ownership = (Get-ProfileOwnership $repoProfiles $_) } })`. The failure object gets `Review = @(); ChainDetail = @()`.
  - Each target object gains `NeedsReview` (`$true` when its RESOLVED profile has any Review entry, else `$false`) and `MatchedStandards` (ids of that profile's standards with any `AppliesTo` glob where `Test-GlobMatch $glob $relative`; `@()` otherwise).
  - `Profiles.<id>` becomes `[pscustomobject]@{ Chain; ChainDetail; Description; Standards = @($r.Standards | Select-Object Id, Description, From, Overrides, Path, ReplacedBy, Amendments, AppliesTo, NeedsReview); Review }` — `Parts` never reaches JSON.
  - Text output: after the `PROFILE:` line of a RESOLVED target with `NeedsReview`, print `  NEEDS HUMAN REVIEW`. Per standard print `  STANDARD $($s.Id) [$($s.From)] - $($s.Description)` and the path line, then `    REPLACED - no longer receives $($s.Overrides[-1]) updates` when `ReplacedBy` and `Overrides` is non-empty, then `    AMENDED BY $($a.From) ($($a.Ownership), $($a.State)): $($a.Path)` per amendment, then `    APPLIES TO: $($s.AppliesTo -join ', ')` when non-empty. After a profile's standards print `  REVIEW: $($i.Standard) - $($i.Profile) ($($i.Ownership)) $($i.Delta) is $($i.State) (basis $basisShown -> $inheritedShown)` per Review entry, with `none` for a missing basis and `n/a` for a missing inherited hash.
  - Update the header comment to mention amendments, replacements and review state. Exit codes 0/1/2 keep their meanings.
- [x] **Step 5 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → ends with `All architecture-profile assertions passed.` Also run `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1` → `All applicable-rules assertions passed.` (it consumes the resolver JSON).
- [x] **Step 6 (commit):** `git add plugins/cogniva-dev/scripts/profile-lib.ps1 plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1 plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` then `git commit -m "feat(profiles): amendments, replacement standards, basis and review state"`

## Task 2: `-Show` and `-Require` (exit 3)

**Files:**
- Modify: `plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1`
- Test: `plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1`

Rules: `-Show <id>` prints the effective text of one standard for one target, with a provenance line before each part; it is text-only, read-only, exit 0 (exit 1 when the target is not RESOLVED, exit 2 for an unknown id, more than one target, or `-Format Json`). `-Require <id,…>` checks every RESOLVED target's profile: a listed id that is missing, or whose standard `NeedsReview`, blocks. Exit precedence: 2 (usage) > 1 (an ERROR target) > 3 (a required standard is blocked) > 0. A stale standard that is not listed never causes exit 3.

- [ ] **Step 1 (failing tests):** Insert directly above `# --- undeclared repos and suggestions` (after the Task 1 delta section, which leaves the `deltas` repo current):
  ```powershell
  # --- -Show and -Require ----------------------------------------------------
  $show = Invoke-Script $resolver @('-Repo', $d, '-Target', 'src/Lib/x.cs', '-Show', 'architecture/owner.md', '-LibraryRoot', $library)
  $iBase = $show.Out.IndexOf('--- standard from base (repo-owned): .cogniva/profiles/base/standards/architecture/owner.md')
  $iMid = $show.Out.IndexOf('--- amendment from mid (repo-owned, CURRENT): .cogniva/profiles/mid/amendments/architecture/owner.md')
  $iLeaf = $show.Out.IndexOf('--- amendment from leaf (repo-owned, CURRENT): .cogniva/profiles/leaf/amendments/architecture/owner.md')
  Check '-Show prints each part with provenance, root first' ($show.Code -eq 0 -and $iBase -ge 0 -and $iMid -gt $iBase -and $iLeaf -gt $iMid -and $show.Out -match '# Delta body')
  $show = Invoke-Script $resolver @('-Repo', $d, '-Target', 'src/Lib/x.cs', '-Show', 'architecture/nope.md', '-LibraryRoot', $library)
  Check '-Show of an unknown standard is a usage error' ($show.Code -eq 2)
  $show = Invoke-Script $resolver @('-Repo', $d, '-Target', 'src/Lib/x.cs', '-Show', 'architecture/owner.md', '-Format', 'Json', '-LibraryRoot', $library)
  Check '-Show does not combine with -Format Json' ($show.Code -eq 2)

  Write-Fixture $d '.cogniva/profiles/base/standards/architecture/owner.md' (Std 'Base owner, changed again.')
  $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs', '-Require', 'architecture/edges.md')
  Check '-Require passes when only an unrelated standard is stale' ($r.Code -eq 0 -and @($r.Json.Require.Blocked).Count -eq 0)
  $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs', '-Require', 'architecture/edges.md,architecture/owner.md')
  Check '-Require exits 3 naming the required standard that needs review' ($r.Code -eq 3 -and @($r.Json.Require.Blocked).Count -eq 1 -and $r.Json.Require.Blocked[0].Standard -eq 'architecture/owner.md' -and $r.Json.Require.Blocked[0].Reason -match 'needs human review')
  $r = Resolve-Json $d @('-Target', 'src/Lib/x.cs', '-Require', 'architecture/nope.md')
  Check '-Require exits 3 for a standard the profile lacks' ($r.Code -eq 3 -and $r.Json.Require.Blocked[0].Reason -match "not in profile 'leaf'")
  $text = Invoke-Script $resolver @('-Repo', $d, '-Target', 'src/Lib/x.cs', '-Require', 'architecture/owner.md', '-LibraryRoot', $library)
  Check '-Require text output names the blocked standard' ($text.Code -eq 3 -and $text.Out -match 'REQUIRE BLOCKED: src/Lib/x\.cs architecture/owner\.md')
  Write-Fixture $d '.cogniva/profiles/base/standards/architecture/owner.md' $baseOwner
  ```
  And in the `independent` section, after `'one broken target does not poison the others'`, add:
  ```powershell
  $r = Resolve-Json $split @('-Target', 'ok/a.py,missing/b.py', '-Require', 'rules/one.md')
  Check '-Require with an ERROR target exits 1, not 3' ($r.Code -eq 1)
  ```
  Note `Resolve-Json` only parses JSON for exit 0/1; change its line to `$json = if ($result.Code -in 0, 1, 3) { $result.Out | ConvertFrom-Json } else { $null }` and update its comment to `# Exit 0, 1 and 3 carry a JSON report (1 = some target is ERROR, 3 = a -Require standard is blocked); exit 2 carries none.`
- [ ] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → FAIL on the `-Show` / `-Require` checks.
- [ ] **Step 3 (implement):** In `resolve-architecture-profile.ps1`:
  - Add params `[string]$Show` and `[string[]]$Require`. In the argument `try` block: if `$Show` and `$Format -eq 'Json'` → `Fail '-Show prints text; do not combine it with -Format Json'`; if `$Show` and more than one requested target → `Fail '-Show takes exactly one target'`. Parse `$requireIds = @($Require | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ })`.
  - After targets are built and before the report is written: if `$Show`:
    ```powershell
    $t = $targets[0]
    if ($t.Status -ne 'RESOLVED') { Write-Output "architecture-profile: $($t.Target) has no resolved profile ($($t.Status))"; exit 1 }
    $wanted = $Show.Replace('\', '/')
    $s = @($profileResults[$t.Profile].Standards | Where-Object { $_.Id -ieq $wanted }) | Select-Object -First 1
    if (-not $s) { Fail "standard '$Show' is not in profile '$($t.Profile)'" }
    Write-Output "SHOW $($s.Id) - profile $($t.Profile) (chain: $($profileResults[$t.Profile].Chain -join ' -> '))"
    if ($s.NeedsReview) { Write-Output 'NEEDS HUMAN REVIEW' }
    foreach ($part in $s.Parts) {
        $state = if ($part.State) { ", $($part.State)" } else { '' }
        Write-Output ''
        Write-Output "--- $($part.Role) from $($part.From) ($($part.Ownership)$state): $($part.Display)"
        Write-Output ([System.IO.File]::ReadAllText($part.Path).TrimEnd())
    }
    exit 0
    ```
    (`$part.Display` must be the repo-relative display path, e.g. `.cogniva/profiles/base/standards/architecture/owner.md`.)
  - When `$requireIds.Count`: for each RESOLVED target and each id, add `[pscustomobject]@{ Target; Standard = $id; Reason }` to `$blocked` when the profile has no standard with that id (`-ieq`; Reason `"not in profile '<profile>'"`) or that standard `NeedsReview` (Reason `"needs human review: " + (parts with non-CURRENT State as "<From> <Role> <State>", joined '; ')`). Add `Require = [pscustomobject]@{ Standards = $requireIds; Blocked = @($blocked) }` to the report (omit the property when `-Require` was not given). Exit code: `if ($aggregate -eq 'ERROR') { 1 } elseif ($blocked.Count) { 3 } else { 0 }`.
  - Text output, before the `WARN:` lines: each blocked item as `REQUIRE BLOCKED: $($b.Target) $($b.Standard) - $($b.Reason)`, or `REQUIRE: ok ($($requireIds -join ', '))` when nothing is blocked.
  - Header comment: document `-Show`, `-Require` and `3 = a standard named by -Require is missing or needs human review`.
- [ ] **Step 4 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → `All architecture-profile assertions passed.`
- [ ] **Step 5 (commit):** `git add plugins/cogniva-dev/scripts/resolve-architecture-profile.ps1 plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` then `git commit -m "feat(profiles): -Show effective text and -Require mutation gate (exit 3)"`

## Task 3: Adoption records, refresh outcomes, `-Refresh`, Stage 1 migration

**Files:**
- Modify: `plugins/cogniva-dev/scripts/adopt-architecture-profile.ps1`
- Create: `plugins/cogniva-dev/tests/architecture-profile/fixtures/stage1/cogniva-base/**`, `plugins/cogniva-dev/tests/architecture-profile/fixtures/stage1/dotnet/**`
- Test: `plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1`

Outcomes, per profile in the adopted chain (repo copy vs plugin library, compared with `Get-TreeHash`, i.e. normalised):

| Repo copy | Record (`.cogniva/adopted/<id>.yml`) | Result |
|---|---|---|
| absent | — | `ADOPTED` + record |
| equals library | any | `UP-TO-DATE` (a missing or out-of-date record is written — this migrates Stage 1 adoptions) |
| equals the record, library newer | present | `REFRESHED` (no `-Force`) + record |
| differs from the record | present | `LOCALLY-EDITED`, blocked, exit 1; `-Force` → `REPLACED` |
| no record, equals a known Stage 1 library copy | absent | `REFRESHED` + record |
| differs, no record | absent | `DIFFERS`, blocked, exit 1; `-Force` → `REPLACED` |

Record format (YAML subset, LF): `source: plugin-library/<id>`, `plugin-version: <version from <plugin>/.claude-plugin/plugin.json, or unknown>`, `content: <Get-TreeHash of the library profile>`. Records are written only after every swap succeeded. `-Refresh` (instead of `-Profile`) refreshes every profile that has a record, plus any record-less copy whose id is in the library and whose hash equals the library or a Stage 1 hash; repo-owned profiles are never written. After writing, adopt prints `REMOVED: <id>/<file>` for files the refresh dropped, a pointer to the migration guide when a retired Stage 1 standard was dropped, and a `REVIEW:` line for every non-`CURRENT` delta of every repo-owned profile.

- [ ] **Step 1 (freeze Stage 1):** Copy `plugins/cogniva-dev/profiles/cogniva-base` and `plugins/cogniva-dev/profiles/dotnet` unchanged to `plugins/cogniva-dev/tests/architecture-profile/fixtures/stage1/cogniva-base` and `.../fixtures/stage1/dotnet` (`Copy-Item -Recurse`). These are the Stage 1 library profiles; Sub-plan 02 rewrites the live ones.
- [ ] **Step 2 (check the Stage 1 hashes):** `pwsh -NoProfile -Command ". ./plugins/cogniva-dev/scripts/profile-lib.ps1; Get-TreeHash plugins/cogniva-dev/tests/architecture-profile/fixtures/stage1/cogniva-base; Get-TreeHash plugins/cogniva-dev/tests/architecture-profile/fixtures/stage1/dotnet"` → `ae8f8cbe9d33` then `d38faa90eaf1` (computed at planning time from the Stage 1 library with the normalisation defined in Task 1). A different value means Task 1's `Get-NormalisedText` / `Get-TreeHash` drifted from the definition — fix the code, not the constants.
- [ ] **Step 3 (failing tests):** In the `# --- adoption` section:
  - After `'adopt never writes a marker'` add:
    ```powershell
    $rec = Join-Path $adopt '.cogniva/adopted/python.yml'
    Check 'adopt writes an adoption record per adopted profile' ((Test-Path $rec) -and (Test-Path (Join-Path $adopt '.cogniva/adopted/base.yml')) -and (Get-Content -Raw $rec) -match '(?m)^source: plugin-library/python$' -and (Get-Content -Raw $rec) -match '(?m)^content: [0-9a-f]{12}$' -and (Get-Content -Raw $rec) -match '(?m)^plugin-version: ')
    ```
  - Replace the check `'a locally edited copy blocks re-adoption and names the file'` with:
    ```powershell
    Check 'a locally edited copy is LOCALLY-EDITED, blocked, and names the file' ($a.Code -eq 1 -and $a.Out -match 'LOCALLY-EDITED: \.cogniva/profiles/python - standards/python/layout\.md' -and $a.Out -match 'repo-owned profile' -and (Get-Content -Raw $layout) -match 'Local edit')
    ```
  - After `'a successful replacement leaves no staging or backup folders'` add:
    ```powershell
    Write-Fixture $library 'python/standards/python/layout.md' (Std 'Python layout rule, revised.')
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'a library update over an unedited copy is REFRESHED without -Force' ($a.Code -eq 0 -and $a.Out -match 'REFRESHED: python' -and (Get-Content -Raw $layout) -match 'revised' -and (Get-Content -Raw $rec) -match ('content: ' + (Get-TreeHash (Join-Path $library 'python'))))
    Remove-Item -LiteralPath $rec
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'a copy equal to the library with no record is UP-TO-DATE and gains a record' ($a.Code -eq 0 -and $a.Out -match 'UP-TO-DATE: python' -and (Test-Path $rec))
    Remove-Item -LiteralPath $rec
    Add-Content -LiteralPath $layout -Value 'Unrecorded edit.'
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library)
    Check 'a differing copy with no record is DIFFERS and blocked' ($a.Code -eq 1 -and $a.Out -match 'DIFFERS: \.cogniva/profiles/python' -and -not (Test-Path $rec))
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Profile', 'python', '-LibraryRoot', $library, '-Force')
    Check '-Force replaces an unrecorded copy and records it' ($a.Code -eq 0 -and $a.Out -match 'REPLACED: python' -and (Test-Path $rec))

    # -Refresh: library profiles refresh, repo-owned profiles are byte-identical and get REVIEW lines.
    Add-Profile $adopt 'acme' "description: Acme.`ninherits: python`n" @{ 'amendments/python/layout.md' = (Delta 'Acme layout.' (Basis @((Std 'Python layout rule, revised.')))) }
    $acmeBefore = @(Get-ChildItem -LiteralPath (Join-Path $adopt '.cogniva/profiles/acme') -Recurse -File | Get-FileHash | ForEach-Object Hash) -join ','
    Write-Fixture $library 'python/standards/python/layout.md' (Std 'Python layout rule, third.')
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Refresh', '-LibraryRoot', $library)
    $acmeAfter = @(Get-ChildItem -LiteralPath (Join-Path $adopt '.cogniva/profiles/acme') -Recurse -File | Get-FileHash | ForEach-Object Hash) -join ','
    Check '-Refresh refreshes every adopted library profile' ($a.Code -eq 0 -and $a.Out -match 'REFRESHED: python' -and $a.Out -match 'UP-TO-DATE: base')
    Check '-Refresh leaves a repo-owned profile byte-identical' ($acmeBefore -eq $acmeAfter -and -not (Test-Path (Join-Path $adopt '.cogniva/adopted/acme.yml')))
    Check 'adopt prints REVIEW for a repo-owned delta that went stale' ($a.Out -match 'REVIEW: acme amendment python/layout\.md is STALE')
    $a = Invoke-Script $adopter @('-Repo', $adopt, '-Refresh', '-Profile', 'python', '-LibraryRoot', $library)
    Check '-Refresh and -Profile together are a usage error' ($a.Code -eq 2)
    Remove-Item -LiteralPath (Join-Path $adopt '.cogniva/profiles/acme') -Recurse -Force

    # Stage 1 migration: a record-less copy of the Stage 1 library refreshes cleanly.
    $stage1 = Join-Path $here 'fixtures\stage1'
    $migrate = New-Repo 'stage1'
    $newLibrary = Join-Path $root 'library-next'
    New-Item -ItemType Directory -Path (Join-Path $migrate '.cogniva/profiles'), $newLibrary -Force | Out-Null
    foreach ($id in 'cogniva-base', 'dotnet') { Copy-Item -LiteralPath (Join-Path $stage1 $id) -Destination (Join-Path $migrate ".cogniva/profiles/$id") -Recurse -Force }
    foreach ($id in 'cogniva-base', 'dotnet') { Copy-Item -LiteralPath (Join-Path $stage1 $id) -Destination (Join-Path $newLibrary $id) -Recurse -Force }
    Remove-Item -LiteralPath (Join-Path $newLibrary 'dotnet/standards/dotnet/module-layout.md')
    Write-Fixture $newLibrary 'dotnet/standards/dotnet/project-layout.md' (Std 'Next layout.')
    $a = Invoke-Script $adopter @('-Repo', $migrate, '-Profile', 'dotnet', '-LibraryRoot', $newLibrary)
    Check 'a Stage 1 adoption with no record refreshes without -Force' ($a.Code -eq 0 -and $a.Out -match 'REFRESHED: dotnet' -and $a.Out -match 'UP-TO-DATE: cogniva-base' -and (Test-Path (Join-Path $migrate '.cogniva/adopted/dotnet.yml')))
    Check 'a dropped Stage 1 standard is reported with the migration guide' ($a.Out -match 'REMOVED: dotnet/standards/dotnet/module-layout\.md' -and $a.Out -match 'module-bundle-migration\.md')
    ```
- [ ] **Step 4 (implement):** In `adopt-architecture-profile.ps1`:
  - Param block: `[string]$Profile` (no longer Mandatory), `[switch]$Refresh`, keep `$LibraryRoot`, `$Force`. Exactly one of `-Profile` / `-Refresh`, else `Fail 'pass -Profile <id> or -Refresh'`.
  - Add near the top:
    ```powershell
    # Tree hashes of the Stage 1 library profiles (frozen in tests/architecture-profile/fixtures/stage1),
    # so a Stage 1 adoption, which has no record, refreshes cleanly instead of reading as a local edit.
    $script:Stage1Hashes = @{ 'cogniva-base' = @('ae8f8cbe9d33'); 'dotnet' = @('d38faa90eaf1') }
    # Stage 1 standards that left the library; their text lives in the migration guide.
    $script:RetiredStandards = @{ 'dotnet' = @('standards/dotnet/module-layout.md', 'standards/dotnet/module-dependencies.md') }
    ```
  - `Get-TreeSnapshot` stores `Read-NormalisedFile` text per relative path (so the differing-files list uses the same normalisation as the hash).
  - Records root: `$recordsRoot = Join-Path $repoFull $script:AdoptedRelative`. Read an existing record with `Read-CognivaYamlFile $file @('source', 'plugin-version', 'content') @('content') ".cogniva/adopted/$id.yml"` (a malformed record → `Fail`). Plugin version: `(Get-Content -Raw (Join-Path (Split-Path -Parent $PSScriptRoot) '.claude-plugin/plugin.json') | ConvertFrom-Json).version`, or `unknown` if unreadable.
  - Build the ids to adopt: `-Profile` → `Resolve-ProfileChain $Profile $library $null '-Profile'`; `-Refresh` → for each `.cogniva/adopted/*.yml` id plus each record-less `.cogniva/profiles/<id>` whose id the library has and whose `Get-TreeHash` equals the library's or is in `$script:Stage1Hashes[$id]`, add `Resolve-ProfileChain $id $library $null "-Refresh ($id)"`, de-duplicated in first-seen order. None → `Write-Output 'Nothing to refresh: no adopted library profiles.'; exit 0`. An id with a record but no longer in the library → `Fail`.
  - Decide each step's Action with the table above (`$libHash = Get-TreeHash $source`, `$copyHash = Get-TreeHash $dest`). Blocked actions (`LOCALLY-EDITED`, `DIFFERS`) without `-Force` print `LOCALLY-EDITED: .cogniva/profiles/<id> - <files>` / `DIFFERS: .cogniva/profiles/<id> - <files>`, then one line: `Nothing written. A locally edited library copy belongs in a repo-owned profile (amendments/ or replacements/); re-run with -Force to replace the copy.` and exit 1. With `-Force` they become `REPLACED`.
  - Keep the staging/swap/rollback code unchanged; use `Get-TreeHash` equality for the staged-copy verification. Steps with Action `UP-TO-DATE` are not swapped.
  - After a successful swap: write the record for every step that is not `UP-TO-DATE`, and for an `UP-TO-DATE` step whose record is missing or whose `content` differs from `$libHash` (`[System.IO.File]::WriteAllText` with LF, creating `.cogniva/adopted/`). For each swapped step whose previous copy existed, print `REMOVED: <id>/<file>` for every file in the old snapshot absent from the library; if any is in `$script:RetiredStandards[$id]`, print once: `NOTE: these standards left the library; their text is in the Module bundle layout migration guide (docs/module-bundle-migration.md in the cogniva-dev plugin).`
  - Then print the outcome lines (`ADOPTED: <id> -> .cogniva/profiles/<id>`, `UP-TO-DATE: <id>`, `REFRESHED: <id> -> …`, `REPLACED: <id> -> …`), then for every repo-owned profile folder in `.cogniva/profiles` (`Get-ProfileOwnership` on a `New-ProfileSource $destRoot $script:RepoProfilesRelative $recordsRoot`), resolve its chain and `Get-EffectiveStandards`, and print `REVIEW: <profile> <delta> <standard> is <STATE> - review it, then run accept-profile-delta.ps1 -Profile <profile> -Standard <standard>` for each of its own Review entries (`Profile -eq` that folder); a resolution error there prints `WARN: <message>` and does not change the exit code. Keep the final "To declare it" line for `-Profile` runs.
  - Update the header comment with the outcome table and exit codes (0 adopted/refreshed/up to date; 1 blocked, nothing written; 2 usage, profile or copy error).
- [ ] **Step 5 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → `All architecture-profile assertions passed.`
- [ ] **Step 6 (commit):** `git add plugins/cogniva-dev/scripts/adopt-architecture-profile.ps1 plugins/cogniva-dev/tests/architecture-profile` then `git commit -m "feat(profiles): adoption records, clean refresh, -Refresh and Stage 1 migration"`

## Task 4: `accept-profile-delta.ps1` and ADRs

**Files:**
- Create: `plugins/cogniva-dev/scripts/accept-profile-delta.ps1`
- Test: `plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1`
- Create: four ADRs under `docs/adr/`

Rules: it rewrites only `basis:` frontmatter lines of the named profile's **own** amendments and replacements (inserting `basis:` right after `description:` when absent), preserving BOM presence and line endings. A repo profile with an adoption record is refused (exit 2: library profiles are reviewed upstream). `-Library` points it at the plugin's `profiles/` (or `-LibraryRoot`) for maintainers and skips the record check. Exactly one of `-Standard <id>` / `-All`. `CURRENT` → `UP-TO-DATE`; `STALE`/`UNREVIEWED` → `ACCEPTED`; `ORPHANED` cannot be accepted (exit 1). An id that is not one of the profile's deltas → exit 2.

- [ ] **Step 1 (failing tests):** Add `$accepter = Join-Path $plugin 'scripts\accept-profile-delta.ps1'` beside `$adopter`, and insert directly above `# --- undeclared repos and suggestions`:
  ```powershell
  # --- accept-profile-delta --------------------------------------------------
  $acc = New-Repo 'accept'
  $accBase = Std 'Acc base.'
  Add-Profile $acc 'base' "description: Base.`n" @{ 'architecture/a.md' = $accBase; 'architecture/b.md' = (Std 'Acc b.') }
  Add-Profile $acc 'kid' "description: Kid.`ninherits: base`n" @{ 'amendments/architecture/a.md' = (Delta 'Kid a.' (Basis @($accBase))); 'amendments/architecture/b.md' = (Delta 'Kid b.' $null) }
  $kidA = Join-Path $acc '.cogniva/profiles/kid/amendments/architecture/a.md'
  $kidB = Join-Path $acc '.cogniva/profiles/kid/amendments/architecture/b.md'
  [System.IO.File]::WriteAllText($kidA, ([System.IO.File]::ReadAllText($kidA)).Replace("`n", "`r`n"))
  Write-Fixture $acc '.cogniva/profiles/base/standards/architecture/a.md' (Std 'Acc base, changed.')
  $linesBefore = @([System.IO.File]::ReadAllLines($kidA) | Where-Object { $_ -notmatch '^basis:' })
  $x = Invoke-Script $accepter @('-Repo', $acc, '-Profile', 'kid', '-Standard', 'architecture/a.md')
  Check 'accept -Standard rewrites only that basis line' ($x.Code -eq 0 -and $x.Out -match 'ACCEPTED: \.cogniva/profiles/kid/amendments/architecture/a\.md basis [0-9a-f]{12} -> ' -and (($linesBefore -join '|') -eq ((@([System.IO.File]::ReadAllLines($kidA) | Where-Object { $_ -notmatch '^basis:' })) -join '|')))
  Check 'accept preserves CRLF line endings' (([System.IO.File]::ReadAllText($kidA)).Contains("`r`n"))
  Check 'accept -Standard leaves other deltas alone' (-not ((Get-Content -Raw $kidB) -match 'basis:'))
  Write-Fixture $acc '.cogniva-profile.yml' "profile: kid`n"
  $r = Resolve-Json $acc @('-Target', 'x')
  Check 'an accepted delta is CURRENT' ((@($r.Json.Profiles.kid.Review | Where-Object Standard -eq 'architecture/a.md')).Count -eq 0)
  $x = Invoke-Script $accepter @('-Repo', $acc, '-Profile', 'kid', '-All')
  Check 'accept -All inserts a missing basis after description' ($x.Code -eq 0 -and $x.Out -match 'UP-TO-DATE: .*architecture/a\.md' -and (Get-Content $kidB)[2] -match '^basis: [0-9a-f]{12}$')
  $r = Resolve-Json $acc @('-Target', 'x')
  Check 'after accept -All nothing needs review' ($r.Json.Targets[0].NeedsReview -eq $false)
  Write-Fixture $acc '.cogniva/profiles/kid/amendments/architecture/gone.md' (Delta 'Gone.' 'aaaaaaaaaaaa')
  $x = Invoke-Script $accepter @('-Repo', $acc, '-Profile', 'kid', '-All')
  Check 'an ORPHANED delta cannot be accepted' ($x.Code -eq 1 -and $x.Out -match 'ORPHANED: .*architecture/gone\.md')
  Remove-Item -LiteralPath (Join-Path $acc '.cogniva/profiles/kid/amendments/architecture/gone.md')
  $x = Invoke-Script $accepter @('-Repo', $acc, '-Profile', 'kid', '-Standard', 'architecture/zzz.md')
  Check 'accepting an id that is not a delta of the profile is a usage error' ($x.Code -eq 2)
  $x = Invoke-Script $accepter @('-Repo', $acc, '-Profile', 'kid')
  Check 'accept needs -Standard or -All' ($x.Code -eq 2)
  Write-Fixture $acc '.cogniva/adopted/kid.yml' "content: aaaaaaaaaaaa`n"
  $x = Invoke-Script $accepter @('-Repo', $acc, '-Profile', 'kid', '-All')
  Check 'accept refuses an adopted library profile' ($x.Code -eq 2 -and $x.All -match 'library profile')
  Write-Fixture $library 'python/amendments/architecture/owner.md' (Delta 'Library python owner.' $null)
  $x = Invoke-Script $accepter @('-Library', '-LibraryRoot', $library, '-Profile', 'python', '-All')
  Check 'accept -Library updates a plugin library profile for maintainers' ($x.Code -eq 0 -and (Get-Content -Raw (Join-Path $library 'python/amendments/architecture/owner.md')) -match 'basis: [0-9a-f]{12}')
  Remove-Item -LiteralPath (Join-Path $library 'python/amendments') -Recurse -Force
  ```
- [ ] **Step 2 (run it, expect fail):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → FAIL on the accept checks.
- [ ] **Step 3 (implement):** Create `plugins/cogniva-dev/scripts/accept-profile-delta.ps1`:
  ```powershell
  #Requires -Version 7.0
  # Record that a human reviewed a repo-owned profile's amendments and replacement
  # standards against the inherited text they change: rewrites only their `basis:`
  # frontmatter lines (inserting one after `description:` when absent). Refuses an
  # adopted library profile - its deltas are reviewed upstream - unless -Library is
  # given, which works on the plugin's own profile library for maintainers.
  # Exit 0 = accepted or already current; 1 = an ORPHANED delta in scope cannot be
  # accepted; 2 = usage or profile error.
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)][string]$Profile,
      [string]$Repo,
      [string]$Standard,
      [switch]$All,
      [switch]$Library,
      [string]$LibraryRoot
  )
  $ErrorActionPreference = 'Stop'
  . (Join-Path $PSScriptRoot 'profile-lib.ps1')

  function Fail([string]$Message) { [Console]::Error.WriteLine("accept-profile-delta: $Message"); exit 2 }

  function Set-BasisLine([string]$Path, [string]$Basis) {
      $bytes = [System.IO.File]::ReadAllBytes($Path)
      $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
      $offset = if ($bom) { 3 } else { 0 }
      $body = [System.Text.UTF8Encoding]::new($false).GetString($bytes, $offset, $bytes.Length - $offset)
      $newline = if ($body.Contains("`r`n")) { "`r`n" } else { "`n" }
      $lines = [System.Collections.Generic.List[string]]::new([string[]]($body -split "`r?`n"))
      $end = -1
      for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '---') { $end = $i; break } }
      $existing = -1; $description = -1
      for ($i = 1; $i -lt $end; $i++) {
          if ($lines[$i] -cmatch '^basis:') { $existing = $i }
          if ($lines[$i] -cmatch '^description:') { $description = $i }
      }
      if ($existing -ge 0) { $lines[$existing] = "basis: $Basis" } else { $lines.Insert($description + 1, "basis: $Basis") }
      [System.IO.File]::WriteAllText($Path, ($lines -join $newline), [System.Text.UTF8Encoding]::new($bom))
  }

  try {
      Assert-ProfileId $Profile '-Profile'
      if ([bool]$Standard -eq [bool]$All) { Fail 'pass -Standard <id> or -All' }
      $warnings = [System.Collections.Generic.List[string]]::new()
      if ($Library) {
          if (-not $LibraryRoot) { $LibraryRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'profiles' }
          $source = New-ProfileSource $LibraryRoot 'plugin-library' $null -IsLibrary
      }
      else {
          if (-not $Repo -or -not (Test-Path -LiteralPath $Repo -PathType Container)) { Fail "repo not found: $Repo" }
          $repoFull = (Get-Item -LiteralPath $Repo).FullName
          $source = New-ProfileSource (Join-Path $repoFull $script:RepoProfilesRelative) $script:RepoProfilesRelative (Join-Path $repoFull $script:AdoptedRelative)
          if ((Get-ProfileOwnership $source $Profile) -eq 'library') { Fail "'$Profile' is an adopted library profile; its deltas are reviewed upstream - put repo changes in a repo-owned profile" }
      }
      if (-not (Get-ProfileEntry $source $Profile)) { Fail "profile '$Profile' is not in $($source.Display)" }
      $chain = Resolve-ProfileChain $Profile $source $null '-Profile'
      $effective = Get-EffectiveStandards $chain $source $warnings
  }
  catch { Fail ($_.Exception.Message -replace '^ProfileError: ', '') }

  $deltas = @($effective.Standards | ForEach-Object { $_.Parts } | Where-Object { $_.From -eq $Profile -and $_.Role -ne 'standard' })
  if ($Standard) {
      $wanted = $Standard.Replace('\', '/')
      $deltas = @($deltas | Where-Object { $_.Standard -ieq $wanted })
      if (-not $deltas.Count) { Fail "'$Standard' is not an amendment or replacement standard in '$Profile'" }
  }
  $orphans = 0
  foreach ($delta in $deltas) {
      switch ($delta.State) {
          'CURRENT' { Write-Output "UP-TO-DATE: $($delta.Display)" }
          'ORPHANED' { Write-Output "ORPHANED: $($delta.Display) cannot be accepted - the standard it changes is no longer inherited; retarget or delete it"; $orphans++ }
          default {
              Set-BasisLine $delta.Path $delta.Inherited
              $old = if ($delta.Basis) { $delta.Basis } else { 'none' }
              Write-Output "ACCEPTED: $($delta.Display) basis $old -> $($delta.Inherited)"
          }
      }
  }
  if ($orphans) { exit 1 }
  exit 0
  ```
- [ ] **Step 4 (run until green):** `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → `All architecture-profile assertions passed.`
- [ ] **Step 5 (write ADRs):** scan `docs/adr/` for the next number and write ADR-C1, ADR-C2, ADR-C3 and ADR-C6 from this sub-plan's `## Candidate ADRs` verbatim (the heading is the title without the `ADR-Cn:` label; keep the Provenance and the `**Relitigation:** Open to discussion` lines) to consecutive `docs/adr/NNNN-<slug>.md` files per `plugins/cogniva-dev/skills/adr/ADR-FORMAT.md`. Then run `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/check-adrs.ps1 -Workspace .` → exit 0.
- [ ] **Step 6 (commit):** `git add plugins/cogniva-dev/scripts/accept-profile-delta.ps1 plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1 docs/adr` then `git commit -m "feat(profiles): accept-profile-delta; ADRs for deltas, basis, adoption records, mutation gating"`
