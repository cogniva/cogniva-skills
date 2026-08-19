# Worktree mode is a per-clone opt-in via an untracked config file

**Provenance:** Suggested by human

Worktree enforcement and worktree skill behavior are controlled per clone by
untracked `.claude/cogniva-dev.local.json` (`{"worktrees": true}`), defaulting
to OFF — lean, direct-on-branch operation. The tracked `.claude/cogniva-dev/`
directory is no longer a mode switch; it remains the home of tracked repo
config (`green-gate.json`, which applies in both modes). Chosen so devs who
never use worktrees pay no worktree cost, on any repo, without per-repo
negotiation.
