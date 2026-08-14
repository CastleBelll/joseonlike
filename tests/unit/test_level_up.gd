extends RefCounted
## Guards the N3-6 power-up choice pool, description formatting and the pure
## apply-one-upgrade transition (LevelUp). Fixture dicts mirror the
## data/weapons.json and data/passives.json field shapes.

const WEAPONS := {
	"talisman": {
		"name_ko": "낡은 부적", "grade": "common", "damage": 12.0,
		"cooldown_sec": 1.2, "speed": 260.0, "max_level": 3,
		"per_level": {"damage": 3.0, "cooldown_sec": -0.05},
		"evolution_only": false,
	},
	"bow": {
		"name_ko": "각궁", "grade": "rare", "damage": 10.0,
		"cooldown_sec": 0.9, "speed": 380.0, "max_level": 3,
		"per_level": {"damage": 2.5, "cooldown_sec": -0.03},
		"evolution_only": false,
	},
	"locked": {
		"name_ko": "봉인검", "grade": "epic", "damage": 20.0,
		"cooldown_sec": 0.8, "speed": 300.0, "max_level": 3,
		"per_level": {"damage": 2.0, "cooldown_sec": -0.02},
		"evolution_only": true,
	},
	"melee": {
		"name_ko": "환도", "grade": "common", "damage": 16.0,
		"cooldown_sec": 0.8, "speed": 0.0, "max_level": 3,
		"per_level": {"damage": 3.5, "cooldown_sec": -0.04},
		"evolution_only": false,
	},
}
const PASSIVES := {
	"attack_damage": {"name_ko": "공격력", "stat": "attack_damage", "per_stack": 0.06, "max_stacks": 2},
	"move_speed": {"name_ko": "이동 속도", "stat": "move_speed", "per_stack": 0.05, "max_stacks": 2},
	"unwired": {"name_ko": "행운", "stat": "luck", "per_stack": 0.05, "max_stacks": 5},
}


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260814
	return rng


func test_pool_never_offers_maxed_weapon() -> bool:
	var pool: Array[Dictionary] = LevelUp.candidates(WEAPONS, {}, {"talisman": 3}, {})
	for choice: Dictionary in pool:
		if choice["kind"] == LevelUp.KIND_WEAPON_UP and choice["id"] == "talisman":
			return false
	return true


func test_pool_never_offers_maxed_passive() -> bool:
	var stacks := {"attack_damage": 2}
	var pool: Array[Dictionary] = LevelUp.candidates({}, PASSIVES, {}, stacks)
	for choice: Dictionary in pool:
		if choice["id"] == "attack_damage":
			return false
	return true


func test_pool_excludes_owned_evolution_and_zero_speed_new_weapons() -> bool:
	var pool: Array[Dictionary] = LevelUp.candidates(WEAPONS, {}, {"talisman": 1}, {})
	var new_ids: Array[String] = []
	for choice: Dictionary in pool:
		if choice["kind"] == LevelUp.KIND_NEW_WEAPON:
			new_ids.append(String(choice["id"]))
	return new_ids == ["bow"]


func test_pool_excludes_unwired_passive_stats() -> bool:
	var pool: Array[Dictionary] = LevelUp.candidates({}, PASSIVES, {}, {})
	for choice: Dictionary in pool:
		if choice["id"] == "unwired":
			return false
	return pool.size() == 2


func test_real_data_pool_offers_nothing_when_everything_maxed() -> bool:
	var weapons: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/weapons.json")
	)
	var passives: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/passives.json")
	)
	var owned: Dictionary = {}
	for weapon_id: String in weapons:
		owned[weapon_id] = int((weapons[weapon_id] as Dictionary)["max_level"])
	var stacks: Dictionary = {}
	for passive_id: String in passives:
		stacks[passive_id] = int((passives[passive_id] as Dictionary)["max_stacks"])
	return LevelUp.candidates(weapons, passives, owned, stacks).is_empty()


func test_pick_three_from_larger_pool_has_no_duplicates() -> bool:
	var pool: Array[Dictionary] = LevelUp.candidates(WEAPONS, PASSIVES, {"talisman": 1}, {})
	var picked: Array[Dictionary] = LevelUp.pick(pool, 3, _rng())
	if picked.size() != 3:
		return false
	for choice: Dictionary in picked:
		if not pool.has(choice):
			return false
	return picked[0] != picked[1] and picked[1] != picked[2] and picked[0] != picked[2]


func test_pick_handles_two_one_and_zero_candidates() -> bool:
	var two: Array[Dictionary] = [
		{"kind": LevelUp.KIND_PASSIVE, "id": "a"}, {"kind": LevelUp.KIND_PASSIVE, "id": "b"}
	]
	var one: Array[Dictionary] = [{"kind": LevelUp.KIND_PASSIVE, "id": "a"}]
	var none: Array[Dictionary] = []
	return (
		LevelUp.pick(two, 3, _rng()).size() == 2
		and LevelUp.pick(one, 3, _rng()).size() == 1
		and LevelUp.pick(none, 3, _rng()).is_empty()
	)


func test_pick_does_not_mutate_pool() -> bool:
	var pool: Array[Dictionary] = [
		{"kind": LevelUp.KIND_PASSIVE, "id": "a"},
		{"kind": LevelUp.KIND_PASSIVE, "id": "b"},
		{"kind": LevelUp.KIND_PASSIVE, "id": "c"},
	]
	var before: Array[Dictionary] = pool.duplicate()
	LevelUp.pick(pool, 2, _rng())
	return pool == before


func test_weapon_stat_scales_with_level() -> bool:
	var stats: Dictionary = WEAPONS["talisman"]
	var damage_ok: bool = (
		is_equal_approx(LevelUp.weapon_stat_at(stats, "damage", 1), 12.0)
		and is_equal_approx(LevelUp.weapon_stat_at(stats, "damage", 3), 18.0)
	)
	return damage_ok and is_equal_approx(LevelUp.weapon_stat_at(stats, "cooldown_sec", 2), 1.15)


func test_describe_weapon_up_shows_real_numbers() -> bool:
	var choice := {"kind": LevelUp.KIND_WEAPON_UP, "id": "talisman"}
	var at_1: String = LevelUp.describe(choice, WEAPONS, {}, {"talisman": 1}, {})
	var at_2: String = LevelUp.describe(choice, WEAPONS, {}, {"talisman": 2}, {})
	return (
		at_1 == "피해 12→15 · 쿨다운 1.2초→1.15초"
		and at_2 == "피해 15→18 · 쿨다운 1.15초→1.1초"
	)


func test_describe_new_weapon_shows_base_stats() -> bool:
	var choice := {"kind": LevelUp.KIND_NEW_WEAPON, "id": "bow"}
	return LevelUp.describe(choice, WEAPONS, {}, {}, {}) == "새 무기 — 피해 10 · 쿨다운 0.9초"


func test_describe_passive_percent_at_several_stacks() -> bool:
	var choice := {"kind": LevelUp.KIND_PASSIVE, "id": "attack_damage"}
	var first: String = LevelUp.describe(choice, {}, PASSIVES, {}, {})
	var second: String = LevelUp.describe(choice, {}, PASSIVES, {}, {"attack_damage": 1})
	return first == "공격력 +6% (1/2)" and second == "공격력 +6% (2/2)"


func test_describe_passive_flat_amount() -> bool:
	var passives := {
		"projectile_count": {"name_ko": "다중 투사", "per_stack": 1.0, "max_stacks": 2}
	}
	var choice := {"kind": LevelUp.KIND_PASSIVE, "id": "projectile_count"}
	return LevelUp.describe(choice, {}, passives, {}, {}) == "다중 투사 +1 (1/2)"


func test_apply_weapon_up_bumps_exactly_that_weapon() -> bool:
	var choice := {"kind": LevelUp.KIND_WEAPON_UP, "id": "talisman"}
	var result: Dictionary = LevelUp.apply_choice(choice, {"talisman": 1, "bow": 2}, {"move_speed": 1})
	var owned: Dictionary = result["owned_levels"]
	var stacks: Dictionary = result["passive_stacks"]
	return owned == {"talisman": 2, "bow": 2} and stacks == {"move_speed": 1}


func test_apply_new_weapon_adds_at_level_one() -> bool:
	var choice := {"kind": LevelUp.KIND_NEW_WEAPON, "id": "bow"}
	var result: Dictionary = LevelUp.apply_choice(choice, {"talisman": 1}, {})
	return result["owned_levels"] == {"talisman": 1, "bow": 1}


func test_apply_passive_adds_exactly_one_stack() -> bool:
	var choice := {"kind": LevelUp.KIND_PASSIVE, "id": "attack_damage"}
	var result: Dictionary = LevelUp.apply_choice(choice, {"talisman": 1}, {"attack_damage": 1})
	var untouched: bool = result["owned_levels"] == {"talisman": 1}
	return untouched and result["passive_stacks"] == {"attack_damage": 2}


func test_apply_choice_does_not_mutate_inputs() -> bool:
	var owned := {"talisman": 1}
	var stacks := {"attack_damage": 1}
	LevelUp.apply_choice({"kind": LevelUp.KIND_PASSIVE, "id": "attack_damage"}, owned, stacks)
	return owned == {"talisman": 1} and stacks == {"attack_damage": 1}


func test_grade_pill_text_from_data() -> bool:
	var common: String = LevelUp.grade_text({"kind": LevelUp.KIND_NEW_WEAPON, "id": "talisman"}, WEAPONS)
	var rare: String = LevelUp.grade_text({"kind": LevelUp.KIND_NEW_WEAPON, "id": "bow"}, WEAPONS)
	var epic: String = LevelUp.grade_text({"kind": LevelUp.KIND_WEAPON_UP, "id": "locked"}, WEAPONS)
	var passive: String = LevelUp.grade_text({"kind": LevelUp.KIND_PASSIVE, "id": "attack_damage"}, WEAPONS)
	return common == "일반" and rare == "희귀" and epic == "영웅" and passive == "일반"


func test_well_label_next_level_and_new() -> bool:
	var up := {"kind": LevelUp.KIND_WEAPON_UP, "id": "talisman"}
	var fresh := {"kind": LevelUp.KIND_NEW_WEAPON, "id": "bow"}
	var passive := {"kind": LevelUp.KIND_PASSIVE, "id": "attack_damage"}
	return (
		LevelUp.well_label(up, {"talisman": 1}, {}) == "Lv.2"
		and LevelUp.well_label(fresh, {"talisman": 1}, {}) == "신규!"
		and LevelUp.well_label(passive, {}, {}) == "신규!"
		and LevelUp.well_label(passive, {}, {"attack_damage": 1}) == "Lv.2"
	)
