"""Slice and pixelize canonical travel, melee, and paired impact art."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PALETTE = ROOT / "asset/character/Taoist/Idle/rotations"
STATIC = (
    ("spinning_talisman", "travel", 14, 32),
    ("arrow", "travel", 10, 32),
    ("fireball", "travel", 14, 32),
    ("throwing_knife", "travel", 10, 32),
    ("spirit_bolt", "travel", 12, 32),
    ("wide_sword_arc", "melee", 44, 64),
    ("dual_blade_cross", "melee", 48, 64),
    ("heavy_overhead", "melee", 48, 64),
    ("spear_thrust", "melee", 20, 64),
)


def run(*args: object) -> None:
    subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True)


def main() -> None:
    raw = ROOT / "asset/weapon/raw"
    cells = raw / "combat_travel_melee_cells"
    run(
        sys.executable, "tools/asset/slice_sheet.py",
        raw / "combat_travel_melee_sheet_higgsfield.png", cells, 3, 3,
        "--inset=12", *(item[0] for item in STATIC),
    )
    for name, category, height, canvas in STATIC:
        output = ROOT / f"asset/weapon/{category}/{name}.png"
        output.parent.mkdir(parents=True, exist_ok=True)
        run(
            sys.executable, "tools/asset/pixelize.py", cells / f"{name}.png",
            output, height, PALETTE, canvas,
        )

    impacts = {
        "fireball_impact": (24, 230, 230),
        "spirit_bolt_impact": (8, 180, 180),
    }
    for effect, (inset_x, inset_top, inset_bottom) in impacts.items():
        source = ROOT / f"asset/effect/raw/{effect}_sheet_higgsfield.png"
        raw_cells = ROOT / f"asset/effect/raw/{effect}_cells"
        output = ROOT / f"asset/effect/{effect}"
        output.mkdir(parents=True, exist_ok=True)
        run(
            sys.executable, "tools/asset/slice_sheet.py", source, raw_cells, 4, 1,
            f"--inset-x={inset_x}", f"--inset-top={inset_top}",
            f"--inset-bottom={inset_bottom}", "0", "1", "2", "3",
        )
        for frame in range(4):
            run(
                sys.executable, "tools/asset/pixelize.py", raw_cells / f"{frame}.png",
                output / f"{frame}.png", 56, PALETTE, 64,
                "--checker-background", "--fixed-cell",
            )


if __name__ == "__main__":
    main()
