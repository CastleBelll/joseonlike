"""Build deterministic Joseon ink/paper nine-slice UI chrome."""
from pathlib import Path

from PIL import Image, ImageDraw

INK = (26, 22, 19, 255)
PAPER = (237, 224, 196, 255)
PAPER_DARK = (214, 197, 161, 255)
VERMILION = (191, 64, 42, 255)
VERMILION_DARK = (139, 44, 28, 255)
GOLD = (196, 154, 61, 255)


def panel(path: Path) -> None:
    image = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((1, 1, 46, 46), fill=INK)
    draw.rectangle((3, 3, 44, 44), fill=PAPER_DARK)
    draw.rectangle((5, 5, 42, 42), fill=PAPER)
    # Broken brush corners remain readable after nine-slice expansion.
    for xy in [(4, 4, 12, 5), (35, 4, 43, 5), (4, 42, 12, 43), (35, 42, 43, 43)]:
        draw.rectangle(xy, fill=VERMILION)
    draw.rectangle((23, 3, 24, 5), fill=GOLD)
    draw.rectangle((23, 42, 24, 44), fill=GOLD)
    image.save(path)


def button(path: Path, fill, inner) -> None:
    image = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((1, 3, 62, 28), fill=INK)
    draw.rectangle((3, 5, 60, 26), fill=fill)
    draw.rectangle((5, 7, 58, 24), fill=inner)
    draw.rectangle((9, 5, 17, 6), fill=GOLD)
    draw.rectangle((46, 25, 54, 26), fill=GOLD)
    image.save(path)


def currency_icons(root: Path) -> None:
    root.mkdir(parents=True, exist_ok=True)
    coin = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(coin)
    draw.ellipse((3, 3, 28, 28), fill=INK)
    draw.ellipse((5, 5, 26, 26), fill=GOLD)
    draw.ellipse((8, 8, 23, 23), outline=PAPER_DARK, width=2)
    draw.rectangle((13, 11, 18, 20), fill=INK)
    draw.rectangle((14, 12, 17, 19), fill=(0, 0, 0, 0))
    coin.save(root / "gold.png")

    crystal = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(crystal)
    draw.polygon([(16, 2), (27, 12), (23, 25), (16, 30), (9, 25), (5, 12)], fill=INK)
    draw.polygon([(16, 5), (24, 13), (20, 23), (16, 27), (12, 23), (8, 13)], fill=(143, 194, 214, 255))
    draw.polygon([(16, 5), (16, 27), (9, 14)], fill=(216, 238, 235, 255))
    draw.rectangle((14, 10, 16, 20), fill=PAPER)
    draw.rectangle((12, 13, 19, 16), fill=PAPER)
    crystal.save(root / "xp.png")


def main() -> None:
    output = Path("asset/ui/chrome")
    output.mkdir(parents=True, exist_ok=True)
    panel(output / "panel_9slice.png")
    button(output / "button_normal_9slice.png", VERMILION_DARK, VERMILION)
    button(output / "button_hover_9slice.png", VERMILION, (205, 81, 55, 255))
    button(output / "button_pressed_9slice.png", INK, VERMILION_DARK)
    currency_icons(Path("asset/ui/currency"))
    print(f"wrote Joseon UI chrome to {output}")


if __name__ == "__main__":
    main()
