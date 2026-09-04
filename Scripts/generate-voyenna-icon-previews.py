#!/usr/bin/env python3
"""Generate Voyenna app-icon preview PNGs (HIG full-bleed, no baked corners/shadows)."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "design" / "voyenna-icon-previews"
SIZE = 1024
SS = 2  # supersample factor
CANVAS = SIZE * SS

# (top-left RGB, bottom-right RGB, glyph RGB, optional glyph accent RGB)
PALETTES: dict[str, tuple[tuple[int, int, int], tuple[int, int, int], tuple[int, int, int], tuple[int, int, int] | None]] = {
    "blue": ((1, 60, 110), (40, 185, 230), (255, 255, 255), None),
    "deep": ((6, 22, 48), (18, 110, 125), (236, 246, 248), None),
    "warm": ((8, 26, 52), (22, 70, 110), (255, 248, 240), (242, 140, 78)),
    "mono": ((28, 30, 34), (48, 52, 58), (236, 236, 238), None),
}

MATRIX: list[tuple[str, str, str]] = [
    ("01-v-blue.png", "v", "blue"),
    ("02-v-deep.png", "v", "deep"),
    ("03-v-warm.png", "v", "warm"),
    ("04-v-mono.png", "v", "mono"),
    ("05-voyage-blue.png", "voyage", "blue"),
    ("06-voyage-deep.png", "voyage", "deep"),
    ("07-voyage-warm.png", "voyage", "warm"),
    ("08-voyage-mono.png", "voyage", "mono"),
    ("09-plane-blue.png", "plane", "blue"),
    ("10-plane-deep.png", "plane", "deep"),
    ("11-plane-warm.png", "plane", "warm"),
    ("12-plane-mono.png", "plane", "mono"),
]


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def gradient_background(
    size: int,
    c0: tuple[int, int, int],
    c1: tuple[int, int, int],
) -> Image.Image:
    """Diagonal gradient, full-bleed (no margin)."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    assert px is not None
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = (
                int(lerp(c0[0], c1[0], t)),
                int(lerp(c0[1], c1[1], t)),
                int(lerp(c0[2], c1[2], t)),
            )
    return img


def draw_v_on(img: Image.Image, color: tuple[int, int, int], accent: tuple[int, int, int] | None) -> None:
    draw = ImageDraw.Draw(img)
    cx, cy = CANVAS // 2, CANVAS // 2 + int(10 * SS)
    t = int(108 * SS)
    w = int(300 * SS)
    h = int(320 * SS)
    top = cy - h // 2
    tip = (cx, cy + h // 2)
    left = [
        (cx - w, top),
        (cx - w + t, top),
        (cx + t // 4, tip[1]),
        (cx - t // 4, tip[1]),
    ]
    right = [
        (cx + w - t, top),
        (cx + w, top),
        (cx + t // 4, tip[1]),
        (cx - t // 4, tip[1]),
    ]
    draw.polygon(left, fill=color)
    draw.polygon(right, fill=color)
    if accent:
        tip_accent = [
            (cx - int(40 * SS), tip[1] - int(50 * SS)),
            (cx + int(40 * SS), tip[1] - int(50 * SS)),
            (cx + int(18 * SS), tip[1]),
            (cx - int(18 * SS), tip[1]),
        ]
        draw.polygon(tip_accent, fill=accent)


def draw_voyage_on(img: Image.Image, color: tuple[int, int, int], accent: tuple[int, int, int] | None) -> None:
    draw = ImageDraw.Draw(img)
    cx, cy = CANVAS // 2, CANVAS // 2
    r_outer = int(310 * SS)
    stroke = int(36 * SS)
    # Horizon arc (lower third) + compass needle
    # Ring
    bbox = [cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer]
    draw.ellipse(bbox, outline=color, width=stroke)
    # Cardinal ticks
    for angle_deg in (0, 90, 180, 270):
        a = math.radians(angle_deg - 90)
        x0 = cx + int((r_outer - stroke * 2.2) * math.cos(a))
        y0 = cy + int((r_outer - stroke * 2.2) * math.sin(a))
        x1 = cx + int((r_outer + stroke * 0.2) * math.cos(a))
        y1 = cy + int((r_outer + stroke * 0.2) * math.sin(a))
        draw.line([(x0, y0), (x1, y1)], fill=color, width=int(28 * SS))
    # Needle pointing NNE (voyage)
    needle_color = accent if accent else color
    tip = (cx + int(70 * SS), cy - int(220 * SS))
    left = (cx - int(48 * SS), cy + int(40 * SS))
    right = (cx + int(48 * SS), cy + int(40 * SS))
    draw.polygon([tip, left, (cx, cy + int(10 * SS))], fill=needle_color)
    draw.polygon([tip, right, (cx, cy + int(10 * SS))], fill=color)
    # Hub
    hub = int(28 * SS)
    draw.ellipse([cx - hub, cy - hub, cx + hub, cy + hub], fill=color)


def draw_plane_on(img: Image.Image, color: tuple[int, int, int], accent: tuple[int, int, int] | None) -> None:
    """Elongated paper-plane dart (nose UR); longer than Telegram's stubby glyph."""
    draw = ImageDraw.Draw(img)
    cx, cy = CANVAS // 2, CANVAS // 2
    # Classic paper-plane silhouette, stretched & rotated ~35° toward UR
    nose = (cx + int(320 * SS), cy - int(240 * SS))
    left_wing = (cx - int(300 * SS), cy + int(200 * SS))
    right_wing = (cx + int(120 * SS), cy + int(260 * SS))
    crease = (cx - int(40 * SS), cy + int(40 * SS))
    # Upper facet (lighter / accent)
    upper = [nose, left_wing, crease]
    # Lower facet
    lower_fill = accent if accent else tuple(max(0, min(255, c - 22)) for c in color)
    lower = [nose, crease, right_wing]
    draw.polygon(upper, fill=color)
    draw.polygon(lower, fill=lower_fill)
    # Center spine (thin darker strip) for fold readability without drop-shadow
    spine_fill = tuple(max(0, c - 40) for c in color) if accent is None else color
    spine_w = int(14 * SS)
    # Approximate spine as slim quad along nose→crease
    dx = crease[0] - nose[0]
    dy = crease[1] - nose[1]
    length = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / length * spine_w, dx / length * spine_w
    spine = [
        (nose[0] + nx, nose[1] + ny),
        (nose[0] - nx, nose[1] - ny),
        (crease[0] - nx, crease[1] - ny),
        (crease[0] + nx, crease[1] + ny),
    ]
    draw.polygon([(int(x), int(y)) for x, y in spine], fill=spine_fill)


def render(motif: str, palette_key: str) -> Image.Image:
    c0, c1, glyph, accent = PALETTES[palette_key]
    hi = gradient_background(CANVAS, c0, c1)
    if motif == "v":
        draw_v_on(hi, glyph, accent)
    elif motif == "voyage":
        draw_voyage_on(hi, glyph, accent)
    elif motif == "plane":
        draw_plane_on(hi, glyph, accent)
    else:
        raise ValueError(motif)
    return hi.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def corner_ok(img: Image.Image) -> bool:
    """Reject classic white-margin baked-squircle pattern."""
    px = img.load()
    assert px is not None
    corners = [px[0, 0], px[SIZE - 1, 0], px[0, SIZE - 1], px[SIZE - 1, SIZE - 1]]
    # White-ish corner + colored interior ≈ baked mask
    def near_white(rgb: tuple[int, ...]) -> bool:
        return rgb[0] > 240 and rgb[1] > 240 and rgb[2] > 240

    if all(near_white(c) for c in corners):
        center = px[SIZE // 2, SIZE // 2]
        if not near_white(center):
            return False
    return True


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, motif, palette in MATRIX:
        img = render(motif, palette)
        if img.mode != "RGB":
            img = img.convert("RGB")
        if not corner_ok(img):
            raise SystemExit(f"HIG fail (white corners): {name}")
        path = OUT / name
        img.save(path, format="PNG", optimize=True)
        print(f"OK {path.relative_to(ROOT)} {img.size} {img.mode}")


if __name__ == "__main__":
    main()
