"""Build a compact overview of the eighteen raw folklore-monster death sheets."""
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
MONSTERS = (
    "gwimyeon_dokkaebi", "blue_dokkaebi", "gumiho_scout", "seonbi_wraith",
    "haetae_guardian", "dokkaebi_king", "cheonyeo_gwisin", "dalgyal_gwisin",
    "jeoseung_saja", "tomb_jangseung", "imugi_whelp", "ancient_imugi",
    "wonhon", "dokkaebi_fire", "shadow_dokkaebi", "fox_spirit", "bulgasari", "gumiho",
)
CELL = (400, 225)
LABEL = 22
COLS = 3


def main() -> None:
    rows = (len(MONSTERS) + COLS - 1) // COLS
    overview = Image.new("RGB", (CELL[0] * COLS, (CELL[1] + LABEL) * rows), (35, 37, 43))
    draw = ImageDraw.Draw(overview)
    for index, monster_id in enumerate(MONSTERS):
        path = ROOT / f"asset/monster/{monster_id}/raw/death_sheet_2026_higgsfield.png"
        with Image.open(path).convert("RGB") as source:
            source.thumbnail(CELL)
            x = (index % COLS) * CELL[0]
            y = (index // COLS) * (CELL[1] + LABEL)
            overview.paste(source, (x + (CELL[0] - source.width) // 2, y + LABEL))
            draw.text((x + 4, y + 4), monster_id, fill=(255, 244, 219))
    output = ROOT / "asset/monster/raw/death_sheet_overview.png"
    overview.save(output)
    print(output.relative_to(ROOT))

    strip_width = 92 * 4
    final = Image.new("RGBA", (strip_width * COLS, 110 * rows), (45, 47, 54, 255))
    draw = ImageDraw.Draw(final)
    for index, monster_id in enumerate(MONSTERS):
        x = (index % COLS) * strip_width
        y = (index // COLS) * 110
        draw.text((x + 4, y + 2), monster_id, fill=(255, 244, 219, 255))
        for frame in range(4):
            with Image.open(ROOT / f"asset/monster/{monster_id}/death/{frame}.png").convert("RGBA") as sprite:
                final.alpha_composite(sprite, (x + frame * 92, y + 18))
    final_output = ROOT / "asset/monster/raw/death_frames_overview.png"
    final.save(final_output)
    print(final_output.relative_to(ROOT))


if __name__ == "__main__":
    main()
