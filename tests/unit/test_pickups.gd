extends RefCounted
## Unit tests for the N5-5 pickup/chest helpers (Pickups) against fixture data
## and the shipped data/pickups.json. Discovered by tests/run_tests.gd.

const PICKUPS_PATH := "res://data/pickups.json"
const PROPS_PATH := "res://data/props.json"
const LUCK_CAP := 0.5  # data/meta_tree.json config.stat_caps.luck
const ROLLS := 10000
const SEED_A := 20260817


static func _fixture() -> Dictionary:
	return {
		"break_table": [
			{"kind": "nothing", "weight": 50.0},
			{"kind": "gold", "weight": 38.0},
			{"kind": "health", "weight": 6.0},
			{"kind": "nuke", "weight": 3.0},
			{"kind": "magnet", "weight": 3.0},
		],
		"_rules": {"plain_share_min": 0.8},
		"gold": {"amount": 12},
		"health": {"hp_ratio": 0.25, "full_hp_gold": 10},
		"nuke": {"damage": 999.0, "elite_boss_damage": 150.0, "ring_radius_px": 320.0},
		"magnet": {"ring_radius_px": 120.0},
		"chest": {
			"open_radius_px": 26.0,
			"weights": {"1": 70.0, "3": 22.0, "5": 8.0},
			"luck_shift": {"1": 0.0, "3": 4.0, "5": 10.0},
			"fallback_gold": 40,
		},
	}


static func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_shipped_data_passes_contract() -> bool:
	var issues: Array[String] = Pickups.data_issues(_load_json(PICKUPS_PATH), LUCK_CAP)
	return issues.is_empty()


func test_roll_break_seeded_distribution_stays_plain() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_A
	var counts: Dictionary = {}
	for i: int in range(ROLLS):
		var kind: String = Pickups.roll_break(_fixture(), rng)
		counts[kind] = int(counts.get(kind, 0)) + 1
	# Every kind must occur, and nothing+gold must dominate (>= 80% intent).
	for kind: String in Pickups.KINDS:
		if int(counts.get(kind, 0)) <= 0:
			return false
	var plain: int = int(counts.get("nothing", 0)) + int(counts.get("gold", 0))
	return float(plain) / float(ROLLS) >= 0.8


func test_roll_break_deterministic_per_seed() -> bool:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = SEED_A
	b.seed = SEED_A
	for i: int in range(100):
		if Pickups.roll_break(_fixture(), a) != Pickups.roll_break(_fixture(), b):
			return false
	return true


func test_chest_weights_luck_bend() -> bool:
	var chest: Dictionary = _fixture()["chest"]
	var base: Dictionary = Pickups.chest_weights(chest, 0.0)
	var bent: Dictionary = Pickups.chest_weights(chest, LUCK_CAP)
	# Luck 0 = the raw base weights; capped luck leaves 1 alone and raises 3/5.
	return is_equal_approx(float(base["1"]), 70.0) \
		and is_equal_approx(float(base["5"]), 8.0) \
		and is_equal_approx(float(bent["1"]), 70.0) \
		and is_equal_approx(float(bent["3"]), 22.0 * 3.0) \
		and is_equal_approx(float(bent["5"]), 8.0 * 6.0)


func test_chest_count_distribution_base_and_max_luck() -> bool:
	var chest: Dictionary = _fixture()["chest"]
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_A
	var base_counts: Dictionary = {1: 0, 3: 0, 5: 0}
	var max_counts: Dictionary = {1: 0, 3: 0, 5: 0}
	for i: int in range(ROLLS):
		base_counts[Pickups.roll_chest_count(chest, 0.0, rng)] += 1
	for i: int in range(ROLLS):
		max_counts[Pickups.roll_chest_count(chest, LUCK_CAP, rng)] += 1
	# Base: 1 is the common case, 5 the rare one. Cap: 5 becomes common
	# (over 15%) but never dominant (below 50%) — and never guaranteed.
	var base_ok: bool = base_counts[1] > base_counts[3] and base_counts[3] > base_counts[5]
	var p5: float = float(max_counts[5]) / float(ROLLS)
	return base_ok and p5 > 0.15 and p5 < 0.5 and max_counts[1] > 0


func test_nuke_damage_caps_elite_and_boss() -> bool:
	var pickups: Dictionary = _fixture()
	return is_equal_approx(Pickups.nuke_damage(pickups, false), 999.0) \
		and is_equal_approx(Pickups.nuke_damage(pickups, true), 150.0)


func test_data_issues_rejects_vending_machine_table() -> bool:
	var bad: Dictionary = _fixture().duplicate(true)
	# Exciting drops pushed to half the table — must fail the plain-share floor.
	(bad["break_table"] as Array)[0] = {"kind": "nothing", "weight": 10.0}
	(bad["break_table"] as Array)[1] = {"kind": "gold", "weight": 10.0}
	(bad["break_table"] as Array)[2] = {"kind": "health", "weight": 20.0}
	return not Pickups.data_issues(bad, LUCK_CAP).is_empty()


func test_data_issues_rejects_missing_kind_and_bad_chest() -> bool:
	var missing: Dictionary = _fixture().duplicate(true)
	(missing["break_table"] as Array).remove_at(4)
	if Pickups.data_issues(missing, LUCK_CAP).is_empty():
		return false
	var flat: Dictionary = _fixture().duplicate(true)
	# Non-decreasing base weights break the 1 > 3 > 5 escalation contract.
	((flat["chest"] as Dictionary)["weights"] as Dictionary)["3"] = 70.0
	if Pickups.data_issues(flat, LUCK_CAP).is_empty():
		return false
	var greedy: Dictionary = _fixture().duplicate(true)
	# A luck bend that makes the 5-reward chest dominant at cap must fail.
	((greedy["chest"] as Dictionary)["luck_shift"] as Dictionary)["5"] = 100.0
	return not Pickups.data_issues(greedy, LUCK_CAP).is_empty()


func test_elite_derivation_marks_is_elite() -> bool:
	var base: Dictionary = {"hp": 85.0, "damage": 18.0, "speed": 70.0}
	var derived: Dictionary = Enemy.derive_elite_stats(base, {"hp_mult": 6.0})
	return bool(derived.get("is_elite", false)) \
		and is_equal_approx(float(derived["hp"]), 510.0)


func test_breakable_props_are_solid_with_positive_hp() -> bool:
	var catalog: Dictionary = _load_json(PROPS_PATH).get("props", {})
	var breakable_count: int = 0
	for prop_id: String in catalog:
		var prop: Dictionary = catalog[prop_id]
		if not prop.has("breakable"):
			continue
		breakable_count += 1
		if not bool(prop.get("solid", false)):
			return false
		if float((prop.get("breakable") as Dictionary).get("hp", 0.0)) <= 0.0:
			return false
	return breakable_count >= 3
