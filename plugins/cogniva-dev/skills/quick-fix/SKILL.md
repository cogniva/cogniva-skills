---
name: quick-fix
description: Use for small follow-up changes (UI tweak, bug fix, copy change) without a formal feature plan. Runs the change via a background Workflow so it can be fired repeatedly without bloating context; in worktree mode the change is isolated in a git worktree and auto-integrated.
---

# Quick Fix

A planless sibling of `/cogniva-dev:execute-feature` for small changes. The
work runs in a background Workflow, so fire it repeatedly from a control
session and stay lean.

Invoke: `/cogniva-dev:quick-fix "<short description of the change>"`.

**Worktree dispatch (check first):** worktree mode is ON iff the target
repo's `.claude/cogniva-dev.local.json` has `"worktrees": true`. ON → read
`WORKTREE.md` beside this file NOW; it replaces the ⟦worktree⟧ steps. OFF →
work directly on the user's checkout and current branch.

`<plugin>` = this plugin's root (parent of `skills/`) — tooling, not the
target; the repo being fixed is the one you were invoked from.

## Step 0 — workspace

`WORKSPACE` = the repo root; `BRANCH` = the current branch; record `START`
= `git rev-parse HEAD`. Dirty tree → show the user what is dirty and get an
OK before dispatching. ⟦worktree⟧

## Step 0.5 — candidate ADRs (confirm BEFORE dispatch)

Most quick-fixes produce none. If scoping surfaces an architectural
decision, hold it as a candidate (title, 1–3 sentences, provenance,
relitigation if non-default — see `/adr`) and get an explicit
yes/amend/drop BEFORE dispatching. Fold each confirmed candidate into the
task body as a final step — "write ADR `NNNN-<slug>.md` (next number by
scanning `docs/adr/`) with this exact content" — so it is written during
execution and committed with the fix.

## Step 1 — make the change (background Workflow)

Run `<plugin>/templates/execute-feature.workflow.js` (copy verbatim; CRLF
rejection → write an LF copy). One synthesized task for trivial fixes, or a
short ordered list. Each task body: what to change, how to verify, a commit
step. Planless — no `planPath`. The agent works in `WORKSPACE` on `BRANCH`,
stages only its own files, and commits.

## Step 2 — land it

Same order as execute-feature's Land step, for the same reasons:
tree clean → ride-along gate (`CAPTURE-BAR.md` Test 3; depth-1 — a genuine
second round is another `/cogniva-dev:quick-fix`, which is cheap and the
whole point of this skill) → `### before-integrate` CLAUDE.md block → ADR
check
(`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/check-adrs.ps1" -Workspace "<WORKSPACE>" -Since START` ⟦worktree⟧)
→ GREEN GATE (`.claude/cogniva-dev/green-gate.json`; absent → skip with one
line) → done ⟦worktree⟧: report the fix in 1–2 sentences.

## Rules

- Never push to a remote; never switch the user's branch.
- Keep it small — a fix growing into a real feature → stop and suggest
  `/cogniva-dev:plan-feature`.
- Follow-ups: the workflow returns `followups`; run the backlog gate
  exactly as execute-feature defines it (CAPTURE-BAR; write only confirmed
  items via `/cogniva-dev:backlog`). A fix that resolved a loose
  `BACKLOG.md` item: tick it and append `→ done` — a closure, not a
  capture, no gate needed.
