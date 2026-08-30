extends RefCounted
## N11-4 smithy recipe unlocks: the atomic gold+material fold, the refusal
## reasons, and the runtime gate that hides locked recipes from a run.

const MODS := {
	"fire_mod": {
		"weapon_id": "sword", "loot_id": "fire_stone",
		"result_weapon": "fire_sword", "level_required": 5,
		"unlock": {"gold": 200, "materials": {"fire_stone": 2}},
	},
	"ice_mod": {
		"weapon_id": "bow", "loot_id": "ice_stone",
		"result_weapon": "ice_bow", "level_required": 5,
		"unlock": {"gold": 300, "materials": {"ice_stone": 2}},
	},
}


static func _rich_profile() -> Dictionary:
	var profile: Dictionary = SaveProfile.default_profile()
	profile["gold"] = 500
	profile["materials"] = {"fire_stone": 3, "ice_stone": 1}
	return profile


func test_unlock_spends_gold_and_materials_atomically() -> bool:
	# Arrange
	var profile: Dictionary = _rich_profile()
	# Act
	var result: Dictionary = Smithy.unlock(profile, MODS, "fire_mod")
	# Assert
	var next: Dictionary = result["profile"]
	if not bool(result["ok"]):
		push_error("test_smithy: affordable unlock must succeed")
		return false
	if int(next["gold"]) != 300 or int(next["materials"]["fire_stone"]) != 1:
		push_error("test_smithy: unlock must spend 200 gold and 2 fire_stone")
		return false
	if not Smithy.is_unlocked(next, "fire_mod"):
		push_error("test_smithy: unlock must record the recipe id")
		return false
	# The original profile stays untouched (immutability contract).
	return int(profile["gold"]) == 500 and Smithy.unlocked_ids(profile).is_empty()


func test_unlock_refusals_name_the_shortage() -> bool:
	var profile: Dictionary = _rich_profile()
	# Materials short: ice needs 2, pouch holds 1 — gold alone must not spend.
	var no_materials: Dictionary = Smithy.unlock(profile, MODS, "ice_mod")
	if String(no_materials["reason"]) != Smithy.REASON_MATERIALS:
		push_error("test_smithy: 1/2 ice_stone must refuse with materials")
		return false
	if int((no_materials["profile"] as Dictionary)["gold"]) != 500:
		push_error("test_smithy: a refused unlock must spend nothing")
		return false
	profile["gold"] = 10
	if String(Smithy.unlock(profile, MODS, "fire_mod")["reason"]) != Smithy.REASON_GOLD:
		push_error("test_smithy: 10 gold must refuse with gold")
		return false
	var owned: Dictionary = Smithy.unlock(_rich_profile(), MODS, "fire_mod")["profile"]
	if String(Smithy.unlock(owned, MODS, "fire_mod")["reason"]) != Smithy.REASON_OWNED:
		push_error("test_smithy: re-buying an owned recipe must refuse")
		return false
	return String(Smithy.unlock(profile, MODS, "ghost_mod")["reason"]) == Smithy.REASON_UNKNOWN


func test_runtime_mods_gate_and_harness_waiver() -> bool:
	# A fresh profile sees no recipes; an unlock opens exactly that one; a
	# harness profile (waived gate) sees everything.
	var fresh: Dictionary = SaveProfile.default_profile()
	if not Smithy.runtime_mods(MODS, fresh).is_empty():
		push_error("test_smithy: fresh profile must see zero recipes in-run")
		return false
	var owned: Dictionary = Smithy.unlock(_rich_profile(), MODS, "fire_mod")["profile"]
	var subset: Dictionary = Smithy.runtime_mods(MODS, owned)
	if subset.size() != 1 or not subset.has("fire_mod"):
		push_error("test_smithy: only the unlocked recipe may reach the run")
		return false
	return Smithy.runtime_mods(MODS, fresh, true).size() == MODS.size()


func test_recipe_ids_group_by_weapon() -> bool:
	var ids: Array[String] = Smithy.recipe_ids(MODS)
	# bow < sword, so ice_mod (bow) sorts ahead of fire_mod (sword).
	return ids == (["ice_mod", "fire_mod"] as Array[String])
