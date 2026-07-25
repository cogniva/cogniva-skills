# BacklogGrooming — Feature Plan

> REQUIRED EXECUTOR: /execute-feature FeatureLifecycle/BacklogGrooming
> Tasks contain NO git worktree/branch step — execute-feature creates the worktree
> and the tasks commit on the feature branch they are already on. Never run
> git switch/checkout/branch inside a task.

**Goal:** Add a `groom-backlog` skill to cogniva-dev: an evidence-backed, human-confirmed backlog grooming pass (with an opt-in deep pass), context-lean via lazy-loaded companion files.

**Architecture:** New skill folder `plugins/cogniva-dev/skills/groom-backlog/` with three layers: a short always-loaded frontmatter description, a SKILL.md body holding only the flow (scope → read-only subagent scan → two confidence tables + flags → one confirmation gate → apply → offer deep pass), and two companion files loaded on demand — `GROOMING-CRITERIA.md` (verdict catalog, evidence standards, edit mechanics) and `DEEP-GROOM.md` (opt-in restructuring checks). Verdicts close items with the exit verbs already defined in the backlog skill's `BACKLOG-FORMAT.md`. Repo surfaces (CLAUDE.md, plugin/marketplace descriptions, glossary, the append-only wording in the backlog skill) are updated to match.

**Read these first:** `plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md` (exit-verb grammar), `plugins/cogniva-dev/skills/backlog/SKILL.md`, `docs/glossary/README.md` (Backlog / Backlog stub / Status entries).

## File structure (locked)

```
plugins/cogniva-dev/skills/groom-backlog/SKILL.md            # flow only: scope, scan, present, gate, apply, deep offer
plugins/cogniva-dev/skills/groom-backlog/GROOMING-CRITERIA.md # verdict catalog + evidence standards + edit mechanics
plugins/cogniva-dev/skills/groom-backlog/DEEP-GROOM.md        # opt-in: still-wanted, merge/split, tier/home, size
plugins/cogniva-dev/skills/backlog/SKILL.md                   # modify: append-only → append-by-default wording
plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md          # modify: same relaxation in the Tier-1 resolving section
plugins/cogniva-dev/.claude-plugin/plugin.json                # modify: description mentions groom-backlog
.claude-plugin/marketplace.json                               # modify: cogniva-dev entry description mentions groom-backlog
CLAUDE.md                                                     # modify: cogniva-dev skill list gains groom-backlog
docs/glossary/README.md                                       # modify: add Grooming + Exit verb entries; update Status entry
docs/adr/NNNN-*.md                                            # two new ADRs (numbers scanned at execution time)
```

## Candidate ADRs

### ADR-C1: Backlog grooming is propose-with-receipts, human-confirmed
**Provenance:** Suggested by human
Grooming never edits the backlog unprompted: a read-only scan proposes verdicts, each closure carrying a receipt (the commit, merged feature, or decision that justifies it), presented in two confidence-separated tables — receipt-backed (scan-and-nod) and inferred (needs a decision) — behind ONE confirmation gate. Confirmed verdicts may reword an item in place; capture stays append-by-default and lines are never deleted.
**Write with:** Task 4

### ADR-C2: Heavy skill guidance ships in lazy-loaded companion files
**Provenance:** Suggested by agent
A skill's unavoidable per-session context cost is its frontmatter description — keep it to at most two sentences. The SKILL.md body carries only the flow; bulky guidance lives in companion files read at the step that needs them, and opt-in material sits in its own file so sessions that skip it never load a token of it. This convention applies to future content-heavy skills.
**Write with:** Task 4

## Task 1: Create the groom-backlog skill flow (SKILL.md)

**Files:**
- Create: `plugins/cogniva-dev/skills/groom-backlog/SKILL.md`

- [ ] **Step 1 (create file):** Create `plugins/cogniva-dev/skills/groom-backlog/SKILL.md` with EXACTLY this content:

````markdown
---
name: groom-backlog
description: Use to groom the backlog - an evidence-gathering scan proposes closures (already-done, obsolete, superseded, duplicate) for loose BACKLOG.md items and deferred stubs, and the user confirms everything once before any edit happens. Deep pass (still-wanted?, merge/split, tier/size review) is opt-in; other skills OFFER a groom before backlog-driven work, never run it silently.
---

# Groom Backlog

Reconcile an aging backlog with reality. A read-only scan gathers evidence, the
verdicts are presented in two confidence-separated tables, the user confirms
ONCE, and only then are edits made — using the exit verbs defined in the backlog
skill's `BACKLOG-FORMAT.md`.

Invoke: `/cogniva-dev:groom-backlog [module=<Module>] [deep]`

Read `GROOMING-CRITERIA.md` in this skill's directory BEFORE the scan — it is
the verdict catalog, the evidence each verdict requires, and the edit mechanics.
Do NOT read `DEEP-GROOM.md` unless the deep pass is actually requested (Step 5);
it is deliberately lazy-loaded so ordinary sessions never pay for it.

## Steps

1. **Scope.** Default = every backlog surface in the target repo:
   `docs/plans/BACKLOG.md`, every `docs/plans/<Module>/BACKLOG.md`, and every
   stub folder (`state.md` with `Status: deferred` and no `-plan.md`).
   `module=<Module>` narrows to that Module's file and stubs.

2. **Scan — one read-only subagent.** Spawn ONE general-purpose subagent with:
   the scope list, the absolute path of `GROOMING-CRITERIA.md` to read first,
   and an instruction to return ONLY structured verdicts. The subagent
   inventories every OPEN item, gathers receipts (git log, plan folders and
   their `state.md` statuses, the code itself), and returns one record per
   finding: location, item text, verdict, proposed exit verb + annotation,
   receipt, and confidence (`confirmed` = verifiable receipt, `inferred` =
   judgment call). It edits NOTHING. Items with no finding are not reported.

3. **Present — two tables + flags, ONE gate.**
   - **Table 1 — receipt-backed** (confidence `confirmed`): numbered; item,
     verdict, receipt. The user should be able to scan and nod.
   - **Table 2 — needs a decision** (confidence `inferred`): numbering
     continues from Table 1; item, proposed verdict, the reasoning, and the
     open question (e.g. which of a conflicting pair survives).
   - **Flags — no edit proposed:** `actionable-now` items (dependency landed —
     point at `/cogniva-dev:plan-feature` or `/cogniva-dev:quick-fix`) and
     `cryptic` items (ask the user what they meant).
   Then ask once: apply Table 1 as-is? Table 2 by number. Nothing is edited
   before this reply.

4. **Apply — only what was confirmed.** Follow the edit mechanics in
   `GROOMING-CRITERIA.md`: tick-and-annotate loose lines, flip stub `state.md`
   statuses, reword items in place where that was the confirmed verdict, and
   add remainder/merged items via `/cogniva-dev:backlog`. Respect the repo's
   primary-edit guard: loose `BACKLOG.md` edits are exempt (direct); stub
   `state.md` edits are NOT — in a guard-opted repo batch them through ONE
   `/cogniva-dev:quick-fix`. Report one line per applied verdict.

5. **Deep pass — opt-in only.** If invoked with `deep`, or the user asks after
   seeing the standard results, read `DEEP-GROOM.md` and follow it. Otherwise,
   when the standard pass suggests restructuring would pay (many survivors,
   several near-miss duplicates), offer it in one sentence and stop.

## Called by another skill

A skill that wants a groomed backlog (e.g. a future easy-work scan) must OFFER
the groom — "want me to groom the backlog first?" — and invoke
`/cogniva-dev:groom-backlog [module=<Module>]` only on a yes. Never auto-groom
as a silent pre-step: whether a groom is worth doing is the user's call (they
know when they last ran one).

## Rules

- No edit of any kind before the Step 3 confirmation — the scan is read-only
  and the gate is mandatory even for "obviously done" items.
- Every closure written to a file carries its receipt in the annotation.
- Append-by-default; in-place rewording only as a confirmed verdict; NEVER
  delete or reorder lines; never delete a stub folder.
- Grooming closes and reconciles items only — actually starting surviving work
  (plan-feature / quick-fix) stays with the user.
- Keep it lean: no glossary work, no version bumps, no code changes.
````

- [ ] **Step 2 (verify):** Read the file back; confirm the frontmatter has exactly `name` and `description` keys and the five `## Steps` items, `## Called by another skill`, and `## Rules` sections are present.
- [ ] **Step 3 (validate):** `claude plugin validate .` (run at the worktree root) → expect `Validation passed`.
- [ ] **Step 4 (commit):** `git add plugins/cogniva-dev/skills/groom-backlog/SKILL.md` then `git commit -m "feat(cogniva-dev): add groom-backlog skill flow"`.

## Task 2: Create the grooming criteria catalog (GROOMING-CRITERIA.md)

**Files:**
- Create: `plugins/cogniva-dev/skills/groom-backlog/GROOMING-CRITERIA.md`

- [ ] **Step 1 (create file):** Create `plugins/cogniva-dev/skills/groom-backlog/GROOMING-CRITERIA.md` with EXACTLY this content:

````markdown
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
  in the primary checkout). Stub `state.md` edits are not — in a guard-opted
  repo, batch ALL confirmed stub closures into ONE `/cogniva-dev:quick-fix`
  invocation listing the exact flips.
- **New items** produced by grooming (remainders, merged scope) go through
  `/cogniva-dev:backlog`, so its dedup and placement rules apply.
````

- [ ] **Step 2 (verify):** Read the file back; confirm the six closure verdicts (complete, partially complete, obsolete, superseded, duplicate, conflicting pair), the three flags (actionable-now, cryptic, stale-refs), and the `## Edit mechanics` section are all present.
- [ ] **Step 3 (commit):** `git add plugins/cogniva-dev/skills/groom-backlog/GROOMING-CRITERIA.md` then `git commit -m "feat(cogniva-dev): add grooming criteria catalog"`.

## Task 3: Create the opt-in deep pass (DEEP-GROOM.md)

**Files:**
- Create: `plugins/cogniva-dev/skills/groom-backlog/DEEP-GROOM.md`

- [ ] **Step 1 (create file):** Create `plugins/cogniva-dev/skills/groom-backlog/DEEP-GROOM.md` with EXACTLY this content:

````markdown
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
````

- [ ] **Step 2 (verify):** Read the file back; confirm the four numbered check sections exist and the file ends with the shared-gate sentence.
- [ ] **Step 3 (validate):** `claude plugin validate .` (worktree root) → expect `Validation passed`.
- [ ] **Step 4 (commit):** `git add plugins/cogniva-dev/skills/groom-backlog/DEEP-GROOM.md` then `git commit -m "feat(cogniva-dev): add opt-in deep-groom pass"`.

## Task 4: Wire groom-backlog into the repo surfaces + write ADRs

**Files:**
- Modify: `plugins/cogniva-dev/skills/backlog/SKILL.md`
- Modify: `plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md`
- Modify: `plugins/cogniva-dev/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `CLAUDE.md`
- Modify: `docs/glossary/README.md`
- Create: `docs/adr/NNNN-backlog-grooming-propose-with-receipts.md`, `docs/adr/NNNN-lazy-loaded-skill-companion-files.md`

- [ ] **Step 1 (backlog SKILL.md — relax append-only):** In `plugins/cogniva-dev/skills/backlog/SKILL.md` replace the text `**append-only**: never delete or reorder existing items.` with `**append-by-default**: never delete or reorder existing items (grooming may close or reword them — see the groom-backlog skill).` Then replace the rule line beginning `- Append-only. Never delete or rewrite existing items here — promotion (ticking an` (the full bullet spans three lines, ending `work is actually picked up.`) with this bullet:
  `- Append-by-default. Never delete existing items here — promotion (ticking an item, flipping a stub's ` `` `Status` `` `) is done by ` `` `plan-feature` `` `/` `` `quick-fix` `` ` when the work is picked up; closure and confirmed in-place rewording are done by ` `` `groom-backlog` `` `.`
- [ ] **Step 2 (BACKLOG-FORMAT.md — same relaxation):** In `plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md`, in the paragraph that reads `The status skills only distinguish open (` … `so\nevery verb counts as resolved. Append-only otherwise: never delete or reorder\nexisting lines.`, replace the final sentence (`Append-only otherwise: never delete or reorder existing lines.`) with: `Append-by-default otherwise: a confirmed grooming verdict may reword an open item in place (see the groom-backlog skill), but lines are never deleted or reordered.` Also replace the earlier line `Append-only otherwise: never delete or reorder existing lines.` if it appears a second time anywhere in the file (search to confirm; apply the same replacement).
- [ ] **Step 3 (plugin.json description):** In `plugins/cogniva-dev/.claude-plugin/plugin.json`, replace `deferred work capture (backlog),` with `deferred work capture and grooming (backlog, groom-backlog),` in the `description` value. Do NOT change the `version` field — the bump is offered separately at integration.
- [ ] **Step 4 (marketplace.json description):** In `.claude-plugin/marketplace.json`, in the `cogniva-dev` entry's `description`, replace `auto-doc, backlog, repo-init,` with `auto-doc, backlog, groom-backlog, repo-init,`.
- [ ] **Step 5 (CLAUDE.md skill list):** In `CLAUDE.md`, in the `plugins/cogniva-dev/` bullet under `## Layout`, replace `` `auto-doc`, `backlog`, `` with `` `auto-doc`, `backlog`, `groom-backlog`, ``.
- [ ] **Step 6 (glossary):** In `docs/glossary/README.md`, insert after the `## Backlog stub` entry (after its `_Avoid_` line) these two entries:

````markdown
## Grooming

The evidence-backed review of the [Backlog](#backlog): a read-only scan proposes closures (already-done, obsolete, superseded, duplicate) each with a receipt, the user confirms once, and items are then closed with [Exit verbs](#exit-verb) or reworded in place. Performed by the `groom-backlog` skill; append-by-default, never deletes lines.
_Avoid_: cleanup, pruning, triage

## Exit verb

The `→` annotation that closes a [Backlog](#backlog) line or stub and records why: `planned:` / `done` when picked up, or the grooming verbs `obsolete:`, `superseded-by:`, `merged-into:`, `wont-do:`. Grammar defined in the backlog skill's `BACKLOG-FORMAT.md`.
_Avoid_: resolution marker, status tag
````

  Then in the `## Status` entry, append this sentence to the end of its paragraph (before the `_Avoid_` line): `A deferred stub can also exit the lifecycle via [Grooming](#grooming): ` `` `deferred → obsolete | superseded | wont-do` `` `.`
- [ ] **Step 7 (write ADR: Backlog grooming is propose-with-receipts, human-confirmed):** Scan `docs/adr/` for the next number and write the confirmed candidate ADR-C1 verbatim (see `## Candidate ADRs`) to `docs/adr/NNNN-backlog-grooming-propose-with-receipts.md` per auto-doc's ADR-FORMAT.
- [ ] **Step 8 (write ADR: Heavy skill guidance ships in lazy-loaded companion files):** Same scan; write ADR-C2 verbatim to `docs/adr/NNNN-lazy-loaded-skill-companion-files.md` (number = the one after Step 7's).
- [ ] **Step 9 (validate):** `claude plugin validate .` (worktree root) → expect `Validation passed`.
- [ ] **Step 10 (commit):** `git add plugins/cogniva-dev/skills/backlog/SKILL.md plugins/cogniva-dev/skills/backlog/BACKLOG-FORMAT.md plugins/cogniva-dev/.claude-plugin/plugin.json .claude-plugin/marketplace.json CLAUDE.md docs/glossary/README.md docs/adr/` then `git commit -m "docs(cogniva-dev): wire groom-backlog into repo surfaces, add grooming ADRs"`.
