---
name: project-context
description: Provide a high-signal, persistent source of truth for non-technical business context that prevents "context drift" across long sessions and multi-step tasks.
---

# Project Context

Manage the core business logic and vision of the project in `PROJECT-CONTEXT.md`. This is the anchor for "why" we are building features and what rules govern them.

Read `PROJECT-CONTEXT-FORMAT.md` in this skill's directory for the content structure and rules.

Invoke: `/cogniva-skills:project-context [<action>] [<args>]`

## Actions

### `generate` — build a new context from scratch

```
/cogniva-skills:project-context generate
```

**Steps:**

1. **Analysis Phase (Optional):** If requested, scan the repository to extract existing context from requirements, glossaries, and plans. Use these results strictly as a *preparation* for drafting — do not dump raw findings to the user.

2. **Section-by-Section Guided Flow:** Present one section at a time, in this order:

   1. Mission
   2. Stakeholders
   3. Business Rules
   4. Constraints
   5. Success Criteria (optional, include only if the project context supports it)

   For each section:
   - Present a draft based on your analysis (or ask clarifying questions if no analysis was performed)
   - **Pause and ask for feedback** — wait for the user to approve, revise, or skip
   - Do NOT proceed to the next section until the user confirms
   - If the user says "move on", "looks good", or similar, advance to the next section
   - If the user wants to skip a section, note it and move on

3. **Final Assembly:** Once all sections are approved, write the complete `PROJECT-CONTEXT.md` and confirm to the user.

### `update` — update a specific section with new information

```
/cogniva-skills:project-context update <query>
```

**Steps:**
1. **Identify Focus:** Identify the portion of `PROJECT-CONTEXT.md` relevant to the user's input or query.
2. **Merge & Rewrite:** Do not just append. Merge the new information into existing paragraphs while maintaining flow and structure.
3. **Confirmation:** After a successful update, provide a concise diff (e.g., "*Updated [Business Rules]: Added details regarding refund policy*").

## Passive monitoring

During any design, planning, or decision session, watch for:

1. **Decision Conflicts:** When an implementation choice is made that seems to contradict established business rules.
2. **Context Gaps:** When a requirement is being defined but the "why" or "who" (stakeholders) isn't clear from the current context.
3. **Scope Creep:** When new features are proposed that fall outside the core mission as defined in `PROJECT-CONTEXT.md`.

## Rules

- **Source of Truth:** If a contradiction occurs between `PROJECT-CONTEXT.md` and other files (like `REQUIREMENTS.md`), flag it to the user immediately. Do not make assumptions.
- **High Signal Only:** Ensure the document remains focused on "Why" and "Rules", not technical implementation or task management.
- **No Appending Junk:** Use the update logic to ensure the document remains a polished, coherent narrative rather than a list of notes.
- **Proactive Inquiry:** If current context is insufficient for a high-stakes decision, prompt the user: "*The project context doesn't specify [X]. Should I assume a default or would you like to add this to PROJECT-CONTEXT.md?*"
