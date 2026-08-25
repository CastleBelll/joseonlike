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

from build_owner_sheets import EXPORT_SCALE, to_logical

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "new_asset" / "generated" / "night2"
OUT_ROOT = ROOT / "asset" / "monsters"

# The backdrop the prompt asks for, with room for the render's own shading of
# it: both ends of the spectrum high, the middle low.
KEY_MIN_MAGENTA = 130
KEY_MAX_GREEN = 110
# Same reason as the owner sheets: the figure must not be welded to the frame edge.
FOOT_MARGIN_PX = 1
# The anchors carry 3-6k colours across a whole canvas; at these sizes that is
# what "flat cel" comes out as, and it keeps every ramp the render actually uses.
PALETTE_SIZE = 224

# (source stem, output folder, logical px, drawn px, detail px)
#
# `drawn px` keeps the on-screen size hierarchy the bestiary depends on:
# goblin 30 < hound/wraith/dokkaebi 31 < player 38 < rusted armour 50 << boss 86.
#
# `detail px` is how many canvas pixels one drawn pixel spans, and it is what
# makes these sit at the bamboo forest's resolution rather than three times
# coarser. The owner's sheets are NOT one flat block per logical pixel: measured
# on the shipped art the smallest uniform run is 5 canvas px on the goblin, 7 on
# the brute, 10 on the boss — the drawing carries roughly three times the
# logical grid and the reduction to screen is what smooths it. Snapping to 16
# threw exactly that away.
MONSTERS = [
    ("ash_wraith", "ash_wraith", 32, 31, 5),
    ("cursed_hound", "cursed_hound", 32, 27, 5),
    ("powder_dokkaebi", "powder_dokkaebi", 32, 31, 5),
    ("rusted_armor", "rusted_armor", 52, 50, 7),
    ("general_wraith", "general_wraith", 88, 86, 10),
]


def key_out(image: Image.Image) -> Image.Image:
    """Drop the whole magenta family, on the render, before anything reduces it.

    Two earlier attempts failed here and both failed the same way. Matching one
    exact key colour leaves the backdrop's darker edge pixels behind, and the
    reduction smears them into the outline as pink confetti; cutting that
    confetti afterwards eats real edge pixels and the figure comes out short.
    The render's own edges are hard, so removing the backdrop BEFORE the
    reduction leaves nothing to smear. Nothing these creatures wear is a
    saturated magenta.
    """
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, _ = pixels[x, y]
            if r > KEY_MIN_MAGENTA and b > KEY_MIN_MAGENTA and g < KEY_MAX_GREEN:
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
            pixels[x, y] = (r, g, b, 255 if a >= 128 else 0)
    alpha = sheet.getchannel("A")
    flat = sheet.convert("RGB").quantize(
        colors=PALETTE_SIZE, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    ).convert("RGBA")
    flat.putalpha(alpha)
    return flat


def to_canvas(frame: Image.Image, logical_px: int, detail_px: int) -> Image.Image:
    """Reduce to the drawing's own pixels, then step up to the sheet canvas.

    ``build_owner_sheets.to_logical`` reduces all the way to ``logical_px``,
    which is right for art already drawn at that grid. These renders are not,
    and snapping them there is what left the night at a third of the bamboo
    forest's resolution. The reduction stops at ``canvas / detail_px`` instead,
    so one drawn pixel spans the same handful of canvas pixels the owner's own
    sheets carry.
    """
    canvas_px = logical_px * EXPORT_SCALE
    art_px = max(1, round(canvas_px / detail_px))
    small = to_logical(frame, art_px).resize((art_px, art_px), Image.NEAREST)
    return small.resize((canvas_px, canvas_px), Image.NEAREST)


def smallest_run(sheet: Image.Image) -> int:
    """Canvas pixels in the shortest uniform run — the drawing's pixel size."""
    pixels = sheet.load()
    shortest = sheet.width
    for y in range(0, sheet.height, max(1, sheet.height // 12)):
        x = 0
        while x < sheet.width:
            colour = pixels[x, y]
            run = 1
            while x + run < sheet.width and pixels[x + run, y] == colour:
                run += 1
            if colour[3] > 0:
                shortest = min(shortest, run)
            x += run
    return shortest


def build(source_stem: str, out_name: str, logical_px: int, drawn_px: int,
          detail_px: int) -> None:
    source = SOURCE_DIR / f"{source_stem}.png"
    if not source.exists():
        print(f"  {out_name}: source missing, skipped ({source.name})")
        return
    figure = key_out(Image.open(source))
    sheet = flatten(to_canvas(square_frame(figure, logical_px, drawn_px), logical_px, detail_px))
    out_dir = OUT_ROOT / out_name
    out_dir.mkdir(parents=True, exist_ok=True)
    sheet.save(out_dir / "idle.png")
    opaque = {p for p in sheet.get_flattened_data() if p[3] > 0}
    drawn = round(sheet.getbbox()[3] - sheet.getbbox()[1]) / EXPORT_SCALE
    print(
        f"  {out_name}: {logical_px}px frame, drawn {drawn:.1f}px, "
        f"{len(opaque)} colours, pixel {smallest_run(sheet)}px"
    )


def main() -> None:
    print("night-2 idle sheets")
    for entry in MONSTERS:
        build(*entry)


if __name__ == "__main__":
    main()
