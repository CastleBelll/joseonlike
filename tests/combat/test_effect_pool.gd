extends RefCounted
## Effect wiring.
##
## Frame paths are built in code from ids, so a renamed folder would fail
## silently at runtime with nothing but a push_warning. This pins the frame
## contract: four frames per set, 0 to 3. The weapon-to-impact pairing is pinned
## next door in test_weapon_art.gd, which owns that mapping.

const EffectPoolScript = preload("res://scripts/combat/effect_pool.gd")

const REPORT_EFFECT_IDS: Array[String] = [
	"talisman_burst", "spirit_flame", "summon_circle", "fire", "lightning",
	"poison_cloud", "slash", "impact_hit", "level_up", "evolution_flourish",
]


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_every_shipped_set_has_four_frames())
	failures.append_array(_test_named_effects_exist())
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
