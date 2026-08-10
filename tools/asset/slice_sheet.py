"""Slice a uniformly gridded generator sheet into raw cells.

Usage: python tools/asset/slice_sheet.py INPUT OUTPUT_DIR COLS ROWS [--inset=N] NAME...

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
    if names and names[0].startswith("--inset="):
        inset = int(names.pop(0).split("=", 1)[1])
    if inset < 0:
        raise SystemExit("inset must be non-negative")
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
        if right - left <= inset * 2 or bottom - top <= inset * 2:
            raise SystemExit(f"inset {inset} is too large for cell {column},{row}")
        left, top, right, bottom = left + inset, top + inset, right - inset, bottom - inset
        path = output / f"{name}.png"
        image.crop((left, top, right, bottom)).save(path)
        print(f"{source} cell {column},{row} -> {path} ({right-left}x{bottom-top})")


if __name__ == "__main__":
    main()
