class_name Achievements
extends RefCounted
## Achievements and the unlocks they grant (N9-65). Pure helpers over plain
## dictionaries, so the suite can play out a career without playing one.
##
## Owner direction: unlocks are EARNED by doing a particular thing with a
## particular character, not bought. Gold already buys stat ranks in the
## 명부수 tree; letting it also buy content made every unlock the same act —
## grind, then pay — and told the player nothing about the game.
##
## Progress is folded from run results into `counters`, and every achievement
## reads a counter. Counters are kept BOTH globally and per character
## ("taoist.victories"), which is what lets a condition say "as the 도사"
## without a second progress system to keep in step with the first.

const COUNTERS_KEY := "counters"
const EARNED_KEY := "achievements"

## Counter names. Anything an achievement may ask about lives here, so a typo
## in data fails validation instead of silently never completing.
const RUNS := "runs"
const VICTORIES := "victories"
const KILLS := "kills"
const BOSSES := "bosses"
const EVOLUTIONS := "evolutions"
const BEST_LEVEL := "best_level"
const BEST_TIME := "best_time_sec"
const COUNTER_NAMES: Array[String] = [
	RUNS, VICTORIES, KILLS, BOSSES, EVOLUTIONS, BEST_LEVEL, BEST_TIME,
]


## Folds one finished run into the profile's counters, globally and under the
## character that played it. `run` carries {"character", "victory", "kills",
## "boss_killed", "level", "evolutions", "elapsed_sec"}.
static func fold_run(profile: Dictionary, run: Dictionary) -> Dictionary:
	var next: Dictionary = profile.duplicate(true)
	var counters: Dictionary = next.get(COUNTERS_KEY, {})
	var character: String = String(run.get("character", ""))
	var totals: Dictionary = {
		RUNS: 1.0,
		VICTORIES: 1.0 if bool(run.get("victory", false)) else 0.0,
		KILLS: float(int(run.get("kills", 0))),
		BOSSES: 1.0 if bool(run.get("boss_killed", false)) else 0.0,
		EVOLUTIONS: float(int(run.get("evolutions", 0))),
	}
	# High-water marks rather than sums: "reached level 15" is about one run,
	# not about fifteen runs that each reached level one.
	var bests: Dictionary = {
		BEST_LEVEL: float(int(run.get("level", 0))),
		BEST_TIME: float(run.get("elapsed_sec", 0.0)),
	}
	for name: String in totals:
		_add(counters, name, character, float(totals[name]))
	for name: String in bests:
		_raise(counters, name, character, float(bests[name]))
	next[COUNTERS_KEY] = counters
	return next


## Reads a counter, optionally scoped to a character. An absent counter is
## zero — a profile from before an achievement existed has simply not started
## on it.
static func counter(profile: Dictionary, name: String, character: String = "") -> float:
	var counters: Dictionary = profile.get(COUNTERS_KEY, {})
	return float(counters.get(_key(name, character), 0.0))


static func is_earned(profile: Dictionary, achievement_id: String) -> bool:
	for raw: Variant in profile.get(EARNED_KEY, []):
		if String(raw) == achievement_id:
			return true
	return false


## How far along one achievement is, as {"have", "need", "ratio", "done"}.
static func progress(profile: Dictionary, entry: Dictionary) -> Dictionary:
	var need: float = maxf(float(entry.get("target", 0.0)), 1.0)
	var have: float = counter(
		profile, String(entry.get("counter", "")), String(entry.get("character", ""))
	)
	return {
		"have": have,
		"need": need,
		"ratio": clampf(have / need, 0.0, 1.0),
		"done": have >= need,
	}


## Awards everything newly completed, in one fold. Returns
## {"profile", "earned": Array[Dictionary]} — the entries, not just ids, so the
## caller can announce them without a second lookup.
##
## A granted unlock is written into the unlock list here. An achievement that
## completed while its reward stayed unowned would be a promise the save
## quietly broke.
static func evaluate(profile: Dictionary, data: Dictionary) -> Dictionary:
	var next: Dictionary = profile.duplicate(true)
	var earned: Array[Dictionary] = []
	for entry: Dictionary in entries(data):
		var id: String = String(entry.get("id", ""))
		if id.is_empty() or is_earned(next, id):
			continue
		if not bool(progress(next, entry)["done"]):
			continue
		var list: Array = next.get(EARNED_KEY, [])
		list.append(id)
		next[EARNED_KEY] = list
		next["gold"] = int(next.get("gold", 0)) + int(entry.get("reward_gold", 0))
		var grants: String = String(entry.get("grants", ""))
		if not grants.is_empty() and not Unlocks.is_unlocked(next, grants):
			var unlocked: Array = next.get(Unlocks.PROFILE_KEY, [])
			unlocked.append(grants)
			next[Unlocks.PROFILE_KEY] = unlocked
		earned.append(entry)
	return {"profile": next, "earned": earned}


static func entries(data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in data:
		if id.begins_with("_"):
			continue
		var raw: Variant = data[id]
		if raw is not Dictionary:
			continue
		var entry: Dictionary = (raw as Dictionary).duplicate()
		entry["id"] = id
		out.append(entry)
	return out


## Row view-model for the screen: everything a line needs, already localized.
static func rows(
	profile: Dictionary, data: Dictionary, unlocks: Dictionary, locale: String
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in entries(data):
		var state: Dictionary = progress(profile, entry)
		var grants: String = String(entry.get("grants", ""))
		var grant_name: String = ""
		if not grants.is_empty():
			grant_name = _localized(Unlocks.entry(unlocks, grants), "name", locale)
		out.append({
			"id": String(entry["id"]),
			"name": _localized(entry, "name", locale),
			"desc": _localized(entry, "desc", locale),
			"have": state["have"],
			"need": state["need"],
			"ratio": state["ratio"],
			"earned": is_earned(profile, String(entry["id"])),
			"grants": grant_name,
			"reward_gold": int(entry.get("reward_gold", 0)),
		})
	return out


static func _localized(entry: Dictionary, field: String, locale: String) -> String:
	var text: String = String(entry.get("%s_%s" % [field, locale], ""))
	if text.is_empty():
		text = String(entry.get("%s_ko" % field, ""))
	return text


static func _key(name: String, character: String) -> String:
	return name if character.is_empty() else "%s.%s" % [character, name]


## Written to the global counter and to the character's own. Both, because a
## condition may be about the career or about one character, and deriving one
## from the other later would need a per-character history nobody keeps.
static func _add(
	counters: Dictionary, name: String, character: String, amount: float
) -> void:
	if amount == 0.0:
		return
	counters[name] = float(counters.get(name, 0.0)) + amount
	if character.is_empty():
		return
	var scoped: String = _key(name, character)
	counters[scoped] = float(counters.get(scoped, 0.0)) + amount


static func _raise(
	counters: Dictionary, name: String, character: String, value: float
) -> void:
	counters[name] = maxf(float(counters.get(name, 0.0)), value)
	if character.is_empty():
		return
	var scoped: String = _key(name, character)
	counters[scoped] = maxf(float(counters.get(scoped, 0.0)), value)


## Data contract for validate_data. The rule that matters most is the last one:
## every unlock must be granted by exactly one achievement. An unlock nothing
## grants is content the player can never reach, and this repo has shipped
## that bug before.
static func data_issues(
	data: Dictionary, unlocks: Dictionary, characters: Dictionary
) -> Array[String]:
	var issues: Array[String] = []
	var found: Array[Dictionary] = entries(data)
	if found.is_empty():
		issues.append("achievements.json declares nothing")
	var granted: Dictionary = {}
	for entry: Dictionary in found:
		var label: String = "achievements." + String(entry["id"])
		for field: String in ["name_ko", "name_en", "desc_ko", "desc_en"]:
			if String(entry.get(field, "")).is_empty():
				issues.append("%s.%s missing" % [label, field])
		if not COUNTER_NAMES.has(String(entry.get("counter", ""))):
			issues.append("%s.counter '%s' is not a counter" % [
				label, String(entry.get("counter", ""))
			])
		if float(entry.get("target", 0.0)) <= 0.0:
			issues.append(label + ".target must be positive")
		if int(entry.get("reward_gold", 0)) < 0:
			issues.append(label + ".reward_gold cannot be negative")
		var character: String = String(entry.get("character", ""))
		if not character.is_empty() and not characters.has(character):
			issues.append("%s.character '%s' is not in characters.json" % [label, character])
		var grants: String = String(entry.get("grants", ""))
		if grants.is_empty():
			continue
		if Unlocks.entry(unlocks, grants).is_empty():
			issues.append("%s.grants '%s' is not an unlock" % [label, grants])
			continue
		if granted.has(grants):
			issues.append("unlock '%s' is granted by two achievements" % grants)
		granted[grants] = true
	for unlock: Dictionary in Unlocks.entries(unlocks):
		var id: String = String(unlock.get("id", ""))
		if not granted.has(id):
			issues.append("unlock '%s' has no achievement that grants it" % id)
	return issues
