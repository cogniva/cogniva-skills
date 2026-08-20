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

**Host dispatch (check second):** if the Workflow tool is not available in
this session (Codex or any non-Claude host), read
`../execute-feature/CODEX.md` NOW — its sequential subagent loop replaces
Step 1 (the Workflow dispatch), driven by the task list synthesized there.
Quick-fix tasks are PLANLESS — no `planPath`, nothing ticks checkboxes, no
plan resume — and after the loop the run lands at Step 2 BELOW, not at
execute-feature's Step 4.
Worktree mode requires the Claude Workflow runtime; under any other host
only lean mode is supported — if worktree mode is ON and the Workflow tool
is absent, STOP and say so.

`<plugin>` = this plugin's root (parent of `skills/`) — tooling, not the
target; the repo being fixed is the one you were invoked from.

**Flags:** quick-fix honours `commits=` exactly as the `## Flags` section of
`../execute-feature/SKILL.md` defines it — the same `none|task|final`
semantics and the same defaults (lean mode → `none`, worktree mode →
`task`), and `none|final` are just as INVALID in worktree mode, where
integration is a fast-forward of commits: reject the combination with one
clear line and stop, never silently ignore it. quick-fix is planless, so
`plan=` does not apply.

## Step 0 — workspace

`WORKSPACE` = the repo root; `BRANCH` = the current branch; record `START`
= `git rev-parse HEAD`. Dirty tree → show the user what is dirty and get an
OK before dispatching. ⟦worktree⟧

**Branch policy (lean mode only).** BEFORE mutating anything, read
`.claude/cogniva-dev/policy.json`. If it exists and carries
`requiredDevelopmentBranchPrefix`, `BRANCH` must start with that prefix.
Mismatch → STOP with one clear line naming the current branch and the
required prefix; NEVER create or switch a branch to satisfy the policy —
which branch to work on is the user's call, not yours. Absent or unreadable
file, or no such key → no policy, no behaviour change. Worktree mode needs
no check: its generated branches are `feature/<slug>` by construction.

## Step 0.5 — candidate ADRs (confirm BEFORE dispatch)

Most quick-fixes produce none. If scoping surfaces an architectural
decision, hold it as a candidate (title, 1–3 sentences, provenance,
relitigation if non-default — see `/adr`) and get an explicit
yes/amend/drop BEFORE dispatching. Fold each confirmed candidate into the
task body as a final step — "write ADR `NNNN-<slug>.md` (next number by
scanning `docs/adr/`) with this exact content" — so it is written during
execution and lands with the fix (committed only where the commit policy
commits; under `commits=none|final` it stays in the tree with the fix).

## Step 1 — make the change (background Workflow)

Run `<plugin>/templates/execute-feature.workflow.js` (copy verbatim; CRLF
rejection → write an LF copy). One synthesized task for trivial fixes, or a
short ordered list. Each task body: what to change, how to verify, and —
only under a commit policy that commits — a commit step. Planless — no
`planPath`. The agent works in `WORKSPACE` on `BRANCH`; where the policy
commits it stages only its own files and commits, otherwise it stages
nothing and leaves the change in the working tree.

## Step 2 — land it

Same order as execute-feature's Land step, for the same reasons:
tree consistent with the commit policy → ride-along gate (`CAPTURE-BAR.md`
Test 3; depth-1 — a genuine second round is another
`/cogniva-dev:quick-fix`, which is cheap and the whole point of this skill)
→ `### before-integrate` CLAUDE.md block (under Codex honour only its
substantive gate — see `../execute-feature/CODEX.md`) → ADR check
(`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/check-adrs.ps1" -Workspace "<WORKSPACE>" -Since START` ⟦worktree⟧)
→ `git diff --check` (whitespace errors or conflict markers → fix them,
respecting the commit policy, and re-run until clean; record the result)
→ GREEN GATE (`.claude/cogniva-dev/green-gate.json`; absent → skip with one
line) → under `commits=final`, NOW the single implementation commit —
exactly one, only after the green gate; a git failure → `BLOCKED`, no
retries → done ⟦worktree⟧. `commits=` stays the sole commit authority
through every one of these steps, exactly as execute-feature defines it.

In lean mode "done" IS the handoff: emit it in full per
`../execute-feature/HANDOFF.md` as the final text of the turn. A short fix
yields a short handoff — every section still appears, one with nothing to
report saying `none`. Worktree mode ends by integrating, unchanged.

## Rules

- Never push to a remote; never switch the user's branch uninvited.
- Keep it small — a fix growing into a real feature → stop and suggest
  `/cogniva-dev:plan-feature`.
- Follow-ups: the workflow returns `followups`; run the backlog gate
  exactly as execute-feature defines it (CAPTURE-BAR; write only confirmed
  items via `/cogniva-dev:backlog`). A fix that resolved a loose
  `BACKLOG.md` item: tick it and append `→ done` — a closure, not a
  capture, no gate needed.
