---
name: plan-feature
description: Use when designing ONE feature with a strong model before implementation - runs a focused design session and emits a task-segmented feature plan (executable by /execute-feature). Pairs with adr (ADRs) and glossary. Does not depend on superpowers.
---

# Plan Feature

Design ONE feature with the strong model, then emit a plan whose tasks a small
model can execute later with lean, per-task context. Output is a feature folder
under `docs/plans/<Module>/<Feature>/`. Keep THIS session focused on design — do
not implement.

**Two repos may be in play — don't conflate them.** The **target repo** is the
checkout you were invoked from (your current working directory): all exploration,
worktrees, plans, and edits happen there. This skill's own files and the
`<plugin>` scripts ship in the cogniva plugin install — usually a DIFFERENT
checkout (the plugin marketplace repo). Read formats and run scripts from there,
but never explore it or treat it as the subject of the feature. Even when the
feature being designed concerns a Claude Code skill or plugin, that skill lives
in the **target repo** unless the user explicitly points elsewhere — do not go
looking for it under `<plugin>`.

## Gather first (ask the user)

1. Module name `<Module>` and feature name `<Feature>` (PascalCase, e.g.
   `Selections` / `TaskpaneStatusBar`). Derive a kebab `<slug>` for branches.
2. The outcome the feature must deliver, and any hard constraints.

## Design loop

**Repo obligations (`before-planning`).** Check the target repo's CLAUDE.md for a
`## Cogniva-dev workflow instructions` section; if it has a `### before-planning`
block, follow it before designing. Absent → nothing to do.

1. Explore the target repo enough to design well (reuse existing code; respect
   the repo's architecture rules in its CLAUDE.md).
2. For domain terms, consult `/glossary`; propose new entries
   before writing them.
3. Surface real design decisions to the user with **AskUserQuestion** (one popup
   per genuine fork). Describe UI choices in prose so the user can validate
   against the implemented result rather than a mockup.
4. **Honour existing ADRs.** Before reopening anything already in `docs/adr/`, read
   the ADR and respect its relitigation weight (see `/adr`) — don't reopen a
   `Compelling reasons only` / `Blockers only` decision without cause. If you think
   one should change, surface it to the user with the reason rather than quietly
   working around it.
5. **Keep a candidate-ADR list — do NOT write ADRs during design.** When an
   architectural decision lands, add it to a running list of *candidate* ADRs
   (title, the decision in 1–3 sentences, its **provenance**, and a **relitigation**
   weight only if it differs from the provenance default — see `/adr`). Do not
   ask about them yet and do not write anything to `docs/adr/`. Provenance is
   *Suggested by agent* only once the human explicitly approves your idea; err
   toward *Suggested by human*; ask before *Required by human*.

## Confirm candidate ADRs, ride-alongs and backlog candidates (once, at handoff)

When the design is essentially settled and you're ready to hand off to
execute-feature — **not before** — present the full candidate-ADR list to the user
in one pass and get an explicit decision on each. For every candidate show: the
one-line decision, its **provenance**, and its **relitigation** weight (only when it
differs from the provenance default). The user confirms, amends, or drops each.

- If the human hasn't already agreed to an idea you proposed, this is where you get
  that yes — an unconfirmed agent idea does not become a candidate ADR.
- Approved candidates are written **into the plan** (a `## Candidate ADRs` section
  and a per-task association — see below). They are **not** written to `docs/adr/`
  here; execute-feature materializes the concrete ADR when it finishes the task the
  candidate is attached to.
- If there are no candidate ADRs, skip this — don't invent decisions to record.

**Backlog candidates and ride-alongs go in the same pass**, as distinct,
separately-answerable sections below the ADRs — one interruption, not three.
Present them in the three sections defined in `CAPTURE-BAR.md`: `## Ride-alongs —
do now, in this work`, then `## Backlog candidates` with its `### Clear intent` and
`### Needs a decision` tables. Never head a table "Capture candidates" — the
user-facing noun is **backlog candidate**.

**Riding along, in a design session, means amending the plan** — adding a step to
an existing task, or one more task — before the plan is committed. The executor
then does it as part of the feature. Two consequences specific to planning:

- Criterion 1 of Test 3 ("the context is already paid for") is satisfied here by a
  file you READ during this design session, since there is no diff yet. Name the
  path; "the surrounding code" is not a path.
- If a confirmed ride-along does not fit any task cleanly, say so and capture it to
  the backlog instead. Do not bend the plan's shape around it — that is criterion 3
  (it does not move the goal) failing late.

After amending the plan, do NOT re-run this pass. The amendment is not a new design
round, and ride-alongs are depth-1 (ADR: the ride-along tier is depth-1 and
non-recursive).

Write only confirmed backlog candidates, via `/cogniva-dev:backlog`, onto the
worktree so they ride the plan commit. Omit any section with no rows — do not print
an empty table. Deliver the whole handoff pass (ADRs plus the sections) as the final
text of the turn, with no tool call after it.

## Emit the plan

**Author on this session's worktree (per CLAUDE.md Git rules) — Claude never writes
to the primary checkout.** Create or reuse the worktree first
(`<plugin>/scripts/new-feature-worktree.ps1 -Slug <slug>`, where `<plugin>` is this
plugin's root — the parent of this `skills/` dir) and author the
whole plan folder under it (`<worktree>/docs/plans/<Module>/<Feature>/`). Nothing
reaches the user's branch until the **Integrate** step below; aim to land the plan as
ONE `plan(<Module>/<Feature>): ...` commit.

Write `docs/plans/<Module>/<Feature>/<Feature>-plan.md` following
`PLAN-FORMAT.md` in this skill's directory (read it). Essentials:
- Header with **Goal**, **Architecture**, **File structure (locked)**, a
  "Read these first" list, and the line:
  `> REQUIRED EXECUTOR: /execute-feature <Module>/<Feature>`.
- Header MUST state: **no git worktree step in tasks** — execute-feature creates
  the worktree; tasks just commit on the feature branch they are already on.
- Tasks numbered `### Task N: <title>`, each **self-contained** (repeat any code
  it needs — never "same as Task 3"), with `- [ ]` steps containing exact code,
  exact commands + expected output, and a final commit step. Keep tasks COARSE —
  a handful of meaningful tasks, not micro-steps.
- Do NOT add `⛔` validation gates by default — the user validates AFTER
  integration, not mid-run. Only mark a `### ⛔ Task N:` gate for a genuinely
  irreversible mid-task action that must be confirmed before later tasks depend
  on it (e.g. a destructive migration).
- If any candidate ADRs were confirmed, add a `## Candidate ADRs` section to the
  plan (full title + provenance + relitigation + the 1–3 sentence body for each, so
  the executor writes it verbatim with only a number), and in each task that
  finalizes such a decision add a step: **"On completion, write ADR: <candidate
  title>"**. execute-feature reads these and writes the concrete `docs/adr/NNNN-*.md`
  when it finishes that task. See `PLAN-FORMAT.md`.
- No placeholders ("TBD", "TODO", "implement later") — those are plan failures.

Then seed `docs/plans/<Module>/<Feature>/state.md`:

```markdown
# <Feature> — execution state

Status: planned
Target branch: (set by execute-feature at run time)
Worktree: (set by execute-feature)
Integration: not started

## Log
```

`Status:` tracks the feature lifecycle (`deferred → planned → in-progress →
blocked → integrated → done`); seed it `planned`. The status skills
(`feature-status`, `module-status`, `repo-status`) read it.

## Large features — decompose into ordered sub-plans (kept invisible to the user)

Some features are too big for one plan. When that happens, DO NOT tell the user it
is multiple plans and DO NOT ask them to orchestrate anything — they hand off one
`/execute-feature <Module>/<Feature>` and validate once, after the WHOLE feature is
integrated. Decide decomposition yourself from the design; the user invokes
plan-feature the same way regardless, and the concise summary still presents ONE
feature (see below). Do not over-decompose — a small feature stays a single
`<Feature>-plan.md` with tasks and no manifest.

When you do decompose, emit an ORCHESTRATION manifest plus self-contained
sub-plans, all under the SAME `docs/plans/<Module>/<Feature>/` folder (full format
in `PLAN-FORMAT.md`):

- `<Feature>-plan.md` becomes the **manifest**: the same header (Goal,
  Architecture, Read-these-first, REQUIRED EXECUTOR line) PLUS a
  `## Sub-plans (execution order)` table — but NO tasks of its own.
- `subplans/NN-<SubSlug>.md` — one file per sub-plan, each a normal self-contained
  feature plan (Task sections in the standard format). Repeat any code a sub-plan
  needs; never cross-reference another sub-plan ("same as 01").
- List the sub-plans in a VALID dependency order (topologically sort prerequisites
  at design time) — execute-feature runs them in the listed order, sequentially, in
  ONE worktree, and integrates ONCE at the end. The prerequisite column documents
  WHY the order; listed order IS the execution order.
- Seed the multi-plan `state.md` variant (per-sub-plan checklist), not the plain
  one.

## Deferred scope (propose, don't write)

A focused design always cuts scope — but most cut scope is not backlog material.
Do NOT write anything to a `BACKLOG.md` from this session. Hold cut items as
**backlog candidates** and confirm them at handoff, in the same pass as the
candidate ADRs (below). A `clear` candidate may also qualify as a **ride-along** —
folded into the plan you are writing rather than deferred; Test 3 in
`CAPTURE-BAR.md` decides, and the handoff pass is where it is offered.

Read `CAPTURE-BAR.md` in the `backlog` skill's directory for the full tests. In
short:

- **Coverage first.** If the plan you just wrote actually delivers it — its Goal,
  a task, a sub-plan — it is not deferred scope. Neither is anything already
  covered by an open plan folder (`state.md` `Status:` `planned` /
  `in-progress` / `blocked`), an active `.explore/` thread, or an existing open
  backlog item. This is the single biggest source of backlog churn: items written
  during planning and closed during execution, having never been deferred at all.
- **Then intent.** Scope the user declined ("no", "wrong approach") is gone —
  never a candidate. Scope with a receipt — their words ("let's do that soon but
  not today", "next one"), or substantive engagement — is a `clear` candidate.
  Scope you floated that they did not engage with is nothing: silence is not
  deferral. Anything in between is `ambiguous`; when you cannot tell, use
  `ambiguous` rather than dropping it.

Hold each survivor as a candidate record (`description`, `module`, `tier`, `size`,
`src`, `receipt`, `strength`). They are presented at handoff, not now.

## Promotion (when this plan fulfills an existing backlog item)

If this feature came from the backlog, close the loop:
- **Loose item** in `docs/plans/<Module>/BACKLOG.md`: tick its line and append
  `→ planned: <Module>/<Feature>` (append-only; don't delete it).
- **Stub folder** `docs/plans/<Module>/<Feature>/`: write `<Feature>-plan.md` into
  that same folder (on the worktree) and flip its `state.md` `Status: deferred → planned`.

## Integrate (one commit)

**Repo obligations (`before-integrate`).** Before you commit and integrate, check
the target repo's CLAUDE.md `## Cogniva-dev workflow instructions` for a
`### before-integrate` block; honor it on the worktree now so anything it
produces rides this commit. Absent → nothing to do.

When the plan — and any sub-plans plus `state.md` — is complete on the worktree,
commit the plan folder as a single commit (stage ONLY that folder, never `git add
-A`), then fast-forward it onto the user's branch and close the worktree out:

```bash
git -C "<worktree>" add -- "docs/plans/<Module>/<Feature>"
git -C "<worktree>" commit -m "plan(<Module>/<Feature>): <one-line summary>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/integrate-feature.ps1" -WorktreePath "<worktree>" -FeatureBranch "feature/<slug>" -TargetBranch "<your branch>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/mark-cleanupable.ps1" -Worktree "<worktree>" -Branch "feature/<slug>" -Summary "plan <Module>/<Feature>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/cleanup-worktrees.ps1" -Scope list -Worktrees "<worktree>"
```

**Close out your own worktree — never leave it for a later session.** The
mark-cleanupable-then-wait handshake exists so the user can *run* code before the
worktree is destroyed. A plan is a markdown file that integrate has already
fast-forwarded onto their branch, so there is nothing to validate and the worktree
is dead the moment integrate returns. Leaving it alive leaks it across session
boundaries — `/cogniva-dev:cleanup-work` only knows the worktrees ITS session
created, and `/cogniva-dev:execute-feature` usually runs in a fresh one — and,
because plan-feature and execute-feature derive the same `<slug>` and therefore the
same worktree path and branch, lets execute-feature silently reuse your stale
planning worktree (ADR: a worktree with no validation gate closes itself out).

Run the close-out with your shell in the PRIMARY checkout, never inside the
worktree — Windows will not delete a directory that is a live process's cwd, and
`git worktree remove` guts it instead. Parse its last JSON line, `{ closed, kept,
pruned }`: `closed` is the normal result and needs no comment; a `kept` entry means
the worktree survived, so quote its reason verbatim in one line and leave it for
`/cogniva-dev:cleanup-work`.

Only run the last two commands when integrate reported `INTEGRATED`. On
`QUEUED_DIRTY` (the user's branch was dirty) still mark the worktree cleanupable but
SKIP the close-out, and say in one line that the plan is queued and
`/cogniva-dev:cleanup-work` will land it once their tree is clean. On `CONFLICT` or
`ERROR`, report the detail and stop — force nothing.

One plan-feature = one commit on the user's branch. (Any glossary edits made on the
SAME worktree ride the same integration; candidate ADRs live inside the plan, not in
`docs/adr/`, and only become concrete files during execute-feature.) If you abandon
the design before integrating, the worktree is disposable — nothing ever touched the
user's branch.

## Emit a CONCISE decisions summary (not the plan)

The user does NOT read or approve the full plan — it is an executor input, not a
review artifact. Instead, end your message with a short summary they WILL read.

The summary contains ONLY **consequential decisions** — choices you made (often
autonomously) that constrain or shape future choices. For each: the decision, and
the downstream consequence in one clause.

EXCLUDE: anything already discussed with the user, obvious/default choices, step
lists, file inventories, and UI tweaks (the user discovers those when they
validate the running app). If a decision has no downstream consequence, leave it
out. If the feature was decomposed into sub-plans, STILL present it as one feature
— do NOT enumerate sub-plans, the manifest, or "orchestration"; that is an
execute-feature implementation detail.

Format: a tight bullet list (aim for 3-7 bullets), then the plan path and the
line: "Run `/execute-feature <Module>/<Feature>` when ready." Keep it scannable —
if it is longer than the user can read in 20 seconds, it is too long.
