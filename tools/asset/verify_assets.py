"""Verify the authored M1 asset contract without importing Godot."""
from pathlib import Path
import json
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
    if any(
        pixel[3]
        and pixel[0] > 120
        and pixel[2] > 120
        and pixel[1] < 110
        and abs(pixel[0] - pixel[2]) < 85
        and min(pixel[0], pixel[2]) - pixel[1] > 55
        for pixel in sprite.get_flattened_data()
    ):
        fail(f"{path}: opaque chroma-magenta range survived cutout")


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


def check_backdrop(path):
    backdrop = image(path)
    if backdrop.size != (540, 960):
        fail(f"{path}: expected 540x960, got {backdrop.size}")
    if any(pixel[3] != 255 for pixel in backdrop.get_flattened_data()):
        fail(f"{path}: expected a fully opaque backdrop")
    colours = {pixel[:3] for pixel in backdrop.get_flattened_data()}
    if len(colours) > 64:
        fail(f"{path}: expected <=64 colours, got {len(colours)}")


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

    directions = ("south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west")
    for character in ("Warrior", "Archer"):
        for direction in directions:
            check_sprite(f"asset/character/{character}/Idle/rotations/{direction}.png", (92, 92), 46)
        metadata = json.loads((ROOT / f"asset/character/{character}/metadata.json").read_text(encoding="utf-8"))
        expected_rotations = {
            direction: f"Idle/rotations/{direction}.png"
            for direction in directions
        }
        if metadata.get("frames", {}).get("rotations") != expected_rotations:
            fail(f"asset/character/{character}/metadata.json: incomplete rotation map")
    monster_heights = {
        "forest_goblin": 44,
        "forest_spirit": 46,
        "bamboo_brute": 58,
        "bamboo_spirit_lord": 76,
    }
    for monster_id, height in monster_heights.items():
        for direction in directions:
            check_sprite(f"asset/monster/{monster_id}/rotations/{direction}.png", (92, 92), height)
    check_tile("asset/stage/bamboo_forest_ground.png")
    check_tile("asset/stage/abandoned_temple_ground.png")
    for name in ("main_menu", "bamboo_forest", "abandoned_temple"):
        check_backdrop(f"asset/stage/backdrops/{name}.png")
    prop_names = (
        "wooden_crate", "small_box", "broken_crate", "storage_chest",
        "bamboo_cluster", "fallen_log", "mossy_rock", "stone_lantern",
        "temple_urn", "offering_table", "prayer_post", "brazier",
    )
    for name in prop_names:
        check_sprite(f"asset/prop/{name}.png", (64, 64), 48)

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

    retry_sheet = image("asset/character/Taoist/raw/taoist_motion_sheet_higgsfield.png")
    if retry_sheet.size != (1200, 896):
        fail(f"single-sheet retry: expected 1200x896 raw sheet, got {retry_sheet.size}")
    retry_names = ("idle_0", "idle_1", "walk_0", "walk_1", "walk_2", "walk_3", "attack_0", "attack_1", "attack_2", "attack_3")
    for name in retry_names:
        check_sprite(f"asset/character/Taoist/raw/motion_cut/{name}.png", (92, 92), 46)
    metrics = json.loads((ROOT / "asset/character/Taoist/raw/motion_metrics.json").read_text(encoding="utf-8"))
    retry_idle = metrics["consecutive_transitions"]["idle_0->idle_1"]["changed_pixels"]
    baseline = metrics["separate_render_baseline"]["changed_pixels"]
    if retry_idle != 510 or baseline != 449:
        fail(f"single-sheet metrics changed unexpectedly: idle={retry_idle}, baseline={baseline}")

    conditioned_dir = "asset/character/Taoist/raw/conditioned_south"
    for name in ("walk_0", "walk_1"):
        check_sprite(f"{conditioned_dir}/{name}_cut.png", (92, 92), 46)
    conditioned = json.loads((ROOT / conditioned_dir / "metrics.json").read_text(encoding="utf-8"))
    conditioned_changed = [
        conditioned["frames"][f"walk_{index}_cut"]["changed_pixels"]
        for index in range(2)
    ]
    conditioned_accepted = [
        conditioned["frames"][f"walk_{index}_cut"]["accepted"]
        for index in range(2)
    ]
    if conditioned_changed != [1005, 987] or any(conditioned_accepted):
        fail(
            "conditioned retry metrics changed unexpectedly: "
            f"changed={conditioned_changed}, accepted={conditioned_accepted}"
        )

    current_motion_metrics = (
        "asset/character/Taoist/raw/walk_conditioned_metrics.json",
        "asset/character/Taoist/raw/attack_conditioned_metrics.json",
        "asset/character/Warrior/raw/walk_motion_metrics.json",
        "asset/character/Warrior/raw/attack_motion_metrics.json",
        "asset/character/Archer/raw/walk_motion_metrics.json",
        "asset/character/Archer/raw/attack_motion_metrics.json",
    )
    accepted_current = 0
    measured_current = 0
    for metrics_path in current_motion_metrics:
        sheet_metrics = json.loads((ROOT / metrics_path).read_text(encoding="utf-8"))
        summary = sheet_metrics["summary"]
        accepted_current += summary["accepted_frames"]
        measured_current += summary["frames"]
        if summary["sheet_accepted"]:
            fail(f"{metrics_path}: unstable generated sheet unexpectedly marked accepted")
    if accepted_current != 0 or measured_current != 96:
        fail(f"current sheet metrics changed unexpectedly: accepted={accepted_current}, measured={measured_current}")

    if ERRORS:
        raise SystemExit("\n".join(ERRORS))
    print("M1 assets verified: 20 UI icons + 4 chrome assets, 14 weapon assets, 2 characters, 2 seamless tiles, 6 audio files")
    print(f"Motion-generation rejection evidence: {changed}/1702 pixels changed between same-pose frames")
    print(f"Single-sheet retry rejected: idle pair {retry_idle}/1702 versus separate baseline {baseline}/1702")
    print(f"Direct-conditioned retry rejected: south walk frames {conditioned_changed[0]}/1702 and {conditioned_changed[1]}/1702")
    print("Directional additions verified: 14 class rotations + 32 monster rotations, 3 backdrops, 12 props")
    print(f"Six multi-reference motion sheets rejected: {accepted_current}/{measured_current} frames passed the regional stability gate")


if __name__ == "__main__":
    main()
