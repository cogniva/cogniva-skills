// PostToolUse (Write|Edit) adapter for `module-deps -Check`: after a .csproj
// edit, block-with-feedback when the edit leaves a cross-Module dependency
// cycle that docs/architecture/allowed-cycles.txt does not allow.
//
// OPT-IN per repo: acts only when the edited file's repo has
// .claude/cogniva-dev/policy.json with "moduleDepsCheck": true. Every other
// repo is untouched. `module-deps.ps1 -Check` stays callable on its own (git
// hooks, CI, by hand); this hook is only the Claude Code adapter around it.
//
// Contract: only ever BLOCK on a confirmed cycle (-Check exit 1 with a report).
// On any uncertainty or error - not a .csproj, no git, no opt-in, no
// PowerShell, timeout, script error - exit 0 silently.
const { execSync, execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const SCRIPT = path.join(__dirname, '..', 'skills', 'module-deps', 'module-deps.ps1');

function allow() { process.exit(0); }

function optedIn(top) {
  try {
    const text = fs.readFileSync(path.join(top, '.claude', 'cogniva-dev', 'policy.json'), 'utf8');
    const policy = JSON.parse(text.replace(/^\uFEFF/, ''));
    return !!policy && policy.moduleDepsCheck === true;
  } catch (e) { return false; }
}

// Returns the -Check report when a disallowed cycle is confirmed, else null.
function runCheck(top) {
  for (const shell of ['powershell.exe', 'pwsh']) {
    try {
      execFileSync(shell,
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', SCRIPT, '-Check', '-RepoRoot', top],
        { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 90000 });
      return null; // exit 0: no disallowed cycle
    } catch (e) {
      if (e.code === 'ENOENT') continue; // this shell is not installed: try the next
      if (e.status === 1 && e.stdout) return String(e.stdout);
      return null; // timeout, script error, ... -> never hard-fail
    }
  }
  return null;
}

let raw = '';
process.stdin.on('data', d => (raw += d)).on('end', () => {
  try {
    const input = JSON.parse(raw || '{}');
    const fp = (input.tool_input || {}).file_path;
    if (!fp || !/\.csproj$/i.test(fp)) return allow();

    const dir = path.dirname(path.resolve(fp));
    if (!fs.existsSync(dir)) return allow();

    let top;
    try {
      top = execSync(`git -C "${dir}" rev-parse --show-toplevel`, {
        encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
      }).trim();
    } catch (e) { return allow(); } // not a git repo
    if (!top || !optedIn(top) || !fs.existsSync(SCRIPT)) return allow();

    const report = runCheck(top);
    if (!report) return allow();
    process.stdout.write(JSON.stringify({
      decision: 'block',
      reason: 'This .csproj edit leaves a cross-Module dependency cycle (module-deps -Check). ' +
        'Revert or change the ProjectReference so cross-Module references stay acyclic, or - ' +
        'deliberate and reviewed only - add the pair to docs/architecture/allowed-cycles.txt.\n\n' +
        report,
    }));
    process.exit(0);
  } catch (e) { return allow(); }
});
