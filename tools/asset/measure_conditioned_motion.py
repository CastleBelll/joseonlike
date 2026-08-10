"""Measure whether a reference-conditioned motion edit stayed in the legs.

The south Taoist authority occupies a 37x46 window (1,702 pixels).  This uses
the same exact RGBA ImageChops comparison as ``measure_motion_sheet.py`` while
also reporting whether changes escaped the lower-body edit region.
"""
from pathlib import Path
import argparse
import json

from PIL import Image, ImageChops


def flattened(image):
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def canonical(image, authority_bbox):
    image = image.convert("RGBA")
    if image.size != (92, 92):
        canvas = Image.new("RGBA", (92, 92), (0, 0, 0, 0))
        canvas.alpha_composite(image, ((92 - image.width) // 2, (92 - image.height) // 2))
        image = canvas
    return image.crop(authority_bbox)


def region_metrics(frame, authority, box):
    frame_region = frame.crop(box)
    authority_region = authority.crop(box)
    difference = ImageChops.difference(frame_region, authority_region)
    changed = sum(pixel != (0, 0, 0, 0) for pixel in flattened(difference))
    alpha = sum(
        first[3] != second[3]
        for first, second in zip(flattened(frame_region), flattened(authority_region))
    )
    return {
        "box": list(box),
        "pixels": frame_region.width * frame_region.height,
        "changed_pixels": changed,
        "alpha_changed_pixels": alpha,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("authority", type=Path)
    parser.add_argument("frames", nargs="+", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    authority_full = Image.open(args.authority).convert("RGBA")
    authority_bbox = authority_full.getbbox()
    if authority_bbox is None:
        raise SystemExit("authority is empty")
    width = authority_bbox[2] - authority_bbox[0]
    height = authority_bbox[3] - authority_bbox[1]
    if (width, height) != (37, 46):
        raise SystemExit(f"authority bounds changed: {authority_bbox}")
    authority = authority_full.crop(authority_bbox)

    # South-authority regions.  The editable feet/lowest legs occupy the last
    # 15 rows. The hat is the first 17 rows; the staff is the leftmost 11
    # columns. Alpha changes in either stable feature mean its geometry moved.
    regions = {
        "upper_body": (0, 0, width, 31),
        "lower_body": (0, 31, width, height),
        "hat": (0, 0, width, 17),
        "staff": (0, 0, 11, height),
    }
    denominator = width * height
    results = {
        "method": "exact RGBA ImageChops difference on the authority's canonical window",
        "authority_bbox": list(authority_bbox),
        "comparison_pixels": denominator,
        "separate_render_baseline": {
            "changed_pixels": 449,
            "changed_percent": round(449 * 100 / denominator, 2),
        },
        "acceptance": {
            "lower_body_share_min_percent": 70.0,
            "hat_alpha_changed_max": 0,
            "staff_alpha_changed_max": 0,
        },
        "frames": {},
    }

    for frame_path in args.frames:
        frame = canonical(Image.open(frame_path), authority_bbox)
        frame_regions = {
            name: region_metrics(frame, authority, box)
            for name, box in regions.items()
        }
        total = region_metrics(frame, authority, (0, 0, width, height))
        lower_share = (
            frame_regions["lower_body"]["changed_pixels"] * 100 / total["changed_pixels"]
            if total["changed_pixels"] else 100.0
        )
        accepted = (
            lower_share >= 70.0
            and frame_regions["hat"]["alpha_changed_pixels"] == 0
            and frame_regions["staff"]["alpha_changed_pixels"] == 0
        )
        results["frames"][frame_path.stem] = {
            "changed_pixels": total["changed_pixels"],
            "changed_percent": round(total["changed_pixels"] * 100 / denominator, 2),
            "alpha_changed_pixels": total["alpha_changed_pixels"],
            "opaque_colours": len({pixel[:3] for pixel in flattened(frame) if pixel[3]}),
            "lower_body_share_percent": round(lower_share, 2),
            "regions": frame_regions,
            "accepted": accepted,
        }

    rendered = json.dumps(results, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")


if __name__ == "__main__":
    main()
