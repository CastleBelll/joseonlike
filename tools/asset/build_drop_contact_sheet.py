"""Build a labelled visual audit sheet for idle pickups and collect frames."""
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
DROP = ROOT / "asset/drop"
IDS = (
    "xp_small", "xp_medium", "xp_large", "gold_coin", "gold_pile",
    "health_gourd", "magnet", "chest_common", "chest_rare", "chest_epic",
    "chest_legendary", "chest_mythic",
)
SCALE = 3
CELL = 108
LABEL = 19


def main() -> None:
    sheet = Image.new("RGBA", (CELL * 5, (CELL + LABEL) * len(IDS)), (45, 47, 54, 255))
    draw = ImageDraw.Draw(sheet)
    for row, drop_id in enumerate(IDS):
        y = row * (CELL + LABEL)
        draw.text((4, y + 3), drop_id, fill=(245, 238, 222, 255))
        paths = [DROP / drop_id / "idle.png", *(DROP / drop_id / "collect" / f"{frame}.png" for frame in range(4))]
        for column, path in enumerate(paths):
            sprite = Image.open(path).convert("RGBA")
            shown = sprite.resize((sprite.width * SCALE, sprite.height * SCALE), Image.Resampling.NEAREST)
            x = column * CELL + (CELL - shown.width) // 2
            cell_y = y + LABEL + (CELL - shown.height) // 2
            sheet.alpha_composite(shown, (x, cell_y))
            draw.rectangle((column * CELL, y + LABEL, (column + 1) * CELL - 1, y + LABEL + CELL - 1), outline=(90, 94, 105, 255))
    output = DROP / "raw/drop_contact_sheet.png"
    sheet.save(output)
    print(output.relative_to(ROOT))


if __name__ == "__main__":
    main()
