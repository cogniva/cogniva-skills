# Investigation record contract

## Location and identity

Prefer an existing suitable tracked record under repository conventions;
otherwise use `docs/experiments/<kebab-topic>.md`. Identify an investigation by
its path and title, and experiments by stable local IDs such as `E001`. Never
renumber historical entries. Add no registry, mandatory YAML, lifecycle state
file, or database.

Keep summary and history together initially. Split only when size or navigation
makes it useful: retain the original as the summary/index and move meaningful
history into linked files in the same investigation area. Preserve IDs, dates,
corrections, and links. Preview any split and include every accepted move path in
the scoped commit. Use no fixed line-count threshold or automatic migration.

## Current understanding

The current summary is editable synthesis. Update it as conclusions change,
linking supporting and contradicting history entries. Keep remaining uncertainty
visible and possible next experiments explicitly marked as proposals.

Use this adaptable skeleton. Headings and bullets are prompts to compress or omit
when irrelevant, not required fields to fill with boilerplate.

```markdown
# Investigation: <technical question>

## Current understanding
- Question and relevant context:
- Supported findings, with links to history entries:
- Remaining uncertainty and limitations:
- Possible next experiments, clearly marked as proposals:

## Experiment history

### E001 — <short experiment name>
Recorded: <date with timezone when time matters>
Performed: <actual date if known; distinguish retrospective reporting>
- Question / hypothesis, when useful:
- Method and comparison:
- Observations, measurements, and their source:
- Interpretation and limits:
- Evidence references:
```

## Meaningful history

Capture meaningful experiments chronologically by recorded date, with performed
date separately when known. Group trivial iterations when their differences do
not affect interpretation. Mark missing historical details unknown or not
measured without demanding reconstruction. Never backdate recording or fabricate
hypotheses after observing results; label retrospective interpretations.

Preserve failed, inconclusive, and mixed outcomes as well as positive results.
Distinguish user-reported observations from agent-observed results; separate
sources, deductions, and uncertainties. Do not imply that a proposed experiment
ran or that an inaccessible artifact was verified.

## Evidence and corrections

Record enough method and context to interpret the result: relevant code revision,
command or configuration, dataset version and split, denominators and units, and
environment or seed only where they matter and are known. Existing logs, commits,
reports, and allowed artifact locations are references, not material to duplicate.
Note missing or unverified evidence. Prefer stable repository links or safe
artifact identifiers to machine-specific paths.

Corrections explicitly reference the affected experiment ID and state what
changed, why, and when. Keep the original observation recoverable in the document
instead of silently replacing it or relying only on Git history. Do not store
sensitive material merely to preserve an error.

Never access a prohibited location to check a link, copy customer or raw data
into documentation, or stage it as evidence. Prefer approved aggregate or
sanitised evidence and safe identifiers. User instructions and customer-data
boundaries govern both reading and output. If a historical correction would
expose prohibited data, explain the specific conflict and resolve it under
repository policy before writing.

## Acceptance and scoped persistence

Present the exact draft or diff, intended documentation paths, and normal local
commit consequence before acceptance. Acceptance authorizes saving that concrete
documentation and its scoped local commit, subject to explicit no-commit or
separate-confirmation instructions and repository or host constraints. It does
not approve running an experiment. Keep an unaccepted draft in chat or already
authorized scratch. This is an instruction recipe using existing tools, not a new
production helper.

1. **Resolve before the first record write.** Resolve the repository and allowed
   output paths, applicable instructions, branch policy, worktree restrictions,
   and current `HEAD` and branch. A configured `requiredDevelopmentBranchPrefix`
   must match before mutations; never create or switch branches. In a guarded
   primary worktree-mode checkout, keep the draft in chat and explain that
   persistence needs a permitted workspace. In a non-Git repository, accepted
   saving may proceed if allowed, but report automatic committing unavailable.
   Never initialize a repository or configure an identity.

2. **Capture the baseline and exact allowlist.** Capture existing status,
   target-file contents and diffs, and unrelated index state. Every commit path
   must be an explicit literal file inside this repo, excluding restricted, raw,
   or generated experiment data. Never accept a directory, wildcard, pathspec
   magic, repository root, or symlink escape as an implicit file allowlist. A
   partially staged target, pre-existing unaccepted target changes, concurrent
   target edits, unmerged files, or a merge, rebase, or cherry-pick in progress
   prevents the automatic commit: preserve the draft and ask only to resolve the
   concrete overlap. Unrelated dirty or staged files alone do not block.

3. **Preview and recheck.** Show the exact accepted delta and intended paths before
   writing. Pre-existing target changes may join the allowlist only if explicitly
   accepted as part of this concrete draft; otherwise do not absorb them. Recheck
   target content, branch, `HEAD`, and relevant index state before writing,
   staging, and committing to detect concurrent changes. Never reset, stash,
   restore, amend, force, bypass hooks or signing, or change Git configuration to
   make the commit possible.

4. **Write and validate only accepted documentation.** Check its complete delta
   against `HEAD`, links, historical integrity, and
   `git --literal-pathspecs diff --check -- <exact-files>`. Run repository-mandated
   documentation checks; this never grants permission to run an unapproved
   experiment. If a mandatory check itself requires unapproved experiment
   execution or inaccessible data, explain the exact dependency and obtain the
   needed approval instead of silently running or skipping it. Respect host
   execution approval for protected Git metadata; never retry a denied write by
   another mechanism.

5. **Stage and commit the literal files.** For new or accepted files use
   `git --literal-pathspecs add -- <exact-files>`, then
   `git --literal-pathspecs commit --only -m "docs(experiments): <brief accepted finding or design>" -- <exact-files>`
   so unrelated staged changes are excluded. These metasyntactic file lists must
   become explicit quoted file arguments in the actual tool call; never
   interpolate user prose into shell code. For a complex message, use the existing
   session's authorized scratch for a message file and `-F`; never write a temp
   file outside the repo without required permission. Do not use `git-commit.ps1`,
   `git add -A`, or a plain index-wide `git commit` here. Honor a no-commit
   instruction by saving only accepted documentation and reporting it uncommitted.

6. **Verify the actual result.** Inspect the new commit's actual path set and diff
   against the accepted content, and verify unrelated working files and staged
   entries retain their prior content and staging. If a hook or concurrent actor
   changes the result, report it; never automatically amend or erase work. On
   failure leave recoverable changes and report the actual saved, staged, and
   committed state; do not claim success. A no-op draft makes no empty commit.
   Never push. Never turn unrelated index or dirty-tree changes into a request
   for cleanup.
