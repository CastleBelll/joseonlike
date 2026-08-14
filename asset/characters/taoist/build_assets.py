from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "tmp" / "taoist" / "higgsfield-base-retake.png"
OUT = ROOT / "asset" / "characters" / "taoist"
SCALE = 16
GROUND = (28, 36, 22, 255)


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


def snap_palette(image: Image.Image, colors: int) -> Image.Image:
    alpha = image.getchannel("A").point(lambda value: 255 if value else 0)
    rgb = image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    rgb.putalpha(alpha)
    return rgb


def logical_from_crop(source: Image.Image, box: tuple[int, int, int, int], size: tuple[int, int], max_subject: tuple[int, int], colors: int) -> Image.Image:
    subject = trim(source.crop(box))
    max_w, max_h = max_subject
    factor = min(max_w / subject.width, max_h / subject.height)
    resized = subject.resize((max(1, round(subject.width * factor)), max(1, round(subject.height * factor))), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", size)
    x = (size[0] - resized.width) // 2
    y = size[1] - resized.height - 1
    canvas.alpha_composite(resized, (x, y))
    return snap_palette(canvas, colors)


def shift_patch(image: Image.Image, box: tuple[int, int, int, int], dx: int, dy: int) -> None:
    patch = image.crop(box)
    clear = Image.new("RGBA", patch.size)
    image.paste(clear, box)
    image.alpha_composite(patch, (box[0] + dx, box[1] + dy))


def walk_frame(idle: Image.Image, phase: int, bob: int) -> Image.Image:
    frame = Image.new("RGBA", idle.size)
    frame.alpha_composite(idle, (0, -bob))
    # Reposition only source-derived lower-leg and hand patches. These boxes
    # deliberately exclude the head and central torso, which stay pixel-locked.
    shift_patch(frame, (13, 28 - bob, 18, 31 - bob), -phase, abs(phase))
    shift_patch(frame, (21, 28 - bob, 25, 31 - bob), phase, 0)
    shift_patch(frame, (12, 23 - bob, 16, 27 - bob), phase, -phase)
    shift_patch(frame, (23, 23 - bob, 26, 27 - bob), -phase, phase)
    return frame


def upscale(image: Image.Image) -> Image.Image:
    return image.resize((image.width * SCALE, image.height * SCALE), Image.Resampling.NEAREST)


def save_outputs(idle: Image.Image, portrait: Image.Image) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    walk_logical = [
        walk_frame(idle, phase=0, bob=0),
        walk_frame(idle, phase=1, bob=1),
        walk_frame(idle, phase=0, bob=0),
        walk_frame(idle, phase=-1, bob=1),
    ]

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
    walk_display = walk_export.resize((1536, 384), Image.Resampling.NEAREST)
    sheet.alpha_composite(walk_display, (576, 160))
    draw.text((2160, 36), "PORTRAIT", fill=(245, 224, 174, 255))
    portrait_display = portrait_export.resize((384, 384), Image.Resampling.NEAREST)
    sheet.alpha_composite(portrait_display, (2144, 128))
    draw.text((48, 896), "Logical 32x32 / 128x32 / 48x48  |  16x nearest export  |  #1c2416 ground check", fill=(173, 209, 160, 255))
    sheet.convert("RGB").save(OUT / "contact-sheet.png", optimize=True)


def main() -> None:
    source = remove_green(Image.open(SOURCE))
    idle = logical_from_crop(source, (25, 340, 790, 1575), (32, 32), (30, 29), 24)
    # Focus the card portrait on the face/upper torso; the separate full-body
    # figure on the left of the Higgsfield sheet must not enter this crop.
    portrait = logical_from_crop(source, (900, 285, 1790, 1495), (48, 48), (46, 46), 32)
    save_outputs(idle, portrait)


if __name__ == "__main__":
    main()
