#!/usr/bin/env python3
"""Install Voyenna app icons from a full-bleed 1024 master PNG (11d-style).

Writes primary (dark) + alternate light icons:
  - Apps/ReiseniOS/Assets.xcassets/AppIcon.appiconset/
  - Apps/ReiseniOS/Assets.xcassets/AppIconLight.appiconset/
  - Apps/Shared/AppIcon.icon/ + AppIconLight.icon/
  - Resources/AppIcon*.icns / iconset / 1024 PNG
  - docs/design/voyenna-icon-previews/11d-plane-warm-light.png
  - docs/legal/assets/app-icon.png (web: Squircle-Maske + Alpha)
  - docs/legal/assets/apple-touch-icon.png (full-bleed, System maskiert)
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SRC = ROOT / "docs/design/voyenna-icon-previews/11d-plane-warm-repositioned.png"
SIZE = 1024
# Approx. iOS continuous corner (marketing / web display only — never bake into App Store masters).
WEB_CORNER_RATIO = 0.2237

# Light full-bleed gradient (cool paper)
LIGHT_C0 = (245, 248, 252)
LIGHT_C1 = (220, 232, 245)
# Recolor cream facets → deep navy for contrast on light ground
NAVY_FACET = (18, 42, 72)


def load_master(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGB")
    if im.size != (SIZE, SIZE):
        im = im.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    px = im.load()
    assert px is not None
    corners = [px[0, 0], px[SIZE - 1, 0], px[0, SIZE - 1], px[SIZE - 1, SIZE - 1]]

    def near_white(rgb: tuple[int, int, int]) -> bool:
        return rgb[0] > 240 and rgb[1] > 240 and rgb[2] > 240

    if all(near_white(c) for c in corners) and not near_white(px[SIZE // 2, SIZE // 2]):
        raise SystemExit(f"HIG fail: white corner margin in {path}")
    return im


def write_png(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rgb = im.convert("RGB") if im.mode != "RGB" else im
    rgb.save(path, format="PNG", optimize=True)


def write_png_rgba(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.convert("RGBA").save(path, format="PNG", optimize=True)


def ios_squircle_mask(size: int, corner_ratio: float = WEB_CORNER_RATIO) -> Image.Image:
    """Luminance mask approximating Apple's continuous corner for web marketing."""
    radius = max(1, int(round(size * corner_ratio)))
    # Supersample for smooth edges, then downscale.
    ss = 4
    big = size * ss
    big_r = radius * ss
    mask_big = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(mask_big)
    draw.rounded_rectangle((0, 0, big - 1, big - 1), radius=big_r, fill=255)
    return mask_big.resize((size, size), Image.Resampling.LANCZOS)


def web_masked_icon(master: Image.Image, size: int) -> Image.Image:
    """Full-bleed master → web icon with transparent corners (not for Xcode assets)."""
    rgb = master.convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (size, size))
    out.paste(rgb, (0, 0))
    out.putalpha(ios_squircle_mask(size))
    return out


def write_appiconset(master: Image.Image, appiconset: Path, filename: str = "AppIcon-1024.png") -> None:
    appiconset.mkdir(parents=True, exist_ok=True)
    write_png(master, appiconset / filename)
    contents = {
        "images": [
            {
                "filename": filename,
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (appiconset / "Contents.json").write_text(
        json.dumps(contents, indent=2) + "\n", encoding="utf-8"
    )


def extract_plane_rgba(master: Image.Image, *, for_light: bool) -> Image.Image:
    """Isolate plane glyph onto transparent canvas."""
    src = master.convert("RGB")
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sp = src.load()
    op = out.load()
    assert sp is not None and op is not None
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b = sp[x, y]
            lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
            cool = b >= r - 8 and b >= g - 8
            if cool and lum < 115 and r < 90:
                continue
            if for_light and lum > 200 and abs(r - g) < 25 and abs(g - b) < 25:
                # Cream/white facet → navy on light background
                op[x, y] = (*NAVY_FACET, 255)
            else:
                op[x, y] = (r, g, b, 255)
    return out


def light_master_from_dark(dark: Image.Image) -> Image.Image:
    """Full-bleed light gradient + recolored plane from dark master."""
    plane = extract_plane_rgba(dark, for_light=True)
    bg = Image.new("RGB", (SIZE, SIZE))
    px = bg.load()
    assert px is not None
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x + y) / (2 * (SIZE - 1))
            px[x, y] = (
                int(LIGHT_C0[0] + (LIGHT_C1[0] - LIGHT_C0[0]) * t),
                int(LIGHT_C0[1] + (LIGHT_C1[1] - LIGHT_C0[1]) * t),
                int(LIGHT_C0[2] + (LIGHT_C1[2] - LIGHT_C0[2]) * t),
            )
    composed = bg.convert("RGBA")
    composed.alpha_composite(plane)
    return composed.convert("RGB")


def average_corner_color(master: Image.Image) -> tuple[float, float, float]:
    px = master.load()
    assert px is not None
    samples = [
        px[0, 0],
        px[SIZE - 1, 0],
        px[0, SIZE - 1],
        px[SIZE - 1, SIZE - 1],
        px[8, 8],
        px[SIZE - 9, SIZE - 9],
    ]
    return (
        sum(c[0] for c in samples) / len(samples) / 255.0,
        sum(c[1] for c in samples) / len(samples) / 255.0,
        sum(c[2] for c in samples) / len(samples) / 255.0,
    )


def write_icon_composer(master: Image.Image, icon_dir: Path, *, for_light: bool) -> None:
    if icon_dir.exists():
        shutil.rmtree(icon_dir)
    assets = icon_dir / "Assets"
    assets.mkdir(parents=True)

    if for_light:
        # Master is light full-bleed; strip cool light background.
        plane = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        sp = master.load()
        op = plane.load()
        assert sp is not None and op is not None
        for y in range(SIZE):
            for x in range(SIZE):
                r, g, b = sp[x, y]
                lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
                if lum > 200 and b >= r - 5:
                    continue
                if r > 200 and g > 200 and b > 200:
                    continue
                op[x, y] = (r, g, b, 255)
    else:
        plane = extract_plane_rgba(master, for_light=False)

    plane.save(assets / "plane.png", format="PNG", optimize=True)

    r, g, b = average_corner_color(master)
    doc = {
        "fill": {
            "automatic-gradient": f"extended-srgb:{r:.5f},{g:.5f},{b:.5f},1.00000"
        },
        "groups": [
            {
                "blur-and-translucency-by-placement": False,
                "layers": [
                    {
                        "glass": True,
                        "image-name": "plane.png",
                        "name": "Plane",
                    }
                ],
                "lighting": "individual",
                "name": "Foreground",
                "shadow": {"kind": "layer-color", "opacity": 0.25 if for_light else 0.3},
                "specular": True,
                "translucency": {"enabled": True, "value": 0.15 if for_light else 0.2},
            }
        ],
        "supported-platforms": {
            "circles": ["watchOS"],
            "squares": "shared",
        },
    }
    (icon_dir / "icon.json").write_text(
        json.dumps(doc, indent=2) + "\n", encoding="utf-8"
    )


def write_macos_iconset(master: Image.Image, iconset: Path) -> None:
    if iconset.exists():
        shutil.rmtree(iconset)
    iconset.mkdir(parents=True)
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]
    for px, name in sizes:
        write_png(master.resize((px, px), Image.Resampling.LANCZOS), iconset / name)


def install_variant(
    master: Image.Image,
    *,
    appiconset_name: str,
    icon_composer_name: str,
    resource_basename: str,
    for_light: bool,
    write_legal: bool,
) -> None:
    write_appiconset(
        master,
        ROOT / "Apps/ReiseniOS/Assets.xcassets" / appiconset_name,
    )
    print(f"OK Apps/ReiseniOS/Assets.xcassets/{appiconset_name}/")

    write_png(master, ROOT / "Resources" / f"{resource_basename}-1024.png")
    iconset = ROOT / "Resources" / f"{resource_basename}.iconset"
    write_macos_iconset(master, iconset)
    icns = ROOT / "Resources" / f"{resource_basename}.icns"
    subprocess.run(
        ["/usr/bin/iconutil", "-c", "icns", str(iconset), "-o", str(icns)],
        check=True,
    )
    print(f"OK {icns.relative_to(ROOT)}")

    write_icon_composer(
        master,
        ROOT / "Apps/Shared" / icon_composer_name,
        for_light=for_light,
    )
    print(f"OK Apps/Shared/{icon_composer_name}/")

    if write_legal:
        legal = ROOT / "docs/legal/assets"
        # Website / favicon / hero: masked squircle (HIG marketing display).
        write_png_rgba(web_masked_icon(master, 512), legal / "app-icon.png")
        # Add-to-Home-Screen: square full-bleed; iOS applies the mask.
        write_png(master.resize((180, 180), Image.Resampling.LANCZOS), legal / "apple-touch-icon.png")
        print("OK docs/legal/assets/app-icon.png (web squircle)")
        print("OK docs/legal/assets/apple-touch-icon.png (full-bleed)")


def main() -> None:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SRC
    if not src.is_absolute():
        src = (ROOT / src).resolve()
    if not src.is_file():
        raise SystemExit(f"Missing source: {src}")
    dark = load_master(src)
    try:
        src_label = src.relative_to(ROOT)
    except ValueError:
        src_label = src
    print(f"Source: {src_label}")

    install_variant(
        dark,
        appiconset_name="AppIcon.appiconset",
        icon_composer_name="AppIcon.icon",
        resource_basename="AppIcon",
        for_light=False,
        write_legal=True,
    )

    light = light_master_from_dark(dark)
    light_preview = ROOT / "docs/design/voyenna-icon-previews/11d-plane-warm-light.png"
    write_png(light, light_preview)
    print(f"OK {light_preview.relative_to(ROOT)}")

    install_variant(
        light,
        appiconset_name="AppIconLight.appiconset",
        icon_composer_name="AppIconLight.icon",
        resource_basename="AppIconLight",
        for_light=True,
        write_legal=False,
    )


if __name__ == "__main__":
    main()
