"""Build the 그슨대 sprite set from the owner's drop (N9-75).

Source: ``new_asset/owner/monster/그슨대 스프라이트.png`` — an 8-frame walk
cycle laid out 4x2. The game wants HORIZONTAL strips of square frames
(``SpriteSheet`` derives the frame count as width / height), so the grid is
re-laid as a strip here rather than by hand.

Scale: every character sheet in this project is authored at 16x its logical
size, and ``Enemy`` divides by that constant when it draws. The owner's frames
are 113px tall, which is neither the logical size nor a whole multiple of it,
so the pipeline is the one ``asset/characters/taoist/build_assets.py`` already
uses: premultiplied BOX reduction down to the logical size, then NEAREST back
up to 16x. Reducing first keeps the soft edges of the source from turning into
ragged fringes; NEAREST on the way up keeps the result crisp.

40 logical px sits between the 도깨비 (32) and the 죽림 거한 (48), which is
where a 13px-radius monster belongs.

Run: python asset/monsters/geuseundae/build_assets.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "new_asset" / "owner" / "monster" / "그슨대 스프라이트.png"
OUT_DIR = ROOT / "asset" / "monsters" / "geuseundae"

COLUMNS = 4
ROWS = 2
LOGICAL_PX = 40
EXPORT_SCALE = 16
FRAME_PX = LOGICAL_PX * EXPORT_SCALE
# Breathing room under the feet so the figure is not welded to the frame edge;
# the shadow's ground pool needs a little of it.
FOOT_MARGIN_PX = 2


def frame_boxes(image: Image.Image) -> list[tuple[int, int, int, int]]:
    """One box per frame, read from the sheet rather than assumed.

    The two rows do not share a vertical offset in the source, so each row's
    content is located by its own alpha bounds. Assuming a uniform grid would
    slice the feet off one of them.
    """
    width, height = image.size
    cell_w = width // COLUMNS
    cell_h = height // ROWS
    boxes: list[tuple[int, int, int, int]] = []
    for row in range(ROWS):
        strip = image.crop((0, row * cell_h, width, (row + 1) * cell_h))
        bounds = strip.split()[3].getbbox()
        if bounds is None:
            raise ValueError(f"row {row} of the sheet is empty")
        top = row * cell_h + bounds[1]
        bottom = row * cell_h + bounds[3]
        for column in range(COLUMNS):
            boxes.append((column * cell_w, top, (column + 1) * cell_w, bottom))
    return boxes


def square_frame(source: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    """Crops one frame onto a square canvas with the feet on the bottom edge.

    The full column width is kept rather than the figure's own bounds: the sway
    of a walk cycle lives in how far the body drifts inside its cell, and
    re-centring every frame on its own silhouette would iron that out.
    """
    cut = source.crop(box)
    side = max(cut.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(cut, ((side - cut.size[0]) // 2, side - cut.size[1] - FOOT_MARGIN_PX))
    return canvas


def to_logical(frame: Image.Image) -> Image.Image:
    """BOX down to the logical size on premultiplied alpha, then NEAREST up.

    Reducing straight RGBA drags the transparent pixels' colour into the edge
    and leaves a dark halo, which on a monster that is already dark reads as a
    smear rather than an outline.
    """
    premultiplied = Image.new("RGBA", frame.size)
    pixels = frame.load()
    out = premultiplied.load()
    for y in range(frame.size[1]):
        for x in range(frame.size[0]):
            r, g, b, a = pixels[x, y]
            out[x, y] = (r * a // 255, g * a // 255, b * a // 255, a)
    small = premultiplied.resize((LOGICAL_PX, LOGICAL_PX), Image.BOX)
    restored = Image.new("RGBA", small.size)
    src = small.load()
    dst = restored.load()
    for y in range(small.size[1]):
        for x in range(small.size[0]):
            r, g, b, a = src[x, y]
            if a == 0:
                dst[x, y] = (0, 0, 0, 0)
            else:
                dst[x, y] = (
                    min(255, r * 255 // a), min(255, g * 255 // a),
                    min(255, b * 255 // a), a,
                )
    return restored.resize((FRAME_PX, FRAME_PX), Image.NEAREST)


def standing_index(frames: list[Image.Image]) -> int:
    """The frame that reads as standing: the narrowest stance in the cycle.

    Same rule as the taoist's idle pose (N9-64) — a walk frame caught
    mid-stride reads as walking on the spot, and the legs-together frame is
    what the eye accepts as still.
    """
    best = 0
    best_width = 10 ** 9
    for index, frame in enumerate(frames):
        legs = frame.crop((0, int(frame.size[1] * 0.72), frame.size[0], frame.size[1]))
        bounds = legs.split()[3].getbbox()
        width = (bounds[2] - bounds[0]) if bounds else 10 ** 9
        if width < best_width:
            best_width = width
            best = index
    return best


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"source sheet missing: {SOURCE}")
    sheet = Image.open(SOURCE).convert("RGBA")
    frames = [to_logical(square_frame(sheet, box)) for box in frame_boxes(sheet)]

    walk = Image.new("RGBA", (FRAME_PX * len(frames), FRAME_PX), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        walk.paste(frame, (index * FRAME_PX, 0))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    walk.save(OUT_DIR / "walk.png")

    idle_index = standing_index(frames)
    frames[idle_index].save(OUT_DIR / "idle.png")
    print(f"walk.png {walk.size} ({len(frames)} frames), idle from frame {idle_index}")


if __name__ == "__main__":
    main()
