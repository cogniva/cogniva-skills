// PreToolUse guard (Bash): in the PRIMARY checkout of an opted-in repo, block git
// commands that move/create/delete branches (switch, checkout, branch -d/-m/... or
// create). The shared primary is pinned to the user's branch and shared with parallel
// sessions; switching or checking out there disrupts their tree. Feature work runs in
// a git worktree that new-feature-worktree.ps1 creates already on feature/<slug>.
//
// ALWAYS ALLOWED: non-branch-moving commands; linked worktrees (Claude's sandbox);
// repos not opted in (no .claude/cogniva-dev/ marker). Contract: only ever DENY; on
// any uncertainty or error, ALLOW (never hard-fail a tool because of this hook).
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

// Branch-moving git ops: switch, checkout (any), and branch create/delete/move/copy.
// Plain `git branch` (list) and read flags (-a/-v/...) are NOT matched.
const SWITCH_RE = /\bgit(\s+-C\s+\S+)?\s+(switch\b|checkout\b|branch\s+(--(delete|force|move|copy)\b|-[dDmMcCf]\b|[^-\s]))/;

let raw = '';
process.stdin.on('data', d => (raw += d)).on('end', () => {
  try {
    const input = JSON.parse(raw || '{}');
    const cmd = (input.tool_input || {}).command || '';
    if (!SWITCH_RE.test(cmd)) return allow();

    // Resolve the repo the command targets: an explicit `git -C <path>`, else the hook cwd.
    let dir = input.cwd || process.cwd();
    const m = cmd.match(/git\s+-C\s+("([^"]+)"|'([^']+)'|(\S+))/);
    if (m) dir = m[2] || m[3] || m[4] || dir;
    dir = path.resolve(dir);
    while (dir && !fs.existsSync(dir)) { const up = path.dirname(dir); if (up === dir) break; dir = up; }
    if (!fs.existsSync(dir)) return allow();

    let topo, gitDir, commonRaw;
    try {
      topo = git(dir, 'rev-parse --show-toplevel');
      gitDir = git(dir, 'rev-parse --absolute-git-dir');
      commonRaw = git(dir, 'rev-parse --git-common-dir');
    } catch (e) { return allow(); } // not a git repo

    const commonAbs = path.isAbsolute(commonRaw) ? commonRaw : path.resolve(dir, commonRaw);
    // Linked worktree => git-dir differs from common-dir => ALLOW (Claude's sandbox).
    if (path.resolve(gitDir).toLowerCase() !== path.resolve(commonAbs).toLowerCase()) return allow();

    // Opt-in: only enforce in repos wired with the cogniva worktree workflow.
    if (!fs.existsSync(path.join(topo, '.claude', 'cogniva-dev'))) return allow();

    return deny(
      'Blocked: do not switch/checkout or create/delete/move branches in the shared PRIMARY checkout ' +
      '(it is pinned to your branch and shared with parallel sessions). Feature work runs in its own git ' +
      'worktree - new-feature-worktree.ps1 creates it already on feature/<slug>, and integrate-feature.ps1 ' +
      'fast-forward-merges it back. Use /cogniva-dev:execute-feature or /cogniva-dev:quick-fix, which manage ' +
      'the worktree for you.'
    );
  } catch (e) { return allow(); }
});
