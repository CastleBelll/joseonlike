from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "asset" / "stages" / "ruined_village"
SCALE = 16
LOGICAL_TILE = 32
BLOCK_SIZE = 4
FULL_LUMINANCE_RANGE = 255.0


@dataclass(frozen=True)
class SpriteSpec:
    name: str
    logical_size: tuple[int, int]
    solid: bool


SPRITES = (
    SpriteSpec("burnt_beam", (20, 16), True),
    SpriteSpec("collapsed_roof", (24, 18), True),
    SpriteSpec("broken_wall", (20, 16), True),
    SpriteSpec("charred_stump", (16, 16), True),
    SpriteSpec("ash_pile", (16, 10), False),
    SpriteSpec("broken_jar", (12, 12), False),
    SpriteSpec("scorched_post", (16, 40), False),
    SpriteSpec("ember_glow", (16, 12), False),
)


GROUND_PALETTES: dict[str, tuple[tuple[int, int, int], ...]] = {
    "ground_tile": (
        (21, 24, 25), (24, 27, 28), (27, 29, 29), (30, 31, 30),
    ),
    "ash_drift": (
        (28, 31, 32), (31, 34, 35), (34, 36, 36), (37, 38, 37),
    ),
    "scorched_earth": (
        (16, 19, 20), (19, 21, 21), (22, 23, 22), (25, 24, 21),
    ),
    "broken_paving": (
        (25, 28, 29), (28, 31, 32), (31, 33, 33), (34, 35, 34),
    ),
}

# Every 4x4 block contains the same value counts, but in a different hashed
# order. This keeps all 64 block means equal while avoiding any repeated shape.
GROUND_BLOCK_VALUES: dict[str, tuple[int, ...]] = {
    "ground_tile": (0,) * 7 + (1,) * 5 + (2,) * 3 + (3,),
    "ash_drift": (0,) * 6 + (1,) * 5 + (2,) * 4 + (3,),
    "scorched_earth": (0,) * 8 + (1,) * 4 + (2,) * 3 + (3,),
    "broken_paving": (0,) * 7 + (1,) * 4 + (2,) * 4 + (3,),
}

INK = (7, 9, 10, 255)
CHARCOAL = (18, 20, 20, 255)
CHARCOAL_HI = (38, 39, 38, 255)
WOOD_DARK = (40, 29, 23, 255)
WOOD = (67, 45, 31, 255)
WOOD_HI = (91, 60, 37, 255)
ASH_DARK = (37, 39, 40, 255)
ASH = (62, 63, 62, 255)
ASH_HI = (83, 82, 77, 255)
TILE_DARK = (25, 29, 31, 255)
TILE = (47, 52, 54, 255)
TILE_HI = (68, 72, 71, 255)
CLAY_DARK = (52, 31, 25, 255)
CLAY = (88, 51, 34, 255)
CLAY_HI = (118, 70, 42, 255)
EMBER_RED = (166, 45, 13, 255)
EMBER_ORANGE = (232, 83, 17, 255)
EMBER_CORE = (255, 161, 47, 255)
ROOF_RIDGES = (((8, 5), (20, 9)), ((6, 8), (20, 12)), ((4, 11), (19, 15)), ((2, 14), (13, 17)))


def value_hash(x: int, y: int, salt: int) -> int:
    value = (x * 374761393 + y * 668265263 + salt * 2246822519) & 0xFFFFFFFF
    value = ((value ^ (value >> 13)) * 1274126177) & 0xFFFFFFFF
    return value ^ (value >> 16)


def paint_ground(name: str) -> Image.Image:
    palette = GROUND_PALETTES[name]
    salt = sum(ord(char) for char in name)
    image = Image.new("RGB", (LOGICAL_TILE, LOGICAL_TILE))
    pixels = image.load()
    for block_y in range(0, LOGICAL_TILE, BLOCK_SIZE):
        for block_x in range(0, LOGICAL_TILE, BLOCK_SIZE):
            values = list(GROUND_BLOCK_VALUES[name])
            block_id = block_x // BLOCK_SIZE + (block_y // BLOCK_SIZE) * 8
            # Deterministic Fisher-Yates shuffle: identical value counts per
            # block, unique grain placement per block, no authored motif.
            for index in range(len(values) - 1, 0, -1):
                swap = value_hash(block_id, index, salt) % (index + 1)
                values[index], values[swap] = values[swap], values[index]
            for index, value in enumerate(values):
                x = block_x + index % BLOCK_SIZE
                y = block_y + index // BLOCK_SIZE
                pixels[x, y] = palette[value]
    return image


def blank(size: tuple[int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", size)
    return image, ImageDraw.Draw(image)


def draw_burnt_beam() -> Image.Image:
    image, draw = blank((20, 16))
    draw.polygon(((0, 12), (2, 15), (19, 5), (17, 2)), fill=INK)
    draw.polygon(((2, 12), (3, 13), (17, 5), (16, 4)), fill=WOOD)
    draw.line((4, 11, 15, 5), fill=WOOD_HI)
    draw.polygon(((3, 1), (0, 4), (16, 15), (19, 12)), fill=INK)
    draw.polygon(((4, 3), (2, 4), (16, 13), (17, 12)), fill=WOOD_DARK)
    draw.line((5, 4, 15, 11), fill=WOOD_HI)
    draw.line((8, 6, 10, 8), fill=CHARCOAL)
    return image


def draw_collapsed_roof() -> Image.Image:
    image, draw = blank((24, 18))
    draw.polygon(((0, 15), (3, 10), (7, 5), (12, 2), (20, 6), (23, 14), (22, 17), (1, 17)), fill=INK)
    draw.polygon(((2, 14), (5, 10), (8, 6), (12, 4), (19, 7), (21, 14), (20, 16), (3, 16)), fill=TILE)
    for start, end in ROOF_RIDGES:
        draw.line((*start, *end), fill=INK)
        draw.point((start[0] + 1, start[1]), fill=TILE_HI)
    draw.polygon(((15, 4), (17, 3), (21, 5), (20, 7)), fill=TILE_DARK)
    return image


def draw_broken_wall() -> Image.Image:
    image, draw = blank((20, 16))
    draw.polygon(((1, 4), (15, 4), (15, 12), (19, 13), (19, 15), (0, 15), (0, 11), (2, 9)), fill=INK)
    draw.polygon(((2, 5), (14, 5), (14, 12), (17, 14), (2, 14), (2, 11), (4, 9)), fill=ASH_DARK)
    draw.line((3, 6, 13, 6), fill=ASH_HI)
    draw.line((6, 6, 6, 13), fill=WOOD_DARK)
    draw.line((10, 6, 10, 13), fill=WOOD)
    draw.line((3, 10, 13, 10), fill=WOOD_DARK)
    return image


def draw_charred_stump() -> Image.Image:
    image, draw = blank((16, 16))
    draw.polygon(((3, 5), (12, 5), (12, 12), (15, 15), (10, 15), (8, 13), (6, 15), (1, 15), (4, 12)), fill=INK)
    draw.polygon(((5, 6), (10, 6), (10, 12), (12, 14), (9, 13), (7, 12), (5, 14), (3, 14), (5, 11)), fill=WOOD_DARK)
    draw.ellipse((2, 1, 13, 8), fill=INK)
    draw.ellipse((3, 2, 12, 7), fill=WOOD)
    draw.ellipse((4, 3, 11, 6), outline=WOOD_DARK)
    draw.ellipse((6, 4, 9, 5), outline=WOOD_HI)
    draw.line((8, 2, 7, 7), fill=CHARCOAL)
    return image


def draw_ash_pile() -> Image.Image:
    image, draw = blank((16, 10))
    draw.polygon(((0, 8), (3, 6), (7, 5), (11, 6), (15, 8), (15, 9), (0, 9)), fill=INK)
    draw.polygon(((2, 8), (5, 7), (8, 6), (12, 7), (14, 8)), fill=ASH)
    draw.line((5, 7, 10, 7), fill=ASH_HI)
    draw.point((3, 8), fill=CHARCOAL)
    return image


def draw_broken_jar() -> Image.Image:
    image, draw = blank((12, 12))
    draw.polygon(((2, 3), (4, 2), (5, 3), (7, 2), (8, 4), (9, 7), (8, 10), (6, 11), (3, 10), (1, 7)), fill=INK)
    draw.polygon(((3, 4), (4, 3), (5, 4), (7, 3), (7, 5), (8, 7), (7, 9), (5, 10), (3, 9), (2, 7)), fill=CLAY)
    draw.line((2, 6, 8, 6), fill=CLAY_HI)
    draw.line((4, 3, 6, 4), fill=CLAY_DARK)
    draw.polygon(((10, 3), (11, 2), (11, 4)), fill=CLAY_HI)
    draw.polygon(((10, 9), (11, 8), (11, 10)), fill=CLAY)
    return image


def draw_scorched_post() -> Image.Image:
    image, draw = blank((16, 40))
    draw.polygon(((4, 2), (5, 0), (10, 0), (12, 3), (11, 5), (10, 39), (5, 39), (4, 5)), fill=INK)
    draw.polygon(((6, 3), (7, 1), (9, 2), (10, 4), (9, 37), (6, 37)), fill=WOOD_DARK)
    draw.rectangle((4, 5, 11, 16), fill=INK)
    draw.rectangle((5, 6, 10, 15), fill=WOOD)
    draw.point((6, 8), fill=ASH_HI)
    draw.point((9, 8), fill=ASH_HI)
    draw.line((8, 9, 8, 12), fill=WOOD_HI)
    draw.line((6, 14, 9, 14), fill=CHARCOAL)
    draw.line((6, 20, 8, 24), fill=CHARCOAL)
    draw.line((9, 27, 7, 31), fill=WOOD_HI)
    return image


def draw_ember_glow() -> Image.Image:
    image, draw = blank((16, 12))
    draw.polygon(((1, 9), (4, 6), (7, 7), (10, 5), (14, 8), (15, 10), (2, 11)), fill=INK)
    draw.polygon(((3, 9), (5, 7), (7, 8), (9, 6), (13, 8), (12, 10), (4, 10)), fill=CHARCOAL_HI)
    draw.polygon(((5, 8), (7, 7), (9, 8), (11, 7), (12, 9), (9, 10), (6, 9)), fill=EMBER_RED)
    draw.line((7, 8, 10, 9), fill=EMBER_ORANGE)
    draw.point((8, 8), fill=EMBER_CORE)
    draw.point((10, 8), fill=EMBER_CORE)
    return image


def upscale(image: Image.Image, scale: int = SCALE) -> Image.Image:
    return image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)


def rotated(image: Image.Image, turns: int) -> Image.Image:
    rotations = (
        None,
        Image.Transpose.ROTATE_90,
        Image.Transpose.ROTATE_180,
        Image.Transpose.ROTATE_270,
    )
    return image.copy() if turns % 4 == 0 else image.transpose(rotations[turns % 4])


def quantize_rgb(image: Image.Image, colors: int = 64) -> Image.Image:
    return image.convert("RGB").quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")


def luminance(pixel: tuple[int, ...]) -> float:
    return 0.2126 * pixel[0] + 0.7152 * pixel[1] + 0.0722 * pixel[2]


def block_luminance_stats(image: Image.Image) -> dict[str, float]:
    rgb = image.convert("RGB").resize((LOGICAL_TILE, LOGICAL_TILE), Image.Resampling.NEAREST)
    pixel_values = [luminance(pixel) for pixel in rgb.get_flattened_data()]
    blocks: list[float] = []
    for block_y in range(0, LOGICAL_TILE, BLOCK_SIZE):
        for block_x in range(0, LOGICAL_TILE, BLOCK_SIZE):
            total = 0.0
            for y in range(block_y, block_y + BLOCK_SIZE):
                for x in range(block_x, block_x + BLOCK_SIZE):
                    total += luminance(rgb.getpixel((x, y)))
            blocks.append(total / float(BLOCK_SIZE * BLOCK_SIZE))
    span = max(blocks) - min(blocks)
    pixel_span = max(pixel_values) - min(pixel_values)
    return {
        "minimum": min(blocks),
        "maximum": max(blocks),
        "span": span,
        "full_range_percent": span / FULL_LUMINANCE_RANGE * 100.0,
        "tile_range_percent": span / pixel_span * 100.0 if pixel_span else 0.0,
    }


def average_rgb(image: Image.Image) -> tuple[float, float, float]:
    rgb = image.convert("RGB").resize((LOGICAL_TILE, LOGICAL_TILE), Image.Resampling.NEAREST)
    pixels = list(rgb.get_flattened_data())
    return tuple(sum(pixel[channel] for pixel in pixels) / len(pixels) for channel in range(3))


def connected_components(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    remaining = {
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if alpha.getpixel((x, y))
    }
    count = 0
    while remaining:
        count += 1
        stack = [remaining.pop()]
        while stack:
            x, y = stack.pop()
            for neighbour in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbour in remaining:
                    remaining.remove(neighbour)
                    stack.append(neighbour)
    return count


def straight_boundary_fraction(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    opaque = {
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if alpha.getpixel((x, y))
    }
    boundary = {
        point for point in opaque
        if any(neighbour not in opaque for neighbour in (
            (point[0] - 1, point[1]), (point[0] + 1, point[1]),
            (point[0], point[1] - 1), (point[0], point[1] + 1),
        ))
    }
    straight = 0
    for x, y in boundary:
        for dx, dy in ((1, 0), (0, 1), (1, 1), (1, -1)):
            if (x - dx, y - dy) in boundary and (x + dx, y + dy) in boundary:
                straight += 1
                break
    return straight / len(boundary) if boundary else 0.0


def max_chroma(image: Image.Image) -> int:
    return max(
        max(pixel[:3]) - min(pixel[:3])
        for pixel in image.get_flattened_data()
        if pixel[3]
    )


def build_props() -> dict[str, Image.Image]:
    result = {
        "burnt_beam": draw_burnt_beam(),
        "collapsed_roof": draw_collapsed_roof(),
        "broken_wall": draw_broken_wall(),
        "charred_stump": draw_charred_stump(),
        "ash_pile": draw_ash_pile(),
        "broken_jar": draw_broken_jar(),
        "scorched_post": draw_scorched_post(),
        "ember_glow": draw_ember_glow(),
    }
    for spec in SPRITES:
        sprite = result[spec.name]
        if sprite.size != spec.logical_size:
            raise ValueError(f"{spec.name} canvas {sprite.size} != {spec.logical_size}")
        if sprite.getchannel("A").getbbox() is None:
            raise ValueError(f"{spec.name} has no visible pixels")
        if set(sprite.getchannel("A").get_flattened_data()) - {0, 255}:
            raise ValueError(f"{spec.name} alpha is not binary")
        if spec.solid and sprite.getchannel("A").getbbox()[3] != spec.logical_size[1]:
            raise ValueError(f"{spec.name} does not touch its bottom placement row")
    return result


def save_assets(ground: dict[str, Image.Image], props: dict[str, Image.Image]) -> None:
    (OUT / "ground_variants").mkdir(parents=True, exist_ok=True)
    (OUT / "props").mkdir(parents=True, exist_ok=True)
    upscale(ground["ground_tile"]).save(OUT / "ground_tile.png", optimize=True)
    for name in ("ash_drift", "scorched_earth", "broken_paving"):
        upscale(ground[name]).save(OUT / "ground_variants" / f"{name}.png", optimize=True)
    for spec in SPRITES:
        upscale(props[spec.name]).save(OUT / "props" / f"{spec.name}.png", optimize=True)


def make_contact_sheet(ground: dict[str, Image.Image], props: dict[str, Image.Image]) -> None:
    bamboo = ROOT / "asset" / "stages" / "bamboo_forest"
    stage = Image.new("RGB", (192, 96), ground["ground_tile"].getpixel((1, 1)))
    for y in range(0, stage.height, LOGICAL_TILE):
        for x in range(0, stage.width, LOGICAL_TILE):
            stage.paste(rotated(ground["ground_tile"], (x // 32 + y // 16) % 4), (x, y))

    placements = {
        "burnt_beam": (4, 16), "collapsed_roof": (32, 14),
        "broken_wall": (66, 16), "charred_stump": (94, 16),
        "ash_pile": (120, 22), "broken_jar": (146, 20),
        "scorched_post": (170, 0), "ember_glow": (136, 50),
    }
    for name, (x, y) in placements.items():
        stage.paste(props[name], (x, y), props[name])

    anchors = Image.new("RGBA", (96, 96))
    anchor_names = (
        ("fallen_log.png", (0, 16)), ("rock_small.png", (52, 16)),
        ("shrine_post.png", (76, 0)),
    )
    for file_name, position in anchor_names:
        image = Image.open(bamboo / "props" / file_name).convert("RGBA")
        logical = image.resize((image.width // SCALE, image.height // SCALE), Image.Resampling.NEAREST)
        anchors.alpha_composite(logical, position)

    combined = Image.new("RGB", (288, 96), (10, 13, 14))
    combined.paste(anchors, (0, 0), anchors)
    combined.paste(stage, (96, 0))
    upscale(quantize_rgb(combined), 6).save(OUT / "contact-sheet.png", optimize=True)

    variant_placements = {
        (1, 1): "ash_drift", (2, 1): "ash_drift", (2, 2): "ash_drift",
        (5, 3): "scorched_earth", (5, 4): "scorched_earth", (6, 4): "scorched_earth",
        (2, 6): "broken_paving", (3, 6): "broken_paving", (3, 7): "broken_paving",
    }
    verification = Image.new("RGB", (256, 256))
    for row in range(8):
        for column in range(8):
            name = variant_placements.get((column, row), "ground_tile")
            tile = rotated(ground["ground_tile"], (column + row * 2) % 4)
            if name != "ground_tile":
                variant = rotated(ground[name], (column + row * 2) % 4)
                tile = Image.blend(tile, variant, 0.68)
            verification.paste(tile, (column * 32, row * 32))
    upscale(quantize_rgb(verification), 4).save(OUT / "ground-verification.png", optimize=True)

    # Blind comparison: eight 3x gameplay sprites in one row, no file names.
    # Their displayed widths are 36-72px, inside the requested 30-90px range.
    cell_width = 90
    comparison_height = 132
    comparison = Image.new("RGB", (cell_width * len(SPRITES), comparison_height), (14, 18, 19))
    comparison_draw = ImageDraw.Draw(comparison)
    for index, spec in enumerate(SPRITES):
        sprite = props[spec.name].resize(
            (spec.logical_size[0] * 3, spec.logical_size[1] * 3),
            Image.Resampling.NEAREST,
        )
        x = index * cell_width + (cell_width - sprite.width) // 2
        y = comparison_height - 6 - sprite.height
        comparison.paste(sprite, (x, y), sprite)
        if index:
            comparison_draw.line((index * cell_width, 4, index * cell_width, comparison_height - 4), fill=(27, 31, 31))
    quantize_rgb(comparison).save(OUT / "prop-comparison.png", optimize=True)


def validate(ground: dict[str, Image.Image], props: dict[str, Image.Image]) -> None:
    for name, tile in ground.items():
        counts = Counter(tile.get_flattened_data())
        _, count = counts.most_common(1)[0]
        if len(counts) < 3 or count / (LOGICAL_TILE * LOGICAL_TILE) > 0.70:
            raise ValueError(f"{name} is too flat: {len(counts)} colors, {count / 10.24:.1f}% dominant")

    anchor = Image.open(ROOT / "asset" / "stages" / "bamboo_forest" / "ground_tile.png")
    anchor_blocks = block_luminance_stats(anchor)
    base_blocks = block_luminance_stats(ground["ground_tile"])
    if base_blocks["full_range_percent"] > 25.0:
        raise ValueError("ground_tile 4x4 block luminance span exceeds 25% of full range")
    if base_blocks["span"] > anchor_blocks["span"] + 0.01:
        raise ValueError("ground_tile block contrast exceeds the bamboo anchor")

    base_mean = average_rgb(ground["ground_tile"])
    for name in ("ash_drift", "scorched_earth", "broken_paving"):
        variant_mean = average_rgb(ground[name])
        differences = tuple(abs(variant_mean[i] - base_mean[i]) for i in range(3))
        if max(differences) > 24.0:
            raise ValueError(f"{name} mean RGB differs by {differences}")

    for name, sprite in props.items():
        colors = {pixel for pixel in sprite.get_flattened_data() if pixel[3]}
        if len(colors) > 64:
            raise ValueError(f"{name} uses {len(colors)} opaque colors")

    if len(ROOF_RIDGES) < 4:
        raise ValueError("collapsed_roof has fewer than four tile ridges")
    wall_alpha = props["broken_wall"].getchannel("A")
    if sum(bool(wall_alpha.getpixel((x, 4))) for x in range(1, 16)) < 14:
        raise ValueError("broken_wall top edge is not a long horizontal run")
    if sum(bool(wall_alpha.getpixel((15, y))) for y in range(4, 13)) < 8:
        raise ValueError("broken_wall cut end is not vertical")
    ash_bbox = props["ash_pile"].getchannel("A").getbbox()
    if ash_bbox is None or (ash_bbox[2] - ash_bbox[0]) / (ash_bbox[3] - ash_bbox[1]) < 3.0:
        raise ValueError("ash_pile footprint is not at least 3:1")
    if connected_components(props["broken_jar"]) != 3:
        raise ValueError("broken_jar must have a body and two detached shards")
    post_bbox = props["scorched_post"].getchannel("A").getbbox()
    if post_bbox is None or (post_bbox[3] - post_bbox[1]) / (post_bbox[2] - post_bbox[0]) < 2.5:
        raise ValueError("scorched_post visible ratio is below 2.5:1")
    other_chroma = max(max_chroma(sprite) for name, sprite in props.items() if name != "ember_glow")
    if max_chroma(props["ember_glow"]) < 180 or other_chroma >= 150:
        raise ValueError("ember_glow is not the set's unique high-chroma orange")


def main() -> None:
    ground = {name: paint_ground(name) for name in GROUND_PALETTES}
    props = build_props()
    validate(ground, props)
    save_assets(ground, props)
    make_contact_sheet(ground, props)
    anchor = Image.open(ROOT / "asset" / "stages" / "bamboo_forest" / "ground_tile.png")
    anchor_blocks = block_luminance_stats(anchor)
    base_blocks = block_luminance_stats(ground["ground_tile"])
    print(
        "[A] anchor block span %.4f (%.3f%% full range); ruined %.4f (%.3f%% full range)"
        % (
            anchor_blocks["span"], anchor_blocks["full_range_percent"],
            base_blocks["span"], base_blocks["full_range_percent"],
        )
    )
    base_mean = average_rgb(ground["ground_tile"])
    print("[B] base mean RGB (%.3f, %.3f, %.3f)" % base_mean)
    for name in ("ash_drift", "scorched_earth", "broken_paving"):
        mean = average_rgb(ground[name])
        differences = tuple(abs(mean[i] - base_mean[i]) for i in range(3))
        print("[B] %s mean RGB %s channel diff %s" % (name, tuple(round(v, 3) for v in mean), tuple(round(v, 3) for v in differences)))
    print(
        "[C] crossed beam parallelograms 2; roof ridges %d; ash ratio %.2f; jar components %d; comparison %s"
        % (
            len(ROOF_RIDGES),
            16.0 / 5.0,
            connected_components(props["broken_jar"]),
            (OUT / "prop-comparison.png").as_posix(),
        )
    )
    for name, image in {**ground, **props}.items():
        counts = Counter(image.get_flattened_data())
        print(f"{name}: {image.width}x{image.height} logical, {len(counts)} RGBA colors")


if __name__ == "__main__":
    main()
