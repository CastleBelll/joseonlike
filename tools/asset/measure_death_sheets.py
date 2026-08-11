"""Measure death animations by irreversible silhouette collapse, not identity lock."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[2]
SEQUENCES = {
    "Taoist": ROOT / "asset/character/Taoist/Death",
    "Warrior": ROOT / "asset/character/Warrior/Death",
    "Archer": ROOT / "asset/character/Archer/Death",
    "forest_goblin": ROOT / "asset/monster/forest_goblin/death",
    "forest_spirit": ROOT / "asset/monster/forest_spirit/death",
    "bamboo_brute": ROOT / "asset/monster/bamboo_brute/death",
    "bamboo_spirit_lord": ROOT / "asset/monster/bamboo_spirit_lord/death",
}


def pixels(image: Image.Image):
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def frame_metrics(path: Path) -> dict:
    frame = Image.open(path).convert("RGBA")
    bbox = frame.getbbox()
    if bbox is None:
        return {"empty": True, "opaque_pixels": 0, "bbox": [0, 0], "centroid_y": None}
    opaque_points = [
        (x, y)
        for y in range(frame.height)
        for x in range(frame.width)
        if frame.getpixel((x, y))[3]
    ]
    return {
        "empty": False,
        "opaque_pixels": len(opaque_points),
        "bbox": [bbox[2] - bbox[0], bbox[3] - bbox[1]],
        "centroid_y": round(sum(y for _, y in opaque_points) / len(opaque_points), 2),
    }


def changed(first: Path, second: Path) -> int:
    a = Image.open(first).convert("RGBA")
    b = Image.open(second).convert("RGBA")
    return sum(pixel != (0, 0, 0, 0) for pixel in pixels(ImageChops.difference(a, b)))


def main() -> None:
    results = {}
    for name, folder in SEQUENCES.items():
        paths = [folder / f"{index}.png" for index in range(4)]
        missing = [str(path.relative_to(ROOT)) for path in paths if not path.exists()]
        if missing:
            raise SystemExit(f"{name}: missing {', '.join(missing)}")
        frames = [frame_metrics(path) for path in paths]
        transitions = [changed(paths[index], paths[index + 1]) for index in range(3)]
        terminal_delta = changed(paths[0], paths[3])
        first_height = frames[0]["bbox"][1]
        final_height = frames[3]["bbox"][1]
        first_area = frames[0]["opaque_pixels"]
        final_area = frames[3]["opaque_pixels"]
        height_ratio = final_height / first_height if first_height else 1.0
        area_ratio = final_area / first_area if first_area else 1.0
        accepted = (
            not any(frame["empty"] for frame in frames)
            and all(value >= 64 for value in transitions)
            and terminal_delta >= 128
            and (height_ratio <= 0.82 or area_ratio <= 0.65)
        )
        results[name] = {
            "frames": {str(index): frame for index, frame in enumerate(frames)},
            "transitions_changed_pixels": transitions,
            "terminal_changed_pixels": terminal_delta,
            "final_to_first_height_ratio": round(height_ratio, 3),
            "final_to_first_area_ratio": round(area_ratio, 3),
            "accepted": accepted,
        }
        print(
            f"{name}: accepted={accepted} changed={transitions} terminal={terminal_delta} "
            f"height_ratio={height_ratio:.3f} area_ratio={area_ratio:.3f}"
        )
    output = ROOT / "asset/character/raw/death_metrics.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {output.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
