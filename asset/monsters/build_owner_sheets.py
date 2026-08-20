"""Build monster sprite sets from the owner's drops in new_asset/owner/monster.

The owner authors one PNG per monster: an 8-frame walk cycle laid out 4x2. The
game wants a HORIZONTAL strip of SQUARE frames (``SpriteSheet`` derives the
frame count as width / height), so the grid is re-laid here rather than by hand.

This is the pipeline ``asset/characters/taoist/build_assets.py`` established and
``asset/monsters/geuseundae/build_assets.py`` repeated for one monster; four
more monsters is where copying it again stops being cheaper than a table. Every
number that differs per monster lives in ``MONSTERS`` and nothing else does.

Scale: every character sheet in this project is authored at 16x its logical size
and ``Enemy`` divides by that constant when it draws. The owner's cells are
neither the logical size nor a whole multiple of it, so each frame is reduced on
PREMULTIPLIED alpha down to the logical size and then blown back up with
NEAREST. Reducing straight RGBA drags the transparent pixels' colour into the
edge and leaves a dark halo, which on these dark creatures reads as a smear
rather than an outline; NEAREST on the way up keeps the result crisp.

Run: python asset/monsters/build_owner_sheets.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "new_asset" / "owner" / "monster"
OUT_ROOT = ROOT / "asset" / "monsters"

EXPORT_SCALE = 16
# Breathing room under the feet so the figure is not welded to the frame edge;
# the shadow's ground pool needs a little of it.
FOOT_MARGIN_PX = 2

# (source file, output folder, logical px, drawn px, columns, rows, breathes)
#
# `logical px` is the frame size data/monsters.json draws at. `drawn px` is how
# tall the FIGURE stands inside that frame, and it is a design number, not an
# art accident: the on-screen hierarchy goblin < spirit < player(38) < brute <<
# boss is what tells the player what can hurt them, and tests/unit/
# test_enemy_sprite.gd asserts it. Letting a new drawing fill its frame edge to
# edge silently made the goblin 32 tall against the taoist's 38 and put the
# spirit BELOW the goblin — which is why the figure is scaled to this number
# rather than to whatever the source happened to be.
MONSTERS = [
    ("도깨비 스프라이트.png", "forest_goblin", 32, 27, 4, 2, False),
    ("숲 정령 스프라이트.png", "forest_spirit", 32, 29, 4, 2, False),
    ("죽림 거한 스프라이트.png", "bamboo_brute", 48, 45, 4, 2, False),
    ("두두리 스프라이트.png", "dudueori", 96, 84, 4, 2, True),
]


def frame_boxes(image: Image.Image, columns: int, rows: int) -> list[tuple[int, int, int, int]]:
    """One box per frame, read from the sheet rather than assumed.

    The rows do not share a vertical offset in the source, so each row's content
    is located by its own alpha bounds. Assuming a uniform grid slices the feet
    off whichever row sits lower.
    """
    width, height = image.size
    cell_w = width // columns
    cell_h = height // rows
    boxes: list[tuple[int, int, int, int]] = []
    for row in range(rows):
        band = image.crop((0, row * cell_h, width, (row + 1) * cell_h))
        bounds = band.split()[3].getbbox()
        if bounds is None:
            raise ValueError(f"row {row} of the sheet is empty")
        top = row * cell_h + bounds[1]
        bottom = row * cell_h + bounds[3]
        for column in range(columns):
            boxes.append((column * cell_w, top, (column + 1) * cell_w, bottom))
    return boxes


def square_frame(
    source: Image.Image, box: tuple[int, int, int, int],
    logical_px: int, drawn_px: int
) -> Image.Image:
    """Crops one frame onto a square canvas sized so the figure lands at `drawn_px`.

    The canvas is deliberately BIGGER than the figure. Reducing the whole square
    to `logical_px` later scales the figure by the same factor, so making the
    square `logical_px / drawn_px` times the figure's height is what puts the
    figure at exactly `drawn_px` in the finished frame. Filling the square with
    the figure instead is what broke the size hierarchy.

    The full column width is kept rather than the figure's own bounds: the sway
    of a walk cycle lives in how far the body drifts inside its cell, and
    re-centring every frame on its own silhouette would iron that out. `box`
    already carries the row's shared vertical bounds for the same reason —
    per-frame vertical bounds would make the creature bob.
    """
    cut = source.crop(box)
    side = max(round(cut.size[1] * logical_px / drawn_px), *cut.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    # Feet near the bottom edge, with the frame's own margin scaled up to this
    # canvas so it survives the reduction as the same fraction of the frame.
    margin = round(FOOT_MARGIN_PX * side / logical_px)
    canvas.paste(cut, ((side - cut.size[0]) // 2, side - cut.size[1] - margin))
    return canvas


def to_logical(frame: Image.Image, logical_px: int) -> Image.Image:
    """BOX down to the logical size on premultiplied alpha, then NEAREST up."""
    premultiplied = Image.new("RGBA", frame.size)
    pixels = frame.load()
    out = premultiplied.load()
    for y in range(frame.size[1]):
        for x in range(frame.size[0]):
            r, g, b, a = pixels[x, y]
            out[x, y] = (r * a // 255, g * a // 255, b * a // 255, a)
    small = premultiplied.resize((logical_px, logical_px), Image.BOX)
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
    frame_px = logical_px * EXPORT_SCALE
    return restored.resize((frame_px, frame_px), Image.NEAREST)


def standing_index(frames: list[Image.Image]) -> int:
    """The frame that reads as standing: the narrowest stance in the cycle.

    Same rule as the taoist's idle pose (N9-64) — a walk frame caught mid-stride
    reads as walking on the spot, and the legs-together frame is what the eye
    accepts as still. A legless creature has no stance to measure, but its
    silhouette barely changes either, so the answer is harmless.
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


def strip(frames: list[Image.Image]) -> Image.Image:
    side = frames[0].size[0]
    out = Image.new("RGBA", (side * len(frames), side), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        out.paste(frame, (index * side, 0))
    return out


def build(source_name: str, out_name: str, logical_px: int, drawn_px: int,
          columns: int, rows: int, breathes: bool) -> None:
    source = SOURCE_DIR / source_name
    if not source.exists():
        print(f"  {out_name}: source missing, skipped ({source_name})")
        return
    sheet = Image.open(source).convert("RGBA")
    frames = [
        to_logical(square_frame(sheet, box, logical_px, drawn_px), logical_px)
        for box in frame_boxes(sheet, columns, rows)
    ]
    out_dir = OUT_ROOT / out_name
    out_dir.mkdir(parents=True, exist_ok=True)
    walk = strip(frames)
    walk.save(out_dir / "walk.png")

    idle_index = standing_index(frames)
    frames[idle_index].save(out_dir / "idle.png")
    note = ""
    if breathes:
        # The boss plays a two-frame idle when it is not walking (see Enemy).
        # Built from the walk's calmest neighbouring frames so the breathing
        # reads as the same creature rather than a second drawing of it.
        neighbour = (idle_index + 1) % len(frames)
        strip([frames[idle_index], frames[neighbour]]).save(out_dir / "idle_breathe.png")
        note = f", breathe from {idle_index}+{neighbour}"
    # Report what the figure ACTUALLY came out at: the design target is the aim,
    # and rounding on the way down can land a pixel off. The test asserts the
    # measured value, so a silent miss here would surface there instead.
    used = frames[idle_index].split()[3].getbbox()
    measured = (used[3] - used[1]) / EXPORT_SCALE if used else 0.0
    half_width = (used[2] - used[0]) / EXPORT_SCALE / 2.0 if used else 0.0
    print(
        f"  {out_name}: walk {walk.size} ({len(frames)} frames), "
        f"idle from frame {idle_index}{note}, "
        f"drawn {measured:g}px (target {drawn_px}), half-width {half_width:g}px"
    )


def main() -> None:
    if not SOURCE_DIR.is_dir():
        raise SystemExit(f"drop folder missing: {SOURCE_DIR}")
    for entry in MONSTERS:
        build(*entry)


if __name__ == "__main__":
    main()
