"""Build the registered layered title set from individually generated raws."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
TITLE = ROOT / "asset/title"
RAW = TITLE / "raw"
LAYERS = TITLE / "layers"
CANVAS = (540, 960)
GROUND_8429_RGBA_SHA256 = "62a5f0e401e68717250dbda7d9a3c0feb5797c0170d502ee591ba1cc8ab2266a"
GROUND_8429_UPPER_SHA256 = "f60254c9be51dd0710e4716ff699002495b0cf3b9620898f05b3654e0bd59503"
GROUND_8429_ALPHA_SHA256 = "6b6979ba2c40ed389ffc766bf19a4b637444de033bd3c0eb39ab26047b10dfba"


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
    """Compress local contrast in the controls band without erasing detail.

    The 8429e00 ground is reproduced by transparent_layer("ground"). Preserve
    it byte-for-byte above y556, then pull each opaque pixel toward the mean of
    the opaque pixels in its fixed 8x8 neighbourhood. Alpha never changes, so
    stones, grass, path edges, and the full-height bamboo framing keep their
    exact positions while their local value contrast is reduced linearly.
    """
    ground = transparent_layer("ground")
    if hashlib.sha256(ground.tobytes()).hexdigest() != GROUND_8429_RGBA_SHA256:
        raise RuntimeError("ground raw no longer reproduces the 8429e00 reference")
    pixels = ground.load()
    palette = sorted({pixel[:3] for pixel in flattened(ground) if pixel[3]})
    factor = 0.40
    tone_gain = 0.55
    tone_offset = 16
    band_top = 556
    block_size = 8
    for top in range(band_top, CANVAS[1], block_size):
        for left in range(0, CANVAS[0], block_size):
            coordinates = [
                (x, y)
                for y in range(top, min(top + block_size, CANVAS[1]))
                for x in range(left, min(left + block_size, CANVAS[0]))
                if pixels[x, y][3] == 255
            ]
            if not coordinates:
                continue
            means = tuple(
                sum(pixels[x, y][channel] for x, y in coordinates) / len(coordinates)
                for channel in range(3)
            )
            for x, y in coordinates:
                r, g, b, alpha = pixels[x, y]
                pixels[x, y] = (
                    round(means[0] + factor * (r - means[0])),
                    round(means[1] + factor * (g - means[1])),
                    round(means[2] + factor * (b - means[2])),
                    alpha,
                )

    # The local operation preserves block means, so separately fit the action
    # band's overall value range to the UI contrast target. Snap back to the
    # original 48-colour ground palette; this keeps the area pixel-authored and
    # leaves every byte above band_top untouched.
    nearest_cache = {}
    for y in range(band_top, CANVAS[1]):
        for x in range(CANVAS[0]):
            r, g, b, alpha = pixels[x, y]
            if alpha == 0:
                continue
            mapped = (
                round(r * tone_gain + tone_offset),
                round(g * tone_gain + tone_offset),
                round(b * tone_gain + tone_offset),
            )
            if mapped not in nearest_cache:
                nearest_cache[mapped] = min(
                    palette,
                    key=lambda colour: sum((colour[channel] - mapped[channel]) ** 2 for channel in range(3)),
                )
            pixels[x, y] = (*nearest_cache[mapped], alpha)
    if hashlib.sha256(ground.crop((0, 0, 540, band_top)).tobytes()).hexdigest() != GROUND_8429_UPPER_SHA256:
        raise RuntimeError("ground processing changed pixels above the action band")
    if hashlib.sha256(ground.getchannel("A").tobytes()).hexdigest() != GROUND_8429_ALPHA_SHA256:
        raise RuntimeError("ground processing changed the 8429e00 alpha silhouette")
    return ground


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
