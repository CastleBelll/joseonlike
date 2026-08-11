"""Slice and pixelize the UI-journey Higgsfield sheets.

The backend sometimes chose a different obvious grid than requested.  The audited layouts
below deliberately describe what is visible in the retained raw sheets instead of pretending
the prompt's grid was obeyed.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "asset/ui/raw/journey"
CELLS = RAW / "cells"
PALETTE = ROOT / "asset/character/Taoist/Idle/rotations"
PYTHON = sys.executable


def run(*args: object) -> None:
    subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True)


def slice_sheet(name: str, cols: int, rows: int, names: tuple[str, ...], inset: int = 4) -> Path:
    output = CELLS / name
    run(
        PYTHON, "tools/asset/slice_sheet.py",
        RAW / f"{name}_sheet_higgsfield.png", output, cols, rows,
        f"--inset={inset}", *names,
    )
    return output


def pixelize(source: Path, target: str, height: int, canvas: str | int = 32) -> None:
    output = ROOT / target
    output.parent.mkdir(parents=True, exist_ok=True)
    run(PYTHON, "tools/asset/pixelize.py", source, output, height, PALETTE, canvas)


def main() -> None:
    icons = slice_sheet(
        "title_profile_icons", 4, 2,
        ("start", "continue", "settings", "credits", "quit", "new_profile", "returning_profile", "delete_profile"),
    )
    for name in ("start", "continue", "settings", "credits", "quit"):
        pixelize(icons / f"{name}.png", f"asset/ui/main/{name}.png", 28)
    for name in ("new_profile", "returning_profile", "delete_profile"):
        pixelize(icons / f"{name}.png", f"asset/ui/profile/{name}.png", 28)

    character = slice_sheet(
        "character_portraits", 3, 2,
        ("taoist_portrait", "warrior_portrait", "archer_portrait", "taoist_class", "warrior_class", "archer_class"),
    )
    for name in ("taoist", "warrior", "archer"):
        pixelize(character / f"{name}_portrait.png", f"asset/ui/character/portraits/{name}.png", 96, 128)
        pixelize(character / f"{name}_class.png", f"asset/ui/character/classes/{name}.png", 28)

    area_cards = slice_sheet("area_cards", 2, 1, ("bamboo_forest", "abandoned_temple"), 8)
    for name in ("bamboo_forest", "abandoned_temple"):
        pixelize(area_cards / f"{name}.png", f"asset/ui/area/cards/{name}.png", 128, "224x128")

    area = slice_sheet(
        "area_indicators", 4, 2,
        ("bamboo_forest", "abandoned_temple", "locked", "difficulty_1",
         "difficulty_2", "difficulty_3", "reward", "boss"),
    )
    for name in ("bamboo_forest", "abandoned_temple", "locked", "difficulty_1", "difficulty_2", "difficulty_3", "reward", "boss"):
        pixelize(area / f"{name}.png", f"asset/ui/area/icons/{name}.png", 28)

    # Audited raw layout is 2x2 despite the requested 4x1.
    interiors = slice_sheet("camp_interiors", 2, 2, ("workshop", "archive", "training_ground", "shrine"), 8)
    for name in ("workshop", "archive", "training_ground", "shrine"):
        pixelize(interiors / f"{name}.png", f"asset/ui/camp/interiors/{name}.png", 112, "224x112")

    # Audited raw layout is 4x2; the second row is unrequested material and remains raw only.
    camp_icons = slice_sheet(
        "camp_icons", 4, 2,
        ("workshop", "archive", "training_ground", "shrine", "_", "_", "_", "_"),
    )
    for name in ("workshop", "archive", "training_ground", "shrine"):
        pixelize(camp_icons / f"{name}.png", f"asset/ui/camp/icons/{name}.png", 28)

    # Top two rows use five obvious columns (the model added a spare cell); bottom uses four.
    hud = slice_sheet(
        "hud_settings_icons", 5, 3,
        ("hp", "boss", "timer", "pause", "_", "damage", "pickup", "kills", "level", "_"),
    )
    settings = slice_sheet(
        "hud_settings_icons", 4, 3,
        ("_", "_", "_", "_", "_", "_", "_", "_", "master_audio", "music", "effects", "language_raw"),
    )
    for name in ("hp", "boss", "timer", "pause", "damage", "pickup", "kills", "level"):
        pixelize(hud / f"{name}.png", f"asset/ui/hud/icons/{name}.png", 28)
    run(
        PYTHON, "tools/asset/clean_tiny_components.py",
        ROOT / "asset/ui/hud/icons/kills.png", "--min-pixels", 34,
    )
    for name in ("master_audio", "music", "effects"):
        pixelize(settings / f"{name}.png", f"asset/ui/settings/{name}.png", 28)
    # The generated language cell contained malformed pseudo-Hangul. It is retained raw but
    # never ships; build_ui_furniture.py supplies a text-free speech-bubble replacement.

    meta = slice_sheet(
        "results_meta_ad_icons", 4, 3,
        ("tier_common", "tier_rare", "tier_legendary", "quest", "progress", "claimed",
         "unclaimed", "new_unlock", "rewarded_ad", "continue_after_death", "currency", "reward_chest"),
    )
    targets = {
        "tier_common": "asset/ui/level_up/tier_common.png",
        "tier_rare": "asset/ui/level_up/tier_rare.png",
        "tier_legendary": "asset/ui/level_up/tier_legendary.png",
        "quest": "asset/ui/meta/quest.png",
        "progress": "asset/ui/meta/progress.png",
        "claimed": "asset/ui/meta/claimed.png",
        "unclaimed": "asset/ui/meta/unclaimed.png",
        "new_unlock": "asset/ui/results/new_unlock.png",
        "rewarded_ad": "asset/ui/monetization/rewarded_ad.png",
        "continue_after_death": "asset/ui/monetization/continue_after_death.png",
        "currency": "asset/ui/monetization/currency.png",
        "reward_chest": "asset/ui/results/reward_chest.png",
    }
    for name, target in targets.items():
        pixelize(meta / f"{name}.png", target, 28)

    banners = slice_sheet("result_banners", 2, 1, ("victory", "defeat"), 4)
    for name in ("victory", "defeat"):
        pixelize(banners / f"{name}.png", f"asset/ui/results/{name}_banner.png", 128, "256x128")

    # Deterministic stretch furniture plus text-free replacements for the four generated
    # cells rejected during visual review (pseudo-Hangul and horizontal "pause" bars).
    run(PYTHON, "tools/asset/build_ui_furniture.py")


if __name__ == "__main__":
    main()
