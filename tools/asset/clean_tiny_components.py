"""Remove isolated generator specks from a hard-alpha pixel sprite."""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument("--min-pixels", type=int, default=3)
    args = parser.parse_args()
    image = Image.open(args.path).convert("RGBA")
    opaque = {
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if image.getpixel((x, y))[3]
    }
    removed = 0
    while opaque:
        seed = opaque.pop()
        component = {seed}
        pending = [seed]
        while pending:
            x, y = pending.pop()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in opaque:
                    opaque.remove(neighbor)
                    component.add(neighbor)
                    pending.append(neighbor)
        if len(component) < args.min_pixels:
            for point in component:
                image.putpixel(point, (0, 0, 0, 0))
            removed += len(component)
    image.save(args.path)
    print(f"{args.path}: removed {removed} pixels in tiny components")


if __name__ == "__main__":
    main()
