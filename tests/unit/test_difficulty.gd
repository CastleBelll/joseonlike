extends RefCounted
## Guards the N9-22 difficulty ladder + run-length contracts: the real data
## satisfies its own validator, unlocks chain strictly, and the scaling
## helpers are pure (they never mutate the stage/monster they are given).

const EPSILON := 0.001


func _config() -> Dictionary:
	return Difficulty.load_config()


func test_real_data_has_no_issues() -> bool:
	return Difficulty.data_issues(_config()).is_empty()


func test_only_the_root_tier_is_open_on_a_fresh_profile() -> bool:
	var config: Dictionary = _config()
	var empty: Array = []
	var root: String = Difficulty.default_id(config)
	if not Difficulty.is_unlocked(config, root, empty):
		return false
	for tier: Dictionary in Difficulty.ladder(config):
		var id: String = String(tier.get("id", ""))
		if id == root:
			continue
		if Difficulty.is_unlocked(config, id, empty):
			return false
	# An unknown id is closed, never a crash.
	return not Difficulty.is_unlocked(config, "no_such_tier", empty)


func test_clearing_opens_exactly_the_next_rung() -> bool:
	var config: Dictionary = _config()
	var ladder: Array[Dictionary] = Difficulty.ladder(config)
	if ladder.size() < 3:
		return false
	var first: String = String(ladder[0]["id"])
	var second: String = String(ladder[1]["id"])
	var third: String = String(ladder[2]["id"])
	var cleared: Array = [first]
	return Difficulty.is_unlocked(config, second, cleared) \
		and not Difficulty.is_unlocked(config, third, cleared) \
		and Difficulty.highest_unlocked(config, cleared) == second


func test_mark_cleared_is_pure_and_idempotent() -> bool:
	var profile: Dictionary = {Difficulty.CLEARED_KEY: []}
	var first: Dictionary = Difficulty.mark_cleared(profile, "sunhaeng")
	if not bool(first["changed"]):
		return false
	# The input profile must be untouched (pure fold).
	if not (profile[Difficulty.CLEARED_KEY] as Array).is_empty():
		return false
	var again: Dictionary = Difficulty.mark_cleared(first["profile"], "sunhaeng")
	return not bool(again["changed"])


func test_apply_scales_schedule_without_mutating_the_source() -> bool:
	var stage: Dictionary = {
		"duration_sec": 400.0, "boss_at_sec": 300.0,
		"soft_enrage": {"start_sec": 320.0, "hp_mult_max": 2.0, "damage_mult_max": 2.0},
		"waves": [
			{"at_sec": 100.0, "monster_id": "forest_goblin", "count": 10},
			{"at_sec": 200.0, "monster_id": "bamboo_brute_elite", "count": 2},
		],
	}
	var tier: Dictionary = {
		"spawn_count_mult": 2.0, "elite_count_mult": 1.0,
		"enemy_hp_mult": 1.5, "enemy_damage_mult": 1.5,
	}
	var length: Dictionary = {"duration_scale": 0.5}
	var scaled: Dictionary = Difficulty.apply(stage, tier, length)

	var timing_ok: bool = absf(float(scaled["duration_sec"]) - 200.0) < EPSILON \
		and absf(float(scaled["boss_at_sec"]) - 150.0) < EPSILON
	var waves: Array = scaled["waves"]
	# Trash takes spawn_count_mult, the elite wave takes elite_count_mult.
	var counts_ok: bool = int(waves[0]["count"]) == 20 and int(waves[1]["count"]) == 2
	var wave_time_ok: bool = absf(float(waves[0]["at_sec"]) - 50.0) < EPSILON
	# The enrage ceiling compounds with the tier.
	var enrage: Dictionary = scaled["soft_enrage"]
	var enrage_ok: bool = absf(float(enrage["hp_mult_max"]) - 3.0) < EPSILON \
		and absf(float(enrage["start_sec"]) - 160.0) < EPSILON
	# Source untouched.
	var pure: bool = absf(float(stage["duration_sec"]) - 400.0) < EPSILON \
		and int((stage["waves"] as Array)[0]["count"]) == 10
	return timing_ok and counts_ok and wave_time_ok and enrage_ok and pure


func test_scale_monster_uses_the_boss_multiplier_for_bosses() -> bool:
	var stats: Dictionary = {"hp": 100.0, "damage": 10.0, "speed": 50.0}
	var tier: Dictionary = {
		"enemy_hp_mult": 2.0, "boss_hp_mult": 3.0,
		"enemy_damage_mult": 1.5, "enemy_speed_mult": 1.1,
	}
	var trash: Dictionary = Difficulty.scale_monster(stats, tier, false)
	var boss: Dictionary = Difficulty.scale_monster(stats, tier, true)
	return absf(float(trash["hp"]) - 200.0) < EPSILON \
		and absf(float(boss["hp"]) - 300.0) < EPSILON \
		and absf(float(trash["damage"]) - 15.0) < EPSILON \
		and absf(float(stats["hp"]) - 100.0) < EPSILON


func test_reward_mult_combines_tier_and_length() -> bool:
	return absf(
		Difficulty.reward_mult({"gold_mult": 2.0}, {"gold_mult": 1.4}, "gold_mult") - 2.8
	) < EPSILON
