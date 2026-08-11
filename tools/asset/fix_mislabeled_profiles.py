"""Repair audited west cells whose generated art duplicated the east facing.

This is deliberately narrow: the three paths below were individually inspected
in the 2026-08-11 contact-sheet audit. Mirroring the already-correct east cell
preserves the exact silhouette, palette, canvas, and content dimensions while
making the semantic direction unambiguous.
"""
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
PROFILE_SETS = (
    "asset/monster/gumiho/rotations",
    "asset/monster/imugi_whelp/rotations",
    "asset/monster/tomb_jangseung/rotations",
)


def main() -> None:
    for relative_root in PROFILE_SETS:
        rotation_root = ROOT / relative_root
        source = rotation_root / "east.png"
        target = rotation_root / "west.png"
        with Image.open(source).convert("RGBA") as sprite:
            ImageOps.mirror(sprite).save(target)
        print(f"reflected {source.relative_to(ROOT)} -> {target.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
