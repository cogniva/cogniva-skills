---
name: quick-fix
description: Use for small follow-up changes (UI tweak, bug fix, copy change) without a formal feature plan. Runs the change in an isolated git worktree via a background Workflow, then auto-integrates into the branch you have checked out - same machinery as execute-feature. Designed to be fired repeatedly from within an active execute-feature session without bloating context.
---

# Quick Fix

A planless sibling of `/cogniva-dev:execute-feature` for small changes. Same
isolation + auto-integration, no plan file. The work runs in a background
Workflow, so you can fire `quick-fix` repeatedly from your control session and it
stays lean.

Invoke: `/cogniva-dev:quick-fix "<short description of the change>"`.

`<plugin>` = this plugin's root — the directory containing `scripts/` AND
`templates/`, i.e. the **parent** of `skills/`. It is NOT the skill's own folder
(`.../skills/quick-fix/`). Resolve it once from the `scripts/...` command in Step 0
and reuse that exact root verbatim everywhere `<plugin>` appears (including the
`templates/...` path in Step 1) — do not re-derive or search for it.

`<plugin>` is tooling, not the target. It usually lives in a DIFFERENT checkout
(the plugin marketplace repo); the repo being fixed is the one you were invoked
from (your current working directory). Even when the fix concerns a Claude Code
skill or plugin, look for it in the target repo — never under `<plugin>`.

## Step 0 — isolated worktree (Bash)
Derive a short `<slug>` from the description (e.g. `fix-status-bar-alignment`), then:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/new-feature-worktree.ps1" -Slug <slug>`
Capture `worktree` and `branch` (`feature/<slug>`). The user's current branch is
the integration target (never switched).

## Step 0.5 — candidate ADRs (confirm BEFORE dispatch)
While scoping the fix, hold any architectural decision worth recording as a
*candidate* ADR (title, 1–3 sentences, **provenance**, and **relitigation** only if
it differs from the provenance default — see `/auto-doc`). Most quick-fixes produce
none. If any exist, present them to the user and get an explicit yes/amend/drop
**before** you dispatch the Workflow — never write an ADR without confirmation, and
never write one from this control session. Fold each confirmed candidate into the
relevant task body as a final step: "write ADR `NNNN-<slug>.md` (next number by
scanning `docs/adr/`) with this exact content", so the concrete ADR is written
**during execution**, committed with that task.

## Step 1 — make the change (Workflow, background)
Run the Workflow from `<plugin>/templates/execute-feature.workflow.js` (same
`<plugin>` root as Step 0 — it sits beside `scripts/`, never under `skills/`; copy
its script verbatim, do not rewrite or hand-author it). Use a SINGLE synthesized
task for trivial fixes, or a short ordered task list for multi-step ones. Each task body must be self-contained and include: what to
change, how to verify (test or manual check), and a commit step. quick-fix is
planless — omit `planPath`/`statePath` and rely on the commit(s) for the record.
(If you do synthesize a state file, it lives in the WORKTREE — `<worktree>/...`,
committed on the feature branch so it rides the merge — never the primary
checkout. See execute-feature Step 4.)

The task-agent works ONLY in `<worktree>` on `feature/<slug>`, never switches
branches, stages only its own files, and commits.

If the Workflow tool rejects the script with an error like *"script contains
control characters that would be hidden in the approval dialog"*, the template
has CRLF line endings — it must be LF. See execute-feature Step 2 for the check
and fix (`tr -cd '\r' < <template> | wc -c` should be 0).

## Step 2 — finish everything, gate last, then auto-integrate

Same order as **execute-feature Step 3**, and for the same reason — the green gate
is the LAST step before integration, so every change that rides the merge is
verified by it:

```
fix done → tree clean → ride-along gate → before-integrate → ADR check → GREEN GATE → integrate
```

**Ride-along gate (only when a candidate exists).** Read `CAPTURE-BAR.md` in the
`backlog` skill's directory and apply Test 3 to every `clear` candidate in the
workflow's `followups`. None passes → skip it; the fix stays fire-and-forget. At
least one passes → STOP and present the full three-section gate as the final text
of the turn, then make each confirmed ride-along IN THE WORKTREE on the feature
branch, one commit each. Anything not ridden along is captured via
`/cogniva-dev:backlog`. Depth-1: this offer happens once, and work you just admitted
as a ride-along never gets a gate of its own — a genuine second round is another
`/cogniva-dev:quick-fix`, which is cheap. That is the whole point of this skill.

Then run the repo green gate exactly as **execute-feature Step 3** defines it: read
`<worktree>/.claude/cogniva-dev/green-gate.json` and run its `commands` in order (each
must exit 0). If the file is ABSENT, skip the gate with the same one-line note ("No
`.claude/cogniva-dev/green-gate.json` in this repo — skipping the build/test gate…");
a present-but-empty `commands: []` is an intentional no-gate. Commit any lingering
worktree changes first — a gate over a dirty tree is a lie.

The gate runs with `<worktree>` as its cwd, but **do not leave your shell parked
there** — bracket it with `Push-Location`/`Pop-Location` in the same call (or
`Set-Location` inside each per-command invocation) and end back in the primary
checkout. Shell cwd persists across tool calls, and a process sitting in the
worktree is exactly what makes Windows refuse to delete it at close-out. See
execute-feature Step 3 for the full reasoning.

**ADR check.** BEFORE the gate, run the same mandatory check execute-feature
Step 3.1c defines:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/check-adrs.ps1" -Worktree "<worktree>" -TargetBranch "<target>"`
It catches an ADR number this branch added that the target already uses, and any
candidate `ADR-Cn` label this branch introduced into shipped code or an ADR
heading. Exit 1 → fix in the worktree, commit on the feature branch, re-run, and
only then integrate. A quick-fix that wrote no ADR still runs it — the label can
arrive in a code comment without any ADR file being touched.

**Repo obligations (`before-integrate`).** Also BEFORE the gate — check the target
repo's CLAUDE.md `## Cogniva-dev workflow instructions` for a `### before-integrate`
block; honor it on the worktree now (commit anything it produces on the feature
branch so it rides the merge). Absent → nothing to do. It runs ahead of the gate so
a block that writes code is verified like any other change.

**If the gate is red and this run has ride-along commits:** one repair attempt, then
`git revert` every ride-along commit and re-run. Green after the revert → the
ride-alongs were the cause; integrate the fix and capture the reverted items to the
backlog instead. Still red → an ordinary failure; report and STOP. Full rules in
execute-feature Step 3.2a.

If the gate is green (or skipped) and the ADR check is clean:
`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/integrate-feature.ps1" -WorktreePath "<worktree>" -FeatureBranch "feature/<slug>" -TargetBranch "<target>"`
Handle the JSON `status` exactly as execute-feature Step 4 does:
- `INTEGRATED` — the fix is live on the user's branch. Mark the worktree
  **cleanupable** so it can close itself out later:
  `powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/mark-cleanupable.ps1" -Worktree "<worktree>" -Branch "feature/<slug>" -Summary "<one line of what the fix did>"`
  Then tell the user: "Merged into your branch. Validate it, then run
  `/cogniva-dev:cleanup-work` to close out (removes the worktree). If this session
  is gone, `/cogniva-dev:cleanup-allwork` finishes it." Do NOT run `git worktree
  remove` manually — cleanup-work / cleanup-allwork own that.
- `QUEUED_DIRTY` — commit/stash on the target, then re-run integrate to land it.
- `CONFLICT` — report the worktree path for resolution; force nothing.
- `ERROR` — surface the detail; do not retry blindly.

## Rules
- Never push to remote. Never branch-switch the primary checkout.
- Never write an ADR without human confirmation, and never from this control
  session — concrete ADRs are written by the task agent during execution (Step 0.5).
- Before reopening anything in `docs/adr/`, respect its relitigation weight (see
  `/auto-doc`); surface a needed change to the user rather than working around it.
- Keep it small — if the change grows into a real feature, stop and suggest
  `/cogniva-dev:plan-feature` instead.
- If the fix surfaces a follow-up you are NOT doing now, don't drop it and don't
  silently write it — the task agent returns it in the workflow result's
  `followups` array, and you run the gate (see execute-feature's "Backlog gate —
  followups from the run", and `CAPTURE-BAR.md` in the `backlog` skill's
  directory). Drop anything already covered by this fix or an open item; anything
  that passed Test 3 was already offered as a ride-along in Step 2, while the
  worktree was open; present the rest under `## Backlog candidates` in its two
  tables and write only what the user confirms, via `/cogniva-dev:backlog`. Never
  head a table "Capture candidates". No followups, or nothing surviving coverage →
  say nothing. If this fix resolved a loose `BACKLOG.md` item, tick it and append
  `→ done` — that is a closure, not a capture, and needs no gate.
