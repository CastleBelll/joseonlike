"""Build labeled nearest-neighbor overviews of the final combat art."""
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
TRAVEL = ("spinning_talisman", "arrow", "fireball", "throwing_knife", "spirit_bolt")
MELEE = ("wide_sword_arc", "dual_blade_cross", "heavy_overhead", "spear_thrust")


def main() -> None:
    panel = Image.new("RGBA", (640, 420), (45, 47, 54, 255))
    draw = ImageDraw.Draw(panel)
    for index, name in enumerate(TRAVEL):
        with Image.open(ROOT / f"asset/weapon/travel/{name}.png").convert("RGBA") as sprite:
            sprite = sprite.resize((128, 128), Image.Resampling.NEAREST)
            panel.alpha_composite(sprite, (index * 128, 24))
            draw.text((index * 128 + 4, 4), name, fill=(255, 244, 219, 255))
    for index, name in enumerate(MELEE):
        with Image.open(ROOT / f"asset/weapon/melee/{name}.png").convert("RGBA") as sprite:
            sprite = sprite.resize((192, 192), Image.Resampling.NEAREST)
            x = index * 160
            panel.alpha_composite(sprite, (x - 16, 190))
            draw.text((x + 4, 168), name, fill=(255, 244, 219, 255))
    output = ROOT / "asset/weapon/raw/combat_art_overview.png"
    panel.save(output)
    print(output.relative_to(ROOT))

    effects = Image.new("RGBA", (512, 164), (45, 47, 54, 255))
    draw = ImageDraw.Draw(effects)
    for row, name in enumerate(("fireball_impact", "spirit_bolt_impact")):
        draw.text((4, row * 82 + 2), name, fill=(255, 244, 219, 255))
        for frame in range(4):
            with Image.open(ROOT / f"asset/effect/{name}/{frame}.png").convert("RGBA") as sprite:
                effects.alpha_composite(sprite, (128 + frame * 64, row * 82 + 16))
    effect_output = ROOT / "asset/effect/raw/paired_impact_overview.png"
    effects.save(effect_output)
    print(effect_output.relative_to(ROOT))


if __name__ == "__main__":
    main()
