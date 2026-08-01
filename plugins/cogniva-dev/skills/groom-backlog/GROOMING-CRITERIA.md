# Grooming criteria

The verdict catalog for `/groom-backlog`. The exit-verb grammar lives in the
backlog skill's `BACKLOG-FORMAT.md`; this file defines WHEN each verb applies,
what evidence it needs, and how the edit is made.

## Confidence

- **confirmed** → Table 1: the receipt is verifiable in the repo right now — a
  commit SHA, a merged feature folder whose `state.md` says
  `integrated`/`done`, the behavior demonstrably present in code, or an
  exact-duplicate line.
- **inferred** → Table 2: the verdict rests on judgment (approach drift,
  apparent supersession, a conflicting pair). State the reasoning and the open
  question.

When in doubt, Table 2. One wrong scan-and-nod row erodes trust in every
future groom.

## Closure verdicts (standard pass)

### complete
The work already happened — via another feature, a quick fix, or a drive-by.
**Receipt:** commit SHA or merged `<Module>/<Feature>`; verify the behavior
exists NOW, not merely that a commit message claims it.
**Edit:** tick, `→ done: <receipt>` + date.

### partially complete
Part landed; a real remainder exists.
**Receipt:** as complete, plus name the remainder precisely.
**Edit (confirmed):** reword the line in place to the remainder only; it stays
open. If the remainder is really different work, close the line
`→ superseded-by: <new item>` and add the new item via `/cogniva-dev:backlog`.

### obsolete
The premise no longer holds — the code it targeted was replaced, or the problem
can no longer occur.
**Receipt:** what changed and where that change is visible.
**Edit:** tick, `→ obsolete: <why>` + date.

### superseded
A later feature, plan, or backlog item covers this ground better.
**Receipt:** the winner (`<Module>/<Feature>` or the newer item).
**Edit:** tick, `→ superseded-by: <winner>` + date.

### duplicate
Two open items describe the same work — possibly across files (Module-level vs
repo-level).
**Receipt:** both locations, quoted.
**Edit:** keep the better-worded, better-homed one open; close the other
`→ merged-into: <survivor>`. If the loser had unique scope, fold it into the
survivor's wording first (in-place reword, confirmed).

### conflicting pair
Two open items prescribe incompatible approaches. Always Table 2 — the user
picks the survivor.
**Edit:** loser closed `→ superseded-by: <survivor>` (the approach changed) or
`→ wont-do: <decision>` (deliberately declined).

## Flags (report-only — never an edit)

### actionable-now
A stub whose `Depends on:` has landed, or a loose item whose blocker is gone.
Report with the evidence the dependency landed; suggest
`/cogniva-dev:plan-feature` (feature-sized) or `/cogniva-dev:quick-fix`
(small). Grooming never starts the work.

### cryptic
The item cannot be understood well enough to judge ANY verdict. Ask the user.
Once explained: reword in place (confirmed) so it stays actionable, or close
`→ wont-do: <decision>` if the user shrugs.

### stale-refs
The item is still valid but its anchors rotted — `src:` names a renamed
feature, paths moved. Optional confirmed in-place reword to fix the anchors.
Low priority; batch these.

## Edit mechanics

- **Loose line close:** flip `- [ ]` to `- [x]`, append the verb annotation
  and a backtick date:
  `- [x] Cache facet counts → obsolete: counts now computed in SQL  ` `` `2026-07-25` ``
- **Stub close:** in `state.md` flip `Status: deferred` →
  `obsolete` | `superseded` | `wont-do` and append a dated `## Log` line with
  the receipt. Leave the folder in place.
- **In-place reword:** allowed ONLY as a confirmed verdict (partial-complete
  remainder, cryptic clarification, stale-ref fix, duplicate fold-in).
  Append-by-default everywhere else; never delete or reorder lines — git
  history carries the old wording.
- **Guard routing:** loose `BACKLOG.md` edits are guard-exempt (edit directly
  in the primary checkout) — but the exemption is not a licence to leave the
  tree dirty. Close the loop as Step 4 of the skill requires: OFFER to commit
  the directly-edited backlog file(s), never auto-commit. An exempt edit nobody
  commits blocks the next integrate with `QUEUED_DIRTY`. Stub `state.md` edits
  are not exempt — in a guard-opted repo, batch ALL confirmed stub closures into
  ONE `/cogniva-dev:quick-fix` invocation listing the exact flips.
- **New items** produced by grooming (remainders, merged scope) go through
  `/cogniva-dev:backlog`, so its dedup and placement rules apply.
