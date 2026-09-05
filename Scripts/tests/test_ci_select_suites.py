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

    def test_all_none_baselines_full_no_last_green(self) -> None:
        baselines = {suite: None for suite in self.mod.ALL_SUITES}
        result = self.mod.select_suites(
            changed_files=["Sources/ReisenDomain/Entities/Booking.swift"],
            baselines=baselines,
            force_full=False,
            push_to_default=False,
        )
        self.assertEqual(result["mode"], "full")
        self.assertEqual(result["reason"], "no-last-green")

    def test_fill_missing_baselines_keeps_pr_sha(self) -> None:
        target = {suite: None for suite in self.mod.ALL_SUITES}
        target["suite-swiftpm"] = "pr-sha"
        source = {suite: "master-sha" for suite in self.mod.ALL_SUITES}
        filled = self.mod.fill_missing_baselines(target, source)
        self.assertEqual(target["suite-swiftpm"], "pr-sha")
        self.assertEqual(target["suite-ios-sim"], "master-sha")
        self.assertEqual(filled, len(self.mod.ALL_SUITES) - 1)

    def test_prepare_master_then_domain_affected_swiftpm(self) -> None:
        baselines = {suite: None for suite in self.mod.ALL_SUITES}
        master = {suite: "master-sha" for suite in self.mod.ALL_SUITES}
        prepared, source = self.mod.prepare_baselines_with_default_branch(
            baselines=baselines,
            master_baselines=master,
            default_branch_sha=None,
        )
        self.assertEqual(source, "master")
        result = self.mod.select_suites(
            changed_files=["Sources/ReisenDomain/Entities/Booking.swift"],
            baselines=prepared,
            force_full=False,
            push_to_default=False,
        )
        self.assertEqual(result["mode"], "affected")
        self.assertEqual(result["suites"], ["suite-swiftpm"])

    def test_prepare_default_branch_when_apis_empty(self) -> None:
        baselines = {suite: None for suite in self.mod.ALL_SUITES}
        prepared, source = self.mod.prepare_baselines_with_default_branch(
            baselines=baselines,
            master_baselines={suite: None for suite in self.mod.ALL_SUITES},
            default_branch_sha="defaultdefault01",
        )
        self.assertEqual(source, "default-branch")
        self.assertTrue(all(prepared[s] == "defaultdefault01" for s in self.mod.ALL_SUITES))
        result = self.mod.select_suites(
            changed_files=["Sources/ReisenAirbnb/AirbnbTravelProvider.swift"],
            baselines=prepared,
            force_full=False,
            push_to_default=False,
        )
        self.assertEqual(result["mode"], "affected")
        self.assertEqual(result["suites"], ["suite-swiftpm"])

    def test_prepare_none_without_default_branch(self) -> None:
        baselines = {suite: None for suite in self.mod.ALL_SUITES}
        prepared, source = self.mod.prepare_baselines_with_default_branch(
            baselines=baselines,
            master_baselines={suite: None for suite in self.mod.ALL_SUITES},
            default_branch_sha=None,
        )
        self.assertEqual(source, "none")
        self.assertTrue(all(prepared[s] is None for s in self.mod.ALL_SUITES))

    def test_pr_green_wins_over_master(self) -> None:
        baselines = {suite: None for suite in self.mod.ALL_SUITES}
        baselines["suite-swiftpm"] = "pr-sha"
        master = {suite: "master-sha" for suite in self.mod.ALL_SUITES}
        prepared, source = self.mod.prepare_baselines_with_default_branch(
            baselines=baselines,
            master_baselines=master,
            default_branch_sha="unused",
        )
        self.assertEqual(source, "pr+master")
        self.assertEqual(prepared["suite-swiftpm"], "pr-sha")
        self.assertEqual(prepared["suite-macos-ui"], "master-sha")
        # no None slots → default-branch not applied
        self.assertNotIn("default-branch", source)

    def test_resolve_default_branch_sha_tries_refs_in_order(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            subprocess_run = __import__("subprocess").run
            subprocess_run(["git", "init", "-b", "master"], cwd=repo, check=True, capture_output=True)
            subprocess_run(
                ["git", "config", "user.email", "t@example.com"],
                cwd=repo,
                check=True,
                capture_output=True,
            )
            subprocess_run(
                ["git", "config", "user.name", "t"],
                cwd=repo,
                check=True,
                capture_output=True,
            )
            (repo / "f").write_text("x\n", encoding="utf-8")
            subprocess_run(["git", "add", "f"], cwd=repo, check=True, capture_output=True)
            subprocess_run(["git", "commit", "-m", "c"], cwd=repo, check=True, capture_output=True)
            resolved = self.mod.resolve_default_branch_sha(repo, refs=("missing", "master"))
            self.assertIsNotNone(resolved)
            assert resolved is not None
            sha, ref = resolved
            self.assertEqual(ref, "master")
            self.assertEqual(len(sha), 40)

    def test_write_github_outputs_includes_baseline_source(self) -> None:
        import tempfile

        selection = {
            "mode": "affected",
            "reason": "affected",
            "baselineSource": "master",
            "suites": ["suite-swiftpm"],
            "skipped": [s for s in self.mod.ALL_SUITES if s != "suite-swiftpm"],
        }
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "github_output"
            self.mod.write_github_outputs(selection, out)
            text = out.read_text(encoding="utf-8")
            self.assertIn("baselineSource=master\n", text)
            self.assertIn("run_swiftpm=true\n", text)


if __name__ == "__main__":
    unittest.main()
