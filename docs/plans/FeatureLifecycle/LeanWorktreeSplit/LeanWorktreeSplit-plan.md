# LeanWorktreeSplit — Feature Plan (orchestrated)

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/LeanWorktreeSplit
> Multi-plan feature: the sub-plans below execute IN LISTED ORDER (already
> dependency-sorted), all in ONE worktree, sequentially, integrating ONCE at the
> end. Tasks contain NO git worktree/branch step.

**Goal:** Make every workflow skill usable WITH or WITHOUT worktrees — a lean
default (no worktrees, minimal skill text) plus a per-clone opt-in that layers
the full worktree rules back in.

**Architecture:** An untracked per-clone switch (`.claude/cogniva-dev.local.json`,
`{"worktrees": true}`, default off) is read by both the guard hooks and the
skills. Each worktree-using skill (execute-feature, plan-feature, quick-fix) is
rewritten as a lean SKILL.md whose worktree mechanics move to a sibling
`WORKTREE.md` overlay read only when the switch is on. execute-feature
additionally normalizes ANY plan into the task format as its first step, so
checkbox tracking and resume work for freeform plans too. The tracked
`.claude/cogniva-dev/` directory stops being a mode switch and remains the home
of tracked config (`green-gate.json`, which runs in BOTH modes).

**Read these first:** `docs/strategy.md`; `plugins/cogniva-dev/skills/plan-feature/PLAN-FORMAT.md`;
current `plugins/cogniva-dev/skills/execute-feature/SKILL.md` (the file being
replaced); `plugins/cogniva-dev/scripts/guard-primary-edit.js`. Version-bump
note: this changes cogniva-dev's skills/scripts/templates — at integration,
offer a **minor** bump (0.5.0 → 0.6.0, workflow change) per `CLAUDE.md ## Rules`.

## Sub-plans (execution order)

| # | Sub-plan | Delivers | Prerequisites |
|---|----------|----------|---------------|
| 1 | `subplans/01-SwitchAndHooks.md` | The worktrees switch, hook gating, docs page, gitignore template | — |
| 2 | `subplans/02-ExecuteFeature.md` | Lean execute-feature + WORKTREE.md, plan normalization, workflow template + check-adrs changes | 1 |
| 3 | `subplans/03-PlanFeatureQuickFix.md` | Lean plan-feature and quick-fix + their WORKTREE.md overlays | 1, 2 |
| 4 | `subplans/04-PeripheryAndDocs.md` | cleanup short-circuits, mode-neutral wording, README/backlog updates | 1, 2, 3 |
