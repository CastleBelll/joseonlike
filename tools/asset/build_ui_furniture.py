"""Build stretch-safe JOSEONLIKE UI furniture from the established palette.

Generated sheets provide the illustrative content and identity-bearing icons.  Frames,
bars, sliders, and card backs are deterministic because their stretch centres and text
contrast must remain exact at arbitrary mobile sizes.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
UI = ROOT / "asset/ui"

INK = (26, 22, 19, 255)
PAPER = (237, 224, 196, 255)
PAPER_DARK = (214, 197, 161, 255)
VERMILION = (191, 64, 42, 255)
VERMILION_DARK = (139, 44, 28, 255)
GOLD = (196, 154, 61, 255)
LOCKED = (107, 100, 89, 255)
SUCCESS = (74, 124, 66, 255)
DANGER = (163, 42, 42, 255)
TRANSPARENT = (0, 0, 0, 0)


def save(path: str, image: Image.Image) -> None:
    target = UI / path
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target)
    print(target.relative_to(ROOT))


def frame(
    size: tuple[int, int], fill=PAPER, border=INK, accent=VERMILION,
    *, corners: str = "square", inset: int = 3,
) -> Image.Image:
    image = Image.new("RGBA", size, TRANSPARENT)
    draw = ImageDraw.Draw(image)
    width, height = size
    draw.rectangle((0, 0, width - 1, height - 1), fill=border)
    draw.rectangle((2, 2, width - 3, height - 3), fill=accent)
    draw.rectangle((inset + 2, inset + 2, width - inset - 3, height - inset - 3), fill=fill)
    # The variants alter corner silhouettes and ornaments, never only hue.
    if corners == "notched":
        for x, y in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
            draw.rectangle((max(0, x - 2), max(0, y - 2), min(width - 1, x + 2), min(height - 1, y + 2)), fill=TRANSPARENT)
        for x, y in ((4, 4), (width - 5, 4), (4, height - 5), (width - 5, height - 5)):
            draw.rectangle((x - 1, y - 1, x + 1, y + 1), fill=GOLD)
    elif corners == "crowned":
        crown = ((width // 2 - 6, 4), (width // 2 - 3, 1), (width // 2, 4),
                 (width // 2 + 3, 1), (width // 2 + 6, 4), (width // 2 + 5, 7),
                 (width // 2 - 5, 7))
        draw.polygon(crown, fill=GOLD)
        draw.rectangle((width // 2 - 5, 7, width // 2 + 5, 8), fill=INK)
    elif corners == "broken":
        draw.line((0, height // 2 - 3, 6, height // 2 + 3), fill=TRANSPARENT, width=2)
        draw.line((width - 7, height // 2 + 3, width - 1, height // 2 - 3), fill=TRANSPARENT, width=2)
    return image


def bar(fill_color, *, symbol: str = "") -> Image.Image:
    image = frame((96, 16), INK, INK, PAPER_DARK, inset=2)
    draw = ImageDraw.Draw(image)
    draw.rectangle((6, 5, 89, 10), fill=fill_color)
    if symbol == "boss":
        draw.polygon(((1, 1), (5, 1), (3, 5)), fill=GOLD)
        draw.polygon(((94, 1), (90, 1), (92, 5)), fill=GOLD)
    return image


def toggle(enabled: bool) -> Image.Image:
    image = frame((48, 32), PAPER_DARK if not enabled else SUCCESS, INK,
                  LOCKED if not enabled else GOLD, inset=3)
    draw = ImageDraw.Draw(image)
    knob_x = 31 if enabled else 5
    draw.rectangle((knob_x, 7, knob_x + 11, 24), fill=PAPER)
    draw.rectangle((knob_x + 2, 9, knob_x + 9, 22), fill=INK)
    if enabled:
        draw.line((knob_x + 3, 16, knob_x + 5, 19, knob_x + 9, 12), fill=SUCCESS, width=2)
    else:
        draw.line((knob_x + 3, 12, knob_x + 9, 19), fill=LOCKED, width=2)
        draw.line((knob_x + 9, 12, knob_x + 3, 19), fill=LOCKED, width=2)
    return image


def knob() -> Image.Image:
    image = Image.new("RGBA", (24, 24), TRANSPARENT)
    draw = ImageDraw.Draw(image)
    draw.rectangle((2, 2, 21, 21), fill=INK)
    draw.rectangle((5, 5, 18, 18), fill=GOLD)
    draw.rectangle((9, 9, 14, 14), fill=PAPER)
    return image


def language_icon() -> Image.Image:
    """Text-free language toggle; the generated cell contained malformed pseudo-Hangul."""
    image = Image.new("RGBA", (32, 32), TRANSPARENT)
    draw = ImageDraw.Draw(image)
    draw.rectangle((2, 3, 20, 17), fill=INK)
    draw.rectangle((5, 6, 17, 14), fill=VERMILION)
    draw.polygon(((7, 17), (11, 17), (7, 22)), fill=INK)
    draw.rectangle((12, 13, 29, 27), fill=INK)
    draw.rectangle((15, 16, 26, 24), fill=PAPER)
    draw.polygon(((24, 27), (20, 27), (24, 31)), fill=INK)
    draw.ellipse((9, 8, 13, 12), fill=PAPER)
    draw.rectangle((18, 18, 22, 22), fill=VERMILION)
    return image


def pause_icon() -> Image.Image:
    image = Image.new("RGBA", (32, 32), TRANSPARENT)
    draw = ImageDraw.Draw(image)
    draw.ellipse((2, 2, 29, 29), fill=INK)
    draw.ellipse((5, 5, 26, 26), fill=VERMILION)
    draw.rectangle((10, 9, 13, 22), fill=PAPER)
    draw.rectangle((18, 9, 21, 22), fill=PAPER)
    return image


def archive_icon() -> Image.Image:
    image = Image.new("RGBA", (32, 32), TRANSPARENT)
    draw = ImageDraw.Draw(image)
    draw.rectangle((3, 5, 26, 26), fill=INK)
    draw.rectangle((6, 7, 23, 24), fill=PAPER)
    draw.rectangle((3, 4, 26, 7), fill=GOLD)
    draw.rectangle((3, 24, 26, 27), fill=GOLD)
    for y in (11, 15, 19):
        draw.rectangle((9, y, 20, y + 1), fill=INK)
    draw.line((23, 8, 28, 25), fill=INK, width=3)
    draw.line((24, 8, 29, 25), fill=VERMILION, width=1)
    return image


def shrine_icon() -> Image.Image:
    image = Image.new("RGBA", (32, 32), TRANSPARENT)
    draw = ImageDraw.Draw(image)
    draw.polygon(((5, 3), (23, 5), (27, 25), (9, 29)), fill=INK)
    draw.polygon(((8, 6), (21, 7), (24, 23), (11, 26)), fill=PAPER)
    draw.rectangle((12, 10, 18, 12), fill=VERMILION)
    draw.polygon(((12, 17), (16, 13), (20, 17), (16, 21)), fill=VERMILION)
    draw.ellipse((22, 19, 30, 27), fill=INK)
    draw.ellipse((24, 21, 28, 25), fill=GOLD)
    return image


def taoist_class_icon() -> Image.Image:
    image = Image.new("RGBA", (32, 32), TRANSPARENT)
    draw = ImageDraw.Draw(image)
    draw.polygon(((8, 3), (23, 6), (20, 28), (5, 24)), fill=INK)
    draw.polygon(((10, 6), (20, 8), (18, 25), (8, 22)), fill=PAPER)
    draw.ellipse((11, 10, 17, 16), outline=VERMILION, width=2)
    draw.line((12, 20, 17, 18, 19, 21), fill=VERMILION, width=2)
    draw.arc((1, 9, 12, 25), 80, 280, fill=GOLD, width=2)
    draw.arc((19, 7, 31, 24), 250, 100, fill=GOLD, width=2)
    return image


def main() -> None:
    specs = {
        "main/version_plaque_9slice.png": frame((96, 32), PAPER_DARK),
        "profile/slot_9slice.png": frame((96, 64), PAPER),
        "profile/slot_selected_9slice.png": frame((96, 64), PAPER, accent=GOLD, corners="notched"),
        "character/card_unselected_9slice.png": frame((96, 96), PAPER_DARK),
        "character/card_selected_9slice.png": frame((96, 96), PAPER, accent=GOLD, corners="notched"),
        "character/preview_panel_9slice.png": frame((96, 64), PAPER),
        "area/card_unselected_9slice.png": frame((96, 64), PAPER_DARK),
        "area/card_selected_9slice.png": frame((96, 64), PAPER, accent=GOLD, corners="notched"),
        "area/card_locked_9slice.png": frame((96, 64), LOCKED, accent=INK, corners="broken"),
        "camp/interior_panel_9slice.png": frame((96, 64), PAPER),
        "hud/bar_background_9slice.png": bar(INK),
        "hud/hp_fill_9slice.png": bar(DANGER),
        "hud/xp_fill_9slice.png": bar(GOLD),
        "hud/boss_fill_9slice.png": bar(VERMILION, symbol="boss"),
        "hud/timer_frame_9slice.png": frame((96, 32), INK, accent=GOLD),
        "feedback/damage_toast_9slice.png": frame((96, 32), PAPER, accent=DANGER, corners="broken"),
        "feedback/pickup_toast_9slice.png": frame((96, 32), PAPER, accent=GOLD, corners="notched"),
        "level_up/card_common_9slice.png": frame((96, 64), PAPER_DARK, accent=LOCKED),
        "level_up/card_rare_9slice.png": frame((96, 64), PAPER, accent=VERMILION, corners="notched"),
        "level_up/card_legendary_9slice.png": frame((96, 64), PAPER, accent=GOLD, corners="crowned"),
        "settings/slider_track_9slice.png": bar(LOCKED),
        "settings/slider_fill_9slice.png": bar(GOLD),
        "results/reward_callout_9slice.png": frame((96, 48), PAPER, accent=GOLD, corners="notched"),
        "results/unlock_callout_9slice.png": frame((96, 48), PAPER, accent=VERMILION, corners="crowned"),
        "meta/list_row_9slice.png": frame((96, 48), PAPER_DARK),
        "meta/list_row_claimed_9slice.png": frame((96, 48), PAPER, accent=SUCCESS, corners="notched"),
        "meta/progress_background_9slice.png": bar(INK),
        "meta/progress_fill_9slice.png": bar(SUCCESS),
        "monetization/reward_prompt_9slice.png": frame((96, 64), PAPER, accent=GOLD, corners="crowned"),
        "monetization/continue_prompt_9slice.png": frame((96, 64), PAPER, accent=VERMILION, corners="notched"),
        "monetization/currency_display_9slice.png": frame((96, 32), INK, accent=GOLD),
    }
    for path, image in specs.items():
        save(path, image)
    save("settings/slider_knob.png", knob())
    save("settings/toggle_off.png", toggle(False))
    save("settings/toggle_on.png", toggle(True))
    save("settings/language.png", language_icon())
    save("hud/icons/pause.png", pause_icon())
    save("camp/icons/archive.png", archive_icon())
    save("camp/icons/shrine.png", shrine_icon())
    save("character/classes/taoist.png", taoist_class_icon())


if __name__ == "__main__":
    main()
