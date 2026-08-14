class_name Loot
extends RefCounted
## Pure loot helpers (N4-1, reshaped in N4-6): drop rolling, run inventory,
## pickup-time usefulness checks and the weapon-mod swap. All inputs are plain
## Dictionaries parsed from data/*.json by the caller, so every function is
## testable headless with fixture data. There is no loot popup any more —
## every material is collected or salvaged silently (DESIGN.md §5.2), and the
## mod choice lives in the level-up cards (LevelUp.KIND_MOD).

## Drop diamond tint per tier — words on the cards carry the meaning, the
## tint is only in-field legibility (DESIGN.md §2: never color alone).
const TIER_COLORS: Dictionary = {
	"common": UiPalette.LOOT_COMMON,
	"uncommon": UiPalette.LOOT_UNCOMMON,
	"rare": UiPalette.LOOT_RARE,
	"epic": UiPalette.LOOT_EPIC,
	"mythic": UiPalette.LOOT_MYTHIC,
}


## Roll one dead monster's drop table. Each entry is an independent chance;
## the caller owns the RNG so a fixed seed replays the same drops.
static func roll_drops(table: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var dropped: Array[String] = []
	for entry: Dictionary in table.get("drops", []):
		if rng.randf() < float(entry.get("chance", 0.0)):
			dropped.append(String(entry.get("loot_id", "")))
	return dropped


static func tier_color(loot_data: Dictionary, loot_id: String) -> Color:
	var tier: String = String((loot_data.get(loot_id, {}) as Dictionary).get("tier", ""))
	return TIER_COLORS.get(tier, UiPalette.LOOT_COMMON)


## Run inventory transitions return new copies (no mutation, matches LevelUp).
static func add(inventory: Dictionary, loot_id: String, count: int = 1) -> Dictionary:
	var updated: Dictionary = inventory.duplicate()
	updated[loot_id] = int(updated.get(loot_id, 0)) + count
	return updated


static func spend(inventory: Dictionary, loot_id: String, count: int = 1) -> Dictionary:
	var updated: Dictionary = inventory.duplicate()
	var remaining: int = int(updated.get(loot_id, 0)) - count
	if remaining > 0:
		updated[loot_id] = remaining
	else:
		updated.erase(loot_id)
	return updated


static func salvage_gold(loot_data: Dictionary, loot_id: String) -> int:
	return int((loot_data.get(loot_id, {}) as Dictionary).get("salvage_gold", 0))


## N4-6 pickup rule: a material is worth holding only while some recipe can
## still consume it this run — the result is not owned yet and neither side
## of the recipe has been replaced by an earlier mod. The base weapon does
## NOT need to be owned yet: the player may still pick it up later. Anything
## else is dead inventory and salvages to gold at pickup time.
static func is_material_useful(
	loot_id: String, mods: Dictionary, owned_levels: Dictionary, replaced: Array = []
) -> bool:
	for mod_id: String in mods:
		var mod: Dictionary = mods[mod_id]
		if String(mod.get("loot_id", "")) != loot_id:
			continue
		if owned_levels.has(String(mod.get("result_weapon", ""))):
			continue
		if replaced.has(String(mod.get("result_weapon", ""))) \
				or replaced.has(String(mod.get("weapon_id", ""))):
			continue
		return true
	return false


## Sweep the inventory after a mod changed the weapon state: materials whose
## every recipe just died cash out. Returns new copies:
## {"inventory": Dictionary, "gold": int}.
static func salvage_dead(
	inventory: Dictionary,
	loot_data: Dictionary,
	mods: Dictionary,
	owned_levels: Dictionary,
	replaced: Array = []
) -> Dictionary:
	var kept: Dictionary = {}
	var gold: int = 0
	for loot_id: String in inventory:
		if is_material_useful(loot_id, mods, owned_levels, replaced):
			kept[loot_id] = inventory[loot_id]
		else:
			gold += salvage_gold(loot_data, loot_id) * int(inventory[loot_id])
	return {"inventory": kept, "gold": gold}


## Replace the base weapon with the recipe result, carrying its level.
## Returns a new owned_levels copy.
static func apply_mod(owned_levels: Dictionary, mod: Dictionary) -> Dictionary:
	var updated: Dictionary = owned_levels.duplicate()
	var base_id: String = String(mod.get("weapon_id", ""))
	var carried_level: int = int(updated.get(base_id, 1))
	updated.erase(base_id)
	updated[String(mod.get("result_weapon", ""))] = carried_level
	return updated
