"""Verify the authored M1 asset contract without importing Godot."""
from pathlib import Path
import hashlib
import json
import math
import struct
import wave
from itertools import combinations

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
ERRORS = []
CHARACTER_ROTATION_DIRECTIONS = (
    "south", "south-east", "east", "north-east",
    "north", "north-west", "west", "south-west",
)
CHARACTER_NEAR_DUPLICATE_THRESHOLD = 2.5


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


def check_no_edge_grid_line(path):
    """Reject a retained sheet border without confusing long in-frame weapons for one."""
    sprite = image(path)
    alpha = sprite.getchannel("A")
    edge_counts = (
        sum(alpha.getpixel((x, 0)) > 0 for x in range(sprite.width)),
        sum(alpha.getpixel((x, sprite.height - 1)) > 0 for x in range(sprite.width)),
        sum(alpha.getpixel((0, y)) > 0 for y in range(sprite.height)),
        sum(alpha.getpixel((sprite.width - 1, y)) > 0 for y in range(sprite.height)),
    )
    limits = (sprite.width * 0.8, sprite.width * 0.8, sprite.height * 0.8, sprite.height * 0.8)
    if any(count >= limit for count, limit in zip(edge_counts, limits)):
        fail(f"{path}: likely retained sheet grid line on canvas edge")


def mean_rgba_distance(first, second):
    """Mean absolute distance per RGBA channel over the fixed 92px character canvas."""
    if first.size != second.size:
        return math.inf
    total = sum(
        abs(left_channel - right_channel)
        for left, right in zip(first.get_flattened_data(), second.get_flattened_data())
        for left_channel, right_channel in zip(left, right)
    )
    return total / (first.width * first.height * 4)


def check_character_rotation_near_duplicates():
    """Reject duplicated direction art for the three same-scale player rotation sets.

    The absolute threshold is deliberately limited to player sprites: all three use a
    92x92 canvas and 46px content height. Monster content ranges from 44 to 150px and
    includes documented symmetric spirits, so their whole-canvas means are not comparable.
    """
    minima = {}
    for character in ("Taoist", "Warrior", "Archer"):
        root = f"asset/character/{character}/Idle/rotations"
        cells = {
            direction: image(f"{root}/{direction}.png")
            for direction in CHARACTER_ROTATION_DIRECTIONS
        }
        pairs = [
            (mean_rgba_distance(cells[first], cells[second]), first, second)
            for first, second in combinations(CHARACTER_ROTATION_DIRECTIONS, 2)
        ]
        distance, first, second = min(pairs)
        minima[character] = (distance, first, second)
        for distance, first, second in pairs:
            if distance < CHARACTER_NEAR_DUPLICATE_THRESHOLD:
                fail(
                    f"character rotation near-duplicate: {character}/{first}.png and "
                    f"{character}/{second}.png mean RGBA distance {distance:.2f} is below "
                    f"{CHARACTER_NEAR_DUPLICATE_THRESHOLD:.2f}"
                )
    return minima


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
    if manifest.get("schema_version") != 2:
        fail("rotation facing audit: expected schema version 2 with exact diagonal labels")
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
    if manifest.get("diagonal_handedness_limit") != (
        "manual contact-sheet inspection required; mirror-pair metrics cannot detect swapped labels"
    ):
        fail("rotation facing audit: diagonal-handedness limitation is not recorded")
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
        if record.get("diagonal_handedness_review") != "accepted_manual_contact_sheet":
            fail(f"rotation facing audit: {name} lacks manual diagonal-handedness approval")
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
            if cell.get("expected_direction") != direction:
                fail(f"rotation facing audit: {name}/{direction} lacks its exact direction label")
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


def check_ui_journey():
    """Require the audited mobile journey set and its state/contrast evidence."""
    metrics_path = ROOT / "asset/ui/raw/journey/ui_metrics.json"
    if not metrics_path.is_file():
        fail("UI journey metrics are missing; run tools/asset/measure_ui_journey.py")
        return
    metrics = json.loads(metrics_path.read_text(encoding="utf-8"))
    expected_counts = {
        "icons": 47,
        "illustrations": 11,
        "furniture": 31,
        "fixed_controls": 3,
    }
    for group, expected in expected_counts.items():
        records = metrics.get(group, {})
        if len(records) != expected:
            fail(f"UI journey: expected {expected} {group}, got {len(records)}")
        for path, record in records.items():
            if not record.get("accepted"):
                fail(f"asset/ui/{path}: failed the recorded UI journey gate")
    expected_states = {
        "character_selected_vs_unselected", "area_selected_vs_unselected",
        "area_locked_vs_unselected", "tier_rare_vs_common",
        "tier_legendary_vs_common", "claimed_vs_unclaimed",
        "toggle_on_vs_off", "victory_vs_defeat",
    }
    states = metrics.get("state_differences", {})
    if set(states) != expected_states:
        fail(f"UI journey: incomplete state-shape evidence {sorted(states)}")
    for state, record in states.items():
        if not record.get("accepted"):
            fail(f"UI journey: {state} has no non-colour state distinction")
    ratios = metrics.get("contrast_ratios", {})
    expected_ratios = {
        "ink_on_paper", "ink_on_paper_dark", "light_text_on_ink",
        "light_text_on_vermilion_dark",
    }
    if set(ratios) != expected_ratios or any(ratio < 4.5 for ratio in ratios.values()):
        fail(f"UI journey: WCAG-AA contrast failure {ratios}")
    if not metrics.get("accepted"):
        fail("UI journey metrics did not accept the complete set")


def check_camp_and_button_redesign():
    """Require the warm camp identity set and the measured button redesign."""
    camp_metrics_path = ROOT / "asset/camp/camp_ground_metrics.json"
    if not camp_metrics_path.is_file():
        fail("camp ground metrics are missing; run tools/asset/build_camp_ground.py")
        return
    camp_metrics = json.loads(camp_metrics_path.read_text(encoding="utf-8"))
    expected_ground = {
        "asset/camp/ground/courtyard.png",
        "asset/camp/ground/flagstone.png",
        "asset/camp/transition/path_overlay_north.png",
        "asset/camp/transition/gate_approach_north.png",
        "asset/camp/transition/boundary_north.png",
    }
    if set(camp_metrics.get("ground", {})) != expected_ground:
        fail("camp ground metrics do not cover the two tiles and three transition overlays")
    for path in ("asset/camp/ground/courtyard.png", "asset/camp/ground/flagstone.png"):
        check_tile(path)
    for path in (
        "asset/camp/transition/path_overlay_north.png",
        "asset/camp/transition/gate_approach_north.png",
        "asset/camp/transition/boundary_north.png",
    ):
        check_sprite(path, (256, 256))
        colours = {pixel[:3] for pixel in image(path).get_flattened_data() if pixel[3]}
        if len(colours) > 32:
            fail(f"{path}: expected <=32 colours, got {len(colours)}")
    brightness = camp_metrics.get("mean_rgb_brightness", {})
    camp_brightness = brightness.get("camp_courtyard", 0)
    stage_brightness = brightness.get("bamboo_forest_stage", math.inf)
    if camp_brightness < stage_brightness + 60:
        fail(
            "camp courtyard is not visibly warmer/brighter than the combat ground: "
            f"camp={camp_brightness}, stage={stage_brightness}"
        )
    if camp_metrics.get("canonical_orientation") != (
        "north for all transition overlays; rotate in 90-degree increments"
    ):
        fail("camp transition canonical orientation is not recorded")

    manifest_path = ROOT / "asset/ui/chrome/button_redesign.json"
    metrics_path = ROOT / "asset/ui/chrome/button_redesign_metrics.json"
    if not manifest_path.is_file() or not metrics_path.is_file():
        fail("button redesign manifest/metrics are missing")
        return
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    metrics = json.loads(metrics_path.read_text(encoding="utf-8"))
    directions = {"royal_seal", "ink_tablet", "knotted_talisman"}
    states = {"normal", "hover", "pressed", "disabled"}
    if set(manifest.get("directions", [])) != directions or set(manifest.get("states", [])) != states:
        fail("button redesign does not contain exactly three directions and four states")
    if manifest.get("selected") != "royal_seal" or metrics.get("selected") != "royal_seal":
        fail("button redesign selected direction changed unexpectedly")
    if metrics.get("nine_slice_margins") != {"left": 6, "top": 8, "right": 6, "bottom": 8}:
        fail("button redesign nine-slice margins changed")
    records = metrics.get("directions", {})
    if set(records) != directions:
        fail("button redesign metrics do not cover all three directions")
    for direction in directions:
        record = records.get(direction, {})
        if not record.get("accepted") or not record.get("pressed_shape_pass"):
            fail(f"button direction {direction} failed contrast/pressed-shape gate")
        state_records = record.get("states", {})
        if set(state_records) != states:
            fail(f"button direction {direction} lacks a complete state set")
        for state in states:
            candidate = f"asset/ui/chrome/candidates/{direction}/button_{state}_9slice.png"
            check_sprite(candidate, (64, 32))
            if state in {"normal", "hover", "pressed"} and state_records.get(state, {}).get("text_contrast", 0) < 4.5:
                fail(f"{candidate}: enabled text contrast is below WCAG AA")
    for state in states:
        canonical = ROOT / f"asset/ui/chrome/button_{state}_9slice.png"
        selected = ROOT / f"asset/ui/chrome/candidates/royal_seal/button_{state}_9slice.png"
        if canonical.read_bytes() != selected.read_bytes():
            fail(f"canonical button_{state} is not the selected royal_seal candidate")
    if not metrics.get("accepted"):
        fail("button redesign metrics rejected the candidate set")


def check_destructible_sets():
    """Require complete intact/break/debris sets and measured collapse evidence."""
    destructible_ids = {
        "onggi_jar", "straw_bundle", "bamboo_basket", "rice_sack",
        "supply_crate", "handcart", "offering_vessels", "roof_tile_stack",
    }
    manifest_path = ROOT / "asset/destructible/destructible_manifest.json"
    metrics_path = ROOT / "asset/destructible/raw/destructible_metrics.json"
    contact_path = ROOT / "asset/destructible/raw/destructible_contact_sheet.png"
    if not manifest_path.is_file() or not metrics_path.is_file() or not contact_path.is_file():
        fail("destructible manifest, metrics, or contact sheet is missing")
        return
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    metrics = json.loads(metrics_path.read_text(encoding="utf-8"))
    if set(manifest.get("objects", {})) != destructible_ids:
        fail("destructible manifest does not cover exactly eight objects")
    if manifest.get("frame_order") != ["intact", "break/0", "break/1", "break/2", "break/3"]:
        fail("destructible frame order changed")
    if manifest.get("breakable_cue") != (
        "small vermilion paper loot seal or knotted tassel on every intact object"
    ):
        fail("destructible breakable-versus-scenery cue is not recorded")
    records = metrics.get("sets", {})
    if set(records) != destructible_ids:
        fail("destructible metrics do not cover exactly eight objects")
    for object_id in sorted(destructible_ids):
        root = f"asset/destructible/{object_id}"
        check_sprite(f"{root}/intact.png", (64, 64))
        intact_bbox = image(f"{root}/intact.png").getbbox()
        if intact_bbox and intact_bbox[3] - intact_bbox[1] > 43:
            fail(f"{root}/intact.png: taller than the under-trash 43px destructible ceiling")
        for frame in range(4):
            check_sprite(f"{root}/break/{frame}.png", (64, 64))
            check_no_edge_grid_line(f"{root}/break/{frame}.png")
        check_sprite(f"{root}/debris.png", (64, 64))
        if (ROOT / f"{root}/debris.png").read_bytes() != (ROOT / f"{root}/break/3.png").read_bytes():
            fail(f"{root}: debris alias differs from resting break frame 3")
        record = records.get(object_id, {})
        if not record.get("accepted"):
            fail(f"{root}: failed irreversible-collapse/scale/cue gate")
        if record.get("debris_equals_break_3") is not True:
            fail(f"{root}: debris equivalence is not recorded")
        transitions = record.get("transitions_changed_pixels", [])
        if len(transitions) != 4 or any(value < 24 for value in transitions):
            fail(f"{root}: break sequence lacks four materially distinct transitions")
    if not metrics.get("accepted"):
        fail("destructible set metrics rejected the batch")


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
    for state in ("normal", "hover", "pressed", "disabled"):
        check_sprite(f"asset/ui/chrome/button_{state}_9slice.png", (64, 32))
    check_ui_journey()
    check_camp_and_button_redesign()
    for name in weapon_ids:
        check_sprite(f"asset/weapon/icons/{name}.png", (32, 32))
        projectile_canvas = (64, 64) if name in weapon_ids[7:] else None
        check_sprite(f"asset/weapon/projectiles/{name}.png", projectile_canvas)

    directions = CHARACTER_ROTATION_DIRECTIONS
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
    character_rotation_minima = check_character_rotation_near_duplicates()
    monster_heights = {
        "forest_goblin": 44,
        "forest_spirit": 46,
        "bamboo_brute": 58,
        "bamboo_spirit_lord": 150,
    }
    for monster_id, height in monster_heights.items():
        canvas = (192, 192) if monster_id == "bamboo_spirit_lord" else (92, 92)
        for direction in directions:
            check_sprite(f"asset/monster/{monster_id}/rotations/{direction}.png", canvas, height)
    check_sprite("asset/monster/bamboo_spirit_lord.png", (120, 150), 150)
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
        "gwimyeon_dokkaebi": "asset/monster/gwimyeon_dokkaebi/death",
        "blue_dokkaebi": "asset/monster/blue_dokkaebi/death",
        "gumiho_scout": "asset/monster/gumiho_scout/death",
        "seonbi_wraith": "asset/monster/seonbi_wraith/death",
        "haetae_guardian": "asset/monster/haetae_guardian/death",
        "dokkaebi_king": "asset/monster/dokkaebi_king/death",
        "cheonyeo_gwisin": "asset/monster/cheonyeo_gwisin/death",
        "dalgyal_gwisin": "asset/monster/dalgyal_gwisin/death",
        "jeoseung_saja": "asset/monster/jeoseung_saja/death",
        "tomb_jangseung": "asset/monster/tomb_jangseung/death",
        "imugi_whelp": "asset/monster/imugi_whelp/death",
        "ancient_imugi": "asset/monster/ancient_imugi/death",
        "wonhon": "asset/monster/wonhon/death",
        "dokkaebi_fire": "asset/monster/dokkaebi_fire/death",
        "shadow_dokkaebi": "asset/monster/shadow_dokkaebi/death",
        "fox_spirit": "asset/monster/fox_spirit/death",
        "bulgasari": "asset/monster/bulgasari/death",
        "gumiho": "asset/monster/gumiho/death",
    }
    for sequence_name, sequence_root in death_sequences.items():
        canvas = (192, 192) if sequence_name == "bamboo_spirit_lord" else (92, 92)
        for frame in range(4):
            check_sprite(f"{sequence_root}/{frame}.png", canvas)
            check_no_edge_grid_line(f"{sequence_root}/{frame}.png")
    death_metrics = json.loads((ROOT / "asset/character/raw/death_metrics.json").read_text(encoding="utf-8"))
    if set(death_metrics) != set(death_sequences):
        fail("death metrics do not cover the twenty-five authored death sheets")
    for sequence in death_sequences:
        if not death_metrics.get(sequence, {}).get("accepted"):
            fail(f"{death_sequences[sequence]}: failed irreversible-collapse gate")

    drop_ids = (
        "xp_small", "xp_medium", "xp_large", "gold_coin", "gold_pile",
        "health_gourd", "magnet", "chest_common", "chest_rare", "chest_epic",
        "chest_legendary", "chest_mythic",
    )
    for drop_id in drop_ids:
        check_sprite(f"asset/drop/{drop_id}/idle.png", (24, 24))
        check_no_edge_grid_line(f"asset/drop/{drop_id}/idle.png")
        for frame in range(4):
            check_sprite(f"asset/drop/{drop_id}/collect/{frame}.png", (32, 32))
            check_no_edge_grid_line(f"asset/drop/{drop_id}/collect/{frame}.png")
    drop_metrics = json.loads((ROOT / "asset/drop/raw/drop_metrics.json").read_text(encoding="utf-8"))
    if set(drop_metrics.get("sets", {})) != set(drop_ids):
        fail("drop metrics do not cover the twelve authored pickup sets")
    if not drop_metrics.get("accepted"):
        fail("asset/drop: failed pickup readability/progression/grade-shape gate")
    check_destructible_sets()
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
        "ward_barrier", "spirit_beam", "seal_field", "fireball_impact",
        "spirit_bolt_impact",
    )
    for effect in effects:
        for frame in range(4):
            check_sprite(f"asset/effect/{effect}/{frame}.png", (64, 64))
            check_no_edge_grid_line(f"asset/effect/{effect}/{frame}.png")
    effect_metrics = json.loads((ROOT / "asset/effect/raw/effect_metrics.json").read_text(encoding="utf-8"))
    if set(effect_metrics) != set(effects):
        fail("effect metrics do not cover the fifteen authored effect sheets")
    for effect in effects:
        if not effect_metrics.get(effect, {}).get("accepted"):
            fail(f"asset/effect/{effect}: failed mobile-readability/progression gate")

    travel = ("spinning_talisman", "arrow", "fireball", "throwing_knife", "spirit_bolt")
    melee = ("wide_sword_arc", "dual_blade_cross", "heavy_overhead", "spear_thrust")
    for name in travel:
        check_sprite(f"asset/weapon/travel/{name}.png", (32, 32))
        check_no_edge_grid_line(f"asset/weapon/travel/{name}.png")
    for name in melee:
        check_sprite(f"asset/weapon/melee/{name}.png", (64, 64))
        check_no_edge_grid_line(f"asset/weapon/melee/{name}.png")
    combat_metrics = json.loads((ROOT / "asset/weapon/raw/combat_art_metrics.json").read_text(encoding="utf-8"))
    if combat_metrics.get("canonical_orientation") != "east":
        fail("canonical travel/melee art is not recorded as east-facing")
    if set(combat_metrics.get("travel", {})) != set(travel) or set(combat_metrics.get("melee", {})) != set(melee):
        fail("combat art metrics do not exactly cover the authored travel and melee sets")
    if not combat_metrics.get("accepted"):
        fail("canonical travel/melee art failed mobile-readability gate")

    walk_status = json.loads((ROOT / "asset/monster/WALK_STATUS.json").read_text(encoding="utf-8"))
    expected_monsters = set(monster_heights) | set(later_monster_heights)
    if set(walk_status.get("sets", {})) != expected_monsters:
        fail("monster walk status does not cover all twenty-two monster sets")
    if walk_status.get("resolution") != "satisfied_otherwise_procedural" or walk_status.get("generated_frames_shipped"):
        fail("monster walk member is not recorded as a procedural negative result")
    walk_metrics = json.loads((ROOT / "asset/monster/raw/walk_trial_metrics.json").read_text(encoding="utf-8"))
    if walk_metrics.get("summary") != {
        "accepted_trials": 0,
        "total_trials": 4,
        "generated_walk_accepted": False,
    }:
        fail("monster walk rejection metrics changed unexpectedly")

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
    print("M1 assets verified: 20 UI icons + 5 chrome assets, 34 weapon assets, 2 characters, 4 seamless tiles, 6 audio files")
    print(f"Motion-generation rejection evidence: {changed}/1702 pixels changed between same-pose frames")
    print(f"Single-sheet retry rejected: idle pair {retry_idle}/1702 versus separate baseline {baseline}/1702")
    print(f"Direct-conditioned retry rejected: south walk frames {conditioned_changed[0]}/1702 and {conditioned_changed[1]}/1702")
    print("Directional additions verified: 14 class rotations + 32 monster rotations, 3 backdrops, 12 props")
    print(f"Six multi-reference motion sheets rejected: {accepted_current}/{measured_current} frames passed the regional stability gate")
    print("Expansion assets verified: 18 folklore monsters + 144 rotations, 60 effect frames, 12 structures, 3 title assets")
    print("Set-gap additions verified: 100 death frames, 22 procedural walk records, 5 travel sprites, 4 melee swings")
    print("Loot and boss-scale assets verified: 12 pickup sets (48 collect frames) + 120x150 boss with 8 rotations and 4 death frames")
    print("Destructible stage objects verified: 8 intact sprites + 32 break frames + 8 debris aliases; progression/scale/cue gates passed")
    print("Directional-facing audit verified: 25/25 sets, 200 hash-bound cells manually reviewed")
    minimum_summary = ", ".join(
        f"{name} {distance:.2f} ({first}/{second})"
        for name, (distance, first, second) in character_rotation_minima.items()
    )
    print(
        "Character near-duplicate gate verified: 84 pairs at mean-RGBA threshold "
        f"{CHARACTER_NEAR_DUPLICATE_THRESHOLD:.2f}; minima: {minimum_summary}"
    )
    print("UI journey verified: 47 icons, 11 illustrations, 31 nine-slices, 3 fixed controls; WCAG-AA/state gates passed")
    print("Camp identity verified: 2 warm seamless tiles + 3 rotatable north-facing transition overlays")
    print("Button redesign verified: 3 directions x 4 states; selected royal_seal, 6x8 margins, WCAG-AA/pressed-shape gates passed")


if __name__ == "__main__":
    main()
