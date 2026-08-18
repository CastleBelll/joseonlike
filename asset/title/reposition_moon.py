#!/usr/bin/env python3
"""Move the moon higher in bg_sky.png (owner direction: '달을 위로 올려').

Detected moon center: ~(762, 744), radius ~105px, in the 1080x1920 export.
Erases the old moon by reconstructing each row's background color from the
same row's pixels outside the moon's x-range (the sky gradient is vertical,
so a per-row fill matches far better than copying a patch from elsewhere),
then pastes the original moon+halo patch higher up through a soft mask.
"""

from PIL import Image, ImageDraw, ImageFilter

SRC = "asset/title/bg_sky.png"
MOON_X, MOON_Y = 762, 744
PATCH_RADIUS = 300   # crop bounds; generous margin around the halo
MASK_RADIUS = 220    # covers the full soft glow (disc ~105 + halo falloff)
TARGET_Y = 280


def radial_mask(patch_size: int, fill_radius: int) -> Image.Image:
    # Small blur sigma relative to fill_radius: the interior must stay at a
    # solid 255 (a wide blur erodes the center too, letting old content
    # bleed through) while only the outer rim feathers to 0.
    mask = Image.new("L", (patch_size, patch_size), 0)
    draw = ImageDraw.Draw(mask)
    c = patch_size // 2
    draw.ellipse([(c - fill_radius, c - fill_radius), (c + fill_radius, c + fill_radius)], fill=255)
    return mask.filter(ImageFilter.GaussianBlur(fill_radius * 0.12))


def main() -> None:
    img = Image.open(SRC).convert("RGB")
    half = PATCH_RADIUS
    size = half * 2
    mask = radial_mask(size, MASK_RADIUS)

    original_patch = img.crop(
        (MOON_X - half, MOON_Y - half, MOON_X + half, MOON_Y + half)
    )
    # Real sky (with its own stars/cloud streaks) from the same y-band,
    # horizontally mirrored, so erasing the old moon keeps the ambient
    # texture instead of leaving a flat, detail-less hole.
    mirror_x = 1080 - MOON_X
    mirror_patch = img.crop(
        (mirror_x - half, MOON_Y - half, mirror_x + half, MOON_Y + half)
    )

    img.paste(mirror_patch, (MOON_X - half, MOON_Y - half), mask)
    img.paste(original_patch, (MOON_X - half, TARGET_Y - half), mask)

    img.save(SRC)
    print(f"Moon moved from y={MOON_Y} to y={TARGET_Y}")


if __name__ == "__main__":
    main()
