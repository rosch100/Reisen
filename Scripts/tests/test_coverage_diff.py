#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts" / "coverage-diff.py"


def load_coverage_diff():
    spec = importlib.util.spec_from_file_location("coverage_diff", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError("coverage-diff.py nicht ladbar")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def llvm_file(filename: str, lines_percent: float, regions_count: int) -> dict:
    return {
        "filename": filename,
        "summary": {
            "lines": {"percent": lines_percent},
            "regions": {"count": regions_count, "percent": lines_percent},
        },
    }


class CoverageDiffGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.module = load_coverage_diff()

    def run_main(self, files: list[dict], sources: list[str], gate: int = 5) -> int:
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as handle:
            json.dump({"data": [{"files": files}]}, handle)
            export_path = handle.name
        previous = sys.argv
        sys.argv = ["coverage-diff.py", export_path, str(gate), *sources]
        try:
            return self.module.main()
        finally:
            sys.argv = previous
            Path(export_path).unlink(missing_ok=True)

    def test_missing_gated_file_fails(self) -> None:
        code = self.run_main(
            files=[],
            sources=["Sources/ReisenAppCore/PasteImport/PasteImportFailedFeatureRequest.swift"],
        )
        self.assertEqual(code, 1)

    def test_missing_ungated_file_is_ok(self) -> None:
        code = self.run_main(
            files=[],
            sources=["Sources/ReisenDomain/PasteImport/PasteImportFilter.swift"],
        )
        self.assertEqual(code, 0)

    def test_gated_file_below_threshold_fails(self) -> None:
        code = self.run_main(
            files=[
                llvm_file(
                    "/repo/Sources/ReisenAppCore/GitHubIssues/GitHubIssueAttachmentCodec.swift",
                    lines_percent=10.0,
                    regions_count=20,
                )
            ],
            sources=["Sources/ReisenAppCore/GitHubIssues/GitHubIssueAttachmentCodec.swift"],
        )
        self.assertEqual(code, 1)

    def test_gated_file_covered_passes(self) -> None:
        code = self.run_main(
            files=[
                llvm_file(
                    "/repo/Sources/ReisenAppCore/PasteImport/PasteImportFailedFeatureRequest.swift",
                    lines_percent=90.0,
                    regions_count=20,
                )
            ],
            sources=["Sources/ReisenAppCore/PasteImport/PasteImportFailedFeatureRequest.swift"],
        )
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()
