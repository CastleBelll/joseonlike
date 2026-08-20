class_name Unlocks
extends RefCounted
## Permanent unlocks, granted by achievements (N9-58, reworked N9-65). Pure
## helpers over plain
## dictionaries, so the headless suite drives them with fixture data.
##
## Separate from the 명부수 tree on purpose. That tree buys STAT ranks, and
## every node in it must feed a stat the run actually consumes (MetaTree
## enforces exactly that). An unlock is not a number — it is a thing the
## player either has or does not, like the 지도.
##
## N9-65: unlocks are no longer BOUGHT. Gold already buys stat ranks, and
## letting it also buy content made every unlock the same act — grind, then
## pay. They are granted by achievements instead (Achievements.evaluate), so
## owning one says what the player did rather than how long they farmed.
##
## The profile stores only the ids owned; names live in data.

const PROFILE_KEY := "unlocks"

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


static func _localized(found: Dictionary, field: String, locale: String) -> String:
	var text: String = String(found.get("%s_%s" % [field, locale], ""))
	if text.is_empty():
		text = String(found.get("%s_ko" % field, ""))
	return text


## Data contract for validate_data: every entry needs an id and both locales
## of its name and description. Whether anything can actually GRANT it is
## checked in Achievements.data_issues, which is the side that knows.
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
	return issues
