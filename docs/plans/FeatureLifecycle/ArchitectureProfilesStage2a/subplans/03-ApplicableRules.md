# 03 ApplicableRules — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/ArchitectureProfilesStage2a
> Tasks contain NO git worktree/branch step — execute-feature sets up the workspace.
> Each task's commit step applies only when the run's `commits=` policy commits
> per task; otherwise leave the changes in the working tree. Never run
> git switch/checkout/branch inside a task.

**Goal:** `applicable-rules` takes its placement checks from the resolved
architecture profile, and a stale amendment or replacement stops preflight only
for targets whose matched standards it affects.

**Architecture:** `plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1`
stays **Windows PowerShell 5.1** (no `?:`, `??`, or pwsh-only APIs) and keeps
running the pwsh 7 resolver as a separate process. It now reads each target's
`MatchedStandards` (standards whose `applies-to` globs match the path) and the
profile's `Review[]` from that JSON.

**Read these first:** `plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1`,
`plugins/cogniva-dev/skills/applicable-rules/SKILL.md`,
`plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1`,
`plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`.
Resolver JSON per target: `Status`, `Profile`, `NeedsReview`,
`MatchedStandards` (array of ids); per profile (`Profiles.<id>`): `Standards[]`
(`Id`, `Description`, …) and `Review[]` (`Standard`, `Profile`, `Ownership`,
`Delta`, `State`, `Basis`, `Inherited`, `Path`).

| Target's profile status | Placement checks |
|---|---|
| `RESOLVED` | Host message iff `architecture/composition-roots.md` is in `MatchedStandards`; published-surface message iff `architecture/common-and-published-types.md` is (only where a repo-owned profile supplies `applies-to`). `STANDARD:` lines for every matched standard. |
| `NONE` | none |
| `UNDECLARED` / `UNAVAILABLE` / `ERROR` | today's `Hosts` / `Contracts` regexes, unchanged |

Review items: one whose `Standard` is in the target's `MatchedStandards` is a
review reason (`REVIEW_REQUIRED`); any other is a `REVIEW:` note that leaves
`Decision` unchanged.

## File structure (locked)

```
plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1        # profile-driven placement, review reasons vs notes
plugins/cogniva-dev/skills/applicable-rules/SKILL.md            # contract: REVIEW: is informational, REVIEW_REQUIRED stops
plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1  # profile-driven cases through the preflight entry point
plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1    # pin the new SKILL contract
docs/adr/NNNN-*.md                                              # ADR C5
```

## Candidate ADRs

### ADR-C5: Placement warnings come from the resolved profile
**Provenance:** Suggested by agent
**Relitigation:** Open to discussion
applicable-rules raises a placement warning for a path only when a standard's
`applies-to` globs match it in the path's resolved architecture profile, and a
review item stops preflight only for the targets whose matched standards it
affects. Undeclared paths keep the old path heuristics, so a repository that
declares nothing sees no change.
**Write with:** Task 1

## Task 1: Profile-driven placement checks

**Files:**
- Modify: `plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1`
- Modify: `plugins/cogniva-dev/skills/applicable-rules/SKILL.md`
- Test: `plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1`
- Test: `plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1`

- [x] **Step 1 (failing tests):** In `applicable-rules.tests.ps1`, insert before the final `}` of the outer `try` (after the "without pwsh" check):
  ```powershell
      # --- profile-driven placement (needs pwsh to adopt the shipped dotnet profile) ---
      $pwshCmd = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
      if (-not $pwshCmd) { Write-Host '  SKIP  profile-driven placement (PowerShell 7 not installed)' }
      else {
          $prof = Join-Path ([System.IO.Path]::GetTempPath()) ("cogniva-applicable-profile-" + [guid]::NewGuid().ToString('N'))
          try {
              function Write-Text([string]$Relative, [string]$Text) {
                  $path = Join-Path $prof $Relative
                  New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
                  [System.IO.File]::WriteAllText($path, $Text.Replace("`r`n", "`n"))
              }
              function Invoke-Preflight([string]$Targets, [string]$Purpose) {
                  return ((& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $prof -Target $Targets -Purpose $Purpose -Format Json) | ConvertFrom-Json)
              }
              New-Item -ItemType Directory -Path $prof -Force | Out-Null
              & git -C $prof init -q
              & $pwshCmd.Source -NoProfile -File (Join-Path $plugin 'scripts\adopt-architecture-profile.ps1') -Repo $prof -Profile dotnet | Out-Null
              Write-Text '.cogniva-profile.yml' "profile: dotnet`n"
              Write-Text 'src/Hosts/Web/Program.cs' "// host`n"
              Write-Text 'src/Lib/Foo.cs' "// lib`n"
              Write-Text 'src/Modules/Orders/Orders.Contracts/IOrders.cs' "// contracts`n"
              Write-Text 'src/Hosts/Old/.cogniva-profile.yml' "profile: none`n"

              $p = Invoke-Preflight 'src/Hosts/Web/Program.cs,src/Lib/Foo.cs,src/Modules/Orders/Orders.Contracts/IOrders.cs,src/Hosts/Old/x.cs' 'wiring'
              Check 'dotnet: a host gets the composition-root message only' (@($p.Targets[0].Conflicts).Count -eq 1 -and ($p.Targets[0].Conflicts -join ' ') -match 'composition-roots\.md' -and $p.Targets[0].Decision -eq 'SAFE_TO_PROCEED' -and @($p.Targets[0].MatchedStandards.Id) -contains 'architecture/composition-roots.md')
              Check 'dotnet: an ordinary library gets no placement message' (@($p.Targets[1].Conflicts).Count -eq 0)
              Check 'dotnet: a Contracts folder gets no message without a repo applies-to' (@($p.Targets[2].Conflicts).Count -eq 0)
              Check "'profile: none' gets no placement message even under Hosts" (@($p.Targets[3].Conflicts).Count -eq 0 -and $p.Targets[3].ArchitectureProfile.Status -eq 'NONE')
              $p = Invoke-Preflight 'src/Hosts/Web/Program.cs' 'domain behavior'
              Check 'dotnet: domain behaviour in a host is still a CONFLICT' ($p.Targets[0].Decision -eq 'REVIEW_REQUIRED' -and ($p.Targets[0].Conflicts -join ' ') -match 'CONFLICT:')

              Write-Text '.cogniva/profiles/acme/profile.yml' "description: Acme.`ninherits: dotnet`n"
              Write-Text '.cogniva/profiles/acme/amendments/architecture/common-and-published-types.md' "---`ndescription: Acme's published types are each Module's Contracts project.`napplies-to:`n  - `"src/Modules/*/*.Contracts/**`"`n---`n`n- Contracts projects publish types.`n"
              Write-Text '.cogniva-profile.yml' "profile: acme`n"
              Write-Text 'src/Hosts/Old/.cogniva-profile.yml' "profile: acme`n"
              & $pwshCmd.Source -NoProfile -File (Join-Path $plugin 'scripts\accept-profile-delta.ps1') -Repo $prof -Profile acme -All | Out-Null
              $p = Invoke-Preflight 'src/Modules/Orders/Orders.Contracts/IOrders.cs,src/Hosts/Web/Program.cs' 'interfaces'
              Check 'a repo applies-to on published types gives the published-surface message' (($p.Targets[0].Conflicts -join ' ') -match 'common-and-published-types\.md' -and $p.Targets[0].Decision -eq 'SAFE_TO_PROCEED')
              Check 'the same repo still gives the composition-root message on a host' (($p.Targets[1].Conflicts -join ' ') -match 'composition-roots\.md')
              $p = Invoke-Preflight 'src/Modules/Orders/Orders.Contracts/IOrders.cs' 'persistence implementation'
              Check 'implementation in a published surface is a CONFLICT' ($p.Targets[0].Decision -eq 'REVIEW_REQUIRED')

              Write-Text '.cogniva/profiles/acme/amendments/architecture/composition-roots.md' "---`ndescription: Acme host note.`nbasis: aaaaaaaaaaaa`n---`n`n- Acme hosts.`n"
              $p = Invoke-Preflight 'src/Hosts/Web/Program.cs,src/Lib/Foo.cs' 'wiring'
              Check 'a stale delta on a matched standard requires review' ($p.Targets[0].Decision -eq 'REVIEW_REQUIRED' -and ($p.Targets[0].ReviewReasons -join ' ') -match 'architecture/composition-roots\.md needs human review')
              Check 'a stale delta on an unmatched standard is only a REVIEW note' ($p.Targets[1].Decision -eq 'SAFE_TO_PROCEED' -and ($p.Targets[1].ReviewNotes -join ' ') -match 'architecture/composition-roots\.md needs human review')
              $text = (& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $prof -Target 'src/Lib/Foo.cs' -Purpose 'wiring') -join "`n"
              Check 'text output prints REVIEW: notes and leaves DECISION unchanged' ($text -match 'REVIEW: Standard architecture/composition-roots\.md' -and $text -match 'DECISION: SAFE_TO_PROCEED')
              $text = (& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Repo $prof -Target 'src/Hosts/Web/Program.cs' -Purpose 'wiring') -join "`n"
              Check 'text output prints STANDARD: lines for matched standards' ($text -match 'STANDARD: architecture/composition-roots\.md - ')
          }
          finally { if (Test-Path -LiteralPath $prof) { Remove-Item -LiteralPath $prof -Recurse -Force } }
      }
  ```
  In `skill-semantics.tests.ps1`, under `# --- architecture profiles`, add:
  ```powershell
  Check 'applicable-rules: REVIEW: lines are informational, REVIEW_REQUIRED stops' `
      ($ar -match '`REVIEW:` lines are informational' -and $ar -match 'Decision` is `REVIEW_REQUIRED`')
  Check 'applicable-rules: placement checks come from the resolved profile' `
      ($ar -match 'applies-to')
  ```
- [x] **Step 2 (run it, expect fail):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1` → FAIL lines for the profile-driven cases; `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → FAIL on the two new pins.
- [x] **Step 3 (implement the script):** In `resolve-applicable-rules.ps1`, inside the per-target loop:
  1. Move the architecture-profile block (the `if (-not $profileReport.Available) … else …` that builds `$architectureProfile`) **above** the placement checks, and keep `$resolved` (the per-target resolver entry, `$null` when unavailable or on a usage error).
  2. Replace the two placement `if` blocks with:
     ```powershell
     $matchedStandards = @()
     $reviewNotes = @()
     if ($architectureProfile.Status -eq 'RESOLVED') {
         # Placement comes from the profile: a message fires only where a standard's
         # applies-to globs match this path (see the resolver's MatchedStandards).
         $profileData = $profileReport.Report.Profiles.($resolved.Profile)
         $matchedIds = @($resolved.MatchedStandards)
         foreach ($id in $matchedIds) {
             $standard = @($profileData.Standards | Where-Object { $_.Id -eq $id }) | Select-Object -First 1
             $matchedStandards += [pscustomobject]@{ Id = $id; Description = $standard.Description }
         }
         if ($matchedIds -contains 'architecture/composition-roots.md') {
             $message = 'Target is under a composition root (architecture/composition-roots.md). Confirm that it is wiring only; substantive application, domain, persistence, evaluation, or reusable behavior belongs in its owning unit.'
             if ($Purpose -match '(?i)domain|persistence|evaluation|orchestrat|business|reusable') { $message = "CONFLICT: $message" }
             $conflicts += $message
         }
         if ($matchedIds -contains 'architecture/common-and-published-types.md') {
             $message = 'Target is a published or common types surface (architecture/common-and-published-types.md). Confirm that it holds no implementation.'
             if ($Purpose -match '(?i)implementation|persistence|business|domain') { $message = "CONFLICT: $message" }
             $conflicts += $message
         }
         # A review item stops preflight only where this target depends on that standard.
         foreach ($item in @($profileData.Review)) {
             $text = "Standard $($item.Standard) needs human review: $($item.Profile) ($($item.Ownership)) $($item.Delta) is $($item.State)."
             if ($matchedIds -contains $item.Standard) { $reviewReasons += $text } else { $reviewNotes += $text }
         }
     }
     elseif ($architectureProfile.Status -ne 'NONE') {
         # No profile to ask (undeclared, pwsh unavailable, or unresolvable): today's path heuristics.
         <the two existing Hosts / Contracts regex blocks, unchanged>
     }
     ```
     Keep the existing per-target `ERROR` review reason. Note `$conflicts` must be initialised before this block, and the existing `CONFLICT:` → `$reviewReasons` loop must still run after it.
  3. Add `MatchedStandards = @($matchedStandards)` and `ReviewNotes = @($reviewNotes | Select-Object -Unique)` to each item.
  4. Text output, after the `PLACEMENT:` lines: `foreach ($s in $item.MatchedStandards) { Write-Output "  STANDARD: $($s.Id) - $($s.Description)" }` and, after the `REVIEW_REQUIRED:` lines, `foreach ($note in $item.ReviewNotes) { Write-Output "  REVIEW: $note" }`.
- [x] **Step 4 (implement the SKILL contract):** In `plugins/cogniva-dev/skills/applicable-rules/SKILL.md`:
  - Replace "and highlights Host and Contracts placement risks." with: "and highlights placement risks. Where a target has a resolved architecture profile, the placement checks come from it: a message fires only for standards whose `applies-to` globs match the path (`MatchedStandards`, printed as `STANDARD:` lines). `profile: none` turns them off; undeclared paths keep the path heuristics for Hosts and Contracts folders."
  - Replace "State the intended owning Module or layer" with "State the intended owning unit (as the repository defines its units)".
  - After the sentence ending "a natural-language policy engine.", add: "A standard that needs human review (an amendment or replacement standard whose inherited text changed) makes `Decision` `REVIEW_REQUIRED` only for targets whose matched standards include it. `REVIEW:` lines are informational: they report review items on other standards and never change `Decision`."
- [x] **Step 5 (run until green):** `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1` → `All applicable-rules assertions passed.`; `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1` → `All skill-semantics assertions passed.`; `pwsh -NoProfile -File plugins/cogniva-dev/tests/architecture-profile/architecture-profile.tests.ps1` → passes (its Linux-only applicable-rules check is unaffected).
- [x] **Step 6 (write ADR):** scan `docs/adr/` for the next number and write ADR-C5 from this sub-plan's `## Candidate ADRs` verbatim (heading without the `ADR-C5:` label; keep Provenance and `**Relitigation:** Open to discussion`) to `docs/adr/NNNN-placement-warnings-come-from-the-resolved-profile.md` per `plugins/cogniva-dev/skills/adr/ADR-FORMAT.md`. Run `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/check-adrs.ps1 -Workspace .` → exit 0.
- [x] **Step 7 (commit):** `git add plugins/cogniva-dev/scripts/resolve-applicable-rules.ps1 plugins/cogniva-dev/skills/applicable-rules/SKILL.md plugins/cogniva-dev/tests/applicable-rules/applicable-rules.tests.ps1 plugins/cogniva-dev/tests/skill-semantics/skill-semantics.tests.ps1 docs/adr` then `git commit -m "feat(applicable-rules): placement checks and review escalation come from the resolved profile"`
