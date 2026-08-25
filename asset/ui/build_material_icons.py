"""Draw the three 삼두구미 gate materials as loot icons (N10-3b).

무쇠 · 생달걀 · 버드나무 가지. Every loot icon in this project is authored at
its 32px logical size and blown up by 16 with NEAREST, so that contract is what
this follows: draw on the 32-grid, scale, done. Nothing here is clever — they
are three small still objects, and a still object at 32px is a shape, two or
three tones and an outline.

Run: python asset/ui/build_material_icons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "asset" / "ui" / "loot_icons"

LOGICAL_PX = 32
EXPORT_SCALE = 16

INK = (14, 12, 15, 255)
IRON_DARK = (38, 40, 45, 255)
IRON = (66, 70, 77, 255)
IRON_HI = (104, 110, 118, 255)
SHELL_DARK = (198, 176, 132, 255)
SHELL = (233, 216, 178, 255)
SHELL_HI = (252, 245, 222, 255)
BARK_DARK = (74, 56, 38, 255)
BARK = (110, 84, 56, 255)
LEAF_DARK = (58, 104, 56, 255)
LEAF = (96, 152, 78, 255)
LEAF_HI = (146, 196, 108, 255)


def canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (LOGICAL_PX, LOGICAL_PX), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def cast_iron() -> Image.Image:
    """A rough block, seen from a low angle so the top face carries the light.

    Sized to fill its frame like the crystals it sits beside in the pouch — a
    small shape floating in a big icon reads as unfinished next to them.
    """
    image, draw = canvas()
    draw.polygon(((2, 12), (16, 3), (30, 12), (30, 25), (16, 31), (2, 25)), fill=INK)
    draw.polygon(((5, 12), (16, 5), (27, 12), (16, 18)), fill=IRON_HI)
    draw.polygon(((6, 13), (16, 19), (16, 28), (6, 23)), fill=IRON)
    draw.polygon(((26, 13), (16, 19), (16, 28), (26, 23)), fill=IRON_DARK)
    # The lit face keeps a brighter ridge along the near edge, so the block has
    # a direction instead of being three flat facets.
    draw.line((6, 12, 16, 6), fill=(134, 140, 148, 255), width=1)
    draw.line((16, 19, 6, 13), fill=(88, 94, 102, 255), width=1)
    # Cast iron is never smooth, and a few dark pixels are how that reads here.
    for pit in ((10, 17), (13, 21), (20, 22), (23, 17), (17, 25)):
        draw.point(pit, fill=INK)
    return image


def raw_egg() -> Image.Image:
    """One egg standing upright, narrow end up."""
    image, draw = canvas()
    draw.ellipse((7, 2, 25, 30), fill=INK)
    draw.ellipse((8, 4, 24, 29), fill=SHELL_DARK)
    draw.ellipse((9, 5, 22, 26), fill=SHELL)
    # Two steps of light, not one: an egg is round, and a single blob of
    # highlight on a flat fill reads as a sticker rather than a shell.
    draw.ellipse((11, 7, 19, 20), fill=(244, 232, 200, 255))
    draw.ellipse((12, 8, 16, 15), fill=SHELL_HI)
    return image


def willow_branch() -> Image.Image:
    """A cut branch on the diagonal, leaves along its upper side."""
    image, draw = canvas()
    draw.line((4, 29, 28, 4), fill=INK, width=5)
    draw.line((4, 29, 28, 4), fill=BARK, width=3)
    draw.line((5, 28, 27, 5), fill=BARK_DARK, width=1)
    draw.line((6, 26, 26, 6), fill=(140, 110, 74, 255), width=1)
    leaves = (
        ((8, 23), (2, 19), (9, 17)),
        ((14, 17), (8, 12), (15, 11)),
        ((21, 10), (15, 5), (22, 3)),
        ((17, 19), (24, 18), (20, 25)),
        ((11, 26), (17, 27), (13, 31)),
    )
    for index, leaf in enumerate(leaves):
        draw.polygon(leaf, fill=INK)
        inner = tuple(
            (round(x + (leaf[0][0] - x) * 0.28), round(y + (leaf[0][1] - y) * 0.28))
            for x, y in leaf
        )
        draw.polygon(inner, fill=LEAF if index % 2 == 0 else LEAF_DARK)
    draw.point((12, 16), fill=LEAF_HI)
    draw.point((17, 11), fill=LEAF_HI)
    return image


ICONS = {
    "cast_iron": cast_iron,
    "raw_egg": raw_egg,
    "willow_branch": willow_branch,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, build in ICONS.items():
        icon = build()
        side = LOGICAL_PX * EXPORT_SCALE
        icon.resize((side, side), Image.NEAREST).save(OUT / f"{name}.png")
        opaque = {p for p in icon.get_flattened_data() if p[3] > 0}
        print(f"  {name}: {side}x{side}, {len(opaque)} colours")


if __name__ == "__main__":
    main()
