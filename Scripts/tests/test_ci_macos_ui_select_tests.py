#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts" / "macos_ui_select_tests.py"

SAMPLE_SOURCE = """\
import XCTest

final class MacUISmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAlpha() {
        XCTAssertTrue(true)
    }

    func testBeta() {
        XCTAssertEqual(1, 1)
    }

    func testGamma() {
        XCTAssertFalse(false)
    }
}
"""


def load_module():
    spec = importlib.util.spec_from_file_location("macos_ui_select_tests", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError("macos_ui_select_tests.py nicht ladbar")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MacosUiSelectTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mod = load_module()

    def test_skip_stderr_matches_spec(self) -> None:
        self.assertIn("no smoke selection (diff)", self.mod.SKIP_STDERR)
        self.assertIn("DoD:", self.mod.SKIP_STDERR)
        self.assertIn("MacUISmokeTests", self.mod.SKIP_STDERR)

    def test_spans_cover_test_methods_only(self) -> None:
        spans = self.mod.test_method_spans(SAMPLE_SOURCE)
        self.assertEqual(set(spans), {"testAlpha", "testBeta", "testGamma"})
        self.assertEqual(spans["testAlpha"][0], 8)
        self.assertLess(spans["testAlpha"][1], spans["testBeta"][0])

    def test_modify_body_selects_only_that_test(self) -> None:
        # Change assertion inside testBeta (working-tree line ~13).
        diff = """\
diff --git a/Tests/ReisenMacUITests/MacUISmokeTests.swift b/Tests/ReisenMacUITests/MacUISmokeTests.swift
--- a/Tests/ReisenMacUITests/MacUISmokeTests.swift
+++ b/Tests/ReisenMacUITests/MacUISmokeTests.swift
@@ -10,7 +10,7 @@ final class MacUISmokeTests: XCTestCase {
     }

     func testBeta() {
-        XCTAssertEqual(1, 1)
+        XCTAssertEqual(2, 2)
     }

     func testGamma() {
"""
        names = self.mod.select_names(SAMPLE_SOURCE, diff, file_is_new=False)
        self.assertEqual(names, ["testBeta"])
        args = [f"{self.mod.ONLY_PREFIX}{n}" for n in names]
        self.assertEqual(
            args,
            ["-only-testing:ReisenMacUITests/MacUISmokeTests/testBeta"],
        )

    def test_add_new_func_selects_new_test(self) -> None:
        source = SAMPLE_SOURCE.replace(
            "    func testGamma() {\n        XCTAssertFalse(false)\n    }\n}\n",
            "    func testGamma() {\n        XCTAssertFalse(false)\n    }\n\n"
            "    func testDelta() {\n        XCTAssertTrue(true)\n    }\n}\n",
        )
        diff = """\
diff --git a/Tests/ReisenMacUITests/MacUISmokeTests.swift b/Tests/ReisenMacUITests/MacUISmokeTests.swift
--- a/Tests/ReisenMacUITests/MacUISmokeTests.swift
+++ b/Tests/ReisenMacUITests/MacUISmokeTests.swift
@@ -16,4 +16,8 @@ final class MacUISmokeTests: XCTestCase {
     func testGamma() {
         XCTAssertFalse(false)
     }
+
+    func testDelta() {
+        XCTAssertTrue(true)
+    }
 }
"""
        names = self.mod.select_names(source, diff, file_is_new=False)
        self.assertEqual(names, ["testDelta"])

    def test_delete_only_yields_empty(self) -> None:
        source = SAMPLE_SOURCE.replace(
            "\n    func testGamma() {\n        XCTAssertFalse(false)\n    }",
            "",
        )
        diff = """\
diff --git a/Tests/ReisenMacUITests/MacUISmokeTests.swift b/Tests/ReisenMacUITests/MacUISmokeTests.swift
--- a/Tests/ReisenMacUITests/MacUISmokeTests.swift
+++ b/Tests/ReisenMacUITests/MacUISmokeTests.swift
@@ -12,8 +12,4 @@ final class MacUISmokeTests: XCTestCase {
     func testBeta() {
         XCTAssertEqual(1, 1)
     }
-
-    func testGamma() {
-        XCTAssertFalse(false)
-    }
 }
"""
        names = self.mod.select_names(source, diff, file_is_new=False)
        self.assertEqual(names, [])

    def test_setup_only_change_yields_empty(self) -> None:
        diff = """\
diff --git a/Tests/ReisenMacUITests/MacUISmokeTests.swift b/Tests/ReisenMacUITests/MacUISmokeTests.swift
--- a/Tests/ReisenMacUITests/MacUISmokeTests.swift
+++ b/Tests/ReisenMacUITests/MacUISmokeTests.swift
@@ -3,7 +3,7 @@ import XCTest
 final class MacUISmokeTests: XCTestCase {
     override func setUp() {
-        continueAfterFailure = false
+        continueAfterFailure = true
     }

     func testAlpha() {
"""
        names = self.mod.select_names(SAMPLE_SOURCE, diff, file_is_new=False)
        self.assertEqual(names, [])

    def test_new_file_selects_all_tests(self) -> None:
        names = self.mod.select_names(SAMPLE_SOURCE, "", file_is_new=True)
        self.assertEqual(names, ["testAlpha", "testBeta", "testGamma"])

    def test_invalid_hunk_raises(self) -> None:
        with self.assertRaises(ValueError):
            self.mod.changed_working_tree_lines("@@ bogus @@\n+foo\n")

    def test_cli_diff_base_override_beats_env(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            smoke = repo / "Tests" / "ReisenMacUITests"
            smoke.mkdir(parents=True)
            (smoke / "MacUISmokeTests.swift").write_text(SAMPLE_SOURCE, encoding="utf-8")
            subprocess.run(["git", "init"], cwd=repo, check=True, capture_output=True)
            subprocess.run(
                ["git", "config", "user.email", "test@example.com"],
                cwd=repo,
                check=True,
                capture_output=True,
            )
            subprocess.run(
                ["git", "config", "user.name", "test"],
                cwd=repo,
                check=True,
                capture_output=True,
            )
            subprocess.run(["git", "add", "."], cwd=repo, check=True, capture_output=True)
            subprocess.run(
                ["git", "commit", "-m", "base"],
                cwd=repo,
                check=True,
                capture_output=True,
            )
            base = subprocess.check_output(
                ["git", "rev-parse", "HEAD"],
                cwd=repo,
                text=True,
            ).strip()

            edited = SAMPLE_SOURCE.replace(
                "XCTAssertEqual(1, 1)",
                "XCTAssertEqual(9, 9)",
            )
            (smoke / "MacUISmokeTests.swift").write_text(edited, encoding="utf-8")

            prev = os.environ.get("REISEN_MAC_UI_DIFF_BASE")
            os.environ["REISEN_MAC_UI_DIFF_BASE"] = "this-ref-must-not-be-used"
            try:
                # CLI --diff-base must win over invalid env.
                selected = self.mod.select_only_testing_args(repo, diff_base=base)
                self.assertEqual(
                    selected,
                    ["-only-testing:ReisenMacUITests/MacUISmokeTests/testBeta"],
                )
                with self.assertRaises(RuntimeError):
                    self.mod.select_only_testing_args(repo, diff_base=None)
            finally:
                if prev is None:
                    os.environ.pop("REISEN_MAC_UI_DIFF_BASE", None)
                else:
                    os.environ["REISEN_MAC_UI_DIFF_BASE"] = prev


if __name__ == "__main__":
    unittest.main()
