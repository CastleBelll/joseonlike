from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "asset" / "stages" / "ruined_village"
RAW = ROOT / "tmp" / "ruined_village"
SCALE = 16
LOGICAL_TILE = 32
PROP_PALETTE_SIZE = 32


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
        (21, 24, 25), (24, 26, 26), (27, 27, 26), (30, 28, 26),
        (33, 29, 26), (36, 30, 26),
    ),
    "ash_drift": (
        (39, 41, 42), (47, 48, 49), (56, 56, 56), (66, 64, 61),
        (76, 72, 67), (84, 78, 71),
    ),
    "scorched_earth": (
        (12, 13, 14), (17, 15, 14), (27, 18, 15), (39, 23, 17),
        (55, 30, 20), (68, 35, 22),
    ),
    "broken_paving": (
        (35, 38, 39), (43, 45, 45), (52, 52, 50), (62, 59, 55),
        (72, 67, 61), (82, 75, 68),
    ),
}


def value_hash(x: int, y: int, salt: int) -> int:
    value = (x * 374761393 + y * 668265263 + salt * 2246822519) & 0xFFFFFFFF
    value = ((value ^ (value >> 13)) * 1274126177) & 0xFFFFFFFF
    return value ^ (value >> 16)


def paint_ground(name: str) -> Image.Image:
    palette = GROUND_PALETTES[name]
    salt = sum(ord(char) for char in name)
    image = Image.new("RGB", (LOGICAL_TILE, LOGICAL_TILE), palette[0])
    draw = ImageDraw.Draw(image)
    # Irregular 2-6px clusters are large enough to read as flat cel-shaded
    # surface marks at the 32px logical resolution. They deliberately replace
    # per-pixel noise, which would amount to forbidden dithering.
    for index in range(26):
        x = 2 + value_hash(index, 3, salt) % 25
        y = 2 + value_hash(5, index, salt) % 25
        width = 2 + value_hash(index, index, salt + 17) % 5
        height = 2 + value_hash(index, 7, salt + 31) % 4
        color_index = 1 + value_hash(9, index, salt + 47) % 4
        draw.rounded_rectangle(
            (x, y, min(29, x + width), min(29, y + height)),
            radius=1,
            fill=palette[color_index],
        )
        if index % 7 == 0:
            draw.line(
                (x + 1, y, min(29, x + width - 1), y),
                fill=palette[min(5, color_index + 1)],
                width=1,
            )

    if name == "ground_tile":
        draw.rectangle((7, 6, 9, 7), fill=palette[4])
        draw.rectangle((22, 20, 24, 21), fill=palette[3])
        draw.point((15, 25), fill=palette[5])
    elif name == "ash_drift":
        draw.polygon(((4, 9), (9, 6), (15, 8), (18, 12), (12, 14), (6, 13)), fill=palette[3])
        draw.polygon(((18, 21), (23, 18), (28, 20), (27, 24), (21, 25)), fill=palette[4])
        draw.line((6, 10, 14, 9), fill=palette[5], width=1)
    elif name == "scorched_earth":
        draw.polygon(((5, 8), (10, 5), (15, 8), (14, 13), (9, 15), (5, 12)), fill=palette[1])
        draw.polygon(((18, 19), (25, 17), (28, 22), (24, 27), (18, 25)), fill=palette[2])
        draw.line((8, 10, 12, 12), fill=palette[4], width=1)
        draw.point((23, 21), fill=palette[5])
    elif name == "broken_paving":
        draw.polygon(((4, 6), (11, 5), (13, 10), (10, 14), (5, 12)), fill=palette[3])
        draw.line((7, 6, 10, 12), fill=palette[1], width=1)
        draw.polygon(((18, 17), (26, 16), (28, 21), (25, 26), (19, 24)), fill=palette[4])
        draw.line((20, 18, 25, 24), fill=palette[1], width=1)

    # A one-pixel quiet edge makes every rotation interchangeable. Since the
    # dominant fill also appears throughout each tile, it does not form a
    # contrasting frame when four rotated copies meet.
    edge_color = GROUND_PALETTES["ground_tile"][0]
    draw.rectangle((0, 0, 31, 31), outline=edge_color, width=1)

    return image


def trim(image: Image.Image, threshold: int = 1) -> Image.Image:
    alpha = image.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("source image has no visible foreground")
    return image.crop(bbox)


def box_resize_rgba(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = image.convert("RGBA")
    red, green, blue, alpha = rgba.split()
    alpha_values = list(alpha.get_flattened_data())
    channels: list[Image.Image] = []
    for channel in (red, green, blue):
        premultiplied = Image.new("L", rgba.size)
        premultiplied.putdata([
            round(value * a / 255)
            for value, a in zip(channel.get_flattened_data(), alpha_values)
        ])
        channels.append(premultiplied.resize(size, Image.Resampling.BOX))
    small_alpha = alpha.resize(size, Image.Resampling.BOX)

    result = Image.new("RGBA", size)
    pixels = []
    for r, g, b, a in zip(
        channels[0].get_flattened_data(),
        channels[1].get_flattened_data(),
        channels[2].get_flattened_data(),
        small_alpha.get_flattened_data(),
    ):
        if a < 128:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((
                min(255, round(r * 255 / a)),
                min(255, round(g * 255 / a)),
                min(255, round(b * 255 / a)),
                255,
            ))
    result.putdata(pixels)
    return result


def fit_to_canvas(source: Image.Image, size: tuple[int, int]) -> Image.Image:
    subject = trim(source.convert("RGBA"), 96)
    max_width = max(1, size[0] - 2)
    max_height = max(1, size[1] - 1)
    factor = min(max_width / subject.width, max_height / subject.height)
    resized_size = (
        max(1, round(subject.width * factor)),
        max(1, round(subject.height * factor)),
    )
    reduced = trim(box_resize_rgba(subject, resized_size), 128)
    canvas = Image.new("RGBA", size)
    x = (size[0] - reduced.width) // 2
    y = size[1] - reduced.height
    canvas.alpha_composite(reduced, (x, y))
    return canvas


def palette_from_images(images: list[Image.Image]) -> tuple[tuple[int, int, int], ...]:
    samples = [pixel[:3] for image in images for pixel in image.get_flattened_data() if pixel[3]]
    strip = Image.new("RGB", (len(samples), 1))
    strip.putdata(samples)
    quantized = strip.quantize(
        colors=PROP_PALETTE_SIZE,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    return tuple(dict.fromkeys(quantized.get_flattened_data()))


def apply_palette(image: Image.Image, palette: tuple[tuple[int, int, int], ...]) -> Image.Image:
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    output = []
    for r, g, b, alpha in image.get_flattened_data():
        if not alpha:
            output.append((0, 0, 0, 0))
            continue
        source = (r, g, b)
        if source not in cache:
            cache[source] = min(
                palette,
                key=lambda color: sum((value - target) ** 2 for value, target in zip(source, color)),
            )
        output.append((*cache[source], 255))
    result = Image.new("RGBA", image.size)
    result.putdata(output)
    return result


def add_outline(image: Image.Image) -> Image.Image:
    source = image.convert("RGBA")
    alpha = source.getchannel("A")
    result = source.copy()
    ink = (8, 9, 10, 255)
    for y in range(source.height):
        for x in range(source.width):
            if alpha.getpixel((x, y)):
                continue
            neighbours = ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
            if any(
                0 <= nx < source.width and 0 <= ny < source.height and alpha.getpixel((nx, ny))
                for nx, ny in neighbours
            ):
                result.putpixel((x, y), ink)
    return result


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


def build_props() -> dict[str, Image.Image]:
    logical: dict[str, Image.Image] = {}
    for spec in SPRITES:
        path = RAW / f"{spec.name}.png"
        if not path.exists():
            raise FileNotFoundError(f"missing generated source: {path}")
        logical[spec.name] = fit_to_canvas(Image.open(path), spec.logical_size)

    palette = palette_from_images(list(logical.values()))
    result: dict[str, Image.Image] = {}
    for spec in SPRITES:
        sprite = add_outline(apply_palette(logical[spec.name], palette))
        if sprite.getchannel("A").getbbox() is None:
            raise ValueError(f"{spec.name} has no visible pixels")
        if set(sprite.getchannel("A").get_flattened_data()) - {0, 255}:
            raise ValueError(f"{spec.name} alpha is not binary")
        if spec.solid and sprite.getchannel("A").getbbox()[3] != spec.logical_size[1]:
            raise ValueError(f"{spec.name} does not touch its bottom placement row")
        result[spec.name] = sprite
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


def validate(ground: dict[str, Image.Image], props: dict[str, Image.Image]) -> None:
    base_dominant = Counter(ground["ground_tile"].get_flattened_data()).most_common(1)[0][0]
    for name, tile in ground.items():
        counts = Counter(tile.get_flattened_data())
        dominant, count = counts.most_common(1)[0]
        if len(counts) < 3 or count / (LOGICAL_TILE * LOGICAL_TILE) > 0.70:
            raise ValueError(f"{name} is too flat: {len(counts)} colors, {count / 10.24:.1f}% dominant")
        if name != "ground_tile":
            distance = sum(abs(a - b) for a, b in zip(base_dominant, dominant))
            if distance < 24:
                raise ValueError(f"{name} dominant is only {distance} from base")

    for name, sprite in props.items():
        colors = {pixel for pixel in sprite.get_flattened_data() if pixel[3]}
        if len(colors) > 64:
            raise ValueError(f"{name} uses {len(colors)} opaque colors")


def main() -> None:
    ground = {name: paint_ground(name) for name in GROUND_PALETTES}
    props = build_props()
    validate(ground, props)
    save_assets(ground, props)
    make_contact_sheet(ground, props)
    for name, image in {**ground, **props}.items():
        counts = Counter(image.get_flattened_data())
        print(f"{name}: {image.width}x{image.height} logical, {len(counts)} RGBA colors")


if __name__ == "__main__":
    main()
