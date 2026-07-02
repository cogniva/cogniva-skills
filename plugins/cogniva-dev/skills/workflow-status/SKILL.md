---
name: workflow-status
description: Read-only status of background Workflow runs (execute-feature, code-review ultra, custom workflows) for this repo - including ones started in OTHER sessions. Scans the on-disk workflow journals so it works from the IDE/chat with no terminal `/workflows` UI. Reports each run's name, originating session, per-task DONE/BLOCKED counts, and whether an agent is RUNNING (open 'started' + fresh write) or STALLED (open 'started' + stale write). Use when the user asks "check workflows / is my workflow still running / what's running / did the execute-feature finish". No subagents, no edits.
---

# workflow-status

The on-disk equivalent of the terminal `/workflows` view, usable from anywhere
(IDE, chat). Workflow runs persist their state to disk under the orchestrating
session, so any session can read another session's runs. This skill is the
single read-only roll-up. It never edits anything and spawns no subagents.

Invoke: `/workflow-status` (optionally `--all`, `--detail`, `--session <prefix>`,
`--json`). For `execute-feature` runs it also prints a **per-task breakdown**
(done / running / blocked / pending + commit SHAs) — per-task status and SHAs
come from the run **journal** (structured truth); the feature plan supplies the
full task list + titles. Shown automatically for any RUNNING run, and for every
shown run with `--detail`.

## Where the state lives

```
~/.claude/projects/<slug>/<session-id>/
  subagents/workflows/<wf-id>/journal.jsonl   one {started|result} per task agent (truth)
  subagents/workflows/<wf-id>/agent-<id>.jsonl each agent transcript (mtime = liveness)
  workflows/scripts/<name>-<wf-id>.js          the workflow script (gives the name)
```
`<slug>` is the repo path with `:` `\` `/` replaced by `-`
(e.g. `c--WorkingGit-CognivaNewRepo`). A run is **RUNNING** when a `started`
record has no matching `result` AND the newest `agent-*.jsonl` was written
recently; **STALLED** when that open agent has gone idle past the threshold
(the classic "workflow died with no completion notification" case); **idle**
when every agent has a `result`; **BLOCKED** when a task returned BLOCKED.

## How to run

`<plugin>` = this plugin's root (the parent of this `skills/` dir). Run this from
the repo root (works from the primary checkout or a worktree — it resolves the
main checkout's slug automatically from the current directory):

```
powershell -NoProfile -File "<plugin>/skills/workflow-status/workflow-status.ps1"
```

Common options:
- `-All` — include runs older than the default 24h window.
- `-Detail` — per-task breakdown for EVERY shown run, not just RUNNING ones.
- `-Session <prefix>` — only one session (full id or a leading prefix).
- `-StallSeconds <n>` — idle threshold for STALLED (default 900).
- `-Json` — raw objects instead of the table; the per-task list is embedded
  under each row's `Tasks` property (each with `N`, `Title`, `State`, `Sha`).
- `-RepoRoot <path>` / `-ProjectsDir <path>` — override slug derivation.

The per-task glyphs: `[v]` done · `[>]` running now · `[~]` partial · `[x]`
blocked · `[.]` pending. Status and commit SHAs are read from the run's
**journal** (the structured `result` records), so they reflect the commits that
actually landed — even after integration rewrote the pre-merge SHAs that
state.md recorded. The plan file (for the task list + titles) is read from the
run's worktree, or — if that worktree was already removed after integration —
from the same path under the main checkout; if it can't be found at all, the
breakdown **degrades to a journal-only view** rather than vanishing (the case
that previously produced `Tasks: null`).

## What to report back

1. Echo the table the script prints. Lead with anything **RUNNING** or
   **STALLED** — those are what the user cares about.
2. For an `execute-feature` run, **present the per-task breakdown as a checkmark
   table** to the user (✅ done · ▶ running · · pending), with commit SHAs and
   the live task highlighted — that level of detail is the point of this skill,
   so include it whenever the script emits it (don't collapse it back to a bare
   count). Pair it with `state.md` only if the user wants the prose log.
3. If a run is **STALLED**, say so plainly and point at the takeover recipe:
   read the newest `agent-*.jsonl` for the last task, finish its uncommitted
   edits manually, then integrate — do not blindly resume (a dead orchestrator
   won't pick back up).
4. To drill into one run, open its `journal.jsonl` and the relevant
   `agent-<id>.jsonl` under the path the table's SESSION + WORKFLOW columns
   identify.

This skill is purely diagnostic. To act on what it finds, use the normal
worktree flow (`/execute-feature` to resume planned work, `/cleanup-work` to
close out integrated worktrees).
