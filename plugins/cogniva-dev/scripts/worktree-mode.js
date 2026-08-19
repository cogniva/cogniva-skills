// Shared mode predicate for the cogniva-dev hooks. ONE place that knows how a
// clone opts into worktree mode, so a wording/format change cannot silently
// diverge between hooks ("oops forgot that check").
//
// Worktree mode is a per-clone opt-in: untracked .claude/cogniva-dev.local.json
// with {"worktrees": true}. Absent/false/unreadable => lean mode => every
// caller stands down (contract: on any uncertainty, allow).
const path = require('path');
const fs = require('fs');

function worktreesOn(topo) {
  try {
    const cfg = JSON.parse(fs.readFileSync(path.join(topo, '.claude', 'cogniva-dev.local.json'), 'utf8'));
    return !!cfg && cfg.worktrees === true;
  } catch (e) { return false; }
}

module.exports = { worktreesOn };
