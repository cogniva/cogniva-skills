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
    - **Active**: The user asks for this skill by name.
    - **Passive**: Describe the conditions under which the agent should *automatically* initiate or monitor using this skill without being asked.

## Example: Passive Triggering

If your skill is passive, use language like:
*"This skill is a background observer. It should be active whenever you are engaged in [task/phase]."*

## Works on both agent hosts

Every skill ships to Claude Code and OpenAI Codex from the same `SKILL.md`. Before shipping one, check:

- Other skills are named by their bare name (`backlog`), never by one agent host's invocation syntax.
- No agent-host tool (for example the Workflow tool or `apply_patch`) is named without the other agent host's equivalent.
- Steps only one agent host needs live in an overlay file beside `SKILL.md` (for example `CODEX.md`), which the skill reads only on that agent host.
- Explicit-only invocation is set in both places together: `disable-model-invocation: true` in the frontmatter and `policy.allow_implicit_invocation: false` in `agents/openai.yaml`.
- The skill has a row in the parity record (`docs/host-parity.md` in the cogniva-skills repo).
- The green gate passes: `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/cogniva-dev/scripts/run-green-gate.ps1 -Repo .`
