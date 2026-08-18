"""Passive stat icons (N9-10b, redrawn N9-13): hand-mapped 16x16 pixel
glyphs (1px ink outline, 2-tone fills with a shade edge) exported 32x to
512px. The first pass used PIL shape primitives at 32px and read as
broken/mismatched on the card wells (owner report) — explicit pixel maps
give clean, chunky glyphs that sit with the game's pixel art.

Legend: . transparent / K ink / W white / P paper / G gold / g gold shade
V vermilion / v vermilion shade / S steel / s steel shade / B blue /
b blue shade / N green / n green shade / O wood / o wood shade
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent
SCALE = 32

COLORS = {
    ".": None,
    "K": (26, 22, 19, 255),
    "W": (255, 255, 250, 255),
    "P": (240, 228, 196, 255),
    "G": (255, 217, 74, 255),
    "g": (196, 154, 61, 255),
    "V": (216, 90, 60, 255),
    "v": (160, 48, 32, 255),
    "S": (214, 220, 228, 255),
    "s": (150, 158, 170, 255),
    "B": (110, 170, 230, 255),
    "b": (66, 110, 170, 255),
    "N": (110, 220, 110, 255),
    "n": (58, 150, 70, 255),
    "O": (226, 160, 87, 255),
    "o": (150, 96, 46, 255),
}

ICONS = {
    # 공격력: upright sword — steel blade, gold guard, wood grip.
    "attack_damage": [
        ".......KK.......",
        "......KWSK......",
        "......KWSK......",
        "......KWSK......",
        "......KWSK......",
        "......KWSK......",
        "......KWSK......",
        "......KWSK......",
        "......KWsK......",
        "...KKKKWsKKKK...",
        "...KGGGGGGGgK...",
        "...KKKKOoKKKK...",
        "......KOoK......",
        "......KOoK......",
        ".....KGGgK......",
        ".....KKKKK......",
    ],
    # 공격 속도: double chevron dash.
    "attack_speed": [
        "................",
        "..KK......KK....",
        "..KVK.....KVK...",
        "..KVVK....KVVK..",
        "...KVVK....KVVK.",
        "....KVVK....KVVK",
        ".....KVVK....KVK",
        "......KVK....KK.",
        "......KVK....KK.",
        ".....KVVK....KVK",
        "....KVVK....KVVK",
        "...KVVK....KVVK.",
        "..KVVK....KVVK..",
        "..KVK.....KVK...",
        "..KK......KK....",
        "................",
    ],
    # 이동 속도: wind-swept boot dash (three speed lines + forward wedge).
    "move_speed": [
        "................",
        "................",
        "........KKK.....",
        "........KNNK....",
        ".KKKKK..KNNNK...",
        ".KnnnK..KNNNNK..",
        ".KKKKK..KNNNNNK.",
        "........KNNNNNNK",
        "........KNNNNNNK",
        ".KKKKK..KNNNNNK.",
        ".KnnnK..KNNNNK..",
        ".KKKKK..KNNNK...",
        "........KNNK....",
        "........KKK.....",
        "................",
        "................",
    ],
    # 최대 체력: classic pixel heart with a highlight.
    "max_hp": [
        "................",
        "..KKK....KKK....",
        ".KVVVK..KVVVK...",
        "KVWVVVKKVVVVVK..",
        "KVWVVVVVVVVVVK..",
        "KVVVVVVVVVVVVK..",
        "KVVVVVVVVVVVvK..",
        ".KVVVVVVVVVvK...",
        "..KVVVVVVVvK....",
        "...KVVVVVvK.....",
        "....KVVVvK......",
        ".....KVvK.......",
        "......KvK.......",
        ".......K........",
        "................",
        "................",
    ],
    # 획득 반경: U-magnet, steel tips.
    "magnet_radius": [
        "................",
        "...KKK....KKK...",
        "..KSSSK..KSSSK..",
        "..KSSSK..KSSSK..",
        "..KKKKK..KKKKK..",
        "..KVVVK..KVVVK..",
        "..KVVVK..KVVVK..",
        "..KVVVK..KVVVK..",
        "..KVVVK..KVVVK..",
        "..KVVvKKKKvVVK..",
        "..KVVvvVVvvVVK..",
        "...KVvVVVVvVK...",
        "....KvVVVVvK....",
        ".....KKKKKK.....",
        "................",
        "................",
    ],
    # 경험치 획득: four-point star, gold with shade.
    "xp_gain": [
        "................",
        ".......KK.......",
        ".......KGK......",
        "......KGGK......",
        "......KGGgK.....",
        ".KKKKKGGGGKKKKK.",
        "..KGGGGWGGGGGgK.",
        "...KGGGWGGGGgK..",
        "...KGGGGGGGgK...",
        "..KGGGGGGGGGgK..",
        ".KKKKKGGGGKKKKK.",
        "......KGGgK.....",
        "......KGGK......",
        ".......KGK......",
        ".......KK.......",
        "................",
    ],
    # 행운: four-leaf clover + stem.
    "luck": [
        "................",
        "...KKK...KKK....",
        "..KNNNK.KNNNK...",
        ".KNWNNNKNNNNNK..",
        ".KNNNNNKNNNNnK..",
        ".KNNNNNKNNNnK...",
        "..KNNNKKKNnK....",
        "...KKKNNNKK.....",
        "..KKKNNNKKKK....",
        ".KNNNNNKNNNNK...",
        ".KNNNNNKNNNNnK..",
        ".KNNNnNKNNNNnK..",
        "..KNnK..KNnnK...",
        "...KK..KKnK.....",
        "......KKK.......",
        "................",
    ],
    # 신속 투사: right arrow + speed lines.
    "projectile_speed": [
        "................",
        "................",
        "..........KK....",
        "..........KBK...",
        "KKKKK.....KBBK..",
        "KbbbK.....KBBBK.",
        "KKKKKKKKKKKBBBK.",
        "KBBBBBBBBBBBBBBK",
        "KBBBBBBBBBBBBBBK",
        "KKKKKKKKKKKBBBK.",
        "KbbbK.....KBBBK.",
        "KKKKK.....KBBK..",
        "..........KBK...",
        "..........KK....",
        "................",
        "................",
    ],
    # 방비: shield, steel rim + blue face.
    "defense": [
        "................",
        "..KKKKKKKKKKK...",
        ".KSSSSSSSSSSSK..",
        ".KSBBBBBBBBBSK..",
        ".KSBBWBBBBBBSK..",
        ".KSBBBBBBBBBSK..",
        ".KSBBBBBBBBbSK..",
        ".KSBBBBBBBBbSK..",
        "..KSBBBBBBbSK...",
        "..KSBBBBBBbSK...",
        "...KSBBBBbSK....",
        "....KSBBbSK.....",
        ".....KSbSK......",
        "......KSK.......",
        ".......K........",
        "................",
    ],
    # 다중 투사: three upward talisman darts.
    "projectile_count": [
        "................",
        ".......KK.......",
        "..KK..KPPK..KK..",
        ".KPPK.KPPK.KPPK.",
        ".KPPK.KPPK.KPPK.",
        ".KPPK.KPPK.KPPK.",
        ".KPPK.KPPK.KPPK.",
        ".KPPK.KPPK.KPPK.",
        ".KPpK.KPpK.KPpK.",
        ".KPpK.KPpK.KPpK.",
        ".KVvK.KVvK.KVvK.",
        ".KKKK.KKKK.KKKK.",
        "................",
        "................",
        "................",
        "................",
    ],
}
# 'p' shade for paper used in projectile_count.
COLORS["p"] = (204, 190, 158, 255)


def build(name: str, rows: list) -> None:
    size = len(rows)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        assert len(row) == size, f"{name} row {y} width {len(row)}"
        for x, ch in enumerate(row):
            color = COLORS[ch]
            if color is not None:
                px[x, y] = color
    img.resize((size * SCALE, size * SCALE), Image.NEAREST).save(OUT / f"{name}.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, rows in ICONS.items():
        build(name, rows)
        print(name)
