class_name Camp
extends RefCounted
## Pure base-camp helpers (N5-3, GDD §24): post-title routing, the camp
## summary view-model over the save profile, and the placeholder building
## roster. Static functions over plain Dictionaries so the headless suite
## covers them (tests/unit/test_camp.gd); CampScreen owns the nodes.

const DEST_STAGE := "stage"
const DEST_CAMP := "camp"
const DEST_TITLE := "title"

## GDD §24 names. `ready` gates the 준비 중 notice — flips per building as
## its screen lands (명부수 N7-1 done, 괴이록 N5-4, ...). A ready building
## carries the scene it routes to, unless it is `in_place`: 지역 선택 cycles
## the departure night right there (N9-150) and has no screen of its own.
const BUILDINGS: Array[Dictionary] = [
	{"id": "meta", "label": "수련", "ready": true, "scene": "res://scenes/meta_tree.tscn"},
	{"id": "bestiary", "label": "괴이록", "ready": true, "scene": "res://scenes/bestiary.tscn"},
	{"id": "achievements", "label": "업적", "ready": true, "scene": "res://scenes/achievements.tscn"},
	{"id": "weapon_codex", "label": "무기 도감", "ready": false},
	{"id": "training", "label": "훈련장", "ready": false},
	{"id": "region_select", "label": "지역 선택", "ready": true, "in_place": true},
]

const STAGES_PATH := "res://data/stages.json"
## N9-150: which nights a profile may walk into. The bamboo forest is always
## open; the ruined village opens with the first boss kill — the same door
## that lets the warrior in.
const STAGE_UNLOCKS: Dictionary = {"ruined_village": "first_boss"}

const NOT_READY_NOTICE := "준비 중"


## Ordered stage ids the profile can depart to (data order, locked filtered).
static func unlocked_stages(profile: Dictionary) -> Array[String]:
	var stages: Variant = JSON.parse_string(FileAccess.get_file_as_string(STAGES_PATH))
	var open: Array[String] = []
	if stages is not Dictionary:
		return open
	for stage_id: String in stages:
		var needed: String = String(STAGE_UNLOCKS.get(stage_id, ""))
		if needed.is_empty() or Achievements.is_earned(profile, needed):
			open.append(stage_id)
	return open


## Pure cycle: the next unlocked stage after the profile's current one.
static func next_stage(profile: Dictionary) -> String:
	var open: Array[String] = unlocked_stages(profile)
	if open.is_empty():
		return ""
	var current: String = String(profile.get("selected_stage", open[0]))
	var index: int = open.find(current)
	return open[(index + 1) % open.size()]


## Localized display name for a stage id, for the region-select notice.
static func stage_label(stage_id: String) -> String:
	var stages: Variant = JSON.parse_string(FileAccess.get_file_as_string(STAGES_PATH))
	if stages is not Dictionary:
		return stage_id
	var entry: Dictionary = (stages as Dictionary).get(stage_id, {})
	var localized: Variant = entry.get("name_" + UiLocale.current_locale)
	if localized is String:
		return localized
	return String(entry.get("name_ko", stage_id))


## Where the title's single start button goes (GDD §28): only a profile that
## has never even ENTERED the tutorial skips camp. Keying this on
## is_first_run alone meant quitting mid-tutorial re-skipped the camp on
## every relaunch (N9-104, owner report) — runs_played only counts finishes.
static func destination_after_title(profile: Dictionary) -> String:
	if Ftue.is_first_run(profile) and not Ftue.has_started_first_sortie(profile):
		return DEST_STAGE
	return DEST_CAMP


## Where character select's back button goes. Camp only exists once a sortie
## has happened, so a truly fresh profile (title corner detour) returns to
## the title.
static func destination_after_select_exit(profile: Dictionary) -> String:
	if Ftue.is_first_run(profile) and not Ftue.has_started_first_sortie(profile):
		return DEST_TITLE
	return DEST_CAMP


## Camp summary view-model: only permanent state the profile already tracks
## (N5-2 gold banking + lifetime stats) — nothing invented here.
static func summary(profile: Dictionary) -> Dictionary:
	var stats: Dictionary = profile.get("stats", {})
	return {
		"gold": maxi(int(profile.get("gold", 0)), 0),
		"runs_played": int(stats.get("runs_played", 0)),
		"best_time_text": CombatHud.format_time(float(stats.get("best_time_sec", 0.0))),
		"best_kills": int(stats.get("best_kills", 0)),
		"bosses_killed": int(stats.get("bosses_killed", 0)),
	}


static func buildings() -> Array[Dictionary]:
	# Translated per call, not in BUILDINGS: a const is built once at load,
	# so a name localised there would freeze at whatever locale started.
	var localized: Array[Dictionary] = BUILDINGS.duplicate(true)
	for building: Dictionary in localized:
		building["label"] = UiLocale.t(String(building.get("label", "")))
	return localized


## Tap response for a building spot: the not-ready notice, or "" once the
## building has a real screen (the spot then routes instead of talking).
static func building_notice(building: Dictionary) -> String:
	if bool(building.get("ready", false)):
		return ""
	return UiLocale.t(NOT_READY_NOTICE)


## Scene a ready building routes to; "" for a placeholder spot.
static func building_scene(building: Dictionary) -> String:
	if not bool(building.get("ready", false)):
		return ""
	return String(building.get("scene", ""))


## A ready building that answers where it stands instead of opening a screen.
static func building_in_place(building: Dictionary) -> bool:
	return bool(building.get("ready", false)) and bool(building.get("in_place", false))
