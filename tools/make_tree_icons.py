"""Draws the training tree's own icon set — simple pixel glyphs, not the HD
loot art.

The loot icons are 1254px paintings; at a 40px tree tile they turn to mush and
two different nodes read as the same smudge. These are 16x16 glyphs in a small
palette, scaled x3 with nearest-neighbour so they stay crisp on the tile and
match the game's pixel grammar.

    python tools/make_tree_icons.py     ->  asset/ui/tree_icons/*.png
"""
import io
import os
import sys

from PIL import Image, ImageDraw

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

OUT_DIR = "asset/ui/tree_icons"
SIZE = 16
SCALE = 3

INK = (26, 22, 19, 255)
LIGHT = (242, 230, 210, 255)
GOLD = (214, 168, 74, 255)
RED = (176, 74, 60, 255)
BLUE = (96, 140, 184, 255)
GREEN = (104, 150, 104, 255)
GREY = (150, 146, 138, 255)
PURPLE = (140, 108, 168, 255)


def canvas():
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def shade(image, amount=0.72):
    """Darkens the bottom-right of every filled pixel by one step.

    Flat fills read as stickers at tile size; one shadow step is what makes a
    16px glyph look carved rather than printed.
    """
    pixels = image.load()
    shaded = image.copy()
    out = shaded.load()
    for y in range(SIZE - 1, 0, -1):
        for x in range(SIZE - 1, 0, -1):
            here = pixels[x, y]
            if here[3] == 0:
                continue
            below = pixels[x, y + 1] if y + 1 < SIZE else (0, 0, 0, 0)
            right = pixels[x + 1, y] if x + 1 < SIZE else (0, 0, 0, 0)
            if below[3] != 0 and right[3] != 0:
                continue
            if here == INK:
                continue
            out[x, y] = (
                int(here[0] * amount), int(here[1] * amount),
                int(here[2] * amount), here[3],
            )
    return shaded


def spark(image, at, colour=LIGHT):
    """A two-pixel glint, the cheapest way to say 'this one is sharper'."""
    draw = ImageDraw.Draw(image)
    draw.point([at, (at[0] + 1, at[1] - 1)], fill=colour)
    return image


def coin(_):
    image, draw = canvas()
    draw.ellipse((2, 2, 13, 13), fill=GOLD, outline=INK)
    draw.rectangle((7, 5, 8, 10), fill=INK)
    draw.rectangle((5, 7, 10, 8), fill=INK)
    return image


def clover(_):
    image, draw = canvas()
    for cx, cy in ((5, 5), (10, 5), (5, 10), (10, 10)):
        draw.ellipse((cx - 3, cy - 3, cx + 2, cy + 2), fill=GREEN, outline=INK)
    draw.rectangle((7, 7, 8, 8), fill=GREEN)
    return image


def book(_):
    image, draw = canvas()
    draw.rectangle((2, 3, 13, 12), fill=LIGHT, outline=INK)
    draw.line((8, 3, 8, 12), fill=INK)
    draw.line((4, 6, 6, 6), fill=GREY)
    draw.line((4, 8, 6, 8), fill=GREY)
    draw.line((10, 6, 12, 6), fill=GREY)
    return image


def magnet(_):
    image, draw = canvas()
    draw.arc((2, 2, 13, 15), start=180, end=360, fill=GREY, width=3)
    draw.rectangle((2, 9, 4, 13), fill=RED, outline=INK)
    draw.rectangle((11, 9, 13, 13), fill=BLUE, outline=INK)
    return image


def boot(_):
    image, draw = canvas()
    draw.rectangle((5, 2, 9, 9), fill=RED, outline=INK)
    draw.rectangle((3, 9, 12, 13), fill=RED, outline=INK)
    draw.line((4, 12, 11, 12), fill=INK)
    return image


def sword(_):
    image, draw = canvas()
    draw.polygon([(8, 1), (10, 4), (10, 10), (6, 10), (6, 4)], fill=GREY, outline=INK)
    draw.rectangle((4, 10, 11, 11), fill=GOLD, outline=INK)
    draw.rectangle((7, 12, 8, 14), fill=INK)
    return image


def spear(_):
    image, draw = canvas()
    draw.polygon([(8, 1), (11, 6), (8, 8), (5, 6)], fill=GREY, outline=INK)
    draw.rectangle((7, 8, 8, 14), fill=GOLD, outline=INK)
    return image


def bow(_):
    image, draw = canvas()
    draw.arc((3, 1, 13, 14), start=270, end=90, fill=GOLD, width=2)
    draw.line((5, 2, 5, 13), fill=LIGHT)
    draw.line((5, 8, 12, 8), fill=INK)
    return image


def arrows(_):
    image, draw = canvas()
    for offset in (-3, 0, 3):
        draw.line((3, 8 + offset, 12, 8 + offset), fill=GOLD)
        draw.polygon([(12, 8 + offset), (9, 6 + offset), (9, 10 + offset)], fill=INK)
    return image


def flame(_):
    image, draw = canvas()
    draw.polygon([(8, 1), (12, 8), (11, 13), (5, 13), (4, 8)], fill=RED, outline=INK)
    draw.polygon([(8, 6), (10, 10), (8, 13), (6, 10)], fill=GOLD)
    return image


def bolt(_):
    image, draw = canvas()
    draw.polygon(
        [(9, 1), (4, 8), (7, 8), (6, 15), (12, 7), (9, 7)], fill=GOLD, outline=INK
    )
    return image


def skull(_):
    image, draw = canvas()
    draw.ellipse((3, 2, 12, 10), fill=LIGHT, outline=INK)
    draw.rectangle((5, 10, 10, 13), fill=LIGHT, outline=INK)
    draw.rectangle((5, 5, 6, 7), fill=INK)
    draw.rectangle((9, 5, 10, 7), fill=INK)
    return image


def talisman(_):
    image, draw = canvas()
    draw.rectangle((4, 1, 11, 14), fill=LIGHT, outline=INK)
    draw.line((6, 4, 9, 4), fill=RED)
    draw.line((7, 4, 7, 11), fill=RED)
    draw.line((6, 8, 9, 8), fill=RED)
    return image


def orb(_):
    image, draw = canvas()
    draw.ellipse((2, 2, 13, 13), outline=PURPLE, width=2)
    draw.ellipse((6, 6, 9, 9), fill=PURPLE)
    return image


def ward(_):
    image, draw = canvas()
    draw.ellipse((1, 4, 14, 12), outline=BLUE, width=2)
    draw.ellipse((5, 6, 10, 10), fill=BLUE)
    return image


def heart(_):
    image, draw = canvas()
    draw.ellipse((3, 3, 8, 8), fill=RED, outline=INK)
    draw.ellipse((7, 3, 12, 8), fill=RED, outline=INK)
    draw.polygon([(3, 7), (12, 7), (8, 14)], fill=RED, outline=INK)
    return image


def shield(_):
    image, draw = canvas()
    draw.polygon([(3, 2), (12, 2), (12, 9), (8, 14), (3, 9)], fill=BLUE, outline=INK)
    draw.line((8, 4, 8, 11), fill=LIGHT)
    return image


def armor(_):
    image, draw = canvas()
    draw.rectangle((3, 3, 12, 12), fill=GREY, outline=INK)
    draw.line((3, 6, 12, 6), fill=INK)
    draw.line((3, 9, 12, 9), fill=INK)
    return image


def feather(_):
    image, draw = canvas()
    draw.polygon([(11, 2), (13, 6), (6, 13), (3, 13), (4, 9)], fill=LIGHT, outline=INK)
    draw.line((5, 12, 11, 4), fill=GREY)
    return image


def eye(_):
    image, draw = canvas()
    draw.polygon([(1, 8), (8, 3), (15, 8), (8, 13)], fill=LIGHT, outline=INK)
    draw.ellipse((6, 6, 9, 10), fill=BLUE, outline=INK)
    return image


def fang(_):
    image, draw = canvas()
    draw.polygon([(4, 2), (11, 2), (8, 14)], fill=LIGHT, outline=INK)
    draw.line((6, 5, 9, 5), fill=RED)
    return image


def hourglass(_):
    image, draw = canvas()
    draw.polygon(
        [(3, 2), (12, 2), (8, 8), (12, 14), (3, 14), (7, 8)], fill=GOLD, outline=INK
    )
    return image


def star(_):
    image, draw = canvas()
    draw.polygon(
        [(8, 1), (10, 6), (15, 7), (11, 10), (12, 15), (8, 12), (4, 15), (5, 10),
         (1, 7), (6, 6)],
        fill=GOLD, outline=INK,
    )
    return image


def pouch(_):
    image, draw = canvas()
    draw.polygon([(4, 5), (11, 5), (13, 13), (2, 13)], fill=GOLD, outline=INK)
    draw.line((5, 5, 6, 2), fill=INK)
    draw.line((10, 5, 9, 2), fill=INK)
    return image


def moon(_):
    image, draw = canvas()
    draw.ellipse((2, 2, 13, 13), fill=LIGHT, outline=INK)
    draw.ellipse((6, 1, 16, 12), fill=(0, 0, 0, 0))
    return image


def sprout(_):
    image, draw = canvas()
    draw.line((8, 6, 8, 14), fill=GREEN, width=2)
    draw.ellipse((2, 4, 8, 9), fill=GREEN, outline=INK)
    draw.ellipse((8, 2, 14, 7), fill=GREEN, outline=INK)
    return image


def cards(_):
    image, draw = canvas()
    draw.rectangle((2, 4, 8, 13), fill=LIGHT, outline=INK)
    draw.rectangle((6, 2, 12, 11), fill=LIGHT, outline=INK)
    draw.line((8, 5, 10, 5), fill=RED)
    return image


def steps(_):
    image, draw = canvas()
    draw.rectangle((2, 10, 6, 13), fill=GOLD, outline=INK)
    draw.rectangle((6, 7, 10, 13), fill=GOLD, outline=INK)
    draw.rectangle((10, 4, 14, 13), fill=GOLD, outline=INK)
    return image


def anvil(_):
    image, draw = canvas()
    draw.polygon([(2, 5), (13, 5), (11, 9), (5, 9)], fill=GREY, outline=INK)
    draw.rectangle((6, 9, 9, 13), fill=GREY, outline=INK)
    return image


def chest(_):
    image, draw = canvas()
    draw.rectangle((2, 6, 13, 13), fill=RED, outline=INK)
    draw.arc((2, 2, 13, 10), start=180, end=360, fill=RED, width=3)
    draw.rectangle((7, 8, 8, 11), fill=GOLD)
    return image


def chain(_):
    image, draw = canvas()
    draw.ellipse((1, 5, 7, 11), outline=GREY, width=2)
    draw.ellipse((8, 5, 14, 11), outline=GOLD, width=2)
    return image



def sword_edge(_):
    return spark(sword(None), (11, 3))


def sword_aura(_):
    image = sword(None)
    draw = ImageDraw.Draw(image)
    draw.line((2, 12, 4, 10), fill=RED)
    draw.line((13, 12, 11, 10), fill=RED)
    return image


def coin_stack(_):
    image, draw = canvas()
    draw.ellipse((2, 6, 13, 12), fill=GOLD, outline=INK)
    draw.ellipse((2, 3, 13, 9), fill=GOLD, outline=INK)
    draw.rectangle((7, 5, 8, 7), fill=INK)
    return image


def coin_chest(_):
    image, draw = canvas()
    draw.rectangle((2, 7, 13, 13), fill=GOLD, outline=INK)
    draw.line((2, 10, 13, 10), fill=INK)
    draw.ellipse((6, 2, 11, 7), fill=GOLD, outline=INK)
    return image


def heart_big(_):
    image = heart(None)
    draw = ImageDraw.Draw(image)
    draw.line((6, 5, 6, 7), fill=LIGHT)
    return image


def shield_stud(_):
    image = shield(None)
    draw = ImageDraw.Draw(image)
    draw.rectangle((7, 6, 8, 7), fill=GOLD)
    return image


def flame_twin(_):
    image, draw = canvas()
    draw.polygon([(5, 3), (8, 8), (6, 13), (2, 13), (2, 8)], fill=RED, outline=INK)
    draw.polygon([(11, 1), (14, 8), (13, 13), (8, 13), (8, 7)], fill=GOLD, outline=INK)
    return image


def bolt_twin(_):
    image = bolt(None)
    draw = ImageDraw.Draw(image)
    draw.line((2, 4, 4, 7), fill=GOLD)
    draw.line((13, 8, 11, 11), fill=GOLD)
    return image


def talisman_seal(_):
    image = talisman(None)
    draw = ImageDraw.Draw(image)
    draw.rectangle((5, 11, 10, 13), fill=RED, outline=INK)
    return image


def arrow_split(_):
    image, draw = canvas()
    draw.line((2, 8, 9, 8), fill=GOLD)
    draw.line((9, 8, 13, 4), fill=GOLD)
    draw.line((9, 8, 13, 12), fill=GOLD)
    draw.polygon([(13, 4), (10, 4), (12, 7)], fill=INK)
    draw.polygon([(13, 12), (10, 12), (12, 9)], fill=INK)
    return image


def eye_wide(_):
    image = eye(None)
    draw = ImageDraw.Draw(image)
    draw.line((3, 4, 5, 6), fill=GOLD)
    draw.line((13, 4, 11, 6), fill=GOLD)
    return image


def hourglass_run(_):
    image = hourglass(None)
    draw = ImageDraw.Draw(image)
    draw.line((1, 5, 2, 5), fill=LIGHT)
    draw.line((14, 10, 15, 10), fill=LIGHT)
    return image

GLYPHS = {
    "coin": coin, "clover": clover, "book": book, "magnet": magnet, "boot": boot,
    "sword": sword, "spear": spear, "bow": bow, "arrows": arrows, "flame": flame,
    "bolt": bolt, "skull": skull, "talisman": talisman, "orb": orb, "ward": ward,
    "heart": heart, "shield": shield, "armor": armor, "feather": feather,
    "eye": eye, "fang": fang, "hourglass": hourglass, "star": star,
    "pouch": pouch, "moon": moon, "sprout": sprout, "cards": cards,
    "steps": steps, "anvil": anvil, "chest": chest, "chain": chain,
    # Tier variants: a chain's second and third rungs must not wear the same
    # face as its first, or the map reads as the same node three times.
    "sword_edge": sword_edge, "sword_aura": sword_aura,
    "coin_stack": coin_stack, "coin_chest": coin_chest,
    "heart_big": heart_big, "shield_stud": shield_stud,
    "flame_twin": flame_twin, "bolt_twin": bolt_twin,
    "talisman_seal": talisman_seal, "arrow_split": arrow_split,
    "eye_wide": eye_wide, "hourglass_run": hourglass_run,
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, draw_glyph in GLYPHS.items():
        glyph = shade(draw_glyph(None))
        glyph = glyph.resize((SIZE * SCALE, SIZE * SCALE), Image.NEAREST)
        glyph.save(os.path.join(OUT_DIR, f"{name}.png"))
    print(f"{len(GLYPHS)} tree icons written to {OUT_DIR}")


main()
