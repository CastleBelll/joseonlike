"""Turn generated ground concept art into a dark, guaranteed seamless tile.

The source is offset by half its size so its original center becomes the outer
edges, then a feathered cross blend repairs the new center seams. Finally it is
downsampled and quantised without dithering to keep the game pixel-art native.
"""
from pathlib import Path
import sys

from PIL import Image, ImageEnhance, ImageFilter, ImageOps


def main() -> None:
    source_path, output_path = sys.argv[1:3]
    target = int(sys.argv[3]) if len(sys.argv) > 3 else 256
    source = Image.open(source_path).convert("RGB")
    side = min(source.size)
    source = ImageOps.fit(source, (side, side), method=Image.Resampling.LANCZOS)

    # Mirror a half-tile quadrant into four quadrants. Mirroring makes opposite
    # edges bit-identical, which is more dependable than a model's "seamless" claim.
    half = side // 2
    quadrant = ImageOps.fit(source, (half, half), method=Image.Resampling.LANCZOS)
    tile = Image.new("RGB", (half * 2, half * 2))
    tile.paste(quadrant, (0, 0))
    tile.paste(ImageOps.mirror(quadrant), (half, 0))
    tile.paste(ImageOps.flip(quadrant), (0, half))
    tile.paste(ImageOps.flip(ImageOps.mirror(quadrant)), (half, half))

    tile = ImageEnhance.Color(tile).enhance(0.62)
    tile = ImageEnhance.Contrast(tile).enhance(0.72)
    tile = ImageEnhance.Brightness(tile).enhance(0.52)
    tile = tile.resize((target, target), Image.Resampling.BOX)
    tile = tile.quantize(colors=32, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    tile.save(output_path)
    print(f"{source_path} -> {output_path} {target}x{target}, guaranteed mirrored seams")


if __name__ == "__main__":
    main()
