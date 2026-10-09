# CrossHostParity Stage 1 review

Branch: `feature/cross-host-parity`
Prepared: 2026-10-09, by the agent that ran sub-plan 04

## Agent checks

| Check | Command | Result |
|---|---|---|
| Green gate | `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .` | `green-gate: GREEN - all 24 command(s) exited 0.` |
| Parity record | `pwsh -NoProfile -File scripts/check-host-parity.ps1` | `host-parity: OK - 25 rows, 32 items covered` |
| Agent-host token ratchet | `pwsh -NoProfile -File scripts/check-host-neutrality.ps1` | `host-neutrality: OK - 70 host-specific references in 16 files (baseline)` |

## Human checks

| # | Check | Agent host and surface | Result (pass / fail) | Notes |
|---|---|---|---|---|
| 1 | Fresh session, no file named: "What files does a plugin version bump touch, and what must a change to a skill consider about agent hosts?" The answer names the three version files and the cross-host parity rule. | Codex, VS Code | | |
| 2 | The same question in a fresh session. | Claude Code | | |
| 3 | `$feature-check review` over the branch diff against `main`; every finding resolved or answered. | Codex | | |
| 4 | `/skills` lists the six explicit-only skills, and "clean up my worktrees" does not start cleanup-work on its own. | Codex, VS Code | | |
| 5 | Typing `/cogniva-dev:execute-feature` still starts the skill. | Claude Code | | |
| 6 | Version bumps applied, three files each, matching (`grep -n '"version"'`), green gate re-run GREEN. | either | | |
| 7 | PR 1 (Stage 1) opened from `feature/cross-host-parity`, reviewed and merged. | n/a | | |
