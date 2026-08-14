from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "new_asset" / "taoist.png"
WALK_SOURCE = ROOT / "new_asset" / "taoist_walk.png"
OUT = ROOT / "asset" / "characters" / "taoist"
PORTRAIT = OUT / "portrait.png"
LOGICAL_SIZE = (40, 40)
FIGURE_HEIGHT = 38
PALETTE_SIZE = 32
SCALE = 16
GROUND = (28, 36, 22, 255)


def remove_green(image: Image.Image) -> Image.Image:
    """Hard-key chroma green at source resolution and despill retained edges."""
    rgba = image.convert("RGBA")
    pixels = []
    for r, g, b, _ in rgba.get_flattened_data():
        keyed = g >= 135 and g - r >= 45 and g - b >= 45
        if keyed:
            pixels.append((0, 0, 0, 0))
            continue
        # Retain blue-green costume hues, but suppress one-channel green halos.
        ceiling = max(r, b) + 12
        pixels.append((r, min(g, ceiling) if g > ceiling else g, b, 255))
    rgba.putdata(pixels)
    return rgba


def trim(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("crop contains no foreground")
    return image.crop(bbox)


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
    out_alpha = Image.new("L", image.size, 0)
    for x, y in keep:
        out_alpha.putpixel((x, y), 255)
    result.putalpha(out_alpha)
    return result


def box_resize_rgba(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """BOX-reduce premultiplied RGB and alpha, then restore binary alpha."""
    rgba = image.convert("RGBA")
    red, green, blue, alpha = rgba.split()
    # Chroma-keyed transparent pixels have RGB zero, so each RGB channel is
    # already premultiplied by the source's binary alpha.
    red = red.resize(size, Image.Resampling.BOX)
    green = green.resize(size, Image.Resampling.BOX)
    blue = blue.resize(size, Image.Resampling.BOX)
    alpha = alpha.resize(size, Image.Resampling.BOX)

    result = Image.new("RGBA", size)
    pixels = []
    for r, g, b, a in zip(
        red.get_flattened_data(),
        green.get_flattened_data(),
        blue.get_flattened_data(),
        alpha.get_flattened_data(),
    ):
        if a < 128:
            pixels.append((0, 0, 0, 0))
            continue
        # Un-premultiply after filtering so transparent surroundings cannot
        # darken or green-tint the silhouette edge.
        pixels.append(
            (
                min(255, round(r * 255 / a)),
                min(255, round(g * 255 / a)),
                min(255, round(b * 255 / a)),
                255,
            )
        )
    result.putdata(pixels)
    return result


def logical_from_crop(
    source: Image.Image,
    box: tuple[int, int, int, int],
    *,
    largest_only: bool = False,
) -> Image.Image:
    crop = source.crop(box)
    if largest_only:
        crop = keep_largest_component(crop)
    subject = rebalance_two_head(trim(crop))
    factor = min((LOGICAL_SIZE[0] - 2) / subject.width, FIGURE_HEIGHT / subject.height)
    size = (
        max(1, round(subject.width * factor)),
        max(1, round(subject.height * factor)),
    )
    resized = trim(box_resize_rgba(subject, size))
    canvas = Image.new("RGBA", LOGICAL_SIZE)
    x = (LOGICAL_SIZE[0] - resized.width) // 2
    y = LOGICAL_SIZE[1] - resized.height
    canvas.alpha_composite(resized, (x, y))
    return canvas


def palette_from_images(images: list[Image.Image], colors: int) -> tuple[tuple[int, int, int], ...]:
    samples = [pixel[:3] for image in images for pixel in image.get_flattened_data() if pixel[3]]
    if not samples:
        raise ValueError("cannot build a palette without opaque pixels")
    strip = Image.new("RGB", (len(samples), 1))
    strip.putdata(samples)
    quantized = strip.quantize(
        colors=colors - 2,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    palette = list(dict.fromkeys(quantized.get_flattened_data()))

    # Eye whites occupy very few logical pixels, so a frequency-only median
    # cut can erase them. Reserve two source-derived light-neutral entries;
    # this preserves facial readability without inventing or recoloring hues.
    light_neutrals = sorted(
        {
            color
            for color in samples
            if min(color) >= 150 and max(color) - min(color) <= 65
        },
        key=sum,
        reverse=True,
    )
    anchors: list[tuple[int, int, int]] = []
    for color in light_neutrals:
        if all(sum((a - b) ** 2 for a, b in zip(color, anchor)) >= 400 for anchor in anchors):
            anchors.append(color)
        if len(anchors) == 2:
            break
    palette.extend(color for color in anchors if color not in palette)
    palette = palette[:colors]
    palette = tuple(palette)
    if not 24 <= len(palette) <= 32:
        raise ValueError(f"expected a 24-32 color palette, got {len(palette)}")
    return palette


def apply_palette(image: Image.Image, palette: tuple[tuple[int, int, int], ...]) -> Image.Image:
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    pixels = []
    for r, g, b, alpha in image.get_flattened_data():
        if not alpha:
            pixels.append((0, 0, 0, 0))
            continue
        source = (r, g, b)
        if source not in cache:
            cache[source] = min(
                palette,
                key=lambda color: sum((channel - target) ** 2 for channel, target in zip(source, color)),
            )
        pixels.append((*cache[source], 255))
    result = Image.new("RGBA", image.size)
    result.putdata(pixels)
    return result


def measure_head_ratio(idle: Image.Image) -> tuple[int, int, int, float]:
    """Measure hair-top through chin against full opaque figure height."""
    bbox = idle.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("idle sprite contains no foreground")
    total_height = bbox[3] - bbox[1]
    hair_rows: list[int] = []
    face_left = bbox[0] + round((bbox[2] - bbox[0]) * 0.35)
    face_right = bbox[2]
    for y in range(bbox[1], bbox[3]):
        for x in range(face_left, face_right):
            r, g, b, alpha = idle.getpixel((x, y))
            if alpha and r >= 70 and r >= g * 1.30 and b >= g * 1.15 and 25 <= b <= 155:
                hair_rows.append(y)
    if not hair_rows:
        raise ValueError("could not locate hair-top row")
    hair_top = min(hair_rows)
    skin_counts: dict[int, int] = {}
    skin_threshold = max(4, round((face_right - face_left) * 0.08))
    for y in range(hair_top + round(total_height * 0.15), min(bbox[3], hair_top + round(total_height * 0.50))):
        count = 0
        for x in range(face_left, face_right):
            r, g, b, alpha = idle.getpixel((x, y))
            if alpha and r >= 155 and g >= 65 and b >= 45 and r >= g * 1.08:
                count += 1
        skin_counts[y] = count
    chin_candidates = [y for y, count in skin_counts.items() if count >= skin_threshold]
    if not chin_candidates:
        raise ValueError("could not locate chin row")
    chin = max(chin_candidates)
    return hair_top, chin, total_height, (chin - hair_top + 1) / total_height


def rebalance_two_head(image: Image.Image) -> Image.Image:
    """Reallocate the full-resolution head/body before the final BOX reduction."""
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("sprite contains no foreground")
    hair_top, chin, total_height, ratio = measure_head_ratio(image)
    if 0.45 <= ratio <= 0.52:
        return image

    split = chin + 1
    subject_width = bbox[2] - bbox[0]
    head = image.crop((bbox[0], bbox[1], bbox[2], split))
    body = image.crop((bbox[0], split, bbox[2], bbox[3]))
    measured_head = chin - hair_top + 1
    desired_head = round(total_height * 0.48)
    head_height = round(head.height * desired_head / measured_head)
    head_height = min(head_height, total_height - max(7, round(total_height * 0.20)))
    body_height = total_height - head_height
    result = Image.new("RGBA", image.size)
    result.alpha_composite(box_resize_rgba(head, (subject_width, head_height)), (bbox[0], bbox[1]))
    result.alpha_composite(
        box_resize_rgba(body, (subject_width, body_height)),
        (bbox[0], bbox[1] + head_height),
    )
    return result


def assemble_walk(source_frames: list[Image.Image]) -> list[Image.Image]:
    """Lock frame one's upper body and retain authored lower-body poses."""
    if len(source_frames) != 4:
        raise ValueError("walk assembly requires four source frames")
    base = source_frames[0]
    lower_start = round(LOGICAL_SIZE[1] * 0.72)
    lower_box = (0, lower_start, LOGICAL_SIZE[0], LOGICAL_SIZE[1])
    result = []
    for authored in source_frames:
        frame = base.copy()
        frame.paste(authored.crop(lower_box), lower_box)
        result.append(frame)
    return result


def assert_no_green_fringe(images: list[Image.Image]) -> None:
    for image in images:
        for r, g, b, alpha in image.get_flattened_data():
            if alpha and g >= 110 and g - r >= 40 and g - b >= 40:
                raise ValueError(f"green fringe survived as opaque RGB {(r, g, b)}")


def upscale(image: Image.Image) -> Image.Image:
    return image.resize((image.width * SCALE, image.height * SCALE), Image.Resampling.NEAREST)


def save_outputs(idle: Image.Image, walk_logical: list[Image.Image], ratio: float) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if not PORTRAIT.exists():
        raise FileNotFoundError("approved portrait.png is missing")
    portrait_export = Image.open(PORTRAIT).convert("RGBA")

    idle_export = upscale(idle)
    walk_export = Image.new("RGBA", (LOGICAL_SIZE[0] * 4 * SCALE, LOGICAL_SIZE[1] * SCALE))
    for index, frame in enumerate(walk_logical):
        walk_export.alpha_composite(upscale(frame), (index * LOGICAL_SIZE[0] * SCALE, 0))

    idle_export.save(OUT / "idle.png", optimize=True)
    walk_export.save(OUT / "walk.png", optimize=True)

    gif_frames = [upscale(frame) for frame in walk_logical]
    gif_frames[0].save(
        OUT / "preview.gif",
        save_all=True,
        append_images=gif_frames[1:],
        duration=[120, 130, 120, 130],
        loop=0,
        disposal=2,
        transparency=0,
    )

    sheet = Image.new("RGBA", (2880, 1024), GROUND)
    draw = ImageDraw.Draw(sheet)
    draw.text((48, 36), "IDLE", fill=(245, 224, 174, 255))
    sheet.alpha_composite(idle_export, (32, 96))
    draw.text((704, 36), "WALK 1-4", fill=(245, 224, 174, 255))
    for index, label in enumerate(("CONTACT", "PASS", "CONTACT", "PASS")):
        draw.text((704 + index * 320, 128), label, fill=(173, 209, 160, 255))
    walk_display = walk_export.resize((1280, 320), Image.Resampling.NEAREST)
    sheet.alpha_composite(walk_display, (704, 160))
    draw.text((2112, 36), "PORTRAIT (UNCHANGED)", fill=(245, 224, 174, 255))
    portrait_display = portrait_export.resize((384, 384), Image.Resampling.NEAREST)
    sheet.alpha_composite(portrait_display, (2112, 128))
    draw.text(
        (48, 896),
        f"Logical {LOGICAL_SIZE[0]}x{LOGICAL_SIZE[1]} / figure {FIGURE_HEIGHT}px | BOX downscale | {PALETTE_SIZE}-color source palette | head ratio {ratio:.6f} | 16x NEAREST export",
        fill=(173, 209, 160, 255),
    )
    sheet.convert("RGB").save(OUT / "contact-sheet.png", optimize=True)


def main() -> None:
    source = remove_green(Image.open(SOURCE))
    idle = logical_from_crop(source, (0, 200, 930, 1770), largest_only=True)

    walk_source = remove_green(Image.open(WALK_SOURCE))
    authored_walk = [
        logical_from_crop(
            walk_source,
            (index * 384, 0, (index + 1) * 384, 440),
            largest_only=True,
        )
        for index in range(4)
    ]

    palette = palette_from_images([idle, *authored_walk], PALETTE_SIZE)
    idle = apply_palette(idle, palette)
    authored_walk = [apply_palette(frame, palette) for frame in authored_walk]
    walk_logical = assemble_walk(authored_walk)
    assert_no_green_fringe([idle, *walk_logical])

    hair_top, chin, total_height, ratio = measure_head_ratio(idle)
    if total_height != FIGURE_HEIGHT:
        raise ValueError(f"figure height {total_height} does not match {FIGURE_HEIGHT}")
    if not 0.42 <= ratio <= 0.55:
        raise ValueError(f"head ratio {ratio:.6f} is outside the 0.42-0.55 contract")
    if any(frame.getchannel("A").getbbox()[3] != LOGICAL_SIZE[1] for frame in walk_logical):
        raise ValueError("every walk frame must place its feet on the bottom row")

    save_outputs(idle, walk_logical, ratio)
    print(f"palette colors: {len(palette)}")
    print(f"head ratio: ({chin} - {hair_top} + 1) / {total_height} = {ratio:.6f}")


if __name__ == "__main__":
    main()
