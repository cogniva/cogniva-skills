---
name: plan-feature
description: Use when designing ONE feature with a strong model before implementation - runs a focused design session and emits a task-segmented feature plan (executable by /cogniva-dev:execute-feature). Pairs with auto-doc (ADRs) and glossary. Does not depend on superpowers.
---

# Plan Feature

Design ONE feature with the strong model, then emit a plan whose tasks a small
model can execute later with lean, per-task context. Output is a feature folder
under `docs/plans/<Module>/<Feature>/`. Keep THIS session focused on design — do
not implement.

## Gather first (ask the user)

1. Module name `<Module>` and feature name `<Feature>` (PascalCase, e.g.
   `Selections` / `TaskpaneStatusBar`). Derive a kebab `<slug>` for branches.
2. The outcome the feature must deliver, and any hard constraints.

## Design loop

1. Explore the target repo enough to design well (reuse existing code; respect
   the repo's architecture rules in its CLAUDE.md).
2. For domain terms, consult `/cogniva-dev:glossary`; propose new entries
   before writing them.
3. Surface real design decisions to the user with **AskUserQuestion** (one popup
   per genuine fork). Describe UI choices in prose so the user can validate
   against the implemented result rather than a mockup.
4. When an architectural decision is made, use `/cogniva-dev:auto-doc` to
   record the ADR.

## Emit the plan

Write `docs/plans/<Module>/<Feature>/<Feature>-plan.md` following
`PLAN-FORMAT.md` in this skill's directory (read it). Essentials:
- Header with **Goal**, **Architecture**, **File structure (locked)**, a
  "Read these first" list, and the line:
  `> REQUIRED EXECUTOR: /cogniva-dev:execute-feature <Module>/<Feature>`.
- Header MUST state: **no git worktree step in tasks** — execute-feature creates
  the worktree; tasks just commit on the feature branch they are already on.
- Tasks numbered `### Task N: <title>`, each **self-contained** (repeat any code
  it needs — never "same as Task 3"), with `- [ ]` steps containing exact code,
  exact commands + expected output, and a final commit step. 2-5 min per step.
- Mark any task that needs human validation as `### ⛔ Task N: <title>` — a hard
  stop; execute-feature halts there until the user validates.
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

Both `<Feature>-plan.md` and `state.md` are **control-plane** files: they live
in the primary checkout and execute-feature reads/updates them there in place —
they are deliberately NOT carried into the feature worktree (see
docs/adr/0004). Just write them; no manual commit is needed (the Stop-hook
commits `docs/plans/` where it is tracked).

## Capture deferrals (don't bury cut scope in prose)

A focused design always cuts scope. Do NOT leave it as a "Deferred / future work"
paragraph — record each cut item with `/cogniva-dev:backlog` so it survives:
- A small follow-up → a loose line:
  `/cogniva-dev:backlog module=<Module> tier=loose src=<Feature> — <description>`
- A feature-sized chunk → a stub:
  `/cogniva-dev:backlog module=<Module> tier=stub src=<Feature> — <description>`

## Promotion (when this plan fulfills an existing backlog item)

If this feature came from the backlog, close the loop:
- **Loose item** in `docs/plans/<Module>/BACKLOG.md`: tick its line and append
  `→ planned: <Module>/<Feature>` (append-only; don't delete it).
- **Stub folder** `docs/plans/<Module>/<Feature>/`: write `<Feature>-plan.md` into
  that same folder and flip its `state.md` `Status: deferred → planned`.

End your message with the plan path so the user can review, then tell them to
run the REQUIRED EXECUTOR when ready.
