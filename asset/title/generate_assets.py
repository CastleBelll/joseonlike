#!/usr/bin/env python3
"""Generate title screen assets programmatically."""

from PIL import Image, ImageDraw
import os

# Output dimensions (logical size 540x960, export at 2x)
WIDTH = 1080
HEIGHT = 1920
LOGICAL_W = 540
LOGICAL_H = 960

# DESIGN.md palette tokens (adjusted for night theme)
NIGHT = (22, 17, 13)
NIGHT_BROWN = (36, 26, 18)
GOLD = (255, 217, 74)
WOOD = (226, 160, 87)
VERMILION = (191, 64, 42)
SKY_DARK = (20, 15, 40)
SKY_MID = (40, 35, 70)
SKY_LIGHT = (60, 50, 100)

def create_sky() -> Image.Image:
    """Create night sky with moon and stars."""
    img = Image.new('RGB', (WIDTH, HEIGHT), SKY_DARK)
    draw = ImageDraw.Draw(img)

    # Gradient effect: darker at top, lighter at bottom (simulated with bands)
    for y in range(0, HEIGHT, 40):
        alpha = y / HEIGHT
        r = int(SKY_DARK[0] + (SKY_MID[0] - SKY_DARK[0]) * alpha)
        g = int(SKY_DARK[1] + (SKY_MID[1] - SKY_DARK[1]) * alpha)
        b = int(SKY_DARK[2] + (SKY_MID[2] - SKY_DARK[2]) * alpha)
        draw.rectangle([(0, y), (WIDTH, y + 40)], fill=(r, g, b))

    # Moon (large, center-right, with crater details)
    moon_x, moon_y = WIDTH * 0.65, HEIGHT * 0.35
    moon_radius = 120
    # Moon body
    draw.ellipse(
        [(moon_x - moon_radius, moon_y - moon_radius),
         (moon_x + moon_radius, moon_y + moon_radius)],
        fill=(240, 235, 210)
    )
    # Craters (small dark spots)
    crater_positions = [
        (moon_x - 60, moon_y - 40, 20),
        (moon_x + 50, moon_y - 60, 15),
        (moon_x - 30, moon_y + 70, 25),
    ]
    for cx, cy, cr in crater_positions:
        draw.ellipse([(cx - cr, cy - cr), (cx + cr, cy + cr)], fill=(200, 195, 170))

    # Stars (multiple small points)
    import random
    random.seed(42)  # Reproducible
    for _ in range(80):
        sx = random.randint(0, WIDTH)
        sy = random.randint(0, int(HEIGHT * 0.6))  # Upper half only
        size = random.randint(2, 8)
        draw.ellipse([(sx, sy), (sx + size, sy + size)], fill=(180, 170, 200))

    return img

def create_village() -> Image.Image:
    """Create village silhouette with buildings and lights."""
    img = Image.new('RGB', (WIDTH, HEIGHT), (200, 190, 160))  # Light background for compositing
    draw = ImageDraw.Draw(img)

    # Ground layer (lighter)
    draw.rectangle([(0, int(HEIGHT * 0.6)), (WIDTH, HEIGHT)], fill=(120, 100, 80))

    # Buildings (simplified Korean traditional architecture)
    # Left building
    build_left_x, build_left_y = 80, int(HEIGHT * 0.55)
    build_width, build_height = 280, 400
    # Building body
    draw.rectangle([
        (build_left_x, build_left_y),
        (build_left_x + build_width, build_left_y + build_height)
    ], fill=(100, 60, 30))
    # Roof (triangular, simplified)
    roof_peak = build_left_y - 80
    draw.polygon([
        (build_left_x - 40, build_left_y),
        (build_left_x + build_width + 40, build_left_y),
        (build_left_x + build_width // 2, roof_peak)
    ], fill=(40, 30, 20))

    # Windows with warm light
    for wx in range(build_left_x + 40, build_left_x + build_width - 40, 80):
        for wy in range(build_left_y + 40, build_left_y + build_height - 60, 100):
            draw.rectangle([(wx, wy), (wx + 40, wy + 40)], fill=(255, 200, 100))

    # Center building (larger)
    build_center_x, build_center_y = 320, int(HEIGHT * 0.45)
    build_center_w, build_center_h = 440, 500
    draw.rectangle([
        (build_center_x, build_center_y),
        (build_center_x + build_center_w, build_center_y + build_center_h)
    ], fill=(110, 70, 35))
    # Roof
    roof_peak_c = build_center_y - 100
    draw.polygon([
        (build_center_x - 60, build_center_y),
        (build_center_x + build_center_w + 60, build_center_y),
        (build_center_x + build_center_w // 2, roof_peak_c)
    ], fill=(45, 35, 20))

    # Windows
    for wx in range(build_center_x + 60, build_center_x + build_center_w - 60, 100):
        for wy in range(build_center_y + 60, build_center_y + build_center_h - 80, 120):
            draw.rectangle([(wx, wy), (wx + 50, wy + 50)], fill=(255, 210, 120))

    # Right building (smaller)
    build_right_x, build_right_y = 760, int(HEIGHT * 0.60)
    build_right_w, build_right_h = 240, 380
    draw.rectangle([
        (build_right_x, build_right_y),
        (build_right_x + build_right_w, build_right_y + build_right_h)
    ], fill=(105, 65, 32))
    # Roof
    roof_peak_r = build_right_y - 70
    draw.polygon([
        (build_right_x - 30, build_right_y),
        (build_right_x + build_right_w + 30, build_right_y),
        (build_right_x + build_right_w // 2, roof_peak_r)
    ], fill=(42, 32, 18))

    # Windows
    for wx in range(build_right_x + 30, build_right_x + build_right_w - 30, 80):
        for wy in range(build_right_y + 40, build_right_y + build_right_h - 60, 100):
            draw.rectangle([(wx, wy), (wx + 40, wy + 40)], fill=(255, 200, 100))

    # Stone path (bottom)
    for px in range(0, WIDTH, 60):
        for py in range(int(HEIGHT * 0.75), HEIGHT, 60):
            draw.rectangle([(px + 10, py + 10), (px + 50, py + 50)], outline=(80, 70, 60), width=4)

    return img

def create_logo_ko() -> Image.Image:
    """Create Korean title logo with lanterns and seal."""
    img = Image.new('RGBA', (840, 400), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Signboard background (木製, brown)
    signboard_x, signboard_y = 50, 50
    signboard_w, signboard_h = 740, 300
    draw.rectangle([
        (signboard_x, signboard_y),
        (signboard_x + signboard_w, signboard_y + signboard_h)
    ], fill=(80, 50, 20, 255))

    # Signboard border (gold)
    draw.rectangle([
        (signboard_x, signboard_y),
        (signboard_x + signboard_w, signboard_y + signboard_h)
    ], outline=(255, 217, 74, 255), width=12)

    # Roof (curved, dark)
    roof_y = signboard_y - 40
    draw.polygon([
        (signboard_x - 20, signboard_y),
        (signboard_x + signboard_w + 20, signboard_y),
        (signboard_x + signboard_w // 2, roof_y)
    ], fill=(30, 20, 10, 255))

    # Left lantern (紅/orange)
    lantern_left_x = signboard_x - 80
    lantern_left_y = signboard_y + 80
    draw.rectangle([
        (lantern_left_x - 40, lantern_left_y),
        (lantern_left_x + 40, lantern_left_y + 120)
    ], fill=(255, 140, 60, 255))
    # Top cap
    draw.rectangle([
        (lantern_left_x - 50, lantern_left_y - 20),
        (lantern_left_x + 50, lantern_left_y)
    ], fill=(40, 30, 20, 255))
    # Bottom cap
    draw.rectangle([
        (lantern_left_x - 50, lantern_left_y + 120),
        (lantern_left_x + 50, lantern_left_y + 140)
    ], fill=(40, 30, 20, 255))

    # Right lantern (mirrored)
    lantern_right_x = signboard_x + signboard_w + 80
    draw.rectangle([
        (lantern_right_x - 40, lantern_left_y),
        (lantern_right_x + 40, lantern_left_y + 120)
    ], fill=(255, 140, 60, 255))
    draw.rectangle([
        (lantern_right_x - 50, lantern_left_y - 20),
        (lantern_right_x + 50, lantern_left_y)
    ], fill=(40, 30, 20, 255))
    draw.rectangle([
        (lantern_right_x - 50, lantern_left_y + 120),
        (lantern_right_x + 50, lantern_left_y + 140)
    ], fill=(40, 30, 20, 255))

    # Text area (placeholder for Korean text "조선라이크")
    text_area_x = signboard_x + 80
    text_area_y = signboard_y + 80
    text_area_w = signboard_w - 160
    text_area_h = 140
    draw.rectangle([
        (text_area_x, text_area_y),
        (text_area_x + text_area_w, text_area_y + text_area_h)
    ], fill=(255, 217, 74, 200))

    # Seal stamp (우하단, red/vermilion)
    seal_x = signboard_x + signboard_w - 80
    seal_y = signboard_y + signboard_h - 60
    draw.rectangle([
        (seal_x - 40, seal_y),
        (seal_x + 40, seal_y + 80)
    ], fill=(191, 64, 42, 255))
    # Border
    draw.rectangle([
        (seal_x - 40, seal_y),
        (seal_x + 40, seal_y + 80)
    ], outline=(0, 0, 0, 255), width=4)

    return img

def main():
    """Generate all assets."""
    os.makedirs('asset/title', exist_ok=True)

    print("Generating bg_sky.png...")
    sky = create_sky()
    sky.save('asset/title/bg_sky.png')
    print("  * Created 1080x1920 (logical 540x960)")

    print("Generating bg_village.png...")
    village = create_village()
    if village.mode == 'RGBA':
        village = village.convert('RGB')
    village.save('asset/title/bg_village.png')
    print("  * Created 1080x1920 (logical 540x960)")

    print("Generating logo_ko.png...")
    logo = create_logo_ko()
    logo_rgb = Image.new('RGB', logo.size, (255, 255, 255))
    logo_rgb.paste(logo, mask=logo.split()[3] if logo.mode == 'RGBA' else None)
    logo_rgb.save('asset/title/logo_ko.png')
    print("  * Created 840x400 (logical 420x200)")

    print("\n* All assets generated successfully!")

if __name__ == '__main__':
    main()
