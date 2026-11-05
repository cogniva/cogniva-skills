// PreToolUse guard (Write|Edit|NotebookEdit; Codex routes apply_patch to the
// same matcher): block ALL direct edits to the PRIMARY checkout of a clone
// running in worktree mode. Every change an agent makes - code, docs, .claude,
// anything - must happen in a git worktree, which fast-forward-merges into your
// branch. This keeps the shared primary checkout's tree clean: no agent lands on
// your branch except via a worktree merge (see docs/adr/0006).
//
// The edited paths come from scripts/hook-input.js: Claude Code's
// file_path/notebook_path, or EVERY path in a Codex apply_patch. The edit is
// denied if ANY of them is guarded; the message names only the guarded ones.
// Shell-mediated writes (a Bash/PowerShell command that writes a file) are not
// seen by this hook - it is a best-effort guardrail, not a guarantee.
//
// ALLOWED in the primary (no worktree) - ONLY gitignored disposable scratch dirs,
// which never appear on your branch so they cannot dirty it:
//   - .explore/**       (explore-idea's brainstorm docs)
//   - .plans-staging/** (general gitignored scratch staging)
// ...plus tier-1 backlog capture, which IS tracked but append-only bookkeeping:
//   - docs/plans/BACKLOG.md and docs/plans/<Module>/BACKLOG.md
//     (deferred stubs' backlog.md, plans, and state.md remain guarded)
// ALWAYS ALLOWED:
//   - any file inside a LINKED worktree (that is where all work belongs)
//   - any clone NOT in worktree mode (no .claude/cogniva-dev.local.json with
//     worktrees: true at the repo root) - lean mode is the default
//
// Contract: only ever DENY a primary-checkout edit; on any uncertainty or
// error, ALLOW (never hard-fail a tool because of this hook).
const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

function git(dir, args) {
  return execSync(`git -C "${dir}" ${args}`, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
}
function allow() { process.exit(0); }
function deny(reason) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: reason },
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
// no paths => this hook stands down (contract: on any uncertainty, allow).
let hookInput;
try { hookInput = require(path.join(__dirname, 'hook-input.js')); }
catch (e) { hookInput = null; }

// Returns abs when it is a guarded PRIMARY-checkout path, else null (linked
// worktree, lean mode, exempt scratch/backlog, not a git repo, or unsure).
function guardedPath(abs) {
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

  // --git-common-dir is relative to the -C dir (where git ran), NOT to topo.
  const commonAbs = path.isAbsolute(commonRaw) ? commonRaw : path.resolve(dir, commonRaw);
  // Linked worktree => git-dir (.../worktrees/<name>) differs from common-dir => ALLOW.
  if (path.resolve(gitDir).toLowerCase() !== path.resolve(commonAbs).toLowerCase()) return null;

  // Opt-in: only enforce in clones running in worktree mode.
  if (!worktreesOn(topo)) return null;

  // We are in the PRIMARY checkout. Allow ONLY gitignored disposable scratch dirs.
  const rel = path.relative(topo, abs).split(path.sep).join('/');
  const first = rel.split('/')[0];
  const exempt = first === '.explore' || first === '.plans-staging';
  if (exempt) return null;

  // Tier-1 backlog capture is exempt: appending a loose item to a BACKLOG.md is
  // append-only bookkeeping, not workflow output, and a worktree round-trip for a
  // one-line append defeats the backlog skill's purpose (see ADR 0006 addendum).
  // Depth is enforced (docs/plans/BACKLOG.md or docs/plans/<Module>/BACKLOG.md)
  // so a deferred stub's docs/plans/<Module>/<Idea>/backlog.md - the same name on
  // a case-insensitive filesystem - stays guarded along with plans and state.md.
  const parts = rel.toLowerCase().split('/');
  const backlogExempt =
    parts[0] === 'docs' && parts[1] === 'plans' &&
    (parts.length === 3 || parts.length === 4) &&
    parts[parts.length - 1] === 'backlog.md';
  if (backlogExempt) return null;

  return abs;
}

let raw = '';
process.stdin.on('data', d => (raw += d)).on('end', () => {
  try {
    if (!hookInput) return allow();
    const paths = hookInput.editedPaths(hookInput.readHookInput(raw));
    if (paths.length === 0) return allow();

    const blocked = [];
    for (const abs of paths) {
      let hit = null;
      try { hit = guardedPath(abs); } catch (e) { hit = null; }
      if (hit) blocked.push(hit);
    }
    if (blocked.length === 0) return allow();

    return deny(
      'Blocked: this is the shared PRIMARY checkout - agents must not edit the primary checkout directly ' +
      '(code, docs, or .claude). Blocked path(s): ' + blocked.join(', ') + '. ' +
      'Every change must go through a git worktree that fast-forward-merges into your branch. ' +
      'Use the quick-fix skill for a small change, or the execute-feature skill for planned work - ' +
      'both create the worktree, integrate, and mark it cleanupable for you (worktree mode requires Claude Code). ' +
      'The ONLY paths editable directly here are gitignored scratch (.explore/**, .plans-staging/**) ' +
      'and tier-1 backlog files (docs/plans/BACKLOG.md, docs/plans/<Module>/BACKLOG.md).'
    );
  } catch (e) { return allow(); }
});
