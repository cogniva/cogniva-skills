---
name: gate-check
description: Run the repository's canonical mechanical completion gates without taking lifecycle ownership. Read-only except for commands explicitly configured by the target repository's green gate.
---

# Gate Check

Run this after implementation or before external review when the caller needs
the same mechanical evidence used by Cogniva lifecycle workflows, without
creating a plan, branch, worktree, commit, integration, backlog item, or ADR.

`<plugin>` is this plugin's root; `<repo>` is the checkout being checked.
`<target-branch>` defaults to `main` and must be supplied when that is not the
integration target.

Run the canonical implementation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/run-gate-check.ps1" -Repo "<repo>" -TargetBranch "<target-branch>"
```

It reports tree state, AGENTS-first `before-integrate` obligations, ADR
integrity, whitespace checks, and the configured green gate. A dirty tree is a
warning for a pre-commit preview, never a claim that a merge is certified. The
target repository's own green-gate commands may perform configured validation;
this skill itself takes no lifecycle action. Report any obligation requiring
separate lifecycle authority for the human or external orchestrator to satisfy.
If the target branch cannot be resolved, the result is `INCONCLUSIVE` / `NOT
CERTIFIED`, even if the independent checks pass; supply the real integration
target and rerun it.
