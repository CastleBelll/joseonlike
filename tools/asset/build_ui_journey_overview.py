"""Build labelled contact sheets for visual review of the UI-journey assets."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
UI = ROOT / "asset/ui"
OUT = UI / "raw/journey"
BG = (37, 38, 46, 255)
TEXT = (245, 238, 222, 255)


def page(paths: list[str], output: str, *, columns: int, cell: tuple[int, int]) -> None:
    rows = (len(paths) + columns - 1) // columns
    image = Image.new("RGBA", (columns * cell[0], rows * cell[1]), BG)
    draw = ImageDraw.Draw(image)
    for index, relative in enumerate(paths):
        x = (index % columns) * cell[0]
        y = (index // columns) * cell[1]
        draw.text((x + 6, y + 5), relative, fill=TEXT)
        sprite = Image.open(UI / relative).convert("RGBA")
        scale = min((cell[0] - 12) / sprite.width, (cell[1] - 26) / sprite.height, 4.0)
        shown = sprite.resize(
            (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale))),
            Image.Resampling.NEAREST,
        )
        image.alpha_composite(
            shown,
            (x + (cell[0] - shown.width) // 2, y + 22 + (cell[1] - 22 - shown.height) // 2),
        )
    target = OUT / output
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target)
    print(target.relative_to(ROOT))


def main() -> None:
    icons = [
        *(f"main/{name}.png" for name in ("start", "continue", "settings", "credits", "quit")),
        *(f"profile/{name}.png" for name in ("new_profile", "returning_profile", "delete_profile")),
        *(f"character/classes/{name}.png" for name in ("taoist", "warrior", "archer")),
        *(f"area/icons/{name}.png" for name in ("bamboo_forest", "abandoned_temple", "locked", "difficulty_1", "difficulty_2", "difficulty_3", "reward", "boss")),
        *(f"camp/icons/{name}.png" for name in ("workshop", "archive", "training_ground", "shrine")),
        *(f"hud/icons/{name}.png" for name in ("hp", "boss", "timer", "pause", "damage", "pickup", "kills", "level")),
        *(f"settings/{name}.png" for name in ("master_audio", "music", "effects", "language")),
        *(f"level_up/{name}.png" for name in ("tier_common", "tier_rare", "tier_legendary")),
        *(f"meta/{name}.png" for name in ("quest", "progress", "claimed", "unclaimed")),
        *(f"results/{name}.png" for name in ("new_unlock", "reward_chest")),
        *(f"monetization/{name}.png" for name in ("rewarded_ad", "continue_after_death", "currency")),
    ]
    page(icons, "ui_icons_overview.png", columns=6, cell=(150, 104))

    illustrations = [
        *(f"character/portraits/{name}.png" for name in ("taoist", "warrior", "archer")),
        "area/cards/bamboo_forest.png", "area/cards/abandoned_temple.png",
        *(f"camp/interiors/{name}.png" for name in ("workshop", "archive", "training_ground", "shrine")),
        "results/victory_banner.png", "results/defeat_banner.png",
    ]
    page(illustrations, "ui_illustrations_overview.png", columns=3, cell=(300, 190))

    furniture = [
        path.relative_to(UI).as_posix()
        for path in sorted(UI.rglob("*.png"))
        if "raw" not in path.parts and (
            path.name.endswith("_9slice.png") or path.name.startswith("toggle_") or path.name == "slider_knob.png"
        )
    ]
    page(furniture, "ui_furniture_overview.png", columns=4, cell=(220, 130))


if __name__ == "__main__":
    main()
