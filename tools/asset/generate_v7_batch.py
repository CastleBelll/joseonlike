#!/usr/bin/env python3
"""Generate the deterministic V7 loot, weapon, status, and digit sprites."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
TRANSPARENT = (0, 0, 0, 0)
INK = (9, 10, 16, 255)
DEEP = (24, 24, 34, 255)
TIER = {
    "common": (235, 235, 235, 255),
    "uncommon": (92, 217, 107, 255),
    "rare": (82, 143, 242, 255),
    "epic": (168, 97, 235, 255),
}


def canvas(size: tuple[int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", size, TRANSPARENT)
    return image, ImageDraw.Draw(image)


def finish(base: Image.Image, rim: tuple[int, int, int, int] | None = None) -> Image.Image:
    """Add a one-pixel dark outline and optional one-pixel outer tier rim."""
    alpha = base.getchannel("A")
    outline_alpha = alpha.filter(ImageFilter.MaxFilter(3))
    output = Image.new("RGBA", base.size, TRANSPARENT)
    if rim is not None:
        rim_alpha = outline_alpha.filter(ImageFilter.MaxFilter(3))
        output.paste(rim, mask=ImageChops.subtract(rim_alpha, outline_alpha))
    output.paste(INK, mask=ImageChops.subtract(outline_alpha, alpha))
    output.alpha_composite(base)
    return output


def save(image: Image.Image, relative: str) -> Path:
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    return path


def fit_pickup(image: Image.Image, max_width: int = 20, max_height: int = 18) -> Image.Image:
    """Center a finished pickup at the same apparent scale as existing drops."""
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return image
    cropped = image.crop(bbox)
    scale = min(1.0, max_width / cropped.width, max_height / cropped.height)
    size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    if size != cropped.size:
        cropped = cropped.resize(size, Image.Resampling.NEAREST)
    output = Image.new("RGBA", image.size, TRANSPARENT)
    output.alpha_composite(cropped, ((image.width - cropped.width) // 2, (image.height - cropped.height) // 2))
    return output


def loot_bamboo() -> Image.Image:
    im, d = canvas((24, 24))
    stalks = [
        ([(5, 17), (8, 19), (14, 6), (11, 5)], (52, 102, 42, 255)),
        ([(8, 18), (11, 19), (16, 5), (13, 4)], (65, 126, 50, 255)),
        ([(11, 18), (14, 19), (19, 7), (16, 5)], (42, 91, 37, 255)),
    ]
    for points, color in stalks:
        d.polygon(points, fill=color)
    d.line([(7, 16), (12, 5)], fill=(118, 174, 73, 255), width=1)
    d.line([(10, 17), (15, 5)], fill=(127, 184, 77, 255), width=1)
    d.line([(13, 17), (18, 7)], fill=(92, 150, 60, 255), width=1)
    d.line([(7, 13), (15, 15)], fill=(173, 120, 55, 255), width=3)
    d.line([(7, 13), (15, 15)], fill=(229, 179, 83, 255), width=1)
    return finish(im, TIER["common"])


def loot_fiber() -> Image.Image:
    im, d = canvas((24, 24))
    rope = (190, 133, 63, 255)
    light = (236, 188, 99, 255)
    # A donut silhouette plus a loose tail remains recognisably coiled at 24px.
    d.ellipse((4, 5, 18, 19), fill=rope)
    d.ellipse((8, 9, 14, 15), fill=TRANSPARENT)
    d.line([(15, 7), (19, 5), (19, 9), (17, 11)], fill=rope, width=3)
    d.arc((5, 6, 17, 18), 205, 335, fill=light, width=1)
    d.arc((6, 7, 16, 17), 20, 155, fill=(142, 91, 48, 255), width=1)
    d.line([(17, 6), (19, 6)], fill=light, width=1)
    return finish(im, TIER["common"])


def loot_fang() -> Image.Image:
    im, d = canvas((24, 24))
    d.polygon([(6, 5), (13, 7), (18, 5), (17, 10), (14, 15), (10, 19), (7, 19), (9, 14), (9, 9)], fill=(222, 205, 168, 255))
    d.polygon([(9, 7), (14, 8), (16, 7), (14, 12), (10, 17), (9, 17), (11, 12)], fill=(255, 247, 213, 255))
    d.rectangle((6, 17, 10, 19), fill=(112, 78, 49, 255))
    d.rectangle((7, 17, 11, 17), fill=(171, 119, 65, 255))
    return finish(im, TIER["common"])


def loot_paper() -> Image.Image:
    im, d = canvas((24, 24))
    d.polygon([(7, 4), (16, 4), (18, 6), (17, 19), (7, 19)], fill=(229, 191, 79, 255))
    d.polygon([(8, 5), (15, 5), (17, 7), (16, 17), (8, 18)], fill=(255, 224, 119, 255))
    d.polygon([(15, 5), (17, 7), (15, 8)], fill=(184, 132, 51, 255))
    rune = (170, 48, 39, 255)
    d.line([(10, 8), (14, 8), (13, 10), (10, 10), (10, 13), (14, 13), (14, 16), (11, 16)], fill=rune, width=1)
    d.point((12, 11), fill=rune)
    return finish(im, TIER["common"])


def loot_soul() -> Image.Image:
    im, d = canvas((24, 24))
    d.polygon([(11, 3), (17, 8), (15, 17), (10, 21), (6, 14), (7, 7)], fill=(77, 185, 207, 255))
    d.polygon([(11, 4), (15, 8), (12, 11), (8, 8)], fill=(171, 245, 239, 255))
    d.polygon([(8, 9), (12, 12), (10, 19), (7, 14)], fill=(99, 217, 224, 255))
    d.line([(12, 11), (15, 9), (14, 16)], fill=(221, 255, 249, 255), width=1)
    return finish(im, TIER["uncommon"])


def loot_wisp() -> Image.Image:
    im, d = canvas((24, 24))
    d.polygon([(12, 3), (14, 8), (17, 6), (16, 11), (19, 10), (17, 17), (13, 20), (8, 18), (6, 14), (8, 9), (10, 12)], fill=(42, 151, 160, 255))
    d.polygon([(12, 7), (13, 12), (16, 11), (15, 16), (12, 18), (9, 16), (9, 13)], fill=(99, 231, 219, 255))
    d.line([(13, 16), (11, 16), (10, 14), (11, 12), (13, 13), (13, 14), (12, 15)], fill=(224, 255, 239, 255), width=1)
    return finish(im, TIER["uncommon"])


def loot_whetstone() -> Image.Image:
    im, d = canvas((24, 24))
    d.polygon([(5, 11), (13, 5), (19, 8), (19, 14), (11, 20), (5, 17)], fill=(91, 94, 101, 255))
    d.polygon([(5, 11), (13, 5), (19, 8), (11, 15)], fill=(180, 178, 166, 255))
    d.polygon([(11, 15), (19, 8), (19, 14), (11, 20)], fill=(69, 72, 81, 255))
    d.line([(8, 11), (13, 8), (16, 9)], fill=(224, 219, 199, 255), width=1)
    d.point((12, 12), fill=(121, 119, 113, 255))
    d.point((15, 10), fill=(121, 119, 113, 255))
    return finish(im, TIER["rare"])


def jagged_stone(base: tuple[int, int, int, int], mid: tuple[int, int, int, int], crack: tuple[int, int, int, int], rim: tuple[int, int, int, int], variant: str) -> Image.Image:
    im, d = canvas((24, 24))
    points = [(5, 8), (9, 4), (14, 5), (17, 7), (19, 13), (16, 19), (11, 20), (6, 17), (4, 13)]
    if variant == "fire":
        points = [(6, 5), (11, 3), (13, 6), (17, 5), (19, 10), (18, 16), (14, 20), (8, 19), (4, 14)]
    elif variant == "cinnabar":
        points = [(5, 12), (8, 5), (11, 8), (14, 4), (16, 9), (19, 8), (19, 16), (15, 19), (9, 19), (5, 16)]
    d.polygon(points, fill=base)
    d.polygon([(7, 8), (10, 5), (14, 6), (16, 9), (13, 12), (8, 12)], fill=mid)
    if variant == "ghost":
        d.line([(11, 5), (10, 10), (14, 12), (12, 18)], fill=crack, width=1)
        d.line([(10, 10), (7, 13)], fill=crack, width=1)
        d.line([(14, 12), (17, 10)], fill=crack, width=1)
    elif variant == "fire":
        d.line([(10, 5), (11, 10), (8, 13), (11, 18)], fill=crack, width=1)
        d.line([(11, 10), (16, 8), (14, 15), (17, 16)], fill=crack, width=1)
        d.rectangle((10, 12, 12, 15), fill=(255, 179, 40, 255))
        d.point((11, 12), fill=(255, 246, 135, 255))
    elif variant == "thunder":
        d.line([(14, 5), (10, 10), (13, 10), (9, 18), (16, 12), (13, 12), (17, 8)], fill=crack, width=1)
        d.point((5, 7), fill=crack)
        d.point((19, 6), fill=crack)
        d.point((20, 14), fill=crack)
    else:
        d.polygon([(8, 7), (11, 9), (10, 15), (7, 15)], fill=(221, 65, 46, 255))
        d.polygon([(14, 5), (17, 10), (15, 15), (12, 12)], fill=(244, 89, 53, 255))
        d.polygon([(12, 14), (17, 12), (18, 17), (14, 18)], fill=(172, 38, 37, 255))
        d.line([(9, 7), (10, 10)], fill=(255, 139, 87, 255), width=1)
        d.line([(14, 6), (16, 10)], fill=(255, 139, 87, 255), width=1)
    return finish(im, rim)


def make_loot() -> list[Path]:
    makers = {
        "bamboo": loot_bamboo,
        "tough_fiber": loot_fiber,
        "beast_fang": loot_fang,
        "talisman_paper": loot_paper,
        "wonhon_shard": loot_soul,
        "dokkaebi_flame": loot_wisp,
        "whetstone": loot_whetstone,
        "ghost_iron": lambda: jagged_stone((34, 34, 46, 255), (67, 65, 82, 255), (183, 69, 232, 255), TIER["epic"], "ghost"),
        "fire_spirit_stone": lambda: jagged_stone((54, 35, 32, 255), (103, 48, 35, 255), (244, 62, 30, 255), TIER["epic"], "fire"),
        "thunder_stone": lambda: jagged_stone((35, 70, 111, 255), (52, 109, 166, 255), (113, 238, 255, 255), TIER["epic"], "thunder"),
        "cinnabar": lambda: jagged_stone((116, 35, 38, 255), (182, 48, 45, 255), (255, 128, 79, 255), TIER["rare"], "cinnabar"),
    }
    return [save(fit_pickup(maker()), f"asset/drop/loot/{name}/idle.png") for name, maker in makers.items()]


def sword_base(kind: str) -> Image.Image:
    im, d = canvas((32, 32))
    if kind == "sharp":
        d.polygon([(6, 27), (9, 29), (25, 9), (27, 4), (23, 6), (7, 23)], fill=(111, 146, 176, 255))
        d.polygon([(9, 25), (24, 7), (26, 6), (24, 11), (11, 28)], fill=(225, 244, 241, 255))
        d.line([(11, 24), (24, 9)], fill=(117, 208, 234, 255), width=1)
        d.polygon([(5, 22), (11, 27), (10, 30), (3, 24)], fill=(187, 139, 56, 255))
        d.line([(5, 27), (3, 29)], fill=(120, 71, 42, 255), width=3)
    elif kind == "ghost":
        d.polygon([(6, 26), (10, 29), (14, 23), (16, 24), (20, 17), (19, 15), (26, 7), (24, 4), (18, 9), (17, 8), (11, 18), (12, 20)], fill=(55, 54, 70, 255))
        d.polygon([(10, 26), (15, 21), (16, 22), (20, 16), (19, 14), (24, 7), (22, 8), (17, 13), (16, 12)], fill=(108, 83, 137, 255))
        d.line([(12, 23), (16, 18), (16, 15), (21, 10)], fill=(198, 91, 234, 255), width=1)
        d.polygon([(5, 21), (12, 27), (10, 30), (3, 24)], fill=(62, 46, 72, 255))
        d.line([(6, 27), (3, 30)], fill=(43, 35, 48, 255), width=3)
    else:
        d.polygon([(6, 27), (10, 29), (24, 10), (25, 5), (21, 8), (7, 23)], fill=(184, 57, 30, 255))
        d.polygon([(10, 25), (23, 8), (24, 7), (23, 12), (12, 27)], fill=(255, 174, 37, 255))
        d.polygon([(16, 18), (18, 12), (20, 15), (23, 8), (24, 5), (26, 10), (23, 16), (20, 18)], fill=(239, 61, 24, 255))
        d.line([(13, 24), (21, 13)], fill=(255, 236, 92, 255), width=1)
        d.polygon([(5, 22), (11, 27), (10, 30), (3, 24)], fill=(198, 121, 39, 255))
        d.line([(6, 27), (3, 30)], fill=(99, 52, 34, 255), width=3)
    return finish(im)


def lightning_talisman_icon() -> Image.Image:
    im, d = canvas((32, 32))
    d.polygon([(9, 3), (23, 4), (25, 7), (23, 29), (8, 28), (7, 25)], fill=(195, 151, 51, 255))
    d.polygon([(10, 4), (22, 5), (23, 7), (22, 27), (9, 26), (8, 24)], fill=(247, 216, 104, 255))
    d.polygon([(20, 5), (23, 7), (20, 9)], fill=(152, 102, 40, 255))
    d.polygon([(17, 7), (12, 16), (16, 16), (12, 25), (21, 13), (17, 13), (20, 8)], fill=(57, 125, 223, 255))
    d.line([(11, 7), (13, 7)], fill=(173, 47, 43, 255), width=1)
    d.line([(18, 25), (20, 25)], fill=(173, 47, 43, 255), width=1)
    return finish(im)


def beopgeom_icon() -> Image.Image:
    im, d = canvas((32, 32))
    d.polygon([(5, 26), (8, 29), (26, 9), (27, 4), (23, 7), (6, 23)], fill=(141, 42, 36, 255))
    d.polygon([(9, 25), (24, 8), (26, 6), (24, 11), (11, 28)], fill=(232, 76, 49, 255))
    d.line([(12, 24), (23, 11)], fill=(255, 173, 75, 255), width=1)
    d.polygon([(4, 21), (12, 27), (10, 30), (2, 24)], fill=(218, 168, 49, 255))
    d.line([(6, 27), (3, 30)], fill=(104, 54, 31, 255), width=3)
    d.polygon([(11, 22), (15, 20), (17, 24), (13, 27)], fill=(243, 209, 97, 255))
    d.line([(13, 22), (14, 25)], fill=(174, 44, 37, 255), width=1)
    return finish(im)


def make_weapon_icons() -> list[Path]:
    images = {
        "sharp_sword": sword_base("sharp"),
        "ghost_sword": sword_base("ghost"),
        "flame_sword": sword_base("flame"),
        "lightning_talisman": lightning_talisman_icon(),
        "beopgeom": beopgeom_icon(),
    }
    return [save(image, f"asset/weapon/icons/{name}.png") for name, image in images.items()]


def lightning_travel() -> Image.Image:
    im, d = canvas((32, 32))
    d.polygon([(2, 17), (9, 11), (11, 14), (18, 8), (17, 14), (29, 15), (21, 20), (22, 16), (13, 22), (12, 18), (5, 21)], fill=(62, 135, 230, 255))
    d.polygon([(5, 17), (10, 13), (12, 16), (19, 11), (18, 15), (27, 16), (20, 18), (21, 16), (13, 20), (12, 17)], fill=(145, 239, 255, 255))
    d.line([(7, 16), (11, 15), (13, 17), (19, 14), (25, 16)], fill=(248, 255, 220, 255), width=1)
    d.point((3, 12), fill=(108, 213, 255, 255))
    d.point((7, 23), fill=(108, 213, 255, 255))
    return finish(im)


def beopgeom_travel() -> Image.Image:
    im, d = canvas((32, 32))
    d.polygon([(3, 17), (8, 14), (22, 14), (28, 16), (22, 18), (8, 18)], fill=(130, 35, 37, 255))
    d.polygon([(8, 15), (22, 15), (27, 16), (22, 17), (8, 17)], fill=(244, 75, 52, 255))
    d.line([(10, 16), (23, 16)], fill=(255, 182, 82, 255), width=1)
    d.polygon([(6, 12), (10, 16), (6, 20), (4, 19), (6, 16), (4, 13)], fill=(226, 174, 55, 255))
    d.line([(3, 16), (1, 12)], fill=(175, 42, 38, 255), width=2)
    d.line([(3, 17), (1, 21)], fill=(175, 42, 38, 255), width=2)
    return finish(im)


def make_travel() -> list[Path]:
    return [
        save(lightning_travel(), "asset/weapon/travel/lightning_bolt.png"),
        save(beopgeom_travel(), "asset/weapon/travel/beopgeom_bolt.png"),
    ]


def burn_frame(index: int) -> Image.Image:
    im, d = canvas((24, 24))
    shapes = [
        [(12, 3), (14, 8), (17, 6), (17, 12), (19, 11), (18, 18), (13, 21), (8, 19), (6, 14), (8, 9), (10, 12)],
        [(10, 4), (13, 7), (15, 3), (17, 10), (19, 9), (18, 17), (14, 21), (9, 20), (6, 16), (7, 10), (10, 13)],
        [(13, 3), (15, 9), (18, 7), (17, 13), (20, 13), (17, 19), (12, 21), (7, 18), (6, 13), (9, 8), (10, 13)],
        [(11, 4), (14, 8), (16, 5), (17, 11), (19, 12), (17, 18), (13, 21), (8, 19), (6, 14), (8, 10), (10, 13)],
    ]
    d.polygon(shapes[index], fill=(190, 45, 25, 255))
    d.polygon([(12, 8), (14, 12), (16, 11), (16, 17), (13, 19), (9, 17), (9, 13)], fill=(244, 105, 29, 255))
    d.polygon([(12, 12), (14, 15), (13, 18), (11, 17), (10, 15)], fill=(255, 224, 79, 255))
    d.point((5 + index * 4, 7 + (index % 2)), fill=(255, 157, 47, 255))
    return finish(im)


def seal_frame(index: int) -> Image.Image:
    im, d = canvas((24, 24))
    dim = [(150, 43, 45, 255), (231, 78, 48, 255), (246, 175, 61, 255), (194, 52, 46, 255)][index]
    corners = [(7, 5), (17, 5), (19, 8), (19, 16), (16, 19), (8, 19), (5, 16), (5, 8)]
    d.line(corners + [corners[0]], fill=dim, width=1)
    if index in (1, 2):
        d.point((12, 3), fill=dim)
        d.point((21, 12), fill=dim)
        d.point((12, 21), fill=dim)
        d.point((3, 12), fill=dim)
    d.line([(9, 7), (15, 7), (13, 10), (10, 10), (10, 13), (15, 13), (15, 17), (11, 17)], fill=dim, width=2 if index == 2 else 1)
    d.line([(7, 12), (17, 12)], fill=(255, 218, 91, 255) if index == 2 else dim, width=1)
    return finish(im)


def make_status() -> list[Path]:
    paths = []
    for name, maker in (("burn", burn_frame), ("seal", seal_frame)):
        strip = Image.new("RGBA", (96, 24), TRANSPARENT)
        for index in range(4):
            strip.alpha_composite(maker(index), (index * 24, 0))
        paths.append(save(strip, f"asset/effect/status/{name}/strip.png"))
    return paths


DIGITS = {
    "0": ("11111", "10001", "10011", "10101", "11001", "10001", "11111"),
    "1": ("00100", "01100", "00100", "00100", "00100", "00100", "01110"),
    "2": ("11110", "00001", "00001", "11110", "10000", "10000", "11111"),
    "3": ("11110", "00001", "00001", "01110", "00001", "00001", "11110"),
    "4": ("10010", "10010", "10010", "11111", "00010", "00010", "00010"),
    "5": ("11111", "10000", "10000", "11110", "00001", "00001", "11110"),
    "6": ("01111", "10000", "10000", "11110", "10001", "10001", "01110"),
    "7": ("11111", "00001", "00010", "00100", "01000", "01000", "01000"),
    "8": ("01110", "10001", "10001", "01110", "10001", "10001", "01110"),
    "9": ("01110", "10001", "10001", "01111", "00001", "00001", "11110"),
}


def make_digits() -> list[Path]:
    strip = Image.new("RGBA", (80, 10), TRANSPARENT)
    for number, rows in DIGITS.items():
        glyph, d = canvas((8, 10))
        for y, row in enumerate(rows, start=1):
            for x, bit in enumerate(row, start=1):
                if bit == "1":
                    d.point((x, y), fill=(255, 255, 255, 255))
        strip.alpha_composite(finish(glyph), (int(number) * 8, 0))
    return [save(strip, "asset/ui/hud/damage_digits.png")]


def stats(path: Path) -> dict[str, object]:
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    alpha_bytes = alpha.tobytes()
    bbox = alpha.getbbox()
    colors = image.getcolors(maxcolors=image.width * image.height) or []
    return {
        "path": path.relative_to(ROOT).as_posix(),
        "canvas": list(image.size),
        "content_bbox": [bbox[2] - bbox[0], bbox[3] - bbox[1]] if bbox else [0, 0],
        "opaque_pixels": alpha_bytes.count(255),
        "rgba_colors": len(colors),
        "alpha_values": sorted(set(alpha_bytes)),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def validate(paths: list[Path]) -> None:
    for path in paths:
        image = Image.open(path).convert("RGBA")
        alpha_values = set(image.getchannel("A").tobytes())
        if not alpha_values <= {0, 255}:
            raise ValueError(f"soft alpha in {path}")
        expected = (24, 24) if "/drop/loot/" in path.as_posix() else None
        if "/weapon/icons/" in path.as_posix() or "/weapon/travel/" in path.as_posix():
            expected = (32, 32)
        if "/effect/status/" in path.as_posix():
            expected = (96, 24)
        if path.name == "damage_digits.png":
            expected = (80, 10)
        if expected and image.size != expected:
            raise ValueError(f"wrong canvas {image.size} in {path}; expected {expected}")
        if image.getbbox() is None:
            raise ValueError(f"empty asset {path}")
    for path in paths:
        if "/effect/status/" not in path.as_posix():
            continue
        image = Image.open(path).convert("RGBA")
        frames = [image.crop((index * 24, 0, (index + 1) * 24, 24)).tobytes() for index in range(4)]
        if len(set(frames)) != 4:
            raise ValueError(f"status frames must be byte-distinct: {path}")


def contact_sheet(paths: list[Path]) -> Path:
    groups = [
        ("LOOT 24x24", [path for path in paths if "/drop/loot/" in path.as_posix()], 4),
        ("WEAPON ICONS 32x32", [path for path in paths if "/weapon/icons/" in path.as_posix()], 3),
        ("TRAVEL + STATUS", [path for path in paths if "/weapon/travel/" in path.as_posix() or "/effect/status/" in path.as_posix()], 2),
        ("OPTIONAL DAMAGE DIGITS", [path for path in paths if path.name == "damage_digits.png"], 1),
    ]
    width = 640
    row_height = 128
    total_rows = sum((len(items) + columns - 1) // columns for _, items, columns in groups)
    sheet = Image.new("RGB", (width, 34 * len(groups) + row_height * total_rows + 20), (39, 42, 50))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    y = 10
    for title, items, columns in groups:
        draw.text((12, y), title, fill=(238, 238, 232), font=font)
        y += 28
        cell_width = width // columns
        rows = (len(items) + columns - 1) // columns
        for index, path in enumerate(items):
            column = index % columns
            row = index // columns
            x = column * cell_width
            top = y + row * row_height
            draw.rectangle((x + 2, top + 2, x + cell_width - 3, top + row_height - 3), outline=(83, 88, 101))
            image = Image.open(path).convert("RGBA")
            scale = min(4, max(1, (cell_width - 16) // image.width), max(1, 86 // image.height))
            preview = image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)
            px = x + (cell_width - preview.width) // 2
            sheet.paste(preview, (px, top + 8), preview)
            label = path.parent.name if path.name in ("idle.png", "strip.png") else path.stem
            draw.text((x + 8, top + 104), label, fill=(202, 205, 215), font=font)
        y += rows * row_height
    return save(sheet.convert("RGBA"), "asset/raw/v7_asset_contact_sheet.png")


def main() -> None:
    paths = make_loot() + make_weapon_icons() + make_travel() + make_status() + make_digits()
    validate(paths)
    contact = contact_sheet(paths)
    metrics = {"assets": [stats(path) for path in paths], "contact_sheet": stats(contact)}
    metrics_path = ROOT / "asset/raw/v7_asset_metrics.json"
    metrics_path.parent.mkdir(parents=True, exist_ok=True)
    metrics_path.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    print(f"generated and verified {len(paths)} PNGs; contact sheet: {contact.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
