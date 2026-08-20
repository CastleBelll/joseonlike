"""Cut the owner's taoist walk sheet into the engine's strip format.

Source: new_asset/owner/taoist_walk.png — eight background-free frames laid out 4x2.
Output: asset/characters/taoist/walk.png — one horizontal strip of square
frames at the 16x NEAREST export scale SpriteSheet expects (it reads the frame
count as width / height, so the strip must stay exactly square-per-frame).

Two things matter more than the cutting itself:

* The figures are NOT on an even grid. Measured content runs sit at x=51, 183,
  317, 449 with widths 93-94, a pitch near 132.7 — splitting the 612px sheet
  into four equal 153px cells slices the last figure in half. Slots are taken
  from the measured runs, not assumed.
* Every frame is cut with the SAME window size and anchor. Cropping each frame
  to its own bounding box would silently flatten the walk's bob and arm swing,
  which is the entire point of the animation.

Run: python asset/characters/taoist/build_walk.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "new_asset" / "owner" / "taoist_walk.png"
TARGET = ROOT / "asset" / "characters" / "taoist" / "walk.png"
REFERENCE = ROOT / "asset" / "characters" / "taoist" / "idle.png"

# asset/characters/taoist/README.md: PNGs are exact 16x nearest blocks of the
# logical frame, downscaled in-engine by sprite scale.
EXPORT_SCALE = 16
LOGICAL_SIDE = 40  # matches the shipped idle.png (640 / 16)
ALPHA_FLOOR = 8
# Chroma-key residue from the owner's background removal: 7,665 pixels where
# green dominates both other channels, most of them semi-transparent edge
# pixels like (0, 140, 0) at alpha 126. Confirmed as residue, not art — the
# taoist palette has no green at all (38 of 60,338 opaque pixels), so these
# only ever appear as a fringe around the silhouette.
KEY_DOMINANCE = 40


def runs(flags):
    """Start/end index pairs for each contiguous True run."""
    out, start = [], None
    for i, on in enumerate(flags):
        if on and start is None:
            start = i
        elif not on and start is not None:
            out.append((start, i - 1))
            start = None
    if start is not None:
        out.append((start, len(flags) - 1))
    return out


def strip_chroma(image):
    """Clear the green fringe left by the background removal."""
    px = image.load()
    w, h = image.size
    cleared = 0
    for y in range(h):
        for x in range(w):
            r, g, bl, a = px[x, y]
            if a > 0 and g > r + KEY_DOMINANCE and g > bl + KEY_DOMINANCE:
                px[x, y] = (r, g, bl, 0)
                cleared += 1
    return cleared


def content_runs(image):
    px = image.load()
    w, h = image.size
    cols = [any(px[x, y][3] > ALPHA_FLOOR for y in range(h)) for x in range(w)]
    rows = [any(px[x, y][3] > ALPHA_FLOOR for x in range(w)) for y in range(h)]
    return runs(cols), runs(rows)


def main():
    sheet = Image.open(SOURCE).convert("RGBA")
    cleared = strip_chroma(sheet)
    col_runs, row_runs = content_runs(sheet)
    if len(row_runs) != 2 or len(col_runs) != 4:
        raise SystemExit(
            f"expected a 4x2 layout, measured {len(col_runs)} columns "
            f"and {len(row_runs)} rows"
        )

    # One window size for every frame, so relative motion survives the cut.
    win_w = max(end - start + 1 for start, end in col_runs)
    win_h = max(end - start + 1 for start, end in row_runs)

    frames = []
    for row_start, _row_end in row_runs:
        for col_start, _col_end in col_runs:
            frames.append(
                sheet.crop(
                    (col_start, row_start, col_start + win_w, row_start + win_h)
                )
            )

    # Fit the window into the logical frame, then block-scale. Feet sit on the
    # bottom edge and the figure is centred horizontally, matching idle.png.
    fit = min(LOGICAL_SIDE / win_w, LOGICAL_SIDE / win_h)
    draw_w = max(1, round(win_w * fit))
    draw_h = max(1, round(win_h * fit))
    side = LOGICAL_SIDE * EXPORT_SCALE

    strip = Image.new("RGBA", (side * len(frames), side), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        small = frame.resize((draw_w, draw_h), Image.NEAREST)
        big = small.resize(
            (draw_w * EXPORT_SCALE, draw_h * EXPORT_SCALE), Image.NEAREST
        )
        x = index * side + (side - big.width) // 2
        y = side - big.height
        strip.alpha_composite(big, (x, y))

    strip.save(TARGET)
    reference = Image.open(REFERENCE)
    print(f"wrote {TARGET.relative_to(ROOT)} {strip.size} ({len(frames)} frames)")
    print(f"frame side {side}px, reference idle {reference.size}")
    print(f"cleared {cleared} chroma-fringe pixels")


if __name__ == "__main__":
    main()
