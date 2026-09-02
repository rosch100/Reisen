#!/usr/bin/env python3
"""Gemeinsame Suite-Namen für Selection und Aggregator-Gate (SSOT)."""

from __future__ import annotations

ALL_SUITES: tuple[str, ...] = (
    "suite-swiftpm",
    "suite-ios-sim",
    "suite-ios-release",
    "suite-macos-ui",
)

SUITE_OUTPUT_KEYS: dict[str, str] = {
    "suite-swiftpm": "run_swiftpm",
    "suite-ios-sim": "run_ios_sim",
    "suite-ios-release": "run_ios_release",
    "suite-macos-ui": "run_macos_ui",
}

ALLOWED_SKIP_REASONS: frozenset[str] = frozenset({"docs-only"})
