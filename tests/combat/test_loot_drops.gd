extends RefCounted
## LootDrops.roll probabilities and RunState loot bookkeeping.

const RUN_STATE_SCRIPT := preload("res://scripts/core/run_state.gd")

const ROLL_ITERATIONS: int = 200
const RNG_SEED: int = 20260814


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_guaranteed_and_impossible_chances())
	failures.append_array(_test_empty_table_rolls_nothing())
	failures.append_array(_test_malformed_entries_are_skipped())
	failures.append_array(_test_partial_chance_is_probabilistic())
	failures.append_array(_test_luck_scales_chances())
	failures.append_array(_test_tier_tints())
	failures.append_array(_test_run_state_loot_counts())
	return failures


func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	return rng


func _test_guaranteed_and_impossible_chances() -> Array[String]:
	var failures: Array[String] = []
	var rng := _seeded_rng()
	var table: Dictionary = {"drops": [
		{"loot_id": "always", "chance": 1.0},
		{"loot_id": "never", "chance": 0.0},
	]}

	for _iteration in ROLL_ITERATIONS:
		var dropped: Array[String] = LootDrops.roll(table, rng)
		if not dropped.has("always"):
			failures.append("chance 1.0 failed to drop")
			break
		if dropped.has("never"):
			failures.append("chance 0.0 dropped")
			break

	return failures


func _test_empty_table_rolls_nothing() -> Array[String]:
	var failures: Array[String] = []
	var rng := _seeded_rng()

	if not LootDrops.roll({}, rng).is_empty():
		failures.append("a monster without a table dropped loot")

	return failures


func _test_malformed_entries_are_skipped() -> Array[String]:
	var failures: Array[String] = []
	var rng := _seeded_rng()
	var table: Dictionary = {"drops": [
		"not_a_dictionary",
		{"chance": 1.0},
		{"loot_id": "valid", "chance": 1.0},
	]}

	var dropped: Array[String] = LootDrops.roll(table, rng)
	var expected: Array[String] = ["valid"]
	if dropped != expected:
		failures.append("malformed entries were not skipped cleanly: %s" % [dropped])

	return failures


func _test_partial_chance_is_probabilistic() -> Array[String]:
	var failures: Array[String] = []
	var rng := _seeded_rng()
	var table: Dictionary = {"drops": [{"loot_id": "half", "chance": 0.5}]}

	var hits: int = 0
	for _iteration in ROLL_ITERATIONS:
		if not LootDrops.roll(table, rng).is_empty():
			hits += 1

	# Seeded stream, so this is deterministic; the loose band only documents
	# that the roll is neither always nor never.
	if hits == 0 or hits == ROLL_ITERATIONS:
		failures.append("chance 0.5 rolled %d/%d — not probabilistic" % [hits, ROLL_ITERATIONS])

	return failures


func _test_luck_scales_chances() -> Array[String]:
	var failures: Array[String] = []
	var rng := _seeded_rng()
	var table: Dictionary = {"drops": [{"loot_id": "gem", "chance": 0.6}]}

	# 0.6 * (1 + 1.0) >= 1.0, so enough luck turns a partial chance guaranteed.
	for _iteration in 50:
		if LootDrops.roll(table, rng, 1.0).is_empty():
			failures.append("chance 0.6 with +100% luck failed to drop")
			break

	# Negative luck must never help nor invert a chance.
	var never: Dictionary = {"drops": [{"loot_id": "gem", "chance": 0.5}]}
	var with_negative: int = 0
	var without: int = 0
	rng = _seeded_rng()
	for _iteration in ROLL_ITERATIONS:
		if not LootDrops.roll(never, rng, -0.5).is_empty():
			with_negative += 1
	rng = _seeded_rng()
	for _iteration in ROLL_ITERATIONS:
		if not LootDrops.roll(never, rng).is_empty():
			without += 1
	if with_negative != without:
		failures.append("negative luck changed the odds (%d vs %d)" % [with_negative, without])

	return failures


func _test_tier_tints() -> Array[String]:
	var failures: Array[String] = []

	if LootDrops.tier_tint("rare") == LootDrops.tier_tint("mythic"):
		failures.append("rare and mythic tints must differ")
	if LootDrops.tier_tint("no_such_tier") != LootDrops.FALLBACK_TINT:
		failures.append("unknown tier did not fall back")

	return failures


func _test_run_state_loot_counts() -> Array[String]:
	var failures: Array[String] = []
	var run: Node = RUN_STATE_SCRIPT.new()

	run.add_loot("whetstone")
	run.add_loot("whetstone")
	run.add_loot("ghost_iron")

	if run.loot_count("whetstone") != 2:
		failures.append("loot_count(whetstone) = %d, expected 2" % run.loot_count("whetstone"))
	if run.loot_count("ghost_iron") != 1:
		failures.append("loot_count(ghost_iron) = %d, expected 1" % run.loot_count("ghost_iron"))
	if run.loot_count("never_collected") != 0:
		failures.append("uncollected loot should count 0")

	run.reset()
	if run.loot_count("whetstone") != 0:
		failures.append("reset() did not clear loot counts")

	run.free()
	return failures
