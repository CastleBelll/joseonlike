"""Verify the authored M1 asset contract without importing Godot."""
from pathlib import Path
import hashlib
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


def check_rotation_facing_audit():
    """Require semantic review of the exact bytes in every rotation cell."""
    manifest_path = ROOT / "asset/rotation_audit/facing_audit.json"
    if not manifest_path.exists():
        fail("rotation facing audit manifest is missing")
        return
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    directions = (
        "south", "south-east", "east", "north-east",
        "north", "north-west", "west", "south-west",
    )
    expected_facing = {
        "south": "front", "south-east": "front", "east": "profile-east",
        "north-east": "back", "north": "back", "north-west": "back",
        "west": "profile-west", "south-west": "front",
    }
    expected_sets = {"Taoist", "Warrior", "Archer"} | {
        path.parent.name for path in ROOT.glob("asset/monster/*/rotations") if path.is_dir()
    }
    if manifest.get("direction_order") != list(directions):
        fail("rotation facing audit: direction order changed")
    if manifest.get("expected_facing") != expected_facing:
        fail("rotation facing audit: semantic direction labels changed")
    sets = manifest.get("sets", {})
    if set(sets) != expected_sets:
        fail(
            "rotation facing audit: expected exact set coverage "
            f"{sorted(expected_sets)}, got {sorted(sets)}"
        )
    for name in sorted(expected_sets & set(sets)):
        record = sets[name]
        if record.get("review") != "accepted_manual_contact_sheet":
            fail(f"rotation facing audit: {name} lacks manual approval")
        contact_sheet = ROOT / record.get("contact_sheet", "")
        if not contact_sheet.is_file():
            fail(f"rotation facing audit: {name} contact sheet is missing")
        elif hashlib.sha256(contact_sheet.read_bytes()).hexdigest() != record.get("contact_sheet_sha256"):
            fail(f"rotation facing audit: {name} contact sheet changed after visual review")
        cells = record.get("cells", {})
        if set(cells) != set(directions):
            fail(f"rotation facing audit: {name} does not cover all eight cells")
            continue
        rotation_root = ROOT / record.get("root", "")
        for direction in directions:
            cell = cells[direction]
            if cell.get("expected_facing") != expected_facing[direction]:
                fail(f"rotation facing audit: {name}/{direction} has wrong semantic label")
            path = rotation_root / f"{direction}.png"
            if not path.is_file():
                fail(f"rotation facing audit: missing {path.relative_to(ROOT)}")
                continue
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if digest != cell.get("sha256"):
                fail(
                    f"rotation facing audit: {name}/{direction} changed after visual review; "
                    "rebuild and inspect its contact sheet, then renew the manifest"
                )
        if record.get("exact_east_west_mirror_required"):
            east = image(f"{record['root']}/east.png")
            west = image(f"{record['root']}/west.png")
            if ImageChops.difference(east.transpose(Image.Transpose.FLIP_LEFT_RIGHT), west).getbbox():
                fail(f"rotation facing audit: {name} east/west are not opposite mirrored profiles")


def main():
    passive_ids = ("attack_damage", "attack_speed", "move_speed", "crit_chance", "max_hp", "xp_gain", "luck", "skill_power")
    achievement_ids = ("first_boss", "boss_slayer", "goblin_hunter", "monster_collector", "survivor", "veteran_survivor", "rising_star", "weapon_master")
    weapon_ids = (
        "old_talisman", "fire_talisman", "phoenix_talisman", "sword", "twin_sword", "bow", "divine_bow",
        "spear", "dragon_spear", "moon_dual_sword", "storm_dual_sword", "axe", "tiger_axe",
        "throwing_knife", "rain_of_knives", "poison_knife", "hundred_poison_blade",
    )

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
        projectile_canvas = (64, 64) if name in weapon_ids[7:] else None
        check_sprite(f"asset/weapon/projectiles/{name}.png", projectile_canvas)

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
    later_monster_heights = {
        "gwimyeon_dokkaebi": 54, "blue_dokkaebi": 50, "gumiho_scout": 48,
        "seonbi_wraith": 52, "haetae_guardian": 58, "dokkaebi_king": 76,
        "cheonyeo_gwisin": 52, "dalgyal_gwisin": 44, "jeoseung_saja": 58,
        "tomb_jangseung": 58, "imugi_whelp": 52, "ancient_imugi": 76,
        "wonhon": 50, "dokkaebi_fire": 44, "shadow_dokkaebi": 52,
        "fox_spirit": 48, "bulgasari": 58, "gumiho": 76,
    }
    for monster_id, height in later_monster_heights.items():
        check_sprite(f"asset/monster/{monster_id}.png", (92, 92), height)
        for direction in directions:
            check_sprite(f"asset/monster/{monster_id}/rotations/{direction}.png", (92, 92), height)
    check_rotation_facing_audit()

    death_sequences = {
        "Taoist": "asset/character/Taoist/Death",
        "Warrior": "asset/character/Warrior/Death",
        "Archer": "asset/character/Archer/Death",
        "forest_goblin": "asset/monster/forest_goblin/death",
        "forest_spirit": "asset/monster/forest_spirit/death",
        "bamboo_brute": "asset/monster/bamboo_brute/death",
        "bamboo_spirit_lord": "asset/monster/bamboo_spirit_lord/death",
    }
    for sequence_root in death_sequences.values():
        for frame in range(4):
            check_sprite(f"{sequence_root}/{frame}.png", (92, 92))
    death_metrics = json.loads((ROOT / "asset/character/raw/death_metrics.json").read_text(encoding="utf-8"))
    if set(death_metrics) != set(death_sequences):
        fail("death metrics do not cover the seven authored death sheets")
    for sequence in death_sequences:
        if not death_metrics.get(sequence, {}).get("accepted"):
            fail(f"{death_sequences[sequence]}: failed irreversible-collapse gate")
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

    effects = (
        "talisman_burst", "spirit_flame", "summon_circle", "fire", "lightning",
        "poison_cloud", "slash", "impact_hit", "level_up", "evolution_flourish",
        "ward_barrier", "spirit_beam", "seal_field",
    )
    for effect in effects:
        for frame in range(4):
            check_sprite(f"asset/effect/{effect}/{frame}.png", (64, 64))
    effect_metrics = json.loads((ROOT / "asset/effect/raw/effect_metrics.json").read_text(encoding="utf-8"))
    if set(effect_metrics) != set(effects):
        fail("effect metrics do not cover the thirteen authored effect sheets")
    for effect in effects:
        if not effect_metrics.get(effect, {}).get("accepted"):
            fail(f"asset/effect/{effect}: failed mobile-readability/progression gate")

    summons = {
        "paper_familiar": 46,
        "haetae_cub": 52,
        "three_legged_crow": 48,
        "turtle_serpent_guardian": 58,
    }
    for summon, height in summons.items():
        check_sprite(f"asset/summon/creatures/{summon}.png", (92, 92), height)

    structures = (
        "workshop", "archive", "training_ground", "camp_shrine", "jangseung_pair",
        "stone_lantern", "joseon_gate", "roadside_shrine", "stone_pagoda",
        "wooden_fence", "village_well", "ritual_altar",
    )
    for structure in structures:
        check_sprite(f"asset/structure/{structure}.png", (128, 128))
    for title in ("joseonlike_en", "joseonlike_ko", "title_frame_blank"):
        check_sprite(f"asset/title/{title}.png", (480, 96))

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
    print("M1 assets verified: 20 UI icons + 4 chrome assets, 34 weapon assets, 2 characters, 2 seamless tiles, 6 audio files")
    print(f"Motion-generation rejection evidence: {changed}/1702 pixels changed between same-pose frames")
    print(f"Single-sheet retry rejected: idle pair {retry_idle}/1702 versus separate baseline {baseline}/1702")
    print(f"Direct-conditioned retry rejected: south walk frames {conditioned_changed[0]}/1702 and {conditioned_changed[1]}/1702")
    print("Directional additions verified: 14 class rotations + 32 monster rotations, 3 backdrops, 12 props")
    print(f"Six multi-reference motion sheets rejected: {accepted_current}/{measured_current} frames passed the regional stability gate")
    print("Expansion assets verified: 18 folklore monsters + 144 rotations, 52 effect frames, 12 structures, 3 title assets")
    print("Round-two additions verified: 28 death frames, 4 summoned creatures, 20 weapon icons/projectiles")
    print("Directional-facing audit verified: 25/25 sets, 200 hash-bound cells manually reviewed")


if __name__ == "__main__":
    main()
