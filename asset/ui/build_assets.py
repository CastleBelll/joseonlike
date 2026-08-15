from __future__ import annotations

import json
from pathlib import Path
from urllib.request import urlretrieve

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "asset" / "ui"
RAW_DIR = ROOT / "tmp" / "ui_icons"
SCALE = 16
INK = (26, 22, 19)
OUTLINE = (17, 13, 20)

SOURCES = {
    "weapons_a.png": "https://d8j0ntlcm91z4.cloudfront.net/user_3HCgsqzSxMMvzqXejoYwa267X3D/hf_20260815_033228_8e9e6923-0807-40c4-af63-e096761a25d0.png",
    "weapons_b.png": "https://d8j0ntlcm91z4.cloudfront.net/user_3HCgsqzSxMMvzqXejoYwa267X3D/hf_20260815_033230_9f52901c-42a4-4980-b778-c39a1103c1c6.png",
    "weapons_c.png": "https://d8j0ntlcm91z4.cloudfront.net/user_3HCgsqzSxMMvzqXejoYwa267X3D/hf_20260815_033232_33ea2d75-5a07-4f08-8e98-34cbfb64fc7d.png",
    "weapons_d.png": "https://d8j0ntlcm91z4.cloudfront.net/user_3HCgsqzSxMMvzqXejoYwa267X3D/hf_20260815_033235_b9b32d1f-c011-4bc1-bd5c-e4611b02e563.png",
    "loot.png": "https://d8j0ntlcm91z4.cloudfront.net/user_3HCgsqzSxMMvzqXejoYwa267X3D/hf_20260815_033237_95708d0b-5998-4467-8e18-8e584aafa00a.png",
    "hud.png": "https://d8j0ntlcm91z4.cloudfront.net/user_3HCgsqzSxMMvzqXejoYwa267X3D/hf_20260815_033238_7317550f-bd64-4dd9-89c6-c871b9e51ff6.png",
    "chrome.png": "https://d8j0ntlcm91z4.cloudfront.net/user_3HCgsqzSxMMvzqXejoYwa267X3D/hf_20260815_033241_fea4a173-26c2-4885-a8d8-37de222cf4f7.png",
}

WEAPON_CELLS = {
    "old_talisman": ("weapons_a.png", 0, 0),
    "fire_talisman": ("weapons_a.png", 1, 0),
    "phoenix_talisman": ("weapons_a.png", 2, 0),
    "hwabu": ("weapons_a.png", 3, 0),
    "hwaryeongbu": ("weapons_a.png", 0, 1),
    "noebu": ("weapons_a.png", 1, 1),
    "noejeongbu": ("weapons_a.png", 2, 1),
    "seokjang": ("weapons_b.png", 0, 0),
    "ghost_staff": ("weapons_b.png", 1, 0),
    "honbul": ("weapons_b.png", 2, 0),
    "flame_honbul": ("weapons_b.png", 3, 0),
    "gyeolgye": ("weapons_b.png", 0, 1),
    "hwayeom_gyeolgye": ("weapons_b.png", 1, 1),
    "sal": ("weapons_b.png", 2, 1),
    "sinjang": ("weapons_c.png", 0, 0),
    "noe_sinjang": ("weapons_c.png", 1, 0),
    "jineon": ("weapons_c.png", 2, 0),
    "bongin_jineon": ("weapons_c.png", 3, 0),
    "gwisal": ("weapons_c.png", 0, 1),
    "beopgeom": ("weapons_c.png", 1, 1),
    "bongmageom": ("weapons_c.png", 2, 1),
    "sword": ("weapons_d.png", 0, 0),
    "twin_sword": ("weapons_d.png", 1, 0),
    "sharp_sword": ("weapons_d.png", 2, 0),
    "ghost_sword": ("weapons_d.png", 3, 0),
    "flame_sword": ("weapons_d.png", 0, 1),
    "bow": ("weapons_d.png", 1, 1),
    "divine_bow": ("weapons_d.png", 2, 1),
}

LOOT_CELLS = {
    "bamboo": (0, 0),
    "tough_fiber": (1, 0),
    "beast_fang": (2, 0),
    "talisman_paper": (3, 0),
    "wonhon_shard": (0, 1),
    "dokkaebi_flame": (1, 1),
    "whetstone": (2, 1),
    "ghost_iron": (3, 1),
    "cinnabar": (0, 2),
    "thunder_stone": (1, 2),
    "fire_spirit_stone": (2, 2),
}

HUD_CELLS = {
    "skull": (0, 0),
    "coin": (1, 0),
    "pause": (0, 1),
    "info": (1, 1),
    "timer": (0, 2),
}

# The HUD generation honored all five objects but composed the first four as a
# 2x2 block and tucked the small timer mark into the unused lower-left margin.
# Source-space boxes isolate those generated objects without redrawing them.
HUD_BOXES = {
    "skull": (8, 8, 510, 510),
    "coin": (510, 8, 1020, 510),
    "pause": (76, 520, 468, 1020),
    "info": (500, 520, 1020, 1020),
    "timer": (0, 882, 112, 1024),
}

CHROME_CELLS = {
    "wood_button_normal": (0, 0, (64, 32)),
    "wood_button_hover": (1, 0, (64, 32)),
    "wood_button_pressed": (0, 1, (64, 32)),
    "paper_panel": (1, 1, (64, 64)),
}

CHROME_PALETTES = {
    "wood_button_normal": ((26, 22, 19), (74, 46, 20), (110, 67, 34), (194, 128, 60), (226, 160, 87), (237, 178, 108)),
    "wood_button_hover": ((26, 22, 19), (74, 46, 20), (110, 67, 34), (207, 145, 72), (237, 178, 108), (247, 202, 147)),
    "wood_button_pressed": ((26, 22, 19), (74, 46, 20), (92, 52, 25), (150, 91, 41), (192, 133, 68), (217, 154, 87)),
    "paper_panel": ((26, 22, 19), (110, 67, 34), (168, 152, 128), (205, 190, 160), (237, 224, 196), (247, 240, 226)),
}


def ensure_sources() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    for filename, url in SOURCES.items():
        path = RAW_DIR / filename
        if not path.exists():
            print(f"downloading {filename}")
            urlretrieve(url, path)


def data_ids(filename: str) -> list[str]:
    data = json.loads((ROOT / "data" / filename).read_text(encoding="utf-8"))
    return [key for key in data if not key.startswith("_")]


def assert_id_contract() -> tuple[list[str], list[str]]:
    weapon_ids = data_ids("weapons.json")
    loot_ids = data_ids("loot.json")
    if set(weapon_ids) != set(WEAPON_CELLS):
        raise ValueError(f"weapon atlas mapping drift: data={weapon_ids}, mapped={list(WEAPON_CELLS)}")
    if set(loot_ids) != set(LOOT_CELLS):
        raise ValueError(f"loot atlas mapping drift: data={loot_ids}, mapped={list(LOOT_CELLS)}")
    return weapon_ids, loot_ids


def crop_cell(image: Image.Image, column: int, row: int, columns: int, rows: int) -> Image.Image:
    inset = 8
    left = round(column * image.width / columns) + inset
    right = round((column + 1) * image.width / columns) - inset
    top = round(row * image.height / rows) + inset
    bottom = round((row + 1) * image.height / rows) - inset
    return image.crop((left, top, right, bottom))


def key_magenta(image: Image.Image, *, remove_dark_well: bool = False) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels: list[tuple[int, int, int, int]] = []
    for red, green, blue, _ in rgba.get_flattened_data():
        key_strength = min(red, blue) - green
        keyed = red >= 170 and blue >= 145 and green <= 135 and key_strength >= 48
        dark_well = remove_dark_well and max(red, green, blue) < 52
        if keyed or dark_well:
            pixels.append((0, 0, 0, 0))
            continue
        if red > 115 and blue > 110 and key_strength > 22:
            spill = key_strength - 22
            red = max(green + 18, red - spill)
            blue = max(green + 18, blue - spill)
        pixels.append((red, green, blue, 255))
    rgba.putdata(pixels)
    return rgba


def trim(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("atlas cell has no visible subject")
    return image.crop(bbox)


def box_resize_rgba(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = image.convert("RGBA")
    red, green, blue, alpha = rgba.split()
    alpha_values = list(alpha.get_flattened_data())
    premultiplied: list[Image.Image] = []
    for channel in (red, green, blue):
        prepared = Image.new("L", rgba.size)
        prepared.putdata([
            round(value * a / 255)
            for value, a in zip(channel.get_flattened_data(), alpha_values)
        ])
        premultiplied.append(prepared.resize(size, Image.Resampling.BOX))
    small_alpha = alpha.resize(size, Image.Resampling.BOX)
    result = Image.new("RGBA", size)
    pixels: list[tuple[int, int, int, int]] = []
    for red, green, blue, a in zip(
        premultiplied[0].get_flattened_data(),
        premultiplied[1].get_flattened_data(),
        premultiplied[2].get_flattened_data(),
        small_alpha.get_flattened_data(),
    ):
        if a < 128:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((
                min(255, round(red * 255 / a)),
                min(255, round(green * 255 / a)),
                min(255, round(blue * 255 / a)),
                255,
            ))
    result.putdata(pixels)
    return result


def learned_palette(image: Image.Image, colors: int) -> tuple[tuple[int, int, int], ...]:
    samples = [pixel[:3] for pixel in image.get_flattened_data() if pixel[3]]
    if not samples:
        raise ValueError("cannot quantize an empty icon")
    strip = Image.new("RGB", (len(samples), 1))
    strip.putdata(samples)
    reduced = strip.quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    return tuple(dict.fromkeys(reduced.get_flattened_data()))


def apply_palette(image: Image.Image, palette: tuple[tuple[int, int, int], ...]) -> Image.Image:
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    pixels: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in image.get_flattened_data():
        if not alpha:
            pixels.append((0, 0, 0, 0))
            continue
        source = (red, green, blue)
        if source not in cache:
            cache[source] = min(
                palette,
                key=lambda color: sum((value - target) ** 2 for value, target in zip(source, color)),
            )
        pixels.append((*cache[source], 255))
    result = Image.new("RGBA", image.size)
    result.putdata(pixels)
    return result


def add_outline(image: Image.Image, color: tuple[int, int, int] = OUTLINE) -> Image.Image:
    alpha = image.getchannel("A")
    # Pillow exposes MaxFilter through ImageFilter; import locally to keep the
    # public palette/build surface compact.
    from PIL import ImageFilter

    expanded = alpha.filter(ImageFilter.MaxFilter(3))
    ring = ImageChops.subtract(expanded, alpha)
    outline = Image.new("RGBA", image.size, (*color, 255))
    result = Image.new("RGBA", image.size)
    result.paste(outline, mask=ring)
    result.alpha_composite(image)
    return result


def fit_subject(
    source: Image.Image,
    size: tuple[int, int],
    *,
    padding: int,
    colors: int,
    palette: tuple[tuple[int, int, int], ...] | None = None,
    outline: bool,
) -> Image.Image:
    subject = trim(source)
    factor = min(
        (size[0] - padding * 2) / subject.width,
        (size[1] - padding * 2) / subject.height,
    )
    reduced_size = (
        max(1, round(subject.width * factor)),
        max(1, round(subject.height * factor)),
    )
    reduced = trim(box_resize_rgba(subject, reduced_size))
    reduced = apply_palette(reduced, palette or learned_palette(reduced, colors))
    canvas = Image.new("RGBA", size)
    canvas.alpha_composite(
        reduced,
        ((size[0] - reduced.width) // 2, (size[1] - reduced.height) // 2),
    )
    return add_outline(canvas) if outline else canvas


def build_weapon_icons(sources: dict[str, Image.Image]) -> dict[str, Image.Image]:
    output: dict[str, Image.Image] = {}
    for weapon_id, (filename, column, row) in WEAPON_CELLS.items():
        cell = crop_cell(sources[filename], column, row, 4, 2)
        keyed = key_magenta(cell, remove_dark_well=filename == "weapons_a.png")
        output[weapon_id] = fit_subject(
            keyed, (32, 32), padding=2, colors=18, outline=True,
        )
    return output


def build_loot_icons(source: Image.Image) -> dict[str, Image.Image]:
    return {
        loot_id: fit_subject(
            key_magenta(crop_cell(source, column, row, 4, 3)),
            (24, 24), padding=2, colors=14, outline=True,
        )
        for loot_id, (column, row) in LOOT_CELLS.items()
    }


def build_hud_icons(source: Image.Image) -> dict[str, Image.Image]:
    return {
        name: fit_subject(
            key_magenta(source.crop(HUD_BOXES[name])),
            (16, 16), padding=1, colors=8, outline=True,
        )
        for name in HUD_CELLS
    }


def build_chrome(source: Image.Image) -> dict[str, Image.Image]:
    output: dict[str, Image.Image] = {}
    for name, (column, row, size) in CHROME_CELLS.items():
        output[name] = fit_subject(
            key_magenta(crop_cell(source, column, row, 2, 2)),
            size,
            padding=1,
            colors=len(CHROME_PALETTES[name]),
            palette=CHROME_PALETTES[name],
            outline=False,
        )
    return output


def assert_icon(name: str, image: Image.Image, size: tuple[int, int]) -> None:
    if image.size != size:
        raise ValueError(f"{name} wrong logical size: {image.size}")
    alpha = image.getchannel("A")
    if set(alpha.get_flattened_data()) - {0, 255}:
        raise ValueError(f"{name} alpha is not binary")
    bbox = alpha.getbbox()
    if bbox is None or (bbox[2] - bbox[0]) < size[0] // 3 or (bbox[3] - bbox[1]) < size[1] // 3:
        raise ValueError(f"{name} silhouette is too small")
    for red, green, blue, a in image.get_flattened_data():
        if a and red >= 135 and blue >= 125 and green <= 105 and min(red, blue) - green >= 35:
            raise ValueError(f"magenta fringe remains in {name}")


def upscale(image: Image.Image, scale: int = SCALE) -> Image.Image:
    return image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)


def save_assets(
    weapons: dict[str, Image.Image],
    loot: dict[str, Image.Image],
    hud: dict[str, Image.Image],
    chrome: dict[str, Image.Image],
) -> None:
    folders = {
        "weapons": OUT / "weapon_icons",
        "loot": OUT / "loot_icons",
        "hud": OUT / "hud",
        "chrome": OUT / "chrome",
    }
    for folder in folders.values():
        folder.mkdir(parents=True, exist_ok=True)
    for name, image in weapons.items():
        upscale(image).save(folders["weapons"] / f"{name}.png", optimize=True)
    for name, image in loot.items():
        upscale(image).save(folders["loot"] / f"{name}.png", optimize=True)
    for name, image in hud.items():
        upscale(image).save(folders["hud"] / f"{name}.png", optimize=True)
    for name, image in chrome.items():
        upscale(image).save(folders["chrome"] / f"{name}.png", optimize=True)


def make_verification(
    weapon_ids: list[str],
    loot_ids: list[str],
    weapons: dict[str, Image.Image],
    loot: dict[str, Image.Image],
    hud: dict[str, Image.Image],
    chrome: dict[str, Image.Image],
) -> None:
    width = 280
    canvas = Image.new("RGB", (width, 268), (13, 11, 9))
    draw = ImageDraw.Draw(canvas)

    def well(x: int, y: int, size: int) -> None:
        draw.rectangle((x, y, x + size - 1, y + size - 1), fill=INK, outline=(69, 61, 84))

    for index, weapon_id in enumerate(weapon_ids):
        x = 4 + (index % 7) * 36
        y = 4 + (index // 7) * 36
        well(x, y, 32)
        canvas.paste(weapons[weapon_id], (x, y), weapons[weapon_id])

    loot_y = 152
    for index, loot_id in enumerate(loot_ids):
        x = 4 + (index % 7) * 28
        y = loot_y + (index // 7) * 28
        well(x, y, 24)
        canvas.paste(loot[loot_id], (x, y), loot[loot_id])

    hud_y = 208
    for index, name in enumerate(HUD_CELLS):
        x = 4 + index * 20
        well(x, hud_y, 16)
        canvas.paste(hud[name], (x, hud_y), hud[name])

    chrome_y = 232
    for index, name in enumerate(("wood_button_normal", "wood_button_hover", "wood_button_pressed")):
        x = 4 + index * 68
        canvas.paste(chrome[name], (x, chrome_y), chrome[name])
    paper = chrome["paper_panel"]
    canvas.paste(paper, (212, 204), paper)
    upscale(canvas, 4).save(OUT / "verification-grid.png", optimize=True)


def main() -> None:
    ensure_sources()
    weapon_ids, loot_ids = assert_id_contract()
    sources = {filename: Image.open(RAW_DIR / filename) for filename in SOURCES}
    weapons = build_weapon_icons(sources)
    loot = build_loot_icons(sources["loot.png"])
    hud = build_hud_icons(sources["hud.png"])
    chrome = build_chrome(sources["chrome.png"])

    for name, image in weapons.items():
        assert_icon(name, image, (32, 32))
    for name, image in loot.items():
        assert_icon(name, image, (24, 24))
    for name, image in hud.items():
        assert_icon(name, image, (16, 16))
    for name, image in chrome.items():
        assert_icon(name, image, CHROME_CELLS[name][2])

    save_assets(weapons, loot, hud, chrome)
    make_verification(weapon_ids, loot_ids, weapons, loot, hud, chrome)
    print(f"built {len(weapons)} weapon icons, {len(loot)} loot icons, {len(hud)} HUD glyphs, and {len(chrome)} chrome plates")


if __name__ == "__main__":
    main()
