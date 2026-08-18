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


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    build_wisp().save(OUT / "honbul_wisp.png")
    build_sigil().save(OUT / "ward_sigil.png")
    for name in ("honbul_wisp.png", "ward_sigil.png"):
        with Image.open(OUT / name) as done:
            print(name, done.size)
