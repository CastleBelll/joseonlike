"""Convert a generated image into a sprite that matches a reference sprite's style.

Usage: python sprite_pixelize.py <in.png> <out.png> <content_height> <palette_dir> [canvas_size]

Style match is three separate things, and the earlier cut script only did the first:

1. Chroma-key the flat generator background and crop to content.
2. Downscale to the reference's ACTUAL logical resolution. The Taoist reference is
   37x46 pixels of character, so a 120px-tall monster reads as a different, much
   more detailed art style no matter how good the source image is.
3. Quantise to the reference palette. Sharing an exact palette is what makes two
   sprites look drawn by the same hand; matching prompts alone never gets there.

BOX downscaling averages the source blocks before quantisation, which lands closer
to hand-drawn pixel art than NEAREST - NEAREST point-samples one arbitrary pixel per
output cell and keeps generator noise.
"""
import pathlib
import sys

from PIL import Image

CHROMA_TOLERANCE = 60    # generator backgrounds are flat but not bit-exact
ALPHA_CUTOFF = 128       # pixel art has hard edges, never soft ones
OUTLINE_DARKNESS = 60    # sum(rgb) below this counts as outline, kept pure


def flattened(image):
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def corner_colour(image):
    width, height = image.size
    corners = [
        image.getpixel((0, 0))[:3],
        image.getpixel((width - 1, 0))[:3],
        image.getpixel((0, height - 1))[:3],
        image.getpixel((width - 1, height - 1))[:3],
    ]
    counts = {}
    for colour in corners:
        counts[colour] = counts.get(colour, 0) + 1
    return max(counts, key=counts.get)


def key_out(image, background):
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            r, g, b, _ = pixels[x, y]
            if (abs(r - background[0]) <= CHROMA_TOLERANCE
                    and abs(g - background[1]) <= CHROMA_TOLERANCE
                    and abs(b - background[2]) <= CHROMA_TOLERANCE):
                pixels[x, y] = (r, g, b, 0)
    return image


SUBJECT_COLOURS = 14   # hues kept from the creature itself


def reference_palette(palette_dir):
    """Every opaque colour used by the reference sprites, most common first."""
    counts = {}
    for path in sorted(pathlib.Path(palette_dir).glob("*.png")):
        image = Image.open(path).convert("RGBA")
        for pixel in flattened(image):
            if pixel[3] > 0:
                counts[pixel[:3]] = counts.get(pixel[:3], 0) + 1
    if not counts:
        raise SystemExit("no reference sprites found in %s" % palette_dir)
    return [colour for colour, _ in sorted(counts.items(), key=lambda item: -item[1])]


def subject_colours(image, count):
    """Dominant colours of the creature itself, via adaptive quantisation.

    Snapping purely to the reference palette killed every hue the reference did
    not already contain - a bamboo creature came out stone grey. Style
    consistency comes from resolution, outline weight and flat shading, not from
    forcing identical hues, so the creature keeps its own colours too.
    """
    opaque = Image.new("RGB", image.size, (0, 0, 0))
    opaque.paste(image.convert("RGB"), mask=image.split()[3])
    reduced = opaque.quantize(colors=count, method=Image.MEDIANCUT).convert("RGB")
    counts = {}
    for pixel in flattened(reduced):
        counts[pixel[:3]] = counts.get(pixel[:3], 0) + 1
    return [colour for colour, _ in sorted(counts.items(), key=lambda item: -item[1])]


def nearest(colour, palette):
    r, g, b = colour
    best = None
    best_distance = None
    for candidate in palette:
        # Weighted to human luminance sensitivity so hue shifts stay believable.
        distance = (
            2 * (r - candidate[0]) ** 2
            + 4 * (g - candidate[1]) ** 2
            + 3 * (b - candidate[2]) ** 2
        )
        if best_distance is None or distance < best_distance:
            best_distance = distance
            best = candidate
    return best


def quantise(image, palette):
    pixels = image.load()
    width, height = image.size
    cache = {}
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a < ALPHA_CUTOFF:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            if r + g + b <= OUTLINE_DARKNESS:
                # Keep the silhouette outline pure black rather than letting it drift
                # into the nearest dark blue; the outline is what reads at sprite size.
                pixels[x, y] = (0, 0, 0, 255)
                continue
            key = (r, g, b)
            if key not in cache:
                cache[key] = nearest(key, palette)
            mapped = cache[key]
            pixels[x, y] = (mapped[0], mapped[1], mapped[2], 255)
    return image


def fit_to_canvas(image, canvas_size):
    """Fit and centre a sprite on an exact transparent square icon canvas."""
    if image.width > canvas_size or image.height > canvas_size:
        scale = min(canvas_size / image.width, canvas_size / image.height)
        image = image.resize(
            (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
            Image.Resampling.NEAREST,
        )
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    canvas.alpha_composite(
        image,
        ((canvas_size - image.width) // 2, (canvas_size - image.height) // 2),
    )
    return canvas


def main():
    source_path, out_path = sys.argv[1], sys.argv[2]
    content_height = int(sys.argv[3])
    palette_dir = sys.argv[4]
    canvas_size = int(sys.argv[5]) if len(sys.argv) > 5 else None

    image = Image.open(source_path).convert("RGBA")
    image = key_out(image, corner_colour(image))

    bbox = image.getbbox()
    if bbox is None:
        raise SystemExit("%s: keying removed everything; check the background colour" % source_path)
    image = image.crop(bbox)

    width, height = image.size
    target_width = max(1, round(width * content_height / height))
    image = image.resize((target_width, content_height), Image.BOX)

    palette = reference_palette(palette_dir) + subject_colours(image, SUBJECT_COLOURS)
    image = quantise(image, palette)

    if canvas_size is not None:
        image = fit_to_canvas(image, canvas_size)

    used = {pixel[:3] for pixel in flattened(image) if pixel[3] > 0}
    image.save(out_path)
    print("%s -> %s  %dx%d  colours=%d (palette of %d)" % (
        source_path, out_path, target_width, content_height, len(used), len(palette)))


if __name__ == "__main__":
    main()
