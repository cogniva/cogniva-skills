---
name: plan-feature
description: Use when designing ONE feature with a strong model before implementation - runs a focused design session and emits a task-segmented feature plan (executable by /execute-feature). Pairs with adr (ADRs) and glossary.
---

# Plan Feature

Design ONE feature with the strong model, then emit a plan whose tasks a
small model can execute later with lean per-task context. Output:
`docs/plans/<Module>/<Feature>/`. Design only — do not implement.

**Worktree dispatch (check first):** worktree mode is ON iff the target
repo's `.claude/cogniva-dev.local.json` has `"worktrees": true`. ON → read
`WORKTREE.md` beside this file NOW; it replaces the ⟦worktree⟧ steps. OFF →
ignore the tags; author directly on the user's checkout and current branch.

The target repo is the checkout you were invoked from. This skill's own
files and the `<plugin>` scripts live in the plugin install — read formats
there, but never treat that checkout as the subject of the feature.

## Gather first

1. `<Module>` and `<Feature>` (PascalCase); derive a kebab `<slug>`.
2. The outcome the feature must deliver, and any hard constraints.

## Design loop

Run `powershell -NoProfile -ExecutionPolicy Bypass -File
"<plugin>/scripts/resolve-workflow-obligations.ps1" -Repo "<repo>" -Phase
"before-planning"` and honour its reported block first. It resolves AGENTS.md
first with a per-phase CLAUDE.md fallback.

1. Explore the repo enough to design well — reuse existing code; respect
   its architecture rules.
2. Domain terms: consult `/glossary`; propose new entries before writing
   them.
3. Surface each genuine design fork with **AskUserQuestion** (one popup per
   fork). Describe UI choices in prose.
4. **Honour existing ADRs** — read the relitigation weight before reopening
   anything in `docs/adr/` (see `/adr`); surface a needed change with the
   reason, never quietly work around it.
5. **Candidate ADRs, not files.** When an architectural decision lands, add
   it to a running candidate list (title, the decision in 1–3 sentences,
   provenance, relitigation only if it differs from the provenance
   default). Nothing is written to `docs/adr/` during design. Provenance is
   *Suggested by agent* only once the human explicitly approves your idea.
   For ADRs coming from humans, err toward *Suggested by human*; ask before
   *Required by human*.

## Handoff pass (once, when the design is settled)

Present in ONE pass, as the final text of the turn: the candidate-ADR list
(the user confirms/amends/drops each — an unconfirmed agent idea never
becomes a candidate; none → skip, don't invent decisions to record), then
surfaced work through `CAPTURE-BAR.md`'s route-first gate (file in the
`backlog` skill's directory). Do now in a design session means amending the
plan before it is committed; depth-1, offered once. Plan next is a proposed
invocation the user fires — never auto-run. Deferred-scope rules, in short:
covered-by-the-plan is not deferred; declined scope is gone; a deferral needs
a receipt AND a `because:` reason; silence is not deferral;
vague-and-unimportant is dropped with a one-line mention.
Write confirmed backlog items via `/cogniva-dev:backlog`. Approved ADR candidates go INTO the plan (below);
execute-feature materializes them.

## Emit the plan

⟦worktree⟧ Write `docs/plans/<Module>/<Feature>/<Feature>-plan.md`
following `PLAN-FORMAT.md` in this skill's directory (read it). Essentials:

- Header: **Goal**, **Architecture**, **File structure (locked)**, "Read
  these first", and the line
  `> REQUIRED EXECUTOR: /execute-feature <Module>/<Feature>`.
- Tasks `## Task N: <title>`, each SELF-CONTAINED (repeat any code it
  needs — never "same as Task 3"), `- [ ]` steps with exact code/commands,
  and a final commit step. Keep tasks COARSE.
- No ⛔ gates by default — only for a genuinely irreversible mid-run action.
- Confirmed candidates → a `## Candidate ADRs` section (full title +
  provenance + relitigation + the 1–3 sentence body) plus an "On
  completion, write ADR: <title>" step in the task that finalizes each
  decision.
- No placeholders ("TBD", "TODO") — those are plan failures.

Large features: decompose into `subplans/NN-<SubSlug>.md` files plus a
manifest with a `## Sub-plans (execution order)` table (format in
PLAN-FORMAT.md). Decide the decomposition yourself, present it to the user
as ONE feature, and do not over-decompose — a small feature stays one plan.

Promotion: if this plan fulfills a backlog item, tick its line and append
`→ planned: <Module>/<Feature>`; a stub folder gets the plan written into
it.

Then land the plan by commit policy. plan-feature reuses execute-feature's
`commits=` vocabulary; only `none|final` apply here (there is at most ONE
commit to make). Run the shared `resolve-workflow-obligations.ps1` with
`-Phase "before-integrate"` and honour its reported block so its output lands
with the plan (under Codex honour only the block's
substantive gate — see `../execute-feature/CODEX.md`):

- **Lean mode default: `commits=none`** — leave the plan folder (and the
  before-integrate output) UNCOMMITTED so the user can review the plan
  first; say so in one line. Never stage or commit on your own.
- **Explicit `commits=final` (opt-in), and worktree mode (unchanged):**
  commit the plan folder as ONE commit:

```bash
git add -- "docs/plans/<Module>/<Feature>"
git commit -m "plan(<Module>/<Feature>): <one-line summary>"
```
⟦worktree⟧

## Emit a CONCISE decisions summary (what the user actually reads)

The user does not read or approve the plan — it is executor input. End with
3–7 bullets of CONSEQUENTIAL decisions only (each: the decision + its
downstream consequence in one clause), then the plan path and "Run
`/execute-feature <Module>/<Feature>` when ready." Exclude anything already
discussed, defaults, step lists, file inventories, and UI tweaks. Present
one feature even when decomposed — sub-plans are an executor detail. Under
the lean `commits=none` default, also state that the plan is uncommitted
awaiting review.
