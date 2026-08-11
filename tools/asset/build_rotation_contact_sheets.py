"""Build deterministic contact sheets for manual directional-facing review.

Every row is ordered clockwise from south:
south, south-east, east, north-east, north, north-west, west, south-west.
The per-set sheets and paged overview live under ``asset/rotation_audit`` so
the exact pixels that received human review stay available with the assets.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "asset" / "rotation_audit"
DIRECTIONS = (
    "south", "south-east", "east", "north-east",
    "north", "north-west", "west", "south-west",
)
CELL = 92
LABEL_HEIGHT = 18
ROW_LABEL_WIDTH = 152
PAGE_ROWS = 8


def rotation_sets() -> list[tuple[str, Path]]:
    sets = []
    for character in ("Taoist", "Warrior", "Archer"):
        sets.append((character, ROOT / "asset" / "character" / character / "Idle" / "rotations"))
    monster_root = ROOT / "asset" / "monster"
    for rotations in sorted(monster_root.glob("*/rotations")):
        sets.append((rotations.parent.name, rotations))
    return sets


def checker(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGBA", size, (102, 106, 116, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], 8):
        for x in range(0, size[0], 8):
            if (x // 8 + y // 8) % 2:
                draw.rectangle((x, y, x + 7, y + 7), fill=(118, 122, 132, 255))
    return image


def contact_sheet(name: str, directory: Path) -> Image.Image:
    sheet = checker((CELL * len(DIRECTIONS), CELL + LABEL_HEIGHT))
    draw = ImageDraw.Draw(sheet)
    for index, direction in enumerate(DIRECTIONS):
        path = directory / f"{direction}.png"
        if not path.exists():
            raise SystemExit(f"missing {path.relative_to(ROOT)}")
        sprite = Image.open(path).convert("RGBA")
        if sprite.size != (CELL, CELL):
            raise SystemExit(f"{path.relative_to(ROOT)}: expected 92x92, got {sprite.size}")
        x = index * CELL
        sheet.alpha_composite(sprite, (x, LABEL_HEIGHT))
        draw.text((x + 3, 3), direction, fill=(255, 255, 255, 255), stroke_width=1, stroke_fill=(0, 0, 0, 255))
        draw.line((x, 0, x, sheet.height), fill=(35, 37, 43, 255))
    return sheet


def main() -> None:
    contact_root = OUTPUT / "contact_sheets"
    contact_root.mkdir(parents=True, exist_ok=True)
    rows = []
    for name, directory in rotation_sets():
        sheet = contact_sheet(name, directory)
        path = contact_root / f"{name}.png"
        sheet.save(path)
        rows.append((name, sheet))
        print(f"{directory.relative_to(ROOT)} -> {path.relative_to(ROOT)}")

    for page_index in range(0, len(rows), PAGE_ROWS):
        page_rows = rows[page_index:page_index + PAGE_ROWS]
        width = ROW_LABEL_WIDTH + CELL * len(DIRECTIONS)
        row_height = CELL + LABEL_HEIGHT
        page = Image.new("RGBA", (width, row_height * len(page_rows)), (45, 47, 54, 255))
        draw = ImageDraw.Draw(page)
        for row_index, (name, sheet) in enumerate(page_rows):
            y = row_index * row_height
            draw.text((6, y + 46), name, fill=(255, 244, 219, 255), stroke_width=1, stroke_fill=(0, 0, 0, 255))
            page.alpha_composite(sheet, (ROW_LABEL_WIDTH, y))
        page_path = OUTPUT / f"overview_{page_index // PAGE_ROWS}.png"
        page.save(page_path)
        print(f"wrote {page_path.relative_to(ROOT)} ({len(page_rows)} sets)")


if __name__ == "__main__":
    main()
