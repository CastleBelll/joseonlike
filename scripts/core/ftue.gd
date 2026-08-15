class_name Ftue
extends RefCounted
## Pure first-time-user-experience helpers (N6-1, GDD §28): first-boot
## routing, one-shot move-hint / mod-explanation flags on the save profile,
## and the data-driven first-run guaranteed-drop table. Everything here is a
## static function over plain Dictionaries so the headless suite covers it
## (tests/unit/test_ftue.gd); SaveService owns persistence, Stage owns nodes.

const FTUE_KEY := "ftue"
const MOVE_HINT_SEEN := "move_hint_seen"
const MOD_EXPLAINED := "mod_explained"

## The one allowed tutorial line (GDD §28): rides on the first 개조 card,
## never a popup, never a second line.
const MOD_EXPLAIN_LINE := "첫 개조! 재료로 무기를 바꾼다"


static func default_flags() -> Dictionary:
	return {MOVE_HINT_SEEN: false, MOD_EXPLAINED: false}


## First run = the profile has never finished a run. The scripted first-run
## drops and the forced-taoist routing key off this, not off file existence,
## so a crash before the first run end still counts as the first run.
static func is_first_run(profile: Dictionary) -> bool:
	var stats: Dictionary = profile.get("stats", {})
	return int(stats.get("runs_played", 0)) <= 0


## First-boot routing decision (GDD §28): the first run is always the taoist,
## skipping character select; a returning player keeps their selection.
static func route_character(profile: Dictionary) -> String:
	if is_first_run(profile):
		return SaveProfile.DEFAULT_CHARACTER
	return String(profile.get("selected_character", SaveProfile.DEFAULT_CHARACTER))


static func should_show_move_hint(profile: Dictionary) -> bool:
	return not _flag(profile, MOVE_HINT_SEEN)


## Pure transition: returns a new profile with the hint marked seen — the
## unseen→shown→dismissed path collapses to this one persisted bit, so the
## hint can never return across runs or relaunches.
static func mark_move_hint_seen(profile: Dictionary) -> Dictionary:
	return _with_flag(profile, MOVE_HINT_SEEN)


static func should_explain_mod(profile: Dictionary) -> bool:
	return not _flag(profile, MOD_EXPLAINED)


static func mark_mod_explained(profile: Dictionary) -> Dictionary:
	return _with_flag(profile, MOD_EXPLAINED)


## Prepends the one-shot explanation line to every 개조 card in a built card
## list (there is at most one — LevelUp.assemble). Returns new copies:
## {"cards": Array[Dictionary], "explained": bool} — explained is true only
## when a 개조 card was actually on screen, so the flag never burns early.
static func explain_mod_cards(cards: Array[Dictionary]) -> Dictionary:
	var updated: Array[Dictionary] = []
	var explained: bool = false
	for card: Dictionary in cards:
		var kind: String = String((card.get("payload", {}) as Dictionary).get("kind", ""))
		if kind != LevelUp.KIND_MOD:
			updated.append(card)
			continue
		explained = true
		var copy: Dictionary = card.duplicate()
		copy["desc"] = MOD_EXPLAIN_LINE + "\n" + String(card.get("desc", ""))
		updated.append(copy)
	return {"cards": updated, "explained": explained}


## First-run guarantee table (data/stages.json "first_run_drops"): entries
## {"loot_id": String, "at_sec": float}. A guarantee is due once the run
## clock passes at_sec and that loot has not dropped yet (naturally or
## forced) — `dropped` maps loot_id to the time it first dropped.
static func due_guarantees(
	guarantees: Array, elapsed_sec: float, dropped: Dictionary
) -> Array[String]:
	var due: Array[String] = []
	for entry: Dictionary in guarantees:
		var loot_id: String = String(entry.get("loot_id", ""))
		if elapsed_sec >= float(entry.get("at_sec", 0.0)) and not dropped.has(loot_id):
			due.append(loot_id)
	return due


static func is_guaranteed(guarantees: Array, loot_id: String) -> bool:
	for entry: Dictionary in guarantees:
		if String(entry.get("loot_id", "")) == loot_id:
			return true
	return false


## Data validation (tools/validate_data.gd): every guarantee must name real
## loot and land inside the run, and a non-empty table must guarantee at
## least one special material — the first-mod moment (GDD §28) depends on it.
static func first_run_issues(
	guarantees: Array, loot: Dictionary, duration_sec: float
) -> Array[String]:
	var issues: Array[String] = []
	var has_special: bool = false
	var seen_ids: Array[String] = []
	for entry: Variant in guarantees:
		if entry is not Dictionary:
			issues.append("first_run_drops entry is not an object")
			continue
		var loot_id: String = String((entry as Dictionary).get("loot_id", ""))
		if seen_ids.has(loot_id):
			issues.append("first_run_drops loot_id '%s' duplicated" % loot_id)
		seen_ids.append(loot_id)
		if not loot.has(loot_id):
			issues.append("first_run_drops loot_id '%s' not in loot.json" % loot_id)
		elif bool((loot[loot_id] as Dictionary).get("special", false)):
			has_special = true
		var at_sec: float = float((entry as Dictionary).get("at_sec", 0.0))
		if at_sec <= 0.0 or at_sec >= duration_sec:
			issues.append("first_run_drops '%s' at_sec outside the run window" % loot_id)
	if not guarantees.is_empty() and not has_special:
		issues.append("first_run_drops guarantees no special material")
	return issues


static func _flag(profile: Dictionary, flag: String) -> bool:
	return bool((profile.get(FTUE_KEY, {}) as Dictionary).get(flag, false))


## Returns a new profile copy with one ftue flag set true; missing ftue
## blocks (pre-N6-1 profiles) are filled from the defaults first.
static func _with_flag(profile: Dictionary, flag: String) -> Dictionary:
	var next: Dictionary = profile.duplicate(true)
	var flags: Dictionary = default_flags()
	flags.merge(next.get(FTUE_KEY, {}) as Dictionary, true)
	flags[flag] = true
	next[FTUE_KEY] = flags
	return next
