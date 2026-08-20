"""Rebuild the 혼불 wisp and icon from the owner's blue fire pack.

Source: new_asset/owner/Pixel Fire Asset Pack v2.2/.../Pixel Fire Asset Pack 2 Blue/
        Group 4 - 2/Group 4 - 2.png — 14 frames of 32x32.

Two outputs, deliberately different in kind:

* asset/weapon/fx/honbul_wisp.png — a LUMINANCE strip. The orb body is tinted
  at runtime (OrbVisual modulates by the weapon colour), which is how 혼불 and
  its evolution 화령 혼불 share one texture while reading as soul-blue and
  fire-orange. Shipping the pack's blue straight in would leave 화령 혼불
  modulating blue by orange, i.e. mud. Checked before writing any of it: the
  shipped wisp has zero saturated pixels, the icons have thousands.
* asset/ui/weapon_icons/honbul.png — COLOURED, 512x512, matching the other
  weapon icons. 혼불 is 도깨비불, so the pack's blue is the right hue here, and
  flame_honbul.png keeps its own red.

Run: python asset/weapon/fx/build_honbul.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = (
    ROOT
    / "new_asset"
    / "owner"
    / "Pixel Fire Asset Pack v2.2"
    / "Pixel Fire Asset Pack v2.2"
    / "Pixel Fire Asset Pack  Colored"
    / "Pixel Fire Asset Pack 2 Blue"
    / "Group 4 - 2"
    / "Group 4 - 2.png"
)
WISP_TARGET = ROOT / "asset" / "weapon" / "fx" / "honbul_wisp.png"
ICON_TARGET = ROOT / "asset" / "ui" / "weapon_icons" / "honbul.png"

ICON_SIDE = 512
# Frame whose flame is fullest — the icon wants the silhouette at its widest,
# not a lull in the loop.
ICON_FRAME = 6
# Rec. 709 luma. Only relative brightness matters; the engine supplies hue.
LUMA = (0.2126, 0.7152, 0.0722)
# Lift the brightest pixel to white so a tint lands at full strength instead
# of being pre-darkened by the source art.
NORMALISE_TO = 255


def frames(sheet):
    side = sheet.size[1]
    count = sheet.size[0] // side
    cells = [sheet.crop((i * side, 0, (i + 1) * side, side)) for i in range(count)]
    return cells, side


def to_luminance(image):
    px = image.load()
    w, h = image.size
    peak = 1
    values = {}
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            value = round(r * LUMA[0] + g * LUMA[1] + b * LUMA[2])
            values[(x, y)] = (value, a)
            peak = max(peak, value)
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    op = out.load()
    for (x, y), (value, a) in values.items():
        lifted = min(NORMALISE_TO, round(value * NORMALISE_TO / peak))
        op[x, y] = (lifted, lifted, lifted, a)
    return out


def main():
    sheet = Image.open(SOURCE).convert("RGBA")
    cells, side = frames(sheet)
    if not cells:
        raise SystemExit(f"no frames found in {SOURCE}")

    strip = Image.new("RGBA", (side * len(cells), side), (0, 0, 0, 0))
    for index, cell in enumerate(cells):
        strip.alpha_composite(to_luminance(cell), (index * side, 0))
    strip.save(WISP_TARGET)

    if ICON_FRAME >= len(cells):
        raise SystemExit(f"ICON_FRAME {ICON_FRAME} is past the {len(cells)} frames")
    scale = ICON_SIDE // side
    big = cells[ICON_FRAME].resize((side * scale, side * scale), Image.NEAREST)
    icon = Image.new("RGBA", (ICON_SIDE, ICON_SIDE), (0, 0, 0, 0))
    icon.alpha_composite(
        big, ((ICON_SIDE - big.width) // 2, (ICON_SIDE - big.height) // 2)
    )
    icon.save(ICON_TARGET)

    print(
        f"wrote {WISP_TARGET.relative_to(ROOT)} {strip.size} "
        f"({len(cells)} frames, luminance)"
    )
    print(
        f"wrote {ICON_TARGET.relative_to(ROOT)} {icon.size} "
        f"(frame {ICON_FRAME}, coloured)"
    )


if __name__ == "__main__":
    main()
