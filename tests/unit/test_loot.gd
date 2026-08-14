extends RefCounted
## Guards the N4-1 pure loot helpers: seeded drop rolling, run inventory
## transitions, mod recipe lookup with its waste-guards, salvage math and the
## special-material choice list. Fixture dicts mirror data/loot.json,
## data/drop_tables.json and data/weapon_mods.json field shapes.

const SAMPLE_ROLLS := 10000
const CHANCE_TOLERANCE := 0.03

const LOOT := {
	"bamboo": {
		"name_ko": "대나무", "tier": "common", "special": false, "salvage_gold": 2
	},
	"whetstone": {
		"name_ko": "숫돌", "tier": "rare", "special": true, "salvage_gold": 8
	},
	"fire_stone": {
		"name_ko": "화령석", "tier": "epic", "special": true, "salvage_gold": 15
	},
}
const WEAPONS := {
	"sword": {"name_ko": "환도"},
	"sharp_sword": {"name_ko": "예리한 환도"},
	"talisman": {"name_ko": "낡은 부적"},
	"fire_talisman": {"name_ko": "화염 부적"},
}
const MODS := {
	"sharp_sword_mod": {
		"weapon_id": "sword", "loot_id": "whetstone", "result_weapon": "sharp_sword"
	},
	"fire_talisman_mod": {
		"weapon_id": "talisman", "loot_id": "fire_stone", "result_weapon": "fire_talisman"
	},
}


func _rng(seed_value: int = 20260814) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_roll_is_deterministic_per_seed() -> bool:
	var table := {"drops": [
		{"loot_id": "bamboo", "chance": 0.5},
		{"loot_id": "whetstone", "chance": 0.5},
		{"loot_id": "fire_stone", "chance": 0.5},
	]}
	var first: Array[String] = []
	var second: Array[String] = []
	var rng_a := _rng()
	var rng_b := _rng()
	for i: int in range(50):
		first.append_array(Loot.roll_drops(table, rng_a))
		second.append_array(Loot.roll_drops(table, rng_b))
	return first == second and not first.is_empty()


func test_roll_respects_chances_over_large_sample() -> bool:
	var table := {"drops": [{"loot_id": "bamboo", "chance": 0.1}]}
	var rng := _rng()
	var hits: int = 0
	for i: int in range(SAMPLE_ROLLS):
		hits += Loot.roll_drops(table, rng).size()
	var rate: float = float(hits) / float(SAMPLE_ROLLS)
	return absf(rate - 0.1) < CHANCE_TOLERANCE


func test_roll_certain_chance_always_drops() -> bool:
	var rng := _rng()
	var always := {"drops": [{"loot_id": "fire_stone", "chance": 1.0}]}
	for i: int in range(100):
		var dropped: Array[String] = Loot.roll_drops(always, rng)
		if dropped != ["fire_stone"]:
			return false
	return true


func test_inventory_add_is_immutable_and_counts() -> bool:
	var empty: Dictionary = {}
	var one: Dictionary = Loot.add(empty, "bamboo")
	var three: Dictionary = Loot.add(one, "bamboo", 2)
	return empty.is_empty() and int(one["bamboo"]) == 1 and int(three["bamboo"]) == 3


func test_inventory_spend_erases_at_zero() -> bool:
	var two: Dictionary = Loot.add(Loot.add({}, "bamboo"), "bamboo")
	var one: Dictionary = Loot.spend(two, "bamboo")
	var none: Dictionary = Loot.spend(one, "bamboo")
	return int(one["bamboo"]) == 1 and not none.has("bamboo") and int(two["bamboo"]) == 2


func test_usable_mods_requires_owned_base() -> bool:
	return Loot.usable_mods(MODS, "whetstone", {"talisman": 3}).is_empty()


func test_usable_mods_excludes_owned_result() -> bool:
	var owned := {"sword": 2, "sharp_sword": 1}
	return Loot.usable_mods(MODS, "whetstone", owned).is_empty()


func test_usable_mods_matches_owned_base() -> bool:
	var matches: Array[Dictionary] = Loot.usable_mods(MODS, "whetstone", {"sword": 4})
	return matches.size() == 1 and String(matches[0]["result_weapon"]) == "sharp_sword"


func test_salvage_gold_math() -> bool:
	return (
		Loot.salvage_gold(LOOT, "fire_stone") == 15
		and Loot.salvage_gold(LOOT, "bamboo") == 2
		and Loot.salvage_gold(LOOT, "unknown") == 0
	)


func test_choices_have_three_cards_with_recipe() -> bool:
	var choices: Array[Dictionary] = Loot.build_choices("whetstone", MODS, {"sword": 1})
	var kinds: Array[String] = []
	for choice: Dictionary in choices:
		kinds.append(String(choice["kind"]))
	return kinds == [Loot.KIND_USE, Loot.KIND_KEEP, Loot.KIND_SALVAGE]


func test_choices_hide_use_without_recipe() -> bool:
	var choices: Array[Dictionary] = Loot.build_choices("whetstone", MODS, {"talisman": 1})
	var kinds: Array[String] = []
	for choice: Dictionary in choices:
		kinds.append(String(choice["kind"]))
	return kinds == [Loot.KIND_KEEP, Loot.KIND_SALVAGE]


func test_apply_mod_swaps_weapon_and_carries_level() -> bool:
	var owned := {"sword": 5, "talisman": 2}
	var updated: Dictionary = Loot.apply_mod(owned, MODS["sharp_sword_mod"])
	return (
		not updated.has("sword")
		and int(updated["sharp_sword"]) == 5
		and int(updated["talisman"]) == 2
		and int(owned["sword"]) == 5
	)


func test_use_card_names_the_transformation() -> bool:
	var choice := {
		"kind": Loot.KIND_USE, "loot_id": "fire_stone",
		"mod": MODS["fire_talisman_mod"],
	}
	var card: Dictionary = Loot.as_card(choice, LOOT, WEAPONS, {})
	return (
		String(card["desc"]).contains("낡은 부적")
		and String(card["desc"]).contains("화염 부적")
		and card["payload"] == choice
	)


func test_salvage_card_shows_real_gold() -> bool:
	var choice := {"kind": Loot.KIND_SALVAGE, "loot_id": "fire_stone"}
	var card: Dictionary = Loot.as_card(choice, LOOT, WEAPONS, {})
	return String(card["desc"]).contains("15") and String(card["grade"]) == "영웅"


func test_level_up_card_carries_display_fields() -> bool:
	var weapons := {
		"talisman": {
			"name_ko": "낡은 부적", "grade": "common", "damage": 12.0,
			"cooldown_sec": 1.2, "per_level": {"damage": 3.0, "cooldown_sec": -0.05},
		}
	}
	var card: Dictionary = LevelUp.as_card(
		{"kind": LevelUp.KIND_WEAPON_UP, "id": "talisman"}, weapons, {}, {"talisman": 1}, {}
	)
	return (
		String(card["name"]) == "낡은 부적"
		and String(card["well_label"]) == "Lv.2"
		and not String(card["desc"]).is_empty()
	)
