extends RefCounted
## Headless coverage for the N6-1 FTUE helpers (scripts/core/ftue.gd):
## first-boot routing, one-shot hint/explanation flags surviving the save
## round-trip, the 개조-card explanation line, and the first-run guarantee
## table — including the shipped data table itself.

const DURATION_SEC := 300.0

const GUARANTEES: Array = [
	{"loot_id": "common_mat", "at_sec": 10.0},
	{"loot_id": "special_mat", "at_sec": 60.0},
]
const FIXTURE_LOOT: Dictionary = {
	"common_mat": {"special": false},
	"special_mat": {"special": true},
}


func test_default_profile_has_unseen_ftue_flags() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	return (
		Ftue.should_show_move_hint(profile)
		and Ftue.should_explain_mod(profile)
		and Ftue.is_first_run(profile)
	)


func test_first_boot_routes_to_taoist() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	profile["selected_character"] = "warrior"  # runs_played is still 0
	return Ftue.route_character(profile) == "taoist"


func test_returning_player_keeps_selected_character() -> bool:
	var profile: Dictionary = SaveProfile.apply_run_result(
		SaveProfile.default_profile(), 60.0, 5, 10, false
	)
	profile["selected_character"] = "warrior"
	return Ftue.route_character(profile) == "warrior"


## unseen → shown → dismissed collapses to one persisted bit that must
## survive serialize/deserialize/migrate — never again across relaunches.
func test_move_hint_never_returns_after_dismissal() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	var seen: Dictionary = Ftue.mark_move_hint_seen(profile)
	if Ftue.should_show_move_hint(seen) or not Ftue.should_show_move_hint(profile):
		return false  # marked copy hides it; the input stays untouched
	var reloaded: Dictionary = SaveProfile.migrate(
		SaveProfile.deserialize(SaveProfile.serialize(seen))
	)
	return not Ftue.should_show_move_hint(reloaded)


## A pre-N6-1 profile has no ftue block: migrate must fill it as unseen
## instead of wiping the profile or crashing.
func test_migrate_fills_missing_ftue_block() -> bool:
	var old: Dictionary = SaveProfile.default_profile()
	old.erase("ftue")
	var migrated: Dictionary = SaveProfile.migrate(
		SaveProfile.deserialize(SaveProfile.serialize(old))
	)
	return Ftue.should_show_move_hint(migrated) and Ftue.should_explain_mod(migrated)


func test_mod_explanation_marks_once_per_profile() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	var marked: Dictionary = Ftue.mark_mod_explained(profile)
	var reloaded: Dictionary = SaveProfile.migrate(
		SaveProfile.deserialize(SaveProfile.serialize(marked))
	)
	return (
		not Ftue.should_explain_mod(marked)
		and not Ftue.should_explain_mod(reloaded)
		and Ftue.should_explain_mod(profile)
	)


func test_explain_mod_cards_touches_only_the_mod_card() -> bool:
	var cards: Array[Dictionary] = [
		{"desc": "up", "payload": {"kind": LevelUp.KIND_WEAPON_UP}},
		{"desc": "swap", "payload": {"kind": LevelUp.KIND_MOD}},
	]
	var result: Dictionary = Ftue.explain_mod_cards(cards)
	var updated: Array[Dictionary] = result["cards"]
	return (
		bool(result["explained"])
		and String(updated[0]["desc"]) == "up"
		and String(updated[1]["desc"]) == Ftue.MOD_EXPLAIN_LINE + "\nswap"
		and String(cards[1]["desc"]) == "swap"  # input cards never mutated
	)


func test_explain_mod_cards_without_mod_card_changes_nothing() -> bool:
	var cards: Array[Dictionary] = [
		{"desc": "up", "payload": {"kind": LevelUp.KIND_WEAPON_UP}},
	]
	var result: Dictionary = Ftue.explain_mod_cards(cards)
	var updated: Array[Dictionary] = result["cards"]
	return not bool(result["explained"]) and String(updated[0]["desc"]) == "up"


func test_due_guarantees_respect_clock_and_satisfaction() -> bool:
	if not Ftue.due_guarantees(GUARANTEES, 5.0, {}).is_empty():
		return false  # nothing due before its time
	if Ftue.due_guarantees(GUARANTEES, 10.0, {}) != Array(["common_mat"]):
		return false  # the early guarantee alone, boundary inclusive
	var both: Array[String] = Ftue.due_guarantees(GUARANTEES, 90.0, {})
	if both != Array(["common_mat", "special_mat"]):
		return false  # an overdue guarantee stays due until it drops
	var log: Dictionary = {"common_mat": 8.0}
	return Ftue.due_guarantees(GUARANTEES, 90.0, log) == Array(["special_mat"])


func test_is_guaranteed_matches_table_ids_only() -> bool:
	return (
		Ftue.is_guaranteed(GUARANTEES, "special_mat")
		and not Ftue.is_guaranteed(GUARANTEES, "whetstone")
	)


func test_first_run_issues_flag_bad_tables() -> bool:
	if not Ftue.first_run_issues(GUARANTEES, FIXTURE_LOOT, DURATION_SEC).is_empty():
		return false  # the fixture table is valid
	if Ftue.first_run_issues(
		[{"loot_id": "ghost", "at_sec": 10.0}], FIXTURE_LOOT, DURATION_SEC
	).is_empty():
		return false  # unknown loot
	if Ftue.first_run_issues(
		[{"loot_id": "special_mat", "at_sec": DURATION_SEC}], FIXTURE_LOOT, DURATION_SEC
	).is_empty():
		return false  # a guarantee at or past the run end can never fire
	if Ftue.first_run_issues(
		[
			{"loot_id": "special_mat", "at_sec": 10.0},
			{"loot_id": "special_mat", "at_sec": 60.0},
		], FIXTURE_LOOT, DURATION_SEC
	).is_empty():
		return false  # a duplicated loot_id would double-spawn the guarantee
	return not Ftue.first_run_issues(
		[{"loot_id": "common_mat", "at_sec": 10.0}], FIXTURE_LOOT, DURATION_SEC
	).is_empty()  # a table without a special material misses the first-mod moment


## The shipped table itself: every stage's first-run guarantees must be
## clean, and the first stage must guarantee a special material in time.
func test_shipped_first_run_table_guarantees_a_special_material() -> bool:
	var stages: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/stages.json")
	)
	var loot: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/loot.json")
	)
	var forest: Dictionary = stages.get("bamboo_forest", {})
	var table: Array = forest.get("first_run_drops", [])
	if table.is_empty():
		return false
	return Ftue.first_run_issues(
		table, loot, float(forest.get("duration_sec", 0.0))
	).is_empty()

## N11-10: the archivist's welcome fires once and the pages exist.
func test_archivist_welcome_is_one_shot() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	if not Ftue.should_meet_archivist(profile):
		return false
	var met: Dictionary = Ftue.mark_archivist_met(profile)
	return (
		not Ftue.should_meet_archivist(met)
		and Ftue.should_meet_archivist(profile)  # the original is untouched
		and Ftue.archivist_pages().size() >= 3
	)

