"""Slice a uniformly gridded generator sheet into raw cells.

Usage: python tools/asset/slice_sheet.py INPUT OUTPUT_DIR COLS ROWS
       [--inset=N] [--inset-x=N] [--inset-top=N] [--inset-bottom=N] NAME...

Names map left-to-right, top-to-bottom. Use ``_`` to skip a cell. The output
remains raw generator material; each named cell must still pass through
pixelize.py before it is used by the game.
"""
from pathlib import Path
import sys

from PIL import Image


def main() -> None:
    source, output_dir, cols_text, rows_text, *names = sys.argv[1:]
    cols, rows = int(cols_text), int(rows_text)
    inset = 0
    inset_x = None
    inset_top = None
    inset_bottom = None
    while names and names[0].startswith("--"):
        option = names.pop(0)
        key, value = option.split("=", 1)
        value = int(value)
        if key == "--inset":
            inset = value
        elif key == "--inset-x":
            inset_x = value
        elif key == "--inset-top":
            inset_top = value
        elif key == "--inset-bottom":
            inset_bottom = value
        else:
            raise SystemExit(f"unknown option {key}")
    inset_x = inset if inset_x is None else inset_x
    inset_top = inset if inset_top is None else inset_top
    inset_bottom = inset if inset_bottom is None else inset_bottom
    if min(inset_x, inset_top, inset_bottom) < 0:
        raise SystemExit("insets must be non-negative")
    if len(names) > cols * rows:
        raise SystemExit("more names than grid cells")

    image = Image.open(source).convert("RGBA")
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(names):
        if name == "_":
            continue
        column, row = index % cols, index // cols
        left = round(column * image.width / cols)
        top = round(row * image.height / rows)
        right = round((column + 1) * image.width / cols)
        bottom = round((row + 1) * image.height / rows)
        if right - left <= inset_x * 2 or bottom - top <= inset_top + inset_bottom:
            raise SystemExit(f"insets are too large for cell {column},{row}")
        left, top, right, bottom = (
            left + inset_x,
            top + inset_top,
            right - inset_x,
            bottom - inset_bottom,
        )
        path = output / f"{name}.png"
        image.crop((left, top, right, bottom)).save(path)
        print(f"{source} cell {column},{row} -> {path} ({right-left}x{bottom-top})")


if __name__ == "__main__":
    main()
