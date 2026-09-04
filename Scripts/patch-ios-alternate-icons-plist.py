#!/usr/bin/env python3
"""Insert CFBundleIcons (primary + AppIconLight alternate) into iOS Info.plist files."""

from __future__ import annotations

import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ICONS = {
    "CFBundlePrimaryIcon": {
        "CFBundleIconFiles": ["AppIcon"],
        "CFBundleIconName": "AppIcon",
    },
    "CFBundleAlternateIcons": {
        "AppIconLight": {
            "CFBundleIconFiles": ["AppIconLight"],
            "UIPrerenderedIcon": False,
        }
    },
}


def patch(path: Path) -> None:
    data = plistlib.loads(path.read_bytes())
    data["CFBundleIcons"] = ICONS
    data["CFBundleIcons~ipad"] = ICONS
    path.write_bytes(plistlib.dumps(data, fmt=plistlib.FMT_XML))
    print(f"OK {path.relative_to(ROOT)}")


def main() -> None:
    for rel in (
        "Apps/ReiseniOS/Info.plist",
        "Apps/ReiseniOSPrivate/Info.plist",
    ):
        patch(ROOT / rel)


if __name__ == "__main__":
    main()
