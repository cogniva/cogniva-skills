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
