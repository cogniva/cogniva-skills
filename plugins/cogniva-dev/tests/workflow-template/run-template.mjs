// Runs templates/execute-feature.workflow.js in plain Node with stubbed
// Workflow globals, so its dispatch logic and the prompts it builds can be
// tested without the Workflow runtime. The template is evaluated as an
// AsyncFunction body after its one module statement, `export const meta`, is
// turned into a plain `const`.
//
// Exported API (other suites reuse it):
//   DEFAULT_TEMPLATE
//       Absolute path of plugins/cogniva-dev/templates/execute-feature.workflow.js.
//   loadTemplateSource(templatePath = DEFAULT_TEMPLATE) -> string
//       The source with `export const meta` made a plain `const`. Throws if
//       that statement is missing or the template has any other top-level
//       import/export (the harness could not evaluate it faithfully).
//   runTemplate({ args, results = {}, argsAsString = false, templatePath = DEFAULT_TEMPLATE }) -> Promise<Run>
//       Evaluates the template with injected globals `args`, `phase`, `log`
//       and `agent`. `results` maps a task tag - 'task-<n>', or
//       '<subplan>/task-<n>' for a sub-plan task - to what `agent` returns for
//       that task (an object, or null). A tag with no entry returns
//       { status: 'DONE', summary: 'ok' }. `argsAsString` passes `args` as a
//       JSON string, as some Workflow runtimes do.
//       Run = { returned, calls: [{ label, phase, prompt, schema }], logs: [string], phases: [string] }
//       `returned` is the template's return value; `calls` are the agent
//       dispatches in order, each with the prompt and the result schema passed.
//   renderPrompts(args, templatePath = DEFAULT_TEMPLATE) -> Promise<string[]>
//       The prompts the template builds, in dispatch order, when every task
//       returns DONE (a gate task still ends the run after it).
// CLI: node run-template.mjs <case.json>
//   case.json = { args, results?, argsAsString?, templatePath? }. Prints the Run
//   as JSON and exits 0, or prints { "error": "<message>" } and exits 1.
import { readFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const DEFAULT_TEMPLATE = fileURLToPath(new URL('../../templates/execute-feature.workflow.js', import.meta.url));
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;

export function loadTemplateSource(templatePath = DEFAULT_TEMPLATE) {
  const raw = readFileSync(templatePath, 'utf8').replace(/^﻿/, '');
  const exportMeta = /^export\s+const\s+meta\b/m;
  if (!exportMeta.test(raw)) throw new Error('template has no "export const meta" statement');
  const source = raw.replace(exportMeta, 'const meta');
  if (/^\s*(import|export)\b/m.test(source)) throw new Error('template has a module statement other than "export const meta"; the harness cannot evaluate it');
  return source;
}

export async function runTemplate({ args, results = {}, argsAsString = false, templatePath = DEFAULT_TEMPLATE } = {}) {
  const calls = [];
  const logs = [];
  const phases = [];
  const agent = async (prompt, opts = {}) => {
    calls.push({ label: opts.label, phase: opts.phase, prompt, schema: opts.schema ?? null });
    if (Object.prototype.hasOwnProperty.call(results, opts.label)) return results[opts.label];
    return { status: 'DONE', summary: 'ok' };
  };
  const body = new AsyncFunction('args', 'phase', 'log', 'agent', loadTemplateSource(templatePath));
  const returned = await body(
    argsAsString ? JSON.stringify(args) : args,
    title => { phases.push(String(title)); },
    message => { logs.push(String(message)); },
    agent,
  );
  return { returned, calls, logs, phases };
}

export async function renderPrompts(args, templatePath = DEFAULT_TEMPLATE) {
  const run = await runTemplate({ args, templatePath });
  return run.calls.map(c => c.prompt);
}

const invokedDirectly = !!process.argv[1] && import.meta.url.toLowerCase() === pathToFileURL(process.argv[1]).href.toLowerCase();
if (invokedDirectly) {
  try {
    const kase = JSON.parse(readFileSync(process.argv[2], 'utf8').replace(/^﻿/, ''));
    const run = await runTemplate({
      args: kase.args,
      results: kase.results ?? {},
      argsAsString: !!kase.argsAsString,
      templatePath: kase.templatePath ?? DEFAULT_TEMPLATE,
    });
    process.stdout.write(JSON.stringify(run));
  } catch (e) {
    process.stdout.write(JSON.stringify({ error: String((e && e.message) || e) }));
    process.exitCode = 1;
  }
}
