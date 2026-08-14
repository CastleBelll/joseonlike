"""Post-process Higgsfield character sheets into runtime side-view sprites.

This script never draws character pixels. It extracts the five generated figures,
removes the chroma background, normalizes them onto a 32x32 logical canvas, and
exports nearest-neighbour 16x runtime PNGs.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


CHARACTERS = ("Taoist", "Warrior", "Archer")
LOGICAL_SIZE = 32
EXPORT_SCALE = 16
GROUND_Y = 29
TARGET_HEIGHT = 27
PALETTE_COLORS = 16
STABLE_UPPER_ROWS = 23


def chroma_foreground(rgb: np.ndarray) -> np.ndarray:
    """Return a binary foreground mask for the generated green-screen sheet."""
    red = rgb[:, :, 0].astype(np.float32)
    green = rgb[:, :, 1].astype(np.float32)
    blue = rgb[:, :, 2].astype(np.float32)
    background = (green > 140) & (green > red * 1.25) & (green > blue * 1.25)
    return ~background


def extract_figures(source: Image.Image) -> list[Image.Image]:
    """Extract the five largest generated connected components, left to right."""
    rgb = np.asarray(source.convert("RGB"))
    mask = chroma_foreground(rgb)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)

    components: list[tuple[int, int, int, int, int, int]] = []
    for label in range(1, count):
        x, y, width, height, area = map(int, stats[label])
        if area >= 2_000:
            components.append((x, y, width, height, area, label))
    components = sorted(components, key=lambda item: item[4], reverse=True)[:5]
    if len(components) != 5:
        raise ValueError(f"expected five generated figures, found {len(components)}")
    components.sort(key=lambda item: item[0])

    figures: list[Image.Image] = []
    for x, y, width, height, _, label in components:
        component_mask = labels[y : y + height, x : x + width] == label
        crop = rgb[y : y + height, x : x + width].copy()
        rgba = np.zeros((height, width, 4), dtype=np.uint8)
        rgba[:, :, :3] = crop
        rgba[:, :, 3] = component_mask.astype(np.uint8) * 255
        figures.append(Image.fromarray(rgba, "RGBA"))
    return figures


def resize_and_align(figures: list[Image.Image]) -> list[Image.Image]:
    """Use one scale per sheet, a head anchor, and one shared ground line."""
    median_height = float(np.median([figure.height for figure in figures]))
    scale = TARGET_HEIGHT / median_height
    logical_frames: list[Image.Image] = []

    for figure in figures:
        width = max(1, round(figure.width * scale))
        height = max(1, round(figure.height * scale))
        reduced = figure.resize((width, height), Image.Resampling.BOX)

        reduced_array = np.asarray(reduced).copy()
        reduced_array[:, :, 3] = np.where(reduced_array[:, :, 3] >= 128, 255, 0)
        reduced_array[reduced_array[:, :, 3] == 0, :3] = 0
        reduced = Image.fromarray(reduced_array, "RGBA")

        alpha = reduced_array[:, :, 3] > 0
        rows, columns = np.nonzero(alpha)
        if not len(columns):
            raise ValueError("empty figure after logical-grid reduction")

        top = int(rows.min())
        bottom = int(rows.max())
        head_limit = top + max(1, round((bottom - top + 1) * 0.42))
        head_rows, head_columns = np.nonzero(alpha & (np.indices(alpha.shape)[0] < head_limit))
        if len(head_columns):
            head_center_x = (int(head_columns.min()) + int(head_columns.max())) / 2.0
        else:
            head_center_x = (int(columns.min()) + int(columns.max())) / 2.0

        destination_x = round(LOGICAL_SIZE / 2 - head_center_x)
        destination_y = GROUND_Y - bottom
        canvas = Image.new("RGBA", (LOGICAL_SIZE, LOGICAL_SIZE), (0, 0, 0, 0))
        canvas.alpha_composite(reduced, (destination_x, destination_y))
        logical_frames.append(canvas)

    return logical_frames


def apply_shared_palette(frames: list[Image.Image]) -> list[Image.Image]:
    """Quantize all five frames together so colors cannot drift frame to frame."""
    sheet = Image.new("RGBA", (LOGICAL_SIZE * len(frames), LOGICAL_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * LOGICAL_SIZE, 0))

    quantized = sheet.quantize(
        colors=PALETTE_COLORS,
        method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    source_alpha = np.asarray(sheet)[:, :, 3]
    quantized_array = np.asarray(quantized).copy()
    quantized_array[:, :, 3] = np.where(source_alpha >= 128, 255, 0)
    quantized_array[quantized_array[:, :, 3] == 0, :3] = 0
    quantized = Image.fromarray(quantized_array, "RGBA")

    return [
        quantized.crop((index * LOGICAL_SIZE, 0, (index + 1) * LOGICAL_SIZE, LOGICAL_SIZE))
        for index in range(len(frames))
    ]


def stabilize_walk_upper_body(frames: list[Image.Image]) -> list[Image.Image]:
    """Reuse one generated walk-frame upper layer to eliminate loop flicker."""
    stabilized = [frame.copy() for frame in frames]
    reference = np.asarray(stabilized[1]).copy()
    for index in range(2, len(stabilized)):
        frame = np.asarray(stabilized[index]).copy()
        frame[:STABLE_UPPER_ROWS, :, :] = reference[:STABLE_UPPER_ROWS, :, :]
        stabilized[index] = Image.fromarray(frame, "RGBA")
    return stabilized


def export_character(character_root: Path) -> dict[str, object]:
    source_path = character_root / "raw" / "side_sheet_higgsfield.png"
    output_root = character_root / "side"
    output_root.mkdir(parents=True, exist_ok=True)

    source = Image.open(source_path).convert("RGBA")
    frames = resize_and_align(extract_figures(source))
    frames = apply_shared_palette(stabilize_walk_upper_body(frames))
    exported = [
        frame.resize(
            (LOGICAL_SIZE * EXPORT_SCALE, LOGICAL_SIZE * EXPORT_SCALE),
            Image.Resampling.NEAREST,
        )
        for frame in frames
    ]

    exported[0].save(output_root / "idle.png", optimize=True)
    walk = Image.new(
        "RGBA",
        (LOGICAL_SIZE * EXPORT_SCALE * 4, LOGICAL_SIZE * EXPORT_SCALE),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(exported[1:]):
        walk.alpha_composite(frame, (index * LOGICAL_SIZE * EXPORT_SCALE, 0))
    walk.save(output_root / "walk.png", optimize=True)

    upper_centers: list[float] = []
    bounds: list[tuple[int, int, int, int] | None] = []
    for frame in frames:
        alpha = np.asarray(frame)[:, :, 3] > 0
        rows, columns = np.nonzero(alpha)
        bounds.append(frame.getbbox())
        upper = alpha & (np.indices(alpha.shape)[0] <= 18)
        upper_rows, upper_columns = np.nonzero(upper)
        upper_centers.append(float(upper_columns.mean()) if len(upper_columns) else 0.0)

    return {
        "source": source_path.as_posix(),
        "source_size": list(source.size),
        "logical_bounds": bounds,
        "walk_upper_body_center_spread_px": round(
            max(upper_centers[1:]) - min(upper_centers[1:]), 3
        ),
        "palette_colors": len(
            {
                tuple(pixel)
                for frame in frames
                for pixel in np.asarray(frame).reshape(-1, 4)
            }
        ),
    }


def verify_exports(asset_root: Path) -> None:
    for character in CHARACTERS:
        side = asset_root / character / "side"
        idle = Image.open(side / "idle.png").convert("RGBA")
        walk = Image.open(side / "walk.png").convert("RGBA")
        if idle.size != (512, 512) or walk.size != (2048, 512):
            raise ValueError(f"unexpected export dimensions for {character}")
        for image in (idle, walk):
            alpha_values = set(np.asarray(image.getchannel("A")).reshape(-1))
            if not alpha_values <= {0, 255}:
                raise ValueError(f"non-binary alpha in {character}")
            logical = image.resize(
                (image.width // EXPORT_SCALE, image.height // EXPORT_SCALE),
                Image.Resampling.NEAREST,
            ).resize(image.size, Image.Resampling.NEAREST)
            if image.tobytes() != logical.tobytes():
                raise ValueError(f"off-grid pixels in {character}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-root", type=Path, default=Path("asset/character"))
    parser.add_argument("--metrics", type=Path)
    args = parser.parse_args()

    metrics = {
        character: export_character(args.asset_root / character)
        for character in CHARACTERS
    }
    verify_exports(args.asset_root)
    if args.metrics:
        args.metrics.parent.mkdir(parents=True, exist_ok=True)
        args.metrics.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
