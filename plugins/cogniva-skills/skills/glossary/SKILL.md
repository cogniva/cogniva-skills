---
name: glossary
description: Use for unfamiliar or ambiguous terms, project-specific jargon, or nouns absent from current context. DO NOT search the codebase (grep, file search or file reads) for an unrecognized term before invoking this skill.
---

<when-to-use>

Check activation as described below before moving to Plan or Execution mode.
When active, you MUST use this skill for new, unfamiliar, ambiguous, conflicting,
or confusing terms and requests to clarify their meaning. Scope includes
technical and domain terms, feature names, proper nouns, unfamiliar classes or
libraries, and any noun absent from the current context (files read or memory);
do not narrow it to domain language or assume an unfamiliar term is merely a typo.

</when-to-use>

<what-to-do>

You MUST search the glossary (`docs/glossary/README.md` and its linked topic
files, or the legacy glossary below) for definitions or descriptions whenever
such terminology appears, before searching the codebase, file system (including
grep, glob, file search or file reads), or web for that term. This glossary-first
prerequisite overrides the normal search loop; knowing that a label might name
implementation does not bypass it.
If the term is missing from the glossary, search the relevant code and filesystem
for its definition or usage before asking the human partner. If that search still
does not resolve the meaning, ask for clarification and offer to document the
confirmed meaning rather than guessing. For ambiguous or conflicting terminology,
automatically prompt for clarification using the workflow below.

## Workflows

### 1. Activation Check
At the start of any design, brainstorming, or planning session, check for:
- `docs/glossary/README.md` (the canonical index)
- OR a legacy `CONTEXT.md` / `CONTEXT-MAP.md` (older repos — see Legacy repos)

The skill activates when either exists or the user explicitly mentions using a
glossary. When active, you MUST monitor for relevant information. Otherwise it
provides no guidance and remains inactive for the current task.

### 2. Terminology Monitoring
During any active session, monitor the dialogue and proposed changes for:
- **Ambiguity**: Terms that are vague or could be interpreted in multiple ways (e.g. overlap between concepts).
- **Conflict**: Use of a term that contradicts an existing definition in the glossary.
- **New/Non-obvious terms**: Introduction of important domain terms that have not yet been documented.

### 3. Clarification and Documentation
When a potential issue is detected:
1. **Interrupt unobtrusively**: Briefly pause the flow to ask for clarification.
2. **Seek feedback from your human partner**: Use the agent host's structured question tool, or a plain question, to confirm: *"You mentioned 'X' — does this refer to [Definition A] or [Definition B]? Or should we define it as something new?"*
3. **Update the glossary (propose-then-confirm)**: Consider documenting every
   clarified term, regardless of its type. Draft the entry using
   [GLOSSARY-FORMAT.md](./GLOSSARY-FORMAT.md), get explicit agreement before
   writing, then immediately update the relevant glossary file. Don't batch
   updates — capture each term as soon as it is confirmed.

## Guidelines

- **Be Unobtrusive**: Do not interrupt for trivialities. Only trigger when ambiguity could lead to architectural errors or future confusion.
- **Consistency is key**: Your primary goal is ensuring that everyone (and every future developer) understands exactly what each term means in the context of this project.
- **Conciseness is good**: Definitions should be as concise as possible while still retaining clarity. Longer definitions will waste context and cause your human partner to start ignoring the glossary.
- **Confirmation is acceptable**: If you are unsure whether to record a new term, and there's more than a 5% chance the user will want to add it, you MUST ask the user whether to store it.
- **Link terms in communication**: When you use a defined term in a response, link it to its entry, e.g. `[Module](docs/glossary/README.md#module)`. Every entry is an `## Heading`, so every term has a stable anchor.
- **Keep glossary entries about meaning**: The glossary should be totally devoid of implementation details. Do not treat it as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

</what-to-do>

<supporting-info>

## Domain awareness

During codebase exploration, also look for existing documentation:

### File structure

Most repos have a single glossary:

```
/
├── docs/
│   ├── glossary/
│   │   └── README.md
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

When the domain grows, the index links per-context topic files (contexts usually correspond to Modules):

```
/
├── docs/
│   ├── glossary/
│   │   ├── README.md                 ← index + context map (relationships)
│   │   ├── ordering.md
│   │   └── billing.md
│   └── adr/                          ← system-wide decisions
└── src/
```

Create files lazily — only when you have something to write. If no glossary exists, propose creating `docs/glossary/README.md` when the first term is resolved.

## Legacy repos

Older repos may have a root `CONTEXT.md` (single context) or `CONTEXT-MAP.md` pointing at per-context `CONTEXT.md` files. Treat these as the glossary for lookup purposes, and offer to migrate them to `docs/glossary/README.md` (see [GLOSSARY-FORMAT.md](./GLOSSARY-FORMAT.md)) when you first touch one.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in the glossary, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

</supporting-info>
