---
name: glossary
description: Use this tool whenever you encounter an unrecognized term, project-specific jargon, or any noun that does not appear in your current context (files read, memory, or system prompt). DO NOT use Grep, Glob, Read, or any search tool on an unrecognized term before invoking this tool. The glossary is the authoritative source of truth and must be consulted before any codebase exploration. If the term is not found in the glossary, you must ask your human partner for its definition and explicitly offer to document it in the glossary. This skill is the authoritative source of truth for any terminology used in this project.
---

<when-to-use>

The skill only activates if `docs/glossary/README.md` is found in the repository (or a legacy `CONTEXT.md` / `CONTEXT-MAP.md` — see Legacy repos below), or if the user explicitly mentions using a glossary. If any of those are true, you MUST use this skill to watch for relevant information. Otherwise, you should not use this skill and you can ignore the rest of these instructions.

When unfamiliar terminology is used, you MUST use this skill to look for an existing definition before moving to searching the file system. The cognitive loop MUST be `Unrecognised Term -> 'glossary' skill -> Search Filesystem -> Ask User'`. This overrides any standard cognitive loop you might otherwise use in that situation.

You MUST check whether this skill applies before moving to either Plan mode or Execution mode. If there have been any requests to clarify terminology, you MUST use this skill.

Any time your human partner uses an unfamiliar term, whether it appears to be a technical term, a domain term, a feature name, or any sort of proper noun, you MUST first check the glossary to see if that term is defined. DO NOT scan the code or the file system until you've searched the glossary.

Any time you have searched for an unfamiliar term and asked your human partner for clarification (regardless of what type of term you think it is), you MUST consider adding it to the glossary.

Any time there is any question about the meaning of a particular term, or any ambiguity or confusion that is not already addressed in the glossary, you MUST invoke this skill. If you have asked the user for clarification of a term or phrase, you MUST use this skill. If you believe a term is some technical concept you don't recognise (an unfamiliar class, library, etc) you MUST invoke this skill.

</when-to-use>

<what-to-do>

You MUST search the glossary (`docs/glossary/README.md` and any topic files it links) for definitions or descriptions when new, conflicting, confusing, or ambiguous terminology is used during a session. This MUST be done before searching the file system. This MUST be done before doing a WebSearch.

You must automatically prompt your human partner for clarification when you detect ambiguous or conflicting terminology during a session.

## Prerequisite

Before using Grep or Glob on any noun not found in your current context (files read/memory), you must verify its definition via this tool.

## Red Flags
| Thought | Reality |
|---------|---------|
| "I can find this term with Grep/Glob" | This is a violation. Check the glossary first. |
| "Let me search the codebase for implementation" | You don't know if it's terminology or code yet. Use the glossary. |
| "It's probably just a typo in the docs" | Verify with the glossary before assuming. |
| "Let's start by searching" | This is a violation. Check the glossary first. |
| "First I need to understand what [some term] means" | The glossary is the most efficient way to find the answer. |
| "Maybe I should search for" | The glossary is the most efficient way to find the answer. DO NOT invoke a search before checking the glossary. |

## Workflows

### 1. Activation Check
At the start of any design, brainstorming, or planning session, check for the existence of:
- `docs/glossary/README.md` (the canonical index)
- OR a legacy `CONTEXT.md` / `CONTEXT-MAP.md` (older repos — see Legacy repos)

If none is found, this skill provides no guidance and should remain inactive for the current task.

### 2. Terminology Monitoring
During any active session, monitor the dialogue and proposed changes for:
- **Ambiguity**: Terms that are vague or could be interpreted in multiple ways (e.g. overlap between concepts).
- **Conflict**: Use of a term that contradicts an existing definition in the glossary.
- **New/Non-obvious terms**: Introduction of important domain terms that have not yet been documented.

### 3. Clarification and Documentation
When a potential issue is detected:
1. **Interrupt unobtrusively**: Briefly pause the flow to ask for clarification.
2. **Seek feedback from your human partner**: Use `AskUserQuestion` or direct text to confirm: *"You mentioned 'X' — does this refer to [Definition A] or [Definition B]? Or should we define it as something new?"*
3. **Update the glossary (propose-then-confirm)**: Draft the entry, get explicit agreement, then immediately update the relevant glossary file using `Edit` or `Write`. Don't batch updates — capture each term as soon as it is confirmed.

## Guidelines

- **Be Unobtrusive**: Do not interrupt for trivialities. Only trigger when ambiguity could lead to architectural errors or future confusion.
- **Consistency is key**: Your primary goal is ensuring that everyone (and every future developer) understands exactly what each term means in the context of this project.
- **Conciseness is good**: Definitions should be as concise as possible while still retaining clarity. Longer definitions will waste context and cause your human partner to start ignoring the glossary.
- **Confirmation is acceptable**: If you are unsure whether to record a new term, and there's more than a 5% chance the user will want to add it, you MUST ask the user whether to store it.
- **Link terms in communication**: When you use a defined term in a response, link it to its entry, e.g. `[Module](docs/glossary/README.md#module)`. Every entry is an `## Heading`, so every term has a stable anchor.

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

### Update the glossary inline

When a term is resolved and confirmed, update the glossary right there. Don't batch these up — capture them as they happen. Use the format in [GLOSSARY-FORMAT.md](./GLOSSARY-FORMAT.md).

The glossary should be totally devoid of implementation details. Do not treat it as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

</supporting-info>
