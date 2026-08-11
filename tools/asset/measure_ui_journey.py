"""Measure the mobile UI-journey assets and write reproducible JSON evidence."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[2]
UI = ROOT / "asset/ui"

ICONS = (
    *(f"main/{name}.png" for name in ("start", "continue", "settings", "credits", "quit")),
    *(f"profile/{name}.png" for name in ("new_profile", "returning_profile", "delete_profile")),
    *(f"character/classes/{name}.png" for name in ("taoist", "warrior", "archer")),
    *(f"area/icons/{name}.png" for name in ("bamboo_forest", "abandoned_temple", "locked", "difficulty_1", "difficulty_2", "difficulty_3", "reward", "boss")),
    *(f"camp/icons/{name}.png" for name in ("workshop", "archive", "training_ground", "shrine")),
    *(f"hud/icons/{name}.png" for name in ("hp", "boss", "timer", "pause", "damage", "pickup", "kills", "level")),
    *(f"settings/{name}.png" for name in ("master_audio", "music", "effects", "language")),
    *(f"level_up/{name}.png" for name in ("tier_common", "tier_rare", "tier_legendary")),
    *(f"meta/{name}.png" for name in ("quest", "progress", "claimed", "unclaimed")),
    *(f"results/{name}.png" for name in ("new_unlock", "reward_chest")),
    *(f"monetization/{name}.png" for name in ("rewarded_ad", "continue_after_death", "currency")),
)
ILLUSTRATIONS = {
    **{f"character/portraits/{name}.png": [128, 128] for name in ("taoist", "warrior", "archer")},
    "area/cards/bamboo_forest.png": [224, 128],
    "area/cards/abandoned_temple.png": [224, 128],
    **{f"camp/interiors/{name}.png": [224, 112] for name in ("workshop", "archive", "training_ground", "shrine")},
    "results/victory_banner.png": [256, 128],
    "results/defeat_banner.png": [256, 128],
}
FURNITURE = {
    "main/version_plaque_9slice.png": ([96, 32], [8, 8, 8, 8]),
    "profile/slot_9slice.png": ([96, 64], [12, 12, 12, 12]),
    "profile/slot_selected_9slice.png": ([96, 64], [12, 12, 12, 12]),
    "character/card_unselected_9slice.png": ([96, 96], [12, 12, 12, 12]),
    "character/card_selected_9slice.png": ([96, 96], [12, 12, 12, 12]),
    "character/preview_panel_9slice.png": ([96, 64], [12, 12, 12, 12]),
    "area/card_unselected_9slice.png": ([96, 64], [12, 12, 12, 12]),
    "area/card_selected_9slice.png": ([96, 64], [12, 12, 12, 12]),
    "area/card_locked_9slice.png": ([96, 64], [12, 12, 12, 12]),
    "camp/interior_panel_9slice.png": ([96, 64], [12, 12, 12, 12]),
    "hud/bar_background_9slice.png": ([96, 16], [6, 6, 6, 6]),
    "hud/hp_fill_9slice.png": ([96, 16], [6, 6, 6, 6]),
    "hud/xp_fill_9slice.png": ([96, 16], [6, 6, 6, 6]),
    "hud/boss_fill_9slice.png": ([96, 16], [6, 6, 6, 6]),
    "hud/timer_frame_9slice.png": ([96, 32], [8, 8, 8, 8]),
    "feedback/damage_toast_9slice.png": ([96, 32], [8, 8, 8, 8]),
    "feedback/pickup_toast_9slice.png": ([96, 32], [8, 8, 8, 8]),
    "level_up/card_common_9slice.png": ([96, 64], [12, 12, 12, 12]),
    "level_up/card_rare_9slice.png": ([96, 64], [12, 12, 12, 12]),
    "level_up/card_legendary_9slice.png": ([96, 64], [12, 12, 12, 12]),
    "settings/slider_track_9slice.png": ([96, 16], [6, 6, 6, 6]),
    "settings/slider_fill_9slice.png": ([96, 16], [6, 6, 6, 6]),
    "results/reward_callout_9slice.png": ([96, 48], [10, 10, 10, 10]),
    "results/unlock_callout_9slice.png": ([96, 48], [10, 10, 10, 10]),
    "meta/list_row_9slice.png": ([96, 48], [10, 10, 10, 10]),
    "meta/list_row_claimed_9slice.png": ([96, 48], [10, 10, 10, 10]),
    "meta/progress_background_9slice.png": ([96, 16], [6, 6, 6, 6]),
    "meta/progress_fill_9slice.png": ([96, 16], [6, 6, 6, 6]),
    "monetization/reward_prompt_9slice.png": ([96, 64], [12, 12, 12, 12]),
    "monetization/continue_prompt_9slice.png": ([96, 64], [12, 12, 12, 12]),
    "monetization/currency_display_9slice.png": ([96, 32], [8, 8, 8, 8]),
}
FIXED_CONTROLS = {
    "settings/slider_knob.png": [24, 24],
    "settings/toggle_off.png": [48, 32],
    "settings/toggle_on.png": [48, 32],
}


def pixels(image: Image.Image):
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def relative_luminance(rgb: tuple[int, int, int]) -> float:
    values = []
    for value in rgb:
        channel = value / 255
        values.append(channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4)
    return 0.2126 * values[0] + 0.7152 * values[1] + 0.0722 * values[2]


def contrast(first: tuple[int, int, int], second: tuple[int, int, int]) -> float:
    a, b = relative_luminance(first), relative_luminance(second)
    return round((max(a, b) + 0.05) / (min(a, b) + 0.05), 2)


def image_metrics(path: Path, expected: list[int]) -> dict:
    image = Image.open(path).convert("RGBA")
    bbox = image.getbbox()
    opaque = sum(pixel[3] > 0 for pixel in pixels(image))
    alphas = {pixel[3] for pixel in pixels(image)}
    chroma = sum(
        pixel[3] > 0 and pixel[0] > 120 and pixel[2] > 120 and pixel[1] < 110
        and abs(pixel[0] - pixel[2]) < 85 and min(pixel[0], pixel[2]) - pixel[1] > 55
        for pixel in pixels(image)
    )
    bbox_size = [0, 0] if bbox is None else [bbox[2] - bbox[0], bbox[3] - bbox[1]]
    return {
        "canvas": list(image.size),
        "bbox": bbox_size,
        "opaque_pixels": opaque,
        "hard_alpha": alphas <= {0, 255},
        "opaque_chroma_pixels": chroma,
        "accepted": list(image.size) == expected and bbox is not None and alphas <= {0, 255} and chroma == 0,
    }


def changed(first: str, second: str) -> tuple[int, int]:
    a = Image.open(UI / first).convert("RGBA")
    b = Image.open(UI / second).convert("RGBA")
    diff = ImageChops.difference(a, b)
    rgba = sum(pixel != (0, 0, 0, 0) for pixel in pixels(diff))
    alpha = sum(left[3] != right[3] for left, right in zip(pixels(a), pixels(b)))
    return rgba, alpha


def main() -> None:
    results = {
        "icons": {}, "illustrations": {}, "furniture": {},
        "fixed_controls": {}, "state_differences": {},
    }
    for relative in ICONS:
        results["icons"][relative] = image_metrics(UI / relative, [32, 32])
    for relative, size in ILLUSTRATIONS.items():
        results["illustrations"][relative] = image_metrics(UI / relative, size)
    palette = {
        (26, 22, 19), (237, 224, 196), (214, 197, 161), (191, 64, 42),
        (139, 44, 28), (196, 154, 61), (107, 100, 89), (74, 124, 66),
        (163, 42, 42),
    }
    for relative, (size, margins) in FURNITURE.items():
        metrics = image_metrics(UI / relative, size)
        image = Image.open(UI / relative).convert("RGBA")
        used = {pixel[:3] for pixel in pixels(image) if pixel[3]}
        metrics["palette_exact"] = used <= palette
        metrics["nine_slice_margins"] = margins
        metrics["accepted"] = metrics["accepted"] and metrics["palette_exact"]
        results["furniture"][relative] = metrics
    for relative, size in FIXED_CONTROLS.items():
        metrics = image_metrics(UI / relative, size)
        image = Image.open(UI / relative).convert("RGBA")
        used = {pixel[:3] for pixel in pixels(image) if pixel[3]}
        metrics["palette_exact"] = used <= palette
        metrics["accepted"] = metrics["accepted"] and metrics["palette_exact"]
        results["fixed_controls"][relative] = metrics

    comparisons = {
        "character_selected_vs_unselected": ("character/card_selected_9slice.png", "character/card_unselected_9slice.png"),
        "area_selected_vs_unselected": ("area/card_selected_9slice.png", "area/card_unselected_9slice.png"),
        "area_locked_vs_unselected": ("area/card_locked_9slice.png", "area/card_unselected_9slice.png"),
        "tier_rare_vs_common": ("level_up/card_rare_9slice.png", "level_up/card_common_9slice.png"),
        "tier_legendary_vs_common": ("level_up/card_legendary_9slice.png", "level_up/card_common_9slice.png"),
        "claimed_vs_unclaimed": ("meta/claimed.png", "meta/unclaimed.png"),
        "toggle_on_vs_off": ("settings/toggle_on.png", "settings/toggle_off.png"),
        "victory_vs_defeat": ("results/victory_banner.png", "results/defeat_banner.png"),
    }
    for name, pair in comparisons.items():
        rgba, alpha = changed(*pair)
        results["state_differences"][name] = {
            "changed_pixels": rgba,
            "alpha_changed_pixels": alpha,
            "accepted": rgba >= 32,
        }

    results["contrast_ratios"] = {
        "ink_on_paper": contrast((26, 22, 19), (237, 224, 196)),
        "ink_on_paper_dark": contrast((26, 22, 19), (214, 197, 161)),
        "light_text_on_ink": contrast((245, 238, 222), (26, 22, 19)),
        "light_text_on_vermilion_dark": contrast((245, 238, 222), (139, 44, 28)),
    }
    results["accepted"] = (
        all(item["accepted"] for group in (
            results["icons"], results["illustrations"], results["furniture"],
            results["fixed_controls"],
        )
            for item in group.values())
        and all(item["accepted"] for item in results["state_differences"].values())
        and all(value >= 4.5 for value in results["contrast_ratios"].values())
    )
    output = UI / "raw/journey/ui_metrics.json"
    output.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(
        f"icons={len(results['icons'])} illustrations={len(results['illustrations'])} "
        f"furniture={len(results['furniture'])} fixed_controls={len(results['fixed_controls'])}"
    )
    print(f"contrast={results['contrast_ratios']}")
    print(f"state_differences={results['state_differences']}")
    print(f"accepted={results['accepted']}")
    print(output.relative_to(ROOT))


if __name__ == "__main__":
    main()
