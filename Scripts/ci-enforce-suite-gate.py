#!/usr/bin/env python3
"""Aggregator-Gate für Reisen CI Suite-Jobs (fail-closed)."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

ALL_SUITES: tuple[str, ...] = (
    "suite-swiftpm",
    "suite-ios-sim",
    "suite-ios-release",
    "suite-macos-ui",
)

ALLOWED_SKIP_REASONS: frozenset[str] = frozenset({"docs-only"})


def load_selection(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(f"selection.json fehlt: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("selection.json muss ein Objekt sein")
    for key in ("mode", "reason", "suites", "skipped"):
        if key not in payload:
            raise ValueError(f"selection.json fehlt Feld: {key}")
    if not isinstance(payload["suites"], list) or not isinstance(payload["skipped"], list):
        raise ValueError("suites/skipped müssen Listen sein")
    return payload


def enforce_suite_gate(
    *,
    selection: dict[str, Any],
    detect_result: str,
    suite_results: dict[str, str],
) -> int:
    if detect_result != "success":
        print(f"Gate fail: detect-suites result={detect_result}", file=sys.stderr)
        return 1

    selected = set(selection["suites"])
    mode = selection["mode"]
    reason = selection["reason"]

    for suite in ALL_SUITES:
        if suite not in suite_results:
            print(f"Gate fail: fehlendes needs-Ergebnis für {suite}", file=sys.stderr)
            return 1

    for suite, result in suite_results.items():
        if result in {"failure", "cancelled"}:
            print(f"Gate fail: {suite} result={result}", file=sys.stderr)
            return 1
        if suite in selected and result != "success":
            print(
                f"Gate fail: selected suite {suite} muss success sein, war {result}",
                file=sys.stderr,
            )
            return 1
        if suite not in selected and result not in {"skipped", "success"}:
            print(
                f"Gate fail: unselected suite {suite} unerwartetes result={result}",
                file=sys.stderr,
            )
            return 1

    if mode == "full":
        for suite in ALL_SUITES:
            if suite_results[suite] != "success":
                print(f"Gate fail: mode=full erfordert success für {suite}", file=sys.stderr)
                return 1

    all_skipped = all(suite_results[s] == "skipped" for s in ALL_SUITES)
    if all_skipped:
        if mode == "empty-allowed" and reason in ALLOWED_SKIP_REASONS and not selected:
            print("Gate ok: empty-allowed docs-only", file=sys.stderr)
            return 0
        print(
            f"Gate fail: alle Suites skipped bei mode={mode} reason={reason}",
            file=sys.stderr,
        )
        return 1

    if mode == "empty-allowed":
        if reason not in ALLOWED_SKIP_REASONS or selected:
            print(
                f"Gate fail: empty-allowed ungültig (reason={reason} suites={selected})",
                file=sys.stderr,
            )
            return 1

    print(
        f"Gate ok: mode={mode} reason={reason} suites={sorted(selected)}",
        file=sys.stderr,
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Reisen CI Suite Aggregator Gate")
    parser.add_argument(
        "--selection",
        type=Path,
        default=Path(os.environ.get("SELECTION_PATH", "selection.json")),
    )
    parser.add_argument(
        "--detect-result",
        default=os.environ.get("DETECT_RESULT", ""),
    )
    parser.add_argument("--swiftpm-result", default=os.environ.get("SUITE_SWIFTPM_RESULT", ""))
    parser.add_argument("--ios-sim-result", default=os.environ.get("SUITE_IOS_SIM_RESULT", ""))
    parser.add_argument("--ios-release-result", default=os.environ.get("SUITE_IOS_RELEASE_RESULT", ""))
    parser.add_argument("--macos-ui-result", default=os.environ.get("SUITE_MACOS_UI_RESULT", ""))
    args = parser.parse_args(argv)

    try:
        selection = load_selection(args.selection)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"Gate fail: {exc}", file=sys.stderr)
        return 1

    suite_results = {
        "suite-swiftpm": args.swiftpm_result,
        "suite-ios-sim": args.ios_sim_result,
        "suite-ios-release": args.ios_release_result,
        "suite-macos-ui": args.macos_ui_result,
    }
    if not args.detect_result or any(not v for v in suite_results.values()):
        print("Gate fail: DETECT_RESULT / SUITE_*_RESULT fehlen", file=sys.stderr)
        return 1

    return enforce_suite_gate(
        selection=selection,
        detect_result=args.detect_result,
        suite_results=suite_results,
    )


if __name__ == "__main__":
    raise SystemExit(main())
