"""Post-process generated character sheets into runtime side-view sprites.

This script never invents character pixels. It extracts the five generated figures,
removes the chroma background, normalizes them onto a 32x32 logical canvas, and
repositions approved logical-pixel clusters for the walk cycle before exporting
nearest-neighbour 16x runtime PNGs.
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
STABLE_UPPER_ROWS = 23

WALK_POSE_CONFIG: dict[str, dict[str, int | tuple[int, int, int, int]]] = {
    "Taoist": {
        "center_x": 15,
        "leg_left": 7,
        "leg_right": 21,
        "arm_box": (9, 18, 14, 23),
    },
    "Warrior": {
        "center_x": 15,
        "leg_left": 8,
        "leg_right": 23,
        "arm_box": (10, 16, 14, 24),
    },
    "Archer": {
        "center_x": 15,
        "leg_left": 7,
        "leg_right": 22,
        "arm_box": (9, 15, 13, 23),
    },
}

CHARACTER_PALETTES: dict[str, tuple[tuple[int, int, int], ...]] = {
    "Taoist": (
        (31, 27, 28),
        (62, 43, 30),
        (99, 68, 36),
        (180, 122, 81),
        (235, 181, 139),
        (147, 158, 168),
        (221, 222, 214),
        (239, 235, 222),
        (35, 73, 120),
        (54, 105, 165),
        (151, 105, 43),
        (210, 164, 82),
        (239, 198, 113),
        (184, 130, 0),
        (242, 194, 40),
        (174, 183, 189),
    ),
    "Warrior": (
        (18, 24, 34),
        (22, 43, 85),
        (43, 79, 136),
        (65, 105, 166),
        (128, 31, 41),
        (185, 47, 58),
        (225, 74, 79),
        (95, 118, 132),
        (181, 199, 207),
        (229, 236, 238),
        (151, 98, 25),
        (219, 158, 48),
        (158, 102, 67),
        (228, 169, 125),
        (70, 44, 30),
        (58, 48, 39),
    ),
    "Archer": (
        (23, 35, 30),
        (66, 44, 30),
        (22, 78, 59),
        (47, 116, 84),
        (77, 142, 100),
        (137, 91, 39),
        (199, 152, 82),
        (226, 184, 107),
        (159, 113, 49),
        (213, 172, 99),
        (240, 205, 132),
        (139, 38, 37),
        (224, 75, 67),
        (172, 112, 74),
        (230, 174, 132),
        (232, 228, 192),
    ),
}

SOURCE_FILENAMES = (
    "side_sheet_youth_v4_higgsfield.png",
    "side_sheet_youth_v4.png",
    "side_sheet_higgsfield.png",
)


def chroma_foreground(rgb: np.ndarray) -> np.ndarray:
    """Return a foreground mask for generated green or magenta chroma sheets."""
    red = rgb[:, :, 0].astype(np.float32)
    green = rgb[:, :, 1].astype(np.float32)
    blue = rgb[:, :, 2].astype(np.float32)
    green_key = (green > 140) & (green > red * 1.25) & (green > blue * 1.25)
    magenta_key = (
        (red > 140)
        & (blue > 140)
        & (red > green * 1.25)
        & (blue > green * 1.25)
    )
    background = green_key | magenta_key
    return ~background


def extract_figures(source: Image.Image, expected_count: int = 5) -> list[Image.Image]:
    """Extract the largest generated connected components, left to right."""
    rgb = np.asarray(source.convert("RGB"))
    mask = chroma_foreground(rgb)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)

    components: list[tuple[int, int, int, int, int, int]] = []
    for label in range(1, count):
        x, y, width, height, area = map(int, stats[label])
        if area >= 2_000:
            components.append((x, y, width, height, area, label))
    components = sorted(components, key=lambda item: item[4], reverse=True)[
        :expected_count
    ]
    if len(components) != expected_count:
        raise ValueError(
            f"expected {expected_count} generated figures, found {len(components)}"
        )
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


def apply_shared_palette(frames: list[Image.Image], character: str) -> list[Image.Image]:
    """Map all frames to one authored palette so materials remain distinct."""
    sheet = Image.new("RGBA", (LOGICAL_SIZE * len(frames), LOGICAL_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * LOGICAL_SIZE, 0))

    source = np.asarray(sheet).copy()
    opaque = source[:, :, 3] >= 128
    palette = np.asarray(CHARACTER_PALETTES[character], dtype=np.uint8)
    source_lab = cv2.cvtColor(source[:, :, :3], cv2.COLOR_RGB2LAB).astype(np.float32)
    palette_lab = cv2.cvtColor(palette.reshape(1, -1, 3), cv2.COLOR_RGB2LAB)[0].astype(
        np.float32
    )
    distances = np.square(source_lab[:, :, None, :] - palette_lab[None, None, :, :]).sum(
        axis=3
    )
    nearest = distances.argmin(axis=2)
    mapped = np.zeros_like(source)
    mapped[:, :, :3] = palette[nearest]
    mapped[:, :, 3] = np.where(opaque, 255, 0)
    mapped[~opaque, :3] = 0
    quantized = Image.fromarray(mapped, "RGBA")

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


def _move_arm(frame: Image.Image, box: tuple[int, int, int, int], dy: int) -> Image.Image:
    """Move the free-arm cluster one logical pixel without changing its pixels."""
    moved = np.asarray(frame).copy()
    x0, y0, x1, y1 = box
    cluster = moved[y0:y1, x0:x1, :].copy()
    moved[y0:y1, x0:x1, :] = 0
    destination_y = y0 + dy
    moved[destination_y : destination_y + cluster.shape[0], x0:x1, :] = cluster
    return Image.fromarray(moved, "RGBA")


def _leg_pixels(
    base: np.ndarray,
    center_x: int,
    contact: bool,
    mirror: bool,
) -> list[tuple[int, int, np.ndarray]]:
    """Shear existing leg pixels into contact or passing poses around one hip."""
    pixels: list[tuple[int, int, np.ndarray]] = []
    for y in range(25, LOGICAL_SIZE):
        for x in range(LOGICAL_SIZE):
            color = base[y, x]
            if color[3] == 0:
                continue
            side = -1 if x <= center_x else 1
            if contact:
                offset = min(2, max(0, y - 25))
                destination_x = x + side * offset
                # The rear foot rolls onto its toe during contact; after the
                # mirrored phase, the opposite foot receives the same lift.
                destination_y = y - 1 if side == -1 and y >= 28 else y
            else:
                offset = 1 if y >= 26 else 0
                destination_x = x - side * offset
                # Passing frames bob the body upward. One foot remains planted
                # on row 29 while the opposite foot lifts with the body.
                planted_side = 1
                destination_y = y if side == planted_side and y == GROUND_Y else y - 1
                if side == planted_side and y == GROUND_Y:
                    pixels.append((destination_x, y - 1, color.copy()))
            if mirror:
                destination_x = center_x * 2 + 1 - destination_x
            if 0 <= destination_x < LOGICAL_SIZE and 0 <= destination_y < LOGICAL_SIZE:
                pixels.append((destination_x, destination_y, color.copy()))
    return pixels


def strengthen_walk_cycle(frames: list[Image.Image], character: str) -> list[Image.Image]:
    """Build a readable contact/passing cycle from one approved walk-frame base."""
    if len(frames) != 5:
        raise ValueError("expected idle plus four walk frames")
    config = WALK_POSE_CONFIG[character]
    center_x = int(config["center_x"])
    leg_left = int(config["leg_left"])
    leg_right = int(config["leg_right"])
    arm_box = config["arm_box"]
    assert isinstance(arm_box, tuple)

    base_image = frames[1]
    base = np.asarray(base_image).copy()
    strengthened: list[Image.Image] = [frames[0]]

    # Contact A and B keep the head/face fixed and use mirrored, widely
    # scissored legs. The free arm counters the leading leg by one pixel.
    for mirror, arm_dy in ((False, 1), (True, -1)):
        pose = base.copy()
        pose[25:, leg_left:leg_right, :] = 0
        for x, y, color in _leg_pixels(base, center_x, True, mirror):
            if leg_left <= x < leg_right:
                pose[y, x] = color
        strengthened.append(
            _move_arm(Image.fromarray(pose, "RGBA"), arm_box, arm_dy)
        )

    # Passing A and B shift the body up exactly one logical pixel, gather the
    # legs beneath the hip, and alternate which foot remains planted.
    passing_poses: list[Image.Image] = []
    for mirror in (False, True):
        pose = np.zeros_like(base)
        pose[:-1, :, :] = base[1:, :, :]
        pose[24:, leg_left:leg_right, :] = 0
        for x, y, color in _leg_pixels(base, center_x, False, mirror):
            if leg_left <= x < leg_right:
                pose[y, x] = color
        passing_poses.append(Image.fromarray(pose, "RGBA"))

    # Runtime order is Contact A, Passing A, Contact B, Passing B.
    return [
        strengthened[0],
        strengthened[1],
        passing_poses[0],
        strengthened[2],
        passing_poses[1],
    ]


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
        expected = ", ".join(SOURCE_FILENAMES)
        raise FileNotFoundError(f"no source sheet for {character_root.name}: {expected}")
    output_root = character_root / "side"
    output_root.mkdir(parents=True, exist_ok=True)

    source = Image.open(source_path).convert("RGBA")
    frames = resize_and_align(extract_figures(source))
    frames = apply_shared_palette(stabilize_walk_upper_body(frames), character_root.name)
    frames = strengthen_walk_cycle(frames, character_root.name)
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

        logical_walk = walk.resize(
            (LOGICAL_SIZE * 4, LOGICAL_SIZE), Image.Resampling.NEAREST
        )
        walk_frames = [
            np.asarray(
                logical_walk.crop(
                    (index * LOGICAL_SIZE, 0, (index + 1) * LOGICAL_SIZE, LOGICAL_SIZE)
                )
            )
            for index in range(4)
        ]
        if len({frame.tobytes() for frame in walk_frames}) != 4:
            raise ValueError(f"duplicate walk phases for {character}")

        tops = []
        for frame in walk_frames:
            rows, _ = np.nonzero(frame[:, :, 3])
            tops.append(int(rows.min()))
            if int(rows.max()) != GROUND_Y:
                raise ValueError(f"walk frame missed ground row for {character}")
        if tops[1] != tops[0] - 1 or tops[3] != tops[2] - 1:
            raise ValueError(f"passing-frame bob is not exactly one pixel for {character}")

        # Contact head/face art is identical; passing frames contain the exact
        # same pixels translated upward by the one-pixel body bob.
        head_box = (slice(2, 15), slice(8, 21))
        if not np.array_equal(walk_frames[0][head_box], walk_frames[2][head_box]):
            raise ValueError(f"contact head drift for {character}")
        if not np.array_equal(
            walk_frames[0][3:15, 8:21], walk_frames[1][2:14, 8:21]
        ) or not np.array_equal(
            walk_frames[2][3:15, 8:21], walk_frames[3][2:14, 8:21]
        ):
            raise ValueError(f"passing head drift for {character}")

        config = WALK_POSE_CONFIG[character]
        center_x = int(config["center_x"])
        ground_centers = []
        for frame in walk_frames:
            ground_columns = np.nonzero(frame[GROUND_Y, :, 3])[0]
            ground_centers.append(float(ground_columns.mean()))
        if not (
            ground_centers[0] > center_x
            and ground_centers[1] > center_x
            and ground_centers[2] < center_x
            and ground_centers[3] < center_x
        ):
            raise ValueError(f"feet do not alternate sides for {character}")

        leg_left = int(config["leg_left"])
        leg_right = int(config["leg_right"])
        strides = []
        for frame in walk_frames:
            columns = np.nonzero(frame[27, leg_left:leg_right, 3])[0]
            strides.append(int(columns.max() - columns.min()))
        if not (strides[0] > strides[1] and strides[2] > strides[3]):
            raise ValueError(f"contact silhouette is not wider than passing for {character}")


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
