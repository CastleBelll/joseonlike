from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "asset" / "monsters"
SOURCE = ROOT / "tmp" / "bamboo_monsters" / "higgsfield-monsters.png"
GROUND = ROOT / "asset" / "stages" / "bamboo_forest" / "ground_tile.png"
TAOIST = ROOT / "asset" / "characters" / "taoist" / "idle.png"
SCALE = 16


@dataclass(frozen=True)
class MonsterSpec:
    monster_id: str
    cell: tuple[int, int]
    logical_size: tuple[int, int]
    figure_height: int
    palette_size: int
    lower_split: float
    stride: int


MONSTERS = (
    MonsterSpec("forest_goblin", (0, 0), (32, 32), 27, 20, 0.68, 1),
    MonsterSpec("forest_spirit", (1, 0), (32, 32), 29, 20, 0.58, 1),
    MonsterSpec("bamboo_brute", (0, 1), (48, 48), 44, 28, 0.68, 2),
    MonsterSpec("bamboo_spirit_lord", (1, 1), (96, 96), 84, 32, 0.66, 3),
)


def trim(image: Image.Image, threshold: int = 1) -> Image.Image:
    alpha = image.getchannel("A")
    if threshold > 1:
        alpha = alpha.point(lambda value: 255 if value >= threshold else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("source crop has no visible foreground")
    return image.crop(bbox)


def key_magenta(image: Image.Image) -> Image.Image:
    """Remove the full-resolution #ff00ff field before any resampling."""
    rgba = image.convert("RGBA")
    pixels = []
    for r, g, b, _ in rgba.get_flattened_data():
        keyed = r >= 160 and b >= 150 and g <= 135 and min(r, b) - g >= 45
        if keyed:
            pixels.append((0, 0, 0, 0))
            continue
        # Despill hot-pink edge blends without changing blue-white spirit hues.
        # Dark antialiased blends can be far below the key threshold, so
        # neutralize both magenta channels instead of checking brightness.
        excess = min(r, b) - g
        if excess > 8:
            r = min(r, g + 8)
            b = min(b, g + 10)
        pixels.append((r, g, b, 255))
    rgba.putdata(pixels)
    return rgba


def box_resize_rgba(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """BOX-resize premultiplied RGBA, then threshold alpha back to binary."""
    rgba = image.convert("RGBA")
    red, green, blue, alpha = rgba.split()
    alpha_values = list(alpha.get_flattened_data())
    premultiplied = []
    for channel in (red, green, blue):
        premul = Image.new("L", rgba.size)
        premul.putdata([
            round(value * a / 255)
            for value, a in zip(channel.get_flattened_data(), alpha_values)
        ])
        premultiplied.append(premul.resize(size, Image.Resampling.BOX))
    small_alpha = alpha.resize(size, Image.Resampling.BOX)

    result = Image.new("RGBA", size)
    pixels = []
    for r, g, b, a in zip(
        premultiplied[0].get_flattened_data(),
        premultiplied[1].get_flattened_data(),
        premultiplied[2].get_flattened_data(),
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


def source_cell(sheet: Image.Image, cell: tuple[int, int]) -> Image.Image:
    width = sheet.width // 2
    height = sheet.height // 2
    x, y = cell
    return sheet.crop((x * width, y * height, (x + 1) * width, (y + 1) * height))


def fit_to_canvas(subject: Image.Image, spec: MonsterSpec) -> Image.Image:
    subject = trim(subject, 128)
    max_width = spec.logical_size[0] - 2
    factor = min(max_width / subject.width, spec.figure_height / subject.height)
    size = (
        max(1, round(subject.width * factor)),
        max(1, round(subject.height * factor)),
    )
    reduced = trim(box_resize_rgba(subject, size), 128)
    canvas = Image.new("RGBA", spec.logical_size)
    x = (spec.logical_size[0] - reduced.width) // 2
    y = spec.logical_size[1] - reduced.height
    canvas.alpha_composite(reduced, (x, y))
    return canvas


def palette_from_image(image: Image.Image, colors: int) -> tuple[tuple[int, int, int], ...]:
    samples = [pixel[:3] for pixel in image.get_flattened_data() if pixel[3]]
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
        pixels.append((*cache[source], 255))
    result = Image.new("RGBA", image.size)
    result.putdata(pixels)
    return result


def reinforce_identity(image: Image.Image, monster_id: str) -> Image.Image:
    """Restore only tiny identity marks that can vanish during BOX reduction."""
    result = image.copy()
    bbox = result.getchannel("A").getbbox()
    if bbox is None:
        return result
    x0, y0, x1, y1 = bbox
    width = x1 - x0
    height = y1 - y0
    if monster_id == "forest_goblin":
        eye = (x0 + round(width * 0.66), y0 + round(height * 0.34))
        if result.getpixel(eye)[3]:
            result.putpixel(eye, (213, 236, 179, 255))
    elif monster_id == "forest_spirit":
        for ratio in (0.43, 0.63):
            eye = (x0 + round(width * ratio), y0 + round(height * 0.28))
            if result.getpixel(eye)[3]:
                result.putpixel(eye, (75, 235, 229, 255))
    return result


def make_walk_frames(idle: Image.Image, spec: MonsterSpec) -> list[Image.Image]:
    """Lock the upper body while alternating contact/pass lower silhouettes."""
    width, height = idle.size
    bbox = idle.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError(f"{spec.monster_id} has no visible pixels")
    split = bbox[1] + round((bbox[3] - bbox[1]) * spec.lower_split)
    mid = width // 2
    upper = idle.crop((0, 0, width, split))
    lower_left = idle.crop((0, split, mid, height))
    lower_right = idle.crop((mid, split, width, height))

    poses = (
        (-spec.stride, spec.stride, 0, 0),
        (1, -1, -1, 0),
        (-spec.stride, spec.stride, 0, 1),
        (1, -1, -1, 1),
    )
    frames: list[Image.Image] = []
    for left_dx, right_dx, bob, right_lift in poses:
        frame = Image.new("RGBA", idle.size)
        frame.alpha_composite(upper, (0, bob))
        frame.alpha_composite(lower_left, (left_dx, split + bob))
        frame.alpha_composite(lower_right, (mid + right_dx, split + bob + right_lift))
        frames.append(frame)
    return frames


def make_boss_breathe(idle: Image.Image) -> list[Image.Image]:
    bbox = idle.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("boss has no visible pixels")
    split = bbox[1] + round((bbox[3] - bbox[1]) * 0.62)
    # Include the first lower-body row in the shifted crop so the one-pixel
    # inhale overlaps at the waist instead of opening a transparent seam.
    upper = idle.crop((0, 0, idle.width, split + 1))
    lower = idle.crop((0, split, idle.width, idle.height))
    inhale = Image.new("RGBA", idle.size)
    inhale.alpha_composite(upper, (0, -1))
    inhale.alpha_composite(lower, (0, split))
    return [idle, inhale]


def upscale(image: Image.Image, scale: int = SCALE) -> Image.Image:
    return image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)


def save_strip(frames: list[Image.Image], path: Path) -> None:
    width, height = frames[0].size
    strip = Image.new("RGBA", (width * len(frames), height))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * width, 0))
    upscale(strip).save(path, optimize=True)


def logical_ground(size: tuple[int, int]) -> Image.Image:
    tile = Image.open(GROUND).convert("RGB").resize((32, 32), Image.Resampling.NEAREST)
    ground = Image.new("RGB", size)
    for y in range(0, size[1], 32):
        for x in range(0, size[0], 32):
            ground.paste(tile, (x, y))
    return ground


def make_contact_sheet(idles: dict[str, Image.Image]) -> None:
    stage = logical_ground((288, 128))

    def place(image: Image.Image, x: int) -> None:
        y = 124 - image.height
        stage.paste(image, (x, y), image)

    place(idles["forest_goblin"], 8)
    place(idles["forest_spirit"], 48)
    if TAOIST.exists():
        taoist = Image.open(TAOIST).convert("RGBA").resize((40, 40), Image.Resampling.NEAREST)
        place(taoist, 88)
    place(idles["bamboo_brute"], 136)
    place(idles["bamboo_spirit_lord"], 192)
    upscale(stage, 8).save(OUT / "contact-sheet.png", optimize=True)


def validate(spec: MonsterSpec, idle: Image.Image, walk: list[Image.Image]) -> None:
    bbox = idle.getchannel("A").getbbox()
    if bbox is None or bbox[3] != spec.logical_size[1]:
        raise ValueError(f"{spec.monster_id} idle base must touch the bottom row")
    if bbox[3] - bbox[1] != spec.figure_height:
        raise ValueError(
            f"{spec.monster_id} figure height {bbox[3] - bbox[1]} != {spec.figure_height}"
        )
    for index, image in enumerate([idle, *walk]):
        if set(image.getchannel("A").get_flattened_data()) - {0, 255}:
            raise ValueError(f"{spec.monster_id} frame {index} alpha is not binary")
        for r, g, b, alpha in image.get_flattened_data():
            if alpha and r >= 145 and b >= 140 and g <= 125 and min(r, b) - g >= 35:
                raise ValueError(f"magenta fringe remains in {spec.monster_id}")
    if len({image.tobytes() for image in walk}) != 4:
        raise ValueError(f"{spec.monster_id} walk frames are not distinct")
    split = bbox[1] + round((bbox[3] - bbox[1]) * spec.lower_split)
    expected_contact = idle.crop((0, 0, idle.width, split))
    for index in (0, 2):
        if walk[index].crop((0, 0, idle.width, split)).tobytes() != expected_contact.tobytes():
            raise ValueError(f"{spec.monster_id} contact upper body drifted")
    expected_bob = idle.crop((0, 1, idle.width, split))
    for index in (1, 3):
        if walk[index].crop((0, 0, idle.width, split - 1)).tobytes() != expected_bob.tobytes():
            raise ValueError(f"{spec.monster_id} passing upper body is not a one-pixel bob")


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError("download the documented Higgsfield job to tmp/bamboo_monsters")
    sheet = Image.open(SOURCE)
    idles: dict[str, Image.Image] = {}
    walks: dict[str, list[Image.Image]] = {}

    for spec in MONSTERS:
        source = trim(key_magenta(source_cell(sheet, spec.cell)), 128)
        logical = fit_to_canvas(source, spec)
        palette = palette_from_image(logical, spec.palette_size)
        idle = reinforce_identity(apply_palette(logical, palette), spec.monster_id)
        walk = make_walk_frames(idle, spec)
        validate(spec, idle, walk)
        idles[spec.monster_id] = idle
        walks[spec.monster_id] = walk

        folder = OUT / spec.monster_id
        folder.mkdir(parents=True, exist_ok=True)
        upscale(idle).save(folder / "idle.png", optimize=True)
        save_strip(walk, folder / "walk.png")
        if spec.monster_id == "bamboo_spirit_lord":
            save_strip(make_boss_breathe(idle), folder / "idle_breathe.png")

    make_contact_sheet(idles)
    print("built 4 idle sprites, 4 four-frame walk strips, and boss idle breathe")


if __name__ == "__main__":
    main()
