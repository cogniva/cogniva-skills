---
name: auto-doc
description: You MUST use this any time architectural decisions have been made. Automatically identifies and documents architectural decisions as ADRs in the background. Use when performing brainstorming, design, or early planning work.
---

<what-to-do>
# auto-doc

## Quick start

This skill is a "background observer". It does not require manual invocation during every turn but should be active whenever you are engaged in tasks like `brainstorming`, `writing-plans`, or any design/planning phase.

## <HARD-GATE>
**Do NOT proceed to implementation, write any code, or modify project files unless an architectural decision has been documented or the transition from brainstorming/design is explicitly approved.** 
This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

## Workflows

### 1. Continuous Monitoring
While participating in design, brainstorming, or planning sessions, continuously evaluate all finalized decisions against these criteria:
- **Hard to reverse**: The cost of changing it later is meaningful.
- **Surprising without context**: A future reader would wonder "why did they do it this way?".
- **Result of a real trade-off**: There were genuine alternatives and a choice was made for specific reasons.

### 2. Automatic ADR Creation
When a decision meets the criteria above, perform the following steps immediately:
1. **Identify the next number**: Scan `docs/adr/` (or context-specific `docs/adr/`) to find the highest existing sequential number and increment it.
2. **Generate the content**: Use a concise format based on [ADR-FORMAT.md](./ADR-FORMAT.md). Focus on:
   - A short, descriptive title.
   - 1-3 sentences covering context, decision, and why (the rationale).
3. **Write the file**: Create the new `.md` file in the appropriate directory (e.g., `docs/adr/0003-use-postgresql.md`). Use the lazy creation pattern: if the directory doesn't exist, create it.
4. **Do not batch**: Write the ADR as soon as the decision is finalized. Do not wait for the end of a session or a "batching" phase.

### 3. Quiet Operation
**Crucial**: Your primary goal is to support the human partner without interrupting their cognitive flow. 
- **Avoid prompt fatigue**: Do *not* ask the user for permission to create an ADR.
- **Minimize noise**: Only mention that an ADR was created if it's relevant to the current conversation or if you are summarizing your actions at a natural breaking point (e.g., end of a task). 
- **Silent execution is preferred**: If the decision is clear and you can write it without ambiguity, just do it.
</what-to-do>

## Advanced features
See [ADR-FORMAT.md](./ADR-FORMAT.md) for more on what qualifies as an ADR.