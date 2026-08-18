"""Camp backdrop (N9-12): composited from the N1-2-REVISED production
title layers — the base camp IS the village the title shows, so the
backdrop reuses that art instead of a lower-quality fresh generation.
Night sky (moon high) over the hanok village, then a NIGHT-tinted scrim
heavy at the top and center so the camp's cards and buttons stay the
primary read (DESIGN.md dark meta grammar).
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
NIGHT = (22, 17, 13)


def main() -> None:
    sky = Image.open(ROOT / "asset" / "title" / "bg_sky.png").convert("RGBA")
    village = Image.open(ROOT / "asset" / "title" / "bg_village.png").convert("RGBA")
    backdrop = sky.copy()
    backdrop.alpha_composite(village)
    # Scrim: strong at the top (title/stats zone), lighter toward the
    # village so the lanterns still glow through behind the buttons.
    scrim = Image.new("RGBA", backdrop.size, (0, 0, 0, 0))
    px = scrim.load()
    height = backdrop.size[1]
    for y in range(height):
        t = y / height
        alpha = int(215 - 70 * t)  # 215 top -> 145 bottom
        for x in range(backdrop.size[0]):
            px[x, y] = (*NIGHT, alpha)
    backdrop.alpha_composite(scrim)
    backdrop.convert("RGB").save(OUT / "backdrop.png")
    print("backdrop.png", backdrop.size)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    main()
