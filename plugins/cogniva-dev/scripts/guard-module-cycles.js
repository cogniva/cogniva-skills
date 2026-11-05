// PostToolUse (Write|Edit) adapter for `module-deps -Check`: after a .csproj
// edit, return decision "block" - feedback asking Claude to correct it - when
// the edit leaves a cross-Module dependency cycle that
// docs/architecture/allowed-cycles.txt does not allow. PostToolUse runs after
// the file has changed, so this cannot prevent the edit; hard enforcement is
// -Check in a completion gate.
//
// OPT-IN per repo: acts only when the edited file's repo has
// .claude/cogniva-dev/policy.json with "moduleDepsCheck": true. Every other
// repo is untouched. `module-deps.ps1 -Check` stays callable on its own (git
// hooks, CI, by hand); this hook is only the Claude Code adapter around it.
//
// Contract: only ever return "block" on a confirmed cycle (-Check exit 1 with a report).
// On any uncertainty or error - not a .csproj, no git, no opt-in, no
// PowerShell, timeout, script error - exit 0 silently.
const { execFileSync } = require('child_process');
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

// Payload parsing is shared (scripts/hook-input.js): Claude Code's file_path
// or every path in a Codex apply_patch. It also strips the UTF-8 BOM Windows
// PowerShell 5.1 can prefix to piped stdin. A missing/broken lib => silent.
let hookInput;
try { hookInput = require(path.join(__dirname, 'hook-input.js')); }
catch (e) { hookInput = null; }

// The repo top of an opted-in repo holding this .csproj, else null.
function optedInTop(fp) {
  const dir = path.dirname(fp);
  if (!fs.existsSync(dir)) return null;
  let top;
  try {
    // execFileSync, not execSync: the edited path must never pass through a shell.
    top = execFileSync('git', ['-C', dir, 'rev-parse', '--show-toplevel'], {
      encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch (e) { return null; } // not a git repo
  return top && optedIn(top) ? top : null;
}

let raw = '';
process.stdin.on('data', d => (raw += d)).on('end', () => {
  try {
    if (!hookInput || !fs.existsSync(SCRIPT)) return allow();
    const csprojs = hookInput.editedPaths(hookInput.readHookInput(raw)).filter(p => /\.csproj$/i.test(p));
    if (csprojs.length === 0) return allow();

    // One -Check per opted-in repo, however many of its .csproj files the edit touched.
    const tops = [];
    for (const fp of csprojs) {
      const top = optedInTop(fp);
      if (top && !tops.includes(top)) tops.push(top);
    }
    let report = null;
    for (const top of tops) { report = runCheck(top); if (report) break; }
    if (!report) return allow();
    process.stdout.write(JSON.stringify({
      decision: 'block',
      reason: 'This .csproj edit leaves a cross-Module dependency cycle (module-deps -Check). ' +
        'Revert or change the ProjectReference so cross-Module references stay acyclic, or - ' +
        'deliberate and reviewed only - add the whole cycle as one line to docs/architecture/allowed-cycles.txt.\n\n' +
        report,
    }));
    process.exit(0);
  } catch (e) { return allow(); }
});
