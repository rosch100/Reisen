#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts" / "ci-select-suites.py"


def load_module():
    spec = importlib.util.spec_from_file_location("ci_select_suites", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError("ci-select-suites.py nicht ladbar")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class CiSelectSuitesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mod = load_module()

    def _baselines(self, sha: str = "abc") -> dict:
        return {suite: sha for suite in self.mod.ALL_SUITES}

    def test_docs_only_empty_allowed(self) -> None:
        result = self.mod.select_suites(
            changed_files=["docs/ci/README.md", "README.md"],
            baselines=self._baselines(),
            force_full=False,
            push_to_default=False,
        )
        self.assertEqual(result["mode"], "empty-allowed")
        self.assertEqual(result["reason"], "docs-only")
        self.assertEqual(result["suites"], [])

    def test_domain_maps_swiftpm(self) -> None:
        result = self.mod.select_suites(
            changed_files=["Sources/ReisenDomain/Entities/Booking.swift"],
            baselines=self._baselines(),
            force_full=False,
            push_to_default=False,
        )
        self.assertEqual(result["mode"], "affected")
        self.assertIn("suite-swiftpm", result["suites"])
        self.assertNotIn("suite-ios-sim", result["suites"])

    def test_ios_app_maps_both_ios_suites(self) -> None:
        result = self.mod.select_suites(
            changed_files=["Apps/ReiseniOS/App.swift"],
            baselines=self._baselines(),
            force_full=False,
            push_to_default=False,
        )
        self.assertEqual(result["mode"], "affected")
        self.assertEqual(
            set(result["suites"]),
            {"suite-ios-sim", "suite-ios-release"},
        )

    def test_shared_ui_maps_all_suites(self) -> None:
        result = self.mod.select_suites(
            changed_files=["Sources/ReisenSharedUI/SettingsView.swift"],
            baselines=self._baselines(),
            force_full=False,
            push_to_default=False,
        )
        self.assertEqual(result["mode"], "affected")
        self.assertEqual(set(result["suites"]), set(self.mod.ALL_SUITES))

    def test_workflow_touch_full(self) -> None:
        result = self.mod.select_suites(
            changed_files=[".github/workflows/ci.yml"],
            baselines=self._baselines(),
            force_full=True,
            push_to_default=False,
        )
        self.assertEqual(result["mode"], "full")
        self.assertEqual(result["suites"], list(self.mod.ALL_SUITES))

    def test_missing_last_green_selects_suite(self) -> None:
        baselines = self._baselines()
        baselines["suite-macos-ui"] = None
        result = self.mod.select_suites(
            changed_files=["docs/ci/README.md"],
            baselines=baselines,
            force_full=False,
            push_to_default=False,
        )
        self.assertIn("suite-macos-ui", result["suites"])
        self.assertNotEqual(result["mode"], "empty-allowed")

    def test_push_master_full(self) -> None:
        result = self.mod.select_suites(
            changed_files=["docs/ci/README.md"],
            baselines=self._baselines(),
            force_full=False,
            push_to_default=True,
        )
        self.assertEqual(result["mode"], "full")

    def test_package_swift_is_harness(self) -> None:
        self.assertTrue(self.mod.is_harness_path("Package.swift"))


if __name__ == "__main__":
    unittest.main()
