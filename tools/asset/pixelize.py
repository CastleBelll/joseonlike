"""Convert a generated image into a sprite that matches a reference sprite's style.

Usage: python sprite_pixelize.py <in.png> <out.png> <content_height> <palette_dir>
       [canvas_size|WIDTHxHEIGHT] [--opaque-background] [--checker-background]
       [--fixed-cell]

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

from PIL import Image, ImageOps

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
            near_sampled_background = (
                    abs(r - background[0]) <= CHROMA_TOLERANCE
                    and abs(g - background[1]) <= CHROMA_TOLERANCE
                    and abs(b - background[2]) <= CHROMA_TOLERANCE)
            # Some sheet generations add low-amplitude noise to the requested
            # magenta. Remove the entire magenta family rather than preserving
            # darker islands that become a visible rectangle after scaling.
            magenta_chroma = (
                    r > 120 and b > 120 and g < 110
                    and abs(r - b) < 85 and min(r, b) - g > 55)
            if near_sampled_background or magenta_chroma:
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


def key_out_checker(image):
    """Remove a generator-drawn transparency checker connected to cell edges.

    Some backends render a grey checkerboard despite an explicit chroma request.
    Restricting removal to bright, nearly-neutral pixels reachable from an edge
    preserves enclosed white effect cores while clearing the synthetic backdrop.
    """
    pixels = image.load()
    width, height = image.size
    pending = []
    seen = set()
    for x in range(width):
        pending.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        pending.extend(((0, y), (width - 1, y)))
    while pending:
        x, y = pending.pop()
        if (x, y) in seen:
            continue
        seen.add((x, y))
        r, g, b, a = pixels[x, y]
        neutral_background = a and min(r, g, b) >= 140 and max(r, g, b) - min(r, g, b) <= 45
        already_clear = a == 0
        if not (neutral_background or already_clear):
            continue
        if neutral_background:
            pixels[x, y] = (r, g, b, 0)
        if x:
            pending.append((x - 1, y))
        if x + 1 < width:
            pending.append((x + 1, y))
        if y:
            pending.append((x, y - 1))
        if y + 1 < height:
            pending.append((x, y + 1))
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
    canvas_size = None
    output_size = None
    opaque_background = False
    checker_background = False
    fixed_cell = False
    for option in sys.argv[5:]:
        if option == "--opaque-background":
            opaque_background = True
        elif option == "--checker-background":
            checker_background = True
        elif option == "--fixed-cell":
            fixed_cell = True
        elif "x" in option.lower():
            width_text, height_text = option.lower().split("x", 1)
            output_size = (int(width_text), int(height_text))
        else:
            canvas_size = int(option)
    if canvas_size is not None and output_size is not None:
        raise SystemExit("choose either a square canvas_size or WIDTHxHEIGHT, not both")
    if fixed_cell and canvas_size is None:
        raise SystemExit("--fixed-cell requires a square canvas_size")

    image = Image.open(source_path).convert("RGBA")
    if not opaque_background:
        image = key_out(image, corner_colour(image))
        if checker_background:
            image = key_out_checker(image)

    bbox = image.getbbox()
    if bbox is None:
        raise SystemExit("%s: keying removed everything; check the background colour" % source_path)

    if fixed_cell:
        # Animation sheets use one common source scale. Cropping each frame to
        # its own subject would enlarge a collapsed body back to standing size,
        # destroying the death progression we need to measure and display.
        scale = min(canvas_size / image.width, canvas_size / image.height)
        resized = image.resize(
            (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
            Image.Resampling.BOX,
        )
        image = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        image.alpha_composite(
            resized,
            ((canvas_size - resized.width) // 2, (canvas_size - resized.height) // 2),
        )
        target_width = target_height = canvas_size
    else:
        image = image.crop(bbox)

    if fixed_cell:
        pass
    elif output_size is not None:
        image = ImageOps.fit(
            image,
            output_size,
            method=Image.Resampling.BOX,
            centering=(0.5, 0.5),
        )
        target_width, target_height = output_size
    else:
        width, height = image.size
        target_width = max(1, round(width * content_height / height))
        target_height = content_height
        image = image.resize((target_width, target_height), Image.BOX)

    palette = reference_palette(palette_dir) + subject_colours(image, SUBJECT_COLOURS)
    image = quantise(image, palette)

    if canvas_size is not None and not fixed_cell:
        image = fit_to_canvas(image, canvas_size)

    used = {pixel[:3] for pixel in flattened(image) if pixel[3] > 0}
    image.save(out_path)
    print("%s -> %s  %dx%d  colours=%d (palette of %d)" % (
        source_path, out_path, target_width, target_height, len(used), len(palette)))


if __name__ == "__main__":
    main()
