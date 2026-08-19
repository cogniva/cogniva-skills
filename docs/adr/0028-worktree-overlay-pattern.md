# Worktree rules live in per-skill WORKTREE.md overlays

**Provenance:** Suggested by human

Each worktree-using skill keeps a lean, mode-independent SKILL.md; its worktree
mechanics live in a sibling WORKTREE.md read only when the per-clone switch is
on, at steps tagged ⟦worktree⟧. Lean invocations never load worktree text; the
guard hooks remain the behavioral backstop, so instruction and enforcement stay
separable.
