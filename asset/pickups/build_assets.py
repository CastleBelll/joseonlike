"""Pickup sprite extraction (N6-5).

Sources are owner-dropped packs in new_asset/ (never loaded by the game):
- health.png <- "Pixel UI pack 3/00.png" full red heart (stars/hearts row)
- nuke.png   <- "Trap and Weapon/Trap and Weapon/Bomb.png" frame 0

The gold pickup reuses asset/ui/hud/coin.png (already palette-true); no
magnet or chest art exists in the current packs (ASSET_REQUIREMENTS.md).

Each sprite is cropped to its used rect, desaturated a touch and darkened
slightly so it sits in the night palette, and saved at native pixel size —
the game draws it 1:1 with NEAREST filtering next to the 38px character.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
DESATURATE = 0.85
DARKEN = 0.95


def night_tint(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(DESATURATE)
    rgb = ImageEnhance.Brightness(rgb).enhance(DARKEN)
    tinted = rgb.convert("RGBA")
    tinted.putalpha(image.getchannel("A"))
    return tinted


def build_health() -> None:
    sheet = Image.open(
        ROOT / "new_asset" / "Pixel UI pack 3" / "00.png"
    ).convert("RGBA")
    heart = sheet.crop((112, 106, 130, 128))
    heart = heart.crop(heart.getbbox())
    night_tint(heart).save(OUT / "health.png")


def build_nuke() -> None:
    sheet = Image.open(
        ROOT / "new_asset" / "Trap and Weapon" / "Trap and Weapon" / "Bomb.png"
    ).convert("RGBA")
    bomb = sheet.crop((0, 0, 32, 32))
    bomb = bomb.crop(bomb.getbbox())
    night_tint(bomb).save(OUT / "nuke.png")


if __name__ == "__main__":
    build_health()
    build_nuke()
    for name in ("health.png", "nuke.png"):
        with Image.open(OUT / name) as done:
            print(name, done.size)
