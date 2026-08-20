extends RefCounted
## Guards the N9-58 unlock helpers (Unlocks) against fixture data and the
## shipped data/unlocks.json. N9-65 moved the granting to achievements, so
## what is left here is OWNERSHIP: reading it, and refusing to report
## something the data no longer declares.

const UNLOCKS_PATH := "res://data/unlocks.json"

const FIXTURE: Dictionary = {"entries": [
	{"id": "map", "name_ko": "지도", "name_en": "Map",
	 "desc_ko": "설명", "desc_en": "desc"},
	{"id": "lantern", "name_ko": "등롱", "name_en": "Lantern",
	 "desc_ko": "설명", "desc_en": "desc"},
]}


func test_a_fresh_profile_owns_nothing() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	return not Unlocks.is_unlocked(profile, "map") \
		and Unlocks.owned(profile, FIXTURE).is_empty()


func test_owned_prunes_ids_the_data_no_longer_declares() -> bool:
	# A hand-edited or stale save must never grant something that is gone.
	var profile: Dictionary = SaveProfile.default_profile()
	profile[Unlocks.PROFILE_KEY] = ["map", "ghost_relic", "map"]
	return Unlocks.owned(profile, FIXTURE) == ["map"]


func test_profile_migration_coerces_a_junk_unlock_list() -> bool:
	# Duplicates and non-strings come from hand-edited saves; consumers iterate
	# this list, so it has to arrive as clean strings.
	var profile: Dictionary = SaveProfile.default_profile()
	profile[Unlocks.PROFILE_KEY] = ["map", "map", 7, ""]
	var clean: Dictionary = SaveProfile.migrate(profile)
	if not clean.has(Unlocks.PROFILE_KEY):
		push_error("test_unlocks: migrate returned a profile with no unlocks key")
		return false
	return (clean[Unlocks.PROFILE_KEY] as Array) == ["map", "7"]


func test_shipped_data_declares_the_map() -> bool:
	var data: Dictionary = _shipped()
	return Unlocks.data_issues(data).is_empty() \
		and not Unlocks.entry(data, Unlocks.MAP).is_empty()


func test_data_issues_catch_a_nameless_unlock() -> bool:
	# Three of the four locale fields are missing.
	return Unlocks.data_issues({"entries": [{"id": "x", "name_ko": "이름"}]}).size() == 3


func test_data_issues_catch_duplicate_ids() -> bool:
	var entry: Dictionary = {
		"id": "x", "name_ko": "이름", "name_en": "Name", "desc_ko": "d", "desc_en": "d",
	}
	return Unlocks.data_issues({"entries": [entry, entry]}).size() == 1


func _shipped() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(UNLOCKS_PATH))
	return data if data is Dictionary else {}
