"""Restore raw-sheet scale progression after each death cell is pixelized.

`pixelize.py` deliberately crops ordinary sprites, so a corpse would otherwise
be enlarged back to standing height. This helper measures each raw keyed cell
against frame zero, scales the already-pixelized sprite by that ratio, and
bottom-aligns the four results on one fixed 92px canvas.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

from pixelize import corner_colour, key_out, key_out_checker


def keyed_bbox(path: Path):
    image = Image.open(path).convert("RGBA")
    image = key_out(image, corner_colour(image))
    image = key_out_checker(image)
    return image.getbbox()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("raw_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    raw_boxes = [keyed_bbox(args.raw_dir / f"{index}.png") for index in range(4)]
    if any(box is None for box in raw_boxes):
        raise SystemExit("death sequence contains an empty raw frame")
    raw_heights = [box[3] - box[1] for box in raw_boxes]

    cut_images = [
        Image.open(args.output_dir / f"{index}.png").convert("RGBA")
        for index in range(4)
    ]
    cut_boxes = [image.getbbox() for image in cut_images]
    if any(box is None for box in cut_boxes):
        raise SystemExit("death sequence contains an empty cut frame")
    standing_height = cut_boxes[0][3] - cut_boxes[0][1]
    baseline = cut_boxes[0][3]

    for index, (image, box, raw_height) in enumerate(zip(cut_images, cut_boxes, raw_heights)):
        sprite = image.crop(box)
        target_height = max(1, round(standing_height * raw_height / raw_heights[0]))
        target_width = max(1, round(sprite.width * target_height / sprite.height))
        if target_width > 92:
            scale = 92 / target_width
            target_width = 92
            target_height = max(1, round(target_height * scale))
        sprite = sprite.resize((target_width, target_height), Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (92, 92), (0, 0, 0, 0))
        x = (92 - target_width) // 2
        y = min(92 - target_height, max(0, baseline - target_height))
        canvas.alpha_composite(sprite, (x, y))
        canvas.save(args.output_dir / f"{index}.png")
    print(
        f"{args.output_dir}: raw heights={raw_heights}, "
        f"normalized from standing height={standing_height}"
    )


if __name__ == "__main__":
    main()
