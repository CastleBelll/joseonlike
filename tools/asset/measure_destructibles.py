"""Measure destructible sets as irreversible collapse, not identity motion."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
DESTRUCTIBLE = ROOT / "asset/destructible"
RAW = DESTRUCTIBLE / "raw"
IDS = (
    "onggi_jar", "straw_bundle", "bamboo_basket", "rice_sack",
    "supply_crate", "handcart", "offering_vessels", "roof_tile_stack",
)
DISPLAY = ("intact", "break/0", "break/1", "break/2", "break/3", "debris")


def pixels(image: Image.Image):
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def frame_metrics(path: Path) -> dict:
    frame = Image.open(path).convert("RGBA")
    bbox = frame.getbbox()
    if bbox is None:
        return {"empty": True, "opaque_pixels": 0, "bbox": [0, 0], "hard_alpha": True, "cue_pixels": 0}
    opaque = [pixel for pixel in pixels(frame) if pixel[3]]
    points = {
        (x, y)
        for y in range(frame.height)
        for x in range(frame.width)
        if frame.getpixel((x, y))[3]
    }
    components = 0
    while points:
        components += 1
        pending = [points.pop()]
        while pending:
            x, y = pending.pop()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in points:
                    points.remove(neighbor)
                    pending.append(neighbor)
    cue_pixels = sum(
        pixel[0] >= 90 and pixel[0] >= pixel[1] * 1.35 and pixel[0] >= pixel[2] * 1.20
        for pixel in opaque
    )
    return {
        "empty": False,
        "opaque_pixels": len(opaque),
        "bbox": [bbox[2] - bbox[0], bbox[3] - bbox[1]],
        "hard_alpha": {pixel[3] for pixel in pixels(frame)} <= {0, 255},
        "cue_pixels": cue_pixels,
        "opaque_components": components,
    }


def changed(first: Path, second: Path) -> int:
    a = Image.open(first).convert("RGBA")
    b = Image.open(second).convert("RGBA")
    return sum(pixel != (0, 0, 0, 0) for pixel in pixels(ImageChops.difference(a, b)))


def contact_sheet() -> Path:
    cell, label, left = 96, 18, 128
    sheet = Image.new("RGBA", (left + cell * len(DISPLAY), (cell + label) * len(IDS)), (45, 47, 54, 255))
    draw = ImageDraw.Draw(sheet)
    for row, object_id in enumerate(IDS):
        y = row * (cell + label)
        draw.text((4, y + 4), object_id, fill=(245, 238, 222, 255))
        for column, relative in enumerate(DISPLAY):
            path = DESTRUCTIBLE / object_id / f"{relative}.png"
            sprite = Image.open(path).convert("RGBA").resize((cell, cell), Image.Resampling.NEAREST)
            sheet.alpha_composite(sprite, (left + column * cell, y))
            draw.text((left + column * cell + 3, y + cell), relative, fill=(245, 238, 222, 255))
    output = RAW / "destructible_contact_sheet.png"
    sheet.save(output)
    return output


def main() -> None:
    results = {"sets": {}, "accepted": True}
    for object_id in IDS:
        root = DESTRUCTIBLE / object_id
        paths = [root / "intact.png"] + [root / "break" / f"{index}.png" for index in range(4)]
        if any(not path.is_file() for path in paths):
            raise SystemExit(f"{object_id}: incomplete set")
        frames = [frame_metrics(path) for path in paths]
        transitions = [changed(paths[index], paths[index + 1]) for index in range(4)]
        terminal = changed(paths[0], paths[4])
        first_height = frames[0]["bbox"][1]
        final_height = frames[4]["bbox"][1]
        first_area = frames[0]["opaque_pixels"]
        final_area = frames[4]["opaque_pixels"]
        height_ratio = final_height / first_height if first_height else 1.0
        area_ratio = final_area / first_area if first_area else 1.0
        debris_equal = (root / "break/3.png").read_bytes() == (root / "debris.png").read_bytes()
        accepted = (
            not any(frame["empty"] for frame in frames)
            and all(frame["hard_alpha"] for frame in frames)
            and 18 <= first_height <= 43
            and frames[0]["cue_pixels"] >= 1
            and all(value >= 24 for value in transitions)
            and terminal >= 64
            and (
                height_ratio <= 0.82
                or area_ratio <= 0.72
                or frames[4]["opaque_components"] >= frames[0]["opaque_components"] + 1
            )
            and debris_equal
        )
        results["sets"][object_id] = {
            "frames": {name: frame for name, frame in zip(("intact", "break_0", "break_1", "break_2", "break_3"), frames)},
            "transitions_changed_pixels": transitions,
            "terminal_changed_pixels": terminal,
            "final_to_first_height_ratio": round(height_ratio, 3),
            "final_to_first_area_ratio": round(area_ratio, 3),
            "debris_equals_break_3": debris_equal,
            "accepted": accepted,
        }
        results["accepted"] = results["accepted"] and accepted
        print(
            f"{object_id}: accepted={accepted} height={first_height} cue={frames[0]['cue_pixels']} "
            f"changed={transitions} terminal={terminal} height_ratio={height_ratio:.3f} area_ratio={area_ratio:.3f}"
        )
    results["contact_sheet"] = str(contact_sheet().relative_to(ROOT)).replace("\\", "/")
    output = RAW / "destructible_metrics.json"
    output.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {output.relative_to(ROOT)}: accepted={results['accepted']}")
    if not results["accepted"]:
        raise SystemExit("one or more destructible sets failed the progression/scale/cue gate")


if __name__ == "__main__":
    main()
