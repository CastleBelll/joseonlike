"""Bind a manual directional-facing review to the exact reviewed sprite bytes.

Pixel distance cannot reliably identify facing for this set: weapons, tails, and
diffusion drift make several correct east/west pairs less mirror-like than the
known-bad gumiho pair, while several correct front/back groups overlap in raw
distance. This audit therefore records semantic labels only after a human views
the generated contact sheets, hashes every approved cell, and keeps the useful
pixel diagnostics for review. Any changed cell invalidates the approval.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from itertools import combinations, product
from pathlib import Path

from PIL import Image, ImageChops, ImageOps

from build_rotation_contact_sheets import contact_sheet


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "asset/rotation_audit/facing_audit.json"
DIRECTIONS = (
    "south", "south-east", "east", "north-east",
    "north", "north-west", "west", "south-west",
)
EXPECTED_FACING = {
    "south": "front",
    "south-east": "front",
    "east": "profile-east",
    "north-east": "back",
    "north": "back",
    "north-west": "back",
    "west": "profile-west",
    "south-west": "front",
}
CHARACTER_ROOTS = {
    name: f"asset/character/{name}/Idle/rotations"
    for name in ("Taoist", "Warrior", "Archer")
}
MONSTERS = (
    "ancient_imugi", "bamboo_brute", "bamboo_spirit_lord", "blue_dokkaebi",
    "bulgasari", "cheonyeo_gwisin", "dalgyal_gwisin", "dokkaebi_fire",
    "dokkaebi_king", "forest_goblin", "forest_spirit", "fox_spirit", "gumiho",
    "gumiho_scout", "gwimyeon_dokkaebi", "haetae_guardian", "imugi_whelp",
    "jeoseung_saja", "seonbi_wraith", "shadow_dokkaebi", "tomb_jangseung",
    "wonhon",
)
ROTATION_ROOTS = {
    **CHARACTER_ROOTS,
    **{name: f"asset/monster/{name}/rotations" for name in MONSTERS},
}
EXACT_MIRROR_PAIRS = {"gumiho", "imugi_whelp", "tomb_jangseung"}
REGENERATED_SETS = {
    "Warrior", "Archer", "bamboo_brute", "bamboo_spirit_lord",
    "cheonyeo_gwisin", "forest_spirit", "gumiho",
}


def changed_pixels(first: Image.Image, second: Image.Image) -> int:
    difference = ImageChops.difference(first, second)
    return sum(pixel != (0, 0, 0, 0) for pixel in difference.get_flattened_data())


def mean(values: list[int]) -> float:
    return round(sum(values) / len(values), 2)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def diagnostics(images: dict[str, Image.Image]) -> dict[str, float | int]:
    front = ("south", "south-east", "south-west")
    back = ("north-east", "north", "north-west")
    direct = changed_pixels(images["east"], images["west"])
    mirrored = changed_pixels(ImageOps.mirror(images["east"]), images["west"])
    return {
        "front_internal_mean": mean([
            changed_pixels(images[a], images[b]) for a, b in combinations(front, 2)
        ]),
        "back_internal_mean": mean([
            changed_pixels(images[a], images[b]) for a, b in combinations(back, 2)
        ]),
        "front_back_mean": mean([
            changed_pixels(images[a], images[b]) for a, b in product(front, back)
        ]),
        "east_west_direct_changed": direct,
        "east_mirrored_to_west_changed": mirrored,
        "east_west_mirror_ratio": round(mirrored / max(direct, 1), 4),
    }


def build_manifest() -> dict:
    sets = {}
    for name, relative_root in ROTATION_ROOTS.items():
        rotation_root = ROOT / relative_root
        contact_path = ROOT / f"asset/rotation_audit/contact_sheets/{name}.png"
        if not contact_path.is_file():
            raise SystemExit(f"missing contact sheet: {contact_path.relative_to(ROOT)}")
        expected_contact = contact_sheet(name, rotation_root)
        with Image.open(contact_path).convert("RGBA") as current_contact:
            if ImageChops.difference(expected_contact, current_contact).getbbox():
                raise SystemExit(
                    f"stale contact sheet for {name}; rebuild and visually review before --write"
                )
        images = {
            direction: Image.open(rotation_root / f"{direction}.png").convert("RGBA")
            for direction in DIRECTIONS
        }
        sets[name] = {
            "root": relative_root,
            "review": "accepted_manual_contact_sheet",
            "diagonal_handedness_review": "accepted_manual_contact_sheet",
            "contact_sheet": f"asset/rotation_audit/contact_sheets/{name}.png",
            "contact_sheet_sha256": sha256(contact_path),
            "regenerated_in_audit": name in REGENERATED_SETS,
            "exact_east_west_mirror_required": name in EXACT_MIRROR_PAIRS,
            "cells": {
                direction: {
                    "expected_direction": direction,
                    "expected_facing": EXPECTED_FACING[direction],
                    "sha256": sha256(rotation_root / f"{direction}.png"),
                }
                for direction in DIRECTIONS
            },
            "diagnostics": diagnostics(images),
        }
        for sprite in images.values():
            sprite.close()
    return {
        "schema_version": 2,
        "reviewed_at": "2026-08-11",
        "review_method": "manual contact-sheet review, hash-bound per cell",
        "diagonal_handedness_limit": (
            "manual contact-sheet inspection required; mirror-pair metrics cannot detect swapped labels"
        ),
        "direction_order": list(DIRECTIONS),
        "expected_facing": EXPECTED_FACING,
        "sets": sets,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--write",
        action="store_true",
        help="write approval manifest after manually reviewing every contact sheet",
    )
    args = parser.parse_args()
    if not args.write:
        raise SystemExit("Refusing to attest automatically; use --write only after visual review")
    manifest = build_manifest()
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"recorded {len(manifest['sets'])} reviewed sets / {len(manifest['sets']) * len(DIRECTIONS)} cells")
    print(MANIFEST.relative_to(ROOT))


if __name__ == "__main__":
    main()
