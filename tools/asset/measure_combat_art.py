"""Measure mobile readability for canonical travel and melee sprites."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
TRAVEL = ("spinning_talisman", "arrow", "fireball", "throwing_knife", "spirit_bolt")
MELEE = ("wide_sword_arc", "dual_blade_cross", "heavy_overhead", "spear_thrust")


def measure(path: Path, canvas: int) -> dict:
    image = Image.open(path).convert("RGBA")
    bbox = image.getbbox()
    opaque = [pixel for pixel in image.get_flattened_data() if pixel[3]]
    bright = [
        pixel for pixel in opaque
        if max(pixel[:3]) >= 220
        and (pixel[0] * 299 + pixel[1] * 587 + pixel[2] * 114) / 1000 >= 165
    ]
    bbox_size = [0, 0] if bbox is None else [bbox[2] - bbox[0], bbox[3] - bbox[1]]
    hard_alpha = {pixel[3] for pixel in image.get_flattened_data()} <= {0, 255}
    return {
        "canvas": list(image.size),
        "bbox": bbox_size,
        "opaque_pixels": len(opaque),
        "bright_core_pixels": len(bright),
        "hard_alpha": hard_alpha,
        "accepted": (
            image.size == (canvas, canvas)
            and hard_alpha
            and 8 <= len(opaque) <= canvas * canvas * 0.65
            and len(bright) >= 2
        ),
    }


def main() -> None:
    results = {"canonical_orientation": "east", "travel": {}, "melee": {}}
    for name in TRAVEL:
        path = ROOT / f"asset/weapon/travel/{name}.png"
        results["travel"][name] = measure(path, 32)
    for name in MELEE:
        path = ROOT / f"asset/weapon/melee/{name}.png"
        results["melee"][name] = measure(path, 64)
    results["accepted"] = all(
        item["accepted"]
        for group in (results["travel"], results["melee"])
        for item in group.values()
    )
    output = ROOT / "asset/weapon/raw/combat_art_metrics.json"
    output.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    for group_name in ("travel", "melee"):
        for name, item in results[group_name].items():
            print(
                f"{group_name}/{name}: accepted={item['accepted']} "
                f"bbox={item['bbox']} opaque={item['opaque_pixels']} "
                f"bright={item['bright_core_pixels']}"
            )
    print(output.relative_to(ROOT))


if __name__ == "__main__":
    main()
