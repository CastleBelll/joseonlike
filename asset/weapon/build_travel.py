"""Build projectile travel sprites and elemental hit strips (N9-3f, art
pass N9-5).

Sources are owner-dropped packs in ``new_asset/owner/`` and are never loaded by
Godot directly. Every sprite points right so Projectile can rotate it to the
flight direction.

N9-5 owner feedback: the first pass picked chevron/tracer bullet rows that
read as rockets. Charms now use the packs' round energy-orb frames
(fire/lightning/curse orbs, native pixels), while the paper talismans and
ritual swords are hand-drawn here — the packs carry no paper or blade
shapes, and a talisman must read as a talisman.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
BULLETS = ROOT / "new_asset" / "owner" / "500 Bullet 24x24 Free"
IMPACTS = ROOT / "new_asset" / "owner" / "Retro Impact Effect Pack 5"
CELL = 24
IMPACT_CELL = 64

# Palette (UiPalette-adjacent, night-legible)
INK = (26, 22, 19, 255)
PAPER = (240, 228, 196, 255)
PAPER_WARM = (248, 214, 150, 255)
PAPER_GOLD = (255, 226, 130, 255)
VERMILION = (191, 64, 42, 255)
EMBER = (255, 140, 60, 255)
FLAME = (255, 90, 40, 255)
STEEL = (214, 220, 228, 255)
STEEL_DIM = (150, 158, 170, 255)
SEAL_VIOLET = (170, 110, 220, 255)
GUARD_GOLD = (196, 154, 61, 255)
GRIP_WOOD = (110, 67, 34, 255)


@dataclass(frozen=True)
class TravelSpec:
    source: str
    column: int
    row: int


# Round energy-orb frames (right half of the orb animation rows) — never the
# chevron/tracer rows, those read as missiles (N9-5 owner report).
TRAVEL: dict[str, TravelSpec] = {
    "hwabu": TravelSpec("Bullet 24x24 Free Part 1A.png", 10, 0),
    "hwaryeongbu": TravelSpec("Bullet 24x24 Free Part 1A.png", 12, 0),
    "noebu": TravelSpec("Bullet 24x24 Free  Part 1B.png", 10, 0),
    "noejeongbu": TravelSpec("Bullet 24x24 Free  Part 1B.png", 12, 0),
    "sal": TravelSpec("Bullet 24x24 Free Part 1A.png", 10, 10),
    "gwisal": TravelSpec("Bullet 24x24 Free Part 1A.png", 12, 10),
}


@dataclass(frozen=True)
class ImpactSpec:
    variant: str
    row: int


# Pack variants: A fire-orange, B violet, C cyan, F neutral silver.
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
    sprite.crop(used).save(OUT / "travel" / f"{asset_id}.png")


def draw_talisman(body: tuple, band: tuple, glow: tuple | None) -> Image.Image:
    """Horizontal hanji slip pointing right: ink outline, colored head band
    at the leading edge, two ink glyph strokes, optional trailing ember."""
    img = Image.new("RGBA", (18, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 1, 16, 8], fill=body, outline=INK)
    d.rectangle([13, 2, 15, 7], fill=band)
    # glyph strokes (read as brushed characters at this size)
    d.line([5, 3, 9, 3], fill=INK)
    d.line([5, 5, 10, 5], fill=INK)
    d.line([7, 3, 7, 6], fill=INK)
    if glow is not None:
        d.point([(1, 4), (1, 5), (0, 4)], fill=glow)
        d.point([(2, 3), (2, 6)], fill=glow)
    return img


def draw_sword(blade: tuple, blade_dim: tuple, guard: tuple) -> Image.Image:
    """Blade pointing right: tapered edge, dark outline, guard + short grip."""
    img = Image.new("RGBA", (20, 7), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # grip
    d.rectangle([0, 2, 3, 4], fill=GRIP_WOOD, outline=INK)
    # guard
    d.rectangle([4, 0, 5, 6], fill=guard, outline=INK)
    # blade body tapering to a point at x=19
    d.polygon([(6, 1), (16, 1), (19, 3), (16, 5), (6, 5)], fill=blade, outline=INK)
    d.line([7, 3, 16, 3], fill=blade_dim)
    return img


DRAWN: dict[str, Image.Image] = {
    "old_talisman": draw_talisman(PAPER, VERMILION, None),
    "fire_talisman": draw_talisman(PAPER_WARM, FLAME, EMBER),
    "phoenix_talisman": draw_talisman(PAPER_GOLD, FLAME, (255, 200, 90, 255)),
    "beopgeom": draw_sword(STEEL, STEEL_DIM, GUARD_GOLD),
    "bongmageom": draw_sword(SEAL_VIOLET, (120, 80, 170, 255), GUARD_GOLD),
}


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
    for name, drawn in DRAWN.items():
        drawn.save(OUT / "travel" / f"{name}.png")
    for name, impact_spec in IMPACT.items():
        build_impact(name, impact_spec)
    for path in sorted((OUT / "travel").glob("*.png")):
        with Image.open(path) as done:
            print(path.name, done.size)
