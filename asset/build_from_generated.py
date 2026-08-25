"""Install the generated weapon/projectile/FX art at its real asset paths.

The images in new_asset/generated are large flat-background renders. The game
wants small transparent sprites at sizes that are already fixed by the shipped
art, so this cuts the background, trims to the figure, and fits it into the
EXISTING file's dimensions. Nothing here invents a size: every target is read
off the file it replaces, so an install can never quietly change how big a
thing is on screen.

Two kinds of target:

* icons (weapon and passive) are authored at 16x their 32px logical size,
  like every other sheet in the project, so they go down to 32 and back up
  with NEAREST — their 512x512 box is fixed by that contract, so an icon
  needs no existing file to take a size from;
* projectile, FX and pickup sprites are authored at 1x. An existing file
  supplies the size; a NEW sprite declares it as a "WxH" string, because
  there is nothing on disk to read it from.

뇌부/뇌정부 are absent on purpose: a chain weapon never flies (AutoWeapon
resolves it on the enemy it aimed at and ChainBolt draws the jump), so a
travel sprite for one would be art nobody sees. validate_data now fails any
chain weapon that declares one.

Not everything can land this way. asset/weapon/fx/swing_arc.png (2 frames) is
a horizontal STRIP; a single still cannot replace an animation, so it stays in
new_asset/generated as reference for the sheet and is listed in
ASSET_REQUIREMENTS.md.

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
    # N9-171 (owner: 살, 귀살 무기 이미지, 투사체 이미지도 수정해 너무 과해):
    # the pair was a cracked stone tablet under a purple aura and a scribble of
    # violet flecks. One iron ritual spike, one slim sliver, and the evolution
    # keeps the base silhouette. The travel sprites stop being 4-frame strips —
    # the flicker was most of what made them noisy — so they declare a size.
    ("icon_sal", "asset/ui/weapon_icons/sal.png", True),
    ("icon_gwisal", "asset/ui/weapon_icons/gwisal.png", True),
    ("travel_sal", "asset/weapon/travel/sal.png", "40x14"),
    ("travel_gwisal", "asset/weapon/travel/gwisal.png", "40x14"),
    ("travel_old_talisman", "asset/weapon/travel/old_talisman.png", False),
    ("travel_fire_talisman", "asset/weapon/travel/fire_talisman.png", False),
    ("travel_hwabu", "asset/weapon/travel/hwabu.png", False),
    ("travel_hwaryeongbu", "asset/weapon/travel/hwaryeongbu.png", False),
    ("fx_sinjang", "asset/weapon/fx/sinjang.png", False),
    ("fx_arc_blade", "asset/weapon/fx/arc_blade.png", False),
    # N9-89: the full passive set as one hand — the shipped eleven were a
    # free-pack grab bag (western boots, a clover, a gear-heart) and seven
    # passives had no icon at all.
    ("passive_attack_damage", "asset/ui/passive_icons/attack_damage.png", True),
    ("passive_attack_speed", "asset/ui/passive_icons/attack_speed.png", True),
    ("passive_move_speed", "asset/ui/passive_icons/move_speed.png", True),
    ("passive_max_hp", "asset/ui/passive_icons/max_hp.png", True),
    ("passive_hp_regen", "asset/ui/passive_icons/hp_regen.png", True),
    ("passive_defense", "asset/ui/passive_icons/defense.png", True),
    ("passive_luck", "asset/ui/passive_icons/luck.png", True),
    ("passive_magnet_radius", "asset/ui/passive_icons/magnet_radius.png", True),
    ("passive_xp_gain", "asset/ui/passive_icons/xp_gain.png", True),
    ("passive_projectile_count", "asset/ui/passive_icons/projectile_count.png", True),
    ("passive_projectile_speed", "asset/ui/passive_icons/projectile_speed.png", True),
    ("passive_crit_chance", "asset/ui/passive_icons/crit_chance.png", True),
    ("passive_crit_damage", "asset/ui/passive_icons/crit_damage.png", True),
    ("passive_skill_power", "asset/ui/passive_icons/skill_power.png", True),
    ("passive_area_scale", "asset/ui/passive_icons/area_scale.png", True),
    ("passive_burn_power", "asset/ui/passive_icons/burn_power.png", True),
    ("passive_chain_amount", "asset/ui/passive_icons/chain_amount.png", True),
    ("passive_seal_haste", "asset/ui/passive_icons/seal_haste.png", True),
    # N9-115 (owner: too small on a phone screen): every pickup one step up.
    ("passive_pickup_magnet2", "asset/pickups/magnet.png", "18x18"),
    # N9-93 (owner: 약초 벽력부 자석 궤짝 새로 생성): the remaining three,
    # each at the size its consumer already draws 1:1.
    ("passive_pickup_health2", "asset/pickups/health.png", "16x16"),
    ("passive_pickup_nuke", "asset/pickups/nuke.png", "28x28"),
    ("passive_pickup_chest", "asset/pickups/chest.png", "38x38"),
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
    # PIL's floodfill returns immediately when the seed already carries the fill
    # colour, so a render whose backdrop IS magenta kept its whole background.
    # Paint with a colour the picture does not contain instead.
    used = {pixel for _count, pixel in rgb.getcolors(maxcolors=1 << 24) or []}
    marker = MARKER if MARKER not in used else next(
        candidate for candidate in (
            (255, 0, 254), (254, 0, 255), (255, 1, 255), (0, 255, 1), (1, 255, 0)
        ) if candidate not in used
    )
    for corner in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        ImageDraw.floodfill(rgb, corner, marker, thresh=BACKGROUND_TOLERANCE)
    out = Image.new("RGBA", rgb.size, (0, 0, 0, 0))
    source = rgb.load()
    target = out.load()
    for y in range(height):
        for x in range(width):
            pixel = source[x, y]
            # The flood stops wherever the render shaded its own backdrop past
            # the tolerance, which leaves magenta islands the trim then reads as
            # the subject. Saturated magenta is the one colour this art set does
            # not use, so whatever is left of it is backdrop.
            if pixel != marker and not (
                pixel[0] > 130 and pixel[2] > 130 and pixel[1] < 110
            ):
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


def install(stem: str, target_rel: str, mode) -> None:
    """mode: True = 16x icon (fixed 512 box), False = 1x at the existing
    file's size, "WxH" = 1x at that size whether or not the file exists."""
    source = SOURCE_DIR / f"{stem}.png"
    target = ROOT / target_rel
    if not source.exists():
        print(f"  {target_rel}: source missing ({stem}.png)")
        return
    is_icon = mode is True
    if is_icon:
        logical = (ICON_LOGICAL_PX, ICON_LOGICAL_PX)
        box = (ICON_LOGICAL_PX * ICON_EXPORT_SCALE, ICON_LOGICAL_PX * ICON_EXPORT_SCALE)
    elif isinstance(mode, str):
        logical = tuple(int(v) for v in mode.split("x"))
        box = logical
    else:
        if not target.exists():
            print(f"  {target_rel}: no existing file to take the size from, skipped")
            return
        with Image.open(target) as existing:
            box = existing.size
        logical = box

    art = fit(cut_background(Image.open(source).convert("RGBA")), logical)
    if is_icon:
        art = art.resize(box, Image.NEAREST)
    if art.size != box:
        raise ValueError(f"{target_rel}: built {art.size}, expected {box}")
    target.parent.mkdir(parents=True, exist_ok=True)
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
