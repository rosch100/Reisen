#!/usr/bin/env python3
"""Diff-scoped Swift coverage/CRAP proxy from llvm-cov JSON export."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def load_files(export_path: Path) -> dict[str, dict]:
    payload = json.loads(export_path.read_text(encoding="utf-8"))
    by_suffix: dict[str, dict] = {}
    for entry in payload["data"][0]["files"]:
        name = entry["filename"].replace("\\", "/")
        summary = entry["summary"]
        by_suffix[name] = {
            "lines_percent": float(summary["lines"]["percent"]),
            "regions_count": int(summary["regions"]["count"]),
            "regions_percent": float(summary["regions"]["percent"]),
        }
    return by_suffix


def match_row(path: str, rows: dict[str, dict]) -> dict | None:
    needle = path.replace("\\", "/")
    for name, row in rows.items():
        if name.endswith("/" + needle) or name.endswith(needle):
            return row
    return None


def is_gated_unit(path: str) -> bool:
    name = Path(path).name
    return name.startswith("PasteImportFailed") or name.startswith("GitHubIssueAttachment")


def main() -> int:
    if len(sys.argv) < 4:
        print("Usage: coverage-diff.py <export.json> <gate> <relative.swift>...", file=sys.stderr)
        return 2
    export_path = Path(sys.argv[1])
    gate = int(sys.argv[2])
    sources = sys.argv[3:]
    rows = load_files(export_path)
    hotspots: list[tuple[float, int, str, dict]] = []
    print("file\tlines%\tregions\tregions%")
    for rel in sources:
        row = match_row(rel, rows)
        if row is None:
            print(f"{rel}\t(not in llvm-cov)\t-\t-")
            continue
        print(
            f"{rel}\t{row['lines_percent']:.1f}\t{row['regions_count']}\t{row['regions_percent']:.1f}"
        )
        hotspots.append((row["lines_percent"], -row["regions_count"], rel, row))
    hotspots.sort()
    print("CRAP-proxy hotspots (low lines% then high regions.count):")
    for lines_percent, neg_regions, rel, row in hotspots[:30]:
        print(f"  {rel}: lines {row['lines_percent']:.1f}% regions {row['regions_count']}")
    failed = [
        (rel, row)
        for _, _, rel, row in hotspots
        if is_gated_unit(rel) and row["lines_percent"] < 80.0 and row["regions_count"] >= gate
    ]
    if failed:
        print(f"FAIL: {len(failed)} diff file(s) below 80% lines with regions.count >= {gate}")
        for rel, row in failed:
            print(f"  {rel}: lines {row['lines_percent']:.1f}% regions {row['regions_count']}")
        return 1
    print(f"OK: no diff Source hotspot (lines% < 80 and regions.count >= {gate})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
