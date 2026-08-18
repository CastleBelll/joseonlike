#!/usr/bin/env python3
"""Generate the settings gear icon to match the existing HUD icon set
(pause.png/skull.png/etc): hard-edged pixel art, ink outline, cream fill,
drawn on a small grid and NEAREST-upscaled to 256x256 (HUD_ICON_DIR
convention, scripts/ui/ui_icons.gd + combat_hud.gd's _corner_icon pattern).
"""

import math
from PIL import Image, ImageDraw

INK = (13, 11, 9, 255)
CREAM = (240, 236, 218, 255)
SHADE = (166, 154, 141, 255)

GRID = 32   # small canvas, hard-edged shapes, then NEAREST-upscaled
SCALE = 8   # -> 256x256, matching the existing icon set's resolution

CENTER = (GRID / 2, GRID / 2)
BODY_R = 9
HOLE_R = 3.5
TOOTH_COUNT = 8
TOOTH_LEN = 4
TOOTH_W = 5


def gear_polygon() -> list:
    """Body-plus-teeth outline as one polygon (star-ish gear silhouette)."""
    points = []
    for i in range(TOOTH_COUNT):
        angle = 2 * math.pi * i / TOOTH_COUNT
        half_w = math.atan2(TOOTH_W / 2, BODY_R)
        for a in (angle - half_w, angle + half_w):
            points.append((
                CENTER[0] + math.cos(a) * BODY_R,
                CENTER[1] + math.sin(a) * BODY_R,
            ))
        for a in (angle - half_w * 0.6, angle + half_w * 0.6):
            points.append((
                CENTER[0] + math.cos(a) * (BODY_R + TOOTH_LEN),
                CENTER[1] + math.sin(a) * (BODY_R + TOOTH_LEN),
            ))
    # Re-order into a proper star silhouette by angle around center.
    points.sort(key=lambda p: math.atan2(p[1] - CENTER[1], p[0] - CENTER[0]))
    return points


def main() -> None:
    img = Image.new("RGBA", (GRID, GRID), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    outline_r = BODY_R + TOOTH_LEN + 1.5
    draw.ellipse(
        [CENTER[0] - outline_r, CENTER[1] - outline_r, CENTER[0] + outline_r, CENTER[1] + outline_r],
        fill=INK,
    )
    for i in range(TOOTH_COUNT):
        angle = 2 * math.pi * i / TOOTH_COUNT
        tx = CENTER[0] + math.cos(angle) * (BODY_R + TOOTH_LEN * 0.6)
        ty = CENTER[1] + math.sin(angle) * (BODY_R + TOOTH_LEN * 0.6)
        half = TOOTH_W / 2 + 1.5
        draw.ellipse([tx - half, ty - half, tx + half, ty + half], fill=INK)

    body_r = BODY_R
    draw.ellipse(
        [CENTER[0] - body_r, CENTER[1] - body_r, CENTER[0] + body_r, CENTER[1] + body_r],
        fill=CREAM,
    )
    for i in range(TOOTH_COUNT):
        angle = 2 * math.pi * i / TOOTH_COUNT
        tx = CENTER[0] + math.cos(angle) * (BODY_R + TOOTH_LEN * 0.5)
        ty = CENTER[1] + math.sin(angle) * (BODY_R + TOOTH_LEN * 0.5)
        half = TOOTH_W / 2
        draw.ellipse([tx - half, ty - half, tx + half, ty + half], fill=CREAM)

    hole_outline_r = HOLE_R + 1.5
    draw.ellipse(
        [CENTER[0] - hole_outline_r, CENTER[1] - hole_outline_r,
         CENTER[0] + hole_outline_r, CENTER[1] + hole_outline_r],
        fill=INK,
    )
    draw.ellipse(
        [CENTER[0] - HOLE_R, CENTER[1] - HOLE_R, CENTER[0] + HOLE_R, CENTER[1] + HOLE_R],
        fill=(0, 0, 0, 0),
    )

    # Threshold alpha to hard edges (no PIL anti-aliasing artifacts) before
    # upscaling, keeping the pixel-art look consistent with the icon set.
    px = img.load()
    for y in range(GRID):
        for x in range(GRID):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= 128 else 0)

    big = img.resize((GRID * SCALE, GRID * SCALE), Image.NEAREST)
    big.save("asset/ui/hud/settings.png")
    print(f"Saved asset/ui/hud/settings.png ({big.size[0]}x{big.size[1]})")


if __name__ == "__main__":
    main()
