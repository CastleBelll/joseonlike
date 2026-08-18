"""Build projectile travel sprites and elemental hit strips (N9-3f).

Sources are owner-dropped packs in ``new_asset/`` and are never loaded by
Godot directly. Travel art is cropped from native 24x24 cells without
resampling; every selected source points right so Projectile can rotate it to
the flight direction. Hit effects retain their native 64x64 frame canvases and
remove only fully transparent trailing frames from the source rows.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
BULLETS = ROOT / "new_asset" / "500 Bullet 24x24 Free"
IMPACTS = ROOT / "new_asset" / "Retro Impact Effect Pack 5"
CELL = 24
IMPACT_CELL = 64


@dataclass(frozen=True)
class TravelSpec:
    source: str
    column: int
    row: int


# Peak travel frames from the source animations. Related weapons share a
# palette but use progressively longer/brighter silhouettes.
TRAVEL: dict[str, TravelSpec] = {
    "old_talisman": TravelSpec("Bullet 24x24 Free Part 2C.png", 2, 13),
    "fire_talisman": TravelSpec("Bullet 24x24 Free Part 2A.png", 2, 2),
    "phoenix_talisman": TravelSpec("Bullet 24x24 Free Part 2A.png", 3, 2),
    "beopgeom": TravelSpec("Bullet 24x24 Free Part 3C.png", 3, 7),
    "bongmageom": TravelSpec("Bullet 24x24 Free Part 3C.png", 3, 0),
    "hwabu": TravelSpec("Bullet 24x24 Free Part 2A.png", 2, 3),
    "hwaryeongbu": TravelSpec("Bullet 24x24 Free Part 2A.png", 2, 4),
    "noebu": TravelSpec("Bullet 24x24 Free Part 2B.png", 2, 2),
    "noejeongbu": TravelSpec("Bullet 24x24 Free Part 2B.png", 3, 2),
    "sal": TravelSpec("Bullet 24x24 Free Part 2C.png", 2, 2),
    "gwisal": TravelSpec("Bullet 24x24 Free Part 2C.png", 3, 2),
}


@dataclass(frozen=True)
class ImpactSpec:
    variant: str
    row: int


# Pack variants: A fire-orange, B violet, C cyan, F neutral silver.
# Different rows keep lightning, curse, and ordinary strikes from reading as
# simple recolors of the fire burst.
IMPACT: dict[str, ImpactSpec] = {
    "hit_fire": ImpactSpec("A", 15),
    "hit_lightning": ImpactSpec("C", 9),
    "hit_curse": ImpactSpec("B", 13),
    "hit_neutral": ImpactSpec("F", 13),
}


def build_travel(asset_id: str, spec: TravelSpec) -> None:
    with Image.open(BULLETS / spec.source) as sheet:
        source = sheet.convert("RGBA")
    left = spec.column * CELL
    top = spec.row * CELL
    sprite = source.crop((left, top, left + CELL, top + CELL))
    used = sprite.getbbox()
    if used is None:
        raise ValueError(f"{asset_id}: selected source cell is transparent")
    # Cropping transparent padding changes no source pixel and makes the
    # Sprite2D pivot the visible projectile rather than the sheet cell.
    sprite.crop(used).save(OUT / "travel" / f"{asset_id}.png")


def build_impact(effect_id: str, spec: ImpactSpec) -> None:
    source_path = IMPACTS / f"Retro Impact Effect Pack 5 {spec.variant}.png"
    with Image.open(source_path) as sheet:
        source = sheet.convert("RGBA")
    top = spec.row * IMPACT_CELL
    frames: list[Image.Image] = []
    for column in range(source.width // IMPACT_CELL):
        frame = source.crop((
            column * IMPACT_CELL,
            top,
            (column + 1) * IMPACT_CELL,
            top + IMPACT_CELL,
        ))
        if frame.getbbox() is not None:
            frames.append(frame)
    if not frames:
        raise ValueError(f"{effect_id}: selected source row is transparent")
    strip = Image.new("RGBA", (len(frames) * IMPACT_CELL, IMPACT_CELL))
    for column, frame in enumerate(frames):
        strip.alpha_composite(frame, (column * IMPACT_CELL, 0))
    strip.save(ROOT / "asset" / "effect" / f"{effect_id}.png")


if __name__ == "__main__":
    (OUT / "travel").mkdir(parents=True, exist_ok=True)
    (ROOT / "asset" / "effect").mkdir(parents=True, exist_ok=True)
    for name, travel_spec in TRAVEL.items():
        build_travel(name, travel_spec)
    for name, impact_spec in IMPACT.items():
        build_impact(name, impact_spec)
    for path in sorted((OUT / "travel").glob("*.png")):
        with Image.open(path) as done:
            print(path.name, done.size)
    for name in IMPACT:
        path = ROOT / "asset" / "effect" / f"{name}.png"
        with Image.open(path) as done:
            print(path.name, done.size)
