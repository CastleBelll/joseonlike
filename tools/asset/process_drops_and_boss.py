"""Slice and pixelize the loot/drop set and the enlarged Bamboo Spirit Lord."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
DROP_RAW = ROOT / "asset/drop/raw"
BOSS = ROOT / "asset/monster/bamboo_spirit_lord"
BOSS_RAW = BOSS / "raw"
PALETTE = ROOT / "asset/character/Taoist/Idle/rotations"
PYTHON = sys.executable

DROP_SPECS = {
    "xp_small": 8,
    "xp_medium": 12,
    "xp_large": 16,
    "gold_coin": 10,
    "gold_pile": 16,
    "health_gourd": 16,
    "magnet": 16,
    "chest_common": 16,
    "chest_rare": 16,
    "chest_epic": 16,
    "chest_legendary": 16,
    "chest_mythic": 16,
}
DIRECTIONS = (
    "south", "south-east", "east", "north-east",
    "north", "north-west", "west", "south-west",
)


def run(*args: object) -> None:
    subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True)


def row_names(ids: tuple[str, ...]) -> tuple[str, ...]:
    names = []
    for drop_id in ids:
        names.extend((f"{drop_id}_idle", *(f"{drop_id}_collect_{index}" for index in range(4))))
    return tuple(names)


def slice_sheet(source: Path, output: Path, columns: int, rows: int, names: tuple[str, ...], inset: int = 4) -> None:
    run(
        PYTHON, "tools/asset/slice_sheet.py", source, output, columns, rows,
        f"--inset={inset}", *names,
    )


def pixelize(source: Path, output: Path, height: int, canvas: int | None = None, *, fixed: bool = False) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    args: list[object] = [PYTHON, "tools/asset/pixelize.py", source, output, height, PALETTE]
    if canvas is not None:
        args.append(canvas)
    if fixed:
        args.append("--fixed-cell")
    run(*args)


def remove_human_skin(path: Path) -> None:
    """Map model-invented skin pixels back to bark/ink so the boss stays a spirit."""
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    changed = 0
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a and r >= 72 and r > g * 1.18 and r > b * 1.35 and b < 105:
                luminance = (r + g + b) // 3
                replacement = (38, 55, 44, 255) if luminance >= 95 else (20, 31, 27, 255)
                pixels[x, y] = replacement
                changed += 1
    image.save(path)
    print(f"{path.relative_to(ROOT)}: remapped {changed} human-skin pixels to spirit bark")


def remove_magenta_glow(path: Path) -> None:
    """Remove a few purple key-light pixels the common chest carried off the key."""
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    changed = 0
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if (
                a and r > 120 and b > 120 and g < 110
                and abs(r - b) < 85 and min(r, b) - g > 55
            ):
                pixels[x, y] = (0, 0, 0, 0)
                changed += 1
    image.save(path)
    if changed:
        print(f"{path.relative_to(ROOT)}: removed {changed} retained chroma-glow pixels")


def process_drop_sheet(source: Path, cell_root: Path, ids: tuple[str, ...], rows: int, *, inset: int = 4) -> None:
    slice_sheet(source, cell_root, 5, rows, row_names(ids), inset)
    for drop_id in ids:
        pixelize(cell_root / f"{drop_id}_idle.png", ROOT / f"asset/drop/{drop_id}/idle.png", DROP_SPECS[drop_id], 24)
        for frame in range(4):
            pixelize(
                cell_root / f"{drop_id}_collect_{frame}.png",
                ROOT / f"asset/drop/{drop_id}/collect/{frame}.png",
                32,
                32,
                fixed=True,
            )


def main() -> None:
    process_drop_sheet(
        DROP_RAW / "xp_gold_sheet_higgsfield.png",
        DROP_RAW / "cells/xp_gold",
        ("xp_small", "xp_medium", "xp_large", "gold_coin", "gold_pile"),
        5,
    )
    # The backend returned an obvious 5x3 grid despite the requested 5x2. The second
    # magnet row is a duplicate variant and is deliberately not sliced or shipped.
    health_cells = DROP_RAW / "cells/health_magnet"
    names = (*row_names(("health_gourd", "magnet")), *("_" for _ in range(5)))
    slice_sheet(DROP_RAW / "health_magnet_sheet_higgsfield.png", health_cells, 5, 3, names, 12)
    for drop_id in ("health_gourd", "magnet"):
        pixelize(health_cells / f"{drop_id}_idle.png", ROOT / f"asset/drop/{drop_id}/idle.png", DROP_SPECS[drop_id], 24)
        for frame in range(4):
            pixelize(
                health_cells / f"{drop_id}_collect_{frame}.png",
                ROOT / f"asset/drop/{drop_id}/collect/{frame}.png",
                32,
                32,
                fixed=True,
            )
    process_drop_sheet(
        DROP_RAW / "chest_grades_sheet_higgsfield.png",
        DROP_RAW / "cells/chest_grades",
        ("chest_common", "chest_rare", "chest_epic", "chest_legendary", "chest_mythic"),
        5,
    )
    for path in (ROOT / "asset/drop/chest_common").rglob("*.png"):
        remove_magenta_glow(path)

    rotation_cells = BOSS_RAW / "boss_scale_rotation_cells"
    slice_sheet(
        BOSS_RAW / "boss_scale_rotations_retry_higgsfield.png",
        rotation_cells,
        4,
        2,
        DIRECTIONS,
        4,
    )
    for direction in DIRECTIONS:
        target = BOSS / f"rotations/{direction}.png"
        pixelize(rotation_cells / f"{direction}.png", target, 150, 192)
        remove_human_skin(target)
    pixelize(rotation_cells / "south.png", ROOT / "asset/monster/bamboo_spirit_lord.png", 150)
    remove_human_skin(ROOT / "asset/monster/bamboo_spirit_lord.png")

    death_cells = BOSS_RAW / "boss_scale_death_cells"
    slice_sheet(
        BOSS_RAW / "boss_scale_death_retry_higgsfield.png",
        death_cells,
        4,
        1,
        ("0", "1", "2", "3"),
        4,
    )
    for frame in range(4):
        target = BOSS / f"death/{frame}.png"
        pixelize(death_cells / f"{frame}.png", target, 192, 192, fixed=True)
        remove_human_skin(target)


if __name__ == "__main__":
    main()
