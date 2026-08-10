"""Verify the authored M1 asset contract without importing Godot."""
from pathlib import Path
import math
import struct
import wave

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
ERRORS = []


def fail(message):
    ERRORS.append(message)


def image(path):
    return Image.open(ROOT / path).convert("RGBA")


def check_sprite(path, canvas=None, content_height=None):
    sprite = image(path)
    if canvas and sprite.size != canvas:
        fail(f"{path}: expected canvas {canvas}, got {sprite.size}")
    bbox = sprite.getbbox()
    if bbox is None:
        fail(f"{path}: empty sprite")
        return
    if content_height and bbox[3] - bbox[1] != content_height:
        fail(f"{path}: expected content height {content_height}, got {bbox[3]-bbox[1]}")
    alphas = {pixel[3] for pixel in sprite.get_flattened_data()}
    if not alphas <= {0, 255}:
        fail(f"{path}: soft alpha values {sorted(alphas - {0, 255})[:8]}")
    if any(pixel[:3] == (255, 0, 255) and pixel[3] for pixel in sprite.get_flattened_data()):
        fail(f"{path}: opaque chroma magenta survived cutout")


def check_tile(path):
    tile = image(path)
    if tile.size != (256, 256):
        fail(f"{path}: expected 256x256, got {tile.size}")
    if list(tile.crop((0, 0, 1, 256)).get_flattened_data()) != list(tile.crop((255, 0, 256, 256)).get_flattened_data()):
        fail(f"{path}: left/right edges differ")
    if list(tile.crop((0, 0, 256, 1)).get_flattened_data()) != list(tile.crop((0, 255, 256, 256)).get_flattened_data()):
        fail(f"{path}: top/bottom edges differ")
    opaque_colours = {pixel[:3] for pixel in tile.get_flattened_data() if pixel[3]}
    if len(opaque_colours) > 32:
        fail(f"{path}: expected <=32 colours, got {len(opaque_colours)}")


def check_audio(path, expected_duration):
    with wave.open(str(ROOT / path), "rb") as stream:
        if stream.getnchannels() != 1 or stream.getsampwidth() != 2 or stream.getframerate() != 22050:
            fail(f"{path}: expected mono 16-bit 22050 Hz PCM")
        frames = stream.readframes(stream.getnframes())
        values = struct.unpack(f"<{len(frames)//2}h", frames)
        duration = len(values) / stream.getframerate()
        if abs(duration - expected_duration) > 0.02:
            fail(f"{path}: expected {expected_duration:.2f}s, got {duration:.3f}s")
        peak = max(abs(value) for value in values) / 32767
        dbfs = 20 * math.log10(max(peak, 1e-9))
        if dbfs > -2.95:
            fail(f"{path}: peak {dbfs:.2f} dBFS exceeds -3 dBFS")


def main():
    passive_ids = ("attack_damage", "attack_speed", "move_speed", "crit_chance", "max_hp", "xp_gain", "luck", "skill_power")
    achievement_ids = ("first_boss", "boss_slayer", "goblin_hunter", "monster_collector", "survivor", "veteran_survivor", "rising_star", "weapon_master")
    weapon_ids = ("old_talisman", "fire_talisman", "phoenix_talisman", "sword", "twin_sword", "bow", "divine_bow")

    for name in passive_ids:
        check_sprite(f"asset/ui/passive/{name}.png", (32, 32))
    for name in achievement_ids:
        check_sprite(f"asset/ui/achievement/{name}.png", (32, 32))
    for name in ("gold", "xp"):
        check_sprite(f"asset/ui/currency/{name}.png", (32, 32))
    for name in ("lock", "check"):
        check_sprite(f"asset/ui/state/{name}.png", (32, 32))
    check_sprite("asset/ui/chrome/panel_9slice.png", (48, 48))
    for state in ("normal", "hover", "pressed"):
        check_sprite(f"asset/ui/chrome/button_{state}_9slice.png", (64, 32))
    for name in weapon_ids:
        check_sprite(f"asset/weapon/icons/{name}.png", (32, 32))
        check_sprite(f"asset/weapon/projectiles/{name}.png")

    check_sprite("asset/character/Warrior/Idle/rotations/south.png", (92, 92), 46)
    check_sprite("asset/character/Archer/Idle/rotations/south.png", (92, 92), 46)
    check_tile("asset/stage/bamboo_forest_ground.png")
    check_tile("asset/stage/abandoned_temple_ground.png")

    audio = {
        "asset/audio/ambience/bamboo_forest_loop.wav": 12.0,
        "asset/audio/sfx/combat_hit.wav": 0.12,
        "asset/audio/sfx/enemy_death.wav": 0.34,
        "asset/audio/sfx/level_up.wav": 0.72,
        "asset/audio/sfx/boss_spawn.wav": 1.50,
        "asset/audio/sfx/ui_click.wav": 0.07,
    }
    for path, duration in audio.items():
        check_audio(path, duration)

    first = image("asset/character/raw/motion_test/frame_a_cut.png")
    second = image("asset/character/raw/motion_test/frame_b_cut.png")
    changed = sum(pixel != (0, 0, 0, 0) for pixel in ImageChops.difference(first, second).get_flattened_data())
    if changed < 100:
        fail(f"motion test unexpectedly consistent: only {changed} changed pixels")

    if ERRORS:
        raise SystemExit("\n".join(ERRORS))
    print("M1 assets verified: 20 UI icons + 4 chrome assets, 14 weapon assets, 2 characters, 2 seamless tiles, 6 audio files")
    print(f"Motion-generation rejection evidence: {changed}/1702 pixels changed between same-pose frames")


if __name__ == "__main__":
    main()
