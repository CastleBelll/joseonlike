"""Slice and pixelize the four representative generated monster-walk trials."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HEIGHTS = {
    "blue_dokkaebi": 50,
    "gumiho_scout": 48,
    "wonhon": 50,
    "ancient_imugi": 76,
}


def run(*args: object) -> None:
    subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True)


def main() -> None:
    for monster_id, height in HEIGHTS.items():
        trial = ROOT / f"asset/monster/{monster_id}/raw/walk_trial"
        cells = trial / "cells"
        cut = trial / "cut"
        cut.mkdir(parents=True, exist_ok=True)
        run(
            sys.executable, "tools/asset/slice_sheet.py", trial / "sheet_higgsfield.png",
            cells, 2, 1, "--inset=4", "0", "1",
        )
        for frame in range(2):
            run(
                sys.executable, "tools/asset/pixelize.py", cells / f"{frame}.png",
                cut / f"{frame}.png", height,
                ROOT / "asset/character/Taoist/Idle/rotations", 92,
            )


if __name__ == "__main__":
    main()
