"""Rebuild UI chrome pieces from the owner's HD singles (2026-08-28 drop).

The owner regenerated the chrome kit as individual high-resolution images —
one piece per file — instead of one packed sheet. They live untouched in
new_asset/owner/ui_hd/ (excluded from every export); this script alpha-trims
each one and LANCZOS-downscales it onto the EXACT canvas of the build/ piece
it replaces, so every 9-slice margin and layout constant in ui_icons.gd keeps
meaning what it meant. Downscale-from-big is the documented win (ART_PROMPTS
1.1): the reduction is the anti-aliasing.

Pieces with no HD replacement (bars, toggles, checkboxes, plaques, banners,
stat_strip, slot_4) keep their kit-sliced build files.

Run: python asset/ui/build_chrome_hd.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "new_asset" / "owner" / "ui_hd"
OUT = ROOT / "asset" / "ui" / "chrome" / "build"

STAMP = "ChatGPT Image 2026년 8월 28일 오후 {}.png"

# piece name -> (source file, target size). Target = the old build piece's
# canvas, measured before this rebuild, so downstream geometry is unchanged.
MAPPING = {
    # wide plates (no tassel)
    "plate_cream": (STAMP.format("02_22_27"), (210, 84)),
    "plate_brown": (STAMP.format("02_23_09"), (211, 83)),
    "plate_purple": (STAMP.format("02_24_09"), (210, 83)),
    "plate_red": (STAMP.format("02_25_57"), (212, 83)),
    # tasseled plates (the old tassel_* family IS plate-with-tassel)
    "tassel_cream": (STAMP.format("02_19_37"), (209, 135)),
    "tassel_tan": (STAMP.format("02_21_29"), (208, 135)),
    "tassel_purple": (STAMP.format("02_22_01"), (216, 134)),
    "tassel_grey": (STAMP.format("02_24_50"), (205, 135)),
    # square slot frames, colour-matched to the old tinted set
    "slot_0": (STAMP.format("02_27_00"), (108, 112)),
    "slot_1": (STAMP.format("02_28_08"), (108, 112)),
    "slot_2": (STAMP.format("02_28_32"), (108, 112)),
    "slot_3": (STAMP.format("02_28_54"), (108, 112)),
    "slot_5": (STAMP.format("02_31_11"), (108, 112)),
    "slot_6": (STAMP.format("02_30_58"), (108, 112)),
    "slot_7": (STAMP.format("02_32_47"), (108, 112)),
    # round discs, colour-matched to the old set; the single dark-brown HD
    # round stands in for both old dark variants
    "disc_0": (STAMP.format("02_34_15"), (96, 100)),
    "disc_1": (STAMP.format("02_34_41"), (96, 100)),
    "disc_2": (STAMP.format("02_35_19"), (97, 100)),
    "disc_3": (STAMP.format("02_37_37"), (96, 100)),
    "disc_4": (STAMP.format("02_36_52"), (96, 100)),
    "disc_5": (STAMP.format("02_41_12"), (96, 100)),
    "disc_6": (STAMP.format("02_41_12"), (97, 100)),
    "disc_7": (STAMP.format("02_40_58"), (96, 100)),
    "disc_8": (STAMP.format("02_40_45"), (96, 100)),
    # square framed buttons
    "btn_list": (STAMP.format("02_44_13"), (77, 76)),
    "btn_menu": (STAMP.format("02_44_42"), (74, 76)),
    "btn_grid": (STAMP.format("02_44_54"), (76, 76)),
    "btn_home": (STAMP.format("02_46_07"), (75, 76)),
    "btn_left": (STAMP.format("02_46_37"), (76, 75)),
    "btn_close": (STAMP.format("02_46_55"), (75, 76)),
    # round rim icon buttons
    "icon_help": (STAMP.format("02_48_46"), (78, 80)),
    "icon_sound": (STAMP.format("02_50_41"), (78, 80)),
    "icon_gear": (STAMP.format("02_52_05"), (78, 80)),
    "icon_music": (STAMP.format("02_53_08"), (78, 79)),
    "icon_mail": (STAMP.format("02_54_44"), (76, 79)),
    "icon_info": (STAMP.format("02_55_53"), (79, 80)),
    "icon_trophy": ("픽셀 트로피 코인 아이콘.png", (77, 79)),
    # verticals
    "scroll": ("두루마리배너.png", (248, 416)),
    "title_plaque": ("두루마리액자.png", (216, 418)),
    # the paper every popup sits on
    "paper_panel": ("paper_panel_hd.png", (368, 404)),
    # new pieces with no old counterpart — parked at sensible sizes, unwired
    "icon_skull": (STAMP.format("03_02_11"), (78, 80)),
    "icon_scroll_open": (STAMP.format("03_03_59"), (78, 80)),
    "bar_level_hd": (STAMP.format("02_56_57"), (625, 62)),
    "bar_exp_hd": (STAMP.format("02_59_28"), (625, 62)),
}

ALPHA_FLOOR = 8


def trim(image):
    """Crop to the piece's own alpha footprint."""
    alpha = image.getchannel("A").point(lambda a: 255 if a > ALPHA_FLOOR else 0)
    bbox = alpha.getbbox()
    return image.crop(bbox) if bbox else image


def main():
    missing = []
    for piece, (source_name, size) in MAPPING.items():
        source = SRC / source_name
        if not source.exists():
            missing.append(source_name)
            continue
        image = trim(Image.open(source).convert("RGBA"))
        image = image.resize(size, Image.LANCZOS)
        image.save(OUT / f"{piece}.png")
        print(f"  {piece:<16} <- {source_name}  -> {size[0]}x{size[1]}")
    # btn_right is the mirrored btn_left, same as the game mirrors sprites.
    left = OUT / "btn_left.png"
    if left.exists():
        mirrored = Image.open(left).transpose(Image.FLIP_LEFT_RIGHT)
        mirrored.save(OUT / "btn_right.png")
        print("  btn_right        <- btn_left (mirrored)")
    if missing:
        raise SystemExit(f"missing sources: {missing}")
    print(f"{len(MAPPING) + 1} pieces -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
