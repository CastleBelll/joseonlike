"""Placeholder icons for the archer's roots and their 개조 (N10-8).

Same reason as build_melee_icons.py: validate_data refuses a weapon with no
icon and the build strip letter-renders it, so the roster cannot land without
something here. Stand-ins on the 32px-logical, x16 NEAREST contract, drawn so
the four separate at strip size — a stocky stock-and-bow silhouette for the
crossbows, loose shafts for the arrows.

Replace with authored art; docs/ART_PROMPTS.md carries the prompts.

Run: python asset/ui/build_ranged_icons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "asset" / "ui" / "weapon_icons"

LOGICAL_PX = 32
EXPORT_SCALE = 16

INK = (14, 12, 15, 255)
WOOD_DARK = (72, 48, 30, 255)
WOOD = (116, 80, 48, 255)
STEEL = (140, 150, 164, 255)
STEEL_HI = (206, 214, 226, 255)
BRASS = (176, 138, 62, 255)
BRASS_HI = (224, 190, 104, 255)
FLETCH = (222, 214, 196, 255)
CORD = (198, 190, 170, 255)


def canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (LOGICAL_PX, LOGICAL_PX), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def _crossbow(metal: tuple, metal_hi: tuple, magazine: bool) -> Image.Image:
    """Stock across the frame, limbs bowing forward, string drawn back."""
    image, draw = canvas()
    draw.line([(6, 22), (25, 13)], fill=INK, width=5)          # stock, outlined
    draw.line([(7, 21), (24, 14)], fill=WOOD, width=3)
    draw.point((9, 20), fill=WOOD_DARK)
    draw.line([(20, 6), (23, 15)], fill=INK, width=3)          # upper limb
    draw.line([(20, 7), (23, 15)], fill=metal, width=1)
    draw.line([(24, 21), (21, 12)], fill=INK, width=3)         # lower limb
    draw.line([(24, 20), (21, 13)], fill=metal, width=1)
    draw.line([(20, 6), (24, 21)], fill=CORD)                  # string
    draw.line([(10, 19), (13, 18)], fill=BRASS, width=2)       # trigger housing
    draw.point((11, 18), fill=BRASS_HI)
    if magazine:
        draw.rectangle([14, 10, 20, 14], fill=INK)             # 수노기 bolt box
        draw.rectangle([15, 11, 19, 13], fill=metal_hi)
    return image


def _arrows(shafts: int, head: tuple, heavy: bool) -> Image.Image:
    """Loose shafts laid diagonally, heads up-right, fletching down-left."""
    image, draw = canvas()
    for index in range(shafts):
        offset = index * 5 - (shafts - 1) * 2
        tail = (5 + offset, 26)
        tip = (23 + offset, 7)
        draw.line([tail, tip], fill=INK, width=3)
        draw.line([tail, tip], fill=WOOD, width=1)
        head_size = 4 if heavy else 3
        draw.polygon(
            [tip, (tip[0] - head_size, tip[1] + 1), (tip[0] - 1, tip[1] + head_size)],
            fill=head,
        )
        draw.line([tail, (tail[0] + 3, tail[1] - 3)], fill=FLETCH, width=2)
    return image


ICONS = {
    "soenoe": lambda: _crossbow(STEEL, STEEL_HI, magazine=False),
    "sunogi": lambda: _crossbow(BRASS, BRASS_HI, magazine=True),
    "pyeonjeon": lambda: _arrows(3, STEEL, heavy=False),
    "yungnyangjeon": lambda: _arrows(1, STEEL_HI, heavy=True),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    side = LOGICAL_PX * EXPORT_SCALE
    for name, build in ICONS.items():
        icon = build()
        icon.resize((side, side), Image.NEAREST).save(OUT / f"{name}.png")
        opaque = sum(1 for p in icon.get_flattened_data() if p[3] > 0)
        print(f"  {name}: {side}x{side}, {opaque} lit px")


if __name__ == "__main__":
    main()
