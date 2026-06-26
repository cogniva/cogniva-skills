# execute-feature subagents commit and validate JSON via wrapper scripts

**Context.** Claude Code matches each `&&`/`;`/`|` segment of a compound Bash
command against the allowlist; if any segment is unlisted — or the line carries a
multi-line quoted commit message that the matcher can't safely decompose — the
*whole* line prompts. execute-feature subagents emitted `git add ... && git commit
-m "<multi-line>"` and inline `ConvertFrom-Json` one-liners, so already-approved
`git add`/`git commit` kept re-prompting and every JSON check was a unique,
un-allowlistable string.

**Decision.** Subagents commit through a committed, allowlisted
`scripts/git-commit.ps1` wrapper and validate JSON through `scripts/validate-json.ps1`,
instead of hand-rolled `add && commit` chains and inline parsing. The plan/execute
machinery (PLAN-FORMAT, the workflow agent prompt) steers toward these wrappers and
away from `&&`-chained, `cd`-prefixed git commands.

**Why.** A single fixed command prefix (`powershell ... -File ".../git-commit.ps1"`
with `:*` covering the args) is allowlistable once and matches regardless of how
long or multi-line the commit message is — which the raw compound form can never be.
This fixes the re-prompting at the source for every future run, including subagents
that settings changes alone can't reach.
