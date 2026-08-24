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
ARROW_INK = (30, 25, 24, 255)
ARROW_WOOD = (133, 88, 43, 255)
ARROW_WOOD_LIGHT = (208, 157, 78, 255)
ARROW_STEEL = (190, 198, 202, 255)
ARROW_STEEL_LIGHT = (238, 236, 216, 255)
ARROW_FEATHER = (170, 64, 46, 255)
DIVINE_GOLD = (230, 170, 50, 255)
DIVINE_LIGHT = (255, 238, 151, 255)
DIVINE_CORE = (255, 252, 222, 255)
SWORD_AURA_INK = (21, 24, 38, 255)
SWORD_AURA_DIM = (56, 103, 126, 255)
SWORD_AURA_EDGE = (126, 203, 218, 255)
SWORD_AURA_CORE = (239, 250, 244, 255)
SEAL_AURA_INK = (29, 16, 45, 255)
SEAL_AURA_DIM = (74, 40, 110, 255)
SEAL_AURA_EDGE = (166, 82, 211, 255)
SEAL_AURA_CORE = (244, 213, 255, 255)
FX_INK = (42, 42, 48, 255)
FX_DIM = (118, 122, 132, 255)
FX_LIGHT = (205, 211, 220, 255)
FX_CORE = (255, 255, 248, 255)
THUNDER_INK = (16, 28, 54, 255)
THUNDER_BLUE = (36, 91, 160, 255)
THUNDER_CYAN = (80, 202, 232, 255)
THUNDER_GOLD = (255, 205, 74, 255)
THUNDER_CORE = (244, 255, 255, 255)


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


def _draw_arrow(
    image: Image.Image,
    origin: tuple[int, int],
    frame: int,
    evolved: bool,
) -> None:
    """Readable 40x16 arrow: separated fletching, shaft, and broad head."""
    d = ImageDraw.Draw(image)
    ox, oy = origin
    bob = (0, -1, 0, 1)[frame]
    cy = oy + 8 + bob
    feather = DIVINE_GOLD if evolved else ARROW_FEATHER
    shaft = DIVINE_GOLD if evolved else ARROW_WOOD
    shaft_hi = DIVINE_LIGHT if evolved else ARROW_WOOD_LIGHT
    steel = DIVINE_LIGHT if evolved else ARROW_STEEL
    steel_hi = DIVINE_CORE if evolved else ARROW_STEEL_LIGHT

    # Short square spirit wake occupies the same bounds in both stages.
    wake = DIVINE_GOLD if evolved else ARROW_WOOD_LIGHT
    d.rectangle([ox, cy, ox + 2, cy], fill=wake)
    d.point((ox + 3, cy - 3), fill=wake)
    d.point((ox + 3, cy + 3), fill=wake)

    # Two distinct feathers around a visible nock; the negative gap between
    # them is what keeps the tail readable at combat zoom.
    upper = [(ox + 3, cy - 1), (ox + 5, cy - 5), (ox + 11, cy - 2), (ox + 10, cy - 1)]
    lower = [(ox + 3, cy + 1), (ox + 5, cy + 5), (ox + 11, cy + 2), (ox + 10, cy + 1)]
    d.polygon(upper, fill=feather, outline=ARROW_INK)
    d.polygon(lower, fill=feather, outline=ARROW_INK)
    d.rectangle([ox + 2, cy - 1, ox + 5, cy + 1], fill=shaft, outline=ARROW_INK)

    # Two-pixel dark shaft with one-pixel lit spine.
    d.rectangle([ox + 7, cy - 1, ox + 34, cy + 1], fill=ARROW_INK)
    d.line([ox + 8, cy, ox + 34, cy], fill=shaft_hi)
    # Broad triangular point with a clear shoulder and white cutting facet.
    head = [(ox + 32, cy - 4), (ox + 39, cy), (ox + 32, cy + 4)]
    d.polygon(head, fill=steel, outline=ARROW_INK)
    d.line([ox + 34, cy - 2, ox + 38, cy], fill=steel_hi)
    d.line([ox + 34, cy + 2, ox + 38, cy], fill=DIVINE_GOLD if evolved else ARROW_STEEL)
    if evolved:
        # Internal energy pulse only; no new silhouette in the evolution.
        pulse_x = ox + (15, 20, 25, 20)[frame]
        d.point((pulse_x, cy), fill=DIVINE_CORE)
        d.point((ox + 7, cy - 3), fill=DIVINE_LIGHT)


def _build_arrow_travel(evolved: bool) -> Image.Image:
    strip = _new((160, 16))
    for frame in range(4):
        _draw_arrow(strip, (frame * 40, 0), frame, evolved)
    return strip


def build_group_2() -> list[Path]:
    outputs = {
        TRAVEL / "bow.png": _build_arrow_travel(False),
        TRAVEL / "divine_bow.png": _build_arrow_travel(True),
    }
    for path, image in outputs.items():
        image.save(path)
    return list(outputs)


def _draw_sword_aura(
    image: Image.Image,
    origin: tuple[int, int],
    frame: int,
    evolved: bool,
) -> None:
    """Dense blade-aura projectile with outlined edge, core, and wake."""
    d = ImageDraw.Draw(image)
    ox, oy = origin
    bob = (0, -1, 0, 1)[frame]
    cy = oy + 8 + bob
    ink = SEAL_AURA_INK if evolved else SWORD_AURA_INK
    dim = SEAL_AURA_DIM if evolved else SWORD_AURA_DIM
    edge = SEAL_AURA_EDGE if evolved else SWORD_AURA_EDGE
    core = SEAL_AURA_CORE if evolved else SWORD_AURA_CORE

    # Staggered afterimages form one tapering wake, never a flat white stick.
    d.line([ox + 1, cy, ox + 8, cy], fill=ink, width=3)
    d.line([ox + 2, cy, ox + 9, cy], fill=dim)
    d.line([ox + 5, cy - 3, ox + 13, cy - 2], fill=dim)
    d.line([ox + 5, cy + 3, ox + 13, cy + 2], fill=dim)
    d.point((ox + (3, 6, 2, 5)[frame], cy - 5), fill=edge)
    d.point((ox + (7, 3, 6, 2)[frame], cy + 5), fill=edge)

    # Solid outer blade aura: broad shoulder, sharpened right tip.
    aura = [
        (ox + 8, cy), (ox + 14, cy - 5), (ox + 34, cy - 4),
        (ox + 43, cy), (ox + 34, cy + 4), (ox + 14, cy + 5),
    ]
    d.polygon(aura, fill=dim, outline=ink)
    # Bright cutting edge and compact white core provide density hierarchy.
    upper_edge = [
        (ox + 12, cy - 1), (ox + 16, cy - 4), (ox + 34, cy - 3),
        (ox + 41, cy), (ox + 33, cy - 1), (ox + 17, cy),
    ]
    d.polygon(upper_edge, fill=edge)
    core_shape = [
        (ox + 16, cy), (ox + 20, cy - 1), (ox + 35, cy - 1),
        (ox + 40, cy), (ox + 34, cy + 1), (ox + 20, cy + 1),
    ]
    d.polygon(core_shape, fill=core)
    d.line([ox + 17, cy + 3, ox + 32, cy + 2], fill=edge)
    # A moving seal notch makes animation visible without altering silhouette.
    notch_x = ox + (18, 23, 28, 23)[frame]
    d.rectangle([notch_x, cy - 3, notch_x + 1, cy - 2], fill=core)
    if evolved:
        d.point((ox + 11, cy), fill=SEAL_AURA_CORE)
        d.point((ox + 29, cy + 3), fill=SEAL_AURA_CORE)


def _build_sword_aura_travel(evolved: bool) -> Image.Image:
    strip = _new((176, 16))
    for frame in range(4):
        _draw_sword_aura(strip, (frame * 44, 0), frame, evolved)
    return strip


def build_group_3() -> list[Path]:
    outputs = {
        TRAVEL / "beopgeom.png": _build_sword_aura_travel(False),
        TRAVEL / "bongmageom.png": _build_sword_aura_travel(True),
    }
    for path, image in outputs.items():
        image.save(path)
    return list(outputs)


def _alpha(color: tuple[int, int, int, int], value: int) -> tuple[int, int, int, int]:
    return color[:3] + (value,)


def _octagon(cx: int, cy: int, radius: int) -> list[tuple[int, int]]:
    cut = max(1, round(radius * 0.4))
    return [
        (cx - cut, cy - radius), (cx + cut, cy - radius),
        (cx + radius, cy - cut), (cx + radius, cy + cut),
        (cx + cut, cy + radius), (cx - cut, cy + radius),
        (cx - radius, cy + cut), (cx - radius, cy - cut),
    ]


def _closed_line(
    d: ImageDraw.ImageDraw,
    points: list[tuple[int, int]],
    fill: tuple[int, int, int, int],
    width: int = 1,
) -> None:
    d.line(points + [points[0]], fill=fill, width=width)


def _draw_jagged_ray(
    d: ImageDraw.ImageDraw,
    cx: int,
    cy: int,
    angle: float,
    start: int,
    end: int,
    outer: tuple[int, int, int, int],
    inner: tuple[int, int, int, int],
    width: int = 3,
) -> None:
    tangent_x = -math.sin(angle)
    tangent_y = math.cos(angle)
    points: list[tuple[int, int]] = []
    for step, share in enumerate((0.0, 0.38, 0.68, 1.0)):
        reach = start + (end - start) * share
        jog = (0, 2, -1, 0)[step]
        points.append((
            round(cx + math.cos(angle) * reach + tangent_x * jog),
            round(cy + math.sin(angle) * reach + tangent_y * jog),
        ))
    d.line(points, fill=outer, width=width)
    d.line(points, fill=inner, width=1)


def _build_hit_lightning() -> Image.Image:
    """6x64 luminance flare for BlastRing's tinted wave-front sprites."""
    strip = _new((384, 64))
    radii = (3, 8, 14, 21, 27, 31)
    fades = (255, 255, 255, 230, 160, 80)
    for frame, radius in enumerate(radii):
        d = ImageDraw.Draw(strip)
        cx = frame * 64 + 32
        cy = 32
        alpha = fades[frame]
        outer = _alpha(FX_INK, alpha)
        middle = _alpha(FX_LIGHT, alpha)
        core = _alpha(FX_CORE, alpha)
        if frame < 5:
            _closed_line(d, _octagon(cx, cy, max(2, radius // 2)), outer, 3)
            _closed_line(d, _octagon(cx, cy, max(2, radius // 2)), core, 1)
        for index in range(8):
            angle = math.tau * index / 8 + (frame % 2) * 0.08
            _draw_jagged_ray(
                d, cx, cy, angle, max(1, radius // 3),
                radius - (index % 2) * 2, outer, middle, 3,
            )
        if frame < 3:
            d.rectangle([cx - 2, cy - 2, cx + 2, cy + 2], fill=core)
        for index in range(4):
            angle = math.pi / 4 + math.tau * index / 4
            dist = min(30, radius + 3)
            x = round(cx + math.cos(angle) * dist)
            y = round(cy + math.sin(angle) * dist)
            d.rectangle([x, y, x + 1, y + 1], fill=core)
    return strip


def _build_hit_paper() -> Image.Image:
    """4x32 luminance ward-rim flash: angular hanji seal pulse."""
    strip = _new((128, 32))
    radii = (3, 7, 11, 15)
    fades = (255, 255, 190, 95)
    for frame, radius in enumerate(radii):
        d = ImageDraw.Draw(strip)
        cx = frame * 32 + 16
        cy = 16
        alpha = fades[frame]
        ink = _alpha(FX_INK, alpha)
        paper = _alpha(FX_LIGHT, alpha)
        core = _alpha(FX_CORE, alpha)
        points = _octagon(cx, cy, radius)
        # Broken opposing halves read as a flare laid over the circular ward.
        d.line(points[0:4], fill=ink, width=3)
        d.line(points[0:4], fill=paper, width=1)
        d.line(points[4:8], fill=ink, width=3)
        d.line(points[4:8], fill=paper, width=1)
        if frame < 3:
            d.rectangle([cx - 2, cy - 2, cx + 2, cy + 2], fill=core, outline=ink)
        # Four blocky seal ticks on the rim, all on-grid and un-antialiased.
        for x, y in ((cx, cy - radius), (cx + radius, cy), (cx, cy + radius), (cx - radius, cy)):
            d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=core)
    return strip


def _draw_pixel_cloud(
    d: ImageDraw.ImageDraw,
    cx: int,
    cy: int,
    radius: int,
    alpha: int,
) -> None:
    outline = _alpha(FX_INK, alpha)
    body = _alpha(FX_DIM, alpha)
    light = _alpha(FX_LIGHT, alpha)
    points = _octagon(cx, cy, radius)
    d.polygon(points, fill=body, outline=outline)
    if radius >= 3:
        d.rectangle(
            [cx - radius // 2, cy - radius // 2, cx + radius // 3, cy],
            fill=light,
        )


def _build_blink_puff() -> Image.Image:
    """8x64 hard-edged 축지 afterimage: expanding, breaking smoke puffs."""
    strip = _new((512, 64))
    for frame in range(8):
        d = ImageDraw.Draw(strip)
        cx = frame * 64 + 32
        cy = 35
        alpha = (255, 255, 245, 220, 185, 145, 100, 55)[frame]
        size_scale = (0.35, 0.55, 0.80, 1.00, 0.85, 0.65, 0.45, 0.30)[frame]
        spread_scale = (0.0, 0.2, 0.45, 0.7, 1.0, 1.35, 1.8, 2.25)[frame]
        # Four overlapping lobes form one irregular smoke mass at the peak;
        # only the late frames pull them apart into drifting remnants.
        template = [(-9, 1, 13), (0, -7, 16), (10, 0, 13), (-2, 7, 14), (8, -8, 10)]
        lobes: list[tuple[int, int, int]] = []
        for index, (base_x, base_y, base_radius) in enumerate(template):
            if frame >= 6 and index == 3:
                continue
            dx = round(base_x * spread_scale)
            dy = round(base_y * min(spread_scale, 1.45))
            lobe_radius = max(2, round(base_radius * size_scale))
            lobes.append((cx + dx, cy + dy, lobe_radius))
        # Paint the union in layers so overlapping lobes merge into one smoky
        # silhouette instead of reading as a row of outlined bubbles.
        for x, y, lobe_radius in lobes:
            d.polygon(_octagon(x, y, lobe_radius), fill=_alpha(FX_INK, alpha))
        for x, y, lobe_radius in lobes:
            inner_radius = max(1, lobe_radius - 1)
            d.polygon(_octagon(x, y, inner_radius), fill=_alpha(FX_DIM, alpha))
        for index, (x, y, lobe_radius) in enumerate(lobes):
            if index not in (1, 4) or lobe_radius < 4:
                continue
            d.polygon(
                _octagon(x - 1, y - 2, max(1, lobe_radius // 3)),
                fill=_alpha(FX_LIGHT, alpha),
            )
        # Angular transparent eddies break the peak cloud into smoke folds.
        if 2 <= frame <= 5:
            d.rectangle([cx - 3, cy - 2, cx, cy + 1], fill=TRANSPARENT)
            d.rectangle([cx + 5, cy + 3, cx + 7, cy + 5], fill=TRANSPARENT)
        # Ground-hugging speed streaks distinguish blink smoke from an impact.
        streak = _alpha(FX_LIGHT, alpha)
        reach = min(28, 5 + frame * 4)
        d.line([cx - reach, cy + 12, cx - 4, cy + 12], fill=streak)
        d.line([cx + 4, cy + 14, cx + reach, cy + 14], fill=streak)
    return strip


def _build_hit_noebu() -> Image.Image:
    """6x52 thunder-talisman impact with flat cyan/gold lightning layers."""
    strip = _new((312, 52))
    radii = (3, 8, 15, 22, 25, 25)
    fades = (255, 255, 255, 235, 150, 70)
    for frame, radius in enumerate(radii):
        d = ImageDraw.Draw(strip)
        cx = frame * 52 + 26
        cy = 26
        alpha = fades[frame]
        ink = _alpha(THUNDER_INK, alpha)
        blue = _alpha(THUNDER_BLUE, alpha)
        cyan = _alpha(THUNDER_CYAN, alpha)
        gold = _alpha(THUNDER_GOLD, alpha)
        white = _alpha(THUNDER_CORE, alpha)
        if frame < 5:
            _closed_line(d, _octagon(cx, cy, max(2, radius // 2)), ink, 3)
            _closed_line(d, _octagon(cx, cy, max(2, radius // 2)), cyan, 1)
        for index in range(8):
            angle = math.tau * index / 8 + (frame % 2) * 0.09
            color = gold if index % 2 else cyan
            _draw_jagged_ray(
                d, cx, cy, angle, max(1, radius // 3),
                radius - (index % 3), ink, color, 3,
            )
        if frame < 4:
            d.polygon(
                [(cx, cy - 5), (cx + 5, cy), (cx, cy + 5), (cx - 5, cy)],
                fill=blue, outline=ink,
            )
            d.rectangle([cx - 1, cy - 2, cx + 1, cy + 2], fill=white)
        for index in range(4):
            angle = math.pi / 4 + math.tau * index / 4
            dist = min(24, radius + 3)
            x = round(cx + math.cos(angle) * dist)
            y = round(cy + math.sin(angle) * dist)
            d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=gold if index % 2 else cyan)
    return strip


def _build_cast_noebu() -> Image.Image:
    """4x34 matching thunder seal charge, from spark to locked diamond."""
    strip = _new((136, 34))
    radii = (3, 7, 11, 15)
    for frame, radius in enumerate(radii):
        d = ImageDraw.Draw(strip)
        cx = frame * 34 + 17
        cy = 17
        ink = THUNDER_INK
        d.polygon(
            [(cx, cy - radius), (cx + radius, cy), (cx, cy + radius), (cx - radius, cy)],
            outline=ink,
        )
        inner_radius = max(1, radius - 3)
        _closed_line(d, _octagon(cx, cy, inner_radius), THUNDER_CYAN, 2)
        for index in range(4):
            angle = math.tau * index / 4
            _draw_jagged_ray(d, cx, cy, angle, 1, radius, ink, THUNDER_GOLD, 3)
        d.rectangle([cx - 2, cy - 2, cx + 2, cy + 2], fill=THUNDER_CORE, outline=ink)
        if frame >= 2:
            d.point((cx - radius + 2, cy - radius + 2), fill=THUNDER_CORE)
            d.point((cx + radius - 2, cy + radius - 2), fill=THUNDER_CORE)
    return strip


def build_group_4() -> list[Path]:
    outputs = {
        EFFECT / "hit_lightning.png": _build_hit_lightning(),
        EFFECT / "hit_paper.png": _build_hit_paper(),
        EFFECT / "blink_puff.png": _build_blink_puff(),
        EFFECT / "hit_noebu.png": _build_hit_noebu(),
        EFFECT / "cast_noebu.png": _build_cast_noebu(),
    }
    for path, image in outputs.items():
        image.save(path)
    return list(outputs)


GROUPS = {
    1: build_group_1,
    2: build_group_2,
    3: build_group_3,
    4: build_group_4,
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--group", type=int, choices=GROUPS, required=True)
    args = parser.parse_args()
    for output in GROUPS[args.group]():
        with Image.open(output) as image:
            print(output.relative_to(ROOT), image.size, image.mode)


if __name__ == "__main__":
    main()
