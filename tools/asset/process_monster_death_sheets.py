"""Slice, pixelize, and scale-normalize the folklore monster death sets."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PYTHON = sys.executable
PALETTE = ROOT / "asset/character/Taoist/Idle/rotations"
HEIGHTS = {
    "gwimyeon_dokkaebi": 54, "blue_dokkaebi": 50, "gumiho_scout": 48,
    "seonbi_wraith": 52, "haetae_guardian": 58, "dokkaebi_king": 76,
    "cheonyeo_gwisin": 52, "dalgyal_gwisin": 44, "jeoseung_saja": 58,
    "tomb_jangseung": 58, "imugi_whelp": 52, "ancient_imugi": 76,
    "wonhon": 50, "dokkaebi_fire": 44, "shadow_dokkaebi": 52,
    "fox_spirit": 48, "bulgasari": 58, "gumiho": 76,
}
TOP_ROW_LAYOUTS = {"dokkaebi_king", "jeoseung_saja", "ancient_imugi"}
CENTRAL_STRIP_INSETS = {
    "blue_dokkaebi": (8, 196, 196),
    "tomb_jangseung": (8, 142, 148),
    "wonhon": (12, 160, 174),
    "dokkaebi_fire": (8, 216, 241),
}


def run(*args: object) -> None:
    subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True)


def main() -> None:
    for monster_id, height in HEIGHTS.items():
        root = ROOT / f"asset/monster/{monster_id}"
        source_name = (
            "death_sheet_2026_retry_higgsfield.png"
            if monster_id == "bulgasari"
            else "death_sheet_2026_higgsfield.png"
        )
        source = root / "raw" / source_name
        raw_cells = root / "raw" / "death_2026_cells"
        output = root / "death"
        output.mkdir(parents=True, exist_ok=True)

        if monster_id == "gumiho":
            cols, rows, names = 2, 2, ("0", "1", "2", "3")
        elif monster_id in TOP_ROW_LAYOUTS:
            cols, rows, names = 4, 2, ("0", "1", "2", "3")
        else:
            cols, rows, names = 4, 1, ("0", "1", "2", "3")
        if monster_id in CENTRAL_STRIP_INSETS:
            inset_x, inset_top, inset_bottom = CENTRAL_STRIP_INSETS[monster_id]
            slice_options = (
                f"--inset-x={inset_x}", f"--inset-top={inset_top}",
                f"--inset-bottom={inset_bottom}",
            )
        else:
            slice_options = ("--inset=4",)
        run(
            PYTHON, "tools/asset/slice_sheet.py", source, raw_cells, cols, rows,
            *slice_options, *names,
        )
        for frame in range(4):
            run(
                PYTHON, "tools/asset/pixelize.py",
                raw_cells / f"{frame}.png", output / f"{frame}.png",
                height, PALETTE, 92, "--checker-background",
            )
        run(PYTHON, "tools/asset/normalize_death_sequence.py", raw_cells, output)
        if monster_id == "ancient_imugi":
            for frame in range(4):
                run(
                    PYTHON, "tools/asset/clean_tiny_components.py",
                    output / f"{frame}.png", "--min-pixels", 3,
                )


if __name__ == "__main__":
    main()
