"""Build the in-world weapon FX textures (N9-5c).

Both textures are drawn in LUMINANCE (grays + white core) so the engine's
modulate supplies the hue: 혼불 tints them WEAPON_SOUL blue, 화령 혼불
WEAPON_FIRE orange, 결계 seal-gold, 화염 결계 fire — one texture each,
no per-variant recolors.

- honbul_wisp.png: a dokkaebi-fire teardrop wisp (owner report: the
  code-drawn lobe stack didn't read as 도깨비불).
- ward_sigil.png: a proper 부적진 ground formation — double boundary
  ring, eight trigram bar clusters, center swirl — replacing the plain
  code-drawn rings (owner report: '별거 아닌 것 같다').
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent / "fx"


def lum(value: int, alpha: int = 255) -> tuple:
    return (value, value, value, alpha)


def build_wisp() -> Image.Image:
    """24x30 teardrop flame pointing up, white core low in the body."""
    img = Image.new("RGBA", (24, 30), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def disc(x: float, y: float, r: float, v: int, a: int = 255) -> None:
        d.ellipse([x - r, y - r, x + r, y + r], fill=lum(v, a))

    # dim halo rim first, then the body stack bottom-up, brighter upward
    disc(12, 21, 8.5, 140, 160)
    disc(12, 21, 7, 190)
    disc(12, 15, 6, 205)
    disc(12, 10, 4.5, 220)
    disc(12, 6, 3, 235)
    disc(12, 3, 1.5, 250)
    # side tongues — the flicker silhouette that reads as 도깨비불
    disc(5.5, 17, 2.5, 175)
    disc(18.5, 15, 2, 175)
    disc(4, 12, 1.2, 165)
    # white-hot core sitting low
    disc(12, 19, 3.5, 255)
    return img


def build_sigil() -> Image.Image:
    """256px 부적진: double ring, 8 trigram clusters, center swirl."""
    size = 256
    c = size / 2
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def ring(radius: float, width: float, v: int, a: int = 255) -> None:
        d.ellipse(
            [c - radius, c - radius, c + radius, c + radius],
            outline=lum(v, a), width=int(width)
        )

    # boundary rings
    ring(122, 5, 230)
    ring(112, 2, 170)
    ring(76, 3, 200)
    # 팔괘-style bar clusters between the rings: three bars per cluster,
    # middle bar broken on alternating clusters (음/양 variety)
    bar_half = 13.0
    for i in range(8):
        angle = math.tau * i / 8.0
        for j, radial in enumerate((86.0, 94.0, 102.0)):
            broken = (i + j) % 2 == 0
            _draw_bar(d, c, angle, radial, bar_half, broken)
    # center swirl: two comma arcs + studs
    d.arc([int(c - 40), int(c - 40), int(c + 40), int(c + 40)], 300, 120, fill=lum(210), width=7)
    d.arc([int(c - 40), int(c - 40), int(c + 40), int(c + 40)], 120, 300, fill=lum(150), width=7)
    d.ellipse([c - 20, c - 38, c, c - 18], outline=lum(210), width=6)
    d.ellipse([c, c + 18, c + 20, c + 38], outline=lum(150), width=6)
    d.ellipse([c - 9, c - 32, c - 3, c - 26], fill=lum(255))
    d.ellipse([c + 3, c + 26, c + 9, c + 32], fill=lum(255))
    # cardinal diamond studs on the outer ring
    for i in range(4):
        angle = math.tau * i / 4.0
        x = c + math.cos(angle) * 122
        y = c + math.sin(angle) * 122
        d.polygon(
            [(x, y - 7), (x + 7, y), (x, y + 7), (x - 7, y)], fill=lum(245)
        )
    return img


def _draw_bar(
    d: ImageDraw.ImageDraw, c: float, angle: float, radial: float,
    half: float, broken: bool
) -> None:
    """One trigram bar: a short stroke perpendicular to the radius."""
    ox = math.cos(angle)
    oy = math.sin(angle)
    px, py = -oy, ox  # perpendicular
    bx = c + ox * radial
    by = c + oy * radial
    if broken:
        for sign in (-1.0, 1.0):
            d.line(
                [
                    (bx + px * sign * half, by + py * sign * half),
                    (bx + px * sign * 2.5, by + py * sign * 2.5),
                ],
                fill=lum(185), width=4,
            )
    else:
        d.line(
            [(bx - px * half, by - py * half), (bx + px * half, by + py * half)],
            fill=lum(185), width=4,
        )


EFFECT_OUT = Path(__file__).resolve().parents[1] / "effect"
PICKUP_OUT = Path(__file__).resolve().parents[1] / "pickups"


def build_sinjang() -> Image.Image:
    """20x32 spirit-general (신장) facing right, drawn in luminance so the
    engine modulate colors it (taoist blue base, lightning tint variant).
    Silhouette: helmet with a crest, broad-shouldered robe tapering to a
    spectral wisp tail, one bright eye, a held blade at the front."""
    img = Image.new("RGBA", (20, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def px(x: int, y: int, v: int, a: int = 255) -> None:
        d.point((x, y), fill=lum(v, a))

    # spectral wisp tail (bottom, fading)
    d.polygon([(7, 31), (13, 31), (14, 26), (6, 26)], fill=lum(120, 170))
    d.rectangle([8, 29, 11, 31], fill=lum(100, 120))
    # robe body — broad shoulders tapering down
    d.polygon([(4, 12), (15, 12), (14, 27), (5, 27)], fill=lum(185))
    d.line([9, 13, 9, 26], fill=lum(150))  # robe fold
    # shoulder guards
    d.rectangle([2, 12, 5, 15], fill=lum(220))
    d.rectangle([14, 12, 17, 15], fill=lum(220))
    # head + helmet
    d.rectangle([6, 5, 13, 11], fill=lum(200))
    d.rectangle([5, 4, 14, 6], fill=lum(235))     # helm brim
    d.rectangle([9, 1, 10, 4], fill=lum(245))     # crest
    # face shadow + bright eye (facing right)
    d.rectangle([7, 7, 13, 10], fill=lum(90))
    d.rectangle([11, 8, 12, 9], fill=lum(255))
    # blade held forward (right side)
    d.rectangle([16, 14, 17, 24], fill=lum(240))
    px(16, 13, 255)
    return img


def build_chest() -> Image.Image:
    """22x18 elite reward chest: dark chest wood, brass fittings, lock plate
    (반닫이 silhouette — was the code-drawn placeholder, N5-5)."""
    img = Image.new("RGBA", (22, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ink = (26, 22, 19, 255)
    wood = (110, 67, 34, 255)
    wood_dark = (78, 46, 22, 255)
    brass = (255, 217, 74, 255)
    brass_dim = (196, 154, 61, 255)
    # body + outline
    d.rectangle([1, 4, 20, 16], fill=wood, outline=ink)
    # lid band
    d.rectangle([1, 4, 20, 8], fill=wood_dark, outline=ink)
    # brass corner fittings
    for x in (2, 18):
        d.rectangle([x, 5, x + 1, 7], fill=brass_dim)
        d.rectangle([x, 13, x + 1, 15], fill=brass_dim)
    # brass mid straps
    d.line([5, 4, 5, 16], fill=brass_dim)
    d.line([16, 4, 16, 16], fill=brass_dim)
    # lock plate + hasp
    d.rectangle([9, 7, 12, 12], fill=brass, outline=ink)
    d.rectangle([10, 9, 11, 10], fill=ink)
    # wood grain
    d.line([3, 11, 4, 11], fill=wood_dark)
    d.line([13, 14, 15, 14], fill=wood_dark)
    return img


def build_hit_paper() -> Image.Image:
    """4-frame 32px strip: hanji shreds + ink flecks scattering (낡은 부적)."""
    frames = 4
    size = 32
    strip = Image.new("RGBA", (frames * size, size), (0, 0, 0, 0))
    cream = (240, 228, 196, 255)
    ink = (26, 22, 19, 255)
    shreds = [
        (1.00, 0.30, 3), (0.55, 0.80, 2), (0.15, 0.55, 3), (0.72, 0.05, 2),
        (0.35, 0.95, 2), (0.88, 0.62, 3), (0.05, 0.15, 2), (0.62, 0.40, 2),
    ]
    for f in range(frames):
        d = ImageDraw.Draw(strip)
        cx = f * size + size / 2
        cy = size / 2
        spread = 4.0 + 9.0 * f / (frames - 1)
        alpha = int(255 * (1.0 - 0.65 * f / (frames - 1)))
        for i, (ang_share, tilt, shred_len) in enumerate(shreds):
            angle = math.tau * ang_share
            x = cx + math.cos(angle) * spread
            y = cy + math.sin(angle) * spread
            color = (*cream[:3], alpha) if i % 3 else (*ink[:3], alpha)
            d.rectangle([x, y, x + shred_len, y + 1 + int(tilt * 2)], fill=color)
    return strip


def build_hit_phoenix() -> Image.Image:
    """5-frame 48px strip: gold-red wing burst sweeping up (봉황 부적)."""
    frames = 5
    size = 48
    strip = Image.new("RGBA", (frames * size, size), (0, 0, 0, 0))
    gold = (255, 217, 74)
    orange = (255, 130, 50)
    red = (200, 50 , 30)
    for f in range(frames):
        d = ImageDraw.Draw(strip)
        cx = f * size + size / 2
        cy = size / 2 + 4
        t = f / (frames - 1)
        alpha = int(255 * (1.0 - 0.7 * t))
        wing_reach = 6.0 + 16.0 * t
        lift = 4.0 + 10.0 * t
        for side in (-1.0, 1.0):
            for k, (color, w) in enumerate(((red, 5), (orange, 3), (gold, 2))):
                d.arc(
                    [
                        cx + side * wing_reach - wing_reach, cy - lift - wing_reach,
                        cx + side * wing_reach + wing_reach, cy - lift + wing_reach,
                    ],
                    200 if side < 0 else 270, 340 if side < 0 else 50,
                    fill=(*color, alpha), width=w - k // 2,
                )
        core_r = 5.0 * (1.0 - t) + 1.0
        d.ellipse([cx - core_r, cy - core_r, cx + core_r, cy + core_r], fill=(*gold, alpha))
        if f < 2:
            d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(255, 255, 240, alpha))
    return strip


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    EFFECT_OUT.mkdir(parents=True, exist_ok=True)
    build_wisp().save(OUT / "honbul_wisp.png")
    build_sigil().save(OUT / "ward_sigil.png")
    build_sinjang().save(OUT / "sinjang.png")
    build_hit_paper().save(EFFECT_OUT / "hit_paper.png")
    build_hit_phoenix().save(EFFECT_OUT / "hit_phoenix.png")
    PICKUP_OUT.mkdir(parents=True, exist_ok=True)
    build_chest().save(PICKUP_OUT / "chest.png")
    for name in ("honbul_wisp.png", "ward_sigil.png"):
        with Image.open(OUT / name) as done:
            print(name, done.size)
    for name in ("hit_paper.png", "hit_phoenix.png"):
        with Image.open(EFFECT_OUT / name) as done:
            print(name, done.size)
