"""Passive stat icons (N9-10b): 32px-grid pixel glyphs exported 16x to
512px, matching the weapon-icon convention (asset/ui/weapon_icons). One
bold shape per stat on the dark card well; ink outline, palette fills.
Replaces the N3-13 letter-glyph fallback for every OFFERABLE passive.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
GRID = 32
SCALE = 16

INK = (26, 22, 19, 255)
STEEL = (214, 220, 228, 255)
GOLD = (255, 217, 74, 255)
VERMILION = (191, 64, 42, 255)
WOOD = (226, 160, 87, 255)
GREEN = (88, 216, 88, 255)
BLUE = (110, 170, 230, 255)
PAPER = (240, 228, 196, 255)


def canvas() -> tuple:
    img = Image.new("RGBA", (GRID, GRID), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def attack_damage() -> Image.Image:
    img, d = canvas()
    d.polygon([(8, 24), (22, 6), (26, 10), (12, 28)], fill=STEEL, outline=INK)
    d.line([6, 22, 12, 28], fill=GOLD, width=3)
    d.rectangle([4, 26, 8, 30], fill=WOOD, outline=INK)
    return img


def attack_speed() -> Image.Image:
    img, d = canvas()
    for x in (6, 14, 22):
        d.polygon([(x, 8), (x + 7, 16), (x, 24), (x + 3, 16)], fill=VERMILION, outline=INK)
    return img


def move_speed() -> Image.Image:
    img, d = canvas()
    d.polygon([(14, 6), (26, 16), (14, 26), (18, 16)], fill=GREEN, outline=INK)
    for y in (10, 16, 22):
        d.line([4, y, 11, y], fill=GREEN, width=2)
    return img


def max_hp() -> Image.Image:
    img, d = canvas()
    d.ellipse([5, 6, 16, 17], fill=VERMILION, outline=INK)
    d.ellipse([16, 6, 27, 17], fill=VERMILION, outline=INK)
    d.polygon([(6, 14), (26, 14), (16, 28)], fill=VERMILION, outline=INK)
    d.rectangle([8, 12, 24, 15], fill=VERMILION)
    d.ellipse([9, 8, 13, 12], fill=(230, 120, 100, 255))
    return img


def magnet_radius() -> Image.Image:
    img, d = canvas()
    d.arc([6, 4, 26, 24], 180, 360, fill=INK, width=8)
    d.arc([8, 6, 24, 22], 180, 360, fill=VERMILION, width=4)
    d.rectangle([6, 14, 12, 26], fill=VERMILION, outline=INK)
    d.rectangle([20, 14, 26, 26], fill=VERMILION, outline=INK)
    d.rectangle([6, 22, 12, 26], fill=STEEL, outline=INK)
    d.rectangle([20, 22, 26, 26], fill=STEEL, outline=INK)
    return img


def xp_gain() -> Image.Image:
    img, d = canvas()
    d.polygon(
        [(16, 3), (19, 12), (28, 12), (21, 18), (24, 28),
         (16, 22), (8, 28), (11, 18), (4, 12), (13, 12)],
        fill=GOLD, outline=INK,
    )
    return img


def luck() -> Image.Image:
    img, d = canvas()
    for cx, cy in ((11, 11), (21, 11), (11, 21), (21, 21)):
        d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=GREEN, outline=INK)
    d.rectangle([14, 14, 18, 18], fill=GREEN)
    d.line([16, 20, 20, 29], fill=INK, width=2)
    return img


def projectile_speed() -> Image.Image:
    img, d = canvas()
    d.polygon([(6, 20), (20, 6), (26, 12), (12, 26)], fill=BLUE, outline=INK)
    d.polygon([(20, 6), (27, 5), (26, 12)], fill=STEEL, outline=INK)
    for y in (24, 28):
        d.line([3, y, 10, y], fill=BLUE, width=2)
    return img


def defense() -> Image.Image:
    img, d = canvas()
    d.polygon(
        [(16, 3), (28, 8), (28, 17), (16, 29), (4, 17), (4, 8)],
        fill=STEEL, outline=INK,
    )
    d.polygon([(16, 7), (24, 10), (24, 16), (16, 24), (8, 16), (8, 10)], fill=BLUE)
    return img


def projectile_count() -> Image.Image:
    img, d = canvas()
    for sx, sy in ((6, 24), (13, 26), (20, 24)):
        d.polygon(
            [(sx, sy), (sx + 6, sy - 18), (sx + 9, sy - 15), (sx + 3, sy + 3)],
            fill=PAPER, outline=INK,
        )
    return img


ICONS = {
    "attack_damage": attack_damage,
    "attack_speed": attack_speed,
    "move_speed": move_speed,
    "max_hp": max_hp,
    "magnet_radius": magnet_radius,
    "xp_gain": xp_gain,
    "luck": luck,
    "projectile_speed": projectile_speed,
    "defense": defense,
    "projectile_count": projectile_count,
}


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in ICONS.items():
        big = fn().resize((GRID * SCALE, GRID * SCALE), Image.NEAREST)
        big.save(OUT / f"{name}.png")
        print(name)
