class_name Smithy
extends RefCounted
## N11-4 개조 해금 (owner direction ⑥): mods no longer start available.
## 돌무쇠's smithy unlocks each recipe for gold + storehouse materials, and
## only unlocked recipes appear as 개조 cards in a run. Pure static folds in
## the MetaTree.purchase style: profile in, {ok, reason, profile} out.

const REASON_OK := "ok"
const REASON_GOLD := "gold"
const REASON_MATERIALS := "materials"
const REASON_OWNED := "owned"
const REASON_UNKNOWN := "unknown"

const PROFILE_KEY := "mod_unlocks"
## The most 흥정 can take off a recipe's coin price.
const MAX_SMITHY_DISCOUNT := 0.4


static func unlocked_ids(profile: Dictionary) -> Array:
	var raw: Variant = profile.get(PROFILE_KEY, [])
	return raw if raw is Array else []


static func is_unlocked(profile: Dictionary, mod_id: String) -> bool:
	return unlocked_ids(profile).has(mod_id)


## The mods dictionary a RUN should see. Harness profiles keep every recipe so
## playtest bots and QA fixtures exercise 개조 without grinding the smithy.
static func runtime_mods(
	mods: Dictionary, profile: Dictionary, waive_gate: bool = false
) -> Dictionary:
	if waive_gate:
		return mods
	var unlocked: Array = unlocked_ids(profile)
	var subset: Dictionary = {}
	for mod_id: String in mods:
		if unlocked.has(mod_id):
			subset[mod_id] = mods[mod_id]
	return subset


static func unlock_cost(mod: Dictionary, discount: float = 0.0) -> Dictionary:
	var unlock: Variant = mod.get("unlock", {})
	if unlock is not Dictionary:
		return {}
	# N11-23 흥정: the tree can talk 돌무쇠 down. Materials are untouched —
	# a recipe still costs what it is made of; only the coin price moves.
	var cut: float = clampf(discount, 0.0, MAX_SMITHY_DISCOUNT)
	if cut <= 0.0:
		return unlock
	var priced: Dictionary = (unlock as Dictionary).duplicate(true)
	priced["gold"] = int(round(float(priced.get("gold", 0)) * (1.0 - cut)))
	return priced


static func can_unlock(
	profile: Dictionary, mods: Dictionary, mod_id: String, discount: float = 0.0
) -> String:
	if not mods.has(mod_id):
		return REASON_UNKNOWN
	if is_unlocked(profile, mod_id):
		return REASON_OWNED
	var cost: Dictionary = unlock_cost(mods[mod_id], discount)
	if int(profile.get("gold", 0)) < int(cost.get("gold", 0)):
		return REASON_GOLD
	var pouch: Dictionary = profile.get("materials", {})
	var bill: Dictionary = cost.get("materials", {})
	if not MetaTree.has_materials(pouch, bill):
		return REASON_MATERIALS
	return REASON_OK


## Atomic fold: gold and the material bill spend together or not at all.
static func unlock(
	profile: Dictionary, mods: Dictionary, mod_id: String, discount: float = 0.0
) -> Dictionary:
	var reason: String = can_unlock(profile, mods, mod_id, discount)
	if reason != REASON_OK:
		return {"ok": false, "reason": reason, "profile": profile}
	var cost: Dictionary = unlock_cost(mods[mod_id], discount)
	var next: Dictionary = profile.duplicate(true)
	next["gold"] = int(profile.get("gold", 0)) - int(cost.get("gold", 0))
	var spent: Dictionary = (next.get("materials", {}) as Dictionary).duplicate()
	var bill: Dictionary = cost.get("materials", {})
	for loot_id: String in bill:
		spent[loot_id] = int(spent.get(loot_id, 0)) - int(bill[loot_id])
	next["materials"] = spent
	var owned: Array = unlocked_ids(next).duplicate()
	owned.append(mod_id)
	next[PROFILE_KEY] = owned
	return {"ok": true, "reason": REASON_OK, "profile": next}


## Screen order: grouped by base weapon so one weapon's recipes sit together,
## then by mod id for a stable list.
static func recipe_ids(mods: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for mod_id: String in mods:
		ids.append(mod_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var wa: String = String((mods[a] as Dictionary).get("weapon_id", ""))
		var wb: String = String((mods[b] as Dictionary).get("weapon_id", ""))
		return a < b if wa == wb else wa < wb
	)
	return ids
