from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "new_asset" / "taoist.png"
WALK_SOURCE = ROOT / "new_asset" / "taoist_walk.png"
OUT = ROOT / "asset" / "characters" / "taoist"
SCALE = 16
GROUND = (28, 36, 22, 255)
IDLE_PALETTE = (
    (0, 0, 0), (0, 0, 3), (0, 2, 1), (2, 0, 1), (7, 3, 4), (25, 27, 53),
    (30, 84, 103), (36, 43, 82), (51, 0, 18), (61, 66, 117), (64, 46, 69),
    (79, 71, 116), (88, 131, 108), (106, 6, 47), (149, 94, 68), (169, 5, 47),
    (183, 20, 53), (189, 100, 78), (211, 11, 69), (219, 146, 80),
    (232, 185, 109), (252, 233, 180), (253, 202, 151),
)
PORTRAIT_PALETTE = (
    (0, 0, 0), (0, 0, 3), (1, 2, 1), (3, 0, 1), (4, 11, 6), (16, 103, 81),
    (21, 2, 11), (37, 42, 69), (59, 67, 115), (70, 15, 51), (75, 109, 101),
    (77, 68, 113), (89, 59, 49), (91, 0, 18), (94, 2, 56), (124, 5, 62),
    (135, 5, 70), (159, 5, 62), (160, 119, 76), (163, 27, 55), (181, 9, 56),
    (183, 96, 86), (202, 166, 116), (210, 10, 68), (210, 12, 69), (217, 133, 81),
    (233, 165, 99), (237, 208, 155), (251, 151, 100), (254, 200, 153),
    (254, 202, 156), (254, 215, 145),
)


def remove_green(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for r, g, b, _ in rgba.get_flattened_data():
        keyed = g >= 170 and g - r >= 72 and g - b >= 72
        pixels.append((r, g, b, 0 if keyed else 255))
    rgba.putdata(pixels)
    return rgba


def trim(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("crop contains no foreground")
    return image.crop(bbox)


def snap_palette(image: Image.Image, palette: tuple[tuple[int, int, int], ...]) -> Image.Image:
    alpha = image.getchannel("A").point(lambda value: 255 if value else 0)
    rgba = image.convert("RGBA")
    snapped = []
    for r, g, b, value in rgba.get_flattened_data():
        if not value:
            snapped.append((0, 0, 0, 0))
            continue
        nearest = min(palette, key=lambda color: (r - color[0]) ** 2 + (g - color[1]) ** 2 + (b - color[2]) ** 2)
        snapped.append((*nearest, 255))
    rgba.putdata(snapped)
    rgba.putalpha(alpha)
    return rgba


def keep_largest_component(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    width, height = image.size
    seen: set[tuple[int, int]] = set()
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if (x, y) in seen or alpha.getpixel((x, y)) == 0:
                continue
            stack = [(x, y)]
            seen.add((x, y))
            component: list[tuple[int, int]] = []
            while stack:
                px, py = stack.pop()
                component.append((px, py))
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in seen and alpha.getpixel((nx, ny)):
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            components.append(component)
    if not components:
        raise ValueError("crop contains no foreground component")
    keep = set(max(components, key=len))
    result = image.copy()
    result.putalpha(Image.new("L", image.size, 0))
    out_alpha = result.getchannel("A")
    for x, y in keep:
        out_alpha.putpixel((x, y), 255)
    result.putalpha(out_alpha)
    return result


def logical_from_crop(source: Image.Image, box: tuple[int, int, int, int], size: tuple[int, int], max_subject: tuple[int, int], palette: tuple[tuple[int, int, int], ...], *, largest_only: bool = False) -> Image.Image:
    crop = source.crop(box)
    if largest_only:
        crop = keep_largest_component(crop)
    subject = trim(crop)
    max_w, max_h = max_subject
    factor = min(max_w / subject.width, max_h / subject.height)
    resized = subject.resize((max(1, round(subject.width * factor)), max(1, round(subject.height * factor))), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", size)
    x = (size[0] - resized.width) // 2
    y = size[1] - resized.height - 1
    canvas.alpha_composite(resized, (x, y))
    return snap_palette(canvas, palette)


def rebalance_two_head(image: Image.Image) -> Image.Image:
    """Compress the source body while retaining its authored head and palette."""
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("sprite contains no foreground")
    _, chin, total_height, _ = measure_head_ratio(image)
    if total_height != 29:
        raise ValueError(f"expected a 29-pixel source figure, got {total_height}")

    split = chin + 1
    subject_width = bbox[2] - bbox[0]
    head = image.crop((bbox[0], bbox[1], bbox[2], split))
    body = image.crop((bbox[0], split, bbox[2], bbox[3]))
    candidates: list[tuple[float, Image.Image]] = []
    for head_height in range(head.height + 1, min(21, total_height - 7)):
        body_height = total_height - head_height
        candidate = Image.new("RGBA", image.size)
        candidate.alpha_composite(
            head.resize((subject_width, head_height), Image.Resampling.NEAREST),
            (bbox[0], bbox[1]),
        )
        candidate.alpha_composite(
            body.resize((subject_width, body_height), Image.Resampling.NEAREST),
            (bbox[0], bbox[1] + head_height),
        )
        _, _, candidate_total, ratio = measure_head_ratio(candidate)
        if candidate_total == 29 and 0.42 <= ratio <= 0.55:
            candidates.append((abs(ratio - 0.48), candidate))
    if not candidates:
        raise ValueError("could not rebalance source to the 0.42-0.55 head ratio")
    return min(candidates, key=lambda item: item[0])[1]


def assemble_walk(source_frames: list[Image.Image]) -> list[Image.Image]:
    """Lock frame-one's upper body and retain the authored leg poses below it."""
    if len(source_frames) != 4:
        raise ValueError("walk assembly requires four source frames")
    base = source_frames[0]
    cut_row = 23
    result: list[Image.Image] = []
    for index, authored in enumerate(source_frames):
        bob = 1 if index in (1, 3) else 0
        locked = Image.new("RGBA", base.size)
        locked.alpha_composite(base, (0, -bob))
        posed = Image.new("RGBA", authored.size)
        posed.alpha_composite(authored, (0, -bob))
        lower_start = cut_row - bob
        lower_box = (0, lower_start, 32, 32)
        locked.paste(posed.crop(lower_box), lower_box)
        result.append(locked)
    return result


def upscale(image: Image.Image) -> Image.Image:
    return image.resize((image.width * SCALE, image.height * SCALE), Image.Resampling.NEAREST)


def measure_head_ratio(idle: Image.Image) -> tuple[int, int, int, float]:
    """Measure approved hair-top through chin against full opaque height."""
    bbox = idle.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("idle sprite contains no foreground")
    hair_rows: list[int] = []
    for y in range(bbox[1], bbox[3]):
        for x in range(10, 25):
            r, g, b, alpha = idle.getpixel((x, y))
            if alpha and r >= 80 and g <= 25 and 30 <= b <= 100:
                hair_rows.append(y)
    if not hair_rows:
        raise ValueError("could not locate hair-top row")
    hair_top = min(hair_rows)
    skin_counts: dict[int, int] = {}
    for y in range(hair_top + 7, min(bbox[3], hair_top + 17)):
        count = 0
        for x in range(10, 25):
            r, g, b, alpha = idle.getpixel((x, y))
            if alpha and r >= 190 and g >= 100 and 70 <= b <= 180:
                count += 1
        skin_counts[y] = count
    chin_candidates = [y for y, count in skin_counts.items() if count >= 3]
    if not chin_candidates:
        raise ValueError("could not locate chin row")
    chin = max(chin_candidates)
    total_height = bbox[3] - bbox[1]
    ratio = (chin - hair_top + 1) / total_height
    return hair_top, chin, total_height, ratio


def save_outputs(idle: Image.Image, portrait: Image.Image, walk_logical: list[Image.Image], ratio: float) -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    idle_export = upscale(idle)
    portrait_export = upscale(portrait)
    walk_export = Image.new("RGBA", (128 * SCALE, 32 * SCALE))
    for index, frame in enumerate(walk_logical):
        walk_export.alpha_composite(upscale(frame), (index * 32 * SCALE, 0))

    idle_export.save(OUT / "idle.png", optimize=True)
    walk_export.save(OUT / "walk.png", optimize=True)
    portrait_export.save(OUT / "portrait.png", optimize=True)

    gif_frames = [upscale(frame) for frame in walk_logical]
    gif_frames[0].save(
        OUT / "preview.gif",
        save_all=True,
        append_images=gif_frames[1:],
        # GIF stores centiseconds, so alternate 120/130 ms for an exact
        # 125 ms average frame interval (8 fps over the four-frame loop).
        duration=[120, 130, 120, 130],
        loop=0,
        disposal=2,
        transparency=0,
    )

    sheet = Image.new("RGBA", (2560, 1024), GROUND)
    draw = ImageDraw.Draw(sheet)
    draw.text((48, 36), "IDLE", fill=(245, 224, 174, 255))
    sheet.alpha_composite(idle_export, (32, 96))
    draw.text((608, 36), "WALK 1-4", fill=(245, 224, 174, 255))
    for index, label in enumerate(("CONTACT", "PASS + BOB", "CONTACT", "PASS + BOB")):
        draw.text((592 + index * 384, 128), label, fill=(173, 209, 160, 255))
    walk_display = walk_export.resize((1536, 384), Image.Resampling.NEAREST)
    sheet.alpha_composite(walk_display, (576, 160))
    draw.text((2160, 36), "PORTRAIT", fill=(245, 224, 174, 255))
    portrait_display = portrait_export.resize((384, 384), Image.Resampling.NEAREST)
    sheet.alpha_composite(portrait_display, (2144, 128))
    draw.text((48, 896), f"Logical 32x32 / 128x32 / 48x48  |  head ratio {ratio:.6f}  |  16x nearest export  |  #1c2416 ground check", fill=(173, 209, 160, 255))
    sheet.convert("RGB").save(OUT / "contact-sheet.png", optimize=True)


def main() -> None:
    source = remove_green(Image.open(SOURCE))
    idle = logical_from_crop(source, (0, 200, 930, 1770), (32, 32), (30, 29), IDLE_PALETTE, largest_only=True)
    idle = rebalance_two_head(idle)
    portrait = logical_from_crop(source, (930, 200, 2048, 1650), (48, 48), (46, 46), PORTRAIT_PALETTE, largest_only=True)

    walk_source = remove_green(Image.open(WALK_SOURCE))
    authored_walk = [
        logical_from_crop(
            walk_source,
            (index * 384, 0, (index + 1) * 384, 440),
            (32, 32),
            (30, 29),
            IDLE_PALETTE,
            largest_only=True,
        )
        for index in range(4)
    ]
    walk_logical = assemble_walk([rebalance_two_head(frame) for frame in authored_walk])
    hair_top, chin, total_height, ratio = measure_head_ratio(idle)
    if not 0.42 <= ratio <= 0.55:
        raise ValueError(f"head ratio {ratio:.6f} is outside the 0.42-0.55 contract")
    save_outputs(idle, portrait, walk_logical, ratio)
    print(f"head ratio: ({chin} - {hair_top} + 1) / {total_height} = {ratio:.6f}")


if __name__ == "__main__":
    main()
