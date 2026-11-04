# Backlog

Planned deferrals — work with a stated reason to wait (`because:` tag). Promote with the plan-feature skill;
trivial fixes can go straight to quick-fix.

- [x] Port a `-Check` gate mode into `module-deps` (report cycles, exit 1, write nothing — CognivaNewRepo's local copy has one to crib from) so completion flows can verify Module dependencies  `size:S` `area:skills` `src:LeanWorktreeSplit` → planned: FeatureLifecycle/ModuleDepsLegacyTool
- [ ] Migrate the existing Windows PowerShell 5.1 scripts (`plugins/cogniva-dev/scripts/*`, `scripts/check-plugin-manifests.ps1`, tests) to PowerShell 7; new scripts already target pwsh 7  `size:M` `area:tooling` `src:ArchitectureProfiles` `because:human later`
- [ ] Set up CI (e.g. a GitHub Actions job on a Windows runner) that runs the green gate on every PR, so a PR cannot merge without it passing  `area:tooling` `src:CrossHostParity` `because:human later`
