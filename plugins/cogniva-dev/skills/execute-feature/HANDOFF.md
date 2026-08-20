# READY FOR REVIEW — lean-mode handoff format

Read this when a lean-mode run reaches its finish (`SKILL.md` Step 4.8, and
the same finish in `quick-fix`). Lean mode does not integrate and does not
push, so the handoff IS the deliverable: it has to tell a reviewer
everything they would otherwise have to reconstruct by hand. Emit it as the
final text of the turn.

## Header block — exactly these four lines, in this order

```
READY FOR REVIEW
Branch: <current branch>
Integration: not performed
Remote push: not performed
```

## Required sections

Every section below appears in EVERY handoff, in this order. Each is 1–5
lines. A section with nothing to report says `none` — never drop it. An
absent section is indistinguishable from a forgotten one, which is exactly
what this format exists to prevent.

- **Summary** — the feature and the tasks that ran, in 2–4 sentences. Under
  `tasks=one`, name the task slice that ran and list the tasks remaining —
  never present the feature as complete while tasks remain.
- **Files changed** — one line per path: the path, then what changed in it.
- **Files read** — only the ones where it is non-obvious why they were
  read; skip the incidental ones.
- **Behavioral / workflow changes** — what a user or a downstream skill
  will now do differently.
- **Deviations & surprises** — where the work departed from the plan, and
  anything encountered that the plan did not anticipate.
- **Checks run** — the exact commands, each with its outcome.
- **Skipped validations** — anything not run, and why.
- **`git diff --check`** — the result (`clean`, or what it flagged and how
  it was resolved).
- **Final tree status** — a summary of `git status --porcelain`; under
  `commits=none` also include `git diff --stat`.
- **Pre-existing / unrelated changes** — anything that was already dirty
  before the run, kept separate from this run's work.
- **Risks / limitations / assumptions** — what could bite, what was assumed.
- **Follow-ups** — work surfaced but NOT done, each with its receipt (a
  located fact). These are candidates for the backlog gate, not entries.
- **Commits** — the SHAs, only under `commits=task|final`; under
  `commits=none` this reads `none — work is uncommitted in the tree`.

## Closing line

Close with this semantics line, verbatim:

READY FOR REVIEW means the executed scope is complete on this branch — NOT
approved, NOT integrated, NOT ready to push.

(The executed scope is the whole feature, or under `tasks=one` the completed
slice the Summary named.)
