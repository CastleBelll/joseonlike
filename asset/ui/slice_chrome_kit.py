"""Cut the owner's UI kit into named chrome pieces (N10-14).

The owner drew one sheet holding the whole interface — panels, scrolls,
plaques, icon buttons, toggles, bars, slots, banners — and asked for it to be
cut up and used everywhere. This finds the pieces by their own transparency
rather than by an assumed grid: the kit is laid out by eye, and every attempt
in this project to guess a generator's grid has cut through a subject.

Outputs go to `chrome/build/` under their own names. The kit itself is an owner
drop and no tool may write to it — an earlier bake saved over the drops it read
and cost the owner a re-download of every sheet.

Run: python asset/ui/slice_chrome_kit.py [--dry-run]
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / "asset" / "ui" / "chrome" / "chrome 모음.png"
OUT = ROOT / "asset" / "ui" / "chrome" / "build"

ALPHA_FLOOR = 24
MIN_AREA = 900

## Reading order is top-to-bottom, then left-to-right, matching how the pieces
## are found. A tuple splits one run into several pieces along its long axis.
NAMES = [
    "paper_panel", "scroll", "title_plaque",
    "plaque_cream", "plaque_brown", "plaque_purple",
    "plaque_cream_wide", "plaque_indigo", "plaque_red",
    "plaque_coin", "plaque_box", "plaque_trophy",
    "btn_menu", "btn_list", "btn_grid", "btn_home", "btn_left", "btn_right",
    "btn_close",
    "icon_help", "icon_info", "icon_gear", "icon_sound", "icon_music",
    "icon_trophy", "icon_mail",
    "tassel_cream", "tassel_grey", "tassel_tan", "tassel_purple",
    "checkbox_off", "checkbox_on",
    "toggle_off", "toggle_on", "toggle_on_purple",
    "plate_cream", "plate_brown", "plate_purple", "plate_red",
    ("bar", 3, "rows"),          # hp / timer / level, stacked
    ("slot", 8, "cols"),         # square icon frames in one run
    "stat_strip",
    ("disc", 9, "cols"),         # round plates in one run
    "banner_purple", "banner_blue", "banner_red",
]
## Friendlier names for the pieces a run splits into, in order.
RUN_NAMES = {
    "bar": ["bar_hp", "bar_timer", "bar_level"],
}


def pieces(alpha):
    """Bounding boxes of every separate drawing, in reading order."""
    solid = alpha > ALPHA_FLOOR
    # Close hairline gaps so a piece with an internal hole stays one blob.
    closed = ndimage.binary_closing(solid, structure=np.ones((5, 5)))
    labelled, _count = ndimage.label(closed, structure=np.ones((3, 3)))
    found = []
    for span in ndimage.find_objects(labelled):
        rows, cols = span
        width, height = cols.stop - cols.start, rows.stop - rows.start
        if width * height < MIN_AREA:
            continue
        found.append((cols.start, rows.start, width, height))
    # Row-major: pieces on roughly the same line read left to right.
    found.sort(key=lambda box: (box[1] // 40, box[0]))
    return found


def split_run(image, count, axis):
    """Cut one run of equally-spaced items along `axis` by its empty gaps."""
    alpha = np.array(image.getchannel("A")) > ALPHA_FLOOR
    profile = alpha.sum(axis=0 if axis == "cols" else 1) > 0
    spans, start = [], None
    for i, lit in enumerate(profile):
        if lit and start is None:
            start = i
        if not lit and start is not None:
            spans.append((start, i - 1))
            start = None
    if start is not None:
        spans.append((start, len(profile) - 1))
    if len(spans) != count:
        # Fall back to even division rather than emitting the wrong number of
        # pieces under the right names.
        step = image.width / count if axis == "cols" else image.height / count
        spans = [(round(i * step), round((i + 1) * step) - 1) for i in range(count)]
    out = []
    for lo, hi in spans:
        box = (lo, 0, hi + 1, image.height) if axis == "cols" \
            else (0, lo, image.width, hi + 1)
        out.append(image.crop(box))
    return out


def main():
    dry_run = "--dry-run" in sys.argv
    if not KIT.exists():
        raise SystemExit(f"kit not found: {KIT}")
    kit = Image.open(KIT).convert("RGBA")
    boxes = pieces(np.array(kit.getchannel("A")))
    if len(boxes) != len(NAMES):
        raise SystemExit(
            f"found {len(boxes)} pieces but {len(NAMES)} names — the kit changed, "
            "so the name table has to be re-read against it"
        )
    if not dry_run:
        OUT.mkdir(parents=True, exist_ok=True)
    written = 0
    for entry, (x, y, width, height) in zip(NAMES, boxes):
        crop = kit.crop((x, y, x + width, y + height))
        if isinstance(entry, tuple):
            stem, count, axis = entry
            names = RUN_NAMES.get(stem, [f"{stem}_{i}" for i in range(count)])
            for name, part in zip(names, split_run(crop, count, axis)):
                print(f"  {name:20}{part.width}x{part.height}")
                if not dry_run:
                    part.save(OUT / f"{name}.png")
                written += 1
            continue
        print(f"  {entry:20}{width}x{height}")
        if not dry_run:
            crop.save(OUT / f"{entry}.png")
        written += 1
    print(f"{written} pieces -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
