# Backlog format

Deferred and not-yet-planned work lives under `docs/plans/`. Two tiers.

## Tier 1 — loose items (`BACKLOG.md`)

A flat checklist. One file per scope:
- `docs/plans/BACKLOG.md` — repo-level (cross-cutting / no Module)
- `docs/plans/<Module>/BACKLOG.md` — Module-level

### Header (used when lazy-creating the file)

```markdown
# <Module> — Backlog

Loose & deferred work, not yet planned. Promote with /cogniva-skills:plan-feature;
trivial fixes can go straight to /cogniva-skills:quick-fix.
```

(For the repo-level file, title it `# Backlog` and drop `<Module>`.)

### Item line grammar

```markdown
- [ ] <description>  `size:S` `area:UI` `src:CreateOrder`
```

- `- [ ]` = open, `- [x]` = resolved. The status skills parse these.
- Trailing **backtick tags** are all optional:
  - `size:S` | `size:M` | `size:L`
  - `area:<x>` — a free-form area label (e.g. `area:UI`)
  - `src:<Feature>` — the feature this was deferred from
  - `promoted:<Module>/<Feature>` — added on promotion (see below)
- Keep the description to one line. No nested bullets.

### Resolving / promoting an item

Done by `plan-feature` / `quick-fix` when the work is actually picked up — tick the
box and append a `→` pointer:

```markdown
- [x] Whole-facet picker → planned: C3Data/ModelUiFoundation  `2026-06-13`
- [x] Status-bar misalignment → done  `2026-06-13`
```

Append-only otherwise: never delete or reorder existing lines.

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

## Deferred scope
- <bullet>
- <bullet>

## Contracts / requests to use
- <interface.Method / request type the implementation will call>

## Acceptance criteria
- <what "done" will look like>

## Expand
Run `/cogniva-skills:plan-feature` for <Module>/<Idea> when <MVP> has landed.
```

### Promotion

When the stub is picked up, `plan-feature` writes `<Idea>-plan.md` into this same
folder and flips `state.md` `Status: deferred → planned`. The `backlog.md` can stay
as design notes or be folded into the plan.
