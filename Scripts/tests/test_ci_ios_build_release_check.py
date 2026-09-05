#!/usr/bin/env python3
"""Contract tests for ios-build-release-check.sh (generic destination + parallel)."""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts" / "ios-build-release-check.sh"


class IosBuildReleaseCheckContractTests(unittest.TestCase):
    def test_self_test_passes(self) -> None:
        proc = subprocess.run(
            ["bash", str(SCRIPT), "--self-test"],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            proc.returncode,
            0,
            msg=f"stdout={proc.stdout!r} stderr={proc.stderr!r}",
        )
        self.assertIn("self-test: OK", proc.stderr)

    def test_script_uses_generic_simulator_destination(self) -> None:
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("generic/platform=iOS Simulator", text)
        marker = 'REISEN_CI_T0="$(date +%s)"'
        self.assertIn(marker, text)
        production = text.rsplit(marker, 1)[1]
        self.assertNotIn("xcrun simctl boot", production)
        self.assertNotIn("simctl bootstatus", production)
        self.assertIn("build_scheme_release ReiseniOS", production)
        self.assertIn("build_scheme_release ReiseniOSPrivate", production)
        self.assertIn("store_pid=$!", production)
        self.assertIn("private_pid=$!", production)
        self.assertIn('wait "$store_pid"', production)
        self.assertIn('wait "$private_pid"', production)
        self.assertIn("xcodebuild-release.log", production)
        self.assertIn("ios-verify-binary-isolation.sh", production)
        self.assertIn(
            "RELEASE_DESTINATION='generic/platform=iOS Simulator'",
            text.split("reisen_ios_release_check_self_test", 1)[0],
        )


if __name__ == "__main__":
    unittest.main()
