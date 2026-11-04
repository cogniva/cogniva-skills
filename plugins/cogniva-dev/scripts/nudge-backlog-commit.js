// PostToolUse nudge (Write|Edit; Codex routes apply_patch to the same
// matcher): a tier-1 BACKLOG.md was just written in the PRIMARY checkout and
// left uncommitted. The primary-edit guard deliberately
// EXEMPTS tier-1 backlog capture (docs/plans/BACKLOG.md and
// docs/plans/<Module>/BACKLOG.md) so a one-line append does not need a worktree
// round-trip - but an exempt write still dirties the shared primary tree, and a
// dirty primary is exactly what makes the next integrate-feature run park itself
// as QUEUED_DIRTY. So we remind the caller to close the loop.
//
// The edited paths come from scripts/hook-input.js (Claude Code's file_path /
// notebook_path, or every path in a Codex apply_patch); the nudge names the
// first edited path that qualifies.
//
// ADVISORY ONLY. This hook never denies, never fails the tool, and prints
// NOTHING unless ALL of the following hold for some edited path:
//   1. the edited path is a tier-1 BACKLOG.md (same depth test the guard uses)
//   2. we are in the PRIMARY checkout (a linked worktree is silent)
//   3. worktree mode is on in this clone (.claude/cogniva-dev.local.json with
//      worktrees: true at the repo root); lean mode is the default and silent
//   4. the file is actually dirty (git status --porcelain is non-empty)
// On any uncertainty or error: exit 0, silently. A hook that chatters on
// unrelated writes is worse than no hook.
const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

function git(dir, args) {
  return execSync(`git -C "${dir}" ${args}`, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
}
function quiet() { process.exit(0); }
function nudge(message) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: 'PostToolUse', additionalContext: message },
  }));
  process.exit(0);
}
// Worktree-mode predicate is shared (scripts/worktree-mode.js) so all hooks
// read the switch identically. A missing/broken lib degrades to lean mode =>
// this hook stands down (contract: on any uncertainty, allow).
let worktreesOn;
try { ({ worktreesOn } = require(path.join(__dirname, 'worktree-mode.js'))); }
catch (e) { worktreesOn = () => false; }
// Payload parsing is shared (scripts/hook-input.js). A missing/broken lib =>
// no paths => silent.
let hookInput;
try { hookInput = require(path.join(__dirname, 'hook-input.js')); }
catch (e) { hookInput = null; }

// Returns the repo top when abs is an uncommitted tier-1 backlog file in the
// PRIMARY checkout of a worktree-mode clone, else null.
function dirtyTier1Backlog(abs) {
  // Use the nearest EXISTING ancestor dir so new files in new dirs still resolve a repo.
  let dir = path.dirname(abs);
  while (dir && !fs.existsSync(dir)) { const up = path.dirname(dir); if (up === dir) break; dir = up; }
  if (!fs.existsSync(dir)) return null;

  let topo, gitDir, commonRaw;
  try {
    topo = git(dir, 'rev-parse --show-toplevel');
    gitDir = git(dir, 'rev-parse --absolute-git-dir');
    commonRaw = git(dir, 'rev-parse --git-common-dir');
  } catch (e) { return null; } // not a git repo

  // Tier-1 depth test, IDENTICAL to guard-primary-edit.js's backlogExempt:
  // docs/plans/BACKLOG.md (3) or docs/plans/<Module>/BACKLOG.md (4) only. A
  // deferred stub's docs/plans/<Module>/<Idea>/backlog.md (5) is NOT tier-1.
  const rel = path.relative(topo, abs).split(path.sep).join('/');
  const parts = rel.toLowerCase().split('/');
  const isTier1Backlog =
    parts[0] === 'docs' && parts[1] === 'plans' &&
    (parts.length === 3 || parts.length === 4) &&
    parts[parts.length - 1] === 'backlog.md';
  if (!isTier1Backlog) return null;

  // --git-common-dir is relative to the -C dir (where git ran), NOT to topo.
  const commonAbs = path.isAbsolute(commonRaw) ? commonRaw : path.resolve(dir, commonRaw);
  // Linked worktree => git-dir (.../worktrees/<name>) differs from common-dir.
  // The capture already rides that worktree's commit - nothing to nudge about.
  if (path.resolve(gitDir).toLowerCase() !== path.resolve(commonAbs).toLowerCase()) return null;

  // Opt-in: only nudge in clones running in worktree mode.
  if (!worktreesOn(topo)) return null;

  // Only nudge if the file is genuinely uncommitted right now.
  let status;
  try {
    status = git(topo, `status --porcelain -- "${abs}"`);
  } catch (e) { return null; }
  return status ? topo : null;
}

let raw = '';
process.stdin.on('data', d => (raw += d)).on('end', () => {
  try {
    if (!hookInput) return quiet();
    const paths = hookInput.editedPaths(hookInput.readHookInput(raw));
    for (const abs of paths) {
      let topo = null;
      try { topo = dirtyTier1Backlog(abs); } catch (e) { topo = null; }
      if (!topo) continue;
      return nudge(
        `The tier-1 backlog file ${abs} is now UNCOMMITTED in the PRIMARY checkout. ` +
        'Leaving it dirty blocks the next integrate-feature run, which parks itself as QUEUED_DIRTY ' +
        'until the primary tree is clean. Close the loop now, one of two ways. ' +
        'If this was a DIRECT /cogniva-dev:backlog capture, commit it path-scoped straight away: ' +
        `scripts/git-commit.ps1 -RepoPath "${topo}" -Path "${abs}" -Message "chore(backlog): <what you captured>" ` +
        '- path-scoped so it never sweeps up unrelated uncommitted work. ' +
        'If this was SKILL-INITIATED capture during plan-feature / execute-feature / quick-fix, it does not ' +
        'belong in the primary at all: move the entry into the open worktree\'s copy of the file so it rides ' +
        'that feature\'s commit, and revert the primary back to clean.'
      );
    }
    return quiet();
  } catch (e) { return quiet(); }
});
