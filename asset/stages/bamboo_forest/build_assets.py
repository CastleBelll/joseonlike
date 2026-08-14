from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "asset" / "stages" / "bamboo_forest"
RAW_GROUND = ROOT / "tmp" / "bamboo_forest" / "higgsfield-ground.png"
RAW_PROPS = ROOT / "tmp" / "bamboo_forest" / "higgsfield-props.png"
TAOIST = ROOT / "asset" / "characters" / "taoist" / "idle.png"
SCALE = 16
CONTACT_SCALE = 8


@dataclass(frozen=True)
class SpriteSpec:
    name: str
    cell: tuple[int, int]
    logical_size: tuple[int, int]
    folder: str
    semi_transparent: bool = False


SPRITES = (
    SpriteSpec("bamboo_clump_small", (0, 0), (24, 40), "props"),
    SpriteSpec("bamboo_clump_large", (1, 0), (40, 56), "props"),
    SpriteSpec("rock_small", (2, 0), (20, 16), "props"),
    SpriteSpec("rock_large", (3, 0), (32, 26), "props"),
    SpriteSpec("water_puddle", (0, 1), (40, 28), "props"),
    SpriteSpec("fallen_log", (1, 1), (48, 20), "props"),
    SpriteSpec("stone_lantern", (2, 1), (20, 36), "props"),
    SpriteSpec("shrine_post", (3, 1), (16, 40), "props"),
    SpriteSpec("grass_tuft", (0, 2), (12, 10), "decor"),
    SpriteSpec("fern", (1, 2), (16, 14), "decor"),
    SpriteSpec("pebbles", (2, 2), (14, 8), "decor"),
    SpriteSpec("fog_wisp", (3, 2), (48, 24), "decor", semi_transparent=True),
)


def trim(image: Image.Image, threshold: int = 0) -> Image.Image:
    alpha = image.getchannel("A")
    if threshold:
        alpha = alpha.point(lambda value: 255 if value >= threshold else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("source crop has no visible foreground")
    return image.crop(bbox)


def key_magenta(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for r, g, b, _ in rgba.get_flattened_data():
        keyed = r >= 165 and b >= 145 and g <= 125 and min(r, b) - g >= 45
        if keyed:
            pixels.append((0, 0, 0, 0))
            continue
        # Remove residual magenta spill without disturbing blue moonlight.
        excess = min(r, b) - g
        if excess > 28 and r > 120:
            r = max(g + 22, r - (excess - 22))
        pixels.append((r, g, b, 255))
    rgba.putdata(pixels)
    return rgba


def extract_fog(image: Image.Image) -> Image.Image:
    """Recover the generated fog from its intentionally dark preview cell."""
    rgb = image.convert("RGB")
    border = []
    for x in range(rgb.width):
        border.extend((rgb.getpixel((x, 0)), rgb.getpixel((x, rgb.height - 1))))
    for y in range(rgb.height):
        border.extend((rgb.getpixel((0, y)), rgb.getpixel((rgb.width - 1, y))))
    base = tuple(sorted(pixel[channel] for pixel in border)[len(border) // 2] for channel in range(3))

    rgba = Image.new("RGBA", rgb.size)
    pixels = []
    for r, g, b in rgb.get_flattened_data():
        signal = (r - base[0]) * 0.15 + (g - base[1]) * 0.35 + (b - base[2]) * 0.50
        blue_bias = max(0, b - r)
        alpha = max(0, min(170, round((signal - 4) * 5 + blue_bias * 0.7)))
        pixels.append((r, g, b, alpha))
    rgba.putdata(pixels)
    return trim(rgba, threshold=8)


def box_resize_rgba(image: Image.Image, size: tuple[int, int], *, binary_alpha: bool) -> Image.Image:
    rgba = image.convert("RGBA")
    red, green, blue, alpha = rgba.split()
    premultiplied = []
    alpha_values = list(alpha.get_flattened_data())
    for channel in (red, green, blue):
        premultiplied.append(
            Image.new("L", rgba.size)
        )
        premultiplied[-1].putdata([
            round(value * a / 255)
            for value, a in zip(channel.get_flattened_data(), alpha_values)
        ])
    small_channels = [channel.resize(size, Image.Resampling.BOX) for channel in premultiplied]
    small_alpha = alpha.resize(size, Image.Resampling.BOX)

    result = Image.new("RGBA", size)
    pixels = []
    for r, g, b, a in zip(
        small_channels[0].get_flattened_data(),
        small_channels[1].get_flattened_data(),
        small_channels[2].get_flattened_data(),
        small_alpha.get_flattened_data(),
    ):
        if (a < 128 and binary_alpha) or a == 0:
            pixels.append((0, 0, 0, 0))
            continue
        out_alpha = 255 if binary_alpha else a
        pixels.append(
            (
                min(255, round(r * 255 / a)),
                min(255, round(g * 255 / a)),
                min(255, round(b * 255 / a)),
                out_alpha,
            )
        )
    result.putdata(pixels)
    return result


def fit_to_canvas(subject: Image.Image, size: tuple[int, int], *, binary_alpha: bool) -> Image.Image:
    max_width = max(1, size[0] - 2)
    factor = min(max_width / subject.width, size[1] / subject.height)
    reduced = box_resize_rgba(
        subject,
        (max(1, round(subject.width * factor)), max(1, round(subject.height * factor))),
        binary_alpha=binary_alpha,
    )
    reduced = trim(reduced, threshold=1 if not binary_alpha else 128)
    canvas = Image.new("RGBA", size)
    x = (size[0] - reduced.width) // 2
    y = size[1] - reduced.height
    canvas.alpha_composite(reduced, (x, y))
    return canvas


def palette_from_images(images: list[Image.Image], colors: int) -> tuple[tuple[int, int, int], ...]:
    samples = [pixel[:3] for image in images for pixel in image.get_flattened_data() if pixel[3] >= 24]
    strip = Image.new("RGB", (len(samples), 1))
    strip.putdata(samples)
    quantized = strip.quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    return tuple(dict.fromkeys(quantized.get_flattened_data()))


def apply_palette(image: Image.Image, palette: tuple[tuple[int, int, int], ...]) -> Image.Image:
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    pixels = []
    for r, g, b, alpha in image.get_flattened_data():
        if not alpha:
            pixels.append((0, 0, 0, 0))
            continue
        source = (r, g, b)
        if source not in cache:
            cache[source] = min(
                palette,
                key=lambda color: sum((value - target) ** 2 for value, target in zip(source, color)),
            )
        pixels.append((*cache[source], alpha))
    result = Image.new("RGBA", image.size)
    result.putdata(pixels)
    return result


def props_cell(sheet: Image.Image, column: int, row: int) -> Image.Image:
    left = round(column * sheet.width / 4)
    right = round((column + 1) * sheet.width / 4)
    top = round(row * sheet.height / 3)
    bottom = round((row + 1) * sheet.height / 3)
    return sheet.crop((left, top, right, bottom))


def build_sprites(sheet: Image.Image) -> dict[str, Image.Image]:
    logical: dict[str, Image.Image] = {}
    for spec in SPRITES:
        cell = props_cell(sheet, *spec.cell)
        if spec.semi_transparent:
            # The fog preview cell has a one-pixel magenta atlas rule. Exclude
            # a source-space safety margin so it cannot become an alpha band.
            margin = 16
            cell = cell.crop((margin, margin, cell.width - margin, cell.height - margin))
            subject = extract_fog(cell)
        else:
            subject = trim(key_magenta(cell), threshold=128)
        logical[spec.name] = fit_to_canvas(
            subject,
            spec.logical_size,
            binary_alpha=not spec.semi_transparent,
        )

    palette = palette_from_images(list(logical.values()), 32)
    return {name: apply_palette(image, palette) for name, image in logical.items()}


QUIET_GRAIN = (
    (4, 6, 1),
    (9, 24, -1),
    (14, 11, 1),
    (20, 27, 1),
    (23, 8, -1),
    (27, 18, 1),
    (6, 17, -1),
)


def median_rgb(image: Image.Image) -> tuple[int, int, int]:
    histogram = image.convert("RGB").histogram()
    medians = []
    for channel in range(3):
        values = histogram[channel * 256:(channel + 1) * 256]
        halfway = sum(values) // 2
        running = 0
        for value, count in enumerate(values):
            running += count
            if running >= halfway:
                medians.append(value)
                break
    return tuple(medians)


def quiet_tile(color: tuple[int, int, int]) -> Image.Image:
    """Make a nearly-flat logical tile with only seven one-pixel grain marks."""
    tile = Image.new("RGB", (32, 32), color)
    for x, y, delta in QUIET_GRAIN:
        tile.putpixel((x, y), tuple(max(0, min(255, value + delta)) for value in color))
    return tile


def build_ground(sheet: Image.Image) -> dict[str, Image.Image]:
    # Anchor the quiet palette to the Higgsfield base swatch, then compress all
    # variant differences to a few RGB levels. Direct logical-pixel grain
    # replaces the old mirrored patch, whose symmetry created a tiled diamond.
    source_base = median_rgb(sheet.crop((24, 24, 1000, 1000)))
    base = (
        min(255, source_base[0] + 2),
        min(255, source_base[1] + 2),
        min(255, source_base[2] + 1),
    )
    colors = {
        "ground_tile": base,
        "patchy_grass": (base[0] + 3, base[1] + 4, base[2] + 2),
        "dirt": (base[0] + 5, base[1] + 1, max(0, base[2] - 1)),
        "moss": (base[0] + 1, base[1] + 3, max(0, base[2] - 1)),
    }
    return {name: quiet_tile(color) for name, color in colors.items()}


def upscale(image: Image.Image, scale: int = SCALE) -> Image.Image:
    return image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)


def assert_seamless(tile: Image.Image) -> None:
    rgb = tile.convert("RGB")
    if list(rgb.crop((0, 0, 1, 32)).get_flattened_data()) != list(rgb.crop((31, 0, 32, 32)).get_flattened_data()):
        raise ValueError("ground tile left/right edges do not match")
    if list(rgb.crop((0, 0, 32, 1)).get_flattened_data()) != list(rgb.crop((0, 31, 32, 32)).get_flattened_data()):
        raise ValueError("ground tile top/bottom edges do not match")
    edges = (
        list(rgb.crop((0, 0, 32, 1)).get_flattened_data()),
        list(rgb.crop((31, 0, 32, 32)).get_flattened_data()),
        list(rgb.crop((0, 31, 32, 32)).get_flattened_data()),
        list(rgb.crop((0, 0, 1, 32)).get_flattened_data()),
    )
    if any(edge != edges[0] for edge in edges[1:]):
        raise ValueError("ground tile edges are not interchangeable under 90-degree rotation")


def assert_quiet_ground(ground: dict[str, Image.Image]) -> None:
    dominant: dict[str, tuple[int, int, int]] = {}
    for name, tile in ground.items():
        counts = Counter(tile.convert("RGB").get_flattened_data())
        color, count = counts.most_common(1)[0]
        dominant[name] = color
        if len(counts) != 3 or count != 1017:
            raise ValueError(f"{name} must be one flat color plus exactly seven grain pixels")
        if any(max(abs(value - anchor) for value, anchor in zip(candidate, color)) > 1 for candidate in counts):
            raise ValueError(f"{name} grain exceeds one RGB level")
    base = dominant["ground_tile"]
    for name, color in dominant.items():
        if name != "ground_tile" and max(abs(value - anchor) for value, anchor in zip(color, base)) > 5:
            raise ValueError(f"{name} differs too strongly from the base tile")


def rotated(tile: Image.Image, turns: int) -> Image.Image:
    rotations = (
        None,
        Image.Transpose.ROTATE_90,
        Image.Transpose.ROTATE_180,
        Image.Transpose.ROTATE_270,
    )
    return tile.copy() if turns % 4 == 0 else tile.transpose(rotations[turns % 4])


def mixed_ground(ground: dict[str, Image.Image], cells: int = 8) -> Image.Image:
    """Mix 10/64 variant tiles in three small clusters, with per-tile rotation."""
    placements = {
        (1, 1): "moss", (1, 2): "moss", (2, 1): "moss", (2, 2): "moss",
        (5, 4): "patchy_grass", (5, 5): "patchy_grass", (6, 4): "patchy_grass",
        (3, 6): "dirt", (4, 6): "dirt", (4, 7): "dirt",
    }
    image = Image.new("RGB", (cells * 32, cells * 32))
    for y in range(cells):
        for x in range(cells):
            name = placements.get((x, y), "ground_tile") if cells == 8 else "ground_tile"
            image.paste(rotated(ground[name], (x + y * 2) % 4), (x * 32, y * 32))
    return image


def save_assets(ground: dict[str, Image.Image], sprites: dict[str, Image.Image]) -> None:
    (OUT / "ground_variants").mkdir(parents=True, exist_ok=True)
    (OUT / "props").mkdir(parents=True, exist_ok=True)
    (OUT / "decor").mkdir(parents=True, exist_ok=True)

    upscale(ground["ground_tile"]).save(OUT / "ground_tile.png", optimize=True)
    for name in ("patchy_grass", "dirt", "moss"):
        upscale(ground[name]).save(OUT / "ground_variants" / f"{name}.png", optimize=True)
    for spec in SPRITES:
        upscale(sprites[spec.name]).save(OUT / spec.folder / f"{spec.name}.png", optimize=True)


def make_contact_sheet(ground: dict[str, Image.Image], sprites: dict[str, Image.Image]) -> None:
    verification = Image.new("RGB", (128, 128))
    for y in range(4):
        for x in range(4):
            verification.paste(ground["ground_tile"], (x * 32, y * 32))

    stage = Image.new("RGB", (128, 128))
    for y in range(4):
        for x in range(4):
            name = {
                (0, 0): "moss",
                (1, 0): "moss",
                (3, 3): "dirt",
            }.get((x, y), "ground_tile")
            stage.paste(rotated(ground[name], (x + y * 2) % 4), (x * 32, y * 32))

    def place(name: str, x: int, y: int) -> None:
        stage.paste(sprites[name], (x, y), sprites[name])

    place("bamboo_clump_large", 2, 1)
    place("bamboo_clump_small", 42, 3)
    place("rock_large", 85, 30)
    place("rock_small", 66, 39)
    place("water_puddle", 44, 69)
    place("fallen_log", 78, 98)
    place("stone_lantern", 106, 58)
    place("shrine_post", 7, 70)
    place("grass_tuft", 25, 105)
    place("fern", 38, 106)
    place("pebbles", 60, 117)
    place("fog_wisp", 73, 4)

    if TAOIST.exists():
        taoist = Image.open(TAOIST).convert("RGBA").resize((40, 40), Image.Resampling.NEAREST)
        stage.paste(taoist, (46, 42), taoist)

    combined = Image.new("RGB", (256, 128), (8, 12, 13))
    combined.paste(verification, (0, 0))
    combined.paste(stage, (128, 0))
    upscale(combined, CONTACT_SCALE).save(OUT / "contact-sheet.png", optimize=True)
    pure_base = Image.new("RGB", (256, 256))
    for y in range(8):
        for x in range(8):
            pure_base.paste(rotated(ground["ground_tile"], (x + y * 2) % 4), (x * 32, y * 32))
    upscale(pure_base, 4).save(OUT / "tile-verification.png", optimize=True)
    upscale(mixed_ground(ground), 4).save(OUT / "ground-verification.png", optimize=True)


def main() -> None:
    if not RAW_GROUND.exists() or not RAW_PROPS.exists():
        raise FileNotFoundError("download the two documented Higgsfield jobs into tmp/bamboo_forest first")
    ground = build_ground(Image.open(RAW_GROUND))
    sprites = build_sprites(Image.open(RAW_PROPS))

    assert_quiet_ground(ground)
    for tile in ground.values():
        assert_seamless(tile)
    for spec in SPRITES:
        image = sprites[spec.name]
        bbox = image.getchannel("A").getbbox()
        if bbox is None:
            raise ValueError(f"{spec.name} has no visible pixels")
        if not spec.semi_transparent and bbox[3] != spec.logical_size[1]:
            raise ValueError(f"{spec.name} does not touch its bottom placement row")
        if not spec.semi_transparent and set(image.getchannel("A").get_flattened_data()) - {0, 255}:
            raise ValueError(f"{spec.name} alpha is not binary")
        for r, g, b, alpha in image.get_flattened_data():
            if alpha and r >= 145 and b >= 135 and g <= 120 and min(r, b) - g >= 35:
                raise ValueError(f"magenta fringe remains in {spec.name}")

    save_assets(ground, sprites)
    make_contact_sheet(ground, sprites)
    print("built 4 seamless ground tiles, 8 solid props, and 4 decor sprites")


if __name__ == "__main__":
    main()
