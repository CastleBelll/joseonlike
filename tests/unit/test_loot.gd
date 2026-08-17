extends RefCounted
## Guards the pure loot helpers: seeded drop rolling, run inventory
## transitions, salvage math and the N4-6 silent-pickup rules (useful vs dead
## materials, dead-inventory sweep). Fixture dicts mirror data/loot.json,
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


## N4-9 천운: luck scales SPECIAL chances only — a doubled 0.5 special becomes
## certain, the ordinary drop next to it keeps its data rate.
func test_luck_scales_special_chance_only() -> bool:
	var table := {"drops": [
		{"loot_id": "fire_stone", "chance": 0.5},
		{"loot_id": "bamboo", "chance": 0.5},
	]}
	var rng := _rng()
	var special_hits: int = 0
	var common_hits: int = 0
	for i: int in range(SAMPLE_ROLLS):
		var dropped: Array[String] = Loot.roll_drops(table, rng, LOOT, 1.0)
		if dropped.has("fire_stone"):
			special_hits += 1
		if dropped.has("bamboo"):
			common_hits += 1
	return (
		special_hits == SAMPLE_ROLLS
		and absf(float(common_hits) / float(SAMPLE_ROLLS) - 0.5) < CHANCE_TOLERANCE
	)


## Luck at any value must clamp at certainty, and zero luck must replay the
## exact sequence of the plain roll (the seeded-replay contract holds).
func test_luck_clamps_and_zero_is_identity() -> bool:
	var table := {"drops": [
		{"loot_id": "whetstone", "chance": 0.02},
		{"loot_id": "bamboo", "chance": 0.3},
	]}
	var plain_rng := _rng()
	var lucky_rng := _rng()
	for i: int in range(200):
		var plain: Array[String] = Loot.roll_drops(table, plain_rng)
		var zero_luck: Array[String] = Loot.roll_drops(table, lucky_rng, LOOT, 0.0)
		if plain != zero_luck:
			return false
	var certain := {"drops": [{"loot_id": "fire_stone", "chance": 0.4}]}
	var rng := _rng()
	for i: int in range(100):
		if Loot.roll_drops(certain, rng, LOOT, 99.0) != ["fire_stone"]:
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


func test_salvage_gold_math() -> bool:
	return (
		Loot.salvage_gold(LOOT, "fire_stone") == 15
		and Loot.salvage_gold(LOOT, "bamboo") == 2
		and Loot.salvage_gold(LOOT, "unknown") == 0
	)


## N4-6: useful = some recipe can still consume it. The base weapon need not
## be owned yet — it may still be acquired later in the run.
func test_material_useful_even_before_base_owned() -> bool:
	return (
		Loot.is_material_useful("whetstone", MODS, {"talisman": 3})
		and Loot.is_material_useful("whetstone", MODS, {"sword": 4})
	)


func test_material_dead_without_any_recipe() -> bool:
	return not Loot.is_material_useful("bamboo", MODS, {"sword": 1})


func test_material_dead_when_result_owned() -> bool:
	return not Loot.is_material_useful("whetstone", MODS, {"sword": 2, "sharp_sword": 1})


func test_material_dead_when_recipe_weapon_replaced() -> bool:
	var base_gone: bool = not Loot.is_material_useful("whetstone", MODS, {}, ["sword"])
	var result_gone: bool = not Loot.is_material_useful("whetstone", MODS, {}, ["sharp_sword"])
	return base_gone and result_gone


func test_salvage_dead_cashes_out_only_dead_materials() -> bool:
	var inventory := {"whetstone": 2, "fire_stone": 1}
	# sharp_sword owned kills the whetstone recipe; fire_stone stays live.
	var sweep: Dictionary = Loot.salvage_dead(
		inventory, LOOT, MODS, {"sharp_sword": 1, "talisman": 1}
	)
	return (
		sweep["inventory"] == {"fire_stone": 1}
		and int(sweep["gold"]) == 16
		and int(inventory["whetstone"]) == 2
	)


func test_apply_mod_swaps_weapon_and_carries_level() -> bool:
	var owned := {"sword": 5, "talisman": 2}
	var updated: Dictionary = Loot.apply_mod(owned, MODS["sharp_sword_mod"])
	return (
		not updated.has("sword")
		and int(updated["sharp_sword"]) == 5
		and int(updated["talisman"]) == 2
		and int(owned["sword"]) == 5
	)


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
