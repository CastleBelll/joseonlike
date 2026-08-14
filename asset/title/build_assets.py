from __future__ import annotations

from pathlib import Path
from urllib.request import urlretrieve

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "asset" / "title"
RAW_DIR = ROOT / "tmp" / "title"
FONT_PATH = ROOT / "asset" / "font" / "neodgm.ttf"

LOGICAL_SIZE = (540, 960)
EXPORT_SCALE = 2
LOGO_LOGICAL_SIZE = (420, 200)

SOURCES = {
    "sky_raw.png": "https://d8j0ntlcm91z4.cloudfront.net/user_3HCgsqzSxMMvzqXejoYwa267X3D/hf_20260814_103245_e2d9b1b4-ca8a-4336-9d37-bb1dda16d48e.png",
    "village_raw.png": "https://d8j0ntlcm91z4.cloudfront.net/user_3HCgsqzSxMMvzqXejoYwa267X3D/hf_20260814_103248_7fce8a0b-ca05-43ba-a5de-b98ff3787cae.png",
    "logo_raw.png": "https://d8j0ntlcm91z4.cloudfront.net/user_3HCgsqzSxMMvzqXejoYwa267X3D/hf_20260814_103251_289e14e8-e8f7-46d8-a65d-b9c8850b76b5.png",
}


def ensure_sources() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    for filename, url in SOURCES.items():
        path = RAW_DIR / filename
        if not path.exists():
            print(f"downloading {filename}")
            urlretrieve(url, path)


def cover_crop(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_ratio = size[0] / size[1]
    source_ratio = image.width / image.height
    if source_ratio > target_ratio:
        width = round(image.height * target_ratio)
        left = (image.width - width) // 2
        return image.crop((left, 0, left + width, image.height))
    height = round(image.width / target_ratio)
    top = (image.height - height) // 2
    return image.crop((0, top, image.width, top + height))


def key_magenta(image: Image.Image) -> Image.Image:
    """Remove the generated #ff00ff field before any resize and despill edges."""
    rgba = image.convert("RGBA")
    output: list[tuple[int, int, int, int]] = []
    for red, green, blue, _ in rgba.get_flattened_data():
        key_strength = min(red, blue) - green
        keyed = red >= 175 and blue >= 150 and green <= 135 and key_strength >= 55
        if keyed:
            output.append((0, 0, 0, 0))
            continue
        if red > 115 and blue > 110 and key_strength > 22:
            spill = key_strength - 22
            red = max(green + 18, red - spill)
            blue = max(green + 18, blue - spill)
        output.append((red, green, blue, 255))
    rgba.putdata(output)
    return rgba


def box_resize_rgba(
    image: Image.Image,
    size: tuple[int, int],
    *,
    binary_alpha: bool,
) -> Image.Image:
    """BOX-resample premultiplied RGB and alpha independently."""
    rgba = image.convert("RGBA")
    red, green, blue, alpha = rgba.split()
    alpha_values = list(alpha.get_flattened_data())
    premultiplied: list[Image.Image] = []
    for channel in (red, green, blue):
        premultiplied_channel = Image.new("L", rgba.size)
        premultiplied_channel.putdata([
            round(value * a / 255)
            for value, a in zip(channel.get_flattened_data(), alpha_values)
        ])
        premultiplied.append(premultiplied_channel.resize(size, Image.Resampling.BOX))
    small_alpha = alpha.resize(size, Image.Resampling.BOX)

    result = Image.new("RGBA", size)
    pixels: list[tuple[int, int, int, int]] = []
    for red, green, blue, a in zip(
        premultiplied[0].get_flattened_data(),
        premultiplied[1].get_flattened_data(),
        premultiplied[2].get_flattened_data(),
        small_alpha.get_flattened_data(),
    ):
        if a == 0 or (binary_alpha and a < 128):
            pixels.append((0, 0, 0, 0))
            continue
        pixels.append(
            (
                min(255, round(red * 255 / a)),
                min(255, round(green * 255 / a)),
                min(255, round(blue * 255 / a)),
                255 if binary_alpha else a,
            )
        )
    result.putdata(pixels)
    return result


def quantize_rgba(image: Image.Image, colors: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    flattened = Image.new("RGB", rgba.size, (8, 10, 18))
    flattened.paste(rgba.convert("RGB"), mask=alpha)
    reduced = flattened.quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    result = reduced.convert("RGBA")
    result.putalpha(alpha)
    return result


def upscale(image: Image.Image, scale: int = EXPORT_SCALE) -> Image.Image:
    return image.resize(
        (image.width * scale, image.height * scale),
        Image.Resampling.NEAREST,
    )


def build_sky(source: Image.Image) -> Image.Image:
    cropped = cover_crop(source.convert("RGB"), LOGICAL_SIZE)
    logical = cropped.resize(LOGICAL_SIZE, Image.Resampling.BOX).convert("RGBA")
    logical.putalpha(255)
    return quantize_rgba(logical, 40).convert("RGB")


def build_village(source: Image.Image) -> Image.Image:
    keyed = key_magenta(source)
    cropped = cover_crop(keyed, LOGICAL_SIZE)
    logical = box_resize_rgba(cropped, LOGICAL_SIZE, binary_alpha=True)
    logical = quantize_rgba(logical, 40)
    # A second hard check prevents any high-saturation key remnant from shipping.
    cleaned: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in logical.get_flattened_data():
        fringe = alpha and red >= 135 and blue >= 125 and green <= 105 and min(red, blue) - green >= 35
        cleaned.append((0, 0, 0, 0) if fringe else (red, green, blue, alpha))
    logical.putdata(cleaned)
    # Higgsfield kept the requested empty key field but let distant roofs begin
    # too high. Preserve the generated scene while compressing its vertical
    # staging into the lower ~48%, leaving the title-safe sky genuinely clear.
    bbox = logical.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("keyed village has no visible pixels")
    subject = logical.crop((0, bbox[1], logical.width, logical.height))
    subject = box_resize_rgba(subject, (LOGICAL_SIZE[0], 460), binary_alpha=True)
    staged = Image.new("RGBA", LOGICAL_SIZE)
    staged.alpha_composite(subject, (0, LOGICAL_SIZE[1] - subject.height))
    return staged


def trim_visible(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("generated source has no visible subject")
    return image.crop(bbox)


def fit_logo(source: Image.Image) -> Image.Image:
    subject = trim_visible(key_magenta(source))
    available = (LOGO_LOGICAL_SIZE[0] - 4, LOGO_LOGICAL_SIZE[1] - 4)
    factor = min(available[0] / subject.width, available[1] / subject.height)
    size = (max(1, round(subject.width * factor)), max(1, round(subject.height * factor)))
    reduced = box_resize_rgba(subject, size, binary_alpha=True)
    reduced = quantize_rgba(reduced, 32)
    canvas = Image.new("RGBA", LOGO_LOGICAL_SIZE)
    canvas.alpha_composite(
        reduced,
        ((canvas.width - reduced.width) // 2, (canvas.height - reduced.height) // 2),
    )
    return canvas


def text_mask(text: str, font_size: int) -> Image.Image:
    font = ImageFont.truetype(str(FONT_PATH), font_size)
    mask = Image.new("L", LOGO_LOGICAL_SIZE)
    draw = ImageDraw.Draw(mask)
    bbox = draw.textbbox((0, 0), text, font=font)
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    x = (mask.width - width) // 2 - bbox[0]
    y = 129 - height // 2 - bbox[1]
    draw.text((x, y), text, font=font, fill=255)
    return mask.point(lambda value: 255 if value >= 128 else 0)


def apply_logo_text(base: Image.Image, text: str, font_size: int) -> Image.Image:
    mask = text_mask(text, font_size)
    outline = mask.filter(ImageFilter.MaxFilter(7))
    result = base.copy()
    outline_layer = Image.new("RGBA", result.size, (16, 12, 12, 255))
    fill_layer = Image.new("RGBA", result.size, (244, 229, 194, 255))
    result.alpha_composite(Image.composite(outline_layer, Image.new("RGBA", result.size), outline))
    result.alpha_composite(Image.composite(fill_layer, Image.new("RGBA", result.size), mask))
    return result


def draw_mock_button(canvas: Image.Image) -> None:
    draw = ImageDraw.Draw(canvas)
    box = (40, 824, 500, 898)
    draw.rounded_rectangle(box, radius=12, fill="#e2a057", outline="#4a2e14", width=4)
    draw.rounded_rectangle((46, 830, 494, 892), radius=8, outline="#edb26c", width=2)
    font = ImageFont.truetype(str(FONT_PATH), 28)
    draw.text((270, 861), "게임 시작", font=font, fill="#4a2e14", anchor="mm")


def draw_settings_glyph(canvas: Image.Image) -> None:
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((16, 16, 64, 64), radius=8, fill="#241a12", outline="#6e4322", width=3)
    center = (40, 40)
    for dx, dy in ((0, -15), (0, 15), (-15, 0), (15, 0), (-11, -11), (11, -11), (-11, 11), (11, 11)):
        draw.rectangle((center[0] + dx - 3, center[1] + dy - 3, center[0] + dx + 3, center[1] + dy + 3), fill="#c49a3d")
    draw.ellipse((27, 27, 53, 53), fill="#c49a3d")
    draw.ellipse((34, 34, 46, 46), fill="#16110d")


def assert_contract(sky: Image.Image, village: Image.Image, logos: tuple[Image.Image, ...]) -> None:
    if sky.size != LOGICAL_SIZE or village.size != LOGICAL_SIZE:
        raise ValueError("background logical canvas must be 540x960")
    if sky.mode != "RGB":
        raise ValueError("sky layer must be opaque")
    if set(village.getchannel("A").get_flattened_data()) - {0, 255}:
        raise ValueError("village layer alpha must be binary")
    top_alpha = village.getchannel("A").crop((0, 0, 540, 460))
    if top_alpha.getbbox() is not None:
        raise ValueError("village intrudes into the upper title-safe sky")
    for logo in logos:
        if logo.size != LOGO_LOGICAL_SIZE:
            raise ValueError("logo logical canvas must be 420x200")
        if set(logo.getchannel("A").get_flattened_data()) - {0, 255}:
            raise ValueError("logo alpha must be binary")


def main() -> None:
    ensure_sources()
    OUT.mkdir(parents=True, exist_ok=True)

    sky = build_sky(Image.open(RAW_DIR / "sky_raw.png"))
    village = build_village(Image.open(RAW_DIR / "village_raw.png"))
    logo_base = fit_logo(Image.open(RAW_DIR / "logo_raw.png"))
    logo_ko = apply_logo_text(logo_base, "조선라이크", 43)
    logo_en = apply_logo_text(logo_base, "JOSEONLIKE", 39)
    assert_contract(sky, village, (logo_ko, logo_en))

    upscale(sky).save(OUT / "bg_sky.png", optimize=True)
    upscale(village).save(OUT / "bg_village.png", optimize=True)
    upscale(logo_ko).save(OUT / "logo_ko.png", optimize=True)
    upscale(logo_en).save(OUT / "logo_en.png", optimize=True)

    preview = sky.convert("RGBA")
    preview.alpha_composite(village)
    preview.alpha_composite(logo_ko, (60, 90))
    draw_mock_button(preview)
    draw_settings_glyph(preview)
    preview.convert("RGB").save(OUT / "preview.png", optimize=True)
    print("built sky, keyed village, KO/EN signboards, and 540x960 preview")


if __name__ == "__main__":
    main()
