---
name: glossary-guard
description: You MUST use this skill during any activity that might introduce new or ambiguous terminology. Monitors and maintains a glossary of terms within CONTEXT.md or CONTEXT-MAP.md. Use when detecting terminology conflicts, confusion, or non-obvious terms during design, brainstorming, or planning sessions.
---

<when-to-use>

The skill is passive and only activates if `CONTEXT.md` or `CONTEXT-MAP.md` is found in the repository, or if the user explicitly mentions using a glossary. If any of those are true, this skill must always be used to watch for relevant information.

</when-to-use>

<what-to-do>

It will automatically prompt your human partner for clarification when it detects ambiguous or conflicting terminology during a session.

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
