# macOS XCUI Diff-Selektion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lokal/Agent-Default fährt nur durch Diff berührte `MacUISmokeTests`; `--full` und CI fahren die ganze Klasse; Selection immer lokal, Remote nur Passthrough.

**Architecture:** `macos_ui_select_tests.py` mappt Git-Diff → `-only-testing`-Zeilen. `macos-ui-test.sh` integriert Modes (`--full` / Diff / `--reisen-ui-only-testing`). `macos-ui-test-remote.sh` selektiert lokal, skipped ohne Sync, sonst Passthrough.

**Tech Stack:** Python 3 + unittest, bash 3.2, xcodebuild `-only-testing`, Git merge-base

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-04-macos-ui-diff-select-design.md` (freigegeben) + Remote Rev 7
- Kein Path-Manifest, keine Tags, kein `.xctestplan`, keine Diff-Selektion remote
- Fail-closed bei Selector-Fehlern (kein stilles Full); Skip = Exit 0 + Pflicht-Stderr
- `git diff --check` sauber; UTF-8 ohne BOM für Shell/Python
- Commits nur auf explizite User-Anweisung

---

### Task 1: Selector-Modul + CI-Unit-Tests (TDD)

**Files:**
- Create: `Scripts/macos_ui_select_tests.py`
- Create: `Scripts/tests/test_ci_macos_ui_select_tests.py`

**Interfaces:**
- Produces: `select_only_testing_args(repo_root: Path, *, diff_base: str | None = None) -> list[str]`
  each item like `-only-testing:ReisenMacUITests/MacUISmokeTests/testFoo`
  empty list = skip; raise on hard errors
- Produces: CLI `python3 Scripts/macos_ui_select_tests.py` → stdout lines, exit 0 empty/ok, exit ≠ 0 on error
- Produces: constant `SKIP_STDERR` matching Spec Regel 5

- [x] **Step 1: Write failing unit tests**

Create `Scripts/tests/test_ci_macos_ui_select_tests.py` that loads the module and covers:

```python
# Fixtures: tiny MacUISmokeTests-like sources + synthetic unified diffs OR temp git repos.
# Required cases (assert exact -only-testing lines):
# 1. modify body of testA → only testA
# 2. add new func testB → testB
# 3. delete testC (only - lines) → empty
# 4. change only setUp / non-test lines → empty
# 5. brand-new file content (treat as all tests) → all test* names
# 6. git/diff failure path → raises / CLI exit ≠ 0
```

Prefer testing pure helpers (`test_method_spans`, `changed_new_side_lines`, `select_from_diff`) with string fixtures so no live git is required for most cases; one integration test may use a temp git repo.

- [x] **Step 2: Run tests — expect fail**

```bash
python3 -m unittest Scripts.tests.test_ci_macos_ui_select_tests -v
# or from repo root:
python3 -m unittest discover -s Scripts/tests -p 'test_ci_macos_ui_select_tests.py' -v
```

Expected: FAIL (module missing or empty).

- [x] **Step 3: Implement `Scripts/macos_ui_select_tests.py`**

Minimal shape:

```python
#!/usr/bin/env python3
"""Diff → -only-testing args for MacUISmokeTests (SSOT: 2026-09-04-macos-ui-diff-select-design)."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

SMOKE_REL = Path("Tests/ReisenMacUITests/MacUISmokeTests.swift")
TEST_FUNC_RE = re.compile(r"^(\s*)func (test[A-Za-z0-9_]*)\s*\(")
ONLY_PREFIX = "-only-testing:ReisenMacUITests/MacUISmokeTests/"
SKIP_STDERR = (
    "macos-ui-test: no smoke selection (diff); skip XCUI. "
    "DoD: UI-Verhalten erfordert Smoke-Edit in MacUISmokeTests."
)

def test_method_spans(source: str) -> dict[str, tuple[int, int]]:
    """1-based inclusive line spans for each test* method."""
    ...

def changed_working_tree_lines(diff_text: str) -> set[int]:
    """Map unified diff to new-side line numbers that changed."""
    ...

def select_names(source: str, diff_text: str, *, file_is_new: bool) -> list[str]:
    ...

def resolve_diff_base(repo: Path, override: str | None) -> str:
    if override:
        return override
    # try origin/master then master via merge-base with HEAD (Reisen default branch)
    ...

def git_diff_smoke(repo: Path, base: str) -> tuple[str, bool]:
    """Return (unified_diff, file_is_new). Fail closed on git errors."""
    ...

def select_only_testing_args(repo_root: Path, *, diff_base: str | None = None) -> list[str]:
    ...

def main(argv: list[str] | None = None) -> int:
    ...
```

Algorithm must match Spec: span overlap + new `func test` on `+` lines; deleted-only → empty; new file → all tests.

- [x] **Step 4: Run tests — expect pass**

```bash
python3 -m unittest discover -s Scripts/tests -p 'test_ci_macos_ui_select_tests.py' -v
```

Expected: OK.

- [x] **Step 5: Confirm discover pattern**

```bash
python3 -m unittest discover -s Scripts/tests -p 'test_ci_*.py' -v 2>&1 | tail -20
```

Expected: includes `test_ci_macos_ui_select_tests` without breaking existing `test_ci_*`.

---

### Task 2: `macos-ui-test.sh` — Modes Full / Diff / Passthrough

**Files:**
- Modify: `Scripts/macos-ui-test.sh`

**Interfaces:**
- Consumes: `select_only_testing_args` via `python3 "$ROOT/Scripts/macos_ui_select_tests.py"`
- Produces CLI: `[--self-test] | [--full] | [--reisen-ui-only-testing <args…>]` (Default = Diff)
- CI/`GITHUB_ACTIONS` → force Full class filter

- [x] **Step 1: Parameterize `-only-testing` in helpers**

Change `reisen_macos_ui_common_args` so it does **not** hardcode the class filter. Accept only-testing lines as extra args (or build array in caller):

```bash
# Before (remove hardcode):
#   -only-testing:ReisenMacUITests/MacUISmokeTests \

reisen_macos_ui_common_args() {
  # same project/scheme/destination/derived/result — ohne only-testing
  ...
}

# Caller appends either:
#   -only-testing:ReisenMacUITests/MacUISmokeTests
# or multiple method filters
```

Ensure `reisen_macos_ui_run_unsigned_build_then_adhoc_test` and `reisen_macos_ui_xcodebuild_args` pass the same filters through to both build-for-testing and test-without-building.

- [x] **Step 2: Argv parsing before Generate**

After `--self-test` block (extend self-test in Step 4), parse:

```bash
MODE=diff   # diff | full | passthrough
ONLY_ARGS=()
while (($#)); do
  case "$1" in
    --full) MODE=full; shift ;;
    --reisen-ui-only-testing)
      MODE=passthrough; shift
      while (($#)); do ONLY_ARGS+=("$1"); shift; done
      ;;
    *)
      echo "Fehler: unbekanntes Argument: $1" >&2
      exit 2
      ;;
  esac
done
if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
  MODE=full
fi
```

- [x] **Step 3: Selection / Skip before xcodebuild**

```bash
case "$MODE" in
  full)
    ONLY_ARGS=(-only-testing:ReisenMacUITests/MacUISmokeTests)
    ;;
  passthrough)
    # ONLY_ARGS already set; validate non-empty and prefix
    ;;
  diff)
    ONLY_ARGS=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && ONLY_ARGS+=("$line")
    done < <(python3 "$ROOT/Scripts/macos_ui_select_tests.py" || exit $?)
    if ((${#ONLY_ARGS[@]} == 0)); then
      # emit SKIP_STDERR fail-closed (empty/missing constant → Exit ≠ 0)
      exit 0
    fi
    ;;
esac
```

bash 3.2: `while IFS= read` (kein `mapfile`).

Pass `"${ONLY_ARGS[@]}"` into xcodebuild helpers. Log selected filters on stderr.

- [x] **Step 4: Extend `--self-test`**

Assert:

- Default helper path can emit class-level filter when MODE=full simulated
- Diff path: invoking selector with mocked empty → skip message constant present in script (`grep -Fq` Spec Skip-Stderr)
- `--reisen-ui-only-testing` parsing keeps args
- Under `CI=true`, MODE forced to full (unit-level check via small function or documented branch grep)

- [x] **Step 5: Run self-test**

```bash
bash ./Scripts/macos-ui-test.sh --self-test
```

Expected: `macos-ui-test.sh self-test: OK`

---

### Task 3: `macos-ui-test-remote.sh` — lokale Selection + Passthrough

**Files:**
- Modify: `Scripts/macos-ui-test-remote.sh`
- Already updated Spec Rev 7 in `docs/superpowers/specs/2026-09-02-macos-ui-test-remote-design.md` (verify still matches)

**Interfaces:**
- Consumes: local `macos_ui_select_tests.py` / `--full`
- Produces: remote invoke `bash ./Scripts/macos-ui-test.sh --full` **or**
  `bash ./Scripts/macos-ui-test.sh --reisen-ui-only-testing -only-testing:… …`
- Skip: Exit 0 **before** lock/rsync when Diff empty

- [x] **Step 1: Parse `--full` / `--self-test` at entry**

Preserve `--self-test`. Add `--full`. Default = diff.

- [x] **Step 2: Local select before gates/lock**

Early in main (after ROOT, before expensive remote work when possible — at latest before `reisen_ui_remote_acquire_lock`):

```bash
REMOTE_TEST_ARGS=()
if [[ "$MODE" == "full" ]]; then
  REMOTE_TEST_ARGS=(--full)
else
  # collect ONLY lines; on empty print SKIP_STDERR and exit 0
  REMOTE_TEST_ARGS=(--reisen-ui-only-testing "${ONLY_LINES[@]}")
fi
```

- [x] **Step 3: Inject args into Terminal `.command`**

In `reisen_ui_remote_run_ui_tests`, change hardcoded:

```bash
# alt:
# echo "bash ./Scripts/macos-ui-test.sh > \${log_file} 2>&1"
```

to quoted passthrough of `"${REMOTE_TEST_ARGS[@]}"` (use `printf '%q'` per arg so spaces/colons safe).

Function signature must take the arg list (or global set before call).

- [x] **Step 4: Self-test Passthrough**

Extend `reisen_ui_remote_self_test`:

- `grep` for `--reisen-ui-only-testing` and local selector invocation
- Quoting probe includes a fake `-only-testing:ReisenMacUITests/MacUISmokeTests/testFoo`
- Assert Skip path exists (string match Spec Skip-Stderr or shared constant source)
- Confirm `.command` line is not bare `macos-ui-test.sh` without args placeholder/variable

- [x] **Step 5: Run self-test**

```bash
bash ./Scripts/macos-ui-test-remote.sh --self-test
```

Expected: OK.

---

### Task 4: Docs / Rules / Skill Sync

**Files:**
- Modify: `AGENTS.md`
- Modify: `.cursor/rules/reisen-macos-workflow.mdc`
- Modify: `.cursor/rules/reisen-logging-and-tests.mdc`
- Modify: `.cursor/skills/reisen-observability-tests/SKILL.md`
- Modify: `.cursor/rules/reisen-ci-agents.mdc` (nur wenn XCUI-Zeile dort ohne Diff-Hinweis)

- [x] **Step 1: Agent-Default text**

Überall wo Agents `macos-ui-test-remote.sh` Pflicht ist, ergänzen:

- Default = Diff-Selektion (nur geänderte Smokes; Skip Exit 0 + DoD-Hinweis wenn keine)
- Full on demand: `bash ./Scripts/macos-ui-test-remote.sh --full`
- Spec-Link: `docs/superpowers/specs/2026-09-04-macos-ui-diff-select-design.md`

Beispiel `AGENTS.md`-Tabelle:

```markdown
| macOS XCUI (Agents, iMac) | `bash ./Scripts/macos-ui-test-remote.sh` (Diff-Default); `--full` on demand |
| macOS XCUI (lokal, nur Fallback) | `bash ./Scripts/macos-ui-test.sh` (gleiches Diff/`--full`) |
```

- [x] **Step 2: Observability-Skill Checklist**

UI-Diff checkbox: Remote ohne `--full` reicht nur wenn Smoke-Methoden im Diff; sonst Smoke nachziehen, dann erneut Remote; optional `--full` vor Merge-Review.

- [x] **Step 3: Whitespace**

```bash
git diff --check
```

Expected: clean for touched docs/rules.

---

### Task 5: Verifikation (ohne vollen XCUI wenn Skip)

**Files:** none new

- [x] **Step 1: Python CI discover**

```bash
python3 -m unittest discover -s Scripts/tests -p 'test_ci_*.py' -v
```

Expected: green, includes new module.

- [x] **Step 2: Both shell self-tests**

```bash
bash ./Scripts/macos-ui-test.sh --self-test
bash ./Scripts/macos-ui-test-remote.sh --self-test
```

Expected: both OK.

- [x] **Step 3: Dry local Diff behavior (no full XCUI required)**

From a clean smoke-file vs base (no smoke edits):

```bash
bash ./Scripts/macos-ui-test.sh
```

Expected: Skip-Stderr + Exit 0, **no** long xcodebuild (or exits before test).

With a temporary edit to one `test*` in `MacUISmokeTests.swift` (revert after):

```bash
# edit one assertion line in an existing test
bash ./Scripts/macos-ui-test.sh   # only if local Fallback path intended
# OR print selection only:
python3 Scripts/macos_ui_select_tests.py
```

Expected: exactly one `-only-testing:…/testName` line.

Revert the temporary smoke edit after the check.

- [x] **Step 4: Spec status already freigegeben** — confirm header in design doc.

- [x] **Step 5: Commit nur auf User-Anweisung** (kein Auto-Commit).

---

## Self-Review (Plan vs Spec)

| Spec-Anforderung | Task |
| --- | --- |
| Diff-Selektion lokal, Algorithmus Spans | Task 1 |
| Skip Exit 0 + Skip-Stderr | Task 1–2 |
| `--full` + CI Full | Task 2 |
| `--reisen-ui-only-testing` | Task 2–3 |
| Remote Passthrough, Skip ohne Sync | Task 3 |
| `test_ci_*.py` | Task 1 |
| Docs/Rules/Skill | Task 4 |
| Self-tests / Verifikation | Task 2–3, 5 |
| Remote Spec Rev 7 | bereits in Spec; Task 3 hält Script synchro |
