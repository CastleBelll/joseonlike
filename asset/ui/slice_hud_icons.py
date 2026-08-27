"""Cut the owner's HUD icon sheet into named icons.

The owner drew the six HUD glyphs on one sheet — coin, skull, hourglass, info,
pause, gear — on a clean 3x2 grid of 512px cells. Unlike the chrome kit this one
IS a grid, so the cells are taken as declared and only the drawing inside each
is found by its own alpha. Guessing a grid is what cut subjects in half on every
earlier sheet; declaring one that is actually there is not the same gamble.

Output matches the existing HUD icons: 256px square, which the HUD draws at 32
(16 logical px at the project's x16 export scale).

`hud_all.png` is an owner drop and no tool may write to it — an earlier bake
saved over the drops it read and cost the owner a re-download of every sheet.
Everything lands in `hud/build/`.

Run: python asset/ui/slice_hud_icons.py [--dry-run]
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "asset" / "ui" / "hud" / "hud_all.png"
OUT = ROOT / "asset" / "ui" / "hud" / "build"

COLUMNS = 3
ROWS = 2
ALPHA_FLOOR = 24
## Match the existing hud icons so display sizes and call sites are unchanged.
EXPORT_PX = 256
## Reading order, left to right then top to bottom.
NAMES = [
    "coin", "skull", "timer",
    "info", "pause", "settings",
]


def cell_bbox(alpha):
    """Tight bounds of the drawing inside one cell, or None when it is empty."""
    lit = alpha > ALPHA_FLOOR
    rows = np.where(lit.any(axis=1))[0]
    cols = np.where(lit.any(axis=0))[0]
    if not len(rows) or not len(cols):
        return None
    return cols[0], rows[0], cols[-1] + 1, rows[-1] + 1


def square(image):
    """Centre the drawing on a transparent square so nothing is stretched.

    Icons sit beside each other in the HUD, and a glyph resized from a
    non-square crop comes out wider or taller than its neighbours even though
    every file is the same size.
    """
    side = max(image.width, image.height)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(image, ((side - image.width) // 2, (side - image.height) // 2))
    return canvas


def main():
    dry_run = "--dry-run" in sys.argv
    if not SHEET.exists():
        raise SystemExit(f"sheet not found: {SHEET}")
    sheet = Image.open(SHEET).convert("RGBA")
    if sheet.width % COLUMNS or sheet.height % ROWS:
        raise SystemExit(
            f"{sheet.width}x{sheet.height} is not a whole {COLUMNS}x{ROWS} grid"
        )
    cell_w = sheet.width // COLUMNS
    cell_h = sheet.height // ROWS
    alpha = np.array(sheet.getchannel("A"))
    if not dry_run:
        OUT.mkdir(parents=True, exist_ok=True)
    written = 0
    for index, name in enumerate(NAMES):
        col, row = index % COLUMNS, index // COLUMNS
        x0, y0 = col * cell_w, row * cell_h
        box = cell_bbox(alpha[y0:y0 + cell_h, x0:x0 + cell_w])
        if box is None:
            raise SystemExit(f"cell {row},{col} ({name}) is empty — grid is wrong")
        left, top, right, bottom = box
        crop = sheet.crop((x0 + left, y0 + top, x0 + right, y0 + bottom))
        icon = square(crop).resize((EXPORT_PX, EXPORT_PX), Image.LANCZOS)
        print(f"  {name:10}{right - left}x{bottom - top} -> {EXPORT_PX}")
        if not dry_run:
            out_path = OUT / f"{name}.png"
            if out_path.resolve() == SHEET.resolve():
                raise SystemExit("refusing to write onto the owner's sheet")
            icon.save(out_path)
        written += 1
    print(f"{written} icons -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
