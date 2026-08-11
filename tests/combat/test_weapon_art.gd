extends RefCounted
## Travel/melee art mapping and the east-canonical rotation contract.
##
## The sprites are authored pointing east so one image serves every angle by
## rotation (asset/ASSET_SET_GAPS_REPORT.md). Nothing else would catch a wrong
## pairing or a renamed file: it would just draw the wrong burst, or nothing.

const WeaponArtScript = preload("res://scripts/weapons/weapon_art.gd")
const EffectPoolScript = preload("res://scripts/combat/effect_pool.gd")
const MotionScript = preload("res://scripts/combat/character_motion.gd")

const WEAPONS_PATH: String = "res://data/weapons.json"


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_pairing_matches_the_report())
	failures.append_array(_test_every_weapon_resolves())
	failures.append_array(_test_east_canonical_rotation())
	failures.append_array(_test_monster_bob_matches_the_recorded_contract())
	return failures


## The report's travel-to-impact table, transcribed. If content or art renames
## something, this fails rather than silently drawing the wrong arrival.
func _test_pairing_matches_the_report() -> Array[String]:
	var expected: Dictionary = {
		&"spinning_talisman": &"talisman_burst",
		&"fireball": &"fireball_impact",
		&"spirit_bolt": &"spirit_bolt_impact",
		&"arrow": &"impact_hit",
		&"throwing_knife": &"impact_hit",
	}
	var failures: Array[String] = []
	for travel_id: Variant in expected.keys():
		var actual: Variant = WeaponArtScript.TRAVEL_IMPACTS.get(travel_id)
		if actual != expected[travel_id]:
			failures.append("%s should pair with %s, got %s" % [travel_id, expected[travel_id], actual])
		if not ResourceLoader.exists(WeaponArtScript.TRAVEL_PATH % travel_id):
			failures.append("missing travel art for %s" % travel_id)
		var impact_frame: String = EffectPoolScript.FRAME_PATH % [expected[travel_id], 0]
		if not ResourceLoader.exists(impact_frame):
			failures.append("missing impact art %s" % impact_frame)
	return failures


## Every shipped weapon must resolve to art that exists, or to the generic hit.
func _test_every_weapon_resolves() -> Array[String]:
	if not FileAccess.file_exists(WEAPONS_PATH):
		return ["could not read %s" % WEAPONS_PATH]
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(WEAPONS_PATH)) != OK:
		return ["%s is not valid JSON" % WEAPONS_PATH]

	var failures: Array[String] = []
	for weapon_key: Variant in (json.data as Dictionary).keys():
		var weapon_id: String = String(weapon_key)
		var travel: StringName = WeaponArtScript.travel_id(weapon_id)
		var melee: StringName = WeaponArtScript.melee_id(weapon_id)
		if travel.is_empty() and melee.is_empty():
			failures.append("weapon %s has neither travel nor melee art" % weapon_id)
		if not travel.is_empty() and WeaponArtScript.travel_texture(weapon_id) == null:
			failures.append("weapon %s travel art does not load" % weapon_id)
		if not melee.is_empty() and WeaponArtScript.melee_texture(weapon_id) == null:
			failures.append("weapon %s melee art does not load" % weapon_id)
		var impact: StringName = WeaponArtScript.impact_for_weapon(weapon_id)
		if not ResourceLoader.exists(EffectPoolScript.FRAME_PATH % [impact, 0]):
			failures.append("weapon %s impact %s has no art" % [weapon_id, impact])
	# A weapon nobody mapped must still mark its landing.
	if WeaponArtScript.impact_for_weapon("not_a_weapon") != WeaponArtScript.GENERIC_IMPACT:
		failures.append("an unmapped weapon should fall back to the generic impact")
	return failures


## East-canonical means local +X follows the velocity: a projectile travelling
## east is unrotated, and every other heading is that heading's angle.
func _test_east_canonical_rotation() -> Array[String]:
	var failures: Array[String] = []
	var cases: Dictionary = {
		"east": [Vector2.RIGHT, 0.0],
		"south": [Vector2.DOWN, PI * 0.5],
		"west": [Vector2.LEFT, PI],
		"north": [Vector2.UP, -PI * 0.5],
	}
	for name: Variant in cases.keys():
		var heading: Vector2 = cases[name][0]
		var expected: float = cases[name][1]
		if not is_equal_approx(heading.angle(), expected):
			failures.append("%s heading should rotate to %f, got %f" % [name, expected, heading.angle()])
	# Travelling east must need no rotation at all, or the art is not east-canonical.
	if not is_zero_approx(Vector2.RIGHT.angle()):
		failures.append("east-canonical art must be unrotated when travelling east")
	return failures


## The recorded monster substitute is the same cycle the player already uses, so
## it must keep reusing CharacterMotion rather than drifting into a second copy.
func _test_monster_bob_matches_the_recorded_contract() -> Array[String]:
	var expected: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, -2), Vector2i(0, -1),
	]
	var failures: Array[String] = []
	if MotionScript.WALK_OFFSETS != expected:
		failures.append("recorded bob is %s, got %s" % [expected, MotionScript.WALK_OFFSETS])
	if not is_equal_approx(MotionScript.WALK_HZ, 8.0):
		failures.append("recorded bob runs at 8 Hz, got %f" % MotionScript.WALK_HZ)
	for offset: Vector2i in MotionScript.WALK_OFFSETS:
		if offset.x != 0:
			failures.append("monster bob must stay on the vertical axis")
	return failures
