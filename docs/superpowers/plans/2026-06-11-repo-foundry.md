# repo-foundry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `repo-foundry` Claude Code plugin (local marketplace) with `repo-init`, `add-module`, and `plan-to-html` skills, a PostToolUse hook that auto-generates HTML twins of plans/specs, and the repo's strategy doc.

**Architecture:** This repo is a local plugin marketplace (`cogniva`) holding one plugin. The plan-to-html pipeline is: PostToolUse hook (PowerShell, stdin JSON) → path filter → `convert-plan.ps1` → single self-contained HTML (vendored marked.js/mermaid.js inlined, client-side rendering, glossary auto-links with in-page appendix). Skills are instruction documents; templates seed new repos. See the approved spec: `docs/superpowers/specs/2026-06-11-repo-foundry-design.md`.

**Tech Stack:** Claude Code plugins (marketplace.json/plugin.json/hooks.json/SKILL.md), Windows PowerShell 5.1 scripts, marked.js v12 + mermaid.js v10 (vendored), plain-PowerShell test harness (no Pester — see Spec deviations), dotnet CLI (referenced by skills, not used in this repo).

**Execution notes:**
- Working dir is `c:\WorkingGit\NewRepo`. Shell commands shown as `bash` run via the Bash tool (curl/git work); PowerShell scripts must run as `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>`. If the permission classifier denies `powershell.exe`, STOP and ask the user to add an allow rule like `Bash(powershell.exe *)` — do not work around it.
- Windows PowerShell is 5.1: no `ConvertFrom-Markdown`, no `pwsh`-only syntax. Scripts below are 5.1-compatible.
- **Spec deviations (intentional, synced to spec in Task 10):**
  1. Watched paths add `docs/superpowers/plans/` (superpowers saves plans there; spec only listed `docs/plans/`).
  2. Tests use a plain PowerShell assertion script instead of Pester (Windows 10 ships Pester 3.4; Pester 3 vs 5 syntax is incompatible — a dependency-free script avoids version hell).
  3. Glossary links in generated HTML point to an **in-page glossary appendix** (terms + definitions embedded in the HTML) rather than the `.md` file, because browsers render raw markdown as plain text. Self-contained stays self-contained.

---

### Task 1: Repo skeleton, marketplace + plugin manifests

**Files:**
- Modify: `.claude-plugin/marketplace.json` (exists — holds the `cogniva-skills` entry)
- Create: `plugins/repo-foundry/.claude-plugin/plugin.json`
- Create: `.gitattributes`
- Create: `README.md`

- [ ] **Step 1: Create `.gitattributes`** (stops the CRLF warnings; keeps vendored minified JS byte-exact)

```
* text=auto
*.min.js -text
*.ps1 text eol=crlf
```

- [ ] **Step 2: Add the repo-foundry entry to `.claude-plugin/marketplace.json`** — append to the existing `plugins` array, keeping the `cogniva-skills` entry untouched. Target state:

```json
{
  "name": "cogniva",
  "owner": {
    "name": "Cogniva",
    "email": "tools@cogniva.ca"
  },
  "plugins": [
    {
      "name": "cogniva-skills",
      "source": "./plugins/cogniva-skills",
      "description": "Skills used internally at Cogniva",
      "version": "0.2.0",
      "author": {
        "name": "Cogniva"
      }
    },
    {
      "name": "repo-foundry",
      "source": "./plugins/repo-foundry",
      "description": "Repo setup toolkit: scaffold Module-based .NET repos, add Modules, and auto-generate HTML twins of plans/specs"
    }
  ]
}
```

- [ ] **Step 3: Create `plugins/repo-foundry/.claude-plugin/plugin.json`**

```json
{
  "name": "repo-foundry",
  "description": "Scaffolds .NET repos with Module (vertical slice) architecture, seeds glossaries, and converts plans/specs to self-contained HTML",
  "version": "0.1.0",
  "author": {
    "name": "Cogniva"
  }
}
```

- [ ] **Step 4: Create `README.md`**

```markdown
# Cogniva — shared tooling marketplace

Cogniva's Claude Code plugin marketplace (`cogniva`). Two plugins: **cogniva-skills** and **repo-foundry**.

| Piece | Purpose |
|---|---|
| `plugins/cogniva-skills/skills/glossary` | Glossary lookup (docs/glossary) before codebase search |
| `plugins/cogniva-skills/skills/auto-doc` | Auto-document architectural decisions as ADRs |
| `plugins/cogniva-skills/plugin-template` | Starter template for new skills |
| `plugins/repo-foundry/skills/repo-init` | Scaffold a brand-new Module-architecture .NET repo |
| `plugins/repo-foundry/skills/add-module` | Add a Module (vertical slice) to an existing repo |
| `plugins/repo-foundry/skills/plan-to-html` | Convert a markdown plan/spec to self-contained HTML |
| `plugins/repo-foundry/hooks` | Auto-regenerate HTML twins when plans/specs are written |
| `docs/strategy.md` | Conventions + tooling decisions |
| `docs/glossary/README.md` | Canonical glossary (architecture terms) |

## Install into any repo

In Claude Code, from the consuming repo (local path or `cogniva/cogniva-skills` from GitHub):

```
/plugin marketplace add c:\WorkingGit\NewRepo
/plugin install repo-foundry@cogniva
/plugin install cogniva-skills@cogniva
```

Then run the `repo-init` skill in an empty repo, or `add-module` in an existing one.

## Develop

Tests: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1`
Validate plugin: `claude plugin validate .`
```

- [ ] **Step 5: Validate the manifests**

Run: `claude plugin validate .`
Expected: validation passes (exit 0). If the subcommand is unavailable in the installed CLI version, fall back to checking both JSON files parse: `git hash-object .claude-plugin/marketplace.json` succeeding only proves existence, so instead run `node -e "JSON.parse(require('fs').readFileSync('.claude-plugin/marketplace.json','utf8')); JSON.parse(require('fs').readFileSync('plugins/repo-foundry/.claude-plugin/plugin.json','utf8')); console.log('ok')"` — Expected: `ok`. If node is also unavailable, Read both files and visually confirm valid JSON.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: marketplace + plugin manifests for repo-foundry"
```

---

### Task 2: Vendor marked.js and mermaid.js

**Files:**
- Create: `plugins/repo-foundry/vendor/marked.min.js`
- Create: `plugins/repo-foundry/vendor/mermaid.min.js`

- [ ] **Step 1: Download pinned versions**

```bash
curl -fsSL -o plugins/repo-foundry/vendor/marked.min.js https://cdn.jsdelivr.net/npm/marked@12.0.2/marked.min.js
curl -fsSL -o plugins/repo-foundry/vendor/mermaid.min.js https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.min.js
```

- [ ] **Step 2: Verify downloads are real libraries, not error pages**

Run: `wc -c plugins/repo-foundry/vendor/marked.min.js plugins/repo-foundry/vendor/mermaid.min.js`
Expected: marked ≈ 39,000–60,000 bytes; mermaid ≈ 1,500,000–3,500,000 bytes.
Run: `head -c 200 plugins/repo-foundry/vendor/marked.min.js`
Expected: JS source (license banner or minified code), NOT HTML (`<!DOCTYPE`).

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: vendor marked 12.0.2 and mermaid 10.9.1 for offline HTML output"
```

---

### Task 3: HTML template for generated plans

**Files:**
- Create: `plugins/repo-foundry/templates/plan-html/template.html`

The converter replaces these placeholders: `{{TITLE}}`, `{{GENERATED}}`, `{{MARKED_JS}}`, `{{MERMAID_JS}}` (empty string when the source has no mermaid block), `{{MARKDOWN_JSON}}` (JSON-encoded source markdown), `{{TERMS_JSON}}` (JSON array of `{term, anchor, definition}`).

- [ ] **Step 1: Create the template** (full content below — CSS matches the approved design-preview style)

`````html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{{TITLE}}</title>
<style>
  :root {
    --bg: #ffffff; --fg: #1f2328; --muted: #59636e; --border: #d1d9e0;
    --accent: #0969da; --code-bg: #f6f8fa;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0d1117; --fg: #e6edf3; --muted: #9198a1; --border: #3d444d;
      --accent: #4493f8; --code-bg: #161b22;
    }
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--fg);
    font-family: -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    font-size: 16px; line-height: 1.6; }
  main { max-width: 52rem; margin: 0 auto; padding: 2rem 1.5rem 5rem; }
  header.doc { border-bottom: 1px solid var(--border); padding-bottom: 1.25rem; margin-bottom: 1.5rem; }
  h1 { font-size: 1.9rem; line-height: 1.25; margin: 0 0 .5rem; }
  h2 { font-size: 1.35rem; margin-top: 2rem; }
  h3 { font-size: 1.05rem; margin-top: 1.5rem; }
  a { color: var(--accent); text-decoration: none; }
  a:hover { text-decoration: underline; }
  a.glossary-link { border-bottom: 1px dotted var(--accent); }
  pre { background: var(--code-bg); border: 1px solid var(--border); border-radius: 8px;
    padding: 1rem; overflow-x: auto; font-size: .85rem; line-height: 1.5; }
  code { font-family: ui-monospace, SFMono-Regular, "Cascadia Code", Consolas, monospace; }
  p code, li code, td code, summary code { background: var(--code-bg); border: 1px solid var(--border);
    border-radius: 4px; padding: .1em .35em; font-size: .85em; }
  table { border-collapse: collapse; width: 100%; margin: 1rem 0; font-size: .92rem; }
  th, td { border: 1px solid var(--border); padding: .45rem .7rem; text-align: left; vertical-align: top; }
  th { background: var(--code-bg); }
  pre.mermaid { background: transparent; border: none; text-align: center; }
  details { border: 1px solid var(--border); border-radius: 8px; padding: 0 1rem; margin: 1rem 0; }
  details[open] { padding-bottom: .5rem; }
  summary { cursor: pointer; font-size: 1.25rem; font-weight: 600; padding: .6rem 0; }
  #glossary-appendix { margin-top: 3rem; border-top: 2px solid var(--border); padding-top: 1rem; }
  #glossary-appendix dt { font-weight: 700; margin-top: 1rem; }
  #glossary-appendix dd { margin-left: 0; color: var(--fg); }
  footer { margin-top: 3.5rem; padding-top: 1rem; border-top: 1px solid var(--border);
    font-size: .85rem; color: var(--muted); }
  input[type=checkbox] { accent-color: var(--accent); }
  blockquote { border-left: 4px solid var(--accent); background: var(--code-bg);
    margin: 1.25rem 0; padding: .75rem 1rem; border-radius: 0 8px 8px 0; }
  @media print { body { font-size: 11pt; } details { border: none; padding: 0; } }
</style>
</head>
<body>
<main>
  <header class="doc">
    <h1 id="doc-title">{{TITLE}}</h1>
  </header>
  <article id="content"></article>
  <section id="glossary-appendix" hidden>
    <h2>Glossary</h2>
    <dl id="glossary-list"></dl>
  </section>
  <footer>generated {{GENERATED}} by repo-foundry plan-to-html</footer>
</main>
<script>{{MARKED_JS}}</script>
<script>{{MERMAID_JS}}</script>
<script>
"use strict";
var SOURCE_MARKDOWN = {{MARKDOWN_JSON}};
var GLOSSARY_TERMS = {{TERMS_JSON}};

var article = document.getElementById('content');
article.innerHTML = marked.parse(SOURCE_MARKDOWN);

// Drop the first H1 if it duplicates the page title
var firstH1 = article.querySelector('h1');
var docTitle = document.getElementById('doc-title');
if (firstH1 && firstH1.textContent.trim() === docTitle.textContent.trim()) firstH1.remove();

// GitHub-style slug ids on headings (marked v12 does not emit ids)
function slugify(text) {
  return text.toLowerCase().trim()
    .replace(/[^\w\s-]/g, '').replace(/\s+/g, '-');
}
article.querySelectorAll('h1, h2, h3, h4').forEach(function (h) {
  if (!h.id) h.id = slugify(h.textContent);
});

// Mermaid: marked renders ```mermaid as code.language-mermaid; convert to pre.mermaid
article.querySelectorAll('code.language-mermaid').forEach(function (code) {
  var holder = document.createElement('pre');
  holder.className = 'mermaid';
  holder.textContent = code.textContent;
  code.parentElement.replaceWith(holder);
});

// Collapsible h2 sections (expanded by default); pre-h2 content goes in #preamble
(function wrapSections() {
  var nodes = Array.prototype.slice.call(article.childNodes);
  var frag = document.createDocumentFragment();
  var preamble = document.createElement('div');
  preamble.id = 'preamble';
  frag.appendChild(preamble);
  var current = null;
  nodes.forEach(function (node) {
    if (node.nodeType === 1 && node.tagName === 'H2') {
      current = document.createElement('details');
      current.open = true;
      var summary = document.createElement('summary');
      summary.innerHTML = node.innerHTML;
      summary.id = node.id;
      current.appendChild(summary);
      frag.appendChild(current);
    } else if (current) {
      current.appendChild(node);
    } else {
      preamble.appendChild(node);
    }
  });
  article.innerHTML = '';
  article.appendChild(frag);
})();

// Render mermaid AFTER section wrapping so layout is final
if (typeof mermaid !== 'undefined' && document.querySelector('pre.mermaid')) {
  mermaid.initialize({
    startOnLoad: false,
    theme: window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default'
  });
  mermaid.run({ querySelector: 'pre.mermaid' });
}

// Glossary auto-linking: first whole-word occurrence per section, case-insensitive
var usedTerms = new Set();
function escapeRegex(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
function linkTermsIn(scope) {
  GLOSSARY_TERMS.forEach(function (t) {
    var re = new RegExp('\\b(' + escapeRegex(t.term) + ')\\b', 'i');
    var walker = document.createTreeWalker(scope, NodeFilter.SHOW_TEXT, {
      acceptNode: function (n) {
        return n.parentElement.closest('a, code, pre, summary, h1, h2, h3, h4')
          ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
      }
    });
    var node;
    while ((node = walker.nextNode())) {
      var m = node.nodeValue.match(re);
      if (m) {
        var a = document.createElement('a');
        a.href = '#glossary-' + t.anchor;
        a.className = 'glossary-link';
        a.title = t.definition.replace(/\s+/g, ' ').slice(0, 240);
        a.textContent = m[1];
        var after = node.splitText(m.index);
        after.nodeValue = after.nodeValue.slice(m[1].length);
        node.parentNode.insertBefore(a, after);
        usedTerms.add(t.anchor);
        break;
      }
    }
  });
}
linkTermsIn(document.getElementById('preamble'));
article.querySelectorAll(':scope > details').forEach(function (d) { linkTermsIn(d); });

// In-page glossary appendix for every term actually referenced
if (usedTerms.size > 0) {
  var list = document.getElementById('glossary-list');
  GLOSSARY_TERMS.forEach(function (t) {
    if (!usedTerms.has(t.anchor)) return;
    var dt = document.createElement('dt');
    dt.id = 'glossary-' + t.anchor;
    dt.textContent = t.term;
    var dd = document.createElement('dd');
    dd.innerHTML = marked.parse(t.definition);
    list.appendChild(dt);
    list.appendChild(dd);
  });
  document.getElementById('glossary-appendix').hidden = false;
}
</script>
</body>
</html>
`````

Note: `linkTermsIn(article)` walks the whole article including `details` contents, so a term used in the preamble AND inside a section gets the preamble link plus per-section links — that satisfies "first occurrence per section". `usedTerms` dedupes the appendix.

- [ ] **Step 2: Sanity check**

Run: `grep -c "{{" plugins/repo-foundry/templates/plan-html/template.html`
Expected: `7` (six distinct placeholders; `{{TITLE}}` appears on two lines).

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: self-contained HTML template for plan rendering"
```

---

### Task 4: Converter script with tests (TDD)

**Files:**
- Create: `tests/fixtures/sample-plan.md`
- Create: `tests/fixtures/no-mermaid.md`
- Create: `tests/fixtures/glossary.md`
- Create: `tests/run-tests.ps1`
- Create: `plugins/repo-foundry/scripts/convert-plan.ps1`

- [ ] **Step 1: Create fixture `tests/fixtures/sample-plan.md`**

`````markdown
# Sample Plan

This plan touches the Orders Module and its Contracts surface.

## First Section

| Col A | Col B |
|---|---|
| 1 | 2 |

```html
<script>alert('x')</script>
```

## Diagram

```mermaid
graph TD
  A --> B
```
`````

- [ ] **Step 2: Create fixture `tests/fixtures/no-mermaid.md`**

```markdown
# Tiny Plan

## Only Section

Just text, no diagrams.
```

- [ ] **Step 3: Create fixture `tests/fixtures/glossary.md`**

```markdown
# Glossary

## Module

A vertical slice of a system containing its own layers.

## Contracts

A Module's pure public surface.
```

- [ ] **Step 4: Create `tests/run-tests.ps1`** (converter tests now; hook tests arrive in Task 5)

```powershell
$ErrorActionPreference = 'Stop'
$repoRoot  = Split-Path -Parent $PSScriptRoot
$converter = Join-Path $repoRoot 'plugins\repo-foundry\scripts\convert-plan.ps1'
$hook      = Join-Path $repoRoot 'plugins\repo-foundry\scripts\plan-to-html-hook.ps1'
$fixtures  = Join-Path $PSScriptRoot 'fixtures'
$work      = Join-Path $env:TEMP ('repo-foundry-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

$script:failures = 0
function Assert([bool]$condition, [string]$name) {
    if ($condition) { Write-Host "PASS: $name" -ForegroundColor Green }
    else { Write-Host "FAIL: $name" -ForegroundColor Red; $script:failures++ }
}

# --- converter tests -------------------------------------------------------
Copy-Item (Join-Path $fixtures 'sample-plan.md') $work
Copy-Item (Join-Path $fixtures 'no-mermaid.md') $work
$samplePath = Join-Path $work 'sample-plan.md'
$tinyPath   = Join-Path $work 'no-mermaid.md'

$outPath = & $converter -MarkdownPath $samplePath -GlossaryPath (Join-Path $fixtures 'glossary.md')
Assert (Test-Path $outPath) 'converter creates sibling html'
Assert ($outPath -eq (Join-Path $work 'sample-plan.html')) 'output path is sibling .html'

$html = [System.IO.File]::ReadAllText($outPath, [System.Text.Encoding]::UTF8)
Assert ($html.Contains('<title>Sample Plan</title>')) 'title extracted from first H1'
Assert (-not ($html -match '\{\{[A-Z_]+\}\}')) 'no unreplaced placeholders'
Assert (-not $html.Contains("alert('x')</script>")) 'embedded script tag cannot terminate the inline script block'
Assert (($html.IndexOf([char]92 + 'u003c') -ge 0) -or $html.Contains('<\/')) 'angle brackets escaped in embedded JSON (PS 5.1 emits backslash-u003c)'
Assert ($html.Contains('"term":"Module"')) 'glossary terms embedded'
Assert ($html.Contains('"anchor":"contracts"')) 'glossary anchors slugified'
Assert ($html.Length -gt 500000) 'mermaid lib inlined when source has mermaid block'

$tinyOut  = & $converter -MarkdownPath $tinyPath
$tinyHtml = [System.IO.File]::ReadAllText($tinyOut, [System.Text.Encoding]::UTF8)
Assert ($tinyHtml.Length -lt 500000) 'mermaid lib skipped when no mermaid block'
Assert ($tinyHtml.Contains('"term"') -eq $false -or $tinyHtml.Contains('[]')) 'no glossary -> empty terms array'
Assert (-not ($tinyHtml -match '\{\{[A-Z_]+\}\}')) 'no unreplaced placeholders (no-mermaid)'

# --- summary ---------------------------------------------------------------
Remove-Item -Recurse -Force $work
if ($script:failures -gt 0) { Write-Host "$($script:failures) test(s) FAILED" -ForegroundColor Red; exit 1 }
Write-Host 'All tests passed' -ForegroundColor Green
exit 0
```

- [ ] **Step 5: Run tests — verify they fail (converter doesn't exist)**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1`
Expected: non-zero exit; error mentioning `convert-plan.ps1` not found / cannot be run.

- [ ] **Step 6: Create `plugins/repo-foundry/scripts/convert-plan.ps1`**

```powershell
<#
.SYNOPSIS
Converts a markdown plan/spec into a single self-contained HTML file.
.DESCRIPTION
Embeds the markdown as JSON inside the HTML template; rendering happens
client-side via vendored marked.js (+ mermaid.js only when needed).
Glossary terms (## headings in -GlossaryPath) become auto-links with an
in-page appendix. Output: sibling .html (or -OutputPath). Prints the path.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$MarkdownPath,
    [string]$GlossaryPath,
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'

$scriptRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$pluginRoot   = Split-Path -Parent $scriptRoot
$templatePath = Join-Path $pluginRoot 'templates\plan-html\template.html'
$markedPath   = Join-Path $pluginRoot 'vendor\marked.min.js'
$mermaidPath  = Join-Path $pluginRoot 'vendor\mermaid.min.js'

if (-not (Test-Path $MarkdownPath)) { throw "Markdown file not found: $MarkdownPath" }
$MarkdownPath = (Resolve-Path $MarkdownPath).Path
$markdown = [System.IO.File]::ReadAllText($MarkdownPath, [System.Text.Encoding]::UTF8)

# Title: first H1, else file name
$title = [System.IO.Path]::GetFileNameWithoutExtension($MarkdownPath)
$h1 = [regex]::Match($markdown, '(?m)^#\s+(.+)$')
if ($h1.Success) { $title = $h1.Groups[1].Value.Trim() }

# Glossary terms: each "## Term" heading + body becomes {term, anchor, definition}
$terms = @()
if ($GlossaryPath -and (Test-Path $GlossaryPath)) {
    $glossaryText = [System.IO.File]::ReadAllText((Resolve-Path $GlossaryPath).Path, [System.Text.Encoding]::UTF8)
    $sections = [regex]::Matches($glossaryText, '(?ms)^##\s+(.+?)\s*\r?$(.*?)(?=^##\s|\z)')
    foreach ($s in $sections) {
        $name = $s.Groups[1].Value.Trim()
        $defn = [regex]::Replace($s.Groups[2].Value, '(?ms)```mermaid.*?```', '').Trim()
        $anchor = [regex]::Replace($name.ToLowerInvariant(), '[^a-z0-9\s-]', '')
        $anchor = [regex]::Replace($anchor, '\s+', '-')
        $terms += [pscustomobject]@{ term = $name; anchor = $anchor; definition = $defn }
    }
}

# JSON-encode for safe inline <script> embedding; escape </ so </script> in
# content cannot terminate the script block ("<\/" is a legal JS escape).
$markdownJson = ($markdown | ConvertTo-Json -Compress).Replace('</', '<\/')
$termsJson    = (ConvertTo-Json -InputObject @($terms) -Compress).Replace('</', '<\/')

$template = [System.IO.File]::ReadAllText($templatePath, [System.Text.Encoding]::UTF8)
$markedJs = [System.IO.File]::ReadAllText($markedPath, [System.Text.Encoding]::UTF8)
$mermaidJs = ''
if ($markdown -match '(?m)^\s*```mermaid') {
    $mermaidJs = [System.IO.File]::ReadAllText($mermaidPath, [System.Text.Encoding]::UTF8)
}

$titleHtml = [System.Net.WebUtility]::HtmlEncode($title)
$generated = Get-Date -Format 'yyyy-MM-dd HH:mm'

$html = $template.Replace('{{TITLE}}', $titleHtml)
$html = $html.Replace('{{GENERATED}}', $generated)
$html = $html.Replace('{{MARKDOWN_JSON}}', $markdownJson)
$html = $html.Replace('{{TERMS_JSON}}', $termsJson)
$html = $html.Replace('{{MARKED_JS}}', $markedJs)
$html = $html.Replace('{{MERMAID_JS}}', $mermaidJs)

if (-not $OutputPath) { $OutputPath = [System.IO.Path]::ChangeExtension($MarkdownPath, '.html') }
[System.IO.File]::WriteAllText($OutputPath, $html, (New-Object System.Text.UTF8Encoding($false)))
Write-Output $OutputPath
```

- [ ] **Step 7: Run tests — verify they pass**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1`
Expected: all `PASS`, `All tests passed`, exit 0.

- [ ] **Step 8: Visual smoke test**

Run the converter on the sample fixture into the temp dir and open the result once: convert `tests/fixtures/sample-plan.md` with `-GlossaryPath tests/fixtures/glossary.md -OutputPath "$env:TEMP\sample-plan.html"`, then tell the user to open `file:///<TEMP>/sample-plan.html` and confirm: table renders, mermaid diagram renders, "Module"/"Contracts" are dotted links jumping to the in-page Glossary appendix, h2 sections collapse.

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "feat: convert-plan.ps1 with self-contained HTML output and tests"
```

---

### Task 5: PostToolUse hook (TDD)

**Files:**
- Create: `plugins/repo-foundry/scripts/plan-to-html-hook.ps1`
- Create: `plugins/repo-foundry/hooks/hooks.json`
- Modify: `tests/run-tests.ps1` (add hook tests before the `# --- summary` block)

- [ ] **Step 1: Add hook tests to `tests/run-tests.ps1`** — insert this block immediately above the `# --- summary` line:

```powershell
# --- hook tests ------------------------------------------------------------
$hookWork = Join-Path $work 'hookrepo'
New-Item -ItemType Directory -Path (Join-Path $hookWork 'docs\plans') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $hookWork 'docs\glossary') -Force | Out-Null
Copy-Item (Join-Path $fixtures 'sample-plan.md') (Join-Path $hookWork 'docs\plans\sample-plan.md')
Copy-Item (Join-Path $fixtures 'glossary.md') (Join-Path $hookWork 'docs\glossary\README.md')

$watchedPath = Join-Path $hookWork 'docs\plans\sample-plan.md'
$payload = @{ tool_name = 'Write'; tool_input = @{ file_path = $watchedPath }; cwd = $hookWork } | ConvertTo-Json -Compress
$stdout = $payload | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook
Assert ($LASTEXITCODE -eq 0) 'hook exits 0 on watched path'
Assert (Test-Path (Join-Path $hookWork 'docs\plans\sample-plan.html')) 'hook generates html twin'
$joined = $stdout -join ''
Assert ($joined.Contains('hookSpecificOutput')) 'hook emits additionalContext JSON'
Assert ($joined.Contains('file:///')) 'hook context includes file:/// url'

$unwatched = @{ tool_name = 'Write'; tool_input = @{ file_path = (Join-Path $hookWork 'src\thing.cs') }; cwd = $hookWork } | ConvertTo-Json -Compress
$stdout2 = $unwatched | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook
Assert ($LASTEXITCODE -eq 0) 'hook exits 0 on unwatched path'
Assert ([string]::IsNullOrWhiteSpace(($stdout2 -join ''))) 'hook silent on unwatched path'

$null = 'not json at all' | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook
Assert ($LASTEXITCODE -eq 0) 'hook exits 0 on malformed stdin (never blocks)'
```

- [ ] **Step 2: Run tests — verify new ones fail**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1`
Expected: converter tests PASS; hook tests FAIL (hook script missing); exit 1.

- [ ] **Step 3: Create `plugins/repo-foundry/scripts/plan-to-html-hook.ps1`**

```powershell
# PostToolUse hook: regenerate the HTML twin when a plan/spec markdown is written.
# Contract: NEVER block the write - exit 0 on every path, including errors.
# Watched: docs/plans/, docs/specs/, docs/superpowers/plans/, docs/superpowers/specs/
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $payload = $raw | ConvertFrom-Json
    $filePath = $payload.tool_input.file_path
    if (-not $filePath) { exit 0 }
    if ($filePath -notmatch '(?i)docs[\\/](superpowers[\\/])?(plans|specs)[\\/].+\.md$') { exit 0 }
    if (-not (Test-Path $filePath)) { exit 0 }

    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $converter = Join-Path $scriptRoot 'convert-plan.ps1'

    $cwd = $payload.cwd
    if (-not $cwd) { $cwd = (Get-Location).Path }
    $params = @{ MarkdownPath = $filePath }
    $glossary = Join-Path $cwd 'docs\glossary\README.md'
    if (Test-Path $glossary) { $params.GlossaryPath = $glossary }

    $htmlPath = & $converter @params
    $fileUrl = 'file:///' + (($htmlPath | Select-Object -Last 1) -replace '\\', '/')
    $context = "plan-to-html hook: regenerated the HTML twin at $htmlPath. " +
        "Tell the user it is updated and END your message with this URL on its own line: $fileUrl"
    $out = @{ hookSpecificOutput = @{ hookEventName = 'PostToolUse'; additionalContext = $context } }
    $out | ConvertTo-Json -Compress -Depth 5
    exit 0
} catch {
    exit 0
}
```

- [ ] **Step 4: Create `plugins/repo-foundry/hooks/hooks.json`**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PLUGIN_ROOT}/scripts/plan-to-html-hook.ps1\""
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 5: Run tests — verify all pass**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1`
Expected: all PASS, exit 0.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: PostToolUse hook auto-generates HTML twins of plans/specs"
```

---

### Task 6: plan-to-html skill

**Files:**
- Create: `plugins/repo-foundry/skills/plan-to-html/SKILL.md`

- [ ] **Step 1: Create the skill**

```markdown
---
name: plan-to-html
description: Use when the user asks for an HTML version of a markdown plan/spec/design doc, or when the plan-to-html hook fails and conversion must be run manually - produces a single self-contained HTML file with rendered Mermaid, collapsible sections, and glossary auto-links
---

# Plan to HTML

Convert a markdown plan/spec into one self-contained HTML file (no network needed to view).

## Steps

1. Identify the markdown file. If the user didn't name one, use the most recently
   modified file under `docs/plans/`, `docs/superpowers/plans/`, or `docs/superpowers/specs/`.
2. Locate the converter relative to this skill's base directory:
   `<skill-base-dir>/../../scripts/convert-plan.ps1`.
3. Run (Windows):

   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/convert-plan.ps1" -MarkdownPath "<file>.md" -GlossaryPath "docs/glossary/README.md"

   Omit `-GlossaryPath` if `docs/glossary/README.md` does not exist. The script
   prints the output path (sibling `.html` by default; override with `-OutputPath`).
4. Report completion and ALWAYS end the message with the raw `file:///` URL of the
   generated HTML on its own line (convert backslashes to forward slashes).

## Troubleshooting

- "Markdown file not found": pass an absolute path.
- Output huge (>1.5 MB): expected when the source contains a ```mermaid block —
  the mermaid library is inlined. Sources without mermaid produce ~100 KB files.
- Glossary links missing: confirm the glossary uses `## Term` headings; the
  converter only parses h2 sections.
```

- [ ] **Step 2: Validate**

Run: `claude plugin validate .`
Expected: passes; skill listed. (Fallback if subcommand unavailable: confirm the file has `name` and `description` frontmatter keys and is at `plugins/repo-foundry/skills/plan-to-html/SKILL.md`.)

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: plan-to-html skill"
```

---

### Task 7: Repo seed templates

**Files:**
- Create: `plugins/repo-foundry/templates/repo/CLAUDE.md`
- Create: `plugins/repo-foundry/templates/repo/.gitignore`
- Create: `plugins/repo-foundry/templates/repo/.editorconfig`
- Create: `plugins/repo-foundry/templates/repo/.gitattributes`
- Create: `plugins/repo-foundry/templates/glossary/README.md`

- [ ] **Step 1: Create `plugins/repo-foundry/templates/repo/CLAUDE.md`**

```markdown
# Project conventions

This repo uses Module (vertical slice) architecture. Definitions: docs/glossary/README.md.

## Architecture rules (enforced in review)

- Vertical slices are **Modules** under `src/Modules/<Name>/`.
- Cross-Module references go through `<Name>.Contracts` ONLY. Never reference
  another Module's Domain, Application, Infrastructure, Client, or UI.
- Per-Module dependency rules:
  - `<Name>.Contracts` -> references nothing
  - `<Name>.Domain` -> references nothing
  - `<Name>.Application` -> Domain, Contracts (implements Contracts in-process)
  - `<Name>.Infrastructure` -> Application, Domain
  - `<Name>.Client` (optional) -> Contracts (HTTP implementation)
  - `<Name>.UI` (Blazor RCL) -> Contracts ONLY
- Hosts (`src/Hosts/*`) are composition roots: each registers either the
  Application (in-process) or the Client (HTTP) implementation per Module.
- UIs are always Blazor. The same Module UI must run under a web host and a
  WPF (BlazorWebView) host - that works only if it depends on Contracts alone.
- Tests mirror modules under `tests/`.

## Glossary protocol

- `docs/glossary/README.md` is the shared glossary. Use its terms in every
  discussion and link them, e.g. [Module](docs/glossary/README.md#module).
- New/changed domain terms: propose the entry, get confirmation, then write it.

## Plans and specs

- Specs: `docs/superpowers/specs/` - Plans: `docs/superpowers/plans/` or `docs/plans/`.
- Writing a plan/spec markdown auto-generates an HTML twin (plan-to-html hook).
  When reporting an HTML artifact, END the message with its raw `file:///` URL.
```

- [ ] **Step 2: Create `plugins/repo-foundry/templates/repo/.gitignore`**

```
# .NET
bin/
obj/
[Dd]ebug/
[Rr]elease/
*.user
*.suo
.vs/
artifacts/
TestResults/
*.binlog

# Node (Blazor tooling)
node_modules/

# OS
Thumbs.db
.DS_Store
```

- [ ] **Step 3: Create `plugins/repo-foundry/templates/repo/.editorconfig`**

```
root = true

[*]
charset = utf-8
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 4

[*.{json,yml,yaml,csproj,props,targets,razor,html,css,js}]
indent_size = 2

[*.md]
trim_trailing_whitespace = false

[*.cs]
dotnet_sort_system_directives_first = true
csharp_style_namespace_declarations = file_scoped:suggestion
csharp_style_var_when_type_is_apparent = true:suggestion
```

- [ ] **Step 4: Create `plugins/repo-foundry/templates/repo/.gitattributes`**

```
* text=auto
*.ps1 text eol=crlf
*.min.js -text
```

- [ ] **Step 5: Create `plugins/repo-foundry/templates/glossary/README.md`** — copy the canonical glossary verbatim:

```bash
cp docs/glossary/README.md plugins/repo-foundry/templates/glossary/README.md
```

Then edit the template copy's first paragraph from "One agreed meaning per domain term..." to:

```markdown
One agreed meaning per domain term. Reference these in every discussion; propose
new entries as terms emerge. Architecture terms below are seeded by repo-foundry;
add this repo's own domain terms as they appear.
```

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: repo seed templates (CLAUDE.md, ignore files, glossary)"
```

---

### Task 8: repo-init skill

**Files:**
- Create: `plugins/repo-foundry/skills/repo-init/SKILL.md`

- [ ] **Step 1: Create the skill**

`````markdown
---
name: repo-init
description: Use when starting a brand-new .NET repo with Module (vertical slice) architecture - scaffolds git, solution, folder layout, glossary, CLAUDE.md, and the first Module
---

# Repo Init

Scaffold a new Module-architecture .NET repo. Templates live at
`<skill-base-dir>/../../templates/` (the plugin root's `templates/` folder).

## Gather first (ask the user)

1. Repo/solution name (PascalCase, e.g. `OrderHub`).
2. Hosts to create now: Web (ASP.NET Core), WPF (BlazorWebView), or both.
3. First Module name (PascalCase business capability, e.g. `Orders`).

## Steps

1. Verify the target directory is empty (or contains only `.git`). If not, stop and ask.
2. `git init` (then `git symbolic-ref HEAD refs/heads/main` if git < 2.28).
3. Copy from the plugin `templates/repo/` into the repo root:
   `CLAUDE.md`, `.gitignore`, `.editorconfig`, `.gitattributes`.
4. Copy `templates/glossary/README.md` to `docs/glossary/README.md`.
5. Create empty dirs: `docs/plans/`, `docs/superpowers/specs/`, `docs/superpowers/plans/`.
6. Create the solution and shared build props:

   dotnet new sln -n <RepoName>

   Create `Directory.Build.props` at repo root:

   ```xml
   <Project>
     <PropertyGroup>
       <TargetFramework>net8.0</TargetFramework>
       <Nullable>enable</Nullable>
       <ImplicitUsings>enable</ImplicitUsings>
       <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
     </PropertyGroup>
   </Project>
   ```

7. Hosts (as chosen):
   - Web: `dotnet new web -n <RepoName>.Host.Web -o src/Hosts/Web` then `dotnet sln add src/Hosts/Web`
   - WPF: `dotnet new wpf -n <RepoName>.Host.Wpf -o src/Hosts/Wpf` then `dotnet sln add src/Hosts/Wpf`
     and `dotnet add src/Hosts/Wpf package Microsoft.AspNetCore.Components.WebView.Wpf`
8. First Module: invoke the `add-module` skill with the chosen Module name.
9. `dotnet build` - must succeed.
10. Recommend the user install this plugin in the new repo:
    `/plugin marketplace add c:\WorkingGit\NewRepo` then `/plugin install repo-foundry@cogniva`
    (enables the plan-to-html hook there).
11. Commit everything: `git add -A && git commit -m "chore: scaffold <RepoName> via repo-foundry"`.

## Rules baked into the scaffold

Dependency rules live in the copied CLAUDE.md and the glossary - do not restate
them ad hoc; link to [Module](docs/glossary/README.md#module) and friends.
`````

- [ ] **Step 2: Validate**

Run: `claude plugin validate .`
Expected: passes; skill listed. (Same fallback as Task 6.)

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: repo-init skill"
```

---

### Task 9: add-module skill

**Files:**
- Create: `plugins/repo-foundry/skills/add-module/SKILL.md`

- [ ] **Step 1: Create the skill**

`````markdown
---
name: add-module
description: Use when adding a new Module (vertical slice) to an existing Module-architecture .NET repo - scaffolds Contracts/Domain/Application/Infrastructure/UI projects, optional Client, wires references and tests, updates the glossary
---

# Add Module

Add one Module named `<M>` (PascalCase, e.g. `Orders`) to an existing repo.

## Gather first (ask the user)

1. Module name `<M>`.
2. Include the optional HTTP `Client` project now? (Default: no - add it when a
   remote deployment actually exists.)
3. One-sentence description of the Module's business capability (for the glossary).

## Steps

1. Create projects (from repo root):

   dotnet new classlib -n <M>.Contracts -o src/Modules/<M>/<M>.Contracts
   dotnet new classlib -n <M>.Domain -o src/Modules/<M>/<M>.Domain
   dotnet new classlib -n <M>.Application -o src/Modules/<M>/<M>.Application
   dotnet new classlib -n <M>.Infrastructure -o src/Modules/<M>/<M>.Infrastructure
   dotnet new razorclasslib -n <M>.UI -o src/Modules/<M>/<M>.UI

   If Client requested: dotnet new classlib -n <M>.Client -o src/Modules/<M>/<M>.Client

2. Delete the template `Class1.cs` from each classlib.
3. Wire references (these ARE the dependency rules - no others allowed):

   dotnet add src/Modules/<M>/<M>.Application reference src/Modules/<M>/<M>.Domain src/Modules/<M>/<M>.Contracts
   dotnet add src/Modules/<M>/<M>.Infrastructure reference src/Modules/<M>/<M>.Application src/Modules/<M>/<M>.Domain
   dotnet add src/Modules/<M>/<M>.UI reference src/Modules/<M>/<M>.Contracts
   If Client: dotnet add src/Modules/<M>/<M>.Client reference src/Modules/<M>/<M>.Contracts

4. Add all new projects to the solution: dotnet sln add src/Modules/<M>/**.csproj
   (or list each project path explicitly if globbing fails).
5. Test project:

   dotnet new xunit -n <M>.Application.Tests -o tests/Modules/<M>/<M>.Application.Tests
   dotnet add tests/Modules/<M>/<M>.Application.Tests reference src/Modules/<M>/<M>.Application
   dotnet sln add tests/Modules/<M>/<M>.Application.Tests

6. `dotnet build` - must succeed before continuing.
7. Glossary: append to `docs/glossary/README.md` (propose to the user first):

   ## <M> (Module)

   <one-sentence business capability description>. A [Module](#module); public
   surface is `<M>.Contracts`.

8. Register in Hosts: remind the user (or do it if asked) that each Host must
   register `<M>.Application` (in-process) or `<M>.Client` (HTTP) against the
   `<M>.Contracts` interfaces.
9. Commit: `git add -A && git commit -m "feat: add <M> module"`.
`````

- [ ] **Step 2: Validate**

Run: `claude plugin validate .`
Expected: passes; all three skills listed. (Same fallback as Task 6.)

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add-module skill"
```

---

### Task 10: Strategy doc + spec sync

**Files:**
- Create: `docs/strategy.md`
- Modify: `docs/superpowers/specs/2026-06-11-repo-foundry-design.md` (two lines — see Step 2)

- [ ] **Step 1: Create `docs/strategy.md`**

```markdown
# Repo strategy

What this repo is, the conventions it encodes, and how to consume it.

## Purpose

`cogniva` is Cogniva's Claude Code plugin marketplace (repo:
github.com/cogniva/cogniva-skills). The `cogniva-skills` plugin carries shared
skills (glossary, auto-doc); the `repo-foundry` plugin packages our
repo-initialization conventions so every new repo starts identical and
improvements propagate (consuming repos reinstall/update plugins instead of
copying files).

## Conventions (canonical definitions: docs/glossary/README.md)

- .NET solutions composed of [Modules](glossary/README.md#module) - vertical
  slices, each with Contracts / Domain / Application / Infrastructure /
  optional Client / Blazor UI.
- Cross-Module communication only via [Contracts](glossary/README.md#contracts).
- [Hosts](glossary/README.md#host) choose in-process (Application) or HTTP
  (Client) per deployment; UIs are always Blazor so they run in web and WPF hosts.
- Every repo keeps a glossary at `docs/glossary/README.md` (seeded by repo-init)
  and grows it propose-then-confirm.
- Specs in `docs/superpowers/specs/`, plans in `docs/superpowers/plans/` or
  `docs/plans/`; each markdown gets a self-contained HTML twin automatically.

## Tooling inventory

| Tool | Plugin | Type | Trigger |
|---|---|---|---|
| repo-init | repo-foundry | skill | user starts a new repo |
| add-module | repo-foundry | skill | user adds a vertical slice |
| plan-to-html | repo-foundry | skill | manual conversion / hook troubleshooting |
| plan-to-html hook | repo-foundry | PostToolUse hook | any Write/Edit of watched plan/spec markdown |
| glossary | cogniva-skills | skill | unrecognized terminology (docs/glossary lookup) |
| auto-doc | cogniva-skills | skill | architectural decisions during design/planning |

## Consuming in a new repo

1. `/plugin marketplace add c:\WorkingGit\NewRepo`
2. `/plugin install repo-foundry@cogniva`
3. Run the repo-init skill.

## Maintenance

- Change skills/templates/scripts here, bump `version` in
  `plugins/repo-foundry/.claude-plugin/plugin.json`, commit; consuming repos
  pick it up via plugin update.
- Tests: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1`
  must pass before any commit to scripts or the HTML template.

## Roadmap (deliberately not yet)

- Enforce dependency rules with Roslyn analyzers or ArchUnitNET tests.
- NuGet packaging of module templates.
- pwsh (PowerShell 7) support in hook command for non-Windows teammates.
```

- [ ] **Step 2: Sync the spec with implementation reality** — in `docs/superpowers/specs/2026-06-11-repo-foundry-design.md`:
  - Replace the line:
    `- \`PostToolUse\` hook on Write/Edit; script checks the path against \`docs/plans/**/*.md\` and \`docs/superpowers/specs/**/*.md\``
    with:
    `- \`PostToolUse\` hook on Write/Edit; script checks the path against \`docs/plans/\`, \`docs/specs/\`, \`docs/superpowers/plans/\`, and \`docs/superpowers/specs/\` (\`*.md\`)`
  - Replace the line:
    `- **Converter:** sample plan fixture (headings, tables, Mermaid, code blocks, glossary terms) + Pester test asserting valid self-contained output`
    with:
    `- **Converter:** sample plan fixture (headings, tables, Mermaid, code blocks, glossary terms) + plain-PowerShell assertion script (\`tests/run-tests.ps1\`; Pester dropped: PS 5.1 ships incompatible Pester 3.4)`

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "docs: strategy doc; sync spec with watched paths and test approach"
```

---

### Task 11: Self-consumption + dogfood

**Files:**
- Create: `.claude/settings.json`

- [ ] **Step 1: Create `.claude/settings.json`** (auto-registers the marketplace + enables the plugin for anyone opening this repo)

```json
{
  "extraKnownMarketplaces": {
    "cogniva": {
      "source": {
        "source": "local",
        "path": "c:\\WorkingGit\\NewRepo"
      }
    }
  },
  "enabledPlugins": {
    "repo-foundry@cogniva": true,
    "cogniva-skills@cogniva": true
  }
}
```

If Claude Code rejects this schema on session restart, delete the file and instead tell the user to run `/plugin marketplace add c:\WorkingGit\NewRepo` and `/plugin install repo-foundry@cogniva` manually.

- [ ] **Step 2: Dogfood — convert this plan itself**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File plugins/repo-foundry/scripts/convert-plan.ps1 -MarkdownPath docs/superpowers/plans/2026-06-11-repo-foundry.md -GlossaryPath docs/glossary/README.md`
Expected: prints the output path `...\docs\superpowers\plans\2026-06-11-repo-foundry.html`.
Report to the user, ending the message with the `file:///` URL of that HTML.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "chore: self-consume plugin; dogfood plan HTML"
```

---

### Task 12: End-to-end verification (with user)

**Files:** none created — verification only.

- [ ] **Step 1: Full test suite green**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1`
Expected: `All tests passed`, exit 0.

- [ ] **Step 2: Plugin validation green**

Run: `claude plugin validate .`
Expected: marketplace + plugin + 3 skills + hooks all valid.

- [ ] **Step 3: User installs and smoke-tests the hook** (requires user action — ask, don't assume)

Ask the user to: restart the Claude Code session in this repo (so `.claude/settings.json` / plugin install takes effect), confirm via `/plugin` that `repo-foundry@cogniva` is enabled, then ask Claude to make any trivial edit to a file in `docs/superpowers/specs/` — the hook should fire, regenerate the HTML twin, and the reply should end with a `file:///` URL.

- [ ] **Step 4: Dry-run repo-init + add-module in a temp directory** (spec requires this before first real use)

Create an empty temp dir (e.g. `$env:TEMP\foundry-dryrun`), then follow the `repo-init` skill end-to-end there with repo name `DryRun`, Web host only, first Module `Sample` (which exercises `add-module`). Expected: `dotnet build` succeeds, glossary + CLAUDE.md present, dependency references match the rules. Delete the temp dir afterwards. Requires the dotnet SDK — if unavailable, report that to the user and mark this step skipped rather than silently passing.

- [ ] **Step 5: Working tree clean**

Run: `git status --short`
Expected: empty output. If not, commit stragglers.
