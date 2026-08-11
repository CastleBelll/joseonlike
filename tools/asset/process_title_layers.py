"""Build the registered layered title set from individually generated raws."""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
TITLE = ROOT / "asset/title"
RAW = TITLE / "raw"
LAYERS = TITLE / "layers"
CANVAS = (540, 960)


def flattened(image: Image.Image):
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def key_magenta(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, _ = pixels[x, y]
            chroma = (
                r > 70
                and b > 70
                and g < min(r, b) * 0.75
                and abs(r - b) < 100
            )
            pixels[x, y] = (0, 0, 0, 0) if chroma else (r, g, b, 255)
    return image


def quantise(image: Image.Image, colours: int = 48) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    rgb = Image.new("RGB", image.size, (0, 0, 0))
    rgb.paste(image.convert("RGB"), mask=alpha)
    rgb = rgb.quantize(
        colors=colours,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def fit_raw(name: str, size: tuple[int, int] = CANVAS) -> Image.Image:
    source = Image.open(RAW / f"{name}_higgsfield.png").convert("RGB")
    return ImageOps.fit(source, size, method=Image.Resampling.BOX)


def opaque_sky() -> Image.Image:
    sky = fit_raw("sky")
    sky = sky.quantize(
        colors=48,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    sky.putalpha(255)
    return sky


def transparent_layer(name: str) -> Image.Image:
    return quantise(key_magenta(fit_raw(name)))


def ground_layer() -> Image.Image:
    """Move path interest above the controls and quiet the action band.

    The targeted image edit supplies a cleaner inhabited-earth source but still
    placed its main path around y530. Shift that authored interest upward, then
    use its low ground texture at deliberately compressed contrast below the
    middle band so five button labels never compete with stones or black holes.
    """
    edited_path = RAW / "ground_action_band_edit_openai.png"
    if not edited_path.is_file():
        raise FileNotFoundError(f"missing targeted ground edit: {edited_path}")
    fitted = ImageOps.fit(
        Image.open(edited_path).convert("RGB"),
        CANVAS,
        method=Image.Resampling.BOX,
    )
    keyed = key_magenta(fitted)

    moved = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    moved.alpha_composite(keyed, (0, -300))

    base = (38, 42, 48)
    fitted_pixels = fitted.load()
    keyed_alpha = keyed.getchannel("A").load()
    moved_pixels = moved.load()
    quiet_start = 320
    quiet_end = 520
    for y in range(quiet_start, CANVAS[1]):
        quiet_strength = min(1.0, (y - quiet_start) / (quiet_end - quiet_start))
        for x in range(CANVAS[0]):
            texture_y = min(CANVAS[1] - 1, y + 220)
            if keyed_alpha[x, texture_y]:
                sr, sg, sb = fitted_pixels[x, texture_y]
            else:
                sr, sg, sb = base
            # Keep subtle earth texture while compressing the controls' value
            # range. Cross-fade into it to avoid a horizontal processing seam.
            qr = base[0] * 0.70 + sr * 0.30
            qg = base[1] * 0.70 + sg * 0.30
            qb = base[2] * 0.70 + sb * 0.30
            mr, mg, mb, ma = moved_pixels[x, y]
            if ma == 0:
                mr, mg, mb = qr, qg, qb
            r = round(mr * (1.0 - quiet_strength) + qr * quiet_strength)
            g = round(mg * (1.0 - quiet_strength) + qg * quiet_strength)
            b = round(mb * (1.0 - quiet_strength) + qb * quiet_strength)
            moved_pixels[x, y] = (r, g, b, 255)

    return quantise(moved)


def moon_glow() -> Image.Image:
    """Extract the valid generated upper ring and pre-position it over the moon."""
    raw = Image.open(RAW / "moon_glow_higgsfield.png").convert("RGBA")
    center = (520, 280)
    radius = 250
    crop = Image.new("RGBA", (radius * 2, radius * 2), (0, 0, 0, 0))
    source = raw.load()
    target = crop.load()
    for dy in range(-radius, radius):
        for dx in range(-radius, radius):
            distance2 = dx * dx + dy * dy
            if distance2 > radius * radius or distance2 < 75 * 75:
                continue
            sx, sy = center[0] + dx, center[1] + dy
            if not (0 <= sx < raw.width and 0 <= sy < raw.height):
                continue
            r, g, b, _ = source[sx, sy]
            chroma = r > 70 and b > 70 and g < min(r, b) * 0.75 and abs(r - b) < 100
            if not chroma:
                target[dx + radius, dy + radius] = (r, g, b, 255)
    crop = crop.resize((112, 112), Image.Resampling.BOX)
    layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    moon_center = (336, 68)
    layer.alpha_composite(crop, (moon_center[0] - 56, moon_center[1] - 56))
    return quantise(layer, 24)


def mote() -> Image.Image:
    """The model redrew the scene; isolate the requested central generated mote."""
    raw = Image.open(RAW / "mote_higgsfield.png").convert("RGB")
    crop = raw.crop((496, 485, 528, 544))
    pixels = crop.load()
    for y in range(crop.height):
        for x in range(crop.width):
            r, g, b = pixels[x, y]
            if max(r, g, b) < 100:
                pixels[x, y] = (0, 0, 0)
    crop = crop.convert("RGBA")
    alpha = crop.convert("RGB").convert("L").point(lambda value: 255 if value >= 70 else 0)
    crop.putalpha(alpha)
    crop.thumbnail((8, 8), Image.Resampling.BOX)
    out = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    out.alpha_composite(crop, ((8 - crop.width) // 2, (8 - crop.height) // 2))
    return quantise(out, 8)


def fog_strip() -> Image.Image:
    base = quantise(key_magenta(fit_raw("fog_strip", (540, 320))), 32)
    # base + mirrored base makes both the outer seam and center join exact.
    out = Image.new("RGBA", (1080, 320), (0, 0, 0, 0))
    out.alpha_composite(base, (0, 0))
    out.alpha_composite(ImageOps.mirror(base), (540, 0))
    return out


def luminance(image: Image.Image, box: tuple[int, int, int, int]) -> float:
    rgb = image.convert("RGB").crop(box)
    values = [0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b in flattened(rgb)]
    return sum(values) / len(values)


def action_band_metrics(image: Image.Image) -> dict[str, float]:
    """Match the coordinator's x32..508/y556..936 Rec.709 8px metric."""
    rgb = image.convert("RGB")
    values = [
        [
            0.2126 * rgb.getpixel((x, y))[0]
            + 0.7152 * rgb.getpixel((x, y))[1]
            + 0.0722 * rgb.getpixel((x, y))[2]
            for x in range(32, 508)
        ]
        for y in range(556, 936)
    ]
    flattened_values = [value for row in values for value in row]
    block_stds = []
    for by in range(0, 376, 8):
        for bx in range(0, 472, 8):
            block = [values[by + dy][bx + dx] for dy in range(8) for dx in range(8)]
            mean = sum(block) / len(block)
            block_stds.append(math.sqrt(sum((value - mean) ** 2 for value in block) / len(block)))
    return {
        "mean_luminance": sum(flattened_values) / len(flattened_values),
        "local_8px_stddev": sum(block_stds) / len(block_stds),
        "min_luminance": min(flattened_values),
        "max_luminance": max(flattened_values),
    }


def main() -> None:
    LAYERS.mkdir(parents=True, exist_ok=True)
    built = {
        "sky": opaque_sky(),
        "moon_glow": moon_glow(),
        "palace": transparent_layer("palace"),
        "bamboo_far": transparent_layer("bamboo_far"),
        "bamboo_near": transparent_layer("bamboo_near"),
        "ground": ground_layer(),
    }

    # Distant bamboo must form a real value step behind the near framing.
    far = built["bamboo_far"]
    far_rgb = ImageEnhance.Brightness(far.convert("RGB")).enhance(1.22)
    far_rgb.putalpha(far.getchannel("A"))
    # Remove the generator's bottom undergrowth; that content belongs to ground.
    far_alpha = far_rgb.getchannel("A")
    draw = ImageDraw.Draw(far_alpha)
    draw.rectangle((0, 790, CANVAS[0], CANVAS[1]), fill=0)
    far_rgb.putalpha(far_alpha)
    built["bamboo_far"] = quantise(far_rgb)

    for name, image in built.items():
        image.save(LAYERS / f"{name}.png")

    fog_strip().save(TITLE / "fog_strip.png")
    mote().save(TITLE / "mote.png")

    composite = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    for name in ("sky", "moon_glow", "palace", "bamboo_far", "bamboo_near", "ground"):
        composite.alpha_composite(built[name])
    composite.convert("RGB").save(RAW / "title_layers_composite.png")

    old = Image.open(ROOT / "asset/stage/backdrops/main_menu.png").convert("RGB")
    review = Image.new("RGB", (1080, 960), (18, 18, 22))
    review.paste(old, (0, 0))
    review.paste(composite.convert("RGB"), (540, 0))
    review.save(RAW / "title_layers_comparison.png")

    metrics = {
        "layer_order": ["sky", "moon_glow", "palace", "bamboo_far", "bamboo_near", "ground"],
        "canvas": list(CANVAS),
        "old_lower_two_thirds_luminance": luminance(old, (0, 320, 540, 960)),
        "new_lower_two_thirds_luminance": luminance(composite, (0, 320, 540, 960)),
        "action_band": action_band_metrics(composite),
        "layers": {},
    }
    for name, image in built.items():
        alpha = image.getchannel("A")
        metrics["layers"][name] = {
            "size": list(image.size),
            "opaque_pixels": sum(value == 255 for value in flattened(alpha)),
            "transparent_pixels": sum(value == 0 for value in flattened(alpha)),
            "colours": len({pixel[:3] for pixel in flattened(image) if pixel[3]}),
        }
    fog = Image.open(TITLE / "fog_strip.png").convert("RGBA")
    metrics["fog_horizontal_seam_changed_pixels"] = sum(
        fog.getpixel((0, y)) != fog.getpixel((fog.width - 1, y))
        for y in range(fog.height)
    )
    metrics["mote_opaque_pixels"] = sum(
        pixel[3] == 255 for pixel in flattened(Image.open(TITLE / "mote.png").convert("RGBA"))
    )
    (RAW / "title_layers_metrics.json").write_text(
        json.dumps(metrics, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
