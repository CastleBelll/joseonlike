"""Placeholder icons for the two new melee roots and their 개조 (N10-7).

The owner is drawing sprites right now and said the weapon icons can come
later — but a weapon with no icon letter-renders in the build strip and
validate_data refuses it, so the roster cannot land without something here.
These are stand-ins: the same 32px-logical, x16 NEAREST contract every weapon
icon in this project follows, drawn so the four read apart at strip size
(long diagonal shaft vs short handle plus a swung head).

Replace them with authored art; ASSET_REQUIREMENTS.md carries the entry.

Run: python asset/ui/build_melee_icons.py
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
STEEL_DARK = (86, 94, 106, 255)
STEEL = (140, 150, 164, 255)
STEEL_HI = (206, 214, 226, 255)
JADE_DARK = (28, 96, 104, 255)
JADE = (64, 158, 160, 255)
JADE_HI = (140, 214, 206, 255)
GOLD = (196, 156, 62, 255)
TASSEL = (168, 48, 52, 255)


def canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (LOGICAL_PX, LOGICAL_PX), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def _shaft(draw: ImageDraw.ImageDraw, tail: tuple, head: tuple) -> None:
    """Outlined pole: ink first, wood over it, so the 1px outline survives."""
    draw.line([tail, head], fill=INK, width=4)
    draw.line([tail, head], fill=WOOD, width=2)
    draw.point((tail[0] + 1, tail[1] - 1), fill=WOOD_DARK)


def _glaive(blade: tuple, blade_dark: tuple, edge: tuple) -> Image.Image:
    """A pole with a curved single-edged head — 월도 and its 개조."""
    image, draw = canvas()
    _shaft(draw, (7, 27), (19, 12))
    draw.polygon([(19, 13), (26, 4), (28, 12), (22, 17)], fill=INK)
    draw.polygon([(20, 13), (25, 6), (26, 12), (22, 15)], fill=blade)
    draw.line([(25, 6), (26, 12)], fill=edge)
    draw.line([(20, 14), (23, 15)], fill=blade_dark)
    draw.line([(17, 14), (20, 11)], fill=GOLD, width=2)  # ferrule
    draw.line([(6, 28), (4, 30)], fill=TASSEL, width=2)  # grip tassel
    return image


def _flail(head: tuple, head_hi: tuple, studs: tuple) -> Image.Image:
    """Short haft, two chain links, a swung striking rod — 편곤 and its 개조."""
    image, draw = canvas()
    _shaft(draw, (6, 26), (14, 18))
    draw.point((15, 17), fill=INK)
    draw.point((17, 15), fill=INK)
    draw.point((16, 16), fill=STEEL_HI)
    draw.point((18, 14), fill=STEEL_HI)
    draw.line([(19, 14), (27, 6)], fill=INK, width=5)
    draw.line([(19, 14), (27, 6)], fill=head, width=3)
    draw.line([(21, 11), (26, 6)], fill=head_hi)
    for at in ((21, 13), (24, 10), (26, 8)):
        draw.point(at, fill=studs)
    draw.line([(5, 27), (3, 29)], fill=TASSEL, width=2)
    return image


ICONS = {
    "wolto": lambda: _glaive(STEEL, STEEL_DARK, STEEL_HI),
    "cheongryong_wolto": lambda: _glaive(JADE, JADE_DARK, JADE_HI),
    "pyeongon": lambda: _flail(WOOD, (150, 112, 70, 255), STEEL),
    "masang_pyeongon": lambda: _flail(STEEL, STEEL_HI, GOLD),
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
