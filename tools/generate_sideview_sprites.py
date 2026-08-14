"""Generate deterministic 32 px Joseon side-view character sprites.

The artwork is authored on the same 32x32 logical grid as new_asset/basic.png,
then enlarged 16x with nearest-neighbour sampling.  Walk frames share the same
head and torso construction; only arm and leg parts vary by phase.
"""

from __future__ import annotations

from collections import Counter
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
LOGICAL_SIZE = 32
SCALE = 16
FRAME_SIZE = LOGICAL_SIZE * SCALE
OUTLINE = (24, 18, 18, 255)
TRANSPARENT = (0, 0, 0, 0)

Command = tuple[str, tuple[int, ...]]
Part = tuple[tuple[int, int, int, int], tuple[Command, ...]]


def rect(x0: int, y0: int, x1: int, y1: int) -> Command:
    return ("rect", (x0, y0, x1, y1))


def poly(*coordinates: int) -> Command:
    return ("poly", coordinates)


def part(color: tuple[int, int, int, int], *commands: Command) -> Part:
    return color, commands


def draw_mask(commands: Iterable[Command]) -> Image.Image:
    mask = Image.new("L", (LOGICAL_SIZE, LOGICAL_SIZE), 0)
    draw = ImageDraw.Draw(mask)
    for kind, values in commands:
        if kind == "rect":
            draw.rectangle(values, fill=255)
        elif kind == "poly":
            draw.polygon(list(zip(values[::2], values[1::2])), fill=255)
        else:  # pragma: no cover - generator-only guard
            raise ValueError(f"Unknown draw command: {kind}")
    return mask


def render(parts: list[Part]) -> Image.Image:
    masks = [(color, draw_mask(commands)) for color, commands in parts]
    silhouette = Image.new("L", (LOGICAL_SIZE, LOGICAL_SIZE), 0)
    for _, mask in masks:
        silhouette = ImageChops.lighter(silhouette, mask)

    outer = silhouette.filter(ImageFilter.MaxFilter(3))
    sprite = Image.new("RGBA", (LOGICAL_SIZE, LOGICAL_SIZE), TRANSPARENT)
    sprite.paste(OUTLINE, mask=outer)
    for color, mask in masks:
        sprite.paste(color, mask=mask)
    return sprite


def common_head(
    *,
    skin: tuple[int, int, int, int],
    skin_shadow: tuple[int, int, int, int],
    hair: tuple[int, int, int, int],
) -> list[Part]:
    """Right-facing head shared in scale and proportion across the family."""
    return [
        part(hair, poly(12, 8, 14, 6, 19, 6, 21, 8, 20, 12, 13, 12)),
        part(skin, poly(14, 9, 21, 8, 22, 10, 24, 11, 23, 13, 21, 13, 20, 16, 15, 16, 13, 13)),
        part(skin_shadow, rect(14, 13, 20, 15), rect(21, 12, 22, 13)),
        part(hair, rect(12, 9, 14, 13), rect(15, 7, 20, 8)),
        part(OUTLINE, rect(21, 10, 21, 10)),
    ]


def legs_for(
    phase: int | None,
    *,
    cloth: tuple[int, int, int, int],
    shadow: tuple[int, int, int, int],
    shoe: tuple[int, int, int, int],
) -> list[Part]:
    """Four readable contact/pass/contact/pass poses plus a neutral idle."""
    if phase is None:
        shapes = [
            part(shadow, poly(12, 22, 16, 22, 16, 27, 14, 27, 13, 25)),
            part(cloth, poly(17, 22, 21, 22, 20, 27, 17, 27, 18, 24)),
            part(shoe, rect(13, 27, 16, 27), rect(17, 27, 21, 27)),
        ]
    elif phase == 0:  # left/back leg extended behind, right/front leg forward
        shapes = [
            part(shadow, poly(12, 22, 16, 22, 15, 25, 11, 27, 9, 27, 13, 24)),
            part(cloth, poly(17, 22, 21, 22, 21, 25, 23, 27, 20, 27, 18, 25)),
            part(shoe, rect(9, 27, 13, 27), rect(20, 27, 24, 27)),
        ]
    elif phase == 1:  # passing pose, rear foot lifting
        shapes = [
            part(shadow, poly(12, 22, 16, 22, 17, 25, 15, 27, 13, 27, 14, 24)),
            part(cloth, poly(17, 22, 21, 22, 20, 27, 17, 27, 18, 24)),
            part(shoe, rect(13, 27, 16, 27), rect(17, 27, 21, 27)),
        ]
    elif phase == 2:  # opposite contact
        shapes = [
            part(shadow, poly(12, 22, 16, 22, 16, 25, 19, 27, 16, 27, 13, 25)),
            part(cloth, poly(17, 22, 21, 22, 19, 25, 15, 27, 12, 27, 17, 24)),
            part(shoe, rect(16, 27, 20, 27), rect(11, 27, 15, 27)),
        ]
    else:  # phase 3, passing pose with front foot lifting
        shapes = [
            part(shadow, poly(12, 22, 16, 22, 15, 27, 12, 27, 13, 24)),
            part(cloth, poly(17, 22, 21, 22, 19, 25, 21, 26, 21, 24, 20, 22)),
            part(shoe, rect(11, 27, 15, 27), rect(20, 25, 22, 26)),
        ]
    return shapes


def arms_for(
    phase: int | None,
    *,
    sleeve: tuple[int, int, int, int],
    sleeve_shadow: tuple[int, int, int, int],
    skin: tuple[int, int, int, int],
) -> list[Part]:
    if phase is None:
        return [
            part(sleeve_shadow, poly(11, 17, 13, 17, 13, 22, 12, 24, 10, 23, 11, 20)),
            part(sleeve, poly(19, 17, 21, 18, 22, 22, 20, 23, 19, 20)),
            part(skin, rect(20, 23, 21, 24)),
        ]
    poses = (
        (
            part(sleeve_shadow, poly(11, 17, 13, 17, 11, 21, 9, 23, 8, 22, 10, 19)),
            part(sleeve, poly(19, 17, 21, 18, 23, 21, 22, 23, 20, 21)),
            part(skin, rect(22, 22, 23, 23)),
        ),
        (
            part(sleeve_shadow, poly(11, 17, 13, 17, 12, 23, 10, 23, 11, 20)),
            part(sleeve, poly(19, 17, 21, 18, 22, 22, 20, 23, 19, 20)),
            part(skin, rect(20, 23, 21, 24)),
        ),
        (
            part(sleeve_shadow, poly(11, 17, 13, 17, 14, 21, 13, 23, 11, 22)),
            part(sleeve, poly(19, 17, 21, 18, 20, 22, 18, 23, 18, 20)),
            part(skin, rect(17, 23, 19, 24)),
        ),
        (
            part(sleeve_shadow, poly(11, 17, 13, 17, 13, 22, 12, 24, 10, 23, 11, 20)),
            part(sleeve, poly(19, 17, 21, 18, 22, 22, 20, 23, 19, 20)),
            part(skin, rect(20, 23, 21, 24)),
        ),
    )
    return list(poses[phase])


def taoist(phase: int | None) -> Image.Image:
    skin = (238, 185, 139, 255)
    skin_shadow = (202, 132, 94, 255)
    hair = (45, 31, 34, 255)
    robe = (238, 239, 218, 255)
    robe_light = (255, 250, 226, 255)
    robe_shadow = (187, 207, 207, 255)
    blue = (55, 111, 157, 255)
    blue_dark = (34, 70, 111, 255)

    parts = legs_for(phase, cloth=robe, shadow=robe_shadow, shoe=blue_dark)
    parts += arms_for(phase, sleeve=robe_light, sleeve_shadow=robe_shadow, skin=skin)
    parts += [
        part(robe_shadow, poly(11, 16, 19, 15, 21, 18, 21, 23, 11, 23, 10, 19)),
        part(robe, poly(13, 16, 20, 16, 21, 22, 12, 22, 11, 18)),
        part(robe_light, poly(15, 16, 20, 16, 20, 19, 14, 19)),
        part(blue, poly(15, 16, 17, 16, 19, 20, 18, 21, 16, 18), rect(11, 21, 21, 22)),
        part(blue_dark, rect(11, 22, 21, 22), rect(18, 21, 19, 23)),
        # A plain folded talisman-paper pouch; no directional glyphs.
        part((224, 187, 93, 255), rect(19, 19, 21, 21)),
        part((168, 100, 51, 255), rect(20, 20, 20, 21)),
    ]
    parts += common_head(skin=skin, skin_shadow=skin_shadow, hair=hair)
    parts += [
        # Small topknot and blue scholar band.
        part(hair, rect(15, 4, 18, 5), rect(14, 5, 19, 6)),
        part(blue_dark, rect(13, 7, 21, 7)),
        part(blue, rect(14, 7, 19, 7)),
    ]
    return render(parts)


def warrior(phase: int | None) -> Image.Image:
    skin = (218, 163, 119, 255)
    skin_shadow = (177, 107, 77, 255)
    hair = (40, 29, 31, 255)
    armor = (45, 69, 87, 255)
    armor_light = (66, 92, 104, 255)
    armor_shadow = (28, 42, 55, 255)
    red = (150, 49, 45, 255)
    red_light = (198, 70, 53, 255)
    brass = (200, 145, 52, 255)

    parts = legs_for(phase, cloth=red, shadow=(103, 43, 43, 255), shoe=armor_shadow)
    parts += arms_for(phase, sleeve=armor, sleeve_shadow=armor_shadow, skin=skin)
    parts += [
        # Broad lamellar torso and shoulder caps.
        part(armor_shadow, poly(10, 16, 20, 15, 23, 18, 22, 23, 10, 23, 9, 18)),
        part(armor, poly(12, 16, 20, 16, 21, 23, 11, 23, 11, 18)),
        part(armor_light, rect(13, 17, 20, 18), rect(12, 20, 20, 20)),
        part(brass, rect(13, 19, 14, 19), rect(17, 19, 18, 19), rect(14, 21, 15, 21), rect(18, 21, 19, 21)),
        part(red, rect(10, 22, 22, 23)),
        part(red_light, rect(12, 22, 20, 22)),
    ]
    parts += common_head(skin=skin, skin_shadow=skin_shadow, hair=hair)
    parts += [
        # Headband wraps cleanly when the sprite is mirrored in-engine.
        part(red, rect(11, 7, 22, 8), poly(11, 8, 8, 10, 11, 10)),
        part(red_light, rect(14, 7, 21, 7)),
    ]
    return render(parts)


def archer(phase: int | None) -> Image.Image:
    skin = (226, 174, 124, 255)
    skin_shadow = (184, 115, 76, 255)
    hair = (50, 36, 31, 255)
    green = (76, 105, 68, 255)
    green_light = (104, 132, 78, 255)
    green_dark = (45, 68, 51, 255)
    leather = (116, 67, 41, 255)
    leather_light = (166, 105, 55, 255)
    straw = (211, 166, 74, 255)
    straw_light = (235, 202, 107, 255)
    straw_dark = (151, 105, 47, 255)

    parts = legs_for(phase, cloth=green, shadow=green_dark, shoe=hair)
    parts += arms_for(phase, sleeve=green_light, sleeve_shadow=green_dark, skin=skin)
    parts += [
        part(green_dark, poly(11, 16, 20, 15, 22, 18, 21, 23, 11, 23, 10, 18)),
        part(green, poly(12, 16, 20, 16, 21, 23, 11, 23, 11, 18)),
        part(green_light, poly(14, 16, 19, 16, 20, 19, 13, 19)),
        # Mirroring-safe diagonal leather harness and quiver belt.
        part(leather, poly(13, 16, 15, 16, 20, 22, 18, 22), rect(10, 21, 22, 22)),
        part(leather_light, rect(12, 21, 20, 21)),
        part(straw_dark, rect(20, 22, 22, 24)),
        part(straw, rect(21, 22, 22, 23)),
    ]
    parts += common_head(skin=skin, skin_shadow=skin_shadow, hair=hair)
    parts += [
        # Paeraengi: low crown and a wide, angular straw brim.
        part(straw_dark, poly(12, 4, 19, 4, 21, 7, 23, 7, 25, 9, 8, 9, 10, 7, 12, 7)),
        part(straw, poly(13, 4, 18, 4, 20, 7, 11, 7)),
        part(straw_light, rect(13, 4, 18, 4), rect(10, 7, 22, 7)),
        part(leather, rect(13, 8, 21, 8)),
    ]
    return render(parts)


BUILDERS = {"Taoist": taoist, "Warrior": warrior, "Archer": archer}


def upscale(logical: Image.Image) -> Image.Image:
    return logical.resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.NEAREST)


def validate_frame(name: str, frame: Image.Image) -> None:
    assert frame.mode == "RGBA" and frame.size == (LOGICAL_SIZE, LOGICAL_SIZE)
    alpha_values = set(frame.getchannel("A").get_flattened_data())
    assert alpha_values <= {0, 255}, f"{name}: non-binary alpha {alpha_values}"
    assert frame.getbbox(), f"{name}: empty frame"
    palette = Counter(frame.get_flattened_data())
    opaque_colors = {color for color in palette if color[3]}
    assert 6 <= len(opaque_colors) <= 16, f"{name}: unexpected palette size {len(opaque_colors)}"


def validate_export(name: str, image: Image.Image, frames: int) -> None:
    assert image.mode == "RGBA"
    assert image.size == (FRAME_SIZE * frames, FRAME_SIZE)
    px = image.load()
    for y in range(0, image.height, SCALE):
        for x in range(0, image.width, SCALE):
            expected = px[x, y]
            for by in range(y, y + SCALE):
                for bx in range(x, x + SCALE):
                    assert px[bx, by] == expected, f"{name}: off-grid pixel at {bx},{by}"


def main() -> None:
    for character, builder in BUILDERS.items():
        logical_idle = builder(None)
        logical_walk = [builder(phase) for phase in range(4)]
        validate_frame(f"{character}/idle", logical_idle)
        for index, frame in enumerate(logical_walk):
            validate_frame(f"{character}/walk[{index}]", frame)

        # The head and central torso remain byte-identical across all walk frames.
        stable_crop = (12, 4, 21, 22)
        stable = logical_walk[0].crop(stable_crop)
        assert all(frame.crop(stable_crop).tobytes() == stable.tobytes() for frame in logical_walk[1:])
        assert len({frame.tobytes() for frame in logical_walk}) == 4

        exported_idle = upscale(logical_idle)
        exported_walk = Image.new("RGBA", (FRAME_SIZE * 4, FRAME_SIZE), TRANSPARENT)
        for index, frame in enumerate(logical_walk):
            exported_walk.paste(upscale(frame), (index * FRAME_SIZE, 0))

        validate_export(f"{character}/idle.png", exported_idle, 1)
        validate_export(f"{character}/walk.png", exported_walk, 4)

        destination = ROOT / "asset" / "character" / character / "side"
        destination.mkdir(parents=True, exist_ok=True)
        exported_idle.save(destination / "idle.png", optimize=True)
        exported_walk.save(destination / "walk.png", optimize=True)

        bbox = logical_idle.getchannel("A").getbbox()
        colors = len(set(logical_idle.get_flattened_data())) - 1
        print(f"{character}: logical bbox={bbox}, idle colors={colors}")


if __name__ == "__main__":
    main()
