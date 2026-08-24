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
ICON_SMOKE_SHADOW = (36, 18, 52, 255)
ICON_SMOKE_DEEP = (57, 27, 82, 255)
ICON_SMOKE_MID = (84, 40, 119, 255)
ICON_SMOKE_LIGHT = (125, 60, 167, 255)
ICON_SMOKE_HOT = (190, 79, 220, 255)
ICON_PAPER_EDGE = (70, 59, 79, 255)
ICON_PAPER_DARK = (104, 91, 115, 255)
ICON_PAPER_MID = (151, 137, 160, 255)
ICON_PAPER_PALE = (191, 180, 198, 255)
ICON_PAPER_HIGH = (224, 214, 226, 255)
ICON_INK_BLEED = (49, 34, 61, 255)
ICON_PAPER_TEXTURE = (
    (82, 69, 91, 255), (96, 82, 105, 255), (116, 101, 125, 255),
    (128, 113, 137, 255), (143, 128, 151, 255), (159, 145, 167, 255),
    (173, 159, 180, 255), (185, 171, 192, 255), (198, 186, 204, 255),
    (210, 199, 215, 255), (218, 207, 221, 255), (231, 222, 232, 255),
)
ICON_SMOKE_TEXTURE = (
    (45, 21, 65, 255), (51, 24, 73, 255), (64, 30, 91, 255),
    (72, 34, 102, 255), (91, 43, 128, 255), (102, 49, 142, 255),
    (113, 54, 154, 255), (137, 65, 177, 255),
)
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
    # Fold/highlight and compact non-linguistic seal marks.  Never join these
    # into a vertical crossed by horizontal bars: at this scale that became 王.
    fold = CURSE_MID if not evolved else CURSE_MAGENTA
    d.line([ox + 28, y + 12, ox + 28, y + 18], fill=fold)
    d.line([ox + 29, y + 13, ox + 31, y + 15], fill=fold)
    d.line([ox + 19, y + 13, ox + 21, y + 15], fill=CURSE_INK)
    d.point((ox + 24, y + 13), fill=CURSE_INK)
    d.line([ox + 24, y + 15, ox + 25, y + 16], fill=CURSE_INK)
    d.line([ox + 19, y + 18, ox + 20, y + 18], fill=CURSE_INK)
    d.point((ox + 22, y + 17), fill=CURSE_INK)
    d.point((ox + 25, y + 18), fill=CURSE_INK)
    if evolved:
        d.point((ox + 26, y + 15), fill=CURSE_CORE)
        d.point((ox + 11, y + 14), fill=CURSE_CORE)


def _build_curse_travel(evolved: bool) -> Image.Image:
    strip = _new((144, 36))
    for frame in range(4):
        _draw_curse_projectile(strip, (frame * 36, 0), frame, evolved)
    return strip


def _draw_curse_icon_base(evolved: bool) -> Image.Image:
    """64px review-native icon, exported 8x with nearest-neighbour pixels.

    Authoring at the actual HUD size prevents detail that exists only in the
    512px source from collapsing when the inventory renders the icon at 64px.
    """
    image = _new((64, 64))
    d = ImageDraw.Draw(image)
    smoke_mid = ICON_SMOKE_LIGHT if evolved else ICON_SMOKE_MID
    smoke_light = ICON_SMOKE_HOT if evolved else ICON_SMOKE_LIGHT
    seal = CURSE_MAGENTA if evolved else CURSE_MID
    paper_mid = ICON_PAPER_PALE if evolved else ICON_PAPER_MID
    paper_high = CURSE_CORE if evolved else ICON_PAPER_HIGH

    # A single broad, angular smoke mass supports the charm.  It has cloud
    # lobes and cut-ins, not limb-like separated tendrils.  The pair shares
    # every geometry coordinate; evolution changes palette only.
    smoke_outer = [
        (2, 34), (8, 28), (5, 21), (14, 18), (14, 11), (24, 14),
        (29, 7), (37, 13), (48, 10), (51, 18), (60, 22), (56, 30),
        (62, 36), (55, 43), (57, 53), (47, 52), (40, 60), (31, 55),
        (23, 62), (17, 54), (7, 55), (9, 46), (2, 41),
    ]
    d.polygon(smoke_outer, fill=CURSE_INK)
    smoke_body = [
        (5, 34), (11, 29), (8, 23), (17, 21), (17, 15), (25, 18),
        (30, 11), (36, 17), (46, 14), (48, 21), (56, 24), (52, 30),
        (58, 36), (52, 41), (53, 49), (45, 48), (39, 55), (31, 51),
        (24, 57), (18, 50), (11, 52), (13, 44), (6, 40),
    ]
    d.polygon(smoke_body, fill=ICON_SMOKE_DEEP)
    # Layered cel-shaded flow bands survive the exact 64px review size.
    d.line([(8, 36), (15, 31), (13, 25), (21, 23), (24, 17)], fill=smoke_mid, width=3)
    d.line([(33, 14), (40, 19), (50, 18), (51, 25), (56, 27)], fill=smoke_mid, width=3)
    d.line([(52, 35), (48, 41), (49, 47), (42, 45), (37, 53)], fill=smoke_mid, width=3)
    d.line([(13, 45), (20, 47), (24, 54), (30, 49)], fill=ICON_SMOKE_MID, width=2)
    d.line([(9, 34), (15, 30), (15, 26)], fill=smoke_light)
    d.line([(35, 15), (41, 20), (48, 19)], fill=smoke_light)
    d.line([(50, 36), (46, 41), (47, 45)], fill=smoke_light)
    # Small negative pockets break the mass into drifting smoke folds.
    d.polygon([(8, 21), (12, 19), (13, 23), (10, 26)], fill=TRANSPARENT)
    d.polygon([(51, 49), (55, 47), (55, 51), (53, 54)], fill=TRANSPARENT)
    smoke_grain = (
        (7, 35), (11, 30), (12, 43), (18, 17), (24, 18), (31, 12),
        (43, 16), (53, 25), (55, 38), (47, 45), (28, 55), (18, 51),
    )
    for index, (x, y) in enumerate(smoke_grain):
        tone = ICON_SMOKE_TEXTURE[index % len(ICON_SMOKE_TEXTURE)]
        if evolved and index % 3 == 0:
            tone = CURSE_BRIGHT
        d.line([(x, y), (x + 1, y - 1)], fill=tone)

    # Deep thickness/shadow under a vertically canted torn hanji charm.
    paper_shadow = [
        (22, 6), (45, 9), (51, 14), (48, 25), (52, 31), (47, 56),
        (41, 61), (18, 57), (11, 51), (15, 38), (12, 32), (18, 9),
    ]
    d.polygon(paper_shadow, fill=CURSE_INK)
    paper_edge = [
        (21, 6), (43, 8), (49, 13), (46, 25), (50, 30), (45, 54),
        (40, 59), (18, 55), (13, 50), (17, 38), (14, 31), (19, 8),
    ]
    d.polygon(paper_edge, fill=ICON_PAPER_EDGE)
    paper = [
        (22, 8), (42, 10), (46, 13), (43, 25), (47, 30), (42, 52),
        (38, 55), (20, 52), (16, 49), (20, 38), (17, 31), (21, 10),
    ]
    d.polygon(paper, fill=paper_mid)
    # Faceted light and shadow planes give the paper volume at 64px.
    d.polygon([(22, 9), (39, 11), (42, 14), (38, 16), (23, 14)], fill=paper_high)
    d.polygon([(18, 31), (22, 29), (42, 31), (44, 35), (20, 37)], fill=ICON_PAPER_DARK)
    d.polygon([(21, 38), (44, 35), (41, 50), (37, 53), (21, 50)], fill=ICON_PAPER_PALE)
    d.polygon([(39, 11), (46, 14), (43, 25), (47, 30), (43, 34), (40, 28)], fill=ICON_PAPER_DARK)
    d.line([(21, 10), (19, 28), (22, 29)], fill=paper_high, width=2)
    d.line([(20, 39), (18, 48), (22, 51)], fill=ICON_PAPER_HIGH)

    # Rolled/torn caps and fold creases echo the approved talisman icons.
    d.polygon([(20, 6), (43, 8), (46, 11), (42, 13), (22, 11), (18, 9)], fill=ICON_PAPER_DARK)
    d.line([(22, 7), (41, 9), (44, 11)], fill=paper_high)
    d.polygon([(18, 50), (24, 51), (38, 53), (41, 57), (38, 59), (18, 55), (13, 50)], fill=ICON_PAPER_DARK)
    d.line([(18, 51), (24, 53), (37, 54), (39, 57)], fill=paper_high)
    d.line([(23, 15), (20, 27)], fill=ICON_PAPER_DARK)
    d.line([(40, 18), (42, 24)], fill=ICON_PAPER_HIGH)
    d.line([(23, 41), (21, 47)], fill=ICON_PAPER_DARK)
    d.line([(37, 39), (40, 48)], fill=ICON_PAPER_HIGH)

    # Irregular one- and two-pixel paper grain.  These are deliberately short
    # diagonals/chips, never aligned into handwriting strokes.
    paper_grain = (
        (24, 12), (29, 11), (36, 12), (41, 14), (22, 17), (25, 21),
        (39, 19), (23, 26), (37, 23), (22, 39), (29, 38), (40, 38),
        (25, 44), (33, 47), (38, 50), (20, 48), (42, 32), (24, 30),
    )
    for index, (x, y) in enumerate(paper_grain):
        tone = ICON_PAPER_TEXTURE[index % len(ICON_PAPER_TEXTURE)]
        if index % 4 == 0:
            d.line([(x, y), (x + 1, y - 1)], fill=tone)
        else:
            d.point((x, y), fill=tone)

    # Disconnected non-linguistic seal fragments.  Diamonds, diagonals,
    # corners, dots and a broken spiral suggest ritual ink but cannot resolve
    # into a Chinese/Korean/Japanese/Latin character or numeral.
    bleed = ICON_INK_BLEED
    for line in (
        (26, 15, 30, 12), (34, 13, 37, 15), (34, 18, 31, 20), (39, 19, 37, 22),
        (26, 28, 29, 25), (33, 25, 36, 27), (38, 30, 35, 33), (28, 35, 25, 32),
        (27, 43, 31, 40), (35, 41, 38, 45), (36, 48, 32, 50),
    ):
        d.line(line, fill=bleed, width=2)
    for line in (
        (26, 15, 30, 13), (34, 14, 37, 15), (34, 18, 31, 19), (39, 19, 37, 21),
        (26, 28, 29, 26), (33, 26, 36, 27), (38, 30, 35, 32), (28, 34, 25, 32),
        (27, 43, 31, 41), (35, 42, 37, 45), (35, 48, 32, 49),
    ):
        d.line(line, fill=seal)
    for x, y in ((24, 19), (39, 13), (31, 29), (38, 36), (26, 38), (30, 46), (40, 27)):
        d.rectangle([x, y, x + 1, y + 1], fill=seal)

    # Paper fibres and chips: short diagonal marks only, never character bars.
    fibres = [
        (24, 18, ICON_PAPER_HIGH), (40, 16, ICON_PAPER_EDGE),
        (22, 24, ICON_PAPER_DARK), (39, 23, ICON_PAPER_HIGH),
        (24, 34, ICON_PAPER_EDGE), (41, 34, ICON_PAPER_HIGH),
        (22, 45, ICON_PAPER_DARK), (39, 46, ICON_PAPER_EDGE),
        (25, 49, ICON_PAPER_HIGH), (43, 28, ICON_PAPER_EDGE),
    ]
    for x, y, color in fibres:
        d.line([(x, y), (x + 1, y - 1)], fill=color)

    # Identical spark silhouette in both stages; Gwisal only raises intensity.
    for index, (x, y) in enumerate(((5, 17), (8, 48), (18, 4), (53, 13), (59, 43), (46, 59))):
        color = smoke_light if index % 2 == 0 else smoke_mid
        d.rectangle([x, y, x + 1, y + 1], fill=color)
    for x, y in ((12, 34), (34, 8), (48, 48)):
        d.point((x, y), fill=CURSE_CORE if evolved else ICON_SMOKE_LIGHT)
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
