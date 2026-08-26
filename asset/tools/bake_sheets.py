"""Bake the owner's 4x4 contact sheets into the strips the engine reads.

`SpriteSheet` counts frames as width / height and wants square frames in one
row, so a 1254x1254 grid sheet is read as a SINGLE frame and the animation
silently becomes a still image. This turns each grid into that strip.

Three things happen per sheet, and each exists because of something measured:

1. **Grid, declared.** The generator does not lay cells on width/N — pitches
   run 201-224 where the nominal is 209 — and sheets whose figures touch hide
   the gap a detector looks for. The grid is stated per sheet, never guessed.

2. **Foot alignment.** The generator lays its four ROWS at slightly different
   heights (measured: row 1 at 313, rows 2-3 at 312, row 4 at 304). Inside a
   row the feet are perfect. Aligning every frame on one baseline removes that
   step, which would otherwise make the character jump once per cycle.

3. **Logical size.** On-screen height is the sprite's opaque height divided by
   SpriteSheet.EXPORT_SCALE (16). The new art is drawn at native 1:1 — about
   289 px tall — so dropping it in as-is would render the taoist at 18 px
   where the game has always drawn him at 38. Each entry declares the logical
   height it must keep, and the bake scales to hit it. Nothing downstream —
   collision radius, the drawn-height hierarchy, balance — has to move.

No retouching. An earlier cutter erased burned-in frame numbers by hunting
near-white pixels; eye highlights are near-white too, and it took the
characters' eyes with the numbers.

Run: python asset/tools/bake_sheets.py [--dry-run]
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
KEEP = ROOT / "new_asset" / "source" / "sheets"
EXPORT_SCALE = 16          # SpriteSheet.EXPORT_SCALE
FRAME_PAD = 0.06           # empty margin kept around the figure, per side


class Sheet:
    """One animation to bake.

    `logical_h` is the on-screen height in pixels the result must keep. It is
    read off the contract the tests already pin, not chosen here.
    """

    def __init__(self, source, out, grid, logical_h, note="", share_scale=True):
        self.source = ROOT / source
        self.out = ROOT / out
        self.grid = grid          # (rows, cols); None for a single-frame image
        self.logical_h = logical_h
        self.note = note
        # Share the actor's factor when this sheet was drawn at the same scale
        # as the reference — that is what keeps a run shorter than a stand.
        # Set False when the source was drawn at its own scale: the ash wraith's
        # idle is a single showcase drawing 3.5x the size of its walk cells, and
        # sharing a factor rendered the walking wraith at 9 logical px.
        self.share_scale = share_scale


## One actor, one scale. The FIRST sheet is the reference: its tallest frame
## becomes `logical_h`, and every other sheet of that actor is scaled by the
## same factor. Scaling each sheet to its own height would make the character
## change size between standing and running — a run's crouch is supposed to be
## shorter than a stand, and that difference has to survive the bake.
ACTORS = [
    ("taoist", 38.0, [
        Sheet("asset/characters/taoist/breath.png", "asset/characters/taoist/idle.png",
              (4, 4), 38.0, "breath becomes the idle animation"),
        Sheet("asset/characters/taoist/walk.png", "asset/characters/taoist/walk.png",
              (4, 4), 38.0),
    ]),
    ("warrior", 38.0, [
        Sheet("asset/characters/warrior/breath.png", "asset/characters/warrior/idle.png",
              (4, 4), 38.0, "breath becomes the idle animation"),
        Sheet("asset/characters/warrior/walk.png", "asset/characters/warrior/walk.png",
              (4, 4), 38.0),
    ]),
    ("ash_wraith", 33.0, [
        Sheet("asset/monsters/ash_wraith/idle.png", "asset/monsters/ash_wraith/idle.png",
              None, 33.0),
        Sheet("asset/monsters/ash_wraith/walk.png", "asset/monsters/ash_wraith/walk.png",
              (4, 4), 33.0, "drawn at its own scale, not the idle's", share_scale=False),
    ]),
]


def bands(mask, gap=0, min_len=8):
    spans, start = [], None
    for i, on in enumerate(mask):
        if on and start is None:
            start = i
        if not on and start is not None:
            spans.append([start, i - 1])
            start = None
    if start is not None:
        spans.append([start, len(mask) - 1])
    merged = []
    for span in spans:
        if merged and span[0] - merged[-1][1] - 1 <= gap:
            merged[-1][1] = span[1]
        else:
            merged.append(span)
    return [s for s in merged if s[1] - s[0] + 1 >= min_len]


def uniform_cuts(profile, count):
    """Best (offset, pitch) for `count` evenly spaced cells.

    Fitting two numbers beats snapping each boundary on its own, which walked
    cuts straight into the subjects the first time this was tried.
    """
    lit = np.nonzero(profile > 0)[0]
    top, bottom = int(lit[0]), int(lit[-1])
    best, best_cost = None, None
    for start in range(max(0, top - 12), top + 13):
        for end in range(bottom - 12, min(len(profile), bottom + 13)):
            if end - start < count * 8:
                continue
            pitch = (end - start + 1) / count
            cuts = [int(round(start + i * pitch)) for i in range(1, count)]
            cost = sum(profile[max(0, c - 1):c + 2].sum() for c in cuts)
            if best_cost is None or cost < best_cost:
                best_cost, best = cost, (start, pitch)
    start, pitch = best
    return [(int(round(start + i * pitch)), int(round(start + (i + 1) * pitch)) - 1)
            for i in range(count)]


def cut_frames(image, grid):
    arr = np.array(image)
    alpha = arr[:, :, 3] > 16
    if grid is None:
        ys, xs = np.nonzero(alpha)
        return [image.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))]
    rows, cols = grid
    row_spans = bands(alpha.sum(axis=1) > 0, gap=4, min_len=30)
    if len(row_spans) != rows:
        row_spans = uniform_cuts(alpha.sum(axis=1), rows)
    out = []
    for y0, y1 in row_spans:
        strip = alpha[y0:y1 + 1, :]
        col_spans = None
        for gap in (12, 20, 28, 36):
            found = bands(strip.sum(axis=0) > 0, gap=gap, min_len=20)
            if len(found) == cols:
                col_spans = found
                break
        if col_spans is None:
            col_spans = uniform_cuts(strip.sum(axis=0), cols)
        for x0, x1 in col_spans:
            cell_alpha = alpha[y0:y1 + 1, x0:x1 + 1]
            ys, xs = np.nonzero(cell_alpha)
            if len(xs) == 0:
                continue
            cell = image.crop((x0, y0, x1 + 1, y1 + 1))
            out.append(cell.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)))
    return out


def bake(sheet, factor, side, dry_run=False):
    image = Image.open(sheet.source).convert("RGBA")
    frames = cut_frames(image, sheet.grid)
    if not frames:
        print(f"  {sheet.out.name}: nothing cut")
        return None

    strip = Image.new("RGBA", (side * len(frames), side), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        scaled = frame.resize(
            (max(1, round(frame.width * factor)), max(1, round(frame.height * factor))),
            Image.LANCZOS if abs(factor - round(factor)) > 0.02 else Image.NEAREST,
        )
        x = i * side + (side - scaled.width) // 2
        y = side - round(side * FRAME_PAD) - scaled.height   # one foot baseline
        strip.alpha_composite(scaled, (x, max(0, y)))

    lit = np.nonzero(np.array(strip.getchannel("A")) > 16)[0]
    drawn = (lit.max() - lit.min() + 1) / EXPORT_SCALE
    print(f"  {sheet.out.relative_to(ROOT)}: {len(frames)} frames, {side}x{side} each, "
          f"scale x{factor:.2f}, drawn {drawn:.1f} logical"
          + (f"  [{sheet.note}]" if sheet.note else ""))
    if dry_run:
        return len(frames)

    KEEP.mkdir(parents=True, exist_ok=True)
    kept = KEEP / f"{sheet.source.parent.name}-{sheet.source.name}"
    if not kept.exists():
        kept.write_bytes(sheet.source.read_bytes())
    strip.save(sheet.out)
    return len(frames)


def reference_scale(sheet, logical_h):
    """Scale that puts this sheet's tallest frame at `logical_h` on screen."""
    image = Image.open(sheet.source).convert("RGBA")
    frames = cut_frames(image, sheet.grid)
    if not frames:
        return None, None
    target_h = logical_h * EXPORT_SCALE
    factor = target_h / max(f.height for f in frames)
    side = int(round(target_h * (1.0 + FRAME_PAD * 2)))
    return factor, side


def main():
    dry_run = "--dry-run" in sys.argv
    for name, logical_h, sheets in ACTORS:
        missing = [s for s in sheets if not s.source.exists()]
        if missing:
            print(f"{name}: source missing — " + ", ".join(s.source.name for s in missing))
            continue
        factor, side = reference_scale(sheets[0], logical_h)
        if factor is None:
            print(f"{name}: reference sheet has no frames")
            continue
        print(f"{name}: scale x{factor:.2f}, frame {side}x{side}")
        for sheet in sheets:
            if sheet.share_scale:
                bake(sheet, factor, side, dry_run)
                continue
            own_factor, _ = reference_scale(sheet, sheet.logical_h)
            bake(sheet, own_factor, side, dry_run)


if __name__ == "__main__":
    main()
