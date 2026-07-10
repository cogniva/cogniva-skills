---
name: backlog
description: Use to capture deferred or not-yet-planned work so it is not lost - a loose idea ("dropdown should be a treeview", "slight UI issue"), scope intentionally cut from a plan, or a feature-sized idea worth tracking before it earns a full plan. Directly invokable AND meant to be called by any skill that surfaces work it is not doing right now. Lightweight, append-only, no subagents. Read with module-status / repo-status.
---

# Backlog

Park work somewhere durable instead of in prose or in your head. Two tiers:

- **Tier 1 — loose item:** one checklist line in a `BACKLOG.md`. For small things
  not worth a folder (a UI tweak, a bug, a "should be X later").
- **Tier 2 — feature-sized stub:** a folder under a Module with `state.md`
  (`Status: deferred`) + `backlog.md`. For a cohesive chunk of future capability
  that will eventually earn a full `/cogniva-dev:plan-feature` plan.

Read `BACKLOG-FORMAT.md` in this skill's directory for the exact line grammar and
stub layout. This skill is **model-driven** (you edit markdown directly — no
script) and **append-only**: never delete or reorder existing items.

Invoke: `/cogniva-dev:backlog [<item description>]` (omit to be asked).

## Inputs

- **description** — what the work is, in one line.
- **module** (optional) — the owning Module. If the item clearly belongs to one,
  use it; otherwise the item is repo-level.
- **size** (optional) — `S` | `M` | `L`.
- **src** (optional) — the `<Feature>` this was deferred from, if any.
- **tier** (optional) — `loose` | `stub`. If absent, you decide (see below).

## Steps

1. **Pick the tier.** A one-liner or small fix → **loose**. A cohesive future
   capability with its own scope, contracts, and acceptance criteria → **stub**.
   When unsure and you are talking to the user, ask; when another skill called you
   with a `tier=`, honor it.

2. **Pick the file / folder.**
   - Belongs to a Module → `docs/plans/<Module>/BACKLOG.md` (loose) or
     `docs/plans/<Module>/<Idea>/` (stub, `<Idea>` PascalCase).
   - Cross-cutting / no Module → `docs/plans/BACKLOG.md` (loose only).
   - **Lazy-create**: if `BACKLOG.md` does not exist, create it from the header in
     `BACKLOG-FORMAT.md`.

3. **Dedup.** Read the target `BACKLOG.md` (or scan the Module's stub folders).
   If a near-duplicate open item already exists, do NOT add a second — point the
   user at the existing one instead.

4. **Write the item.**
   - **Loose:** append one `- [ ] <description>` line with optional trailing
     backtick tags (`size:`, `area:`, `src:`) per `BACKLOG-FORMAT.md`.
   - **Stub:** create the folder with `state.md` (`Status: deferred`) and
     `backlog.md` (deferred scope, contracts/requests to use, acceptance criteria,
     the MVP it depends on, and a one-line "expand with /cogniva-dev:plan-feature"
     pointer).

5. **Report** the one-line result: tier, path, and the item text. No HTML, no
   glossary work, minimal ceremony.

## Called by another skill

Any skill that finds work it is not doing now should route it here rather than
burying it in prose. The caller invokes:

```
/cogniva-dev:backlog  module=<Module> tier=loose|stub size=<S> src=<Feature> — <description>
```

Honor the passed `tier`/`module`; still dedup; record and return the one-line
result. Examples of callers: `plan-feature` (scope cut from a design),
`execute-feature` (leftover scope on a BLOCKED task), `quick-fix` (a follow-up the
fix surfaced).

## Rules

- Append-only. Never delete or rewrite existing items here — promotion (ticking an
  item, flipping a stub's `Status`) is done by `plan-feature`/`quick-fix` when the
  work is actually picked up.
- Keep it lightweight: one line or one small folder, then stop. This skill never
  writes feature code and never runs subagents.
- In a guard-opted-in repo's primary checkout, tier-1 loose appends work directly:
  `BACKLOG.md` files (`docs/plans/BACKLOG.md`, `docs/plans/<Module>/BACKLOG.md`)
  are exempt from the primary-edit guard. Tier-2 stub creation is NOT exempt —
  create stubs inside a worktree (e.g. while other worktree work is open, or via
  `/cogniva-dev:quick-fix`).
