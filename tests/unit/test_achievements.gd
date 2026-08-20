extends RefCounted
## Guards the N9-65 achievement career (Achievements): counters folded from
## runs, awards granted once, and the unlocks those awards hand over. Nothing
## here is bought — the point of the rework is that owning something says what
## the player did.

const EPSILON := 0.001

const UNLOCKS: Dictionary = {"entries": [
	{"id": "map", "name_ko": "지도", "name_en": "Map", "desc_ko": "d", "desc_en": "d"},
]}

const DATA: Dictionary = {
	"_note": "ignored",
	"taoist_clear": {
		"name_ko": "죽림 답파", "name_en": "Pathfinder",
		"desc_ko": "d", "desc_en": "d",
		"character": "taoist", "counter": "victories", "target": 1,
		"grants": "map", "reward_gold": 150,
	},
	"hunter": {
		"name_ko": "사냥꾼", "name_en": "Hunter", "desc_ko": "d", "desc_en": "d",
		"counter": "kills", "target": 100, "reward_gold": 50,
	},
}


func test_a_run_folds_into_global_and_character_counters() -> bool:
	var profile: Dictionary = Achievements.fold_run(SaveProfile.default_profile(), {
		"character": "taoist", "victory": true, "kills": 40,
		"boss_killed": true, "level": 9, "evolutions": 1, "elapsed_sec": 300.0,
	})
	return absf(Achievements.counter(profile, Achievements.KILLS) - 40.0) < EPSILON \
		and absf(Achievements.counter(profile, Achievements.KILLS, "taoist") - 40.0) < EPSILON \
		and absf(Achievements.counter(profile, Achievements.VICTORIES) - 1.0) < EPSILON


func test_another_character_does_not_inherit_progress() -> bool:
	# The reason counters are scoped: "as the 도사" must not be satisfied by
	# somebody else's run.
	var profile: Dictionary = Achievements.fold_run(SaveProfile.default_profile(), {
		"character": "warrior", "victory": true, "kills": 10, "elapsed_sec": 100.0,
	})
	return Achievements.counter(profile, Achievements.VICTORIES, "taoist") == 0.0 \
		and absf(
			Achievements.counter(profile, Achievements.VICTORIES, "warrior") - 1.0
		) < EPSILON


func test_totals_accumulate_across_runs() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	for _i: int in range(3):
		profile = Achievements.fold_run(profile, {
			"character": "taoist", "kills": 10, "elapsed_sec": 50.0,
		})
	return absf(Achievements.counter(profile, Achievements.KILLS) - 30.0) < EPSILON \
		and absf(Achievements.counter(profile, Achievements.RUNS) - 3.0) < EPSILON


func test_best_counters_keep_the_high_water_mark() -> bool:
	# "Reach level 15" is about one run, not fifteen runs that reached level 1.
	var profile: Dictionary = SaveProfile.default_profile()
	profile = Achievements.fold_run(profile, {"character": "taoist", "level": 12})
	profile = Achievements.fold_run(profile, {"character": "taoist", "level": 4})
	return absf(Achievements.counter(profile, Achievements.BEST_LEVEL) - 12.0) < EPSILON


func test_completing_one_grants_its_unlock_and_gold() -> bool:
	var profile: Dictionary = Achievements.fold_run(SaveProfile.default_profile(), {
		"character": "taoist", "victory": true, "kills": 5, "elapsed_sec": 400.0,
	})
	var result: Dictionary = Achievements.evaluate(profile, DATA)
	var next: Dictionary = result["profile"]
	return (result["earned"] as Array).size() == 1 \
		and Unlocks.is_unlocked(next, "map") \
		and int(next["gold"]) == 150 \
		and Achievements.is_earned(next, "taoist_clear")


func test_an_award_never_lands_twice() -> bool:
	# Re-evaluating after another run must not pay again; the gold and the
	# unlock are both once-only.
	var profile: Dictionary = Achievements.fold_run(SaveProfile.default_profile(), {
		"character": "taoist", "victory": true, "elapsed_sec": 400.0,
	})
	profile = Achievements.evaluate(profile, DATA)["profile"]
	profile = Achievements.fold_run(profile, {
		"character": "taoist", "victory": true, "elapsed_sec": 400.0,
	})
	var again: Dictionary = Achievements.evaluate(profile, DATA)
	var next: Dictionary = again["profile"]
	return (again["earned"] as Array).is_empty() and int(next["gold"]) == 150 \
		and (next[Unlocks.PROFILE_KEY] as Array).size() == 1


func test_a_character_condition_is_not_met_by_the_wrong_character() -> bool:
	var profile: Dictionary = Achievements.fold_run(SaveProfile.default_profile(), {
		"character": "warrior", "victory": true, "elapsed_sec": 400.0,
	})
	return (Achievements.evaluate(profile, DATA)["earned"] as Array).is_empty()


func test_progress_reports_partial_work() -> bool:
	var profile: Dictionary = Achievements.fold_run(SaveProfile.default_profile(), {
		"character": "taoist", "kills": 25, "elapsed_sec": 60.0,
	})
	var state: Dictionary = Achievements.progress(profile, DATA["hunter"])
	return absf(float(state["ratio"]) - 0.25) < EPSILON and not bool(state["done"])


func test_a_fresh_profile_has_earned_nothing() -> bool:
	var fresh: Dictionary = SaveProfile.default_profile()
	return (Achievements.evaluate(fresh, DATA)["earned"] as Array).is_empty() \
		and not Unlocks.is_unlocked(fresh, "map")


func test_rows_name_the_unlock_they_grant() -> bool:
	# The screen has to answer "what do I do to get the 지도", so the reward is
	# named rather than described as "an unlock".
	var rows: Array[Dictionary] = Achievements.rows(
		SaveProfile.default_profile(), DATA, UNLOCKS, "ko"
	)
	for row: Dictionary in rows:
		if String(row["id"]) == "taoist_clear":
			return String(row["grants"]) == "지도"
	return false


func test_shipped_data_is_consistent_with_the_unlocks() -> bool:
	return Achievements.data_issues(
		_json("res://data/achievements.json"),
		_json("res://data/unlocks.json"),
		_json("res://data/characters.json")
	).is_empty()


func test_the_map_is_earned_by_clearing_as_the_taoist() -> bool:
	# The specific promise made to the owner: the map comes from a character
	# doing a thing, not from gold.
	for entry: Dictionary in Achievements.entries(_json("res://data/achievements.json")):
		if String(entry.get("grants", "")) != Unlocks.MAP:
			continue
		return String(entry.get("character", "")) == "taoist" \
			and String(entry.get("counter", "")) == Achievements.VICTORIES
	return false


func test_every_unlock_has_exactly_one_source() -> bool:
	# An unlock granted twice would be awarded twice; one granted never is
	# content nobody can reach.
	var seen: Dictionary = {}
	for entry: Dictionary in Achievements.entries(_json("res://data/achievements.json")):
		var grants: String = String(entry.get("grants", ""))
		if grants.is_empty():
			continue
		if seen.has(grants):
			return false
		seen[grants] = true
	for unlock: Dictionary in Unlocks.entries(_json("res://data/unlocks.json")):
		if not seen.has(String(unlock.get("id", ""))):
			return false
	return true


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
