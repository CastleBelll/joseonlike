"""Build accepted-cell reference strips for the seven failed rotation sets."""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "asset" / "rotation_audit" / "fix_references"
CORRECT_DIRECTIONS = {
    "Warrior": ("south", "south-east", "north-east", "north", "south-west"),
    "Archer": ("south", "south-east", "north", "west"),
    "bamboo_brute": ("south", "south-east", "east", "north", "west"),
    "bamboo_spirit_lord": ("south", "south-east", "east", "north", "west", "south-west"),
    "forest_spirit": ("south", "south-east", "east", "north", "west", "south-west"),
    "gumiho": ("south", "east", "west", "south-west"),
}


def directory(name: str) -> Path:
    if name in ("Warrior", "Archer"):
        return ROOT / "asset" / "character" / name / "Idle" / "rotations"
    return ROOT / "asset" / "monster" / name / "rotations"


def largest_component(image: Image.Image) -> Image.Image:
    """Remove detached bleed from the cheonyeo flat authority."""
    alpha = image.getchannel("A")
    unseen = {(x, y) for y in range(image.height) for x in range(image.width) if alpha.getpixel((x, y))}
    components = []
    while unseen:
        start = unseen.pop()
        pending = deque([start])
        component = {start}
        while pending:
            x, y = pending.popleft()
            for point in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if point in unseen:
                    unseen.remove(point)
                    component.add(point)
                    pending.append(point)
        components.append(component)
    keep = max(components, key=len)
    cleaned = Image.new("RGBA", image.size, (0, 0, 0, 0))
    source = image.load()
    target = cleaned.load()
    for point in keep:
        target[point] = source[point]
    return cleaned


def strip(name: str, directions: tuple[str, ...]) -> Image.Image:
    cell = 116
    label_height = 20
    image = Image.new("RGBA", (cell * len(directions), cell), (255, 0, 255, 255))
    draw = ImageDraw.Draw(image)
    for index, direction in enumerate(directions):
        sprite = Image.open(directory(name) / f"{direction}.png").convert("RGBA")
        x = index * cell + (cell - sprite.width) // 2
        image.alpha_composite(sprite, (x, label_height))
        draw.text(
            (index * cell + 4, 3), direction,
            fill=(255, 255, 255, 255), stroke_width=1, stroke_fill=(0, 0, 0, 255),
        )
    return image


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, directions in CORRECT_DIRECTIONS.items():
        path = OUTPUT / f"{name}.png"
        strip(name, directions).save(path)
        print(f"{name}: {', '.join(directions)} -> {path.relative_to(ROOT)}")

    source = Image.open(ROOT / "asset" / "monster" / "cheonyeo_gwisin.png").convert("RGBA")
    cleaned = largest_component(source)
    clean_path = OUTPUT / "cheonyeo_gwisin_clean_flat.png"
    cleaned.save(clean_path)
    print(f"cheonyeo_gwisin largest connected component -> {clean_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
