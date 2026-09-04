#!/usr/bin/env python3
"""Unit tests for Scripts/install-voyenna-app-icon.py web-mask helpers."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts" / "install-voyenna-app-icon.py"


def load_install_module():
    spec = importlib.util.spec_from_file_location("install_voyenna_app_icon", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError("install-voyenna-app-icon.py nicht ladbar")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class InstallVoyennaAppIconTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mod = load_install_module()

    def test_requirements_icon_lists_pillow(self) -> None:
        text = (ROOT / "Scripts" / "requirements-icon.txt").read_text(encoding="utf-8")
        self.assertIn("Pillow", text)

    def test_web_masked_icon_has_transparent_corners(self) -> None:
        master = Image.new("RGB", (64, 64), (8, 26, 52))
        for y in range(64):
            for x in range(64):
                master.putpixel((x, y), (20 + x, 40, 80 + y % 40))
        web = self.mod.web_masked_icon(master, 64)
        self.assertEqual(web.mode, "RGBA")
        self.assertEqual(web.size, (64, 64))
        self.assertEqual(web.getpixel((0, 0))[3], 0)
        self.assertEqual(web.getpixel((63, 0))[3], 0)
        self.assertEqual(web.getpixel((0, 63))[3], 0)
        self.assertEqual(web.getpixel((63, 63))[3], 0)
        self.assertEqual(web.getpixel((32, 32))[3], 255)

    def test_ios_squircle_mask_center_opaque(self) -> None:
        mask = self.mod.ios_squircle_mask(128)
        self.assertEqual(mask.mode, "L")
        self.assertEqual(mask.getpixel((0, 0)), 0)
        self.assertEqual(mask.getpixel((64, 64)), 255)


if __name__ == "__main__":
    unittest.main()
