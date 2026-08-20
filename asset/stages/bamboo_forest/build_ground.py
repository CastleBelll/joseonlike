"""Author the bamboo-forest ground tiles.

The shipped tiles were flat: 1017 of each tile's 1024 logical pixels were one
colour, and the four of them sat within 5/255 of each other. GroundLayer runs a
whole system on top of that — density noise picks patches, a type noise picks
which variant, every tile gets a seeded 90-degree rotation, variants composite
at 68% alpha — and all of it was invisible work, because rotating a flat colour
and blending a flat colour over a flat colour changes nothing. The field read as
a black void with props glued onto it.

The tiles are authored here rather than painted, for two reasons: the pattern
has to be periodic to tile seamlessly, and it has to survive a 90-degree
rotation. A per-pixel value hash gives both for free — the pattern repeats by
construction so edges always agree, and speckle has no orientation to break.

Colours stay night-dark. The problem was never brightness, it was that there
were no steps: four values a few units apart read as texture at 32px where one
value reads as nothing at all.

Run: python asset/stages/bamboo_forest/build_ground.py
"""

from collections import Counter
from pathlib import Path

from PIL import Image

OUT_DIR = Path(__file__).resolve().parent
VARIANT_DIR = OUT_DIR / "ground_variants"

LOGICAL_PX = 32
EXPORT_SCALE = 16

# Each tile is a weighted value ramp, darkest first. Weights are relative counts,
# so the last entry is the rare accent that stops the eye reading a repeat.
TILES = {
    "ground_tile": {
        "target": OUT_DIR / "ground_tile.png",
        # Packed forest floor: cold, mostly even, a few paler scuffs.
        "ramp": [("#141b19", 4), ("#1b2320", 7), ("#212a26", 4), ("#27312c", 1)],
        "blades": None,
    },
    "dirt": {
        "target": VARIANT_DIR / "dirt.png",
        # Bare earth: warmer and coarser, with the odd small stone. The hue
        # carries the difference rather than the brightness — a patch has to
        # read as another SURFACE at 68% alpha without turning the night grey.
        "ramp": [("#1e1610", 4), ("#2b2116", 7), ("#352a1c", 4), ("#423422", 1)],
        "blades": None,
    },
    "moss": {
        "target": VARIANT_DIR / "moss.png",
        # Damp moss: cool green, soft, one bright fleck.
        "ramp": [("#14251b", 4), ("#1a3627", 7), ("#224434", 4), ("#2a5240", 1)],
        "blades": None,
    },
    "patchy_grass": {
        "target": VARIANT_DIR / "patchy_grass.png",
        # Thin grass over earth: warmer and yellower than moss, so the two
        # never read as the same patch, and it carries actual blades.
        "ramp": [("#1d2714", 5), ("#29371b", 7), ("#334523", 4)],
        "blades": {"color": "#3f5429", "tip": "#4c6633", "count": 7},
    },
}


def rgb(value: str) -> tuple[int, int, int]:
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def value_hash(x: int, y: int, salt: int) -> int:
    """A stable per-pixel hash.

    Arithmetic rather than `random`: the tile ships as a file, so it has to come
    out byte-identical on every machine and every rerun. A re-export that
    shifted one pixel would show up as a diff nobody could explain.
    """
    h = (x * 374761393 + y * 668265263 + salt * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return h ^ (h >> 16)


def build(name: str, spec: dict) -> None:
    ramp = [(rgb(colour), weight) for colour, weight in spec["ramp"]]
    total = sum(weight for _, weight in ramp)
    salt = sum(ord(c) for c in name)

    image = Image.new("RGB", (LOGICAL_PX, LOGICAL_PX))
    pixels = image.load()
    for y in range(LOGICAL_PX):
        for x in range(LOGICAL_PX):
            roll = value_hash(x, y, salt) % total
            for colour, weight in ramp:
                roll -= weight
                if roll < 0:
                    pixels[x, y] = colour
                    break

    blades = spec["blades"]
    if blades is not None:
        body = rgb(blades["color"])
        tip = rgb(blades["tip"])
        for i in range(blades["count"]):
            # Kept clear of every edge so a blade never straddles the seam
            # between two tiles, where the 90-degree rotation would break it
            # into two half-blades pointing different ways.
            bx = 1 + value_hash(i, 0, salt + 17) % (LOGICAL_PX - 2)
            by = 2 + value_hash(0, i, salt + 31) % (LOGICAL_PX - 4)
            height = 2 + value_hash(i, i, salt + 47) % 2
            for step in range(height):
                pixels[bx, by - step] = tip if step == height - 1 else body

    side = LOGICAL_PX * EXPORT_SCALE
    spec["target"].parent.mkdir(parents=True, exist_ok=True)
    image.resize((side, side), Image.NEAREST).save(spec["target"])

    counts = Counter(image.getdata())
    dominant = counts.most_common(1)[0][1] / float(LOGICAL_PX * LOGICAL_PX) * 100.0
    print(
        f"  {spec['target'].name}: {len(counts)} colours, "
        f"most common {dominant:.0f}% of the tile"
    )


def main() -> None:
    for name, spec in TILES.items():
        build(name, spec)


if __name__ == "__main__":
    main()
