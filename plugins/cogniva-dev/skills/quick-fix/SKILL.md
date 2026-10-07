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
OK before dispatching. Then record `START_TREE`, the starting state that
Step 2's structural check compares against. It includes whatever was
already dirty, so none of that is attributed to this fix:
`pwsh -NoProfile -File "<plugin>/scripts/check-structural-changes.ps1" -Repo "<WORKSPACE>" -Snapshot`
prints `START_TREE: <sha>`. Any other result (a non-zero exit, or no
`START_TREE:` line) → stop before dispatching and show its output: without
a valid `START_TREE` the structural check cannot run. No `pwsh`: if the
repo has a `.cogniva/profiles/` folder, say the structural check cannot run
and ask the user before dispatching whether to go ahead without it (yes →
record that under Skipped validations); otherwise say so in one line and
carry on. ⟦worktree⟧

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

## Step 0.6 — expected structural change (usually skipped)

Run this step only when scoping shows the fix will add or remove a unit (a
project, package or module), add or remove a dependency between units, or
move code from one unit to another. Otherwise skip this step: no profile
call, nothing added to tasks.

1. Write down what you expect as `EXPECTED`: comma-separated
   `<kind>:<path>[|<path>...]` items, one per kind. Each lists every folder
   that change touches, both ends of a dependency included, for example
   `dependency-added:src/A|src/B`. The kinds are `unit-added`,
   `unit-removed`, `dependency-added`, `dependency-removed` and
   `code-moved`. A structural change outside the folders you name counts as
   unexpected at landing.
2. For each `EXPECTED` item, run
   `pwsh -NoProfile -File "<plugin>/scripts/resolve-architecture-profile.ps1" -Repo "<WORKSPACE>" -Target "<that item's paths>" -Kinds "<that item's kind>"`.
   Never pass one item's kind against another item's paths: a kind is
   checked only where that change happens. Act on every run's result:
   - Exit 3 → stop before dispatching and show the `REQUIRE BLOCKED:`
     lines. A reason `not in profile` means the profile maps that kind to a
     standard it does not have: a human adds the standard or corrects the
     `structure-requires` pair. A reason `needs human review` means a human
     reviews that standard and runs `accept-profile-delta.ps1`.
   - Exit 2 → the command is wrong: fix it and re-run; never dispatch on it.
   - Exit 1 → show the error and ask the user how to proceed.
   - `PROFILE: undeclared` or `PROFILE: none`, `REQUIRE: ok (no standards
     required)`, or no `pwsh` → carry on with nothing added to tasks.
3. Otherwise print the standards in full, profile by profile. For each
   `REQUIRE FOR <target> (<profile>): <ids>` line that lists standards, in
   any run, run the same script with
   `-Target "<that target>" -Show "<those ids>"`. Read them. A planned
   change that departs from them, or needs a choice they leave open, is not
   a quick fix: stop and propose `/cogniva-dev:plan-feature` (never auto-run
   it).
4. Put the `-Show` output VERBATIM in the body of each task that makes the
   change, using the output for the items and targets that task touches
   (each standard once per profile — one copy per (profile, standard ID),
   so a task that spans profiles gets each profile's own amended version),
   under `### Architecture standards for this task`, after this line:
   "Follow these standards. If the work needs a structural change they do
   not cover, or a different one from what this task describes, stop and
   return BLOCKED with what you found." Tasks that do not make the change
   get none of it.

## Step 1 — make the change (background Workflow)

Run `<plugin>/templates/execute-feature.workflow.js` (copy verbatim; CRLF
rejection → write an LF copy). One synthesized task for trivial fixes, or a
short ordered list. Each task body: what to change, how to verify, and —
only under a commit policy that commits — a commit step. Planless — no
`planPath`. The agent works in `WORKSPACE` on `BRANCH`; where the policy
commits it stages only its own files and commits, otherwise it stages
nothing and leaves the change in the working tree.

Every task body ends with this line, whatever the fix: "If this change
turns out to need adding or removing a unit (a project, package or
module), a dependency between units, or moving code from one unit to
another, and this task does not ask for it, stop and return BLOCKED saying
what you would change." A task BLOCKED that way → treat the change as
expected: run Step 0.6 for it, then re-dispatch the tasks that did not
finish.

## Step 2 — land it

Same order as execute-feature's Land step, for the same reasons, plus the
structural check:
tree consistent with the commit policy → do-now gate (`CAPTURE-BAR.md`
Test 3; depth-1 — a genuine second round is another
`/cogniva-dev:quick-fix`, which is cheap and the whole point of this skill)
→ `### before-integrate` block from
`scripts/resolve-workflow-obligations.ps1` (under Codex honour only its
substantive gate — see `../execute-feature/CODEX.md`) → STRUCTURAL CHECK
(below; after every step that can write code, before the gates) → ADR check
(`powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/check-adrs.ps1" -Workspace "<WORKSPACE>" -Since START` ⟦worktree⟧)
→ `git diff --check` (whitespace errors or conflict markers → fix them,
respecting the commit policy, and re-run until clean; record the result)
→ GREEN GATE (`powershell -NoProfile -ExecutionPolicy Bypass -File
"<plugin>/scripts/run-green-gate.ps1" -Repo "<WORKSPACE>"`; exit 0 = green or
legitimate skip, 1 = red, 2 = config error) → under `commits=final`, NOW the single implementation commit —
exactly one, only after the green gate; a git failure → `BLOCKED`, no
retries → done ⟦worktree⟧. `commits=` stays the sole commit authority
through every one of these steps, exactly as execute-feature defines it.

In lean mode "done" IS the handoff: emit it in full per
`../execute-feature/HANDOFF.md` as the final text of the turn. A short fix
yields a short handoff — every section still appears, one with nothing to
report saying `none`. Its Checks run section carries the `STRUCTURE:` line.
Worktree mode ends by integrating, unchanged.

### Structural check

`pwsh -NoProfile -File "<plugin>/scripts/check-structural-changes.ps1" -Repo "<WORKSPACE>" -Since <START_TREE> -Expected "<EXPECTED>"`
(leave out `-Expected` when Step 0.6 was skipped). It compares everything
since the start - task commits, staged, unstaged and untracked files - runs
the structure detectors the repo's profiles select, and checks each change
against the profiles of every path it touches, as they are now and as they
were at the start.

| Exit | `STRUCTURE:` | Then |
|---|---|---|
| 0 | `NONE` or `NOT-CHECKED` | Continue. |
| 4 | `FOUND` | Read each `FACT`'s `EVIDENCE` and the standards on its `REQUIRES` lines: `resolve-architecture-profile.ps1 -Repo "<WORKSPACE>" -Target . -Profile <the profile on that REQUIRES line> -Show "<that line's ids>"` (by profile, not by path: a path the fix deleted no longer resolves). Then act as below. |
| 3 | `BLOCKED` | Stop landing and show the `REQUIRE BLOCKED` lines. A reason `not in profile` → a human adds the standard or corrects the `structure-requires` pair; `needs human review` → a human reviews the standard and runs `accept-profile-delta.ps1`. Then re-run this check. |
| 2 | (usage error) | Stop landing: the command is wrong. Fix it and re-run this check; never treat it as no structural changes. |
| 1 | `FAILED` | Stop landing and show the `CHECK FAILED:` lines. Never treat a failed check as no structural changes. Land only if the user explicitly says to land without the check; record that under Skipped validations. |

On `FOUND`:

- A fact that complies with its standards and is not marked `UNEXPECTED`
  → continue.
- Any `UNEXPECTED` fact → show the user the fact, its evidence and how its
  standards apply, and wait for their OK before continuing. List it under
  Deviations & surprises. A `profile-changed` fact is always `UNEXPECTED`:
  the fix changed the profiles its own changes are checked against. Name
  each changed file; a repair the user just made is theirs to OK.
- A fact that breaks its standards but can be put right within them → fix
  it (respecting the commit policy) and re-run this check.
- A departure from a standard, a choice the standards leave open, or a
  needed exception → stop landing, leave the work where it is, and propose
  `/cogniva-dev:plan-feature` for the decision (never auto-run it).

Finding a structural change is never by itself a reason to leave
quick-fix.

No `pwsh`: Step 0 already settled it - skip this check only as agreed
there, and say so under Skipped validations.

## Rules

- Never push to a remote; never switch the user's branch uninvited.
- Keep it small — a fix growing into a real feature → stop and suggest
  `/cogniva-dev:plan-feature`.
- Follow-ups: the workflow returns `followups`; run the backlog gate
  exactly as execute-feature defines it (CAPTURE-BAR's route-first gate;
  write only confirmed deferrals, each with its `because:`, via
  `/cogniva-dev:backlog`). A fix that resolved a loose
  `BACKLOG.md` item: tick it and append `→ done` — a closure, not a
  capture, no gate needed.
