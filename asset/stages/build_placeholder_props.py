"""Placeholder art for the four props that have never existed.

props.json has referenced water_puddle, prop_flame, anvil and stone_marker since
it was written, and none of the four is in HEAD or has ever been — which has
kept validate_data, and with it CI, red on every run. A red gate masks every
real failure that lands after it.

The real art needs the owner: bamboo_forest/build_assets.py refuses to run
without two Higgsfield originals only the owner can download, and only
water_puddle is even in its SPRITES table. Until then these stand in, drawn to
the stage-prop contract (32 logical px, x16 NEAREST, 1px outline, flat cel
shading). Placeholders are this repo's house pattern for exactly this —
PlaceholderArt for entities, the stand-in weapon icons for the roster.

Never overwrites: a prop that exists is left alone, so the owner's real art
wins the moment it lands.

Run: python asset/stages/build_placeholder_props.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "asset" / "stages" / "bamboo_forest" / "props"

LOGICAL_PX = 32
EXPORT_SCALE = 16

INK = (14, 12, 15, 255)
STONE_DARK = (72, 74, 82, 255)
STONE = (116, 118, 128, 255)
STONE_HI = (162, 166, 178, 255)
IRON_DARK = (48, 50, 58, 255)
IRON = (86, 90, 100, 255)
WATER_DARK = (36, 62, 78, 255)
WATER = (58, 98, 120, 255)
WATER_HI = (108, 158, 178, 255)
FLAME_CORE = (255, 232, 168, 255)
FLAME_MID = (240, 158, 62, 255)
FLAME_EDGE = (188, 74, 38, 255)


def canvas():
    image = Image.new("RGBA", (LOGICAL_PX, LOGICAL_PX), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def water_puddle():
    """Ground water: a squashed ellipse with one reflecting arc."""
    image, draw = canvas()
    draw.ellipse([4, 16, 27, 27], fill=WATER, outline=INK)
    draw.ellipse([7, 18, 24, 24], fill=WATER_DARK)
    draw.arc([9, 18, 20, 23], start=200, end=320, fill=WATER_HI)
    return image


def prop_flame():
    """The stone lantern's flame — its own sprite so the light can animate."""
    image, draw = canvas()
    draw.polygon([(16, 4), (22, 15), (19, 25), (13, 25), (10, 15)],
                 fill=FLAME_EDGE, outline=INK)
    draw.polygon([(16, 9), (20, 17), (18, 24), (14, 24), (12, 17)],
                 fill=FLAME_MID)
    draw.polygon([(16, 14), (18, 19), (16, 23), (14, 19)], fill=FLAME_CORE)
    return image


def anvil():
    """Horn, waist, splayed foot — the silhouette carries the whole read."""
    image, draw = canvas()
    draw.polygon([(3, 12), (11, 10), (27, 10), (27, 15), (11, 15), (3, 14)],
                 fill=IRON, outline=INK)
    draw.rectangle([14, 15, 21, 22], fill=IRON_DARK, outline=INK)
    draw.rectangle([9, 22, 26, 27], fill=IRON, outline=INK)
    draw.line([(12, 11), (26, 11)], fill=STONE_HI)
    return image


def stone_marker():
    """A squared stone post with a carved cap and base stones."""
    image, draw = canvas()
    draw.rectangle([12, 6, 20, 26], fill=STONE, outline=INK)
    draw.rectangle([10, 3, 22, 7], fill=STONE_HI, outline=INK)
    draw.line([(14, 11), (18, 11)], fill=STONE_DARK)
    draw.line([(14, 15), (18, 15)], fill=STONE_DARK)
    draw.ellipse([7, 24, 25, 29], fill=STONE_DARK, outline=INK)
    return image


PROPS = {
    "water_puddle": water_puddle,
    "prop_flame": prop_flame,
    "anvil": anvil,
    "stone_marker": stone_marker,
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, build in PROPS.items():
        path = OUT / f"{name}.png"
        if path.exists():
            print(f"  {name:14} exists - left alone")
            continue
        image = build().resize(
            (LOGICAL_PX * EXPORT_SCALE, LOGICAL_PX * EXPORT_SCALE), Image.NEAREST
        )
        image.save(path)
        print(f"  {name:14} {LOGICAL_PX}px logical -> {image.width}x{image.height}")
    print(f"{len(PROPS)} props -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
