"""Wire the owner's new_asset/skill drop into the game (N9-17).

The owner dropped 16 authored 512x512 icons. This copies them to their
game paths under their English ids — the repo never loads new_asset/
directly (ASSET_REQUIREMENTS.md). Sources stay untouched.

Targets:
- 10 passive stat icons  -> asset/ui/passive_icons/<passive_id>.png
- 법검 weapon icon        -> asset/ui/weapon_icons/beopgeom.png
- 상자 chest sprite       -> asset/pickups/chest.png       (in-world, 32px)
- 폭탄 nuke pickup        -> asset/pickups/nuke.png        (in-world, 24px)
- 모닥불/모루/비석 props  -> asset/stages/bamboo_forest/props/<id>.png
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "new_asset" / "skill"

# UI icons keep the 512px convention of the existing sets.
UI_ICONS = {
    "경험치 획득.png": ("ui/passive_icons", "xp_gain", 512),
    "공격력 증가.png": ("ui/passive_icons", "attack_damage", 512),
    "공격속도.png": ("ui/passive_icons", "attack_speed", 512),
    "끌어당김.png": ("ui/passive_icons", "magnet_radius", 512),
    "이동속도.png": ("ui/passive_icons", "move_speed", 512),
    "체력 회복률 증가.png": ("ui/passive_icons", "hp_regen", 512),
    "최대 생명력 증가.png": ("ui/passive_icons", "max_hp", 512),
    "투사체 증가.png": ("ui/passive_icons", "projectile_count", 512),
    "피격 데미지 감소(방비).png": ("ui/passive_icons", "defense", 512),
    "행운.png": ("ui/passive_icons", "luck", 512),
    "법검.png": ("ui/weapon_icons", "beopgeom", 512),
}

# In-world sprites are downscaled to their logical footprint (NEAREST, so
# the pixel grid survives) — the entities draw them at 1:1.
WORLD_SPRITES = {
    "상자.png": ("pickups", "chest", 32),
    "폭탄.png": ("pickups", "nuke", 24),
    "모닥불.png": ("stages/bamboo_forest/props", "campfire", 40),
    "모루.png": ("stages/bamboo_forest/props", "anvil", 36),
    "비석.png": ("stages/bamboo_forest/props", "stone_marker", 44),
}


def convert(source: Path, target: Path, size: int) -> None:
    with Image.open(source) as raw:
        image = raw.convert("RGBA")
    if image.size != (size, size):
        image = image.resize((size, size), Image.NEAREST)
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target)
    print(f"{source.name} -> {target.relative_to(ROOT)} {image.size}")


if __name__ == "__main__":
    for filename, (folder, asset_id, size) in {**UI_ICONS, **WORLD_SPRITES}.items():
        source = SRC / filename
        if not source.exists():
            raise FileNotFoundError(f"missing owner drop: {source}")
        convert(source, ROOT / "asset" / folder / f"{asset_id}.png", size)
