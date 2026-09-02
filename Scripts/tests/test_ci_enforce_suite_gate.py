#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "Scripts"
SCRIPT = SCRIPTS / "ci-enforce-suite-gate.py"

if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import ci_suite_constants  # noqa: E402


def load_module():
    spec = importlib.util.spec_from_file_location("ci_enforce_suite_gate", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError("ci-enforce-suite-gate.py nicht ladbar")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class CiEnforceSuiteGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mod = load_module()

    def _selection(self, mode: str, reason: str, suites: list[str]) -> dict:
        skipped = [s for s in self.mod.ALL_SUITES if s not in suites]
        return {
            "mode": mode,
            "reason": reason,
            "baselines": {},
            "suites": suites,
            "skipped": skipped,
            "changedFilesSample": [],
        }

    def _results(self, **overrides: str) -> dict[str, str]:
        base = {suite: "skipped" for suite in self.mod.ALL_SUITES}
        base.update(overrides)
        return base

    def test_suite_failure_fails_gate(self) -> None:
        code = self.mod.enforce_suite_gate(
            selection=self._selection("affected", "affected", ["suite-swiftpm"]),
            detect_result="success",
            suite_results=self._results(**{"suite-swiftpm": "failure"}),
        )
        self.assertEqual(code, 1)

    def test_docs_only_all_skipped_ok(self) -> None:
        code = self.mod.enforce_suite_gate(
            selection=self._selection("empty-allowed", "docs-only", []),
            detect_result="success",
            suite_results=self._results(),
        )
        self.assertEqual(code, 0)

    def test_affected_all_skipped_fails(self) -> None:
        code = self.mod.enforce_suite_gate(
            selection=self._selection("affected", "affected", []),
            detect_result="success",
            suite_results=self._results(),
        )
        self.assertEqual(code, 1)

    def test_selected_skipped_fails(self) -> None:
        code = self.mod.enforce_suite_gate(
            selection=self._selection("affected", "affected", ["suite-swiftpm"]),
            detect_result="success",
            suite_results=self._results(**{"suite-swiftpm": "skipped"}),
        )
        self.assertEqual(code, 1)

    def test_full_success_ok(self) -> None:
        code = self.mod.enforce_suite_gate(
            selection=self._selection("full", "harness", list(self.mod.ALL_SUITES)),
            detect_result="success",
            suite_results=self._results(
                **{
                    "suite-swiftpm": "success",
                    "suite-ios-sim": "success",
                    "suite-ios-release": "success",
                    "suite-macos-ui": "success",
                }
            ),
        )
        self.assertEqual(code, 0)

    def test_detect_failure_fails(self) -> None:
        code = self.mod.enforce_suite_gate(
            selection=self._selection("full", "harness", list(self.mod.ALL_SUITES)),
            detect_result="failure",
            suite_results=self._results(),
        )
        self.assertEqual(code, 1)

    def test_empty_allowed_with_suite_success_fails(self) -> None:
        code = self.mod.enforce_suite_gate(
            selection=self._selection("empty-allowed", "docs-only", []),
            detect_result="success",
            suite_results=self._results(**{"suite-swiftpm": "success"}),
        )
        self.assertEqual(code, 1)

    def test_affected_empty_suites_with_success_fails(self) -> None:
        code = self.mod.enforce_suite_gate(
            selection=self._selection("affected", "affected", []),
            detect_result="success",
            suite_results=self._results(**{"suite-swiftpm": "success"}),
        )
        self.assertEqual(code, 1)

    def test_all_suites_match_constants_ssot(self) -> None:
        self.assertEqual(self.mod.ALL_SUITES, ci_suite_constants.ALL_SUITES)

    def test_missing_selection_file_fails_main(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            missing = Path(tmp) / "missing.json"
            code = self.mod.main(
                [
                    "--selection",
                    str(missing),
                    "--detect-result",
                    "success",
                    "--swiftpm-result",
                    "skipped",
                    "--ios-sim-result",
                    "skipped",
                    "--ios-release-result",
                    "skipped",
                    "--macos-ui-result",
                    "skipped",
                ]
            )
        self.assertEqual(code, 1)

    def test_load_selection_roundtrip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "selection.json"
            payload = self._selection("empty-allowed", "docs-only", [])
            path.write_text(json.dumps(payload), encoding="utf-8")
            loaded = self.mod.load_selection(path)
            self.assertEqual(loaded["mode"], "empty-allowed")


if __name__ == "__main__":
    unittest.main()
