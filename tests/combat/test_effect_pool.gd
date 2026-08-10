extends RefCounted
## Effect wiring.
##
## The frame paths and the weapon mapping are built in code from ids, so a
## renamed folder or an unmapped new weapon would fail silently at runtime with
## nothing but a push_warning. This pins both, and the frame contract from
## asset/SECOND_ASSET_BATCH_REPORT.md: four frames per set, 0 to 3.

const EffectPoolScript = preload("res://scripts/combat/effect_pool.gd")

const WEAPONS_PATH: String = "res://data/weapons.json"
const REPORT_EFFECT_IDS: Array[String] = [
	"talisman_burst", "spirit_flame", "summon_circle", "fire", "lightning",
	"poison_cloud", "slash", "impact_hit", "level_up", "evolution_flourish",
]


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_every_shipped_set_has_four_frames())
	failures.append_array(_test_named_effects_exist())
	failures.append_array(_test_every_weapon_maps_to_real_art())
	return failures


func _test_every_shipped_set_has_four_frames() -> Array[String]:
	var failures: Array[String] = []
	for effect_id: String in REPORT_EFFECT_IDS:
		for frame in EffectPoolScript.FRAME_COUNT:
			var path: String = EffectPoolScript.FRAME_PATH % [effect_id, frame]
			if not ResourceLoader.exists(path):
				failures.append("missing frame %s" % path)
	return failures


## The ids the code reaches for by constant, rather than through the map.
func _test_named_effects_exist() -> Array[String]:
	var failures: Array[String] = []
	var named: Array[StringName] = [
		EffectPoolScript.HIT, EffectPoolScript.SLASH,
		EffectPoolScript.LEVEL_UP, EffectPoolScript.EVOLUTION,
	]
	for effect_id: StringName in named:
		if not REPORT_EFFECT_IDS.has(String(effect_id)):
			failures.append("%s is not one of the shipped effect sets" % effect_id)
	return failures


## A weapon added later must not silently lose its impact art: it either maps to
## a real set or falls back to the generic hit, and both must resolve on disk.
func _test_every_weapon_maps_to_real_art() -> Array[String]:
	if not FileAccess.file_exists(WEAPONS_PATH):
		return ["could not read %s" % WEAPONS_PATH]
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(WEAPONS_PATH)) != OK:
		return ["%s is not valid JSON" % WEAPONS_PATH]

	var failures: Array[String] = []
	for weapon_key: Variant in (json.data as Dictionary).keys():
		var effect_id: StringName = EffectPoolScript.weapon_effect(String(weapon_key))
		var first_frame: String = EffectPoolScript.FRAME_PATH % [effect_id, 0]
		if not ResourceLoader.exists(first_frame):
			failures.append("weapon %s maps to %s, which has no art" % [weapon_key, effect_id])
	# An unknown weapon must fall back rather than resolve to nothing.
	if EffectPoolScript.weapon_effect("not_a_weapon") != EffectPoolScript.HIT:
		failures.append("an unmapped weapon should fall back to the generic hit")
	return failures
