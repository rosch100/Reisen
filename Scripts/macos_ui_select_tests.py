#!/usr/bin/env python3
"""Diff → -only-testing args for MacUISmokeTests (SSOT: 2026-09-04-macos-ui-diff-select-design)."""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

SMOKE_REL = Path("Tests/ReisenMacUITests/MacUISmokeTests.swift")
TEST_FUNC_RE = re.compile(r"^(\s*)func (test[A-Za-z0-9_]*)\s*\(")
NEW_TEST_FUNC_RE = re.compile(r"^\+\s*func (test[A-Za-z0-9_]*)\s*\(")
ONLY_PREFIX = "-only-testing:ReisenMacUITests/MacUISmokeTests/"
SKIP_STDERR = (
    "macos-ui-test: no smoke selection (diff); skip XCUI. "
    "DoD: UI-Verhalten erfordert Smoke-Edit in MacUISmokeTests."
)


def test_method_spans(source: str) -> dict[str, tuple[int, int]]:
    """1-based inclusive line spans for each test* method."""
    lines = source.splitlines()
    matches: list[tuple[int, str]] = []
    for index, line in enumerate(lines, start=1):
        match = TEST_FUNC_RE.match(line)
        if match is not None:
            matches.append((index, match.group(2)))

    spans: dict[str, tuple[int, int]] = {}
    for idx, (start_line, name) in enumerate(matches):
        if idx + 1 < len(matches):
            end_line = matches[idx + 1][0] - 1
        else:
            end_line = len(lines)
        spans[name] = (start_line, end_line)
    return spans


def changed_working_tree_lines(diff_text: str) -> set[int]:
    """Map unified diff to new-side line numbers that changed."""
    changed: set[int] = set()
    new_line = 0
    in_hunk = False

    for raw_line in diff_text.splitlines():
        if raw_line.startswith("diff --git") or raw_line.startswith("--- ") or raw_line.startswith("+++ "):
            in_hunk = False
            continue

        if raw_line.startswith("@@"):
            match = re.match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", raw_line)
            if match is None:
                raise ValueError(f"invalid unified diff hunk header: {raw_line!r}")
            new_line = int(match.group(1))
            in_hunk = True
            continue

        if not in_hunk:
            continue

        if raw_line.startswith("\\"):
            continue

        prefix = raw_line[:1] if raw_line else ""
        if prefix == " ":
            new_line += 1
        elif prefix == "+":
            # Blank insertions between methods must not select the previous span.
            if raw_line[1:].strip():
                changed.add(new_line)
            new_line += 1
        elif prefix == "-":
            continue
        elif prefix == "":
            continue
        else:
            raise ValueError(f"unexpected diff line: {raw_line!r}")

    return changed


def _newly_introduced_test_names(diff_text: str) -> set[str]:
    names: set[str] = set()
    for line in diff_text.splitlines():
        match = NEW_TEST_FUNC_RE.match(line)
        if match is not None:
            names.add(match.group(1))
    return names


def select_names(source: str, diff_text: str, *, file_is_new: bool) -> list[str]:
    spans = test_method_spans(source)
    if file_is_new:
        return sorted(spans.keys())

    changed_lines = changed_working_tree_lines(diff_text)
    introduced = _newly_introduced_test_names(diff_text)
    selected: set[str] = set()

    for name, (start, end) in spans.items():
        if name in introduced:
            selected.add(name)
            continue
        span_lines = range(start, end + 1)
        if any(line in changed_lines for line in span_lines):
            selected.add(name)

    return sorted(selected)


def resolve_diff_base(repo: Path, override: str | None) -> str:
    if override:
        return override

    env_override = os.environ.get("REISEN_MAC_UI_DIFF_BASE")
    if env_override:
        return env_override

    for ref in ("origin/master", "master"):
        result = subprocess.run(
            ["git", "merge-base", "HEAD", ref],
            cwd=repo,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()

    raise RuntimeError(
        "macos_ui_select_tests: merge-base failed for origin/master and master"
    )


def _run_git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=repo,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise RuntimeError(f"macos_ui_select_tests: git {' '.join(args)} failed: {detail}")
    return result.stdout


def git_diff_smoke(repo: Path, base: str) -> tuple[str, bool]:
    """Return (unified_diff, file_is_new). Fail closed on git errors."""
    smoke = str(SMOKE_REL)
    smoke_path = repo / SMOKE_REL
    diff_text = _run_git(repo, "diff", base, "--", smoke)
    if diff_text.strip():
        file_is_new = "new file mode" in diff_text or (
            diff_text.startswith("diff --git") and "--- /dev/null" in diff_text
        )
        return diff_text, file_is_new

    # Untracked or otherwise absent from base: `git diff` is empty — Spec Regel 6.
    base_has = subprocess.run(
        ["git", "cat-file", "-e", f"{base}:{smoke}"],
        cwd=repo,
        capture_output=True,
        text=True,
    )
    if base_has.returncode != 0 and smoke_path.is_file():
        return "", True
    return "", False


def select_only_testing_args(repo_root: Path, *, diff_base: str | None = None) -> list[str]:
    repo = repo_root.resolve()
    smoke_path = repo / SMOKE_REL
    if not smoke_path.is_file():
        raise RuntimeError(f"macos_ui_select_tests: missing {SMOKE_REL}")

    source = smoke_path.read_text(encoding="utf-8")
    base = resolve_diff_base(repo, diff_base)
    diff_text, file_is_new = git_diff_smoke(repo, base)
    names = select_names(source, diff_text, file_is_new=file_is_new)
    return [f"{ONLY_PREFIX}{name}" for name in names]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Select MacUISmokeTests -only-testing args from local git diff.",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path.cwd(),
        help="Repository root (default: cwd)",
    )
    parser.add_argument(
        "--diff-base",
        default=None,
        help="Git ref/commit for diff base (overrides REISEN_MAC_UI_DIFF_BASE)",
    )
    args = parser.parse_args(argv)

    try:
        selected = select_only_testing_args(args.repo_root, diff_base=args.diff_base)
    except (RuntimeError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1

    for line in selected:
        print(line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
