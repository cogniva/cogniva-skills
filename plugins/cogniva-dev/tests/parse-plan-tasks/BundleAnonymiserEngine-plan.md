# BundleAnonymiserEngine — Feature Plan

> REQUIRED EXECUTOR: /cogniva-dev:execute-feature ShareInsights/BundleAnonymiserEngine
> Tasks contain NO git worktree/branch step — execute-feature creates the worktree
> and the tasks commit on the feature branch they are already on. Never run
> git switch/checkout/branch inside a task.

**Goal:** Make `/extract-treesizepro` work in any repo by bundling its Python engine
(`treesize_ingest` + `reversible_name_anonymizer`) inside the cogniva-shareinsights
plugin and resolving it via `${CLAUDE_PLUGIN_ROOT}` instead of the user's project dir.

**Architecture:** Today the extract skill drives Python at
`$CLAUDE_PROJECT_DIR/scripts/Anonymization` — the *user's* project directory, which
is empty in any repo other than this one (the reported bug: "missing all the
scripts"). Its sibling `prepare-treesizepro` already does this right: it ships its
PowerShell at `plugins/cogniva-shareinsights/scripts/` and resolves via
`${CLAUDE_PLUGIN_ROOT}`. This feature mirrors that pattern. The two importable
Python packages plus `requirements.txt` MOVE into
`plugins/cogniva-shareinsights/scripts/Anonymization/` (single source of truth — no
repo-local copy). To keep the published plugin lean, the test suite + conftest +
demos MOVE to `tests/ShareInsights/Anonymization/` (mirroring the PowerShell tests'
repo-root home); a relocated conftest puts the bundled packages on `sys.path`. The
skill's `cd` target changes from `$CLAUDE_PROJECT_DIR` to `${CLAUDE_PLUGIN_ROOT}`;
the dataguard allowlist regex (`^python -m treesize_ingest`) is cwd-independent and
needs no change.

**Read these first:**
- [extract-treesizepro/SKILL.md](../../../../plugins/cogniva-shareinsights/skills/extract-treesizepro/SKILL.md) — the skill being repointed
- [prepare-treesizepro/SKILL.md](../../../../plugins/cogniva-shareinsights/skills/prepare-treesizepro/SKILL.md) — the bundled-scripts pattern to mirror (its Packaging section)
- [ADR 0017](../../../adr/0017-treesize-ingest-frontend-for-restricted-export-anonymisation.md) — the treesize_ingest frontend contract
- [ExtractTreeSizePro/state.md](../ExtractTreeSizePro/state.md) — how the current layout was built

## File structure (locked)

```
plugins/cogniva-shareinsights/scripts/Anonymization/      # NEW home of the engine (bundled, shipped)
  treesize_ingest/                                         # MOVED from scripts/Anonymization/treesize_ingest/
  reversible_name_anonymizer/                              # MOVED from scripts/Anonymization/reversible_name_anonymizer/
  requirements.txt                                         # MOVED from scripts/Anonymization/requirements.txt
plugins/cogniva-shareinsights/scripts/Anonymization/treesize_ingest/__main__.py   # docstring: cwd note repointed to plugin path
tests/ShareInsights/Anonymization/                         # NEW home of the suite (repo-root, NOT shipped)
  __init__.py                                              # MOVED from scripts/Anonymization/tests/__init__.py
  test_*.py  (14 files)                                    # MOVED from scripts/Anonymization/tests/
  conftest.py                                              # MOVED + REWRITTEN: sys.path now points into the plugin
  demo_roundtrip.py                                        # MOVED + sys.path bootstrap added
  demo_csv_roundtrip.py                                    # MOVED + sys.path bootstrap + fixture path fixed
plugins/cogniva-shareinsights/skills/extract-treesizepro/SKILL.md   # cd target -> ${CLAUDE_PLUGIN_ROOT}; Packaging rewritten
README.md                                                  # Layout + Anonymization sections repointed to the plugin path
plugins/cogniva-shareinsights/.claude-plugin/plugin.json   # description notes the bundled anonymiser engine
scripts/                                                   # DELETED (emptied by the moves)
```

## Task 1: Move the Python engine into the plugin

**Files:**
- Move: `scripts/Anonymization/treesize_ingest/` → `plugins/cogniva-shareinsights/scripts/Anonymization/treesize_ingest/`
- Move: `scripts/Anonymization/reversible_name_anonymizer/` → `plugins/cogniva-shareinsights/scripts/Anonymization/reversible_name_anonymizer/`
- Move: `scripts/Anonymization/requirements.txt` → `plugins/cogniva-shareinsights/scripts/Anonymization/requirements.txt`

- [x] **Step 1 (make the destination):** create the target dir, then move the two
      packages and requirements with `git mv` (preserves history):
      ```bash
      mkdir -p plugins/cogniva-shareinsights/scripts/Anonymization
      git mv scripts/Anonymization/treesize_ingest          plugins/cogniva-shareinsights/scripts/Anonymization/treesize_ingest
      git mv scripts/Anonymization/reversible_name_anonymizer plugins/cogniva-shareinsights/scripts/Anonymization/reversible_name_anonymizer
      git mv scripts/Anonymization/requirements.txt          plugins/cogniva-shareinsights/scripts/Anonymization/requirements.txt
      ```
- [x] **Step 2 (verify both packages import from the new home):** run, via Bash, in
      two steps (the first sets cwd, the second starts with `python` so the dataguard
      allowlist still matches — never `cd … && python …`):
      ```bash
      cd plugins/cogniva-shareinsights/scripts/Anonymization
      ```
      ```bash
      python -c "import treesize_ingest, reversible_name_anonymizer; print('engine-ok')"
      ```
      Expected output: `engine-ok`
- [x] **Step 3 (commit):**
      `git add plugins/cogniva-shareinsights/scripts/Anonymization scripts/Anonymization`
      then
      `git commit -m "refactor(shareinsights): bundle treesize_ingest + reversible_name_anonymizer into the plugin"`
      (No-op: the three engine items already live at the plugin path in HEAD — see state.md. No new commit was created because there was nothing to stage.)

## Task 2: Relocate the test suite + demos to the repo-root tests tree and rewire imports

The packages now live in the plugin (Task 1). The suite + conftest + demos move out
of the emptied `scripts/Anonymization/` to `tests/ShareInsights/Anonymization/`, and
the conftest is rewritten to put the *plugin* package dir on `sys.path`. All tests
use pytest's `tmp_path` for file I/O (no fixture-file lookups), so only import
resolution needs fixing; the one exception is `demo_csv_roundtrip.py`, which reads
the shared sample CSV and needs its relative path corrected.

**Files:**
- Move: `scripts/Anonymization/tests/` → `tests/ShareInsights/Anonymization/` (14 `test_*.py` + `__init__.py`)
- Move + Rewrite: `scripts/Anonymization/conftest.py` → `tests/ShareInsights/Anonymization/conftest.py`
- Move + Edit: `scripts/Anonymization/demo_roundtrip.py` → `tests/ShareInsights/Anonymization/demo_roundtrip.py`
- Move + Edit: `scripts/Anonymization/demo_csv_roundtrip.py` → `tests/ShareInsights/Anonymization/demo_csv_roundtrip.py`
- Delete: the emptied `scripts/` tree

- [x] **Step 1 (move suite, conftest, demos):**
      ```bash
      mkdir -p tests/ShareInsights/Anonymization
      git mv scripts/Anonymization/tests/* tests/ShareInsights/Anonymization/
      git mv scripts/Anonymization/conftest.py          tests/ShareInsights/Anonymization/conftest.py
      git mv scripts/Anonymization/demo_roundtrip.py     tests/ShareInsights/Anonymization/demo_roundtrip.py
      git mv scripts/Anonymization/demo_csv_roundtrip.py tests/ShareInsights/Anonymization/demo_csv_roundtrip.py
      ```
- [x] **Step 2 (rewrite conftest to point at the bundled packages):** overwrite
      `tests/ShareInsights/Anonymization/conftest.py` with exactly:
      ```python
      """Put the bundled anonymiser packages (shipped in the cogniva-shareinsights
      plugin) on sys.path so `treesize_ingest` and `reversible_name_anonymizer`
      resolve when the suite runs from the repo-root tests tree."""
      import os
      import sys

      _HERE = os.path.dirname(os.path.abspath(__file__))
      _PKGS = os.path.normpath(
          os.path.join(
              _HERE, "..", "..", "..",
              "plugins", "cogniva-shareinsights", "scripts", "Anonymization",
          )
      )
      sys.path.insert(0, _PKGS)
      ```
- [x] **Step 3 (bootstrap demo_roundtrip):** in
      `tests/ShareInsights/Anonymization/demo_roundtrip.py`, replace the top of the
      file (from its module docstring through the `from pathlib import Path` line):
      old:
      ```python
      """Manual end-to-end demo for ReversibleNameAnonymizer (real spaCy NER)."""

      from pathlib import Path
      ```
      new:
      ```python
      """Manual end-to-end demo for ReversibleNameAnonymizer (real spaCy NER)."""

      import os
      import sys
      from pathlib import Path

      sys.path.insert(0, os.path.normpath(os.path.join(
          os.path.dirname(os.path.abspath(__file__)),
          "..", "..", "..", "plugins", "cogniva-shareinsights", "scripts", "Anonymization")))
      ```
- [x] **Step 4 (bootstrap demo_csv + fix the sample path):** in
      `tests/ShareInsights/Anonymization/demo_csv_roundtrip.py`, replace the top of
      the file (docstring through the `from pathlib import Path` line):
      old:
      ```python
      """Manual end-to-end demo: anonymise & de-anonymise the real sample TreeSize CSV (real spaCy)."""

      from pathlib import Path
      ```
      new:
      ```python
      """Manual end-to-end demo: anonymise & de-anonymise the real sample TreeSize CSV (real spaCy)."""

      import os
      import sys
      from pathlib import Path

      sys.path.insert(0, os.path.normpath(os.path.join(
          os.path.dirname(os.path.abspath(__file__)),
          "..", "..", "..", "plugins", "cogniva-shareinsights", "scripts", "Anonymization")))
      ```
      then fix the now-stale sample lookup — replace:
      ```python
      HERE = Path(__file__).resolve().parent
      SAMPLE = HERE.parents[1] / "tests" / "ShareInsights" / "fixtures" / "sample_H_Standards.csv"
      ```
      with:
      ```python
      HERE = Path(__file__).resolve().parent
      SAMPLE = HERE.parent / "fixtures" / "sample_H_Standards.csv"
      ```
- [x] **Step 5 (delete the emptied scripts tree):**
      ```bash
      rm -rf scripts
      ```
- [x] **Step 6 (run the full suite from the repo root):** in two Bash steps —
      ```bash
      cd "$CLAUDE_PROJECT_DIR"
      ```
      ```bash
      python -m pytest tests/ShareInsights/Anonymization -q
      ```
      Expected output ends with: `42 passed` (warnings about SwigPy/spaCy are fine).
- [x] **Step 7 (commit):**
      `git add tests/ShareInsights/Anonymization scripts` then
      `git commit -m "test(shareinsights): move anonymiser suite to repo-root tests, point conftest at the bundled engine"`

## Task 3: Repoint the extract-treesizepro skill at ${CLAUDE_PLUGIN_ROOT}

The engine now ships in the plugin, so the skill must resolve it via
`${CLAUDE_PLUGIN_ROOT}` (like prepare-treesizepro) rather than the user's project
dir. `$CLAUDE_PROJECT_DIR` is still used for `--out-dir` and `--map-dir` (the
sanitised output and the source's `.restricted/` live in the user's repo) — only the
*engine* working directory changes.

**Files:**
- Modify: `plugins/cogniva-shareinsights/skills/extract-treesizepro/SKILL.md`

- [x] **Step 1 (intro: note the engine is bundled):** replace
      ```
      itself. This skill is a thin marshaller around the Python module
      `treesize_ingest` (under `scripts/Anonymization/`); it does not read the raw data
      ```
      with
      ```
      itself. This skill is a thin marshaller around the Python module
      `treesize_ingest`, bundled in this plugin under `scripts/Anonymization/`; it does not read the raw data
      ```
- [x] **Step 2 (change the working-directory step):** replace the whole Step 2 line
      ```
      2. **Set the working directory** (separate Bash call, no `.restricted` reference):
         `cd "$CLAUDE_PROJECT_DIR/scripts/Anonymization"`. Both `treesize_ingest` and
         `reversible_name_anonymizer` import from here.
      ```
      with
      ```
      2. **Set the working directory** (separate Bash call, no `.restricted` reference):
         `cd "${CLAUDE_PLUGIN_ROOT}/scripts/Anonymization"`. Both `treesize_ingest` and
         `reversible_name_anonymizer` are bundled here and import from this directory.
      ```
- [x] **Step 3 (rewrite the Packaging section):** replace the entire `## Packaging`
      section (from `## Packaging` through the line ending `…must be
      present in `.claude/dataguard-allow.txt`.`) with exactly:
      ```
      ## Packaging

      This skill ships in the `cogniva-shareinsights` plugin and the Python engine
      it drives is **bundled in the same plugin**:

      ```
      plugins/cogniva-shareinsights/
        scripts/Anonymization/                 # ${CLAUDE_PLUGIN_ROOT}/scripts/Anonymization
          treesize_ingest/                     # this skill's entry module
          reversible_name_anonymizer/          # its anonymiser dependency
          requirements.txt
        skills/extract-treesizepro/SKILL.md
      ```

      The engine resolves at `${CLAUDE_PLUGIN_ROOT}/scripts/Anonymization` (the Step 2
      `cd` target), so the skill works in any repo — there is no dependence on a
      repo-local `scripts/` path. If that directory or
      `${CLAUDE_PLUGIN_ROOT}/scripts/Anonymization/treesize_ingest/` is absent, say the
      plugin engine is missing rather than guessing.

      The Python dependencies are NOT bundled. Once per machine, install them from the
      bundled requirements (Bash tool, command starts with `python`):
      `python -m pip install -r "${CLAUDE_PLUGIN_ROOT}/scripts/Anonymization/requirements.txt"`
      — the default `ner` detector additionally needs the spaCy model
      (`python -m spacy download en_core_web_lg`), or use `--detector conventions`.

      The guard allowlist entry for `python -m treesize_ingest` ships in the
      cogniva-dataguard template and must be present in `.claude/dataguard-allow.txt`;
      it matches on the command string, so the new working directory does not affect it.
      ```
- [x] **Step 4 (verify the repoint):** run
      ```bash
      grep -n "CLAUDE_PROJECT_DIR/scripts\|not yet plugin-bundled" plugins/cogniva-shareinsights/skills/extract-treesizepro/SKILL.md; echo "exit:$?"
      ```
      Expected output: no matching lines, then `exit:1` (grep found nothing).
- [x] **Step 5 (verify the new resolution is present):** run
      ```bash
      grep -c "CLAUDE_PLUGIN_ROOT}/scripts/Anonymization" plugins/cogniva-shareinsights/skills/extract-treesizepro/SKILL.md
      ```
      Expected output: `3` (Step 2 cd, the Packaging layout comment, and the
      pip-install line).
- [x] **Step 6 (commit):**
      `git add plugins/cogniva-shareinsights/skills/extract-treesizepro/SKILL.md` then
      `git commit -m "fix(shareinsights): resolve extract engine via CLAUDE_PLUGIN_ROOT so the skill is portable"`

## Task 4: Fix residual path references (module docstring, README, plugin metadata)

Stale `scripts/Anonymization/` references remain in the moved module's docstring, the
README, and the plugin description. These are docs only — no behaviour change.

**Files:**
- Modify: `plugins/cogniva-shareinsights/scripts/Anonymization/treesize_ingest/__main__.py`
- Modify: `README.md`
- Modify: `plugins/cogniva-shareinsights/.claude-plugin/plugin.json`

- [x] **Step 1 (module docstring):** in
      `plugins/cogniva-shareinsights/scripts/Anonymization/treesize_ingest/__main__.py`,
      replace
      ```
      Run with the working directory set to `scripts/Anonymization` so both
      `treesize_ingest` and `reversible_name_anonymizer` import. Invoke ONLY via the
      ```
      with
      ```
      Run with the working directory set to the plugin's
      `scripts/Anonymization` (`${CLAUDE_PLUGIN_ROOT}/scripts/Anonymization`) so both
      `treesize_ingest` and `reversible_name_anonymizer` import. Invoke ONLY via the
      ```
- [x] **Step 2 (README Layout bullet):** in `README.md`, replace the line
      ```
      - `scripts/Anonymization/` — self-contained Python project: `reversible_name_anonymizer/` package, `tests/`, `conftest.py`, `requirements.txt`, `demo_roundtrip.py`.
      ```
      with
      ```
      - `plugins/cogniva-shareinsights/scripts/Anonymization/` — the bundled Python engine the `extract-treesizepro` skill drives: `treesize_ingest/` + `reversible_name_anonymizer/` packages and `requirements.txt`. Its pytest suite + demos live at `tests/ShareInsights/Anonymization/` (repo-root, not shipped in the plugin).
      ```
- [x] **Step 3 (README Anonymization section):** in `README.md`, replace this exact
      block (the paragraph plus the fenced powershell example, currently lines 53-61):
      old:
      ```
      Self-contained under `scripts/Anonymization/`. Install deps (Presidio also needs
      a spaCy model, e.g. `python -m spacy download en_core_web_lg`) and run the
      20-test pytest suite from that directory:

      ```powershell
      cd scripts\Anonymization
      pip install -r requirements.txt
      pytest -q
      ```
      ```
      new:
      ```
      The engine ships in `plugins/cogniva-shareinsights/scripts/Anonymization/`; the
      pytest suite lives at `tests/ShareInsights/Anonymization/` and its conftest puts
      the bundled packages on `sys.path`. Install deps (Presidio also needs a spaCy
      model, e.g. `python -m spacy download en_core_web_lg`) and run the 42-test suite
      from the repo root:

      ```powershell
      pip install -r plugins\cogniva-shareinsights\scripts\Anonymization\requirements.txt
      python -m pytest tests\ShareInsights\Anonymization -q
      ```
      ```
- [x] **Step 4 (plugin.json description):** in
      `plugins/cogniva-shareinsights/.claude-plugin/plugin.json`, replace the
      description value
      ```
      "description": "ShareInsights report-prep tooling. The extract-treesizepro skill turns a raw TreeSize Pro export (.xlsx/.csv) in .restricted/ into a sanitised CSV in the repo root; the prepare-treesizepro skill then turns that CSV into readable folder-structure artifacts (Markdown tree, collapsible HTML tree, optional zoomable D3 treemap), driven by bundled PowerShell scripts.",
      ```
      with
      ```
      "description": "ShareInsights report-prep tooling. The extract-treesizepro skill turns a raw TreeSize Pro export (.xlsx/.csv) in .restricted/ into a sanitised CSV in the repo root, driven by a bundled Python anonymiser engine (treesize_ingest + reversible_name_anonymizer); the prepare-treesizepro skill then turns that CSV into readable folder-structure artifacts (Markdown tree, collapsible HTML tree, optional zoomable D3 treemap), driven by bundled PowerShell scripts.",
      ```
- [x] **Step 5 (sanity-check the JSON parses):** run
      ```bash
      python -c "import json; json.load(open('plugins/cogniva-shareinsights/.claude-plugin/plugin.json')); print('json-ok')"
      ```
      Expected output: `json-ok`
- [x] **Step 6 (commit):**
      `git add plugins/cogniva-shareinsights/scripts/Anonymization/treesize_ingest/__main__.py README.md plugins/cogniva-shareinsights/.claude-plugin/plugin.json`
      then
      `git commit -m "docs(shareinsights): repoint anonymiser path references to the bundled plugin location"`

## ⛔ Task 5: Validate portability from a second repo  (manual validation gate — execute-feature STOPS here)

The whole point of this feature is that `/extract-treesizepro` works *outside* this
repo. That can only be confirmed by the user, with the updated plugin, in another
repo. This is a hard stop.

- [ ] **Step 1:** Make the updated plugin available where the second repo loads it
      from (e.g. update the local marketplace / reinstall `cogniva-shareinsights` so
      its cached copy includes `scripts/Anonymization/`). Confirm the cache now
      contains `…/cogniva-shareinsights/0.1.0/scripts/Anonymization/treesize_ingest/`.
- [ ] **Step 2:** In the *other* repo (one with a `.restricted/` TreeSize export and
      the dataguard allowlist), install the engine deps once:
      `python -m pip install -r "${CLAUDE_PLUGIN_ROOT}/scripts/Anonymization/requirements.txt"`
      (plus the spaCy model, or plan to pass `--detector conventions`).
- [ ] **Step 3:** Run `/extract-treesizepro <export>` there and confirm it resolves
      the bundled engine (no "missing scripts" / no "extractor not installed"
      message) and writes a `*_sanitised.csv`.
- [ ] **Step 4:** Wait for the user to confirm success before this feature is marked
      integrated.
