from __future__ import annotations

from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
MONSTERS = ROOT / "asset" / "monsters"
EFFECTS = ROOT / "asset" / "effect"

INK = (8, 11, 13, 255)
ASH_DARK = (34, 37, 40, 255)
ASH = (69, 72, 73, 255)
ASH_HI = (119, 119, 113, 255)
EMBER = (224, 74, 30, 255)
EMBER_HI = (255, 165, 55, 255)
HOUND_DARK = (30, 25, 24, 255)
HOUND = (62, 49, 43, 255)
HOUND_HI = (96, 73, 57, 255)
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


def blank(size: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (size, size))
    return image, ImageDraw.Draw(image)


def ash_wraith() -> Image.Image:
    image, draw = blank(32)
    # Four broad ash steps form the disappearing lower body.
    draw.polygon(((9, 17), (23, 17), (25, 21), (22, 23), (25, 25), (21, 26),
                  (22, 29), (18, 28), (16, 31), (13, 28), (8, 29), (11, 25),
                  (6, 24), (9, 21)), fill=INK)
    draw.polygon(((11, 18), (21, 18), (23, 21), (19, 23), (23, 25), (18, 25),
                  (20, 28), (16, 27), (15, 29), (13, 27), (10, 27), (12, 24),
                  (9, 23), (11, 21)), fill=ASH)
    draw.polygon(((13, 20), (20, 20), (18, 22), (21, 24), (16, 24), (18, 27),
                  (14, 25), (13, 27), (12, 24)), fill=ASH_HI)
    # Big torn sleeves, not fingers or cloth folds.
    draw.polygon(((10, 13), (6, 15), (4, 20), (6, 23), (10, 20), (12, 17)), fill=INK)
    draw.polygon(((9, 15), (7, 16), (6, 20), (7, 21), (10, 19), (11, 17)), fill=ASH)
    draw.polygon(((22, 13), (26, 15), (29, 19), (27, 22), (23, 20), (20, 17)), fill=INK)
    draw.polygon(((23, 15), (25, 16), (27, 19), (26, 20), (23, 18), (21, 17)), fill=ASH)
    # Hooded head and two explicit 2x2 ember eyes.
    draw.ellipse((8, 2, 24, 18), fill=INK)
    draw.polygon(((11, 5), (20, 4), (23, 8), (22, 15), (18, 17), (12, 15), (9, 10)), fill=ASH_DARK)
    draw.polygon(((12, 6), (20, 6), (21, 9), (20, 13), (12, 13), (10, 9)), fill=ASH)
    draw.rectangle((12, 9, 13, 10), fill=EMBER)
    draw.rectangle((18, 9, 19, 10), fill=EMBER)
    draw.point((13, 9), fill=EMBER_HI)
    draw.point((19, 9), fill=EMBER_HI)
    draw.rectangle((14, 13, 18, 14), fill=ASH_DARK)
    # Detached ash clumps remain deliberately 2x2 or larger.
    draw.rectangle((4, 25, 5, 26), fill=ASH_HI)
    draw.rectangle((25, 27, 27, 29), fill=ASH)
    draw.rectangle((6, 29, 8, 30), fill=ASH_DARK)
    return image


def cursed_hound() -> Image.Image:
    image, draw = blank(32)
    # Raised tail and long quadruped torso establish the silhouette first.
    draw.polygon(((8, 12), (5, 10), (4, 6), (2, 5), (1, 9), (3, 14), (7, 17)), fill=INK)
    draw.polygon(((7, 13), (5, 11), (5, 8), (3, 7), (3, 10), (5, 14)), fill=HOUND_HI)
    draw.ellipse((5, 9, 23, 22), fill=INK)
    draw.polygon(((7, 11), (18, 10), (23, 14), (21, 19), (9, 20), (6, 17)), fill=HOUND)
    draw.polygon(((9, 12), (18, 12), (20, 14), (16, 16), (8, 16)), fill=HOUND_HI)
    # Forward canine head, pointed ears, eye and fang.
    draw.polygon(((19, 11), (21, 6), (23, 10), (27, 9), (30, 13), (31, 17),
                  (28, 20), (22, 19), (19, 16)), fill=INK)
    draw.polygon(((21, 12), (22, 9), (24, 12), (27, 11), (29, 14), (29, 17),
                  (27, 18), (22, 17)), fill=HOUND)
    draw.rectangle((25, 13, 26, 14), fill=EMBER_HI)
    draw.rectangle((28, 17, 30, 18), fill=HOUND_DARK)
    draw.rectangle((27, 18, 28, 20), fill=FANG)
    # Four separated weight-bearing legs.
    legs = (((7, 18), (11, 18), (10, 27), (6, 27)),
            ((13, 18), (16, 18), (17, 27), (13, 27)),
            ((20, 17), (23, 17), (24, 27), (20, 27)),
            ((25, 18), (28, 18), (30, 27), (25, 27)))
    for index, points in enumerate(legs):
        draw.polygon(points, fill=INK)
        draw.rectangle((points[0][0] + 1, 20, points[1][0] - 1, 25), fill=HOUND if index % 2 else HOUND_DARK)
        draw.rectangle((points[3][0], 27, points[2][0] + 1, 28), fill=INK)
        draw.point((points[3][0] + 1, 27), fill=FANG)
    return image


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
    return image


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
    return image


def general_wraith() -> Image.Image:
    image, draw = blank(88)
    # Banner and pole establish command rank behind the body.
    draw.line((28, 6, 24, 71), fill=INK, width=5)
    draw.line((28, 7, 25, 70), fill=GHOST_HI, width=2)
    draw.polygon(((28, 9), (8, 14), (14, 25), (7, 37), (25, 47)), fill=INK)
    draw.polygon(((26, 12), (11, 15), (17, 25), (11, 35), (24, 42)), fill=FLAG)
    draw.polygon(((23, 14), (14, 16), (19, 24), (13, 31), (23, 36)), fill=FLAG_DARK)
    # Large ghost-fire mantle and disappearing base.
    draw.polygon(((27, 34), (20, 41), (14, 53), (22, 57), (14, 64), (25, 65),
                  (18, 74), (31, 72), (27, 83), (42, 78), (48, 87), (56, 77),
                  (68, 82), (65, 69), (75, 66), (67, 58), (76, 51), (65, 45),
                  (60, 35)), fill=INK)
    draw.polygon(((29, 37), (23, 43), (19, 51), (27, 55), (20, 62), (31, 61),
                  (24, 70), (36, 68), (33, 78), (43, 73), (49, 82), (54, 72),
                  (64, 77), (61, 67), (70, 64), (62, 58), (70, 51), (61, 47),
                  (57, 38)), fill=GHOST)
    draw.polygon(((35, 43), (28, 52), (36, 57), (31, 65), (42, 63), (39, 72),
                  (48, 67), (53, 75), (55, 63), (63, 61), (56, 54), (61, 47),
                  (52, 43)), fill=GHOST_HI)
    # Helmeted face and translucent armor blocks.
    draw.polygon(((35, 13), (52, 13), (58, 20), (56, 33), (51, 38), (37, 36),
                  (31, 29), (32, 19)), fill=INK)
    draw.polygon(((37, 15), (50, 15), (55, 20), (53, 31), (49, 35), (38, 33),
                  (34, 28), (35, 19)), fill=GHOST_DARK)
    draw.rectangle((32, 22, 56, 26), fill=GHOST_HI)
    draw.polygon(((38, 25), (49, 25), (51, 32), (47, 36), (39, 33)), fill=GHOST_PALE)
    draw.rectangle((42, 28, 46, 29), fill=INK)
    draw.polygon(((30, 34), (56, 34), (64, 47), (58, 63), (47, 68), (33, 63),
                  (24, 49)), fill=INK)
    draw.polygon(((32, 36), (54, 36), (61, 47), (56, 59), (47, 65), (35, 60),
                  (27, 48)), fill=GHOST_DARK)
    draw.rectangle((35, 39, 52, 54), fill=GHOST)
    draw.polygon(((35, 39), (44, 44), (52, 39), (50, 54), (37, 54)), fill=GHOST_HI)
    draw.ellipse((40, 47, 47, 54), fill=GHOST_PALE)
    draw.polygon(((25, 35), (14, 42), (13, 53), (25, 56), (33, 47)), fill=INK)
    draw.polygon(((26, 38), (18, 43), (17, 51), (24, 53), (30, 47)), fill=GHOST)
    draw.polygon(((57, 35), (69, 39), (73, 50), (63, 57), (54, 48)), fill=INK)
    draw.polygon(((58, 38), (66, 41), (69, 49), (63, 53), (57, 47)), fill=GHOST)
    # Guan dao crosses the whole silhouette and ends in a huge readable blade.
    draw.line((12, 75, 72, 37), fill=INK, width=7)
    draw.line((13, 74, 72, 38), fill=GHOST_DARK, width=3)
    draw.polygon(((67, 40), (73, 28), (82, 17), (85, 20), (82, 33), (87, 36),
                  (78, 43), (72, 44)), fill=INK)
    draw.polygon(((70, 39), (75, 29), (81, 21), (82, 29), (79, 35), (83, 36),
                  (77, 40)), fill=GHOST_PALE)
    draw.rectangle((10, 72, 18, 78), fill=INK)
    draw.rectangle((12, 73, 16, 76), fill=GHOST_HI)
    return image


# The engine divides every sheet by SpriteSheet.EXPORT_SCALE (16), so any other
# export multiplier lands the drawing on a fractional display scale.
SPECS = {
    "ash_wraith": (32, 16, 32, ash_wraith),
    "cursed_hound": (32, 16, 32, cursed_hound),
    "powder_dokkaebi": (32, 16, 32, powder_dokkaebi),
    "rusted_armor": (52, 16, 43, rusted_armor),
    "general_wraith": (88, 16, 84, general_wraith),
}


def nearest_roundtrip_difference(image: Image.Image, logical_size: tuple[int, int]) -> tuple[int, float]:
    logical = image.resize(logical_size, Image.Resampling.NEAREST)
    restored = logical.resize(image.size, Image.Resampling.NEAREST)
    different = sum(left != right for left, right in zip(image.get_flattened_data(), restored.get_flattened_data()))
    return different, different / float(image.width * image.height) * 100.0


def peak_effect_frame(path: Path, frame_count: int) -> Image.Image:
    sheet = Image.open(path).convert("RGBA")
    frame_width = sheet.width // frame_count
    frames = [sheet.crop((index * frame_width, 0, (index + 1) * frame_width, sheet.height)) for index in range(frame_count)]
    return max(frames, key=lambda frame: sum(bool(alpha) for alpha in frame.getchannel("A").get_flattened_data()))


def make_comparison() -> Path:
    entries: list[tuple[str, Image.Image, int]] = [
        ("FOREST GOBLIN", Image.open(MONSTERS / "forest_goblin" / "idle.png").convert("RGBA"), 30),
        ("TAOIST", Image.open(ROOT / "asset" / "characters" / "taoist" / "idle.png").convert("RGBA"), 40),
    ]
    entries.extend(
        (name.replace("_", " ").upper(), Image.open(MONSTERS / name / "idle.png").convert("RGBA"), display)
        for name, (_, _, display, _) in SPECS.items()
    )
    entries.extend((
        ("CHEOLBYEOK", peak_effect_frame(EFFECTS / "skill_cheolbyeok.png", 6), 96),
        ("CHAMGYEOK", peak_effect_frame(EFFECTS / "skill_chamgyeok.png", 8), 150),
    ))
    cell_width = 174
    image = Image.new("RGB", (cell_width * len(entries), 190), (11, 15, 17))
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()
    for index, (label, source, display_size) in enumerate(entries):
        display = source.resize((display_size, display_size), Image.Resampling.NEAREST)
        x = index * cell_width + (cell_width - display.width) // 2
        y = 4 + (156 - display.height) // 2
        image.paste(display, (x, y), display)
        draw.text((index * cell_width + 6, 166), label, fill=(190, 197, 196), font=font)
        if index:
            draw.line((index * cell_width, 4, index * cell_width, 184), fill=(37, 43, 45))
    path = MONSTERS / "night2-grid-comparison.png"
    image.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB").save(path, optimize=True)
    return path


def main() -> None:
    for name, (logical_size, scale, _, builder) in SPECS.items():
        logical = builder()
        if logical.size != (logical_size, logical_size):
            raise ValueError(f"{name}: wrong logical size {logical.size}")
        output = logical.resize((logical_size * scale, logical_size * scale), Image.Resampling.NEAREST)
        colors = Counter(output.get_flattened_data())
        if len(colors) > 64:
            raise ValueError(f"{name}: {len(colors)} colors")
        output_path = MONSTERS / name / "idle.png"
        output.save(output_path, optimize=True)
        different, percent = nearest_roundtrip_difference(output, logical.size)
        print(f"{name}: {logical_size}x{logical_size} x{scale} -> {output.width}x{output.height}; {len(colors)} RGBA colors; roundtrip {different} px ({percent:.6f}%)")
    print(f"comparison: {make_comparison().as_posix()}")


if __name__ == "__main__":
    main()
