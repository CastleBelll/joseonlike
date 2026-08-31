class_name SaveService
extends Node
## Persistence autoload (ARCHITECTURE.md §3.4), registered as SaveManager.
## Callers use the typed SaveService.instance accessor instead of the bare
## autoload identifier — the headless test runner (custom SceneTree main
## loop) compiles scripts without autoload globals, and class_name resolves
## there while `SaveManager` would not.
## Loads user://profile.save at boot, applies the persisted settings (audio
## bus volumes + locale) and autosaves on the events that matter — run end,
## settings change, character selection — never on a frame timer.
## Writes go through a temp file so a crash mid-write cannot corrupt the
## save; a rename interrupted between remove and rename is recovered on load.
## Never log the profile contents.

const SAVE_FILE := "profile.save"
const TEMP_FILE := "profile.save.tmp"
const USER_DIR := "user://"
const SAVE_PATH := USER_DIR + SAVE_FILE
const TEMP_PATH := USER_DIR + TEMP_FILE

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_EFFECTS := "Effects"
const ACHIEVEMENTS_PATH := "res://data/achievements.json"
const META_TREE_PATH := "res://data/meta_tree.json"
const BUS_BY_SETTING := {
	"master_volume": BUS_MASTER,
	"music_volume": BUS_MUSIC,
	"effects_volume": BUS_EFFECTS,
}

## The one live autoload instance; null only in node-free headless tests.
static var instance: SaveService

var profile: Dictionary = SaveProfile.default_profile()

## N7-1 fail-safe: a profile written by a NEWER build is never loaded and
## never overwritten — the session runs on an in-memory default instead.
var _write_locked: bool = false


## True while a harness drives a throwaway profile (N11-10): one-shot FTUE
## moments must not fire for it — they would mark themselves seen on a
## profile that cannot save, and pollute every layout measurement with a
## modal that a real first visit earns exactly once.
func is_harness_profile() -> bool:
	return _write_locked
## Why writes are locked, so the log says which guard fired. The lock is set
## both by the newer-build guard and by every harness that swaps in a throwaway
## profile, and one message for both told the reader the wrong thing.
var _write_lock_reason: String = "writes locked"
## N9-65: achievements completed by the most recent bank_run, waiting to be
## shown once on the result screen.
var _earned_achievements: Array[Dictionary] = []


## N11-18: coins handed back by the tree redesign, for the camp to announce
## once. Zero when there was nothing to refund.
var pending_refund: int = 0


func _init() -> void:
	instance = self


func _ready() -> void:
	profile = _load_from_disk()
	_refund_removed_nodes()
	apply_settings()


## N11-18: the redesign removed 49 tree nodes, so a returning profile is paid
## back what it spent on them before anything reads the tree. One pass — the
## ranks are dropped in the same fold, so a second boot finds nothing to
## refund. The amount is remembered for the camp to announce once.
func _refund_removed_nodes() -> void:
	var tree: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(META_TREE_PATH)
	)
	if not tree is Dictionary:
		return
	var result: Dictionary = MetaTree.refund_removed(profile, tree as Dictionary)
	var coins: int = int(result["refunded"])
	if coins <= 0:
		return
	profile = result["profile"]
	pending_refund = coins
	save_profile()


## Sets one settings key, applies it immediately, and optionally persists.
## Sliders pass persist=false per tick and save once on drag end.
func set_setting(key: String, value: Variant, persist: bool = true) -> void:
	var settings: Dictionary = profile["settings"]
	settings[key] = value
	profile["settings"] = SaveProfile.clamp_settings(settings)
	apply_settings()
	if persist:
		save_profile()


func get_setting(key: String) -> Variant:
	return (profile["settings"] as Dictionary).get(key)


func set_selected_character(id: String) -> void:
	profile["selected_character"] = id
	save_profile()


func selected_character() -> String:
	return String(profile.get("selected_character", SaveProfile.DEFAULT_CHARACTER))


func gold() -> int:
	return int(profile.get("gold", 0))


## N6-1 one-shot FTUE marks: persisted the moment they happen (a crash right
## after must not replay the hint), never re-fired — callers gate on the
## Ftue.should_* readers first.
func mark_move_hint_seen() -> void:
	profile = Ftue.mark_move_hint_seen(profile)
	save_profile()


func mark_mod_explained() -> void:
	profile = Ftue.mark_mod_explained(profile)
	save_profile()


## N11-4: the smithy spends gold + materials to open one recipe; the fold is
## atomic in Smithy.unlock and only a successful buy touches disk.
func unlock_mod(mods: Dictionary, mod_id: String) -> String:
	var result: Dictionary = Smithy.unlock(profile, mods, mod_id)
	if bool(result["ok"]):
		profile = result["profile"]
		save_profile()
	return String(result["reason"])


func mark_guide_seen() -> void:
	profile = Ftue.mark_guide_seen(profile)
	save_profile()


## N9-104: written when the first sortie BEGINS so a mid-tutorial quit still
## routes the next launch to camp; callers gate on the reader to avoid
## rewriting the profile every run start.
func mark_first_sortie_started() -> void:
	profile = Ftue.mark_first_sortie_started(profile)
	save_profile()


## N9-22: a cleared difficulty opens the next rung; no write when repeated.
func mark_difficulty_cleared(id: String) -> void:
	var result: Dictionary = Difficulty.mark_cleared(profile, id)
	if bool(result["changed"]):
		profile = result["profile"]
		save_profile()


func mark_archivist_met() -> void:
	profile = Ftue.mark_archivist_met(profile)
	save_profile()


func mark_level_up_explained() -> void:
	profile = Ftue.mark_level_up_explained(profile)
	save_profile()


## N9-11 NEW badge: rendering a bestiary tab marks its discovered entries
## viewed; no-op (no IO) when nothing was new.
func mark_bestiary_viewed(kind: String, ids: Array) -> void:
	var result: Dictionary = Bestiary.mark_viewed(profile, kind, ids)
	if bool(result["changed"]):
		profile = result["profile"]
		save_profile()


## N5-4 괴이록: the first sighting of a kind/id persists the moment it
## happens (mid-run), so the record survives death and crashes alike — that
## is the point of the record (GDD §31). Repeats are no-ops with no IO.
func record_discovery(kind: String, id: String) -> void:
	var result: Dictionary = Bestiary.record_discovery(profile, kind, id)
	if bool(result["new"]):
		profile = result["profile"]
		save_profile()


## Opening the 괴이록 clears the camp's new-discoveries hint.
func mark_bestiary_seen() -> void:
	var result: Dictionary = Bestiary.mark_seen(profile)
	if bool(result["changed"]):
		profile = result["profile"]
		save_profile()


## Banks a finished run into the permanent profile and saves.
## Returns the new permanent gold total for the result screen.
## N9-65: the run also folds into the career counters and awards whatever that
## completed, in the SAME write. Two saves would leave a window where the
## counters had moved but the achievement they completed had not been given.
func bank_run(
	elapsed_sec: float, kills: int, run_gold: int, boss_killed: bool,
	run: Dictionary = {}
) -> int:
	profile = SaveProfile.apply_run_result(profile, elapsed_sec, kills, run_gold, boss_killed)
	var folded: Dictionary = run.duplicate()
	folded["character"] = selected_character()
	folded["kills"] = kills
	folded["boss_killed"] = boss_killed
	folded["elapsed_sec"] = elapsed_sec
	# N9-162: leftover run loot banks into the meta-tree pouch — the run
	# spent what it spent (mods), and the rest funds 수련.
	var pouch: Dictionary = (profile.get("materials", {}) as Dictionary).duplicate()
	for loot_id: Variant in (run.get("loot", {}) as Dictionary):
		pouch[String(loot_id)] = (
			int(pouch.get(String(loot_id), 0))
			+ maxi(int((run.get("loot", {}) as Dictionary)[loot_id]), 0)
		)
	profile["materials"] = pouch
	profile = Achievements.fold_run(profile, folded)
	var result: Dictionary = Achievements.evaluate(profile, achievement_data())
	profile = result["profile"]
	_earned_achievements = result["earned"]
	save_profile()
	return gold()


## Achievement entries that completed on the last banked run, handed over once.
## The result screen is the only place they are shown, and showing them twice
## would read as earning them twice.
func take_earned_achievements() -> Array[Dictionary]:
	var earned: Array[Dictionary] = _earned_achievements
	_earned_achievements = []
	return earned


static func achievement_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(ACHIEVEMENTS_PATH)
	)
	return parsed if parsed is Dictionary else {}


## N7-1 명부수 purchase: one pure fold produces the new profile (gold and rank
## together), then one atomic write persists it — a crash in between leaves
## the old state fully intact. Returns the MetaTree.REASON_* outcome.
func purchase_meta_node(tree: Dictionary, node_id: String) -> String:
	var unlocked: Array[String] = MetaTree.unlocked_characters(
		MetaTree.load_characters(), profile
	)
	var result: Dictionary = MetaTree.purchase(profile, tree, node_id, unlocked)
	if bool(result["ok"]):
		profile = result["profile"]
		save_profile()
	return String(result["reason"])


func apply_settings() -> void:
	var settings: Dictionary = profile["settings"]
	for key: String in BUS_BY_SETTING.keys():
		_set_bus_volume(String(BUS_BY_SETTING[key]), float(settings[key]))
	UiLocale.current_locale = String(settings["locale"])


func save_profile() -> void:
	if _write_locked:
		push_warning("save_manager: not overwriting the profile — " + _write_lock_reason)
		return
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("save_manager: cannot write " + TEMP_PATH)
		return
	file.store_string(SaveProfile.serialize(profile))
	file.close()
	var dir: DirAccess = DirAccess.open(USER_DIR)
	if dir == null:
		push_error("save_manager: cannot open " + USER_DIR)
		return
	# Remove-then-rename: if the process dies between the two calls the temp
	# file still holds a complete payload and _load_from_disk recovers it.
	if dir.file_exists(SAVE_FILE):
		dir.remove(SAVE_FILE)
	var err: Error = dir.rename(TEMP_FILE, SAVE_FILE)
	if err != OK:
		push_error("save_manager: rename failed: " + error_string(err))


func _load_from_disk() -> Dictionary:
	var path: String = SAVE_PATH
	if not FileAccess.file_exists(path):
		if not FileAccess.file_exists(TEMP_PATH):
			return SaveProfile.default_profile()
		path = TEMP_PATH
	var raw: Dictionary = SaveProfile.deserialize(FileAccess.get_file_as_string(path))
	if SaveProfile.is_future_schema(raw):
		push_warning("save_manager: profile schema is newer than this build; " +
			"running read-only on a default profile")
		_write_locked = true
		_write_lock_reason = "its schema is newer than this build"
		return SaveProfile.default_profile()
	var migrated: Dictionary = SaveProfile.migrate(raw)
	if migrated.is_empty():
		push_warning("save_manager: unreadable profile, starting fresh")
		return SaveProfile.default_profile()
	return migrated


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_error("save_manager: missing audio bus " + bus_name)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(linear))
