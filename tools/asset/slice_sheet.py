"""Slice a uniformly gridded generator sheet into raw cells.

Usage: python tools/asset/slice_sheet.py INPUT OUTPUT_DIR COLS ROWS NAME...

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
        path = output / f"{name}.png"
        image.crop((left, top, right, bottom)).save(path)
        print(f"{source} cell {column},{row} -> {path} ({right-left}x{bottom-top})")


if __name__ == "__main__":
    main()
