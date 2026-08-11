"""Slice, pixelize, and assemble the eight destructible-object sets.

Each Higgsfield row is intact followed by four irreversible break frames. The
whole raw cell is scaled into one 64px canvas so later frames retain the sheet's
collapse scale instead of being cropped and enlarged back to intact height.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
DESTRUCTIBLE = ROOT / "asset/destructible"
RAW = DESTRUCTIBLE / "raw"
PALETTE = ROOT / "asset/character/Taoist/Idle/rotations"
PYTHON = sys.executable

SHEETS = {
    "bamboo_forest": {
        "source": RAW / "bamboo_forest_destructibles_sheet_higgsfield.png",
        "objects": ("onggi_jar", "straw_bundle", "bamboo_basket", "rice_sack"),
    },
    "abandoned_temple": {
        "source": RAW / "abandoned_temple_destructibles_sheet_higgsfield.png",
        "objects": ("supply_crate", "handcart", "offering_vessels", "roof_tile_stack"),
    },
}

DROP_GUIDANCE = {
    "onggi_jar": {
        "stages": ["bamboo_forest", "abandoned_temple"],
        "primary_drop": "health_gourd",
        "secondary_drop": "gold_coin",
        "rare_drop": None,
        "reason": "an onggi plausibly stores restorative drink, herbs, or a few household coins",
    },
    "straw_bundle": {
        "stages": ["bamboo_forest"],
        "primary_drop": "gold_coin",
        "secondary_drop": "health_gourd",
        "rare_drop": None,
        "reason": "farm bundles conceal small coin purses or gathered medicinal herbs, not treasure chests",
    },
    "bamboo_basket": {
        "stages": ["bamboo_forest"],
        "primary_drop": "gold_coin",
        "secondary_drop": "health_gourd",
        "rare_drop": None,
        "reason": "a foraging basket plausibly carries provisions and small valuables",
    },
    "rice_sack": {
        "stages": ["bamboo_forest", "abandoned_temple"],
        "primary_drop": "health_gourd",
        "secondary_drop": "gold_coin",
        "rare_drop": None,
        "reason": "food stores support recovery; a low coin chance represents payment hidden in the binding",
    },
    "supply_crate": {
        "stages": ["bamboo_forest", "abandoned_temple"],
        "primary_drop": "gold_pile",
        "secondary_drop": "health_gourd",
        "rare_drop": "chest_common",
        "reason": "a rope-bound supply crate is the most credible container for supplies and an occasional chest",
    },
    "handcart": {
        "stages": ["bamboo_forest", "abandoned_temple"],
        "primary_drop": "gold_pile",
        "secondary_drop": "magnet",
        "rare_drop": "chest_common",
        "reason": "a working cart carries bulk goods; its iron fittings make the magnet pickup visually plausible",
    },
    "offering_vessels": {
        "stages": ["abandoned_temple"],
        "primary_drop": "gold_coin",
        "secondary_drop": "magnet",
        "rare_drop": None,
        "reason": "temple offerings plausibly contain coins, while a spiritual attraction pickup fits ritual vessels",
    },
    "roof_tile_stack": {
        "stages": ["abandoned_temple"],
        "primary_drop": "gold_coin",
        "secondary_drop": None,
        "rare_drop": None,
        "reason": "only a small hidden coin reward is credible under loose roof tiles; premium loot would feel arbitrary",
    },
}

TARGET_HEIGHTS = {
    "onggi_jar": 40,
    "straw_bundle": 34,
    "bamboo_basket": 36,
    "rice_sack": 38,
    "supply_crate": 40,
    "handcart": 37,
    "offering_vessels": 39,
    "roof_tile_stack": 40,
}


def normalize_scale(folder: Path, target_height: int) -> None:
    """Scale the complete fixed-cell sequence uniformly from its intact height."""
    paths = [folder / "intact.png"] + [folder / "break" / f"{index}.png" for index in range(4)]
    images = [Image.open(path).convert("RGBA") for path in paths]
    intact_bbox = images[0].getbbox()
    if intact_bbox is None:
        raise SystemExit(f"{folder}: empty intact frame")
    intact_height = intact_bbox[3] - intact_bbox[1]
    scale = min(1.0, target_height / intact_height)
    if scale == 1.0:
        return
    side = max(1, round(64 * scale))
    offset = ((64 - side) // 2, (64 - side) // 2)
    for path, image in zip(paths, images):
        resized = image.resize((side, side), Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        canvas.alpha_composite(resized, offset)
        canvas.save(path)
    print(f"{folder.relative_to(ROOT)}: normalized intact {intact_height}px -> {target_height}px")


def stamp_breakable_seal(path: Path, anchor: tuple[int, int]) -> None:
    """Add the shared vermilion loot-seal cue when the generated row omitted it."""
    image = Image.open(path).convert("RGBA")
    draw = ImageDraw.Draw(image)
    x, y = anchor
    draw.rectangle((x - 2, y - 3, x + 2, y + 3), fill=(0, 0, 0, 255))
    draw.rectangle((x - 1, y - 2, x + 1, y + 2), fill=(191, 64, 42, 255))
    draw.point((x, y - 2), fill=(196, 154, 61, 255))
    image.save(path)


def run(*args: object) -> None:
    subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True)


def names(objects: tuple[str, ...]) -> tuple[str, ...]:
    result = []
    for object_id in objects:
        result.extend((f"{object_id}_intact", *(f"{object_id}_break_{index}" for index in range(4))))
    return tuple(result)


def main() -> None:
    for stage, spec in SHEETS.items():
        source = spec["source"]
        if not source.is_file():
            raise SystemExit(f"missing raw Higgsfield sheet: {source.relative_to(ROOT)}")
        cell_root = RAW / "cells" / stage
        run(
            PYTHON, "tools/asset/slice_sheet.py", source, cell_root, 5, 4,
            "--inset=4", *names(spec["objects"]),
        )
        for object_id in spec["objects"]:
            output = DESTRUCTIBLE / object_id
            (output / "break").mkdir(parents=True, exist_ok=True)
            inputs = [cell_root / f"{object_id}_intact.png"] + [
                cell_root / f"{object_id}_break_{index}.png" for index in range(4)
            ]
            outputs = [output / "intact.png"] + [
                output / "break" / f"{index}.png" for index in range(4)
            ]
            for source_cell, target in zip(inputs, outputs):
                run(
                    PYTHON, "tools/asset/pixelize.py", source_cell, target,
                    40, PALETTE, 64, "--fixed-cell",
                )
            normalize_scale(output, TARGET_HEIGHTS[object_id])
            if object_id == "handcart":
                stamp_breakable_seal(output / "intact.png", (29, 34))
                stamp_breakable_seal(output / "break/0.png", (29, 34))
            elif object_id == "roof_tile_stack":
                stamp_breakable_seal(output / "intact.png", (32, 39))
                stamp_breakable_seal(output / "break/0.png", (32, 39))
            # The fourth break frame is already the authored resting state. Keep
            # an explicit alias so combat never has to infer debris semantics.
            shutil.copyfile(output / "break/3.png", output / "debris.png")

    manifest = {
        "canvas": [64, 64],
        "frame_order": ["intact", "break/0", "break/1", "break/2", "break/3"],
        "break_semantics": [
            "first impact / loosened binding", "major split or tilt",
            "active irreversible collapse", "resting debris",
        ],
        "debris_rest": "debris.png is byte-identical to break/3.png; leave briefly, then fade or pool-return",
        "breakable_cue": "small vermilion paper loot seal or knotted tassel on every intact object",
        "objects": DROP_GUIDANCE,
    }
    (DESTRUCTIBLE / "destructible_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print("processed 8 destructible sets: intact + 4 break frames + explicit debris aliases")


if __name__ == "__main__":
    main()
