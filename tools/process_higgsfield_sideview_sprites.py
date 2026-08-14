"""Build the V8 48px two-head side-view sprites from Higgsfield sheets.

The generator supplies the character pixels.  This script removes the chroma key,
snaps the five poses to one 48x48 logical grid, locks the head drawing across poses,
and exports the authored contact/passing cycle on a shared ground line.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


CHARACTERS = ("Taoist", "Warrior", "Archer")
LOGICAL_WIDTH = 48
LOGICAL_HEIGHT = 48
EXPORT_SCALE = 16
GROUND_Y = 46
TARGET_HEIGHT = 43
OPAQUE_PALETTE_COLORS = 20
OUTLINE_COLOR = (20, 20, 27, 255)

POSE_CONFIG: dict[str, dict[str, int]] = {
    "Taoist": {
        "center_x": 23,
        "leg_left": 12,
        "leg_right": 35,
        "head_left": 9,
        "head_right": 34,
    },
    "Warrior": {
        "center_x": 23,
        "leg_left": 13,
        "leg_right": 35,
        "head_left": 10,
        "head_right": 36,
    },
    "Archer": {
        "center_x": 23,
        "leg_left": 12,
        "leg_right": 36,
        "head_left": 9,
        "head_right": 36,
    },
}

SOURCE_FILENAMES = (
    "side_sheet_v8_higgsfield.png",
)


def chroma_foreground(rgb: np.ndarray) -> np.ndarray:
    """Return a foreground mask for green or magenta generation backdrops."""
    red = rgb[:, :, 0].astype(np.float32)
    green = rgb[:, :, 1].astype(np.float32)
    blue = rgb[:, :, 2].astype(np.float32)
    green_key = (green > 125) & (green > red * 1.20) & (green > blue * 1.20)
    magenta_key = (
        (red > 125)
        & (blue > 110)
        & (red > green * 1.35)
        & (blue > green * 1.25)
    )
    return ~(green_key | magenta_key)


def extract_figures(source: Image.Image, expected_count: int = 5) -> list[Image.Image]:
    """Extract the five largest connected silhouettes and order them left-to-right."""
    rgb = np.asarray(source.convert("RGB"))
    mask = chroma_foreground(rgb)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)
    minimum_area = max(800, source.width * source.height // 5_000)
    components: list[tuple[int, int, int, int, int, int]] = []
    for label in range(1, count):
        x, y, width, height, area = map(int, stats[label])
        if area >= minimum_area and height > source.height * 0.20:
            components.append((x, y, width, height, area, label))
    components = sorted(components, key=lambda item: item[4], reverse=True)[:expected_count]
    if len(components) != expected_count:
        raise ValueError(f"expected {expected_count} figures, found {len(components)}")
    components.sort(key=lambda item: item[0])

    figures: list[Image.Image] = []
    for x, y, width, height, _, label in components:
        component = labels[y : y + height, x : x + width] == label
        rgba = np.zeros((height, width, 4), dtype=np.uint8)
        rgba[:, :, :3] = rgb[y : y + height, x : x + width]
        rgba[:, :, 3] = component.astype(np.uint8) * 255
        figures.append(Image.fromarray(rgba, "RGBA"))
    return figures


def resize_and_align(figures: list[Image.Image]) -> list[Image.Image]:
    """Apply one per-sheet reduction scale and one shared head/ground anchor."""
    median_height = float(np.median([figure.height for figure in figures]))
    scale = TARGET_HEIGHT / median_height
    frames: list[Image.Image] = []

    for figure in figures:
        width = max(1, round(figure.width * scale))
        height = max(1, round(figure.height * scale))
        reduced = figure.resize((width, height), Image.Resampling.BOX)
        pixels = np.asarray(reduced).copy()
        pixels[:, :, 3] = np.where(pixels[:, :, 3] >= 128, 255, 0)
        pixels[pixels[:, :, 3] == 0, :3] = 0
        alpha = pixels[:, :, 3] > 0
        rows, columns = np.nonzero(alpha)
        if not len(columns):
            raise ValueError("empty figure after logical-grid reduction")

        top, bottom = int(rows.min()), int(rows.max())
        head_limit = top + max(1, round((bottom - top + 1) * 0.30))
        head = alpha & (np.indices(alpha.shape)[0] < head_limit)
        _, head_columns = np.nonzero(head)
        head_center = (
            (int(head_columns.min()) + int(head_columns.max())) / 2.0
            if len(head_columns)
            else (int(columns.min()) + int(columns.max())) / 2.0
        )

        # Reserve one row for the explicit outer outline at the shared ground.
        destination_x = round(LOGICAL_WIDTH / 2 - head_center)
        destination_y = GROUND_Y - 1 - bottom
        canvas = Image.new("RGBA", (LOGICAL_WIDTH, LOGICAL_HEIGHT), (0, 0, 0, 0))
        canvas.alpha_composite(Image.fromarray(pixels, "RGBA"), (destination_x, destination_y))
        frames.append(canvas)
    return frames


def reference_palette(reference_path: Path) -> np.ndarray:
    """Derive one deterministic flat palette from the authoritative character crop."""
    source = np.asarray(Image.open(reference_path).convert("RGB"))
    foreground = chroma_foreground(source)
    colors = source[foreground]
    if not len(colors):
        raise ValueError(f"reference contains no foreground: {reference_path}")
    # Median-cut is deterministic and preserves rare, high-salience weapon colors.
    swatch = Image.fromarray(colors.reshape(1, -1, 3), "RGB")
    quantized = swatch.quantize(
        colors=OPAQUE_PALETTE_COLORS - 1,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    palette = np.unique(np.asarray(quantized).reshape(-1, 3), axis=0)
    outline = np.asarray(OUTLINE_COLOR[:3], dtype=np.uint8)
    palette = np.vstack((outline, palette))
    return np.unique(palette, axis=0).astype(np.uint8)


def apply_palette(frames: list[Image.Image], palette: np.ndarray) -> list[Image.Image]:
    """Map every pose to the reference-derived palette without dithering."""
    sheet = Image.new(
        "RGBA", (LOGICAL_WIDTH * len(frames), LOGICAL_HEIGHT), (0, 0, 0, 0)
    )
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * LOGICAL_WIDTH, 0))
    source = np.asarray(sheet).copy()
    opaque = source[:, :, 3] >= 128
    source_lab = cv2.cvtColor(source[:, :, :3], cv2.COLOR_RGB2LAB).astype(np.float32)
    palette_lab = cv2.cvtColor(palette.reshape(1, -1, 3), cv2.COLOR_RGB2LAB)[0].astype(
        np.float32
    )
    distances = np.square(source_lab[:, :, None, :] - palette_lab[None, None, :, :]).sum(3)
    mapped = np.zeros_like(source)
    mapped[:, :, :3] = palette[distances.argmin(2)]
    mapped[:, :, 3] = np.where(opaque, 255, 0)
    mapped[~opaque, :3] = 0
    quantized = Image.fromarray(mapped, "RGBA")
    return [
        quantized.crop(
            (index * LOGICAL_WIDTH, 0, (index + 1) * LOGICAL_WIDTH, LOGICAL_HEIGHT)
        )
        for index in range(len(frames))
    ]


def add_outline(frame: Image.Image) -> Image.Image:
    """Add one logical pixel of near-black around the generated silhouette."""
    pixels = np.asarray(frame).copy()
    alpha = pixels[:, :, 3] > 0
    dilated = cv2.dilate(alpha.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=1) > 0
    border = dilated & ~alpha
    pixels[border] = OUTLINE_COLOR
    return Image.fromarray(pixels, "RGBA")


def lock_head_drawing(frames: list[Image.Image], character: str) -> list[Image.Image]:
    """Use the idle head pixels in every pose while leaving limbs and gear authored.

    The generated sheets are already consistent, but small eye/hat variations become
    distracting after reduction.  Locking only the central head rectangle preserves
    the staff, sword, bow, quiver, shoulders, and their generated motion.
    """
    idle = np.asarray(frames[0])
    rows, _ = np.nonzero(idle[:, :, 3])
    if not len(rows):
        raise ValueError(f"empty idle frame for {character}")
    top = int(rows.min())
    head_bottom = min(LOGICAL_HEIGHT, top + 22)
    config = POSE_CONFIG[character]
    left, right = config["head_left"], config["head_right"]
    locked = [frames[0]]
    for frame in frames[1:]:
        pixels = np.asarray(frame).copy()
        # Clear the full top slice first so a taller generated hat cannot peek
        # above the canonical idle drawing.
        pixels[:head_bottom, left:right] = idle[:head_bottom, left:right]
        locked.append(Image.fromarray(pixels, "RGBA"))
    return locked


def build_walk_cycle(frames: list[Image.Image], character: str) -> list[Image.Image]:
    """Keep Higgsfield's authored walk poses and apply only the required bob.

    No limb pixels are synthesized or mirrored.  Contact frames are passed
    through unchanged; each generated passing frame is translated up exactly
    one logical pixel and its authored sole row is retained on the ground.
    """
    if len(frames) != 5:
        raise ValueError("expected idle plus four generated walk poses")
    del character
    built: list[Image.Image] = [frames[0]]
    for source_index in range(1, 5):
        source = np.asarray(frames[source_index]).copy()
        passing = source_index in (2, 4)
        if passing:
            pose = np.zeros_like(source)
            pose[:-1, :, :] = source[1:, :, :]
            # Retain the exact generated sole pixels at the shared ground row;
            # this leaves a visibly planted support foot instead of an airborne
            # frame while the body completes its one-pixel passing rise.
            pose[GROUND_Y, :, :] = source[GROUND_Y, :, :]
        else:
            pose = source
        built.append(Image.fromarray(pose, "RGBA"))

    return built


def save_preview(frames: list[Image.Image], output_path: Path) -> None:
    """Save an 8.3 fps dark-background GIF used for loop inspection."""
    previews: list[Image.Image] = []
    for frame in frames:
        background = Image.new("RGBA", frame.size, (25, 28, 38, 255))
        background.alpha_composite(frame)
        previews.append(
            background.convert("RGB").resize(
                (LOGICAL_WIDTH * 4, LOGICAL_HEIGHT * 4), Image.Resampling.NEAREST
            )
        )
    previews[0].save(
        output_path,
        save_all=True,
        append_images=previews[1:],
        duration=120,
        loop=0,
        optimize=False,
    )


def export_character(character_root: Path) -> dict[str, object]:
    source_path = next(
        (
            character_root / "raw" / filename
            for filename in SOURCE_FILENAMES
            if (character_root / "raw" / filename).is_file()
        ),
        None,
    )
    if source_path is None:
        raise FileNotFoundError(f"no V6 source sheet for {character_root.name}")
    reference_path = character_root / "raw" / "character_v6_reference.png"
    if not reference_path.is_file():
        raise FileNotFoundError(reference_path)

    source = Image.open(source_path).convert("RGBA")
    frames = resize_and_align(extract_figures(source))
    frames = apply_palette(frames, reference_palette(reference_path))
    frames = [add_outline(frame) for frame in frames]
    frames = lock_head_drawing(frames, character_root.name)
    frames = build_walk_cycle(frames, character_root.name)
    exported = [
        frame.resize(
            (LOGICAL_WIDTH * EXPORT_SCALE, LOGICAL_HEIGHT * EXPORT_SCALE),
            Image.Resampling.NEAREST,
        )
        for frame in frames
    ]

    output_root = character_root / "side"
    output_root.mkdir(parents=True, exist_ok=True)
    exported[0].save(output_root / "idle.png", optimize=True)
    walk = Image.new(
        "RGBA",
        (LOGICAL_WIDTH * EXPORT_SCALE * 4, LOGICAL_HEIGHT * EXPORT_SCALE),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(exported[1:]):
        walk.alpha_composite(frame, (index * LOGICAL_WIDTH * EXPORT_SCALE, 0))
    walk.save(output_root / "walk.png", optimize=True)
    save_preview(frames[1:], character_root / "raw" / "walk_v8_preview.gif")

    bounds = [frame.getbbox() for frame in frames]
    return {
        "source": source_path.as_posix(),
        "source_size": list(source.size),
        "reference": reference_path.as_posix(),
        "logical_canvas": [LOGICAL_WIDTH, LOGICAL_HEIGHT],
        "export_scale": EXPORT_SCALE,
        "ground_row": GROUND_Y,
        "logical_bounds": bounds,
        "opaque_palette_colors": len(
            {
                tuple(pixel[:3])
                for frame in frames
                for pixel in np.asarray(frame).reshape(-1, 4)
                if pixel[3]
            }
        ),
    }


def verify_exports(asset_root: Path) -> dict[str, object]:
    verification: dict[str, object] = {}
    idle_size = (LOGICAL_WIDTH * EXPORT_SCALE, LOGICAL_HEIGHT * EXPORT_SCALE)
    walk_size = (idle_size[0] * 4, idle_size[1])
    for character in CHARACTERS:
        side = asset_root / character / "side"
        idle = Image.open(side / "idle.png").convert("RGBA")
        walk = Image.open(side / "walk.png").convert("RGBA")
        if idle.size != idle_size or walk.size != walk_size:
            raise ValueError(f"unexpected export dimensions for {character}")
        for image in (idle, walk):
            if not set(np.asarray(image.getchannel("A")).reshape(-1)) <= {0, 255}:
                raise ValueError(f"non-binary alpha in {character}")
            logical = image.resize(
                (image.width // EXPORT_SCALE, image.height // EXPORT_SCALE),
                Image.Resampling.NEAREST,
            ).resize(image.size, Image.Resampling.NEAREST)
            if image.tobytes() != logical.tobytes():
                raise ValueError(f"off-grid pixels in {character}")

        logical_walk = walk.resize(
            (LOGICAL_WIDTH * 4, LOGICAL_HEIGHT), Image.Resampling.NEAREST
        )
        frames = [
            np.asarray(
                logical_walk.crop(
                    (
                        index * LOGICAL_WIDTH,
                        0,
                        (index + 1) * LOGICAL_WIDTH,
                        LOGICAL_HEIGHT,
                    )
                )
            )
            for index in range(4)
        ]
        if len({frame.tobytes() for frame in frames}) != 4:
            raise ValueError(f"duplicate walk phases for {character}")
        tops: list[int] = []
        bottoms: list[int] = []
        for frame in frames:
            rows, _ = np.nonzero(frame[:, :, 3])
            tops.append(int(rows.min()))
            bottoms.append(int(rows.max()))
        if tops[1] != tops[0] - 1 or tops[3] != tops[2] - 1:
            raise ValueError(f"passing bob is not exactly one pixel for {character}")
        if bottoms != [GROUND_Y] * 4:
            raise ValueError(f"frames missed shared ground row for {character}: {bottoms}")

        config = POSE_CONFIG[character]
        head_centers: list[float] = []
        for frame in frames:
            head_alpha = frame[:24, 9:38, 3] > 0
            _, columns = np.nonzero(head_alpha)
            center = float((columns + 9).mean()) if len(columns) else 0.0
            head_centers.append(center)
        if max(head_centers) - min(head_centers) > 1.25:
            raise ValueError(f"head anchor drift for {character}")

        canonical_head = frames[0][:24, config["head_left"] : config["head_right"]]
        for index, frame in enumerate(frames[1:], start=1):
            if index in (1, 3):
                restored = np.zeros_like(frame)
                restored[1:] = frame[:-1]
                candidate = restored[:24, config["head_left"] : config["head_right"]]
            else:
                candidate = frame[:24, config["head_left"] : config["head_right"]]
            if candidate.tobytes() != canonical_head.tobytes():
                raise ValueError(f"head pixels drifted in {character} frame {index + 1}")

        ground_centers: list[float] = []
        strides: list[int] = []
        for frame in frames:
            columns = np.nonzero(frame[GROUND_Y, :, 3])[0]
            ground_centers.append(round(float(columns.mean()), 3))
            leg_columns = np.nonzero(
                frame[GROUND_Y - 3, config["leg_left"] : config["leg_right"], 3]
            )[0]
            strides.append(int(leg_columns.max() - leg_columns.min()))
        if not (strides[0] > strides[1] and strides[2] > strides[3]):
            raise ValueError(f"contact/passing stride order failed for {character}: {strides}")
        verification[character] = {
            "walk_top_rows": tops,
            "walk_bottom_rows": bottoms,
            "grounded_foot_centers": ground_centers,
            "stride_widths": strides,
            "head_center_spread": round(max(head_centers) - min(head_centers), 3),
            "head_pixels_locked": True,
            "head_height_px": 22,
            "figure_height_px": bottoms[0] - tops[0] + 1,
            "distinct_frames": 4,
            "binary_alpha": True,
            "grid_aligned": True,
            "gif_fps": 8.3,
        }
    return verification


def save_contact_sheet(asset_root: Path) -> None:
    """Save a 1x-logical silhouette review sheet enlarged without smoothing."""
    scale = 6
    margin = 4
    sheet = Image.new(
        "RGBA",
        (
            (LOGICAL_WIDTH * 5 + margin * 6) * scale,
            (LOGICAL_HEIGHT * len(CHARACTERS) + margin * 4) * scale,
        ),
        (25, 28, 38, 255),
    )
    for row, character in enumerate(CHARACTERS):
        side = asset_root / character / "side"
        idle = Image.open(side / "idle.png").convert("RGBA").resize(
            (LOGICAL_WIDTH, LOGICAL_HEIGHT), Image.Resampling.NEAREST
        )
        walk = Image.open(side / "walk.png").convert("RGBA").resize(
            (LOGICAL_WIDTH * 4, LOGICAL_HEIGHT), Image.Resampling.NEAREST
        )
        frames = [idle] + [
            walk.crop(
                (
                    index * LOGICAL_WIDTH,
                    0,
                    (index + 1) * LOGICAL_WIDTH,
                    LOGICAL_HEIGHT,
                )
            )
            for index in range(4)
        ]
        for column, frame in enumerate(frames):
            preview = frame.resize(
                (LOGICAL_WIDTH * scale, LOGICAL_HEIGHT * scale),
                Image.Resampling.NEAREST,
            )
            x = (margin + column * (LOGICAL_WIDTH + margin)) * scale
            y = (margin + row * (LOGICAL_HEIGHT + margin)) * scale
            sheet.alpha_composite(preview, (x, y))
    sheet.convert("RGB").save(asset_root / "side_v8_contact_sheet.png", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-root", type=Path, default=Path("asset/character"))
    parser.add_argument("--metrics", type=Path)
    args = parser.parse_args()
    metrics: dict[str, object] = {
        "source_design": "new_asset/Character.png",
        "source_size": [2688, 1520],
        "proportion_reference": "git show 97eb0d0 -- asset/character/*/side/",
        "logical_canvas": [LOGICAL_WIDTH, LOGICAL_HEIGHT],
        "export_scale": EXPORT_SCALE,
        "ground_row": GROUND_Y,
        "characters": {
            character: export_character(args.asset_root / character)
            for character in CHARACTERS
        },
    }
    metrics["verification"] = verify_exports(args.asset_root)
    save_contact_sheet(args.asset_root)
    if args.metrics:
        args.metrics.parent.mkdir(parents=True, exist_ok=True)
        args.metrics.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
