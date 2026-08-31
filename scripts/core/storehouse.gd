class_name Storehouse
extends RefCounted
## N11-5 장터 창고 (owner axis 7 — 전리품 줍기가 장기 동기): the banked
## material pouch, and what each material is still owed to. Two systems bill
## materials now (the smithy's recipe unlocks, the 수련 tree's ranks), so a
## count with no "what for" is a number the player cannot act on.

## One row per material the player holds OR still owes, shopping list first so
## the pouch reads as a stock list rather than a data dump.
static func rows(
	profile: Dictionary, loot: Dictionary, mods: Dictionary, tree: Dictionary
) -> Array[Dictionary]:
	var pouch: Dictionary = profile.get("materials", {})
	var wanted: Dictionary = demand(profile, mods, tree)
	var built: Array[Dictionary] = []
	for loot_id: String in loot:
		if int(pouch.get(loot_id, 0)) <= 0 and not wanted.has(loot_id):
			continue
		var entry: Dictionary = loot[loot_id]
		built.append({
			"id": loot_id,
			"name": UiLocale.data_name(entry, loot_id),
			"count": int(pouch.get(loot_id, 0)),
			"needed": int(wanted.get(loot_id, 0)),
		})
	built.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# Owed-but-missing first (that is the shopping list), then by stock.
		var a_short: bool = int(a["needed"]) > int(a["count"])
		var b_short: bool = int(b["needed"]) > int(b["count"])
		if a_short != b_short:
			return a_short
		if int(a["count"]) != int(b["count"]):
			return int(a["count"]) > int(b["count"])
		return String(a["id"]) < String(b["id"])
	)
	return built


## How much of each material the player still owes across every UNBOUGHT
## smithy recipe and every NEXT meta-tree rank. Unlocked recipes and bought
## ranks ask for nothing.
static func demand(profile: Dictionary, mods: Dictionary, tree: Dictionary) -> Dictionary:
	var wanted: Dictionary = {}
	for mod_id: String in mods:
		if Smithy.is_unlocked(profile, mod_id):
			continue
		var unlock_bill: Dictionary = Smithy.unlock_cost(mods[mod_id]).get("materials", {})
		for loot_id: String in unlock_bill:
			wanted[loot_id] = int(wanted.get(loot_id, 0)) + int(unlock_bill[loot_id])
	var state: Dictionary = profile.get("meta_tree", {})
	for node: Variant in (tree.get("nodes", []) as Array):
		var entry: Dictionary = node
		var rank: int = int(state.get(String(entry.get("id", "")), 0))
		var rank_bill: Dictionary = MetaTree.next_materials(entry, rank)
		for loot_id: String in rank_bill:
			wanted[loot_id] = int(wanted.get(loot_id, 0)) + int(rank_bill[loot_id])
	return wanted


## Header line: how many kinds are stocked, out of every kind the night drops.
static func stocked_count(profile: Dictionary, loot: Dictionary) -> int:
	var pouch: Dictionary = profile.get("materials", {})
	var kinds: int = 0
	for loot_id: String in loot:
		if int(pouch.get(loot_id, 0)) > 0:
			kinds += 1
	return kinds
