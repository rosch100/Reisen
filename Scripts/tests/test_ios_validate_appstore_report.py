#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts" / "ios-validate-appstore-report.py"


def load_report():
    spec = importlib.util.spec_from_file_location("ios_validate_appstore_report", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError("ios-validate-appstore-report.py nicht ladbar")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class AltoolValidateReportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.report = load_report()

    def test_success_message_without_errors_passes(self) -> None:
        code = self.report.evaluate_altool_json(
            '{"success-message": "No errors validating archive at path."}'
        )
        self.assertEqual(code, 0)

    def test_product_errors_fail(self) -> None:
        code = self.report.evaluate_altool_json(
            '{"product-errors":[{"code":90081,"message":"Invalid Bundle"}]}'
        )
        self.assertEqual(code, 1)

    def test_empty_product_errors_pass(self) -> None:
        code = self.report.evaluate_altool_json('{"product-errors":[]}')
        self.assertEqual(code, 0)

    def test_invalid_json_is_error(self) -> None:
        with self.assertRaises(ValueError):
            self.report.evaluate_altool_json("not-json")

    def test_empty_input_is_error(self) -> None:
        with self.assertRaises(ValueError):
            self.report.evaluate_altool_json("  \n")

    def test_json_after_altool_log_prefix_passes(self) -> None:
        raw = (
            "Running altool at path /Applications/Xcode.app/Contents/SharedFrameworks/"
            "ContentDelivery.framework/Resources/altool\n"
            '{"success-message": "No errors validating archive at path."}\n'
        )
        self.assertEqual(self.report.evaluate_altool_json(raw), 0)


if __name__ == "__main__":
    unittest.main()
