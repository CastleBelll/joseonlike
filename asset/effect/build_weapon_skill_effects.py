from __future__ import annotations

import math
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "asset" / "effect"
GENERATED = ROOT / "new_asset" / "generated"
FRAME = 128
# validate() caps a sheet at 64 RGBA entries and the transparent one counts,
# so the visible palette has to stop below that.
SHEET_PALETTE = 56
SKILL_SPECS = {
    "skill_chamgyeok": {"grid": 75, "scale": 2, "frames": 8, "logical_px": 150},
    "skill_cheolbyeok": {"grid": 48, "scale": 2, "frames": 6, "logical_px": 96},
}

INK = (14, 12, 15, 255)
BRASS_DARK = (91, 67, 36, 255)
BRASS = (186, 145, 73, 255)
CREAM = (245, 222, 159, 255)
DUST_DARK = (78, 65, 49, 255)
DUST = (143, 120, 84, 255)
DUST_HI = (204, 176, 119, 255)
GHOST_DARK = (48, 33, 67, 255)
GHOST = (116, 82, 157, 255)
GHOST_HI = (194, 164, 228, 255)
GHOST_PALE = (235, 221, 255, 255)
CRIMSON_DARK = (83, 25, 31, 255)
CRIMSON = (226, 96, 78, 255)  # #e2604e
CRIMSON_HI = (255, 165, 132, 255)
STEEL_DARK = (49, 55, 61, 255)
STEEL = (104, 116, 122, 255)
STEEL_HI = (190, 199, 199, 255)


def canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (FRAME, FRAME))
    return image, ImageDraw.Draw(image)


def effect_cel_shade(image: Image.Image, seed: int) -> Image.Image:
    """Add hard core/mid/rim bands without creating sub-grid pixels."""
    source = image.copy()
    output = image.copy()
    source_pixels = source.load()
    output_pixels = output.load()
    offsets = (-24, -12, 0, 12, 24)

    def same_material(x: int, y: int, color: tuple[int, int, int, int]) -> bool:
        return 0 <= x < image.width and 0 <= y < image.height and source_pixels[x, y] == color

    for y in range(image.height):
        for x in range(image.width):
            color = source_pixels[x, y]
            if color[3] == 0 or color == INK:
                continue
            lit_edge = not same_material(x - 1, y, color) or not same_material(x, y - 1, color)
            dark_edge = not same_material(x + 1, y, color) or not same_material(x, y + 1, color)
            if lit_edge and not dark_edge:
                tone = 4
            elif dark_edge and not lit_edge:
                tone = 0
            else:
                # A positional ramp inside the fill tiles a 5x6 plaid across the
                # arc, which at display size reads as fabric rather than light.
                # The interior is one tone; the edge bands are what shape it.
                tone = 2
            delta = offsets[tone]
            output_pixels[x, y] = (
                max(0, min(255, color[0] + delta)),
                max(0, min(255, color[1] + delta)),
                max(0, min(255, color[2] + delta)),
                color[3],
            )
    return output


def save_sheet(name: str, frames: list[Image.Image]) -> Image.Image:
    processed: list[Image.Image] = []
    for index, frame in enumerate(frames):
        if name in SKILL_SPECS:
            spec = SKILL_SPECS[name]
            grid = int(spec["grid"])
            scale = int(spec["scale"])
            logical = frame.resize((grid, grid), Image.Resampling.NEAREST)
            logical = effect_cel_shade(logical, index + (7 if name == "skill_chamgyeok" else 19))
            frame = logical.resize((grid * scale, grid * scale), Image.Resampling.NEAREST)
        processed.append(frame)
    cell = processed[0].height
    if any(frame.size != (cell, cell) for frame in processed):
        raise ValueError(f"{name}: frames are not uniformly square")
    sheet = Image.new("RGBA", (cell * len(processed), cell))
    for index, frame in enumerate(processed):
        sheet.alpha_composite(frame, (index * cell, 0))
    if name in SKILL_SPECS:
        # One palette for the whole strip, not one per frame: the frames are the
        # same artwork at different sizes and brightnesses, and quantizing them
        # separately makes the colour crawl between cells.
        alpha = sheet.getchannel("A")
        flat = sheet.convert("RGB").quantize(
            colors=SHEET_PALETTE, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
        ).convert("RGBA")
        flat.putalpha(alpha)
        sheet = flat
    sheet.save(OUT / f"{name}.png", optimize=True)
    return sheet


def outlined_line(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], fill: tuple[int, int, int, int], width: int) -> None:
    draw.line(points, fill=INK, width=width + 2, joint="curve")
    draw.line(points, fill=fill, width=width, joint="curve")


def outlined_ring(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill: tuple[int, int, int, int]) -> None:
    draw.ellipse(box, outline=INK, width=3)
    inset = (box[0] + 1, box[1] + 1, box[2] - 1, box[3] - 1)
    draw.ellipse(inset, outline=fill, width=1)


def star(draw: ImageDraw.ImageDraw, center: tuple[int, int], radius: int, fill: tuple[int, int, int, int]) -> None:
    cx, cy = center
    points: list[tuple[int, int]] = []
    for index in range(16):
        angle = math.radians(index * 22.5 - 90.0)
        use_radius = radius if index % 2 == 0 else max(1, radius // 3)
        points.append((round(cx + math.cos(angle) * use_radius), round(cy + math.sin(angle) * use_radius)))
    draw.polygon(points, fill=INK)
    if radius >= 4:
        inner = max(2, radius - 2)
        inner_points = []
        for index in range(16):
            angle = math.radians(index * 22.5 - 90.0)
            use_radius = inner if index % 2 == 0 else 1
            inner_points.append((round(cx + math.cos(angle) * use_radius), round(cy + math.sin(angle) * use_radius)))
        draw.polygon(inner_points, fill=fill)


def blunt_wedge(
    draw: ImageDraw.ImageDraw,
    length: int,
    half_height: int,
    dark: tuple[int, int, int, int],
    mid: tuple[int, int, int, int],
    highlight: tuple[int, int, int, int],
) -> None:
    ox, oy = 37, 84
    outer = (
        (ox - 5, oy - 1), (ox + 8, oy - 9),
        (ox + length - 8, oy - half_height), (ox + length + 5, oy - half_height + 5),
        (ox + length + 8, oy + 2), (ox + length - 5, oy + half_height),
        (ox + 7, oy + 8),
    )
    draw.polygon(outer, fill=INK)
    inner = (
        (ox - 2, oy - 1), (ox + 10, oy - 6),
        (ox + length - 9, oy - half_height + 2), (ox + length + 2, oy - half_height + 6),
        (ox + length + 5, oy + 2), (ox + length - 6, oy + half_height - 2),
        (ox + 9, oy + 5),
    )
    draw.polygon(inner, fill=dark)
    core = (
        (ox + 6, oy - 2), (ox + length - 9, oy - half_height + 5),
        (ox + length + 1, oy + 1), (ox + length - 8, oy + half_height - 5),
        (ox + 8, oy + 3),
    )
    draw.polygon(core, fill=mid)
    draw.line((ox + 10, oy - 3, ox + length - 7, oy - half_height + 5), fill=highlight, width=2)
    draw.line((ox + length + 2, oy - half_height + 7, ox + length + 5, oy), fill=highlight, width=2)


def dust_and_gravel(draw: ImageDraw.ImageDraw, frame: int) -> None:
    drift = max(0, frame - 1)
    dust_specs = (
        (33 - drift * 2, 91 - drift, 8, 4),
        (54 + drift * 5, 103 - drift * 2, 11, 5),
        (83 + drift * 4, 96 - drift * 3, 9, 4),
    )
    for index, (x, y, width, height) in enumerate(dust_specs):
        if frame < index or x > 124:
            continue
        draw.polygon(((x, y), (x + width // 2, y - height), (x + width, y), (x + width - 2, y + 2), (x + 2, y + 2)), fill=INK)
        draw.polygon(((x + 2, y), (x + width // 2, y - height + 2), (x + width - 2, y),), fill=DUST if index != 1 else DUST_HI)
    gravel = ((45 + drift * 3, 107 - drift * 4), (70 + drift * 5, 99 - drift * 5), (98 + drift * 3, 104 - drift * 6))
    for index, (x, y) in enumerate(gravel):
        if frame >= index + 2 and x < 126:
            draw.rectangle((x, y, x + 3, y + 2), fill=INK)
            draw.point((x + 1, y), fill=DUST_HI)


def soul(draw: ImageDraw.ImageDraw, x: int, y: int, scale: int) -> None:
    draw.ellipse((x - scale, y - scale, x + scale, y + scale), fill=INK)
    draw.ellipse((x - scale + 1, y - scale + 1, x + scale - 1, y + scale - 1), fill=GHOST_PALE)
    tail = ((x - scale, y + scale - 1), (x + scale, y + scale - 1), (x + scale - 1, y + scale + 5), (x + 1, y + scale + 3), (x - 2, y + scale + 8), (x - scale - 1, y + scale + 4))
    draw.polygon(tail, fill=INK)
    inner = tuple((px, py - 1 if index < 2 else py) for index, (px, py) in enumerate(tail[1:-1]))
    draw.polygon(inner, fill=GHOST_HI)


def staff_frames(ghost: bool) -> list[Image.Image]:
    lengths = (9, 29, 51, 72, 80, 69, 50, 28)
    heights = (4, 9, 16, 23, 27, 24, 17, 10)
    frames: list[Image.Image] = []
    for frame, (length, half_height) in enumerate(zip(lengths, heights)):
        image, draw = canvas()
        if frame <= 2:
            color = GHOST_HI if ghost else BRASS
            outlined_line(draw, [(46 - frame * 2, 20 + frame * 7), (40, 78)], color, 4 + frame)
            star(draw, (40, 82), 5 + frame * 2, GHOST_PALE if ghost else CREAM)
        if frame <= 6:
            blunt_wedge(
                draw,
                length,
                half_height,
                GHOST_DARK if ghost else BRASS_DARK,
                GHOST if ghost else BRASS,
                GHOST_PALE if ghost else CREAM,
            )

        ring_color = GHOST_HI if ghost else CREAM
        ring_count = 2 if frame < 3 else 3
        for ring_index in range(ring_count):
            radius = 4 + ring_index * 3 + frame
            cx = 41 + ring_index * 13 + frame * 3
            cy = 83 - ring_index * 9 - frame
            if cx + radius < 128 and frame <= 6:
                outlined_ring(draw, (cx - radius, cy - radius, cx + radius, cy + radius), ring_color)

        if ghost:
            if 2 <= frame <= 7:
                soul(draw, 61 + frame * 4, 76 - frame * 5, 4)
            if 3 <= frame <= 6:
                soul(draw, 88 + frame * 3, 90 - frame * 7, 3)
            if frame >= 5:
                soul(draw, 42 + frame * 2, 75 - frame * 6, 3)
        else:
            dust_and_gravel(draw, frame)
        frames.append(image)
    return frames


def elliptical_sector(
    center: tuple[int, int],
    outer: tuple[int, int],
    inner: tuple[int, int],
    start_deg: int,
    end_deg: int,
) -> list[tuple[int, int]]:
    cx, cy = center
    points = []
    for angle in range(start_deg, end_deg + 1, 3):
        radians = math.radians(angle)
        points.append((round(cx + math.cos(radians) * outer[0]), round(cy + math.sin(radians) * outer[1])))
    for angle in range(end_deg, start_deg - 1, -3):
        radians = math.radians(angle)
        points.append((round(cx + math.cos(radians) * inner[0]), round(cy + math.sin(radians) * inner[1])))
    return points


def skill_render(stem: str) -> Image.Image:
    """One generated still, keyed and trimmed, ready to be posed per frame.

    Drawing these by hand is what the owner rejected twice: seven melee arcs
    that were the same crescent in different colours, and then a sweep with a
    5x6 plaid tiled inside it. The artwork is one render now; the animation is
    still code, because eight independently generated frames would not hold
    their shape from one to the next.
    """
    source = Image.open(GENERATED / f"{stem}.png").convert("RGBA")
    pixels = source.load()
    for y in range(source.height):
        for x in range(source.width):
            r, g, b, _ = pixels[x, y]
            if r > 130 and b > 130 and g < 110:
                pixels[x, y] = (0, 0, 0, 0)
    bounds = source.getbbox()
    if bounds is None:
        raise ValueError(f"{stem}: nothing left after keying")
    return source.crop(bounds)


def posed(art: Image.Image, span: int, angle: float, light: float) -> Image.Image:
    """The still placed on a frame canvas at one moment of the animation.

    A frame fades by going dark, not by going translucent: these sheets carry
    binary alpha (validate() fails anything else), so the resize and the
    rotation both get their soft edges cut back to a hard silhouette.
    """
    scale = span / max(art.size)
    small = art.resize(
        (max(1, round(art.width * scale)), max(1, round(art.height * scale))),
        Image.Resampling.LANCZOS,
    )
    if angle:
        small = small.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    small.putalpha(small.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
    if light != 1.0:
        pixels = small.load()
        for y in range(small.height):
            for x in range(small.width):
                r, g, b, a = pixels[x, y]
                if a:
                    pixels[x, y] = (round(r * light), round(g * light), round(b * light), a)
    image, _draw = canvas()
    image.alpha_composite(small, ((FRAME - small.width) // 2, (FRAME - small.height) // 2))
    return image


def chamgyeok_frames() -> list[Image.Image]:
    """A crimson crescent swept through the arc it cuts.

    The sweep IS the rotation: one blade shape turning from the wind-up to the
    follow-through, growing as it bites and thinning as it leaves. Frame 0 is
    the flash before contact, so it is small and mostly transparent.
    """
    art = skill_render("fx_chamgyeok")
    spans = (58, 84, 110, 122, 126, 120, 108, 92)
    angles = (52.0, 34.0, 14.0, -4.0, -22.0, -40.0, -56.0, -70.0)
    lights = (0.55, 0.8, 1.0, 1.0, 1.0, 0.85, 0.65, 0.45)
    return [
        posed(art, spans[index], angles[index], lights[index])
        for index in range(int(SKILL_SPECS["skill_chamgyeok"]["frames"]))
    ]


def cheolbyeok_frames() -> list[Image.Image]:
    """An iron ring rising to the guard and holding there.

    It never rotates: a spinning ring reads as a projectile, and this is a
    stance. The last two frames are the held pose the buff sits in.
    """
    art = skill_render("fx_cheolbyeok")
    spans = (44, 72, 96, 112, 118, 118)
    lights = (0.5, 0.7, 0.9, 1.0, 1.0, 1.0)
    return [
        posed(art, spans[index], 0.0, lights[index])
        for index in range(int(SKILL_SPECS["skill_cheolbyeok"]["frames"]))
    ]


def split_frames(sheet: Image.Image) -> list[Image.Image]:
    cell = sheet.height
    return [sheet.crop((index * cell, 0, (index + 1) * cell, cell)) for index in range(sheet.width // cell)]


def peak_frame(sheet: Image.Image) -> Image.Image:
    frames = split_frames(sheet)
    return max(frames, key=lambda frame: sum(1 for alpha in frame.getchannel("A").get_flattened_data() if alpha))


def silhouette_iou(left: Image.Image, right: Image.Image) -> float:
    if right.size != left.size:
        right = right.resize(left.size, Image.Resampling.NEAREST)
    left_alpha = left.getchannel("A")
    right_alpha = right.getchannel("A")
    intersection = 0
    union = 0
    for left_value, right_value in zip(left_alpha.get_flattened_data(), right_alpha.get_flattened_data()):
        left_on = bool(left_value)
        right_on = bool(right_value)
        intersection += left_on and right_on
        union += left_on or right_on
    return intersection / union if union else 0.0


def make_comparison(sheets: dict[str, Image.Image], cheolbyeok: Image.Image) -> Path:
    entries = (
        ("SEOKJANG", sheets["swing_seokjang"], 96),
        ("GHOST STAFF", sheets["swing_ghost_staff"], 96),
        ("SWORD", Image.open(OUT / "swing_sword.png").convert("RGBA"), 96),
        ("TWIN", Image.open(OUT / "swing_twin_sword.png").convert("RGBA"), 96),
        ("SHARP", Image.open(OUT / "swing_sharp_sword.png").convert("RGBA"), 96),
        ("GHOST SWORD", Image.open(OUT / "swing_ghost_sword.png").convert("RGBA"), 96),
        ("FLAME SWORD", Image.open(OUT / "swing_flame_sword.png").convert("RGBA"), 96),
        ("CHAMGYEOK", sheets["skill_chamgyeok"], 150),
    )
    cell_width = 164
    top_height = 180
    image = Image.new("RGB", (cell_width * len(entries), 340), (12, 15, 18))
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()
    for index, (label, sheet, display_px) in enumerate(entries):
        frame = peak_frame(sheet).resize((display_px, display_px), Image.Resampling.NEAREST)
        x = index * cell_width + (cell_width - display_px) // 2
        y = 6 + (150 - display_px) // 2
        image.paste(frame, (x, y), frame)
        visible_colors = len({pixel for pixel in frame.get_flattened_data() if pixel[3] > 0})
        draw.text((index * cell_width + 8, 160), f"{label} {display_px}px/{visible_colors}c", fill=(196, 202, 202), font=font)
        if index:
            draw.line((index * cell_width, 4, index * cell_width, top_height - 5), fill=(37, 42, 45))

    cheol_colors = len({pixel for pixel in cheolbyeok.get_flattened_data() if pixel[3] > 0})
    draw.text((12, 190), f"CHEOLBYEOK: 6 FRAMES AT 96PX, FIXED OCTAGON, {cheol_colors}c", fill=(196, 202, 202), font=font)
    for index, frame in enumerate(split_frames(cheolbyeok)):
        display = frame.resize((96, 96), Image.Resampling.NEAREST)
        x = 34 + index * 132
        image.paste(display, (x, 216), display)
    path = OUT / "weapon-effect-comparison.png"
    image.save(path, optimize=True)
    return path


def validate(sheets: dict[str, Image.Image]) -> None:
    expected = {
        "swing_seokjang": (1024, 128),
        "swing_ghost_staff": (1024, 128),
        "skill_chamgyeok": (1200, 150),
        "skill_cheolbyeok": (576, 96),
    }
    for name, sheet in sheets.items():
        if sheet.size != expected[name]:
            raise ValueError(f"{name} is {sheet.size}, expected {expected[name]}")
        if set(sheet.getchannel("A").get_flattened_data()) - {0, 255}:
            raise ValueError(f"{name} contains partial alpha")
        colors = Counter(sheet.get_flattened_data())
        if len(colors) > 64:
            raise ValueError(f"{name} uses {len(colors)} RGBA colors")
        visible_colors = {color for color in colors if color[3] > 0}
        if name in SKILL_SPECS and len(visible_colors) < 12:
            raise ValueError(f"{name} uses only {len(visible_colors)} visible colors")
        if any(frame.getchannel("A").getbbox() is None for frame in split_frames(sheet)):
            raise ValueError(f"{name} has an empty animation frame")
        if name in SKILL_SPECS:
            spec = SKILL_SPECS[name]
            grid = int(spec["grid"])
            frame_count = int(spec["frames"])
            logical_px = int(spec["logical_px"])
            if sheet.height != logical_px:
                raise ValueError(f"{name} cell {sheet.height}px does not match logical_px {logical_px}")
            logical = sheet.resize((grid * frame_count, grid), Image.Resampling.NEAREST)
            restored = logical.resize(sheet.size, Image.Resampling.NEAREST)
            different = sum(
                left != right
                for left, right in zip(sheet.get_flattened_data(), restored.get_flattened_data())
            )
            percent = different / float(sheet.width * sheet.height) * 100.0
            if different:
                raise ValueError(f"{name} logical-grid roundtrip differs by {different} px ({percent:.4f}%)")

    sword_names = ("swing_sword.png", "swing_twin_sword.png", "swing_sharp_sword.png", "swing_ghost_sword.png", "swing_flame_sword.png")
    sword_peaks = [peak_frame(Image.open(OUT / name).convert("RGBA")) for name in sword_names]
    staff_peaks = [peak_frame(sheets["swing_seokjang"]), peak_frame(sheets["swing_ghost_staff"])]
    for staff in staff_peaks:
        staff_overlap = max(silhouette_iou(staff, sword) for sword in sword_peaks)
        if staff_overlap >= 0.45:
            raise ValueError(f"a blunt staff silhouette overlaps a sword swing too closely: {staff_overlap:.4f}")
    chamgyeok_peak = peak_frame(sheets["skill_chamgyeok"])
    weapon_names = sword_names + ("swing_seokjang.png", "swing_ghost_staff.png")
    overlaps = [silhouette_iou(chamgyeok_peak, weapon) for weapon in sword_peaks + staff_peaks]
    chamgyeok_overlap = max(overlaps)
    if chamgyeok_overlap >= 0.45:
        overlap_name = weapon_names[overlaps.index(chamgyeok_overlap)]
        raise ValueError(f"chamgyeok silhouette overlaps {overlap_name} too closely: {chamgyeok_overlap:.4f}")


def main() -> None:
    sheets = {
        "swing_seokjang": save_sheet("swing_seokjang", staff_frames(False)),
        "swing_ghost_staff": save_sheet("swing_ghost_staff", staff_frames(True)),
        "skill_chamgyeok": save_sheet("skill_chamgyeok", chamgyeok_frames()),
        "skill_cheolbyeok": save_sheet("skill_cheolbyeok", cheolbyeok_frames()),
    }
    validate(sheets)
    comparison_path = make_comparison(sheets, sheets["skill_cheolbyeok"])
    sword_peaks = [
        peak_frame(Image.open(OUT / name).convert("RGBA"))
        for name in ("swing_sword.png", "swing_twin_sword.png", "swing_sharp_sword.png", "swing_ghost_sword.png", "swing_flame_sword.png")
    ]
    staff_peaks = [peak_frame(sheets["swing_seokjang"]), peak_frame(sheets["swing_ghost_staff"])]
    for name, sheet in sheets.items():
        detail = ""
        visible_colors = len({color for color in sheet.get_flattened_data() if color[3] > 0})
        if name in SKILL_SPECS:
            spec = SKILL_SPECS[name]
            grid = int(spec["grid"])
            frame_count = int(spec["frames"])
            logical = sheet.resize((grid * frame_count, grid), Image.Resampling.NEAREST)
            restored = logical.resize(sheet.size, Image.Resampling.NEAREST)
            different = sum(left != right for left, right in zip(sheet.get_flattened_data(), restored.get_flattened_data()))
            detail = f", {grid}x{grid} x2 roundtrip {different} px ({different / float(sheet.width * sheet.height) * 100.0:.6f}%)"
        print(f"{name}: {sheet.width}x{sheet.height}, {visible_colors} visible colors, binary alpha{detail}")
    print("staff/sword peak silhouette max IoU: %.4f" % max(silhouette_iou(staff, sword) for staff in staff_peaks for sword in sword_peaks))
    print("chamgyeok/weapon peak silhouette max IoU: %.4f" % max(silhouette_iou(peak_frame(sheets["skill_chamgyeok"]), weapon) for weapon in sword_peaks + staff_peaks))
    print(f"comparison: {comparison_path.as_posix()}")


if __name__ == "__main__":
    main()
