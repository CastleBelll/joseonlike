class_name Unlocks
extends RefCounted
## Permanent unlocks bought with gold (N9-58). Pure helpers over plain
## dictionaries, so the headless suite drives them with fixture data.
##
## Separate from the 명부수 tree on purpose. That tree buys STAT ranks, and
## every node in it must feed a stat the run actually consumes (MetaTree
## enforces exactly that). An unlock is not a number — it is a thing the
## player either has or does not, like the 지도. Squeezing it into the tree
## would mean inventing a fake stat per unlock and loosening the rule that
## keeps the tree honest.
##
## The profile stores only the ids owned. Costs and names live in data, so
## repricing never has to touch a save.

const PROFILE_KEY := "unlocks"

const REASON_OK := "ok"
const REASON_UNKNOWN := "unknown"
const REASON_OWNED := "owned"
const REASON_POOR := "poor"

## The 지도 id, referenced by the run that draws it.
const MAP := "map"


static func entries(data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: Variant in data.get("entries", []):
		if raw is Dictionary:
			out.append(raw)
	return out


static func entry(data: Dictionary, unlock_id: String) -> Dictionary:
	for found: Dictionary in entries(data):
		if String(found.get("id", "")) == unlock_id:
			return found
	return {}


## Owned ids, cleaned of anything the data no longer declares. A hand-edited
## or stale save can never grant something that does not exist.
static func owned(profile: Dictionary, data: Dictionary) -> Array[String]:
	var valid: Array[String] = []
	for found: Dictionary in entries(data):
		valid.append(String(found.get("id", "")))
	var out: Array[String] = []
	for raw: Variant in profile.get(PROFILE_KEY, []):
		var id: String = String(raw)
		if valid.has(id) and not out.has(id):
			out.append(id)
	return out


static func is_unlocked(profile: Dictionary, unlock_id: String) -> bool:
	for raw: Variant in profile.get(PROFILE_KEY, []):
		if String(raw) == unlock_id:
			return true
	return false


static func cost(data: Dictionary, unlock_id: String) -> int:
	return int(entry(data, unlock_id).get("cost", 0))


static func can_purchase(
	profile: Dictionary, data: Dictionary, unlock_id: String
) -> String:
	if entry(data, unlock_id).is_empty():
		return REASON_UNKNOWN
	if is_unlocked(profile, unlock_id):
		return REASON_OWNED
	if int(profile.get("gold", 0)) < cost(data, unlock_id):
		return REASON_POOR
	return REASON_OK


## Buys `unlock_id`, returning {"ok", "reason", "profile"}. The profile is a
## copy — a refused purchase hands back the original untouched, so a caller
## can never half-apply one.
static func purchase(
	profile: Dictionary, data: Dictionary, unlock_id: String
) -> Dictionary:
	var reason: String = can_purchase(profile, data, unlock_id)
	if reason != REASON_OK:
		return {"ok": false, "reason": reason, "profile": profile}
	var next: Dictionary = profile.duplicate(true)
	next["gold"] = int(next.get("gold", 0)) - cost(data, unlock_id)
	var list: Array = next.get(PROFILE_KEY, [])
	list.append(unlock_id)
	next[PROFILE_KEY] = list
	return {"ok": true, "reason": REASON_OK, "profile": next}


## Row view-model for the screen: everything a line needs, so the screen does
## no data lookups of its own.
static func rows(
	profile: Dictionary, data: Dictionary, locale: String
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for found: Dictionary in entries(data):
		var id: String = String(found.get("id", ""))
		out.append({
			"id": id,
			"name": _localized(found, "name", locale),
			"desc": _localized(found, "desc", locale),
			"cost": cost(data, id),
			"owned": is_unlocked(profile, id),
			"affordable": can_purchase(profile, data, id) == REASON_OK,
		})
	return out


static func _localized(found: Dictionary, field: String, locale: String) -> String:
	var text: String = String(found.get("%s_%s" % [field, locale], ""))
	if text.is_empty():
		text = String(found.get("%s_ko" % field, ""))
	return text


## Data contract for validate_data: every entry needs an id, both locales of
## its name and description, and a price. A free unlock would read as already
## bought the moment the screen opens.
static func data_issues(data: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var found: Array[Dictionary] = entries(data)
	if found.is_empty():
		issues.append("entries is missing or empty")
	var ids: Array[String] = []
	for item: Dictionary in found:
		var id: String = String(item.get("id", ""))
		var label: String = "entries." + id
		if id.is_empty() or ids.has(id):
			issues.append("entries has a missing or duplicated id '%s'" % id)
		ids.append(id)
		for field: String in ["name_ko", "name_en", "desc_ko", "desc_en"]:
			if String(item.get(field, "")).is_empty():
				issues.append("%s.%s missing" % [label, field])
		if int(item.get("cost", 0)) <= 0:
			issues.append(label + ".cost must be positive")
	return issues
