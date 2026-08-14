class_name Loot
extends RefCounted
## Pure loot helpers (N4-1): drop rolling, run inventory, weapon-mod recipe
## lookup and the special-material choice cards. All inputs are plain
## Dictionaries parsed from data/*.json by the caller, so every function is
## testable headless with fixture data.
##
## Choice shape: {"kind": "use"|"keep"|"salvage", "loot_id": String,
## "mod": Dictionary (use only)}.

const KIND_USE := "use"
const KIND_KEEP := "keep"
const KIND_SALVAGE := "salvage"

const TIER_KO := {
	"common": "일반", "uncommon": "고급", "rare": "희귀",
	"epic": "영웅", "mythic": "신화"
}
const DEFAULT_TIER_KO := "일반"

## Drop diamond tint per tier — words on the popup carry the meaning, the
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


## Recipes this material can apply right now: base weapon owned and the
## result not owned yet — the two waste-guards from the task spec.
static func usable_mods(
	mods: Dictionary, loot_id: String, owned_levels: Dictionary
) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for mod_id: String in mods:
		var mod: Dictionary = mods[mod_id]
		if String(mod.get("loot_id", "")) != loot_id:
			continue
		if not owned_levels.has(String(mod.get("weapon_id", ""))):
			continue
		if owned_levels.has(String(mod.get("result_weapon", ""))):
			continue
		matches.append(mod)
	return matches


## The special-material popup card list: 사용 only when a recipe applies
## (never a disabled card), then always 보관 and 분해.
## ponytail: first matching recipe only; multi-recipe picker if data grows one.
static func build_choices(
	loot_id: String, mods: Dictionary, owned_levels: Dictionary
) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var matches: Array[Dictionary] = usable_mods(mods, loot_id, owned_levels)
	if not matches.is_empty():
		choices.append({"kind": KIND_USE, "loot_id": loot_id, "mod": matches[0]})
	choices.append({"kind": KIND_KEEP, "loot_id": loot_id})
	choices.append({"kind": KIND_SALVAGE, "loot_id": loot_id})
	return choices


## Replace the base weapon with the recipe result, carrying its level.
## Returns a new owned_levels copy.
static func apply_mod(owned_levels: Dictionary, mod: Dictionary) -> Dictionary:
	var updated: Dictionary = owned_levels.duplicate()
	var base_id: String = String(mod.get("weapon_id", ""))
	var carried_level: int = int(updated.get(base_id, 1))
	updated.erase(base_id)
	updated[String(mod.get("result_weapon", ""))] = carried_level
	return updated


## Display dict for the shared paper-panel card component (LevelUpPopup.open).
static func as_card(
	choice: Dictionary,
	loot_data: Dictionary,
	weapons: Dictionary,
	inventory: Dictionary
) -> Dictionary:
	var loot_id: String = String(choice.get("loot_id", ""))
	var stats: Dictionary = loot_data.get(loot_id, {})
	var grade: String = String(TIER_KO.get(String(stats.get("tier", "")), DEFAULT_TIER_KO))
	match String(choice.get("kind", "")):
		KIND_USE:
			var mod: Dictionary = choice.get("mod", {})
			var base: Dictionary = weapons.get(String(mod.get("weapon_id", "")), {})
			var result: Dictionary = weapons.get(String(mod.get("result_weapon", "")), {})
			return {
				"name": "사용",
				"desc": "%s → %s (레벨 유지)" % [
					String(base.get("name_ko", "")), String(result.get("name_ko", ""))
				],
				"well_label": "변신!",
				"grade": grade,
				"payload": choice,
			}
		KIND_KEEP:
			var count: int = int(inventory.get(loot_id, 0))
			return {
				"name": "보관",
				"desc": "가방에 보관 (%d개 → %d개)" % [count, count + 1],
				"well_label": "+1",
				"grade": grade,
				"payload": choice,
			}
		KIND_SALVAGE:
			return {
				"name": "분해",
				"desc": "엽전 +%d" % salvage_gold(loot_data, loot_id),
				"well_label": "엽전",
				"grade": grade,
				"payload": choice,
			}
	push_error("loot: unknown choice kind in " + str(choice))
	return {}
