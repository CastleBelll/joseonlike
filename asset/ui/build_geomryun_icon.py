"""Placeholder icon for 검륜, the warrior's orbiting blade root (B2-2).

The owner is generating art right now and said to note what is needed and keep
going. validate_data refuses a weapon with no icon, so the roster cannot land
without something here. This follows the same contract as every other weapon
icon in the project — 32 logical px, exported x16 with NEAREST — and is drawn to
read apart from the other melee roots at strip size: a ring of blades rather
than a single shaft, because what makes 검륜 different is that it circles.

Replace it with authored art; ASSET_REQUIREMENTS.md carries the entry.

Run: python asset/ui/build_geomryun_icon.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "asset" / "ui" / "weapon_icons"

LOGICAL_PX = 32
EXPORT_SCALE = 16

INK = (14, 12, 15, 255)
STEEL_DARK = (86, 94, 106, 255)
STEEL = (140, 150, 164, 255)
STEEL_HI = (206, 214, 226, 255)
## The warrior's accent, so the ring reads as 검기 rather than as loose metal.
QI = (196, 168, 92, 255)

BLADES = 3
## The ring has to stay readable while the blades carry the silhouette, so
## the blades take most of the radius rather than perching on it.
RING_RADIUS = 7.5
BLADE_LEN = 8.0


def blade(draw, cx, cy, angle_deg):
    """One blade standing off the ring, pointing outward along its own radius."""
    a = math.radians(angle_deg)
    ox, oy = math.cos(a), math.sin(a)
    # Perpendicular, for the blade's width.
    px, py = -oy, ox
    inner = (cx + ox * RING_RADIUS, cy + oy * RING_RADIUS)
    tip = (cx + ox * (RING_RADIUS + BLADE_LEN), cy + oy * (RING_RADIUS + BLADE_LEN))
    half = 2.6
    quad = [
        (inner[0] + px * half, inner[1] + py * half),
        (tip[0], tip[1]),
        (inner[0] - px * half, inner[1] - py * half),
    ]
    draw.polygon(quad, fill=STEEL, outline=INK)
    # A lit edge on one side so the blade has a direction at strip size.
    draw.line(
        [(inner[0] + px * half * 0.4, inner[1] + py * half * 0.4), tip],
        fill=STEEL_HI, width=1,
    )


def main():
    size = LOGICAL_PX
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    cx = cy = size / 2.0 - 0.5
    # The path the blades travel, drawn faintly: the icon has to say "this one
    # goes around you", which a single blade cannot.
    draw.ellipse(
        [cx - RING_RADIUS, cy - RING_RADIUS, cx + RING_RADIUS, cy + RING_RADIUS],
        outline=QI,
    )
    draw.ellipse(
        [cx - RING_RADIUS + 1, cy - RING_RADIUS + 1,
         cx + RING_RADIUS - 1, cy + RING_RADIUS - 1],
        outline=STEEL_DARK,
    )
    for i in range(BLADES):
        blade(draw, cx, cy, -90.0 + i * (360.0 / BLADES))
    out = image.resize(
        (size * EXPORT_SCALE, size * EXPORT_SCALE), Image.NEAREST
    )
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / "geomryun.png"
    out.save(path)
    print(f"  geomryun  {size}px logical -> {out.width}x{out.height}")
    print(f"1 icon -> {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
