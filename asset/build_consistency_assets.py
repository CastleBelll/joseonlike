"""Build the owner-directed weapon consistency art pass.

All art is drawn on the native pixel grid with Pillow primitives.  There is
no resampling except the intentional nearest-neighbour scale-up used by the
512px inventory icons, so exported edges stay hard and palette-controlled.

Run one review group at a time, for example::

    python asset/build_consistency_assets.py --group 1
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
TRAVEL = ROOT / "weapon" / "travel"
EFFECT = ROOT / "effect"
ICONS = ROOT / "ui" / "weapon_icons"

TRANSPARENT = (0, 0, 0, 0)
CURSE_INK = (25, 14, 35, 255)
CURSE_DEEP = (53, 27, 76, 255)
CURSE_MID = (93, 48, 135, 255)
CURSE_BRIGHT = (161, 83, 214, 255)
CURSE_MAGENTA = (224, 75, 189, 255)
CURSE_CORE = (238, 208, 255, 255)
PAPER_SHADOW = (91, 79, 105, 255)
PAPER = (160, 147, 170, 255)
PAPER_LIGHT = (201, 190, 211, 255)


def _new(size: tuple[int, int]) -> Image.Image:
    return Image.new("RGBA", size, TRANSPARENT)


def _draw_curse_projectile(
    image: Image.Image,
    origin: tuple[int, int],
    frame: int,
    evolved: bool,
) -> None:
    """One 36px projectile cell: torn charm plus angular ghost-script wake.

    Sal and Gwisal intentionally share every opaque silhouette coordinate.
    Evolution changes the internal palette and energy marks, never the body.
    """
    d = ImageDraw.Draw(image)
    ox, oy = origin
    bob = (0, -1, 0, 1)[frame]
    y = oy + bob

    # Three separated, angular smoke ribbons.  Their broken construction keeps
    # them reading as drifting calligraphy, not arms or tentacles.
    smoke = CURSE_MID if not evolved else CURSE_BRIGHT
    smoke_hi = CURSE_BRIGHT if not evolved else CURSE_MAGENTA
    ribbons = [
        [(2, 16), (5, 13), (10, 14), (14, 11), (17, 13), (13, 16), (8, 16), (5, 19)],
        [(1, 22), (5, 19), (10, 20), (14, 18), (17, 20), (12, 23), (7, 22), (4, 25)],
        [(5, 9), (8, 7), (12, 9), (16, 7), (18, 10), (13, 12), (9, 11)],
    ]
    for index, points in enumerate(ribbons):
        shifted = [(ox + x, y + py) for x, py in points]
        d.polygon(shifted, fill=CURSE_INK)
        inner = [(x + (1 if index != 1 else 0), py) for x, py in shifted[1:-1]]
        if len(inner) >= 3:
            d.line(inner, fill=smoke, width=2)
    # Square-edged brush/glyph flecks animate but occupy the same outer bounds.
    glyphs = (
        ((5, 12), (9, 25), (13, 5)),
        ((3, 11), (8, 26), (14, 6)),
        ((4, 8), (10, 25), (15, 14)),
        ((2, 15), (8, 7), (14, 26)),
    )[frame]
    for i, (gx, gy) in enumerate(glyphs):
        color = smoke_hi if i == 0 or evolved else smoke
        d.rectangle([ox + gx, y + gy, ox + gx + 1, y + gy + 1], fill=color)

    # Torn hanji charm: shared outline silhouette, pointed only by its folded
    # leading corner.  The left edge is ragged like a ripped paper fragment.
    charm = [
        (14, 11), (17, 9), (29, 10), (33, 15), (30, 20), (18, 22),
        (15, 20), (16, 18), (14, 16), (16, 14),
    ]
    charm = [(ox + x, y + py) for x, py in charm]
    d.polygon(charm, fill=PAPER_SHADOW, outline=CURSE_INK)
    inner_paper = [
        (17, 11), (28, 12), (31, 15), (29, 18), (18, 20),
        (17, 18), (18, 16), (17, 14),
    ]
    d.polygon([(ox + x, y + py) for x, py in inner_paper], fill=PAPER if not evolved else PAPER_LIGHT)
    # Fold/highlight and compact abstract ghost-writing.
    fold = CURSE_MID if not evolved else CURSE_MAGENTA
    d.line([ox + 28, y + 12, ox + 28, y + 18], fill=fold)
    d.line([ox + 29, y + 13, ox + 31, y + 15], fill=fold)
    d.line([ox + 20, y + 13, ox + 25, y + 13], fill=CURSE_INK)
    d.line([ox + 22, y + 13, ox + 22, y + 18], fill=CURSE_INK)
    d.line([ox + 19, y + 16, ox + 25, y + 16], fill=CURSE_INK)
    d.point((ox + 24, y + 18), fill=CURSE_INK)
    if evolved:
        d.point((ox + 26, y + 15), fill=CURSE_CORE)
        d.point((ox + 11, y + 14), fill=CURSE_CORE)


def _build_curse_travel(evolved: bool) -> Image.Image:
    strip = _new((144, 36))
    for frame in range(4):
        _draw_curse_projectile(strip, (frame * 36, 0), frame, evolved)
    return strip


def _draw_curse_icon_base(evolved: bool) -> Image.Image:
    """128px logical icon, exported 4x with nearest-neighbour pixels."""
    image = _new((128, 128))
    d = ImageDraw.Draw(image)
    smoke = CURSE_MID if not evolved else CURSE_BRIGHT
    smoke_hi = CURSE_BRIGHT if not evolved else CURSE_MAGENTA

    # Large, separated brush-smoke bands behind a single torn charm.  Both
    # evolution stages use identical shapes and differ only in energy fills.
    bands = [
        # One broad, stepped plume rather than limb-like separate tendrils.
        [(4, 74), (15, 58), (10, 45), (29, 44), (36, 29), (51, 37),
         (66, 26), (73, 43), (62, 57), (69, 70), (53, 82), (38, 76),
         (25, 91), (12, 89)],
        # Two short broken brush marks sell drifting script without changing
        # the main plume into a creature silhouette.
        [(18, 24), (27, 17), (39, 23), (34, 29), (24, 29)],
        [(19, 99), (30, 92), (43, 96), (37, 103), (26, 106)],
    ]
    for points in bands:
        d.polygon(points, fill=CURSE_INK)
        # One flat interior stripe, inset by a few native pixels.
        middle = points[1:-1]
        d.line(middle, fill=smoke, width=5)
        if len(middle) > 3:
            d.line(middle[1:-1], fill=smoke_hi, width=2)

    charm = [
        (48, 39), (58, 31), (101, 35), (121, 62), (104, 91), (59, 96),
        (47, 88), (52, 78), (45, 68), (52, 57),
    ]
    d.polygon(charm, fill=PAPER_SHADOW, outline=CURSE_INK, width=3)
    inner = [
        (57, 40), (96, 42), (111, 62), (99, 82), (62, 87),
        (55, 82), (59, 71), (53, 63), (60, 51),
    ]
    d.polygon(inner, fill=PAPER if not evolved else PAPER_LIGHT)
    d.line([94, 43, 94, 83], fill=smoke_hi, width=3)
    d.line([95, 45, 111, 62, 96, 80], fill=smoke_hi, width=3)

    # Abstract brush glyph: deliberately not a readable text character at UI
    # scale, but unmistakably ink writing on paper.
    for line in (
        (66, 47, 85, 47), (75, 46, 75, 77), (62, 59, 87, 59),
        (66, 72, 84, 72), (65, 80, 73, 73), (82, 71, 89, 80),
    ):
        d.line(line, fill=CURSE_INK, width=3)
    d.rectangle([78, 53, 81, 56], fill=smoke_hi)
    if evolved:
        d.rectangle([82, 61, 86, 65], fill=CURSE_CORE)
        d.rectangle([28, 39, 31, 42], fill=CURSE_CORE)
        d.rectangle([21, 91, 24, 94], fill=CURSE_MAGENTA)

    # Sparse, square glyph sparks.  The base has the same bounded silhouette;
    # upgraded colors make them flare without introducing a new creature form.
    flecks = [(16, 37), (11, 73), (29, 104), (43, 16), (109, 25), (117, 100)]
    for index, (x, y) in enumerate(flecks):
        color = smoke_hi if evolved or index % 2 == 0 else smoke
        d.rectangle([x, y, x + 2, y + 2], fill=color)
    return image


def _build_curse_icon(evolved: bool) -> Image.Image:
    return _draw_curse_icon_base(evolved).resize((512, 512), Image.Resampling.NEAREST)


def _draw_block_ray(
    d: ImageDraw.ImageDraw,
    cx: int,
    cy: int,
    angle: float,
    inner: float,
    outer: float,
    color: tuple[int, int, int, int],
    width: int,
) -> None:
    x1 = round(cx + math.cos(angle) * inner)
    y1 = round(cy + math.sin(angle) * inner)
    x2 = round(cx + math.cos(angle) * outer)
    y2 = round(cy + math.sin(angle) * outer)
    d.line([x1, y1, x2, y2], fill=color, width=width)


def _build_curse_hit(evolved: bool) -> Image.Image:
    frames = 10
    cell = 64
    strip = _new((frames * cell, cell))
    for frame in range(frames):
        d = ImageDraw.Draw(strip)
        cx = frame * cell + cell // 2
        cy = cell // 2
        # Fast ignition, broad middle burst, then sparse ghost-script decay.
        growth = (2, 6, 12, 19, 25, 29, 31, 32, 33, 34)[frame]
        strength = (255, 255, 255, 255, 235, 205, 170, 125, 85, 45)[frame]
        outer = (*((CURSE_BRIGHT if not evolved else CURSE_MAGENTA)[:3]), strength)
        inner = (*((CURSE_MID if not evolved else CURSE_BRIGHT)[:3]), strength)
        for index in range(12):
            angle = math.tau * index / 12 + (frame % 2) * 0.07
            reach = growth - (index % 3) * 3
            _draw_block_ray(d, cx, cy, angle, max(2, growth * 0.35), reach, CURSE_INK[:-1] + (strength,), 3)
            _draw_block_ray(d, cx, cy, angle, max(3, growth * 0.42), max(3, reach - 2), outer, 1)
        radius = max(1, growth // 2)
        if frame < 8:
            d.rectangle([cx - radius, cy - radius, cx + radius, cy + radius], outline=inner, width=2)
        if frame < 6:
            # Rotating paper shard at the impact core.
            shard = [
                (cx - 7, cy - 5), (cx + 5, cy - 7), (cx + 8, cy + 3),
                (cx - 3, cy + 7), (cx - 8, cy + 2),
            ]
            d.polygon(shard, fill=PAPER if not evolved else PAPER_LIGHT, outline=CURSE_INK)
            d.line([cx - 2, cy - 3, cx + 3, cy + 3], fill=CURSE_MID if not evolved else CURSE_MAGENTA)
            d.line([cx + 2, cy - 3, cx - 3, cy + 3], fill=CURSE_INK)
        # Square glyph motes at fixed compass offsets, increasingly separated.
        for index in range(4):
            angle = math.tau * index / 4 + math.pi / 4
            dist = min(29, 7 + frame * 3 + index % 2)
            x = round(cx + math.cos(angle) * dist)
            y = round(cy + math.sin(angle) * dist)
            d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=outer)
        if evolved and frame < 5:
            d.rectangle([cx - 2, cy - 2, cx + 2, cy + 2], fill=CURSE_CORE)
    return strip


def build_group_1() -> list[Path]:
    outputs = {
        TRAVEL / "sal.png": _build_curse_travel(False),
        TRAVEL / "gwisal.png": _build_curse_travel(True),
        ICONS / "sal.png": _build_curse_icon(False),
        ICONS / "gwisal.png": _build_curse_icon(True),
        EFFECT / "hit_sal.png": _build_curse_hit(False),
        EFFECT / "hit_gwisal.png": _build_curse_hit(True),
    }
    for path, image in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path)
    return list(outputs)


GROUPS = {1: build_group_1}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--group", type=int, choices=GROUPS, required=True)
    args = parser.parse_args()
    for output in GROUPS[args.group]():
        with Image.open(output) as image:
            print(output.relative_to(ROOT), image.size, image.mode)


if __name__ == "__main__":
    main()
