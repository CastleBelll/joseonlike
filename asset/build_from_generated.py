"""Install the generated weapon/projectile/FX art at its real asset paths.

The images in new_asset/generated are large flat-background renders. The game
wants small transparent sprites at sizes that are already fixed by the shipped
art, so this cuts the background, trims to the figure, and fits it into the
EXISTING file's dimensions. Nothing here invents a size: every target is read
off the file it replaces, so an install can never quietly change how big a
thing is on screen.

Two kinds of target:

* weapon icons are authored at 16x their 32px logical size, like every other
  sheet in the project, so they go down to 32 and back up with NEAREST;
* projectile and FX sprites are authored at 1x, so they go straight down to
  their final size and stop there.

Not everything can land this way. asset/effect/hit_phoenix.png (5 frames) and
asset/weapon/fx/swing_arc.png (2 frames) are horizontal STRIPS; a single still
cannot replace an animation, so those two stay in new_asset/generated as
reference for the sheets and are listed in ASSET_REQUIREMENTS.md.

Run: python asset/build_from_generated.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "new_asset" / "generated"

ICON_LOGICAL_PX = 32
ICON_EXPORT_SCALE = 16
# How far a pixel may drift from the corner colour and still count as
# background. The renders use one flat colour, but PNG rounding leaves a little
# noise along the edge of it.
BACKGROUND_TOLERANCE = 26
# Colour the flood fill paints the background with before it is turned
# transparent. Magenta at full saturation does not occur in this art.
MARKER = (255, 0, 255)
# Padding kept inside the target box so a subject never touches the edge.
EDGE_PADDING_PX = 1

# (generated file stem, target path relative to the repo, is a 16x icon)
INSTALL = [
    ("icon_old_talisman", "asset/ui/weapon_icons/old_talisman.png", True),
    ("icon_fire_talisman", "asset/ui/weapon_icons/fire_talisman.png", True),
    ("icon_beopgeom", "asset/ui/weapon_icons/beopgeom.png", True),
    ("icon_bongmageom", "asset/ui/weapon_icons/bongmageom.png", True),
    ("icon_hwabu", "asset/ui/weapon_icons/hwabu.png", True),
    ("icon_noebu", "asset/ui/weapon_icons/noebu.png", True),
    ("icon_noejeongbu", "asset/ui/weapon_icons/noejeongbu.png", True),
    ("icon_jineon", "asset/ui/weapon_icons/jineon.png", True),
    ("icon_bongin_jineon", "asset/ui/weapon_icons/bongin_jineon.png", True),
    ("travel_old_talisman", "asset/weapon/travel/old_talisman.png", False),
    ("travel_fire_talisman", "asset/weapon/travel/fire_talisman.png", False),
    ("travel_beopgeom", "asset/weapon/travel/beopgeom.png", False),
    ("travel_bongmageom", "asset/weapon/travel/bongmageom.png", False),
    ("travel_hwabu", "asset/weapon/travel/hwabu.png", False),
    ("travel_hwaryeongbu", "asset/weapon/travel/hwaryeongbu.png", False),
    ("travel_noebu", "asset/weapon/travel/noebu.png", False),
    ("travel_noejeongbu", "asset/weapon/travel/noejeongbu.png", False),
    ("travel_sal", "asset/weapon/travel/sal.png", False),
    ("travel_gwisal", "asset/weapon/travel/gwisal.png", False),
    ("fx_sinjang", "asset/weapon/fx/sinjang.png", False),
    ("fx_arc_blade", "asset/weapon/fx/arc_blade.png", False),
]


def cut_background(image: Image.Image) -> Image.Image:
    """Drops the flat backdrop by flood-filling inward from all four corners.

    A global colour match would also punch holes anywhere inside the subject
    that happens to share the backdrop's colour — a pale talisman on a pale
    ground loses its middle that way. Filling from the border only removes what
    is actually connected to the outside.
    """
    rgb = image.convert("RGB")
    width, height = rgb.size
    for corner in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        ImageDraw.floodfill(rgb, corner, MARKER, thresh=BACKGROUND_TOLERANCE)
    out = Image.new("RGBA", rgb.size, (0, 0, 0, 0))
    source = rgb.load()
    target = out.load()
    for y in range(height):
        for x in range(width):
            pixel = source[x, y]
            if pixel != MARKER:
                target[x, y] = (*pixel, 255)
    return out


def fit(image: Image.Image, box: tuple[int, int]) -> Image.Image:
    """Trims to the subject and reduces it to fit `box`, keeping its aspect.

    Reducing happens on PREMULTIPLIED alpha: reducing straight RGBA drags the
    colour of transparent pixels into the edge, which on a dark-outlined sprite
    reads as a grey fringe rather than an outline.
    """
    bounds = image.split()[3].getbbox()
    if bounds is None:
        raise ValueError("image is fully transparent after the background cut")
    subject = image.crop(bounds)

    premultiplied = Image.new("RGBA", subject.size)
    src = subject.load()
    dst = premultiplied.load()
    for y in range(subject.size[1]):
        for x in range(subject.size[0]):
            r, g, b, a = src[x, y]
            dst[x, y] = (r * a // 255, g * a // 255, b * a // 255, a)

    room = (max(box[0] - 2 * EDGE_PADDING_PX, 1), max(box[1] - 2 * EDGE_PADDING_PX, 1))
    scale = min(room[0] / subject.size[0], room[1] / subject.size[1])
    size = (max(round(subject.size[0] * scale), 1), max(round(subject.size[1] * scale), 1))
    small = premultiplied.resize(size, Image.BOX if scale < 1.0 else Image.NEAREST)

    restored = Image.new("RGBA", size)
    src = small.load()
    dst = restored.load()
    for y in range(size[1]):
        for x in range(size[0]):
            r, g, b, a = src[x, y]
            if a == 0:
                dst[x, y] = (0, 0, 0, 0)
            else:
                dst[x, y] = (
                    min(255, r * 255 // a), min(255, g * 255 // a),
                    min(255, b * 255 // a), a,
                )

    canvas = Image.new("RGBA", box, (0, 0, 0, 0))
    canvas.paste(restored, ((box[0] - size[0]) // 2, (box[1] - size[1]) // 2))
    return canvas


def install(stem: str, target_rel: str, is_icon: bool) -> None:
    source = SOURCE_DIR / f"{stem}.png"
    target = ROOT / target_rel
    if not source.exists():
        print(f"  {target_rel}: source missing ({stem}.png)")
        return
    if not target.exists():
        print(f"  {target_rel}: no existing file to take the size from, skipped")
        return
    with Image.open(target) as existing:
        box = existing.size
    logical = (ICON_LOGICAL_PX, ICON_LOGICAL_PX) if is_icon else box

    art = fit(cut_background(Image.open(source).convert("RGBA")), logical)
    if is_icon:
        art = art.resize(
            (logical[0] * ICON_EXPORT_SCALE, logical[1] * ICON_EXPORT_SCALE), Image.NEAREST
        )
    if art.size != box:
        raise ValueError(f"{target_rel}: built {art.size}, file is {box}")
    art.save(target)
    used = art.split()[3].getbbox()
    print(f"  {target_rel}: {art.size}, subject {used[2] - used[0]}x{used[3] - used[1]}")


def main() -> None:
    if not SOURCE_DIR.is_dir():
        raise SystemExit(f"drop folder missing: {SOURCE_DIR}")
    for entry in INSTALL:
        install(*entry)


if __name__ == "__main__":
    main()
