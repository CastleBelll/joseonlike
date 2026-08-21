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


# N4-6 mod-card fixtures: one recipe joining the talisman to its rare result.
const MOD_WEAPONS := {
	"talisman": {
		"name_ko": "낡은 부적", "grade": "common", "damage": 12.0,
		"cooldown_sec": 1.2, "speed": 260.0, "max_level": 8,
		"per_level": {"damage": 3.0, "cooldown_sec": -0.05},
		"evolution_only": false,
	},
	"fire_talisman": {
		"name_ko": "화염 부적", "grade": "rare", "damage": 18.0,
		"cooldown_sec": 1.1, "speed": 260.0, "max_level": 8,
		"per_level": {"damage": 4.0, "cooldown_sec": -0.05},
		"evolution_only": true,
	},
}
const MODS := {
	"fire_mod": {
		"weapon_id": "talisman", "loot_id": "fire_stone",
		"result_weapon": "fire_talisman",
	},
	"sword_mod": {
		"weapon_id": "sword", "loot_id": "whetstone", "result_weapon": "sharp_sword"
	},
}
const GRADES := {
	"ladder": ["common", "rare"],
	"steps": {"rare": {"mult": {"damage": 2.0}}},
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
		if weapon_id.begins_with("_"):
			continue  # reserved config keys (N4-2 "_grades") are not weapons
		owned[weapon_id] = int((weapons[weapon_id] as Dictionary)["max_level"])
	var stacks: Dictionary = {}
	for passive_id: String in passives:
		stacks[passive_id] = int((passives[passive_id] as Dictionary)["max_stacks"])
	return LevelUp.candidates(weapons, passives, owned, stacks).is_empty()


## N4-6 regression (owner-reported): a weapon replaced by a mod must be out
## of BOTH the new-weapon pool and the upgrade pool for the rest of the run.
func test_replaced_weapon_out_of_new_weapon_pool() -> bool:
	# talisman is unowned with speed > 0 — without the replaced guard it would
	# come straight back as a new-weapon card after the mod swapped it away.
	var pool: Array[Dictionary] = LevelUp.candidates(
		WEAPONS, {}, {"bow": 1}, {}, {}, {}, ["talisman"]
	)
	for choice: Dictionary in pool:
		if String(choice["id"]) == "talisman":
			return false
	return true


func test_replaced_weapon_out_of_upgrade_pool() -> bool:
	var pool: Array[Dictionary] = LevelUp.candidates(
		WEAPONS, {}, {"talisman": 1}, {}, {}, {}, ["talisman"]
	)
	for choice: Dictionary in pool:
		if String(choice["id"]) == "talisman":
			return false
	return true


func test_mod_candidates_need_material_and_owned_base() -> bool:
	var with_both: Array[Dictionary] = LevelUp.mod_candidates(
		MODS, {"fire_stone": 1}, {"talisman": 2}
	)
	var no_material: Array[Dictionary] = LevelUp.mod_candidates(MODS, {}, {"talisman": 2})
	var no_base: Array[Dictionary] = LevelUp.mod_candidates(MODS, {"fire_stone": 1}, {"bow": 1})
	return (
		with_both.size() == 1
		and String(with_both[0]["id"]) == "fire_mod"
		and no_material.is_empty()
		and no_base.is_empty()
	)


func test_mod_candidates_exclude_owned_or_replaced_result() -> bool:
	var result_owned: Array[Dictionary] = LevelUp.mod_candidates(
		MODS, {"fire_stone": 1}, {"talisman": 2, "fire_talisman": 1}
	)
	var result_replaced: Array[Dictionary] = LevelUp.mod_candidates(
		MODS, {"fire_stone": 1}, {"talisman": 2}, ["fire_talisman"]
	)
	return result_owned.is_empty() and result_replaced.is_empty()


## N4-9: a recipe with level_required only fires once the base weapon reached
## that milestone; the FTUE waiver bypasses the gate on the scripted first run.
func test_mod_candidates_respect_level_required() -> bool:
	var gated := {"fire_mod": {
		"weapon_id": "talisman", "loot_id": "fire_stone",
		"result_weapon": "fire_talisman", "level_required": 3,
	}}
	var too_low: Array[Dictionary] = LevelUp.mod_candidates(
		gated, {"fire_stone": 1}, {"talisman": 2}
	)
	var at_level: Array[Dictionary] = LevelUp.mod_candidates(
		gated, {"fire_stone": 1}, {"talisman": 3}
	)
	var waived: Array[Dictionary] = LevelUp.mod_candidates(
		gated, {"fire_stone": 1}, {"talisman": 1}, [], true
	)
	return too_low.is_empty() and at_level.size() == 1 and waived.size() == 1


## N4-9 soft-lock guard: when the only usable mod is level-gated, the screen
## still fills with regular cards — the gate removes one card, never the pool.
func test_level_gated_mod_leaves_pool_full() -> bool:
	var gated := {"fire_mod": {
		"weapon_id": "talisman", "loot_id": "fire_stone",
		"result_weapon": "fire_talisman", "level_required": 3,
	}}
	var mod_pool: Array[Dictionary] = LevelUp.mod_candidates(
		gated, {"fire_stone": 1}, {"talisman": 1}
	)
	var pool: Array[Dictionary] = LevelUp.candidates(WEAPONS, PASSIVES, {"talisman": 1}, {})
	var cards: Array[Dictionary] = LevelUp.assemble(pool, mod_pool, 3, _rng())
	for card: Dictionary in cards:
		if String(card["kind"]) == LevelUp.KIND_MOD:
			return false
	return mod_pool.is_empty() and cards.size() == 3


## N4-9: every shipping recipe must gate on a reachable milestone level.
func test_real_data_mods_all_gate_on_a_milestone() -> bool:
	var weapons: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/weapons.json")
	)
	var mods: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/weapon_mods.json")
	)
	for mod_id: String in mods:
		var mod: Dictionary = mods[mod_id]
		var base: Dictionary = weapons.get(String(mod.get("weapon_id", "")), {})
		var required: int = int(mod.get("level_required", 0))
		if required < 2 or required > int(base.get("max_level", 0)):
			return false
		var milestones: Dictionary = base.get("milestones", {})
		if not milestones.is_empty() and not milestones.has(str(required)):
			return false
	return true


## N4-9 knowledge rule: an unrecorded mod result shows as ??? with no numbers,
## no mechanic and no result icon — the recipe is legible only once performed.
func test_mod_card_masks_unrecorded_result() -> bool:
	var choice := {"kind": LevelUp.KIND_MOD, "id": "fire_mod", "mod": MODS["fire_mod"]}
	var masked: Dictionary = LevelUp.as_card(
		choice, MOD_WEAPONS, {}, {"talisman": 1}, {}, {}, GRADES, ["fire_talisman"]
	)
	var known: Dictionary = LevelUp.as_card(
		choice, MOD_WEAPONS, {}, {"talisman": 1}, {}, {}, GRADES, []
	)
	return (
		String(masked["desc"]) == "낡은 부적 → ??? (레벨 유지)"
		and String(masked["icon_weapon_id"]).is_empty()
		and String(masked["icon_loot_id"]) == "fire_stone"
		and String(known["desc"]).contains("화염 부적")
		and String(known["icon_weapon_id"]) == "fire_talisman"
	)


func test_assemble_keeps_at_most_one_mod_card_and_fills_three() -> bool:
	var pool: Array[Dictionary] = LevelUp.candidates(WEAPONS, PASSIVES, {"talisman": 1}, {})
	var mod_pool: Array[Dictionary] = [
		{"kind": LevelUp.KIND_MOD, "id": "fire_mod", "mod": MODS["fire_mod"]},
		{"kind": LevelUp.KIND_MOD, "id": "sword_mod", "mod": MODS["sword_mod"]},
	]
	var cards: Array[Dictionary] = LevelUp.assemble(pool, mod_pool, 3, _rng())
	var mod_count: int = 0
	for card: Dictionary in cards:
		if String(card["kind"]) == LevelUp.KIND_MOD:
			mod_count += 1
	return cards.size() == 3 and mod_count == 1


func test_assemble_without_mods_is_plain_pick() -> bool:
	var pool: Array[Dictionary] = LevelUp.candidates(WEAPONS, PASSIVES, {"talisman": 1}, {})
	var cards: Array[Dictionary] = LevelUp.assemble(pool, [], 3, _rng())
	for card: Dictionary in cards:
		if String(card["kind"]) == LevelUp.KIND_MOD:
			return false
	return cards.size() == 3


func test_mod_card_reads_like_the_old_popup() -> bool:
	var choice := {"kind": LevelUp.KIND_MOD, "id": "fire_mod", "mod": MODS["fire_mod"]}
	var card: Dictionary = LevelUp.as_card(
		choice, MOD_WEAPONS, {}, {"talisman": 1}, {}, {}, GRADES
	)
	# Result damage 18 stays flat: the carried grade equals its own base rung.
	return (
		String(card["name"]) == "개조"
		and String(card["desc"]) == "낡은 부적 → 화염 부적 · 피해 12→18 (레벨 유지)"
		and String(card["grade"]) == "희귀"
		and String(card["well_label"]) == "변신!"
		and card["payload"] == choice
	)


func test_pick_three_from_larger_pool_has_no_duplicates() -> bool:
	var pool: Array[Dictionary] = LevelUp.candidates(WEAPONS, PASSIVES, {"talisman": 1}, {})
	var picked: Array[Dictionary] = LevelUp.pick(pool, 3, _rng())
	if picked.size() != 3:
		return false
	for choice: Dictionary in picked:
		if not pool.has(choice):
			return false
	return picked[0] != picked[1] and picked[1] != picked[2] and picked[0] != picked[2]


## N4-7: the pool legitimately holds a level card AND a grade card for the
## same weapon — one screen must still never show the same weapon twice, by
## construction, not by shuffle luck.
func test_pick_never_yields_two_cards_for_the_same_weapon() -> bool:
	# Built by hand rather than via candidates(): since N9-28 gated grade behind
	# max level, candidates() no longer produces a level+grade collision for one
	# weapon — and the rule under test belongs to pick() (one card per subject
	# id), whatever put two of them in the pool.
	var pool: Array[Dictionary] = [
		{"kind": LevelUp.KIND_WEAPON_UP, "id": "talisman"},
		{"kind": LevelUp.KIND_GRADE_UP, "id": "talisman"},
		{"kind": LevelUp.KIND_NEW_WEAPON, "id": "bow"},
		{"kind": LevelUp.KIND_PASSIVE, "id": "attack_damage"},
		{"kind": LevelUp.KIND_PASSIVE, "id": "move_speed"},
	]
	var rng := _rng()
	for _attempt: int in range(200):
		var seen: Array[String] = []
		for choice: Dictionary in LevelUp.pick(pool, 3, rng):
			for id: String in LevelUp.subject_ids(choice):
				if seen.has(id):
					return false
				seen.append(id)
	return true


## N4-7: the 개조 card already shows its base weapon — the fill picks must not
## show that weapon (or the result) again on the same screen.
func test_assemble_never_repeats_the_mod_cards_weapons() -> bool:
	var pool: Array[Dictionary] = LevelUp.candidates(
		WEAPONS, PASSIVES, {"talisman": 1}, {}, {"talisman": "common"}, GRADES
	)
	var mod_pool: Array[Dictionary] = [
		{"kind": LevelUp.KIND_MOD, "id": "fire_mod", "mod": MODS["fire_mod"]},
	]
	var rng := _rng()
	for _attempt: int in range(200):
		var cards: Array[Dictionary] = LevelUp.assemble(pool, mod_pool, 3, rng)
		for card: Dictionary in cards.slice(1):
			if String(card["id"]) == "talisman" or String(card["id"]) == "fire_talisman":
				return false
	return true


## N4-7 (owner-reported): every weapon_mods.json result must stay out of the
## new-weapon pool — mod results are obtainable only through their recipe.
func test_real_data_mod_results_never_offered_as_new_weapons() -> bool:
	var weapons: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/weapons.json")
	)
	var mods: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/weapon_mods.json")
	)
	var result_ids: Array[String] = []
	for mod_id: String in mods:
		result_ids.append(String((mods[mod_id] as Dictionary).get("result_weapon", "")))
	var pool: Array[Dictionary] = LevelUp.candidates(weapons, {}, {}, {})
	for choice: Dictionary in pool:
		if String(choice["kind"]) == LevelUp.KIND_NEW_WEAPON \
				and result_ids.has(String(choice["id"])):
			push_error("test_level_up: mod result offered as new weapon: " + String(choice["id"]))
			return false
	return true


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
	var mechanic_line: String = Bestiary.mechanic_line("straight", "ko")
	return (
		at_1 == "%s · 피해 12→15 · 쿨다운 1.2초→1.15초" % mechanic_line
		and at_2 == "%s · 피해 15→18 · 쿨다운 1.15초→1.1초" % mechanic_line
	)


func test_describe_new_weapon_shows_base_stats() -> bool:
	var choice := {"kind": LevelUp.KIND_NEW_WEAPON, "id": "bow"}
	var mechanic_line: String = Bestiary.mechanic_line("straight", "ko")
	return LevelUp.describe(choice, WEAPONS, {}, {}, {}) == "%s — 피해 10 · 쿨다운 0.9초" % mechanic_line


func test_describe_passive_percent_at_several_stacks() -> bool:
	# N9-105: the body leads with the desc (what the % touches); a fixture
	# without one falls back to the name so the card is never blank.
	var choice := {"kind": LevelUp.KIND_PASSIVE, "id": "attack_damage"}
	var first: String = LevelUp.describe(choice, {}, PASSIVES, {}, {})
	var second: String = LevelUp.describe(choice, {}, PASSIVES, {}, {"attack_damage": 1})
	return first == "공격력 — +6% (1/2)" and second == "공격력 — +6% (2/2)"


func test_describe_passive_flat_amount() -> bool:
	var passives := {
		"projectile_count": {"name_ko": "다중 투사", "per_stack": 1.0, "max_stacks": 2}
	}
	var choice := {"kind": LevelUp.KIND_PASSIVE, "id": "projectile_count"}
	return LevelUp.describe(choice, {}, passives, {}, {}) == "다중 투사 — +1 (1/2)"


func test_mechanic_passives_need_a_customer_weapon() -> bool:
	# N9-110 (owner: 연쇄 확장 같은 건 한 기술에 국한돼 잘 안 쓴다): a
	# mechanic-bound passive only appears while an owned weapon can use it.
	var weapons := {
		"sword": {"max_level": 8},
		"noebu": {"max_level": 8, "chain": {"jumps": 2}},
	}
	var passives := {
		"chain_amount": {"name_ko": "연쇄 확장", "per_stack": 1.0, "max_stacks": 2},
		"attack_damage": {"name_ko": "공격력", "per_stack": 0.06, "max_stacks": 5},
	}
	var no_chain: Array[Dictionary] = LevelUp.candidates(weapons, passives, {"sword": 1}, {})
	for choice: Dictionary in no_chain:
		if String(choice.get("id", "")) == "chain_amount":
			push_error("test_level_up: chain_amount offered with no chain weapon owned")
			return false
	var with_chain: Array[Dictionary] = LevelUp.candidates(weapons, passives, {"noebu": 1}, {})
	var offered: bool = false
	for choice: Dictionary in with_chain:
		if String(choice.get("id", "")) == "chain_amount":
			offered = true
	if not offered:
		push_error("test_level_up: chain_amount missing despite an owned chain weapon")
		return false
	# An invested stack keeps growing even after a mod swaps the weapon away.
	var stacked: Array[Dictionary] = LevelUp.candidates(
		weapons, passives, {"sword": 1}, {"chain_amount": 1}
	)
	for choice: Dictionary in stacked:
		if String(choice.get("id", "")) == "chain_amount":
			return true
	push_error("test_level_up: a stacked chain_amount stopped being offered")
	return false


func test_burn_passive_needs_a_burn_weapon() -> bool:
	var weapons := {
		"sword": {"max_level": 8},
		"honbul": {"max_level": 8, "on_hit_status": {"id": "burn", "dps": 4.0}},
	}
	var passives := {
		"burn_power": {"name_ko": "불씨 정통", "per_stack": 0.2, "max_stacks": 3},
	}
	var without: Array[Dictionary] = LevelUp.candidates(weapons, passives, {"sword": 1}, {})
	for choice: Dictionary in without:
		if String(choice.get("id", "")) == "burn_power":
			push_error("test_level_up: burn_power offered with nothing that burns")
			return false
	var with_burn: Array[Dictionary] = LevelUp.candidates(weapons, passives, {"honbul": 1}, {})
	for choice: Dictionary in with_burn:
		if String(choice.get("id", "")) == "burn_power":
			return true
	push_error("test_level_up: burn_power missing despite an owned burn weapon")
	return false


func test_describe_passive_leads_with_its_desc() -> bool:
	# N9-105 (owner: a bare % never says what it touches): with a desc in
	# data the body explains the effect instead of repeating the title.
	var passives := {
		"area_scale": {
			"name_ko": "광역 확장", "desc_ko": "폭발·장판·파동의 반경이 넓어진다",
			"per_stack": 0.08, "max_stacks": 5,
		}
	}
	var choice := {"kind": LevelUp.KIND_PASSIVE, "id": "area_scale"}
	var line: String = LevelUp.describe(choice, {}, passives, {}, {})
	return line == "폭발·장판·파동의 반경이 넓어진다 — +8% (1/5)"


func test_apply_weapon_up_bumps_exactly_that_weapon() -> bool:
	var choice := {"kind": LevelUp.KIND_WEAPON_UP, "id": "talisman"}
	var result: Dictionary = LevelUp.apply_choice(choice, {"talisman": 1, "bow": 2}, {"move_speed": 1})
	var owned: Dictionary = result["owned_levels"]
	var stacks: Dictionary = result["passive_stacks"]
	# N9-20: a level card is worth LEVEL_STEP weapon levels.
	return owned == {"talisman": 1 + LevelUp.LEVEL_STEP, "bow": 2} 		and stacks == {"move_speed": 1}


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


func test_grade_id_matches_pill_text_source() -> bool:
	# Arrange: the same choices the pill-text test reads.
	var weapon := {"kind": LevelUp.KIND_NEW_WEAPON, "id": "bow"}
	var passive := {"kind": LevelUp.KIND_PASSIVE, "id": "attack_damage"}
	# Act
	var rare: String = LevelUp.grade_id(weapon, WEAPONS)
	var common: String = LevelUp.grade_id(passive, WEAPONS)
	var display: Dictionary = LevelUp.as_card(weapon, WEAPONS, PASSIVES, {}, {})
	# Assert: the id drives the pill tint and rides along on the display dict.
	return rare == "rare" and common == "common" and String(display.get("grade_id", "")) == "rare"


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


func test_card_icon_ids_bind_by_kind() -> bool:
	# N3-13: weapon kinds bind their own id, the mod card binds the result
	# weapon plus its consumed material, passives bind nothing (letter glyph).
	var weapon_card: Dictionary = LevelUp.as_card(
		{"kind": LevelUp.KIND_WEAPON_UP, "id": "talisman"}, WEAPONS, PASSIVES,
		{"talisman": 1}, {}
	)
	var passive_card: Dictionary = LevelUp.as_card(
		{"kind": LevelUp.KIND_PASSIVE, "id": "attack_damage"}, WEAPONS, PASSIVES, {}, {}
	)
	var mod_card: Dictionary = LevelUp.as_card(
		{"kind": LevelUp.KIND_MOD, "id": "fire_mod", "mod": MODS["fire_mod"]},
		MOD_WEAPONS, {}, {"talisman": 1}, {}
	)
	var passed: bool = String(weapon_card["icon_weapon_id"]) == "talisman"
	passed = passed and String(weapon_card["icon_loot_id"]) == ""
	passed = passed and String(passive_card["icon_weapon_id"]) == ""
	passed = passed and String(mod_card["icon_weapon_id"]) == "fire_talisman"
	passed = passed and String(mod_card["icon_loot_id"]) == "fire_stone"
	if not passed:
		push_error("test_level_up: card icon ids broken")
	return passed


# --- N4-8 milestone growth ---

const MILESTONE_WEAPON := {
	"name_ko": "시험 뇌부", "grade": "common", "mechanic": "chain",
	"damage": 7.0, "cooldown_sec": 1.4, "projectile_count": 1,
	"max_level": 8,
	"per_level": {"damage": 2.6, "cooldown_sec": -0.05},
	"chain": {"jumps": 3, "falloff": 0.7, "range_px": 150.0},
	"milestones": {
		"3": {"chain": {"jumps": 1}},
		"8": {"chain": {"jumps": 2, "falloff": 0.05}, "projectile_count": 1},
	},
}


func test_stats_at_level_below_first_milestone_is_base() -> bool:
	var stats: Dictionary = LevelUp.stats_at_level(MILESTONE_WEAPON, 2)
	return int((stats["chain"] as Dictionary)["jumps"]) == 3 \
		and int(stats.get("projectile_count", 1)) == 1


func test_stats_at_level_merges_cumulatively_and_additively() -> bool:
	var mid: Dictionary = LevelUp.stats_at_level(MILESTONE_WEAPON, 3)
	var top: Dictionary = LevelUp.stats_at_level(MILESTONE_WEAPON, 8)
	return int((mid["chain"] as Dictionary)["jumps"]) == 4 \
		and int((top["chain"] as Dictionary)["jumps"]) == 6 \
		and absf(float((top["chain"] as Dictionary)["falloff"]) - 0.75) < 0.001 \
		and int(top["projectile_count"]) == 2


func test_stats_at_level_does_not_mutate_the_source() -> bool:
	var _top: Dictionary = LevelUp.stats_at_level(MILESTONE_WEAPON, 8)
	return int((MILESTONE_WEAPON["chain"] as Dictionary)["jumps"]) == 3


func test_milestone_delta_hits_only_the_exact_level() -> bool:
	return not LevelUp.milestone_delta(MILESTONE_WEAPON, 3).is_empty() \
		and LevelUp.milestone_delta(MILESTONE_WEAPON, 4).is_empty()


func test_milestone_text_renders_known_fields() -> bool:
	var text: String = LevelUp.milestone_text(
		LevelUp.milestone_delta(MILESTONE_WEAPON, 8)
	)
	return text.contains("연쇄") and text.contains("투사체")


func test_describe_marks_a_milestone_level_up_card() -> bool:
	var weapons: Dictionary = {"test_chain": MILESTONE_WEAPON}
	var choice: Dictionary = {"kind": LevelUp.KIND_WEAPON_UP, "id": "test_chain"}
	var marked: String = LevelUp.describe(
		choice, weapons, {}, {"test_chain": 2}, {}
	)
	var plain: String = LevelUp.describe(
		choice, weapons, {}, {"test_chain": 3}, {}
	)
	return marked.contains(LevelUp.MILESTONE_MARK) \
		and not plain.contains(LevelUp.MILESTONE_MARK)


# N9-23 build slots: the pool must stop offering NEW weapons and NEW passives
# once the build is full, which is what lets a focused player actually reach
# the level-5 개조 gate instead of being handed a grab bag.
const SLOT_WEAPONS := {
	"w1": {"name_ko": "1", "damage": 5.0, "cooldown_sec": 1.0, "speed": 200.0, "max_level": 8},
	"w2": {"name_ko": "2", "damage": 5.0, "cooldown_sec": 1.0, "speed": 200.0, "max_level": 8},
	"w3": {"name_ko": "3", "damage": 5.0, "cooldown_sec": 1.0, "speed": 200.0, "max_level": 8},
	"w4": {"name_ko": "4", "damage": 5.0, "cooldown_sec": 1.0, "speed": 200.0, "max_level": 8},
	"w5": {"name_ko": "5", "damage": 5.0, "cooldown_sec": 1.0, "speed": 200.0, "max_level": 8},
	"w6": {"name_ko": "6", "damage": 5.0, "cooldown_sec": 1.0, "speed": 200.0, "max_level": 8},
}
const SLOT_PASSIVES := {
	"attack_damage": {"name_ko": "a", "stat": "attack_damage", "per_stack": 0.05, "max_stacks": 5},
	"move_speed": {"name_ko": "b", "stat": "move_speed", "per_stack": 0.05, "max_stacks": 5},
	"max_hp": {"name_ko": "c", "stat": "max_hp", "per_stack": 0.05, "max_stacks": 5},
	"magnet_radius": {"name_ko": "d", "stat": "magnet_radius", "per_stack": 0.05, "max_stacks": 5},
	"luck": {"name_ko": "e", "stat": "luck", "per_stack": 0.05, "max_stacks": 5},
}


func _kinds(pool: Array[Dictionary], kind: String) -> Array[String]:
	var ids: Array[String] = []
	for choice: Dictionary in pool:
		if String(choice["kind"]) == kind:
			ids.append(String(choice["id"]))
	return ids


func test_new_weapons_are_offered_while_a_slot_is_free() -> bool:
	var owned := {"w1": 1, "w2": 1, "w3": 1}
	var pool: Array[Dictionary] = LevelUp.candidates(
		SLOT_WEAPONS, SLOT_PASSIVES, owned, {}
	)
	# Three owned, one slot left: the three unowned weapons are all on offer.
	return _kinds(pool, LevelUp.KIND_NEW_WEAPON).size() == 3


func test_a_full_weapon_build_stops_offering_new_weapons() -> bool:
	var owned := {"w1": 1, "w2": 1, "w3": 1, "w4": 1}
	var pool: Array[Dictionary] = LevelUp.candidates(
		SLOT_WEAPONS, SLOT_PASSIVES, owned, {}
	)
	if not _kinds(pool, LevelUp.KIND_NEW_WEAPON).is_empty():
		return false
	# ...but every owned weapon still has somewhere to go, or the screen would
	# be empty at exactly the moment the player is meant to be investing.
	return _kinds(pool, LevelUp.KIND_WEAPON_UP).size() == 4


func test_a_full_passive_build_still_grows_the_passives_it_has() -> bool:
	var stacks := {"attack_damage": 1, "move_speed": 1, "max_hp": 1, "magnet_radius": 1}
	var pool: Array[Dictionary] = LevelUp.candidates(
		SLOT_WEAPONS, SLOT_PASSIVES, {"w1": 1}, stacks
	)
	var offered: Array[String] = _kinds(pool, LevelUp.KIND_PASSIVE)
	# The fifth passive is locked out; the four taken ones keep climbing.
	return offered.size() == 4 and not offered.has("luck")


func test_a_zero_stack_passive_does_not_consume_a_slot() -> bool:
	# A passive that was offered and never taken can linger at 0 in the dict;
	# counting it would silently shrink the build by one.
	var stacks := {"attack_damage": 1, "move_speed": 0, "max_hp": 0, "magnet_radius": 0}
	var pool: Array[Dictionary] = LevelUp.candidates(
		SLOT_WEAPONS, SLOT_PASSIVES, {"w1": 1}, stacks
	)
	return _kinds(pool, LevelUp.KIND_PASSIVE).size() == 5


func test_a_maxed_full_build_reopens_the_slots_instead_of_going_blank() -> bool:
	# Four weapons at max level with no grade ladder, four passives at max
	# stacks: without the reopen the player would face an empty screen.
	var owned := {"w1": 8, "w2": 8, "w3": 8, "w4": 8}
	var stacks := {"attack_damage": 5, "move_speed": 5, "max_hp": 5, "magnet_radius": 5}
	var pool: Array[Dictionary] = LevelUp.candidates(
		SLOT_WEAPONS, SLOT_PASSIVES, owned, stacks
	)
	return not pool.is_empty()
