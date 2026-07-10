// PreToolUse guard (Write|Edit|NotebookEdit): block ALL direct edits to the
// PRIMARY checkout of an opted-in repo. Every change Claude makes - code, docs,
// .claude, anything - must happen in a git worktree, which fast-forward-merges
// into your branch. This keeps the shared primary checkout's tree clean: Claude
// never lands on your branch except via a worktree merge (see docs/adr/0006).
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
//   - any repo that has not opted in (no .claude/cogniva-dev/ marker at its root)
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

let raw = '';
process.stdin.on('data', d => (raw += d)).on('end', () => {
  try {
    const input = JSON.parse(raw || '{}');
    const ti = input.tool_input || {};
    const fp = ti.file_path || ti.notebook_path;
    if (!fp) return allow();

    const abs = path.resolve(fp);
    // Use the nearest EXISTING ancestor dir so new files in new dirs still resolve a repo.
    let dir = path.dirname(abs);
    while (dir && !fs.existsSync(dir)) { const up = path.dirname(dir); if (up === dir) break; dir = up; }
    if (!fs.existsSync(dir)) return allow();

    let topo, gitDir, commonRaw;
    try {
      topo = git(dir, 'rev-parse --show-toplevel');
      gitDir = git(dir, 'rev-parse --absolute-git-dir');
      commonRaw = git(dir, 'rev-parse --git-common-dir');
    } catch (e) { return allow(); } // not a git repo

    // --git-common-dir is relative to the -C dir (where git ran), NOT to topo.
    const commonAbs = path.isAbsolute(commonRaw) ? commonRaw : path.resolve(dir, commonRaw);
    // Linked worktree => git-dir (.../worktrees/<name>) differs from common-dir => ALLOW.
    if (path.resolve(gitDir).toLowerCase() !== path.resolve(commonAbs).toLowerCase()) return allow();

    // Opt-in: only enforce in repos wired with the cogniva worktree workflow.
    if (!fs.existsSync(path.join(topo, '.claude', 'cogniva-dev'))) return allow();

    // We are in the PRIMARY checkout. Allow ONLY gitignored disposable scratch dirs.
    const rel = path.relative(topo, abs).split(path.sep).join('/');
    const first = rel.split('/')[0];
    const exempt = first === '.explore' || first === '.plans-staging';
    if (exempt) return allow();

    // Tier-1 backlog capture is exempt: appending a loose item to a BACKLOG.md is
    // append-only bookkeeping, not workflow output, and a worktree round-trip for a
    // one-line append defeats the backlog skill's purpose (see ADR 0006 addendum).
    // Depth is enforced (docs/plans/BACKLOG.md or docs/plans/<Module>/BACKLOG.md)
    // so a deferred stub's docs/plans/<Module>/<Idea>/backlog.md — the same name on
    // a case-insensitive filesystem — stays guarded along with plans and state.md.
    const parts = rel.toLowerCase().split('/');
    const backlogExempt =
      parts[0] === 'docs' && parts[1] === 'plans' &&
      (parts.length === 3 || parts.length === 4) &&
      parts[parts.length - 1] === 'backlog.md';
    if (backlogExempt) return allow();

    return deny(
      'Blocked: this is the shared PRIMARY checkout - Claude must NOT edit it directly (code, docs, or .claude). ' +
      'Every change must go through a git worktree that fast-forward-merges into your branch. ' +
      'Use the /cogniva-dev:quick-fix skill for a small change, or /cogniva-dev:execute-feature for planned ' +
      'work - both create the worktree, integrate, and mark it cleanupable for you. ' +
      'The ONLY paths editable directly here are gitignored scratch (.explore/**, .plans-staging/**) ' +
      'and tier-1 backlog files (docs/plans/BACKLOG.md, docs/plans/<Module>/BACKLOG.md).'
    );
  } catch (e) { return allow(); }
});
