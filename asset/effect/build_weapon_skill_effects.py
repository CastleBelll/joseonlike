from __future__ import annotations

import math
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "asset" / "effect"
FRAME = 128
LOGICAL_EFFECT_FRAME = 64

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


def save_sheet(name: str, frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", (FRAME * len(frames), FRAME))
    for index, frame in enumerate(frames):
        if name.startswith("skill_"):
            # Warrior actives are authored on the 64px gameplay grid, then
            # enlarged exactly x2. This intentionally discards sub-grid detail.
            logical = frame.resize(
                (LOGICAL_EFFECT_FRAME, LOGICAL_EFFECT_FRAME), Image.Resampling.NEAREST
            )
            frame = logical.resize((FRAME, FRAME), Image.Resampling.NEAREST)
        sheet.alpha_composite(frame, (index * FRAME, 0))
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


def chamgyeok_frames() -> list[Image.Image]:
    frames: list[Image.Image] = []
    for frame in range(8):
        image, draw = canvas()
        if frame == 0:
            outlined_line(draw, [(28, 90), (62, 22)], CREAM, 3)
            star(draw, (64, 18), 10, CRIMSON_HI)
        elif frame == 1:
            outlined_line(draw, [(25, 91), (88, 24)], CRIMSON_HI, 7)
            star(draw, (91, 21), 8, CREAM)
        elif 2 <= frame <= 4:
            end_angles = (-5, 32, 65)
            end_angle = end_angles[frame - 2]
            outer = elliptical_sector((20, 64), (103, 57), (18, 10), -65, end_angle)
            draw.polygon(outer, fill=INK)
            inner_fill = elliptical_sector((20, 64), (100, 54), (22, 12), -63, end_angle - 2)
            draw.polygon(inner_fill, fill=CRIMSON_DARK)
            bright_band = elliptical_sector((20, 64), (97, 51), (70, 37), -61, end_angle - 4)
            draw.polygon(bright_band, fill=CRIMSON)
            draw.line(elliptical_sector((20, 64), (95, 49), (95, 49), -59, end_angle - 5)[: max(2, (end_angle + 59) // 3)], fill=CRIMSON_HI, width=2)
            star(draw, (23, 64), 5 + frame, CREAM if frame == 3 else CRIMSON_HI)
        else:
            fragments = (
                ((72, 18), (103, 30), (98, 35), (68, 24)),
                ((91, 54), (124, 62), (121, 68), (88, 61)),
                ((76, 94), (108, 105), (104, 111), (72, 101)),
                ((42, 112), (64, 119), (59, 123), (38, 117)),
            )
            keep = max(1, 8 - frame)
            for index, fragment in enumerate(fragments[:keep]):
                shifted = tuple((x + (frame - 5) * (index + 1) * 2, y) for x, y in fragment)
                draw.polygon(shifted, fill=INK)
                inset = tuple((x - 1 if x > 64 else x + 1, y) for x, y in shifted)
                draw.polygon(inset, fill=CRIMSON if frame == 5 else CRIMSON_DARK)
            for index in range(8 - frame):
                x = 56 + index * 10 + (frame - 5) * 6
                y = 30 + (index * 17) % 72
                draw.rectangle((x, y, x + 3, y + 2), fill=CRIMSON_HI if index % 3 == 0 else CRIMSON)
        frames.append(image)
    return frames


def octagon(center: tuple[int, int], radius_x: int, radius_y: int) -> list[tuple[int, int]]:
    cx, cy = center
    return [
        (cx - radius_x // 2, cy - radius_y), (cx + radius_x // 2, cy - radius_y),
        (cx + radius_x, cy - radius_y // 2), (cx + radius_x, cy + radius_y // 2),
        (cx + radius_x // 2, cy + radius_y), (cx - radius_x // 2, cy + radius_y),
        (cx - radius_x, cy + radius_y // 2), (cx - radius_x, cy - radius_y // 2),
    ]


def cheolbyeok_frames() -> list[Image.Image]:
    widths = (8, 17, 27, 36, 42, 42)
    heights = (5, 11, 18, 25, 29, 29)
    centers_y = (96, 91, 86, 81, 77, 77)
    frames: list[Image.Image] = []
    for frame in range(6):
        image, draw = canvas()
        center = (64, centers_y[frame])
        rx, ry = widths[frame], heights[frame]
        draw.polygon(octagon(center, rx + 3, ry + 3), fill=INK)
        draw.polygon(octagon(center, rx + 1, ry + 1), fill=STEEL_DARK)
        draw.polygon(octagon(center, max(1, rx - 5), max(1, ry - 4)), fill=STEEL if frame < 5 else STEEL_HI)
        if frame >= 2:
            inner = octagon(center, max(1, rx - 11), max(1, ry - 9))
            draw.polygon(inner, fill=INK)
            inner_cut = octagon(center, max(1, rx - 14), max(1, ry - 12))
            draw.polygon(inner_cut, fill=(0, 0, 0, 0))
            plate_color = CRIMSON if frame < 5 else CRIMSON_HI
            draw.rectangle((61, center[1] - ry - 1, 67, center[1] - ry + 3), fill=plate_color)
            draw.rectangle((61, center[1] + ry - 3, 67, center[1] + ry + 1), fill=plate_color)
            draw.rectangle((center[0] - rx - 1, center[1] - 2, center[0] - rx + 3, center[1] + 2), fill=plate_color)
            draw.rectangle((center[0] + rx - 3, center[1] - 2, center[0] + rx + 1, center[1] + 2), fill=plate_color)
        spark_count = min(5, frame + 1)
        for index in range(spark_count):
            x = 39 + index * 13 + (frame % 2) * 3
            y = 66 - ((index * 11 + frame * 7) % 34)
            star(draw, (x, y), 2 + (1 if frame >= 4 and index % 2 == 0 else 0), CRIMSON_HI)
        if frame == 5:
            draw.line(octagon(center, rx - 1, ry - 1) + [octagon(center, rx - 1, ry - 1)[0]], fill=STEEL_HI, width=2)
        frames.append(image)
    return frames


def split_frames(sheet: Image.Image) -> list[Image.Image]:
    return [sheet.crop((index * FRAME, 0, (index + 1) * FRAME, FRAME)) for index in range(sheet.width // FRAME)]


def peak_frame(sheet: Image.Image) -> Image.Image:
    frames = split_frames(sheet)
    return max(frames, key=lambda frame: sum(1 for alpha in frame.getchannel("A").get_flattened_data() if alpha))


def silhouette_iou(left: Image.Image, right: Image.Image) -> float:
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
        draw.text((index * cell_width + 8, 160), label, fill=(196, 202, 202), font=font)
        if index:
            draw.line((index * cell_width, 4, index * cell_width, top_height - 5), fill=(37, 42, 45))

    draw.text((12, 190), "CHEOLBYEOK: 6 FRAMES AT 96PX, FIXED OCTAGON", fill=(196, 202, 202), font=font)
    for index, frame in enumerate(split_frames(cheolbyeok)):
        display = frame.resize((96, 96), Image.Resampling.NEAREST)
        x = 34 + index * 132
        image.paste(display, (x, 216), display)
    comparison = image.quantize(colors=32, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    path = OUT / "weapon-effect-comparison.png"
    comparison.save(path, optimize=True)
    return path


def validate(sheets: dict[str, Image.Image]) -> None:
    expected = {
        "swing_seokjang": (1024, 128),
        "swing_ghost_staff": (1024, 128),
        "skill_chamgyeok": (1024, 128),
        "skill_cheolbyeok": (768, 128),
    }
    for name, sheet in sheets.items():
        if sheet.size != expected[name]:
            raise ValueError(f"{name} is {sheet.size}, expected {expected[name]}")
        if set(sheet.getchannel("A").get_flattened_data()) - {0, 255}:
            raise ValueError(f"{name} contains partial alpha")
        colors = Counter(sheet.get_flattened_data())
        if len(colors) > 64:
            raise ValueError(f"{name} uses {len(colors)} RGBA colors")
        if any(frame.getchannel("A").getbbox() is None for frame in split_frames(sheet)):
            raise ValueError(f"{name} has an empty animation frame")
        if name.startswith("skill_"):
            logical = sheet.resize(
                (sheet.width // 2, sheet.height // 2), Image.Resampling.NEAREST
            )
            restored = logical.resize(sheet.size, Image.Resampling.NEAREST)
            different = sum(
                left != right
                for left, right in zip(sheet.get_flattened_data(), restored.get_flattened_data())
            )
            percent = different / float(sheet.width * sheet.height) * 100.0
            if percent >= 2.0:
                raise ValueError(f"{name} logical-grid roundtrip differs by {percent:.4f}%")

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
        if name.startswith("skill_"):
            logical = sheet.resize((sheet.width // 2, sheet.height // 2), Image.Resampling.NEAREST)
            restored = logical.resize(sheet.size, Image.Resampling.NEAREST)
            different = sum(left != right for left, right in zip(sheet.get_flattened_data(), restored.get_flattened_data()))
            detail = f", 64x64 x2 roundtrip {different} px ({different / float(sheet.width * sheet.height) * 100.0:.6f}%)"
        print(f"{name}: {sheet.width}x{sheet.height}, {len(set(sheet.get_flattened_data()))} RGBA colors, binary alpha{detail}")
    print("staff/sword peak silhouette max IoU: %.4f" % max(silhouette_iou(staff, sword) for staff in staff_peaks for sword in sword_peaks))
    print("chamgyeok/weapon peak silhouette max IoU: %.4f" % max(silhouette_iou(peak_frame(sheets["skill_chamgyeok"]), weapon) for weapon in sword_peaks + staff_peaks))
    print(f"comparison: {comparison_path.as_posix()}")


if __name__ == "__main__":
    main()
