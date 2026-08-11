"""Measure button WCAG contrast and non-colour state differences."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
CHROME = ROOT / "asset/ui/chrome"
RAW = ROOT / "asset/ui/raw/button_redesign"
DIRECTIONS = ("royal_seal", "ink_tablet", "knotted_talisman")
STATES = ("normal", "hover", "pressed", "disabled")
TEXT = (245, 238, 222)


def relative_luminance(rgb: tuple[int, int, int]) -> float:
    channels = []
    for value in rgb:
        channel = value / 255
        channels.append(channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4)
    return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722


def contrast(first: tuple[int, int, int], second: tuple[int, int, int]) -> float:
    light, dark = sorted((relative_luminance(first), relative_luminance(second)), reverse=True)
    return round((light + 0.05) / (dark + 0.05), 2)


def changed(first: Image.Image, second: Image.Image) -> dict:
    rgba = ImageChops.difference(first.convert("RGBA"), second.convert("RGBA"))
    alpha = ImageChops.difference(first.getchannel("A"), second.getchannel("A"))
    changed_pixels = sum(pixel != (0, 0, 0, 0) for pixel in rgba.get_flattened_data())
    alpha_pixels = sum(pixel != 0 for pixel in alpha.get_flattened_data())
    return {
        "changed_pixels": changed_pixels,
        "alpha_changed_pixels": alpha_pixels,
        "shape_distinct": alpha_pixels >= 8,
    }


def make_overview() -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    scale = 4
    cell_w, cell_h = 272, 180
    sheet = Image.new("RGBA", (cell_w * 4, cell_h * 3), (237, 224, 196, 255))
    draw = ImageDraw.Draw(sheet)
    for row, direction in enumerate(DIRECTIONS):
        draw.text((8, row * cell_h + 4), direction.replace("_", " "), fill=(26, 22, 19, 255))
        for column, state in enumerate(STATES):
            path = CHROME / "candidates" / direction / f"button_{state}_9slice.png"
            image = Image.open(path).convert("RGBA").resize((64 * scale, 32 * scale), Image.Resampling.NEAREST)
            x = column * cell_w + 8
            y = row * cell_h + 28
            sheet.alpha_composite(image, (x, y))
            draw.text((x, y + 132), state, fill=(26, 22, 19, 255))
    sheet.save(RAW / "button_directions_overview.png")


def main() -> None:
    results = {
        "text_colour": "#f5eede",
        "minimum_enabled_contrast": 4.5,
        "nine_slice_margins": {"left": 6, "top": 8, "right": 6, "bottom": 8},
        "directions": {},
        "selected": "royal_seal",
    }
    for direction in DIRECTIONS:
        images = {
            state: Image.open(CHROME / "candidates" / direction / f"button_{state}_9slice.png").convert("RGBA")
            for state in STATES
        }
        state_metrics = {}
        for state, image in images.items():
            center = image.getpixel((32, 16))[:3]
            state_metrics[state] = {
                "canvas": list(image.size),
                "center_fill": "#%02x%02x%02x" % center,
                "text_contrast": contrast(TEXT, center),
                "hard_alpha": {pixel[3] for pixel in image.get_flattened_data()} <= {0, 255},
            }
            if state != "normal":
                state_metrics[state]["difference_from_normal"] = changed(images["normal"], image)
        enabled_pass = all(state_metrics[state]["text_contrast"] >= 4.5 for state in ("normal", "hover", "pressed"))
        pressed_shape = state_metrics["pressed"]["difference_from_normal"]["shape_distinct"]
        results["directions"][direction] = {
            "states": state_metrics,
            "enabled_contrast_pass": enabled_pass,
            "pressed_shape_pass": pressed_shape,
            "accepted": enabled_pass and pressed_shape and all(item["hard_alpha"] for item in state_metrics.values()),
        }

    results["accepted"] = all(record["accepted"] for record in results["directions"].values())
    make_overview()
    target = CHROME / "button_redesign_metrics.json"
    target.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {target.relative_to(ROOT)}: accepted={results['accepted']}")
    for direction, record in results["directions"].items():
        contrasts = {state: data["text_contrast"] for state, data in record["states"].items()}
        pressed = record["states"]["pressed"]["difference_from_normal"]
        print(f"{direction}: contrast={contrasts}; pressed={pressed}")


if __name__ == "__main__":
    main()
