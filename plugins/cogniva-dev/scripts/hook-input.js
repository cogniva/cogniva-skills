// Shared hook-input adapter for the cogniva-dev hooks: ONE place that knows
// how each agent host describes a tool call, so every hook reads Claude Code
// and Codex payloads identically.
//   - Claude Code: Write/Edit carry tool_input.file_path, NotebookEdit carries
//     tool_input.notebook_path.
//   - Codex: apply_patch carries the whole patch text (tool_input.command);
//     every "*** Add File: ", "*** Update File: ", "*** Delete File: " and
//     "*** Move to: " line names a path, relative to the payload's cwd. Codex
//     shell calls arrive as tool_name "Bash" with tool_input.command.
// No dependencies. readHookInput THROWS on invalid JSON - callers keep their
// own "on any uncertainty, allow" contract around it.
const path = require('path');

// tool_input fields that may hold apply_patch text. Codex documents `command`;
// `input` and `patch` are accepted in case a surface uses them.
const PATCH_FIELDS = ['command', 'input', 'patch'];
const PATCH_LINE = /^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)$/;
const BEGIN_PATCH = /^\s*\*\*\* Begin Patch\s*$/m;

function readHookInput(raw) {
  const text = String(raw == null ? '' : raw).replace(/^\uFEFF/, '').trim();
  if (!text) return {};
  const parsed = JSON.parse(text);
  return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
}

function isPatchText(value) {
  return typeof value === 'string' && BEGIN_PATCH.test(value);
}

// Every patch text the payload carries (a string field, or an element of an
// array field such as ["apply_patch", "<patch>"]).
function patchTexts(input) {
  const ti = input.tool_input;
  if (typeof ti === 'string') return isPatchText(ti) || input.tool_name === 'apply_patch' ? [ti] : [];
  if (!ti || typeof ti !== 'object') return [];
  const found = [];
  for (const field of PATCH_FIELDS) {
    const value = ti[field];
    if (typeof value === 'string') {
      if (isPatchText(value) || (input.tool_name === 'apply_patch' && found.length === 0)) found.push(value);
    }
    else if (Array.isArray(value)) {
      for (const part of value) if (isPatchText(part)) found.push(part);
    }
  }
  return found;
}

function editedPaths(input) {
  if (!input || typeof input !== 'object') return [];
  const base = typeof input.cwd === 'string' && input.cwd ? input.cwd : process.cwd();
  const raw = [];
  const ti = input.tool_input && typeof input.tool_input === 'object' ? input.tool_input : {};
  if (typeof ti.file_path === 'string' && ti.file_path) raw.push(ti.file_path);
  if (typeof ti.notebook_path === 'string' && ti.notebook_path) raw.push(ti.notebook_path);
  for (const text of patchTexts(input)) {
    for (const line of text.split(/\r?\n/)) {
      const m = line.match(PATCH_LINE);
      if (m && m[1].trim()) raw.push(m[1].trim());
    }
  }
  const seen = new Set();
  const out = [];
  for (const p of raw) {
    const abs = path.resolve(base, p);
    const key = process.platform === 'win32' ? abs.toLowerCase() : abs;
    if (!seen.has(key)) { seen.add(key); out.push(abs); }
  }
  return out;
}

// The shell command a Bash-style call runs, or '' (never a patch text).
function shellCommand(input) {
  if (!input || typeof input !== 'object') return '';
  if (input.tool_name === 'apply_patch') return '';
  const ti = input.tool_input && typeof input.tool_input === 'object' ? input.tool_input : {};
  let cmd = '';
  if (typeof ti.command === 'string') cmd = ti.command;
  else if (Array.isArray(ti.command)) cmd = ti.command.map(String).join(' ');
  return cmd.includes('*** Begin Patch') ? '' : cmd;
}

module.exports = { readHookInput, editedPaths, shellCommand };
