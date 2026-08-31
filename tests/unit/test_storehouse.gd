extends RefCounted
## N11-5 창고: the pouch view over the banked materials — what is held, what
## the smithy and 수련 still owe, and the shopping-list-first ordering.

const LOOT := {
	"whetstone": {"name_ko": "숫돌", "name_en": "Whetstone", "special": false},
	"ghost_iron": {"name_ko": "귀철", "name_en": "Ghost Iron", "special": true},
	"bamboo": {"name_ko": "대나무", "name_en": "Bamboo", "special": false},
}
const MODS := {
	"sharp_mod": {
		"weapon_id": "sword", "loot_id": "whetstone",
		"unlock": {"gold": 200, "materials": {"whetstone": 2}},
	},
	"ghost_mod": {
		"weapon_id": "sword", "loot_id": "ghost_iron",
		"unlock": {"gold": 200, "materials": {"ghost_iron": 2}},
	},
}
const TREE := {
	"nodes": [
		{"id": "iron_bones", "costs": [80, 180], "materials": {"whetstone": [1, 3]}},
	],
}


static func _profile(materials: Dictionary) -> Dictionary:
	var profile: Dictionary = SaveProfile.default_profile()
	profile["materials"] = materials
	return profile


func test_demand_sums_unbought_recipes_and_next_ranks() -> bool:
	# Arrange: nothing unlocked, tree at rank 0 — every bill is still owed.
	var fresh: Dictionary = _profile({})
	# Act
	var wanted: Dictionary = Storehouse.demand(fresh, MODS, TREE)
	# Assert: whetstone = 2 (recipe) + 1 (rank 1), ghost_iron = 2 (recipe).
	if int(wanted.get("whetstone", 0)) != 3 or int(wanted.get("ghost_iron", 0)) != 2:
		push_error("test_storehouse: demand must sum recipe and rank bills")
		return false
	# An unlocked recipe and a bought rank stop asking.
	var rich: Dictionary = _profile({"whetstone": 9})
	rich["gold"] = 500
	var owned: Dictionary = Smithy.unlock(rich, MODS, "sharp_mod")["profile"]
	owned["meta_tree"] = {"iron_bones": 1}
	var after: Dictionary = Storehouse.demand(owned, MODS, TREE)
	# whetstone now only owes rank 2's 3; ghost_iron still owes its recipe.
	return int(after.get("whetstone", 0)) == 3 and int(after.get("ghost_iron", 0)) == 2


func test_rows_list_held_and_owed_only() -> bool:
	# bamboo is neither held nor owed, so it must not take a row.
	var rows: Array[Dictionary] = Storehouse.rows(
		_profile({"ghost_iron": 1}), LOOT, MODS, TREE, "ko"
	)
	var ids: Array[String] = []
	for row: Dictionary in rows:
		ids.append(String(row["id"]))
	if ids.has("bamboo"):
		push_error("test_storehouse: an unheld, unwanted material must not take a row")
		return false
	return ids.size() == 2 and ids.has("whetstone") and ids.has("ghost_iron")


func test_rows_put_the_shopping_list_first() -> bool:
	# whetstone is fully stocked (owes 3, holds 9); ghost_iron is short.
	var rows: Array[Dictionary] = Storehouse.rows(
		_profile({"whetstone": 9, "ghost_iron": 1}), LOOT, MODS, TREE, "ko"
	)
	if String(rows[0]["id"]) != "ghost_iron":
		push_error("test_storehouse: a short material must sort above a stocked one")
		return false
	return int(rows[0]["needed"]) == 2 and int(rows[0]["count"]) == 1


func test_stocked_count_ignores_zero_and_unknown() -> bool:
	var profile: Dictionary = _profile({"whetstone": 3, "bamboo": 0, "mystery": 5})
	return Storehouse.stocked_count(profile, LOOT) == 1
