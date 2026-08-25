from __future__ import annotations

from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
MONSTERS = ROOT / "asset" / "monsters"

INK = (8, 11, 13, 255)
ASH_DARK = (34, 37, 40, 255)
ASH_MID = (51, 53, 53, 255)
ASH = (69, 72, 73, 255)
ASH_COOL = (82, 87, 89, 255)
ASH_HI = (119, 119, 113, 255)
ASH_PALE = (151, 149, 139, 255)
EMBER_DARK = (120, 38, 23, 255)
EMBER = (224, 74, 30, 255)
EMBER_HI = (255, 165, 55, 255)
HOUND_DARK = (30, 25, 24, 255)
HOUND = (62, 49, 43, 255)
HOUND_HI = (96, 73, 57, 255)
HOUND_TAIL = (78, 57, 45, 255)
HOUND_LEG = (51, 38, 35, 255)
HOUND_MUZZLE = (75, 55, 48, 255)
CURSE_DARK = (47, 31, 55, 255)
CURSE = (100, 61, 112, 255)
FANG = (218, 205, 169, 255)
RED_DARK = (91, 27, 23, 255)
RED = (162, 52, 39, 255)
RED_HI = (211, 79, 51, 255)
BARREL_DARK = (72, 42, 20, 255)
BARREL = (123, 75, 33, 255)
BARREL_HI = (169, 108, 48, 255)
IRON = (42, 46, 49, 255)
IRON_HI = (83, 85, 82, 255)
RUST_DARK = (91, 46, 29, 255)
RUST = (151, 77, 39, 255)
RUST_HI = (201, 119, 60, 255)
BLUE_DARK = (22, 37, 52, 255)
BLUE = (43, 67, 83, 255)
GHOST_DARK = (15, 53, 60, 220)
GHOST = (55, 126, 131, 210)
GHOST_HI = (137, 218, 211, 220)
GHOST_PALE = (209, 247, 232, 235)
FLAG_DARK = (73, 22, 31, 235)
FLAG = (142, 42, 49, 235)
FLAG_HI = (190, 61, 63, 235)
STEEL_DARK = (55, 75, 79, 255)
STEEL = (131, 172, 166, 255)
STEEL_HI = (220, 246, 224, 255)


def blank(size: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (size, size))
    return image, ImageDraw.Draw(image)


def cel_shade(image: Image.Image, seed: int) -> Image.Image:
    """Split every painted material into deliberate hard-edged light bands."""
    source = image.copy()
    output = image.copy()
    source_pixels = source.load()
    output_pixels = output.load()
    offsets = (-18, -6, 6, 18)

    def same_material(x: int, y: int, color: tuple[int, int, int, int]) -> bool:
        return 0 <= x < image.width and 0 <= y < image.height and source_pixels[x, y] == color

    for y in range(image.height):
        for x in range(image.width):
            color = source_pixels[x, y]
            if color[3] == 0 or color == INK:
                continue
            lit_edge = not same_material(x - 1, y, color) or not same_material(x, y - 1, color)
            shaded_edge = not same_material(x + 1, y, color) or not same_material(x, y + 1, color)
            if lit_edge and not shaded_edge:
                tone = 3
            elif shaded_edge and not lit_edge:
                tone = 0
            else:
                # Three- to five-cell patches read as cel-shaded facets rather
                # than one-pixel noise at the logical display size.
                tone = 1 + ((x // 4 + 2 * (y // 5) + seed) & 1)
            delta = offsets[tone]
            output_pixels[x, y] = (
                max(0, min(255, color[0] + delta)),
                max(0, min(255, color[1] + delta)),
                max(0, min(255, color[2] + delta)),
                color[3],
            )
    return output


def ash_wraith() -> Image.Image:
    image, draw = blank(32)
    # A pale ash mantle surrounds a dark, heat-hollowed face.
    draw.polygon(((10, 3), (20, 2), (25, 7), (24, 14), (22, 17), (26, 19),
                  (24, 23), (21, 23), (23, 27), (19, 27), (20, 30), (16, 29),
                  (13, 31), (11, 27), (7, 28), (9, 24), (6, 22), (9, 18),
                  (7, 14), (8, 7)), fill=INK)
    draw.polygon(((11, 5), (20, 4), (23, 8), (22, 14), (19, 17), (22, 20),
                  (20, 22), (21, 25), (17, 25), (18, 28), (15, 27), (13, 29),
                  (12, 25), (9, 26), (11, 22), (8, 21), (11, 17), (9, 13),
                  (10, 7)), fill=ASH_MID)
    # Broad stepped strata make the torso and dissolving base read as ash.
    draw.polygon(((9, 15), (22, 15), (21, 18), (24, 20), (20, 21), (22, 23),
                  (17, 23), (19, 26), (14, 25), (16, 28), (12, 26), (11, 23),
                  (8, 21), (11, 19)), fill=ASH)
    draw.polygon(((11, 17), (20, 17), (18, 19), (21, 20), (16, 21), (19, 23),
                  (13, 23), (15, 25), (11, 24), (10, 21)), fill=ASH_HI)
    draw.polygon(((13, 18), (18, 18), (16, 20), (19, 21), (14, 22), (12, 20)), fill=ASH_PALE)
    # Torn sleeves end in square soot clumps rather than hands.
    draw.polygon(((10, 13), (6, 14), (3, 19), (5, 23), (9, 21), (12, 17)), fill=INK)
    draw.polygon(((9, 15), (7, 15), (5, 19), (6, 21), (9, 19), (11, 17)), fill=ASH)
    draw.polygon(((22, 13), (26, 15), (30, 19), (28, 23), (24, 20), (20, 17)), fill=INK)
    draw.polygon(((23, 15), (25, 16), (28, 19), (27, 21), (24, 18), (21, 17)), fill=ASH_HI)
    # Two 2x2 ember eyes sit inside a clearly darker cinder hollow.
    draw.polygon(((11, 6), (20, 5), (22, 9), (20, 14), (12, 14), (9, 10)), fill=ASH_DARK)
    draw.polygon(((12, 7), (20, 7), (20, 12), (12, 12), (10, 9)), fill=INK)
    draw.rectangle((12, 9, 13, 10), fill=EMBER)
    draw.rectangle((18, 9, 19, 10), fill=EMBER)
    draw.point((13, 9), fill=EMBER_HI)
    draw.point((19, 9), fill=EMBER_HI)
    draw.rectangle((14, 12, 18, 13), fill=EMBER_DARK)
    # Detached ash chunks extend the stair-step breakup beyond the body.
    draw.rectangle((3, 24, 5, 25), fill=ASH_PALE)
    draw.rectangle((5, 28, 7, 29), fill=ASH_HI)
    draw.rectangle((8, 30, 10, 31), fill=ASH_DARK)
    draw.rectangle((24, 25, 26, 26), fill=ASH)
    draw.rectangle((27, 28, 29, 30), fill=ASH_COOL)
    return cel_shade(image, 1)


def cursed_hound() -> Image.Image:
    image, draw = blank(32)
    # Raised tail, high rump and dipped shoulders form one curved animal back.
    draw.polygon(((8, 14), (5, 12), (4, 8), (2, 5), (1, 7), (2, 12), (5, 16), (8, 18)), fill=INK)
    draw.polygon(((7, 14), (5, 11), (4, 8), (3, 7), (3, 11), (6, 16)), fill=HOUND_TAIL)
    draw.polygon(((6, 13), (10, 9), (17, 10), (21, 13), (24, 16), (22, 21),
                  (14, 20), (9, 22), (5, 18)), fill=INK)
    draw.polygon(((7, 14), (10, 11), (16, 11), (20, 14), (22, 16), (20, 19),
                  (14, 18), (9, 20), (7, 17)), fill=HOUND)
    draw.polygon(((9, 13), (12, 11), (17, 12), (20, 15), (17, 16), (11, 15)), fill=HOUND_HI)
    draw.polygon(((8, 17), (14, 17), (12, 20), (8, 20)), fill=HOUND_DARK)
    # Low forward head, separate muzzle and pointed ears.
    draw.polygon(((19, 14), (21, 8), (24, 11), (27, 10), (31, 14), (31, 19),
                  (28, 22), (22, 20), (19, 18)), fill=INK)
    draw.polygon(((21, 14), (22, 10), (24, 13), (27, 12), (29, 14), (30, 17),
                  (28, 19), (23, 18)), fill=HOUND_MUZZLE)
    draw.polygon(((23, 14), (27, 13), (29, 15), (27, 16), (23, 16)), fill=HOUND_HI)
    draw.rectangle((25, 14, 26, 15), fill=EMBER_HI)
    draw.rectangle((28, 17, 31, 19), fill=HOUND_DARK)
    draw.point((30, 17), fill=CURSE)
    draw.rectangle((27, 19, 28, 21), fill=FANG)
    # Curse scars break up the fur without changing the canine silhouette.
    draw.line((10, 12, 12, 15), fill=CURSE_DARK, width=1)
    draw.line((15, 12, 17, 16), fill=CURSE, width=1)
    draw.line((20, 15, 21, 18), fill=CURSE_DARK, width=1)
    # Rear legs push backward while the front pair brace at different angles.
    draw.polygon(((7, 18), (11, 18), (10, 22), (7, 26), (3, 27), (2, 25),
                  (6, 22)), fill=INK)
    draw.polygon(((8, 19), (10, 19), (8, 23), (5, 25), (3, 25), (7, 21)), fill=HOUND_LEG)
    draw.polygon(((12, 18), (15, 18), (16, 22), (19, 24), (18, 27), (15, 26),
                  (13, 23)), fill=INK)
    draw.polygon(((13, 19), (14, 19), (15, 22), (18, 24), (17, 25), (14, 23)), fill=HOUND)
    draw.polygon(((20, 18), (23, 18), (23, 22), (21, 25), (18, 25), (18, 23),
                  (20, 21)), fill=INK)
    draw.polygon(((21, 19), (22, 19), (22, 21), (20, 24), (19, 24), (21, 21)), fill=HOUND_LEG)
    draw.polygon(((24, 18), (27, 18), (28, 26), (31, 27), (30, 29), (26, 28),
                  (25, 23)), fill=INK)
    draw.polygon(((25, 19), (26, 19), (27, 26), (29, 27), (28, 27), (26, 26)), fill=HOUND)
    draw.point((3, 26), fill=FANG)
    draw.point((18, 26), fill=FANG)
    draw.point((19, 24), fill=FANG)
    draw.point((29, 27), fill=FANG)
    return cel_shade(image, 2)


def powder_dokkaebi() -> Image.Image:
    image, draw = blank(32)
    # Barrel occupies the whole back third and reads before the face.
    draw.ellipse((2, 3, 20, 20), fill=INK)
    draw.ellipse((4, 4, 18, 18), fill=BARREL)
    draw.rectangle((5, 7, 18, 9), fill=BARREL_HI)
    draw.rectangle((4, 12, 18, 14), fill=BARREL_DARK)
    draw.line((7, 4, 5, 18), fill=IRON, width=2)
    draw.line((16, 4, 18, 17), fill=IRON, width=2)
    draw.rectangle((9, 2, 12, 4), fill=BARREL_DARK)
    draw.line((11, 2, 15, 0), fill=RUST_HI, width=1)
    draw.point((16, 0), fill=EMBER_HI)
    # Squat red body.
    draw.polygon(((12, 15), (24, 14), (28, 19), (26, 25), (23, 24), (25, 29),
                  (19, 30), (17, 25), (14, 30), (8, 29), (11, 23), (8, 20)), fill=INK)
    draw.polygon(((13, 16), (23, 16), (26, 19), (24, 23), (21, 22), (23, 28),
                  (20, 28), (18, 23), (16, 28), (11, 28), (13, 22), (10, 20)), fill=RED)
    draw.rectangle((14, 19, 22, 24), fill=RED_HI)
    # Horned goblin head with two white eyes and tusks.
    draw.polygon(((13, 7), (15, 3), (17, 7), (23, 6), (26, 3), (27, 8),
                  (30, 10), (29, 18), (25, 21), (16, 19), (12, 15)), fill=INK)
    draw.polygon(((15, 8), (16, 5), (18, 8), (23, 8), (25, 5), (25, 9),
                  (28, 11), (27, 16), (24, 18), (17, 17), (14, 14)), fill=RED)
    draw.rectangle((17, 11, 19, 12), fill=FANG)
    draw.rectangle((24, 11, 26, 12), fill=FANG)
    draw.point((19, 12), fill=INK)
    draw.point((24, 12), fill=INK)
    draw.rectangle((20, 15, 23, 16), fill=RED_DARK)
    draw.rectangle((16, 16, 17, 19), fill=FANG)
    draw.rectangle((25, 16, 26, 19), fill=FANG)
    return cel_shade(image, 3)


def rusted_armor() -> Image.Image:
    image, draw = blank(52)
    # Broad dojeonggap silhouette: helmet, pauldrons, plated skirt, boots.
    draw.polygon(((19, 4), (32, 4), (36, 9), (35, 18), (31, 20), (20, 19),
                  (16, 15), (17, 8)), fill=INK)
    draw.polygon(((20, 5), (30, 5), (34, 9), (33, 16), (29, 18), (21, 17),
                  (18, 14), (19, 8)), fill=IRON)
    draw.rectangle((18, 10, 34, 13), fill=RUST)
    draw.rectangle((21, 13, 31, 18), fill=INK)
    draw.rectangle((24, 14, 27, 17), fill=EMBER)
    draw.rectangle((25, 14, 26, 15), fill=EMBER_HI)
    # Torso and shoulder plates.
    draw.polygon(((15, 17), (36, 17), (41, 24), (38, 38), (31, 40), (19, 39),
                  (12, 34), (11, 23)), fill=INK)
    draw.polygon(((17, 19), (34, 19), (38, 24), (35, 35), (29, 38), (20, 36),
                  (15, 32), (14, 24)), fill=IRON)
    draw.rectangle((20, 21, 31, 34), fill=BLUE_DARK)
    draw.rectangle((22, 22, 29, 32), fill=IRON_HI)
    draw.line((18, 19, 20, 35), fill=RUST, width=2)
    draw.line((33, 19, 31, 36), fill=RUST, width=2)
    draw.ellipse((5, 16, 19, 29), fill=INK)
    draw.ellipse((7, 18, 17, 27), fill=IRON)
    draw.line((8, 21, 16, 23), fill=RUST, width=2)
    draw.ellipse((33, 16, 47, 29), fill=INK)
    draw.ellipse((35, 18, 45, 27), fill=IRON)
    draw.line((36, 21, 44, 23), fill=RUST, width=2)
    # Blocky arms and gauntlets.
    draw.polygon(((7, 25), (15, 24), (17, 38), (12, 43), (6, 39), (4, 31)), fill=INK)
    draw.polygon(((8, 27), (13, 26), (15, 37), (11, 40), (7, 38), (6, 31)), fill=IRON)
    draw.rectangle((7, 36, 14, 41), fill=RUST_DARK)
    draw.polygon(((38, 24), (45, 26), (48, 34), (46, 41), (40, 43), (36, 37)), fill=INK)
    draw.polygon(((39, 27), (44, 28), (46, 34), (44, 39), (41, 40), (38, 36)), fill=IRON)
    draw.rectangle((39, 36, 46, 41), fill=RUST_DARK)
    # Studded coat and split skirt.
    draw.polygon(((14, 33), (38, 33), (41, 45), (30, 45), (26, 42), (22, 46), (10, 44)), fill=INK)
    draw.polygon(((16, 35), (36, 35), (38, 43), (30, 43), (26, 40), (21, 44), (13, 42)), fill=IRON)
    for y in (22, 27, 36, 40):
        for x in range(17 if y < 33 else 16, 36, 5):
            draw.rectangle((x, y, x + 1, y + 1), fill=RUST_HI)
    draw.polygon(((14, 42), (23, 42), (22, 49), (9, 49), (9, 46)), fill=INK)
    draw.polygon(((29, 42), (38, 42), (44, 47), (43, 50), (29, 49)), fill=INK)
    draw.rectangle((11, 46, 21, 48), fill=IRON_HI)
    draw.rectangle((31, 46, 41, 48), fill=IRON_HI)
    return cel_shade(image, 4)


def general_wraith() -> Image.Image:
    image, draw = blank(88)
    # Command flag stays behind the figure and has a clearly torn fly edge.
    draw.line((24, 7, 21, 72), fill=INK, width=5)
    draw.line((24, 8, 22, 71), fill=STEEL_DARK, width=2)
    draw.polygon(((23, 10), (6, 13), (12, 22), (6, 31), (13, 39), (22, 44)), fill=INK)
    draw.polygon(((21, 12), (9, 15), (15, 22), (9, 30), (15, 36), (21, 39)), fill=FLAG)
    draw.polygon(((18, 14), (11, 16), (16, 22), (11, 28), (18, 32)), fill=FLAG_DARK)
    draw.line((11, 18, 19, 17), fill=FLAG_HI, width=2)
    # A horsehair plume rises from a compact helmet crown.
    draw.polygon(((42, 14), (43, 5), (48, 1), (57, 3), (52, 7), (47, 8), (47, 15)), fill=INK)
    draw.polygon(((44, 13), (45, 6), (49, 3), (54, 4), (50, 6), (46, 7), (46, 14)), fill=FLAG)
    draw.rectangle((45, 7, 46, 13), fill=FLAG_HI)
    # Helmet crown, broad brim and dark face are three separate silhouettes.
    draw.polygon(((35, 14), (51, 14), (56, 19), (55, 26), (32, 26), (32, 19)), fill=INK)
    draw.polygon(((37, 16), (49, 16), (53, 19), (52, 23), (35, 23), (35, 19)), fill=GHOST_DARK)
    draw.polygon(((30, 23), (57, 23), (62, 27), (58, 31), (29, 31), (25, 27)), fill=INK)
    draw.polygon(((31, 25), (56, 25), (59, 27), (56, 29), (30, 29), (28, 27)), fill=GHOST_HI)
    draw.polygon(((35, 29), (53, 29), (52, 38), (47, 41), (38, 38), (34, 34)), fill=INK)
    draw.polygon(((38, 30), (50, 30), (49, 36), (46, 38), (39, 36), (37, 33)), fill=GHOST_PALE)
    draw.rectangle((40, 32, 42, 33), fill=GHOST_DARK)
    draw.rectangle((46, 32, 48, 33), fill=GHOST_DARK)
    # Wide armor shoulders and plated chest sit below the narrow helmet.
    draw.polygon(((29, 36), (20, 39), (14, 49), (19, 57), (29, 55), (32, 65),
                  (55, 66), (59, 55), (69, 57), (75, 49), (68, 39), (57, 36)), fill=INK)
    draw.polygon(((29, 39), (22, 41), (18, 49), (21, 53), (30, 51), (34, 61),
                  (53, 62), (57, 51), (67, 53), (71, 49), (66, 42), (57, 39)), fill=GHOST_DARK)
    draw.polygon(((31, 39), (43, 43), (56, 39), (54, 58), (44, 62), (34, 57)), fill=GHOST)
    draw.polygon(((35, 42), (43, 45), (52, 42), (51, 55), (44, 58), (36, 54)), fill=GHOST_HI)
    draw.line((34, 47, 53, 47), fill=GHOST_PALE, width=2)
    draw.line((36, 53, 51, 53), fill=GHOST_PALE, width=2)
    draw.rectangle((41, 48, 47, 54), fill=GHOST_DARK)
    # Ghost-fire lower body dissolves in broad stepped tongues.
    draw.polygon(((31, 58), (57, 58), (64, 66), (59, 70), (68, 74), (59, 77),
                  (62, 84), (52, 80), (47, 87), (41, 79), (32, 84), (34, 75),
                  (24, 77), (29, 69), (21, 66)), fill=INK)
    draw.polygon(((33, 61), (55, 61), (60, 66), (55, 69), (63, 73), (56, 75),
                  (58, 81), (51, 77), (47, 83), (42, 76), (35, 80), (37, 72),
                  (28, 74), (32, 68), (26, 66)), fill=GHOST)
    draw.polygon(((38, 63), (52, 63), (55, 67), (51, 70), (57, 73), (50, 74),
                  (47, 79), (43, 73), (37, 76), (40, 69), (34, 67)), fill=GHOST_HI)
    # Guan dao crosses the body; steel shaft and crescent blade remain distinct.
    draw.line((15, 77, 72, 39), fill=INK, width=7)
    draw.line((16, 76, 72, 40), fill=STEEL_DARK, width=3)
    draw.line((20, 72, 65, 43), fill=STEEL, width=1)
    draw.polygon(((67, 43), (71, 32), (78, 20), (83, 17), (82, 29), (87, 33),
                  (85, 39), (76, 45), (70, 46)), fill=INK)
    draw.polygon(((70, 42), (74, 33), (79, 23), (81, 21), (80, 31), (84, 34),
                  (82, 37), (76, 42)), fill=STEEL)
    draw.polygon(((74, 39), (77, 31), (80, 26), (79, 34), (82, 35), (79, 39)), fill=STEEL_HI)
    draw.rectangle((11, 73, 19, 79), fill=INK)
    draw.rectangle((13, 74, 17, 77), fill=STEEL)
    return cel_shade(image, 5)


# The engine divides every sheet by SpriteSheet.EXPORT_SCALE (16), so any other
# export multiplier lands the drawing on a fractional display scale.
SPECS = {
    "ash_wraith": (32, 16, 32, ash_wraith),
    "cursed_hound": (32, 16, 32, cursed_hound),
    "powder_dokkaebi": (32, 16, 32, powder_dokkaebi),
    "rusted_armor": (52, 16, 52, rusted_armor),
    "general_wraith": (88, 16, 88, general_wraith),
}


def nearest_roundtrip_difference(image: Image.Image, logical_size: tuple[int, int]) -> tuple[int, float]:
    logical = image.resize(logical_size, Image.Resampling.NEAREST)
    restored = logical.resize(image.size, Image.Resampling.NEAREST)
    different = sum(left != right for left, right in zip(image.get_flattened_data(), restored.get_flattened_data()))
    return different, different / float(image.width * image.height) * 100.0


def make_comparison() -> Path:
    entries: list[tuple[str, Image.Image, int]] = [
        ("FOREST GOBLIN", Image.open(MONSTERS / "forest_goblin" / "idle.png").convert("RGBA"), 30),
        ("TAOIST", Image.open(ROOT / "asset" / "characters" / "taoist" / "idle.png").convert("RGBA"), 40),
    ]
    entries.extend(
        (name.replace("_", " ").upper(), Image.open(MONSTERS / name / "idle.png").convert("RGBA"), display)
        for name, (_, _, display, _) in SPECS.items()
    )
    cell_width = 174
    image = Image.new("RGB", (cell_width * len(entries), 190), (11, 15, 17))
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()
    for index, (label, source, display_size) in enumerate(entries):
        display = source.resize((display_size, display_size), Image.Resampling.NEAREST)
        x = index * cell_width + (cell_width - display.width) // 2
        y = 4 + (156 - display.height) // 2
        image.paste(display, (x, y), display)
        visible_colors = len({pixel for pixel in display.get_flattened_data() if pixel[3] > 0})
        draw.text((index * cell_width + 6, 166), f"{label} {display_size}px / {visible_colors}c", fill=(190, 197, 196), font=font)
        if index:
            draw.line((index * cell_width, 4, index * cell_width, 184), fill=(37, 43, 45))
    path = MONSTERS / "night2-grid-comparison.png"
    image.save(path, optimize=True)
    return path


def main() -> None:
    for name, (logical_size, scale, display_size, builder) in SPECS.items():
        if scale != 16:
            raise ValueError(f"{name}: export scale {scale}; engine requires 16")
        if display_size != logical_size:
            raise ValueError(f"{name}: display {display_size}; expected logical size {logical_size}")
        logical = builder()
        if logical.size != (logical_size, logical_size):
            raise ValueError(f"{name}: wrong logical size {logical.size}")
        output = logical.resize((logical_size * scale, logical_size * scale), Image.Resampling.NEAREST)
        colors = Counter(output.get_flattened_data())
        if len(colors) > 64:
            raise ValueError(f"{name}: {len(colors)} colors")
        opaque_colors = {color for color in colors if color[3] > 0}
        if not 30 <= len(opaque_colors) <= 60:
            raise ValueError(f"{name}: {len(opaque_colors)} display colors; expected 30..60")
        output_path = MONSTERS / name / "idle.png"
        output.save(output_path, optimize=True)
        different, percent = nearest_roundtrip_difference(output, logical.size)
        if different:
            raise ValueError(f"{name}: logical-grid roundtrip differs by {different} px")
        print(f"{name}: {logical_size}x{logical_size} x{scale} -> {output.width}x{output.height}; {len(opaque_colors)} display colors; roundtrip {different} px ({percent:.6f}%)")
    print(f"comparison: {make_comparison().as_posix()}")


if __name__ == "__main__":
    main()
