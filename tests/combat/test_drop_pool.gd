extends RefCounted
## Drop selection and the art contract behind it.
##
## Which drop a kill leaves is chosen in code from data values, so a renamed
## folder or a shifted threshold would only show up as a missing pickup in play.

const DropPoolScript = preload("res://scripts/combat/drop_pool.gd")

const ALL_DROPS: Array[String] = [
	"xp_small", "xp_medium", "xp_large", "gold_coin", "gold_pile",
	"health_gourd", "magnet",
	"chest_common", "chest_rare", "chest_epic", "chest_legendary", "chest_mythic",
]


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_every_set_has_idle_and_four_collect_frames())
	failures.append_array(_test_xp_grades())
	failures.append_array(_test_gold_grades())
	failures.append_array(_test_chests_are_earned())
	return failures


func _test_every_set_has_idle_and_four_collect_frames() -> Array[String]:
	var failures: Array[String] = []
	for drop_id: String in ALL_DROPS:
		if not ResourceLoader.exists(DropPoolScript.IDLE_PATH % drop_id):
			failures.append("missing idle art for %s" % drop_id)
		for frame in DropPoolScript.COLLECT_FRAMES:
			var path: String = DropPoolScript.COLLECT_PATH % [drop_id, frame]
			if not ResourceLoader.exists(path):
				failures.append("missing collect frame %s" % path)
	return failures


## A goblin worth 1 and a spirit worth 5 must not leave the same orb.
func _test_xp_grades() -> Array[String]:
	var failures: Array[String] = []
	var cases: Dictionary = {1: &"xp_small", 2: &"xp_small", 3: &"xp_medium",
		7: &"xp_medium", 8: &"xp_large", 200: &"xp_large"}
	for amount: Variant in cases.keys():
		var actual: StringName = DropPoolScript.xp_drop_id(int(amount))
		if actual != cases[amount]:
			failures.append("xp %d should drop %s, got %s" % [amount, cases[amount], actual])
	return failures


func _test_gold_grades() -> Array[String]:
	var failures: Array[String] = []
	if DropPoolScript.gold_drop_id(1) != &"gold_coin":
		failures.append("a small payout should be a coin")
	if DropPoolScript.gold_drop_id(150) != &"gold_pile":
		failures.append("a large payout should be a pile")
	return failures


## Chests are for bosses and elites, not for every goblin in a wave.
func _test_chests_are_earned() -> Array[String]:
	var failures: Array[String] = []
	if DropPoolScript.chest_id_for("boss") != DropPoolScript.BOSS_CHEST:
		failures.append("a boss should leave %s" % DropPoolScript.BOSS_CHEST)
	if DropPoolScript.chest_id_for("charger") != DropPoolScript.ELITE_CHEST:
		failures.append("an elite should leave %s" % DropPoolScript.ELITE_CHEST)
	for behaviour: String in ["chase", "ranged", "swarm", ""]:
		if not DropPoolScript.chest_id_for(behaviour).is_empty():
			failures.append("%s should leave no chest, got %s" % [behaviour, DropPoolScript.chest_id_for(behaviour)])
	# Every chest the mapping can name must actually exist on disk.
	for chest: StringName in [DropPoolScript.BOSS_CHEST, DropPoolScript.ELITE_CHEST]:
		if not ResourceLoader.exists(DropPoolScript.IDLE_PATH % chest):
			failures.append("chest %s has no art" % chest)
	return failures
