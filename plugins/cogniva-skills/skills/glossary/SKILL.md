---
name: glossary
description: Use this tool whenever you encounter an unrecognized term, project-specific jargon, or any noun that does not appear in your current context (files read, memory, or system prompt). DO NOT use Grep, Glob, Read, or any search tool on an unrecognized term before invoking this tool. The glossary is the authoritative source of truth and must be consulted before any codebase exploration. If the term is not found in the glossary, you must ask your human partner for its definition and explicitly offer to document it in `CONTEXT.md`. This skill is the authoritative source of truth for any terminology used in this project.
---

<when-to-use>

The skill only activates if `CONTEXT.md` or `CONTEXT-MAP.md` is found in the repository, or if the user explicitly mentions using a glossary. If any of those are true, you MUST use this skill to watch for relevant information. Otherwise, you should not use this skill and you can ignore the rest of these instructions.

When unfamiliar terminology is used, you MUST use this skill to look for an existing definition before moving to searching the file system. The cognitive loop MUST be `Unrecognised Term -> 'glossary' skill -> Search Filesystem -> Ask User'`. This overrides any standard cognitive loop you might otherwise use in that situation.

You MUST check whether this skill applies before moving to either Plan mode or Execution mode. If there have been any requests to clarify terminology, you MUST use this skill.

Any time your human partner uses an unfamiliar term, whether it appears to be a technical term, a domain term, a feature name, or any sort of proper noun, you MUST first check any applicable 'CONTEXT.md' file to see if that term is defined. DO NOT scan the code or the file system until you've searched 'CONTEXT.md'.

Any time you have searched for an unfamiliar term and asked your human partner for clarification (regardless of what type of term you think it is), you MUST consider adding it to the 'CONTEXT.md' file.

Any time there is any question about the meaning of a particular term, or any ambiguity or confusion that is not already addressed in a 'CONTEXT.md' file, you MUST invoke this skill. If you have asked the user for clarification of a term or phase, you MUST use this skill. If you believe a term is some technical concept you don't recognise (an unfamiliar class, library, etc) you MUST invoke this skill.

</when-to-use>

<what-to-do>

You MUST search 'CONTEXT.md' (if one exists) for definitions or descriptions when new, conflicting, confusing, or ambiguous terminology is used during a session. This MUST be done before searching the file system. This MUST be done before doing a WebSearch.

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
- `CONTEXT.md`
- OR `CONTEXT-MAP.md` (which points to other `CONTEXT.md` files)

If neither is found, this skill provides no guidance and should remain inactive for the current task.

### 2. Terminology Monitoring
During any active session, monitor the dialogue and proposed changes for:
- **Ambiguity**: Terms that are vague or could be interpreted in multiple ways (e. overlap between concepts).
- **Conflict**: Use of a term that contradicts an existing definition in `CONTEXT.md`.
- **New/Non-obvious terms**: Introduction of important domain terms that have not yet been documented.

### 3. Clarification and Documentation
When a potential issue is detected:
1. **Interrupt unobtrusively**: Briefly pause the flow to ask for clarification.
2. **Seek feedback from your human partner**: Use `AskUserQuestion` or direct text to confirm: *"You mentioned 'X' — does this refer to [Definition A] or [Definition B]? Or should we define it as something new?"*
3. **Update the glossary**: Once a definition is agreed upon, immediately update the relevant `CONTEXT.md` file using `Edit` or `Write`.

## Guidelines

- **Be Unobtrusive**: Do not interrupt for trivialities. Only trigger when ambiguity could lead to architectural errors or future confusion.
- **Consistency is key**: Your primary goal is ensuring that everyone (and every future developer) understands exactly what each term means in the context of this project.
- **Conciseness is good**: Definitions should be as concise as possible while still retaining clarity. Longer definitions will waste context and cause your human partner to start ignoring the glossary.
- **Confirmation is acceptable**: If you are unsure whether to record a new term, and there's more than a 5% chance the user will want to add it, you MUST ask the user whether to store it.

</what-to-do>

<supporting-info>

## Domain awareness

During codebase exploration, also look for existing documentation:

### File structure

Most repos have a single context:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `CONTEXT-MAP.md` exists at the root, the repo has multiple contexts. The map points to where each one lives:

```
/
├── CONTEXT-MAP.md
├── docs/
│   └── adr/                          ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   └── docs/adr/                 ← context-specific decisions
│   └── billing/
│       ├── CONTEXT.md
│       └── docs/adr/
```

Create files lazily — only when you have something to write. If no `CONTEXT.md` exists, create one when the first term is resolved.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up — capture them as they happen. Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).

`CONTEXT.md` should be totally devoid of implementation details. Do not treat `CONTEXT.md` as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

</supporting-info>
