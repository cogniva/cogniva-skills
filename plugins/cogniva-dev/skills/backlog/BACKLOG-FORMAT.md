# Backlog format

Planned deferrals live under `docs/plans/` — work with a stated reason to wait. Two tiers.

## Tier 1 — loose items (`BACKLOG.md`)

A flat checklist. One file per scope:
- `docs/plans/BACKLOG.md` — repo-level (cross-cutting / no Module)
- `docs/plans/<Module>/BACKLOG.md` — Module-level

### Header (used when lazy-creating the file)

```markdown
# <Module> — Backlog

Planned deferrals — work with a stated reason to wait (`because:` tag). Promote with /cogniva-dev:plan-feature;
trivial fixes can go straight to /cogniva-dev:quick-fix.
```

(For the repo-level file, title it `# Backlog` and drop `<Module>`.)

### Item line grammar

```markdown
- [ ] <description>  `size:S` `area:UI` `src:CreateOrder` `because:after ModelUiFoundation`
```

- `- [ ]` = open, `- [x]` = resolved. The status skills parse these.
- Trailing **backtick tags** are all optional:
  - `size:S` | `size:M` | `size:L`
  - `area:<x>` — a free-form area label (e.g. `area:UI`)
  - `src:<Feature>` — the feature this was deferred from
  - `because:<reason>` — why this waits (spaces are fine inside the backticks,
    e.g. `because:blocked on IExportPort`, `because:decision pending`).
    Encouraged on every item; REQUIRED when a skill proposed the deferral.
    Legacy lines without one stay valid — groom-backlog flags them for
    routing.
  - `promoted:<Module>/<Feature>` — added on promotion (see below)
- Keep the description to one line. No nested bullets.

### Resolving / promoting an item

An item is closed by ticking the box and appending a `→` **exit verb**. Never
delete the line — the verb is the history.

Pick-up verbs (written by `plan-feature` / `quick-fix` when work starts):

```markdown
- [x] Whole-facet picker → planned: C3Data/ModelUiFoundation  `2026-06-13`
- [x] Status-bar misalignment → done  `2026-06-13`
```

When an item's `because:` reason has cleared — the blocker landed, the awaited
feature merged, the pending decision was made — groom-backlog flags it
actionable-now with a ready invocation; the pick-up verbs above then apply.

Grooming verbs (written when a review finds the item no longer needs doing —
always with a receipt: the feature, commit, or decision that justifies the
verdict):

```markdown
- [x] Cache facet counts → obsolete: counts now computed in SQL  `2026-07-25`
- [x] Export to CSV → superseded-by: C3Data/BulkExport  `2026-07-25`
- [x] Tooltip on size column → merged-into: Polish grid columns  `2026-07-25`
- [x] Dark-mode toggle → wont-do: theming dropped per strategy call  `2026-07-25`
```

- `→ obsolete: <why the premise no longer holds>`
- `→ superseded-by: <Module>/<Feature> or <newer item>` — a later feature or
  item covers this ground; the pointer names the winner.
- `→ merged-into: <surviving item>` — this line's scope now lives in another
  (usually new) item; add the merged scope THERE before closing here.
- `→ wont-do: <the decision>` — still valid work, deliberately declined.

The status skills only distinguish open (`- [ ]`) from closed (`- [x]`), so
every verb counts as resolved. Append-by-default otherwise: a confirmed grooming
verdict may reword an open item in place (see the groom-backlog skill), but lines
are never deleted or reordered.

## Tier 2 — feature-sized stub (`<Module>/<Idea>/`)

For a cohesive future capability worth tracking before it earns a full plan
(like the C3Data Backlog A/B/C stubs). Folder: `docs/plans/<Module>/<Idea>/`
(`<Idea>` PascalCase). It has **no `-plan.md`** — that absence marks it a stub;
`feature-status` / `module-status` see it via `state.md`.

### `state.md`

```markdown
# <Idea> — execution state

Status: deferred
Target branch: (set by execute-feature at run time)
Worktree: (set by execute-feature)
Integration: not started

## Log
```

### `backlog.md`

```markdown
# <Idea> — Backlog (deferred)

**Depends on:** <the MVP / feature this comes after>
**Deferred because:** <the reason this waits — required>

## Deferred scope
- <bullet>
- <bullet>

## Contracts / requests to use
- <interface.Method / request type the implementation will call>

## Acceptance criteria
- <what "done" will look like>

## Expand
Run `/cogniva-dev:plan-feature` for <Module>/<Idea> when <MVP> has landed.
```

### Promotion

When the stub is picked up, `plan-feature` writes `<Idea>-plan.md` into this same
folder and flips `state.md` `Status: deferred → planned`. The `backlog.md` can stay
as design notes or be folded into the plan.

The grooming verbs apply to stubs too, via `state.md`: flip
`Status: deferred → obsolete` (or `superseded`, `wont-do`) and add a dated `## Log`
line carrying the same receipt (e.g. `2026-07-25 — superseded by C3Data/BulkExport`).
Leave the folder in place — never delete a stub.
