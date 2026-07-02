---
name: explore-idea
description: Use when the user wants to BRAINSTORM and develop an idea before any planning - a long, question-driven design conversation that produces only disposable thinking docs (gitignored .explore/), never a plan and never code. Invoke explicitly only; the goal is to deepen the idea, not to converge on action. Comes BEFORE plan-feature.
---

# Explore Idea

A pre-planning brainstorm. The goal is to UNDERSTAND and develop an idea through a
long, interactive question-and-answer conversation - NOT to produce a plan, NOT to
write code. Output is disposable thinking captured in gitignored markdown the user
can read, react to, and throw away.

This skill runs BEFORE `/plan-feature`. Jumping to plan-feature forces an
executor-shaped plan before the idea is even understood. Explore-idea is the
missing "just think with me" phase.

## Prime directive - keep fleshing out the idea

Your single job is to DEEPEN the idea. At every turn your bias is to explore
further, not to wrap up. This is the whole point of the skill.

- NEVER push toward a plan, a feature, code, or "next steps." Do not offer to
  implement, do not suggest `/plan-feature`, do not ask "should I start building."
- When you reach a natural stopping point, do NOT propose an action - instead
  surface an unexplored angle, a tension, or a sharper question.
- Converging, planning, persisting, or handing off happens ONLY when the USER
  explicitly asks for it. Until then, assume the conversation continues.
- These are expected to be LONG conversations across many turns (and possibly
  resumed in a later session). That is the success case, not a problem to escape.

## Where the thinking lives

- All output goes to a gitignored folder at the primary checkout root:
  `.explore/<slug>/` (`<slug>` = kebab of the topic). The main living doc is
  `.explore/<slug>/exploration.md`; fork sub-threads into sibling `<sub-slug>.md`
  files as the conversation branches.
- `.explore/` is in `.gitignore`, so it is invisible to git: it never appears as
  an uncommitted change and never blocks the background fast-forward auto-merges.
  Do NOT write exploration docs anywhere tracked.
- NEVER commit, stage, branch, or create a worktree for this work. Explore-idea
  makes no code edits, so under the ambient-worktree workflow it stays in the
  primary checkout and needs no worktree (see the note at the end).
- Disposable by default: leaving the session loses nothing important and clutters
  nothing. The docs persist on disk for resuming but are never repo content unless
  the user explicitly promotes them.

## Run it

1. Invoke: `/explore-idea [topic]` (omit the topic to be asked what we're exploring).
2. If `.explore/` already holds topic folders, list them first so the user can
   resume an earlier thread instead of starting fresh.
3. Create/open `.explore/<slug>/exploration.md` and start the loop.

## The exploration loop

1. **Ask a lot.** Lead with questions. Draw out goals, constraints, unknowns,
   assumptions, the "why now," what success looks like, what is explicitly out of
   scope. Prefer open questions; use **AskUserQuestion** only for genuine forks.
2. **Read code to inform, never to change it.** You may read the codebase and
   dispatch read-only `Explore` agents to understand what exists and what is
   feasible. You may NOT Edit/Write anything in the tracked tree.
3. **Capture into the living doc.** Keep `exploration.md` current as understanding
   evolves - what we know, options on the table with tradeoffs, candidate (NOT
   committed) decisions, open questions, parked tangents. It is a thinking surface,
   not a spec.
4. **Pause for reading.** At meaningful checkpoints, tell the user which file to
   read and stop for their follow-ups - e.g. "Updated
   `.explore/<slug>/exploration.md` - read the Options section and tell me which
   way pulls you, or what I've missed." Do not monologue past a natural read point.
5. **Use the glossary read-only.** Reference existing terms and link them. If a new
   term seems to be emerging, note it as a *candidate* in the doc - do NOT write
   glossary entries (those are committed).

## Hard rules

- No plan. No code. No commits. No ADRs, no glossary writes - capture candidates in
  the doc only. Read-only on everything tracked.
- All writes go under `.explore/<slug>/` and nowhere else.
- Never nudge the user toward acting. (See Prime directive.)

## Handoff - only when the user asks

The user decides if and when an exploration becomes something else. When - and only
when - they ask, you can:
- **Plan it:** hand the relevant `.explore/<slug>/` material to `/plan-feature` as
  design input.
- **Park it:** drop a `/backlog` item or stub so the thread is not lost.
- **Persist it:** move/copy the doc into a tracked location (e.g. `docs/specs/` or
  `docs/plans/<Module>/<Idea>/`) so it becomes committed repo content.
- **Drop it:** delete `.explore/<slug>/`, or just leave it - it is gitignored and
  harmless.

Never perform any of these unprompted.

## exploration.md skeleton

```markdown
# Exploring: <topic>

Status: exploring   (disposable - gitignored, not a plan)

## What we're trying to figure out
<the question / itch, in the user's terms>

## What we know
- ...

## Options on the table
- **Option A** - <tradeoffs>
- **Option B** - <tradeoffs>

## Candidate decisions (NOT committed)
- ...

## Open questions
- [ ] ...

## Candidate glossary terms / ADRs (capture only - do not write)
- ...

## Parking lot / tangents
- ...
```

## Note for the ambient-worktree workflow

The worktree+auto-merge default has landed: Claude edits NOTHING in the primary
checkout except the two gitignored scratch dirs `.explore/**` and `.plans-staging/**`
(everything else - code, docs, .claude - goes through a worktree, and there are no
auto-commit hooks). `.explore/` MUST stay on that exempt list: because it is gitignored
it never touches your branch, and exempting it keeps explore-idea's brainstorm writes
in the primary instead of forcing them into (and destroying them with) a worktree.
