# Deep groom (opt-in)

Judgment-heavy checks over the items that SURVIVED the standard pass. Only read
this file when the deep pass was requested. Run the checks in order, each as
ONE batched question — never item-by-item ping-pong.

## 1. Still wanted?

Present every surviving open item in one numbered list, grouped by Module, each
with one line of what it would take today. Ask once: "which of these are
dead?" Closures: `→ wont-do: no longer wanted (deep groom <date>)`.
Streamlining: pre-sort so the likeliest-dead items (oldest, smallest, least
connected to the repo's current direction) are on top, and say that is the sort
order so the user can stop reading when the list turns healthy.

## 2. Merge / split

Propose merges (several lines that are one piece of work) and splits (one line
hiding several) as a short list: the new item wording, and which old lines
close `→ merged-into:` / `→ superseded-by:` it. New items go via
`/cogniva-dev:backlog`; the user confirms the batch.

## 3. Wrong tier / wrong home

- Loose item grown feature-sized → propose a stub: close the line
  `→ superseded-by: <Module>/<Idea>` and create the stub via
  `/cogniva-dev:backlog tier=stub` (worktree rules apply to stub creation).
- Stub shrunk to a tweak → flip the stub `Status: superseded`, add the loose
  line via `/cogniva-dev:backlog`.
- Wrong Module (or a repo-level item that now has a Module) → close
  `→ merged-into: <right file>` and re-add there via `/cogniva-dev:backlog`.
  Cross-file moves are never in-place edits.

## 4. Size re-check

Only for items carrying a `size:` tag. Flag tags the codebase has invalidated
(either direction) with one line of why. Confirmed fixes are in-place tag
edits (mechanics per `GROOMING-CRITERIA.md`).

Report deep-groom results in the same two-table + flags format as the standard
pass, and apply them through the same single confirmation gate.
