"""Measure pickup readability, progression, and shape-coded grade distinctions."""
from __future__ import annotations

import json
from itertools import combinations
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[2]
DROP_ROOT = ROOT / "asset/drop"
DROP_IDS = (
    "xp_small", "xp_medium", "xp_large", "gold_coin", "gold_pile",
    "health_gourd", "magnet", "chest_common", "chest_rare", "chest_epic",
    "chest_legendary", "chest_mythic",
)
CHESTS = ("chest_common", "chest_rare", "chest_epic", "chest_legendary", "chest_mythic")


def pixels(image: Image.Image):
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def metrics(path: Path, canvas: tuple[int, int], *, allow_violet: bool = False) -> dict:
    image = Image.open(path).convert("RGBA")
    bbox = image.getbbox()
    alphas = {pixel[3] for pixel in pixels(image)}
    opaque = sum(pixel[3] > 0 for pixel in pixels(image))
    bright = sum(pixel[3] > 0 and max(pixel[:3]) >= 185 for pixel in pixels(image))
    chroma = sum(
        pixel[3] and pixel[0] > 120 and pixel[2] > 120 and pixel[1] < 110
        and abs(pixel[0] - pixel[2]) < 85 and min(pixel[0], pixel[2]) - pixel[1] > 55
        for pixel in pixels(image)
    )
    size = [0, 0] if bbox is None else [bbox[2] - bbox[0], bbox[3] - bbox[1]]
    return {
        "canvas": list(image.size), "bbox": size, "opaque_pixels": opaque,
        "bright_pixels": bright, "hard_alpha": alphas <= {0, 255},
        "opaque_chroma_pixels": chroma,
        "accepted": (
            image.size == canvas and bbox is not None and alphas <= {0, 255}
            and (allow_violet or chroma == 0)
        ),
    }


def changed(first: Path, second: Path, *, alpha_only: bool = False) -> int:
    a = Image.open(first).convert("RGBA")
    b = Image.open(second).convert("RGBA")
    if alpha_only:
        return sum(left[3] != right[3] for left, right in zip(pixels(a), pixels(b)))
    return sum(pixel != (0, 0, 0, 0) for pixel in pixels(ImageChops.difference(a, b)))


def main() -> None:
    result = {"sets": {}, "xp_tiers": {}, "grade_shape_pairs": {}}
    for drop_id in DROP_IDS:
        idle_path = DROP_ROOT / drop_id / "idle.png"
        allow_violet = drop_id == "chest_epic"
        idle = metrics(idle_path, (24, 24), allow_violet=allow_violet)
        frames = {}
        paths = []
        for frame in range(4):
            path = DROP_ROOT / drop_id / "collect" / f"{frame}.png"
            paths.append(path)
            frames[str(frame)] = metrics(path, (32, 32), allow_violet=allow_violet)
        transitions = [changed(paths[index], paths[index + 1]) for index in range(3)]
        frame_distinct = len({path.read_bytes() for path in paths}) == 4
        accepted = (
            idle["accepted"] and 8 <= idle["bbox"][1] <= 16 and idle["bright_pixels"] >= 1
            and all(frame["accepted"] for frame in frames.values())
            and frame_distinct and all(value >= 8 for value in transitions)
            and max(frame["bright_pixels"] for frame in frames.values()) >= 2
        )
        result["sets"][drop_id] = {
            "idle": idle, "collect": frames,
            "collect_frame_order": ["anticipation", "expansion", "peak", "dissipation"],
            "transitions_changed_pixels": transitions,
            "accepted": accepted,
        }

    xp = [result["sets"][name]["idle"] for name in ("xp_small", "xp_medium", "xp_large")]
    areas = [item["opaque_pixels"] for item in xp]
    result["xp_tiers"] = {
        "opaque_areas": areas,
        "strictly_increasing": areas[0] < areas[1] < areas[2],
    }
    result["xp_tiers"]["accepted"] = result["xp_tiers"]["strictly_increasing"]

    for first, second in combinations(CHESTS, 2):
        delta = changed(DROP_ROOT / first / "idle.png", DROP_ROOT / second / "idle.png", alpha_only=True)
        result["grade_shape_pairs"][f"{first}->{second}"] = {
            "alpha_changed_pixels": delta,
            "accepted": delta >= 8,
        }
    result["accepted"] = (
        all(record["accepted"] for record in result["sets"].values())
        and result["xp_tiers"]["accepted"]
        and all(record["accepted"] for record in result["grade_shape_pairs"].values())
    )
    output = DROP_ROOT / "raw/drop_metrics.json"
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    for drop_id, record in result["sets"].items():
        print(
            f"{drop_id}: idle_bbox={record['idle']['bbox']} "
            f"changed={record['transitions_changed_pixels']} accepted={record['accepted']}"
        )
    print(f"xp_areas={areas} grade_shape_pairs={len(result['grade_shape_pairs'])} accepted={result['accepted']}")
    print(output.relative_to(ROOT))


if __name__ == "__main__":
    main()
