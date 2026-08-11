"""Build warm camp ground and rotatable transition overlays from Higgsfield concepts.

The concepts have already passed through pixelize.py against the Taoist palette.
This pass guarantees edge identity for repeating ground, keeps hard alpha for the
overlays, and limits every deliverable to the ground-tile 32-colour budget.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
CAMP = ROOT / "asset/camp"
RAW = CAMP / "raw"
GROUND = CAMP / "ground"
TRANSITION = CAMP / "transition"

SIZE = 256
TRANSPARENT = (0, 0, 0, 0)
INK = (26, 22, 19, 255)
EARTH_DARK = (116, 69, 43, 255)
EARTH = (185, 116, 68, 255)
STONE_DARK = (151, 132, 98, 255)
STONE = (214, 197, 161, 255)
PAPER = (237, 224, 196, 255)


def hard_palette(image: Image.Image, colors: int = 32) -> Image.Image:
    """Quantise opaque pixels while preserving exact transparent pixels."""
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    rgb = rgba.convert("RGB").quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    rgb.putalpha(alpha)
    return rgb


def seamless_tile(source: Image.Image) -> Image.Image:
    """Bind terminal rows/columns on a concept already composed for tiling.

    Both generated concepts deliberately carry their paths through the midpoint of
    each edge, so preserving the full composition avoids the fourfold symmetry of
    a mirrored-quadrant repair. Binding only the terminal pixels makes the seam
    exact without discarding that useful large-scale variation.
    """
    image = ImageOps.fit(source.convert("RGB"), (SIZE, SIZE), Image.Resampling.BOX)
    image = hard_palette(image, 32)
    image.paste(image.crop((0, 0, 1, SIZE)), (SIZE - 1, 0))
    image.paste(image.crop((0, 0, SIZE, 1)), (0, SIZE - 1))
    return image


def irregular_corridor_mask(width_top: int, width_bottom: int, end_y: int = SIZE) -> Image.Image:
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(mask)
    points_left = []
    points_right = []
    for y in range(0, end_y, 8):
        t = y / max(1, end_y - 1)
        half = round((width_top + (width_bottom - width_top) * t) / 2)
        wobble = (0, 2, -1, 3, -2, 1)[(y // 8) % 6]
        points_left.append((SIZE // 2 - half + wobble, y))
        points_right.append((SIZE // 2 + half + wobble, y))
    polygon = points_left + list(reversed(points_right))
    draw.polygon(polygon, fill=255)
    return mask


def path_overlay(path_source: Image.Image) -> Image.Image:
    """A north-south flagstone strip; rotate for other directions."""
    # The generated concept's central band contains the clearest flagstones.
    band = path_source.crop((64, 0, 192, SIZE)).resize((SIZE, SIZE), Image.Resampling.BOX)
    mask = irregular_corridor_mask(42, 56)
    out = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
    out.paste(band.convert("RGBA"), (0, 0), mask)
    return hard_palette(out, 24)


def gate_approach(path_source: Image.Image) -> Image.Image:
    """A north-facing path that terminates in an unmistakable gate threshold."""
    out = path_overlay(path_source)
    draw = ImageDraw.Draw(out)
    # A two-rail threshold remains legible under the existing Joseon gate sprite.
    draw.rectangle((76, 12, 179, 18), fill=INK)
    draw.rectangle((82, 18, 173, 25), fill=STONE_DARK)
    draw.rectangle((88, 20, 167, 23), fill=PAPER)
    for x in (82, 128, 169):
        draw.rectangle((x, 12, x + 3, 25), fill=EARTH_DARK)
    return hard_palette(out, 24)


def boundary_edge() -> Image.Image:
    """North-facing camp limit overlay; rotate and place beneath fence/gate art."""
    out = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
    draw = ImageDraw.Draw(out)
    # Ditch, stone curb and swept-earth fringe make the safe zone end explicit.
    draw.rectangle((0, 0, 255, 15), fill=INK)
    draw.rectangle((0, 16, 255, 25), fill=EARTH_DARK)
    draw.rectangle((0, 26, 255, 31), fill=STONE_DARK)
    for x in range(-8, 264, 24):
        offset = 3 if (x // 24) % 2 else 0
        draw.rectangle((x + offset, 25, x + 17 + offset, 34), fill=STONE)
        draw.rectangle((x + 3 + offset, 27, x + 14 + offset, 31), fill=PAPER)
    # Sparse inward grass/brush teeth prevent a ruler-straight UI-looking edge.
    for x, height in ((12, 9), (38, 5), (71, 12), (109, 6), (146, 10), (188, 7), (225, 12)):
        draw.polygon(((x, 32), (x + 3, 32 + height), (x + 6, 32)), fill=EARTH_DARK)
    return hard_palette(out, 12)


def metrics(paths: list[Path]) -> dict:
    records = {}
    for path in paths:
        image = Image.open(path).convert("RGBA")
        records[str(path.relative_to(ROOT)).replace("\\", "/")] = {
            "canvas": list(image.size),
            "colours": len({pixel[:3] for pixel in image.get_flattened_data() if pixel[3]}),
            "alpha_values": sorted({pixel[3] for pixel in image.get_flattened_data()}),
            "left_right_identical": list(image.crop((0, 0, 1, SIZE)).get_flattened_data())
            == list(image.crop((SIZE - 1, 0, SIZE, SIZE)).get_flattened_data()),
            "top_bottom_identical": list(image.crop((0, 0, SIZE, 1)).get_flattened_data())
            == list(image.crop((0, SIZE - 1, SIZE, SIZE)).get_flattened_data()),
        }
    return records


def layout_preview(courtyard: Image.Image) -> None:
    """Render a read-only visual QA mock using the camp's current 540x960 layout."""
    preview = courtyard.convert("RGBA").resize((540, 960), Image.Resampling.NEAREST)

    def place(path: Path, center: tuple[int, int], rotation: int = 0) -> None:
        sprite = Image.open(path).convert("RGBA")
        if rotation:
            sprite = sprite.rotate(rotation, expand=True, resample=Image.Resampling.NEAREST)
        preview.alpha_composite(sprite, (center[0] - sprite.width // 2, center[1] - sprite.height // 2))

    boundary = boundary_edge().resize((540, 256), Image.Resampling.NEAREST)
    preview.alpha_composite(boundary, (0, 0))
    place(ROOT / "asset/structure/joseon_gate.png", (270, 76))
    for name, center in (
        ("workshop", (150, 260)), ("archive", (390, 260)),
        ("training_ground", (150, 470)), ("camp_shrine", (390, 470)),
    ):
        place(ROOT / f"asset/structure/{name}.png", center)
    place(ROOT / "asset/structure/stone_lantern.png", (60, 620))
    place(ROOT / "asset/structure/jangseung_pair.png", (480, 620))
    place(ROOT / "asset/character/Taoist/Idle/rotations/south.png", (270, 660))
    preview.save(RAW / "camp_layout_preview.png")


def main() -> None:
    GROUND.mkdir(parents=True, exist_ok=True)
    TRANSITION.mkdir(parents=True, exist_ok=True)
    courtyard_source = Image.open(RAW / "camp_ground_concept_b_pixelized.png")
    path_source = Image.open(RAW / "camp_ground_concept_a_pixelized.png")

    courtyard = seamless_tile(courtyard_source)
    flagstone = seamless_tile(path_source)
    courtyard.save(GROUND / "courtyard.png")
    flagstone.save(GROUND / "flagstone.png")
    path_overlay(path_source).save(TRANSITION / "path_overlay_north.png")
    gate_approach(path_source).save(TRANSITION / "gate_approach_north.png")
    boundary_edge().save(TRANSITION / "boundary_north.png")
    layout_preview(courtyard)

    paths = [
        GROUND / "courtyard.png", GROUND / "flagstone.png",
        TRANSITION / "path_overlay_north.png",
        TRANSITION / "gate_approach_north.png",
        TRANSITION / "boundary_north.png",
    ]
    stage = Image.open(ROOT / "asset/stage/bamboo_forest_ground.png").convert("RGB")
    camp = courtyard.convert("RGB")
    mean = lambda im: round(sum(sum(pixel) / 3 for pixel in im.get_flattened_data()) / (im.width * im.height), 2)
    payload = {
        "generator": "Higgsfield Nano Banana Pro, two 1K jobs conditioned on the existing stage ground and Joseon gate",
        "canonical_orientation": "north for all transition overlays; rotate in 90-degree increments",
        "ground": metrics(paths),
        "mean_rgb_brightness": {
            "bamboo_forest_stage": mean(stage),
            "camp_courtyard": mean(camp),
        },
    }
    (CAMP / "camp_ground_metrics.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print("built 2 seamless camp tiles and 3 north-facing transition overlays")


if __name__ == "__main__":
    main()
