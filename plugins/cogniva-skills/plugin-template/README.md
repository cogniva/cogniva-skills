# Skill Template

Use this template to create new skills for the repository.

## Structure

Each skill should live in its own directory within the `skills/` folder of the main repository.

```text
skills/<skill-name>/
├── SKILL.md        <-- Metadata and operational logic (THE MOST IMPORTANT)
├── [other-files]  <-- Supporting docs, templates, or data files for this skill
```

## Writing SKILL.md

The `SKILL.md` is the source of truth. It must include:

1.  **Frontmatter**: Name and description.
2.  **Workflow/Logic**: Detailed instructions on how the skill should operate.
3.  **Triggering Logic**: 
    - **Active**: Explicitly call this skill (e.g., `/run-skill`).
    - **Passive**: Describe the conditions under which the agent should *automatically* initiate or monitor using this skill without being asked.

## Example: Passive Triggering

If your skill is passive, use language like:
*"This skill is a background observer. It should be active whenever you are engaged in [task/phase]."*