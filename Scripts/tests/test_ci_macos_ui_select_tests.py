#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import io
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts" / "macos_ui_select_tests.py"
SMOKE_REL = Path("Tests/ReisenMacUITests/MacUISmokeTests.swift")
ONLY_PREFIX = "-only-testing:ReisenMacUITests/MacUISmokeTests/"


def load_module():
    spec = importlib.util.spec_from_file_location("macos_ui_select_tests", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError("macos_ui_select_tests.py nicht ladbar")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def only_testing_lines(names: list[str]) -> list[str]:
    return [f"{ONLY_PREFIX}{name}" for name in names]


def init_git_repo(repo: Path, *, initial_branch: str = "master") -> None:
    subprocess.run(
        ["git", "init", "-b", initial_branch],
        cwd=repo,
        check=True,
        capture_output=True,
        text=True,
    )
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        cwd=repo,
        check=True,
        capture_output=True,
        text=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=repo,
        check=True,
        capture_output=True,
        text=True,
    )


def write_smoke(repo: Path, source: str) -> Path:
    smoke_path = repo / SMOKE_REL
    smoke_path.parent.mkdir(parents=True, exist_ok=True)
    smoke_path.write_text(source, encoding="utf-8")
    return smoke_path


SAMPLE_SOURCE = """\
import XCTest

@MainActor
final class MacUISmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testA() {
        let x = 1
    }

    func testC() {
        let y = 2
    }
}
"""

SOURCE_WITH_B = """\
import XCTest

@MainActor
final class MacUISmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testA() {
        let x = 1
    }

    func testB() {
        let z = 3
    }

    func testC() {
        let y = 2
    }
}
"""


class MacosUiSelectTestsPure(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mod = load_module()

    def test_skip_stderr_matches_spec(self) -> None:
        self.assertEqual(
            self.mod.SKIP_STDERR,
            "macos-ui-test: no smoke selection (diff); skip XCUI. "
            "DoD: UI-Verhalten erfordert Smoke-Edit in MacUISmokeTests.",
        )

    def test_modify_testA_body_selects_only_testA(self) -> None:
        diff = """\
diff --git a/Tests/ReisenMacUITests/MacUISmokeTests.swift b/Tests/ReisenMacUITests/MacUISmokeTests.swift
index 1111111..2222222 100644
--- a/Tests/ReisenMacUITests/MacUISmokeTests.swift
+++ b/Tests/ReisenMacUITests/MacUISmokeTests.swift
@@ -8,7 +8,7 @@ final class MacUISmokeTests: XCTestCase {
     }

     func testA() {
-        let x = 1
+        let x = 42
     }

     func testC() {
"""
        names = self.mod.select_names(SAMPLE_SOURCE, diff, file_is_new=False)
        self.assertEqual(names, ["testA"])
        self.assertEqual(
            only_testing_lines(names),
            ["-only-testing:ReisenMacUITests/MacUISmokeTests/testA"],
        )

    def test_add_new_func_testB_selects_testB(self) -> None:
        diff = """\
diff --git a/Tests/ReisenMacUITests/MacUISmokeTests.swift b/Tests/ReisenMacUITests/MacUISmokeTests.swift
index 1111111..2222222 100644
--- a/Tests/ReisenMacUITests/MacUISmokeTests.swift
+++ b/Tests/ReisenMacUITests/MacUISmokeTests.swift
@@ -11,6 +11,10 @@ final class MacUISmokeTests: XCTestCase {
         let x = 1
     }

+    func testB() {
+        let z = 3
+    }
+
     func testC() {
         let y = 2
     }
"""
        names = self.mod.select_names(SOURCE_WITH_B, diff, file_is_new=False)
        self.assertEqual(names, ["testB"])
        self.assertEqual(
            only_testing_lines(names),
            ["-only-testing:ReisenMacUITests/MacUISmokeTests/testB"],
        )

    def test_blank_line_insertion_between_methods_does_not_select(self) -> None:
        """Rev 2: pure + blank lines must not overlap the previous test span."""
        diff = """\
diff --git a/Tests/ReisenMacUITests/MacUISmokeTests.swift b/Tests/ReisenMacUITests/MacUISmokeTests.swift
index 1111111..2222222 100644
--- a/Tests/ReisenMacUITests/MacUISmokeTests.swift
+++ b/Tests/ReisenMacUITests/MacUISmokeTests.swift
@@ -11,6 +11,8 @@ final class MacUISmokeTests: XCTestCase {
         let x = 1
     }

+
+
     func testC() {
         let y = 2
     }
"""
        names = self.mod.select_names(SAMPLE_SOURCE, diff, file_is_new=False)
        self.assertEqual(names, [])

    def test_delete_testC_only_minus_lines_empty(self) -> None:
        source_after_delete = """\
import XCTest

@MainActor
final class MacUISmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testA() {
        let x = 1
    }
}
"""
        diff = """\
diff --git a/Tests/ReisenMacUITests/MacUISmokeTests.swift b/Tests/ReisenMacUITests/MacUISmokeTests.swift
index 1111111..2222222 100644
--- a/Tests/ReisenMacUITests/MacUISmokeTests.swift
+++ b/Tests/ReisenMacUITests/MacUISmokeTests.swift
@@ -11,9 +11,5 @@ final class MacUISmokeTests: XCTestCase {
         let x = 1
     }

-    func testC() {
-        let y = 2
-    }
 }
"""
        names = self.mod.select_names(source_after_delete, diff, file_is_new=False)
        self.assertEqual(names, [])

    def test_change_only_setup_empty(self) -> None:
        source = """\
import XCTest

@MainActor
final class MacUISmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    func testA() {
        let x = 1
    }
}
"""
        diff = """\
diff --git a/Tests/ReisenMacUITests/MacUISmokeTests.swift b/Tests/ReisenMacUITests/MacUISmokeTests.swift
index 1111111..2222222 100644
--- a/Tests/ReisenMacUITests/MacUISmokeTests.swift
+++ b/Tests/ReisenMacUITests/MacUISmokeTests.swift
@@ -3,7 +3,7 @@ import XCTest
 @MainActor
 final class MacUISmokeTests: XCTestCase {
     override func setUp() {
-        continueAfterFailure = false
+        continueAfterFailure = true
     }

     func testA() {
"""
        names = self.mod.select_names(source, diff, file_is_new=False)
        self.assertEqual(names, [])

    def test_brand_new_file_selects_all_tests(self) -> None:
        source = """\
import XCTest

@MainActor
final class MacUISmokeTests: XCTestCase {
    func testAlpha() {
    }

    func testBeta() {
    }
}
"""
        names = self.mod.select_names(source, "", file_is_new=True)
        self.assertEqual(names, ["testAlpha", "testBeta"])

    def test_test_method_spans(self) -> None:
        spans = self.mod.test_method_spans(SAMPLE_SOURCE)
        self.assertEqual(set(spans.keys()), {"testA", "testC"})
        self.assertLess(spans["testA"][0], spans["testA"][1])
        self.assertLess(spans["testC"][0], spans["testC"][1])

    def test_changed_working_tree_lines(self) -> None:
        diff = """\
@@ -8,7 +8,7 @@ final class MacUISmokeTests: XCTestCase {
     }

     func testA() {
-        let x = 1
+        let x = 42
     }
"""
        changed = self.mod.changed_working_tree_lines(diff)
        self.assertIn(10, changed)

    def test_concatenated_diff_resets_hunk_state(self) -> None:
        """Regression: concatenated git diff output must not crash the parser."""
        diff = """\
diff --git a/Tests/ReisenMacUITests/MacUISmokeTests.swift b/Tests/ReisenMacUITests/MacUISmokeTests.swift
index 1111111..2222222 100644
--- a/Tests/ReisenMacUITests/MacUISmokeTests.swift
+++ b/Tests/ReisenMacUITests/MacUISmokeTests.swift
@@ -8,7 +8,7 @@ final class MacUISmokeTests: XCTestCase {
     }

     func testA() {
-        let x = 1
+        let x = 42
     }

     func testC() {
diff --git a/Tests/ReisenMacUITests/MacUISmokeTests.swift b/Tests/ReisenMacUITests/MacUISmokeTests.swift
index 1111111..3333333 100644
--- a/Tests/ReisenMacUITests/MacUISmokeTests.swift
+++ b/Tests/ReisenMacUITests/MacUISmokeTests.swift
@@ -8,7 +8,7 @@ final class MacUISmokeTests: XCTestCase {
     }

     func testA() {
-        let x = 1
+        let x = 99
     }
"""
        names = self.mod.select_names(SAMPLE_SOURCE, diff, file_is_new=False)
        self.assertEqual(names, ["testA"])

    def test_invalid_hunk_raises_value_error(self) -> None:
        with self.assertRaises(ValueError):
            self.mod.changed_working_tree_lines("@@ invalid @@\n+line\n")

    def test_main_value_error_no_traceback(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            write_smoke(repo, SAMPLE_SOURCE)
            init_git_repo(repo)
            subprocess.run(["git", "add", "."], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-m", "initial"], cwd=repo, check=True)
            stderr = io.StringIO()
            with mock.patch.object(
                self.mod,
                "git_diff_smoke",
                return_value=("@@ invalid @@\n+line\n", False),
            ):
                with mock.patch("sys.stderr", stderr):
                    code = self.mod.main(["--repo-root", str(repo)])
            self.assertNotEqual(code, 0)
            self.assertIn("invalid unified diff hunk header", stderr.getvalue())
            self.assertNotIn("Traceback", stderr.getvalue())


class MacosUiSelectTestsGit(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mod = load_module()

    def test_git_diff_failure_raises(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            with self.assertRaises(RuntimeError):
                self.mod.git_diff_smoke(repo, "HEAD")

    def test_select_only_testing_args_integration(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            smoke_path = write_smoke(repo, SAMPLE_SOURCE)
            init_git_repo(repo)
            subprocess.run(["git", "add", "."], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-m", "initial"], cwd=repo, check=True)
            text = smoke_path.read_text(encoding="utf-8")
            smoke_path.write_text(
                text.replace("let x = 1", "let x = 99"),
                encoding="utf-8",
            )
            args = self.mod.select_only_testing_args(repo)
            self.assertEqual(
                args,
                ["-only-testing:ReisenMacUITests/MacUISmokeTests/testA"],
            )

    def test_staged_smoke_change_selects_method(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            smoke_path = write_smoke(repo, SAMPLE_SOURCE)
            init_git_repo(repo)
            subprocess.run(["git", "add", "."], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-m", "initial"], cwd=repo, check=True)
            text = smoke_path.read_text(encoding="utf-8")
            smoke_path.write_text(
                text.replace("let x = 1", "let x = 77"),
                encoding="utf-8",
            )
            subprocess.run(["git", "add", str(SMOKE_REL)], cwd=repo, check=True)
            args = self.mod.select_only_testing_args(repo)
            self.assertEqual(
                args,
                ["-only-testing:ReisenMacUITests/MacUISmokeTests/testA"],
            )
            env = os.environ.copy()
            env.pop("REISEN_MAC_UI_DIFF_BASE", None)
            result = subprocess.run(
                ["python3", str(SCRIPT), "--repo-root", str(repo)],
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(result.returncode, 0)
            self.assertEqual(
                result.stdout.strip(),
                "-only-testing:ReisenMacUITests/MacUISmokeTests/testA",
            )

    def test_resolve_diff_base_prefers_origin_master(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            bare = tmp_path / "origin.git"
            repo = tmp_path / "work"
            repo.mkdir()
            bare.mkdir()
            subprocess.run(
                ["git", "init", "--bare", "-b", "master"],
                cwd=bare,
                check=True,
                capture_output=True,
                text=True,
            )
            init_git_repo(repo, initial_branch="dev")
            (repo / "README.md").write_text("1\n", encoding="utf-8")
            subprocess.run(["git", "add", "."], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-m", "c1"], cwd=repo, check=True)
            c1 = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=repo,
                capture_output=True,
                text=True,
                check=True,
            ).stdout.strip()
            subprocess.run(
                ["git", "remote", "add", "origin", str(bare)],
                cwd=repo,
                check=True,
            )
            subprocess.run(
                ["git", "push", "origin", "dev:master"],
                cwd=repo,
                check=True,
                capture_output=True,
                text=True,
            )
            (repo / "README.md").write_text("2\n", encoding="utf-8")
            subprocess.run(["git", "add", "."], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-m", "c2"], cwd=repo, check=True)

            calls: list[list[str]] = []
            original_run = subprocess.run

            def tracking_run(cmd, **kwargs):
                calls.append(list(cmd))
                return original_run(cmd, **kwargs)

            env = os.environ.copy()
            env.pop("REISEN_MAC_UI_DIFF_BASE", None)
            with mock.patch("subprocess.run", side_effect=tracking_run):
                base = self.mod.resolve_diff_base(repo, None)

            self.assertEqual(base, c1)
            merge_cmds = [
                c
                for c in calls
                if len(c) >= 4 and c[0] == "git" and c[1] == "merge-base"
            ]
            self.assertEqual(len(merge_cmds), 1)
            self.assertEqual(merge_cmds[0], ["git", "merge-base", "HEAD", "origin/master"])

    def test_diff_base_cli_overrides_env(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            write_smoke(repo, SAMPLE_SOURCE)
            init_git_repo(repo)
            subprocess.run(["git", "add", "."], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-m", "initial"], cwd=repo, check=True)
            head = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=repo,
                capture_output=True,
                text=True,
                check=True,
            ).stdout.strip()
            env = os.environ.copy()
            env["REISEN_MAC_UI_DIFF_BASE"] = head
            result = subprocess.run(
                [
                    "python3",
                    str(SCRIPT),
                    "--repo-root",
                    str(repo),
                    "--diff-base",
                    head,
                ],
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.strip(), "")

    def test_cli_exit_nonzero_on_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            result = subprocess.run(
                ["python3", str(SCRIPT)],
                cwd=repo,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("Traceback", result.stderr)

    def test_cli_empty_stdout_exit_zero(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            smoke_path = repo / SMOKE_REL
            smoke_path.parent.mkdir(parents=True)
            smoke_path.write_text(SAMPLE_SOURCE, encoding="utf-8")
            subprocess.run(["git", "init", "-b", "master"], cwd=repo, check=True)
            subprocess.run(
                ["git", "config", "user.email", "test@example.com"],
                cwd=repo,
                check=True,
            )
            subprocess.run(["git", "config", "user.name", "Test"], cwd=repo, check=True)
            subprocess.run(["git", "add", "."], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-m", "init"], cwd=repo, check=True)
            env = os.environ.copy()
            env.pop("REISEN_MAC_UI_DIFF_BASE", None)
            result = subprocess.run(
                ["python3", str(SCRIPT)],
                cwd=repo,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.strip(), "")

    def test_untracked_new_smoke_file_selects_all_tests(self) -> None:
        """Spec Regel 6: datei neu (auch untracked) → alle test*."""
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            init_git_repo(repo)
            (repo / "README").write_text("base\n", encoding="utf-8")
            subprocess.run(["git", "add", "."], cwd=repo, check=True, capture_output=True)
            subprocess.run(
                ["git", "commit", "-m", "base without smoke"],
                cwd=repo,
                check=True,
                capture_output=True,
            )
            base = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=repo,
                capture_output=True,
                text=True,
                check=True,
            ).stdout.strip()
            write_smoke(repo, SAMPLE_SOURCE)  # untracked
            selected = self.mod.select_only_testing_args(repo, diff_base=base)
            self.assertEqual(selected, only_testing_lines(["testA", "testC"]))


if __name__ == "__main__":
    unittest.main()
