"""Build the night-two idle sheets from the Higgsfield renders.

The renders arrive as 1024px pictures on a magenta backdrop, which is neither
transparent nor on the pixel grid. This keys the backdrop out and then hands the
frame to the pipeline ``build_owner_sheets`` established for the owner's own
drops: reduce on premultiplied alpha to the logical size, blow it back up by
``EXPORT_SCALE`` with NEAREST. A render dropped straight in would sit on a
fractional display scale and smear.

The colour is flattened to a small palette on the way through: the anchors are
cel-shaded, and a render's smooth ramps read as mush once the sprite is 32px on
screen.

Run: python asset/monsters/build_night2_sheets.py
"""

from pathlib import Path

from PIL import Image

from build_owner_sheets import to_logical

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "new_asset" / "generated" / "night2"
OUT_ROOT = ROOT / "asset" / "monsters"

# The prompt asks for a magenta backdrop because it is the one hue none of these
# creatures wear, so keying it costs no pixel of the figure.
KEY_COLOR = (255, 0, 255)
KEY_DISTANCE = 120
KEY_FRINGE = 60
# Same reason as the owner sheets: the figure must not be welded to the frame edge.
FOOT_MARGIN_PX = 1
# The anchors carry 3-6k colours across a whole canvas; at these sizes that is
# what "flat cel" comes out as, and it keeps every ramp the render actually uses.
PALETTE_SIZE = 48

# (source stem, output folder, logical px, drawn px)
#
# `drawn px` keeps the on-screen size hierarchy the bestiary depends on:
# goblin 30 < hound/wraith/dokkaebi 31 < player 38 < rusted armour 50 << boss 86.
MONSTERS = [
    ("ash_wraith", "ash_wraith", 32, 31),
    ("cursed_hound", "cursed_hound", 32, 27),
    ("powder_dokkaebi", "powder_dokkaebi", 32, 31),
    ("rusted_armor", "rusted_armor", 52, 50),
    ("general_wraith", "general_wraith", 88, 86),
]


def key_out(image: Image.Image) -> Image.Image:
    """Replace the magenta backdrop with transparency."""
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, _ = pixels[x, y]
            distance = abs(r - KEY_COLOR[0]) + abs(g - KEY_COLOR[1]) + abs(b - KEY_COLOR[2])
            if distance < KEY_DISTANCE:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def square_frame(figure: Image.Image, logical_px: int, drawn_px: int) -> Image.Image:
    """Centre the figure on a square sized so it lands at `drawn_px` after reduction."""
    bounds = figure.getbbox()
    if bounds is None:
        raise ValueError("nothing left after keying")
    cut = figure.crop(bounds)
    side = max(round(cut.size[1] * logical_px / drawn_px), *cut.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    margin = round(FOOT_MARGIN_PX * side / logical_px)
    canvas.paste(cut, ((side - cut.size[0]) // 2, side - cut.size[1] - margin))
    return canvas


def flatten(sheet: Image.Image) -> Image.Image:
    """Hard alpha and a small palette — the grid must stay one colour per cell."""
    pixels = sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            r, g, b, a = pixels[x, y]
            # Reduction blends the backdrop into the outline, and what survives
            # is magenta enough to read as pink confetti around the silhouette.
            # Nothing these creatures wear is this far off its green channel.
            if min(r, b) - g > KEY_FRINGE:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            pixels[x, y] = (r, g, b, 255 if a >= 128 else 0)
    alpha = sheet.getchannel("A")
    flat = sheet.convert("RGB").quantize(
        colors=PALETTE_SIZE, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    ).convert("RGBA")
    flat.putalpha(alpha)
    return flat


def build(source_stem: str, out_name: str, logical_px: int, drawn_px: int) -> None:
    source = SOURCE_DIR / f"{source_stem}.png"
    if not source.exists():
        print(f"  {out_name}: source missing, skipped ({source.name})")
        return
    figure = key_out(Image.open(source))
    sheet = flatten(to_logical(square_frame(figure, logical_px, drawn_px), logical_px))
    out_dir = OUT_ROOT / out_name
    out_dir.mkdir(parents=True, exist_ok=True)
    sheet.save(out_dir / "idle.png")
    logical = sheet.resize((logical_px, logical_px), Image.NEAREST)
    opaque = {p for p in logical.get_flattened_data() if p[3] > 0}
    drawn = len({
        y for y in range(logical_px) for x in range(logical_px)
        if logical.getpixel((x, y))[3] > 0
    })
    print(f"  {out_name}: {logical_px}px frame, drawn {drawn}px, {len(opaque)} colours")


def main() -> None:
    print("night-2 idle sheets")
    for entry in MONSTERS:
        build(*entry)


if __name__ == "__main__":
    main()
