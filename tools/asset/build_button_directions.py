"""Build three stretch-safe Joseon button directions and select the seal family.

The state silhouettes are authored, not tinted: hover gains gold focus brackets,
pressed moves the physical face down two pixels, and disabled breaks the frame.
All four fills keep the existing light button text above WCAG AA contrast.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
CHROME = ROOT / "asset/ui/chrome"
CANDIDATES = CHROME / "candidates"

INK = (26, 22, 19, 255)
PAPER = (237, 224, 196, 255)
PAPER_DARK = (214, 197, 161, 255)
VERMILION = (191, 64, 42, 255)
VERMILION_DARK = (139, 44, 28, 255)
GOLD = (196, 154, 61, 255)
LOCKED = (107, 100, 89, 255)
TRANSPARENT = (0, 0, 0, 0)

SIZE = (64, 32)
MARGINS = {"left": 6, "top": 8, "right": 6, "bottom": 8}
STATES = ("normal", "hover", "pressed", "disabled")


def _canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", SIZE, TRANSPARENT)
    return image, ImageDraw.Draw(image)


def _cut_chamfers(draw: ImageDraw.ImageDraw) -> None:
    for point in ((0, 0), (1, 0), (0, 1), (62, 0), (63, 0), (63, 1),
                  (0, 30), (0, 31), (1, 31), (63, 30), (62, 31), (63, 31)):
        draw.point(point, fill=TRANSPARENT)


def royal_seal(state: str) -> Image.Image:
    """Vermilion royal seal: strongest Joseon identity and shipped direction."""
    image, draw = _canvas()
    y = 4 if state == "pressed" else 2
    bottom = 30 if state == "pressed" else 28
    draw.rectangle((2, y, 61, bottom), fill=INK)
    draw.rectangle((4, y + 2, 59, bottom - 2), fill=VERMILION_DARK)
    draw.rectangle((6, y + 4, 57, bottom - 4), fill=INK if state == "hover" else VERMILION_DARK)

    # A seal impression has clipped corners; the centre remains stretch-flat.
    _cut_chamfers(draw)
    for x in (2, 61):
        draw.rectangle((x, y, x, y + 3), fill=TRANSPARENT)
        draw.rectangle((x, bottom - 3, x, bottom), fill=TRANSPARENT)
    for x in (7, 54):
        draw.rectangle((x, y + 2, x + 2, y + 3), fill=GOLD)

    if state == "normal":
        draw.rectangle((10, y + 2, 53, y + 2), fill=VERMILION)
        draw.rectangle((10, bottom - 2, 53, bottom - 2), fill=INK)
    elif state == "hover":
        # Gold brackets are a shape cue as well as a brighter focus cue.
        for x in (4, 57):
            draw.rectangle((x, y + 5, x + 2, y + 7), fill=GOLD)
            draw.rectangle((x, bottom - 7, x + 2, bottom - 5), fill=GOLD)
        draw.rectangle((11, y + 2, 52, y + 2), fill=GOLD)
    elif state == "pressed":
        # The complete face is two pixels lower, with a deep top recess.
        draw.rectangle((4, 2, 59, 3), fill=INK)
        draw.rectangle((9, bottom - 3, 54, bottom - 1), fill=INK)
        draw.rectangle((29, y, 34, y + 1), fill=TRANSPARENT)
    else:
        draw.rectangle((6, y + 4, 57, bottom - 4), fill=LOCKED)
        for x in range(8, 57, 8):
            draw.line((x, y + 5, x + 4, bottom - 5), fill=INK, width=1)
        # Broken frame is an explicit disabled shape cue.
        draw.rectangle((27, y, 36, y + 2), fill=TRANSPARENT)
        draw.rectangle((27, bottom - 2, 36, bottom), fill=TRANSPARENT)
    return image


def ink_tablet(state: str) -> Image.Image:
    """Dark scholar's inkstone with vermilion binding tabs."""
    image, draw = _canvas()
    y = 5 if state == "pressed" else 3
    bottom = 30 if state == "pressed" else 28
    draw.rectangle((1, y, 62, bottom), fill=INK)
    draw.rectangle((4, y + 3, 59, bottom - 3), fill=VERMILION_DARK if state != "disabled" else LOCKED)
    draw.rectangle((7, y + 5, 56, bottom - 5), fill=INK)
    # Binding tabs change length by state and survive horizontal stretching.
    tab = 8 if state == "hover" else 5
    draw.rectangle((0, y + 8, tab, bottom - 8), fill=GOLD if state == "hover" else VERMILION)
    draw.rectangle((63 - tab, y + 8, 63, bottom - 8), fill=GOLD if state == "hover" else VERMILION)
    if state == "pressed":
        draw.rectangle((4, 2, 59, 4), fill=INK)
        draw.rectangle((9, bottom - 2, 54, bottom), fill=VERMILION_DARK)
    elif state == "disabled":
        draw.rectangle((0, y + 8, tab, bottom - 8), fill=LOCKED)
        draw.rectangle((63 - tab, y + 8, 63, bottom - 8), fill=LOCKED)
        draw.rectangle((28, y, 35, y + 3), fill=TRANSPARENT)
    return image


def knotted_talisman(state: str) -> Image.Image:
    """Paper talisman outline around a dark core with knotted side cords."""
    image, draw = _canvas()
    y = 4 if state == "pressed" else 2
    bottom = 30 if state == "pressed" else 28
    draw.rectangle((5, y, 58, bottom), fill=INK)
    draw.rectangle((7, y + 2, 56, bottom - 2), fill=VERMILION_DARK if state != "disabled" else LOCKED)
    draw.rectangle((9, y + 4, 54, bottom - 4), fill=INK)
    # Side knots create a unique non-rectangular silhouette.
    knot = GOLD if state == "hover" else (LOCKED if state == "disabled" else PAPER_DARK)
    draw.polygon(((1, 12 + y // 2), (5, 8 + y // 2), (9, 12 + y // 2), (5, 16 + y // 2)), fill=knot)
    draw.polygon(((62, 12 + y // 2), (58, 8 + y // 2), (54, 12 + y // 2), (58, 16 + y // 2)), fill=knot)
    if state == "hover":
        draw.rectangle((11, y + 2, 52, y + 3), fill=GOLD)
    elif state == "pressed":
        draw.rectangle((7, 2, 56, 3), fill=INK)
        draw.rectangle((11, bottom - 3, 52, bottom - 1), fill=INK)
    elif state == "disabled":
        draw.line((24, y + 4, 39, bottom - 4), fill=LOCKED, width=2)
        draw.line((39, y + 4, 24, bottom - 4), fill=LOCKED, width=2)
    return image


def version_plaque() -> Image.Image:
    """Bring the title's small plaque into the shipped royal-seal family."""
    image = Image.new("RGBA", (96, 32), TRANSPARENT)
    draw = ImageDraw.Draw(image)
    draw.rectangle((1, 2, 94, 29), fill=INK)
    draw.rectangle((3, 4, 92, 27), fill=PAPER_DARK)
    draw.rectangle((6, 7, 89, 24), fill=PAPER)
    for x in (4, 89):
        draw.rectangle((x, 4, x + 3, 6), fill=VERMILION_DARK)
        draw.rectangle((x, 25, x + 3, 27), fill=VERMILION_DARK)
    draw.rectangle((43, 4, 52, 5), fill=GOLD)
    return image


def main() -> None:
    builders = {
        "royal_seal": royal_seal,
        "ink_tablet": ink_tablet,
        "knotted_talisman": knotted_talisman,
    }
    for direction, builder in builders.items():
        folder = CANDIDATES / direction
        folder.mkdir(parents=True, exist_ok=True)
        for state in STATES:
            builder(state).save(folder / f"button_{state}_9slice.png")

    # Royal seal ships at canonical paths; alternatives stay reviewable in-tree.
    CHROME.mkdir(parents=True, exist_ok=True)
    for state in STATES:
        royal_seal(state).save(CHROME / f"button_{state}_9slice.png")
    version_plaque().save(ROOT / "asset/ui/main/version_plaque_9slice.png")

    manifest = {
        "canvas": list(SIZE),
        "nine_slice_margins": MARGINS,
        "states": list(STATES),
        "directions": list(builders),
        "selected": "royal_seal",
        "state_shape_cues": {
            "normal": "raised top keyline and bottom shadow",
            "hover": "gold focus brackets and top rail",
            "pressed": "entire face shifted down two pixels with top recess and heavier foot",
            "disabled": "broken centre rails and diagonal hatch",
        },
    }
    (CHROME / "button_redesign.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("built 3 x 4 button candidates; selected royal_seal at canonical paths")


if __name__ == "__main__":
    main()
