#!/usr/bin/env python3
"""Merge batch L10n JSON into Reisen Localizable.xcstrings."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

DEFAULT_XCSTRINGS = Path("Sources/ReisenDomain/Resources/Localizable.xcstrings")


def make_string_entry(de: str, en: str) -> dict[str, Any]:
    unit = {"state": "translated", "value": de}
    unit_en = {"state": "translated", "value": en}
    return {
        "localizations": {
            "de": {"stringUnit": unit},
            "en": {"stringUnit": unit_en},
        }
    }


def load_json(path: Path) -> Any:
    text = path.read_text(encoding="utf-8-sig")
    return json.loads(text)


def validate_json_object(data: Any, label: str) -> None:
    try:
        serialized = json.dumps(data, ensure_ascii=False)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{label} is not JSON-serializable: {exc}") from exc
    try:
        json.loads(serialized)
    except json.JSONDecodeError as exc:
        raise ValueError(f"{label} failed JSON round-trip validation: {exc}") from exc


def merge_batch(xcstrings: dict[str, Any], batch: dict[str, Any]) -> tuple[int, int]:
    strings = xcstrings.setdefault("strings", {})
    if not isinstance(strings, dict):
        raise ValueError("'strings' section must be a JSON object")

    added = 0
    skipped = 0
    for key, translations in batch.items():
        if not isinstance(key, str) or not key:
            raise ValueError("Batch keys must be non-empty strings")
        if key in strings:
            skipped += 1
            continue
        if not isinstance(translations, dict):
            raise ValueError(f"Batch entry for {key!r} must be an object")
        de = translations.get("de")
        en = translations.get("en")
        if not isinstance(de, str) or not isinstance(en, str):
            raise ValueError(f"Batch entry for {key!r} must contain string 'de' and 'en'")
        strings[key] = make_string_entry(de, en)
        added += 1

    strings_sorted = dict(sorted(strings.items(), key=lambda item: item[0]))
    xcstrings["strings"] = strings_sorted
    return added, skipped


def write_utf8_no_bom(path: Path, data: dict[str, Any]) -> None:
    text = json.dumps(data, ensure_ascii=False, indent=2)
    text += "\n"
    path.write_bytes(text.encode("utf-8"))


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Merge {'key': {'de': '...', 'en': '...'}} batch JSON into Localizable.xcstrings."
    )
    parser.add_argument(
        "batch",
        type=Path,
        help="Path to batch JSON file",
    )
    parser.add_argument(
        "--xcstrings",
        type=Path,
        default=DEFAULT_XCSTRINGS,
        help=f"Path to Localizable.xcstrings (default: {DEFAULT_XCSTRINGS})",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])

    if not args.batch.is_file():
        print(f"error: batch file not found: {args.batch}", file=sys.stderr)
        return 1
    if not args.xcstrings.is_file():
        print(f"error: xcstrings file not found: {args.xcstrings}", file=sys.stderr)
        return 1

    batch = load_json(args.batch)
    if not isinstance(batch, dict):
        print("error: batch JSON must be a top-level object", file=sys.stderr)
        return 1

    xcstrings = load_json(args.xcstrings)
    if not isinstance(xcstrings, dict):
        print("error: xcstrings root must be a JSON object", file=sys.stderr)
        return 1

    try:
        added, skipped = merge_batch(xcstrings, batch)
        validate_json_object(xcstrings, "Merged xcstrings")
        write_utf8_no_bom(args.xcstrings, xcstrings)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"Merged {added} new key(s), preserved {skipped} existing key(s) -> {args.xcstrings}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
