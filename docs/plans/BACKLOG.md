# Backlog

Planned deferrals — work with a stated reason to wait (`because:` tag). Promote with /cogniva-dev:plan-feature;
trivial fixes can go straight to /cogniva-dev:quick-fix.

- [x] Port a `-Check` gate mode into `module-deps` (report cycles, exit 1, write nothing — CognivaNewRepo's local copy has one to crib from) so completion flows can verify Module dependencies  `size:S` `area:skills` `src:LeanWorktreeSplit` → planned: FeatureLifecycle/ModuleDepsLegacyTool
- [ ] Migrate the existing Windows PowerShell 5.1 scripts (`plugins/cogniva-dev/scripts/*`, `scripts/check-plugin-manifests.ps1`, tests) to PowerShell 7; new scripts already target pwsh 7  `size:M` `area:tooling` `src:ArchitectureProfiles` `because:human later`
