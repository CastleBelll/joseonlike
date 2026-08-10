"""Measure pixel-level consistency of cut character motion frames.

The canonical comparison is the authority sprite's 37x46 opaque bounds. This
reuses the exact ImageChops pixel-difference method from the separate-render
test, keeping the denominator at 1,702 pixels so results remain comparable.
"""
from pathlib import Path
import argparse
import json

from PIL import Image, ImageChops

FRAME_ORDER = (
    "idle_0", "idle_1",
    "walk_0", "walk_1", "walk_2", "walk_3",
    "attack_0", "attack_1", "attack_2", "attack_3",
)
TRANSITIONS = (
    ("idle_0", "idle_1"),
    ("walk_0", "walk_1"),
    ("walk_1", "walk_2"),
    ("walk_2", "walk_3"),
    ("walk_3", "walk_0"),
    ("attack_0", "attack_1"),
    ("attack_1", "attack_2"),
    ("attack_2", "attack_3"),
)


def flattened(image):
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def changed_pixels(first, second):
    difference = ImageChops.difference(first, second)
    return sum(pixel != (0, 0, 0, 0) for pixel in flattened(difference))


def alpha_changed(first, second):
    return sum(a[3] != b[3] for a, b in zip(flattened(first), flattened(second)))


def canonical(image, authority_bbox):
    """Centre non-92 sprites, then crop the exact authority comparison window."""
    image = image.convert("RGBA")
    if image.size != (92, 92):
        canvas = Image.new("RGBA", (92, 92), (0, 0, 0, 0))
        canvas.alpha_composite(image, ((92 - image.width) // 2, (92 - image.height) // 2))
        image = canvas
    return image.crop(authority_bbox)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("frame_dir", type=Path)
    parser.add_argument("authority", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    authority_full = Image.open(args.authority).convert("RGBA")
    authority_bbox = authority_full.getbbox()
    if authority_bbox is None:
        raise SystemExit("authority is empty")
    if (authority_bbox[2] - authority_bbox[0], authority_bbox[3] - authority_bbox[1]) != (37, 46):
        raise SystemExit(f"authority bounds changed: {authority_bbox}")
    authority = authority_full.crop(authority_bbox)
    frames = {
        name: canonical(Image.open(args.frame_dir / f"{name}.png"), authority_bbox)
        for name in FRAME_ORDER
    }
    denominator = authority.width * authority.height

    results = {
        "authority_bbox": list(authority_bbox),
        "comparison_pixels": denominator,
        "separate_render_baseline": {
            "changed_pixels": 449,
            "changed_percent": round(449 * 100 / denominator, 2),
        },
        "frames_vs_authority": {},
        "consecutive_transitions": {},
    }
    for name, frame in frames.items():
        changed = changed_pixels(frame, authority)
        results["frames_vs_authority"][name] = {
            "changed_pixels": changed,
            "changed_percent": round(changed * 100 / denominator, 2),
            "alpha_changed": alpha_changed(frame, authority),
            "opaque_colours": len({pixel[:3] for pixel in flattened(frame) if pixel[3]}),
        }
    for first_name, second_name in TRANSITIONS:
        first, second = frames[first_name], frames[second_name]
        changed = changed_pixels(first, second)
        results["consecutive_transitions"][f"{first_name}->{second_name}"] = {
            "changed_pixels": changed,
            "changed_percent": round(changed * 100 / denominator, 2),
            "alpha_changed": alpha_changed(first, second),
        }

    rendered = json.dumps(results, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")


if __name__ == "__main__":
    main()
