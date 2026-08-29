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
		"elite_heal": {"hp_ratio": 0.15},
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


func test_heal_budget_prices_breaks_and_elite_kills() -> bool:
	# Fixture: health share 6/100, pickup ratio 0.25, elite ratio 0.15.
	# 10 breaks -> 10 * 0.06 * 0.25 = 0.15; 6 elites -> 6 * 0.15 = 0.9.
	var budget: float = Pickups.heal_budget(_fixture(), 10, 6)
	return is_equal_approx(budget, 0.15 + 0.9)


func test_heal_budget_zero_on_empty_data() -> bool:
	return Pickups.heal_budget({}, 10, 6) == 0.0


func test_data_issues_rejects_bad_elite_heal() -> bool:
	var missing: Dictionary = _fixture().duplicate(true)
	(missing as Dictionary).erase("elite_heal")
	if Pickups.data_issues(missing, LUCK_CAP).is_empty():
		return false
	var refill: Dictionary = _fixture().duplicate(true)
	# A kill heal above half the bar stops being a slice and becomes a refill.
	((refill["elite_heal"] as Dictionary))["hp_ratio"] = 0.6
	return not Pickups.data_issues(refill, LUCK_CAP).is_empty()


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


# N9-41 (owner report: 상자에서 신규 무기·패시브가 나온다). A chest only ever
# deepens what the run already holds; new skills belong to the level-up screen.
# The weapon half shipped in N5-5, the passive half leaked until now, so this
# guards the RULE rather than either half of it.
const CHEST_WEAPONS := {
	"owned": {
		"name_ko": "보유", "grade": "common", "damage": 10.0, "cooldown_sec": 1.0,
		"speed": 200.0, "max_level": 8, "per_level": {"damage": 2.0},
	},
	"unowned": {
		"name_ko": "미보유", "grade": "common", "damage": 10.0, "cooldown_sec": 1.0,
		"speed": 200.0, "max_level": 8, "per_level": {"damage": 2.0},
	},
}
const CHEST_PASSIVES := {
	"attack_damage": {"name_ko": "공격력", "stat": "attack_damage", "per_stack": 0.05, "max_stacks": 5},
	"move_speed": {"name_ko": "이동 속도", "stat": "move_speed", "per_stack": 0.05, "max_stacks": 5},
}


## Mirrors Stage._show_next_chest_reward's filter. Kept as a pure function here
## so the rule is testable without a running stage.
func _chest_pool(owned_levels: Dictionary, stacks: Dictionary) -> Array[Dictionary]:
	var pool: Array[Dictionary] = LevelUp.candidates(
		CHEST_WEAPONS, CHEST_PASSIVES, owned_levels, stacks
	)
	var owned_only: Array[Dictionary] = []
	for choice: Dictionary in pool:
		var id: String = String(choice.get("id", ""))
		match String(choice.get("kind", "")):
			LevelUp.KIND_NEW_WEAPON:
				continue
			LevelUp.KIND_PASSIVE:
				if int(stacks.get(id, 0)) <= 0:
					continue
		owned_only.append(choice)
	return owned_only


func test_chest_never_offers_an_unowned_weapon() -> bool:
	var pool: Array[Dictionary] = _chest_pool({"owned": 1}, {"attack_damage": 1})
	for choice: Dictionary in pool:
		if String(choice["kind"]) == LevelUp.KIND_NEW_WEAPON:
			return false
		if String(choice["id"]) == "unowned":
			return false
	return true


func test_chest_never_offers_a_passive_the_run_has_not_taken() -> bool:
	# move_speed sits at zero stacks: legal on a level-up screen, never in a
	# chest. This is the half that leaked.
	var pool: Array[Dictionary] = _chest_pool({"owned": 1}, {"attack_damage": 1})
	for choice: Dictionary in pool:
		if String(choice["id"]) == "move_speed":
			return false
	return true


func test_chest_still_offers_what_the_run_already_holds() -> bool:
	# The filter must not empty the pool — a chest that can offer nothing pays
	# fallback gold instead of a reward. N11-8: passives left the run, so the
	# chest's held-only pool is weapon upgrades alone.
	var pool: Array[Dictionary] = _chest_pool({"owned": 1}, {"attack_damage": 1})
	var has_weapon: bool = false
	for choice: Dictionary in pool:
		if String(choice["kind"]) == LevelUp.KIND_WEAPON_UP and String(choice["id"]) == "owned":
			has_weapon = true
		if String(choice["kind"]) == LevelUp.KIND_PASSIVE:
			return false
	return has_weapon


## N9-55 field passives (owner: "떨어져있는 패시브를 주우면 4개 이상으로도
## 등록이 되도록"). The rule under test is that the four-slot budget does NOT
## apply to something found on the ground — only maxed passives are excluded.
func test_field_passive_ids_ignore_the_slot_budget() -> bool:
	var passives: Dictionary = {
		"a": {"max_stacks": 5}, "b": {"max_stacks": 5},
		"c": {"max_stacks": 5}, "d": {"max_stacks": 5}, "e": {"max_stacks": 5},
	}
	# Four already taken: the level-up screen would offer nothing new here.
	var stacks: Dictionary = {"a": 1, "b": 1, "c": 1, "d": 1}
	return Pickups.field_passive_ids(passives, stacks).size() == 5


func test_field_passive_ids_drop_maxed_passives() -> bool:
	var passives: Dictionary = {"a": {"max_stacks": 3}, "b": {"max_stacks": 3}}
	var ids: Array[String] = Pickups.field_passive_ids(passives, {"a": 3})
	return ids == ["b"]


func test_field_passive_ids_skip_comment_keys_and_junk() -> bool:
	# Data files carry "_note" keys, and a malformed entry must not crash a run.
	var passives: Dictionary = {"_note": "text", "a": {"max_stacks": 2}, "b": 7}
	return Pickups.field_passive_ids(passives, {}) == ["a"]


func test_field_spawn_point_sits_on_the_ring() -> bool:
	var player := Vector2(120.0, -40.0)
	var at: Vector2 = Pickups.field_spawn_point(player, PI / 3.0, 700.0)
	return absf(player.distance_to(at) - 700.0) < 0.01


func test_field_spawn_point_survives_a_negative_distance() -> bool:
	var player := Vector2(5.0, 5.0)
	return Pickups.field_spawn_point(player, 0.0, -100.0) == player


func test_shipped_field_passive_block_stays_parked() -> bool:
	# N11-8: in-run passives moved to the permanent refine ranks, so the spawn
	# block is parked under a "_" key — the run must see NO live block (one
	# "missing block" issue is the parked state). N11-3 re-aims the thief at
	# materials and revives these numbers.
	return Pickups.field_passive_issues(_pickups()).size() == 1


func test_field_passive_issues_catch_an_onscreen_spawn() -> bool:
	var broken: Dictionary = {"field_passive": {
		"interval_sec": 10.0, "max_live": 2,
		"spawn_min_px": 100.0, "spawn_max_px": 900.0, "min_offscreen_px": 560.0,
	}}
	return Pickups.field_passive_issues(broken).size() == 1


func test_field_passive_issues_report_a_missing_block() -> bool:
	return Pickups.field_passive_issues({}).size() == 1


func _pickups() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PICKUPS_PATH))
	return data if data is Dictionary else {}
