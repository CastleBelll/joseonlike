"""Measure generated directional motion against each direction's own idle.

All comparisons use exact RGBA ``ImageChops.difference`` on the full 92x92
canvas.  Walk acceptance additionally requires at least 70% of changed pixels
to be in the lower third of the authority and no head-silhouette movement.
Attack acceptance permits weapon/arm movement but still requires the head
silhouette to remain fixed and no more than 15% of changed pixels in the head.
"""
from pathlib import Path
import argparse
import json
import statistics

from PIL import Image, ImageChops


DIRECTIONS = (
    "south", "south-east", "east", "north-east",
    "north", "north-west", "west", "south-west",
)


def flattened(image):
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def changed(first, second, box=(0, 0, 92, 92)):
    first_region = first.crop(box)
    second_region = second.crop(box)
    difference = ImageChops.difference(first_region, second_region)
    rgba = sum(pixel != (0, 0, 0, 0) for pixel in flattened(difference))
    alpha = sum(
        a[3] != b[3]
        for a, b in zip(flattened(first_region), flattened(second_region))
    )
    return rgba, alpha


def load_canvas(path):
    image = Image.open(path).convert("RGBA")
    if image.size != (92, 92):
        raise SystemExit(f"{path}: expected 92x92, got {image.size}")
    return image


def frame_path(frame_dir, motion, direction, index):
    direct = frame_dir / f"{direction}_{index}.png"
    prefixed = frame_dir / f"{motion}_{direction}_{index}.png"
    if direct.exists():
        return direct
    if prefixed.exists():
        return prefixed
    raise SystemExit(f"missing frame: {direct} or {prefixed}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("idle_dir", type=Path)
    parser.add_argument("frame_dir", type=Path)
    parser.add_argument("motion", choices=("walk", "attack"))
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    results = {
        "method": "exact RGBA ImageChops difference on full 92x92 canvases",
        "motion": args.motion,
        "canvas_pixels": 92 * 92,
        "directions": {},
    }
    all_changed = []
    all_lower_share = []
    accepted_frames = 0

    for direction in DIRECTIONS:
        idle = load_canvas(args.idle_dir / f"{direction}.png")
        bbox = idle.getbbox()
        if bbox is None:
            raise SystemExit(f"{direction}: idle is empty")
        height = bbox[3] - bbox[1]
        head_bottom = bbox[1] + round(height * 0.40)
        lower_top = bbox[1] + round(height * 0.67)
        head_box = (0, bbox[1], 92, head_bottom)
        lower_box = (0, lower_top, 92, 92)
        upper_box = (0, 0, 92, lower_top)
        direction_result = {"idle_bbox": list(bbox), "frames": {}}
        frames = []

        for index in (0, 1):
            path = frame_path(args.frame_dir, args.motion, direction, index)
            frame = load_canvas(path)
            frames.append(frame)
            total, alpha_total = changed(frame, idle)
            lower, lower_alpha = changed(frame, idle, lower_box)
            upper, upper_alpha = changed(frame, idle, upper_box)
            head, head_alpha = changed(frame, idle, head_box)
            lower_share = lower * 100 / total if total else 100.0
            head_share = head * 100 / total if total else 0.0
            accepted = (
                lower_share >= 70.0 and head_alpha == 0
                if args.motion == "walk"
                else head_share <= 15.0 and head_alpha == 0
            )
            accepted_frames += int(accepted)
            all_changed.append(total)
            all_lower_share.append(lower_share)
            direction_result["frames"][str(index)] = {
                "path": path.as_posix(),
                "changed_pixels": total,
                "changed_percent_canvas": round(total * 100 / (92 * 92), 2),
                "alpha_changed_pixels": alpha_total,
                "lower_changed_pixels": lower,
                "lower_alpha_changed_pixels": lower_alpha,
                "lower_share_percent": round(lower_share, 2),
                "upper_changed_pixels": upper,
                "upper_alpha_changed_pixels": upper_alpha,
                "head_changed_pixels": head,
                "head_alpha_changed_pixels": head_alpha,
                "head_share_percent": round(head_share, 2),
                "opaque_colours": len({pixel[:3] for pixel in flattened(frame) if pixel[3]}),
                "accepted": accepted,
            }

        pair_changed, pair_alpha = changed(frames[0], frames[1])
        direction_result["frame_pair"] = {
            "changed_pixels": pair_changed,
            "alpha_changed_pixels": pair_alpha,
        }
        results["directions"][direction] = direction_result

    results["summary"] = {
        "frames": len(all_changed),
        "accepted_frames": accepted_frames,
        "sheet_accepted": accepted_frames == len(all_changed),
        "changed_pixels_mean": round(statistics.mean(all_changed), 2),
        "changed_pixels_min": min(all_changed),
        "changed_pixels_max": max(all_changed),
        "lower_share_percent_mean": round(statistics.mean(all_lower_share), 2),
    }
    rendered = json.dumps(results, indent=2) + "\n"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")


if __name__ == "__main__":
    main()
