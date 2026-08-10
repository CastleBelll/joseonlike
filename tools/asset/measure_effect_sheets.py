"""Measure small animation effects for mobile readability and progression.

The character-motion metrics intentionally reject silhouette drift. Effects need a
different gate: each frame needs a non-trivial, compact silhouette, a bright core,
and a visible change from its neighbours. This script records those properties for
the four-frame effect sheets in ``asset/effect``.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[2]
EFFECT_ROOT = ROOT / "asset" / "effect"


def pixels(image: Image.Image):
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def frame_metrics(path: Path) -> dict:
    frame = Image.open(path).convert("RGBA")
    opaque = [pixel for pixel in pixels(frame) if pixel[3]]
    bbox = frame.getbbox()
    bright = [
        pixel for pixel in opaque
        if max(pixel[:3]) >= 230
        and (pixel[0] * 299 + pixel[1] * 587 + pixel[2] * 114) / 1000 >= 180
    ]
    bbox_size = [0, 0] if bbox is None else [bbox[2] - bbox[0], bbox[3] - bbox[1]]
    coverage = len(opaque) / (frame.width * frame.height)
    silhouette_readable = 16 <= len(opaque) <= frame.width * frame.height * 0.8
    return {
        "canvas": [frame.width, frame.height],
        "bbox": bbox_size,
        "opaque_pixels": len(opaque),
        "coverage_percent": round(coverage * 100, 2),
        "bright_core_pixels": len(bright),
        "silhouette_readable": silhouette_readable,
        "bright_core_present": len(bright) >= 4,
        "readable": silhouette_readable and len(bright) >= 4,
    }


def changed_pixels(first: Path, second: Path) -> int:
    a = Image.open(first).convert("RGBA")
    b = Image.open(second).convert("RGBA")
    return sum(pixel != (0, 0, 0, 0) for pixel in pixels(ImageChops.difference(a, b)))


def main() -> None:
    if not EFFECT_ROOT.exists():
        raise SystemExit("asset/effect does not exist")
    all_metrics = {}
    for effect_dir in sorted(path for path in EFFECT_ROOT.iterdir() if path.is_dir() and path.name != "raw"):
        frame_paths = [effect_dir / f"{index}.png" for index in range(4)]
        missing = [str(path.relative_to(ROOT)) for path in frame_paths if not path.exists()]
        if missing:
            raise SystemExit(f"{effect_dir.name}: missing {', '.join(missing)}")
        frames = {path.stem: frame_metrics(path) for path in frame_paths}
        transitions = {
            f"{index}->{index + 1}": changed_pixels(frame_paths[index], frame_paths[index + 1])
            for index in range(3)
        }
        # The fourth frame is deliberately dissipation; requiring its bright
        # core to survive would reject a correct fade-out. Frames 0-2 carry the
        # active hit/readability signal, while all four still need silhouettes.
        accepted = (
            all(item["silhouette_readable"] for item in frames.values())
            and all(frames[str(index)]["bright_core_present"] for index in range(3))
            and all(value >= 16 for value in transitions.values())
        )
        all_metrics[effect_dir.name] = {
            "frames": frames,
            "transitions_changed_pixels": transitions,
            "accepted": accepted,
        }
        print(
            f"{effect_dir.name}: accepted={accepted} "
            f"bright={[item['bright_core_pixels'] for item in frames.values()]} "
            f"changed={list(transitions.values())}"
        )
    output = EFFECT_ROOT / "raw" / "effect_metrics.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(all_metrics, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {output.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
