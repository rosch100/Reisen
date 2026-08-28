#!/usr/bin/env python3
"""Wertet JSON von xcrun altool --validate-app aus (stdin oder evaluate_altool_json)."""

from __future__ import annotations

import json
import sys
from typing import Any


def extract_json_object(text: str) -> str:
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end < start:
        raise ValueError("altool-JSON fehlt")
    return text[start : end + 1]


def evaluate_altool_json(text: str) -> int:
    blob = extract_json_object(text)
    data = json.loads(blob)
    if not isinstance(data, dict):
        raise ValueError("altool-JSON muss ein Objekt sein")
    errors: Any = data.get("product-errors")
    if errors:
        return 1
    return 0


def main() -> int:
    raw = sys.stdin.read()
    try:
        return evaluate_altool_json(raw)
    except (ValueError, json.JSONDecodeError) as exc:
        print(f"Fehler: altool --validate-app lieferte kein auswertbares JSON ({exc}).", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
