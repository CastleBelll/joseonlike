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
## carries the scene it routes to.
const BUILDINGS: Array[Dictionary] = [
	{"id": "meta", "label": "수련", "ready": true, "scene": "res://scenes/meta_tree.tscn"},
	{"id": "bestiary", "label": "괴이록", "ready": true, "scene": "res://scenes/bestiary.tscn"},
	{"id": "weapon_codex", "label": "무기 도감", "ready": false},
	{"id": "training", "label": "훈련장", "ready": false},
	{"id": "region_select", "label": "지역 선택", "ready": false},
]

const NOT_READY_NOTICE := "준비 중"


## Where the title's single start button goes (GDD §28): the first run skips
## camp and character select entirely; from the second visit on the player
## lands in camp and departs from there.
static func destination_after_title(profile: Dictionary) -> String:
	if Ftue.is_first_run(profile):
		return DEST_STAGE
	return DEST_CAMP


## Where character select's back button goes. Camp only exists for returning
## profiles, so a fresh profile (title corner detour) returns to the title.
static func destination_after_select_exit(profile: Dictionary) -> String:
	if Ftue.is_first_run(profile):
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
	return BUILDINGS.duplicate(true)


## Tap response for a building spot: the not-ready notice, or "" once the
## building has a real screen (the spot then routes instead of talking).
static func building_notice(building: Dictionary) -> String:
	if bool(building.get("ready", false)):
		return ""
	return NOT_READY_NOTICE


## Scene a ready building routes to; "" for a placeholder spot.
static func building_scene(building: Dictionary) -> String:
	if not bool(building.get("ready", false)):
		return ""
	return String(building.get("scene", ""))
