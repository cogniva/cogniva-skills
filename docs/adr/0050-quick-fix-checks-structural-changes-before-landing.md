# quick-fix checks structural changes before landing, against a snapshot taken at its start

**Provenance:** Suggested by agent

At its start, quick-fix records the working state as a git tree: tracked,
staged, unstaged and untracked files. Before the ADR check and green gate, it
runs the profile-selected detectors on everything since then. Task commits
and uncommitted work are attributed to the fix; work that was already dirty
is not. Each change is governed by the profile every path it touches has
now, and by the profile that path's marker named at the start, so deleting a
folder together with its marker cannot hide its standards. What those
profiles require is always read from their current text, so a repair clears
on re-check. Any change the fix makes to the profiles themselves needs the
user's OK. Expecting a structural change while scoping only moves the standards
check earlier and hands the tasks the standards' full text. Correctness rests
on the landing check:
- a change nobody expected needs the user's OK;
- a blocked required standard stops landing;
- a failed check lands only on the user's explicit waiver.

Finding a structural change never sends the fix to plan-feature by itself. A
departure from a standard, or a choice the standards leave open, does.
