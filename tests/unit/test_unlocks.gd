extends RefCounted
## Guards the N9-58 permanent-unlock helpers (Unlocks) against fixture data and
## the shipped data/unlocks.json. Everything here is about a purchase either
## happening completely or not at all — a half-applied one charges the player
## for nothing.

const UNLOCKS_PATH := "res://data/unlocks.json"

const FIXTURE: Dictionary = {"entries": [
	{"id": "map", "name_ko": "지도", "name_en": "Map",
	 "desc_ko": "설명", "desc_en": "desc", "cost": 100},
	{"id": "lantern", "name_ko": "등롱", "name_en": "Lantern",
	 "desc_ko": "설명", "desc_en": "desc", "cost": 300},
]}


func test_a_fresh_profile_owns_nothing() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	return not Unlocks.is_unlocked(profile, "map") \
		and Unlocks.owned(profile, FIXTURE).is_empty()


func test_purchase_charges_the_price_and_grants_the_id() -> bool:
	var result: Dictionary = Unlocks.purchase(_profile(500), FIXTURE, "map")
	var next: Dictionary = result["profile"]
	return bool(result["ok"]) and int(next["gold"]) == 400 \
		and Unlocks.is_unlocked(next, "map")


func test_a_refused_purchase_leaves_the_profile_untouched() -> bool:
	# Too poor: no gold may be taken and no id granted.
	var result: Dictionary = Unlocks.purchase(_profile(50), FIXTURE, "map")
	var next: Dictionary = result["profile"]
	return not bool(result["ok"]) and String(result["reason"]) == Unlocks.REASON_POOR \
		and int(next["gold"]) == 50 and not Unlocks.is_unlocked(next, "map")


func test_buying_the_same_unlock_twice_is_refused() -> bool:
	var profile: Dictionary = Unlocks.purchase(_profile(500), FIXTURE, "map")["profile"]
	var again: Dictionary = Unlocks.purchase(profile, FIXTURE, "map")
	return not bool(again["ok"]) and String(again["reason"]) == Unlocks.REASON_OWNED \
		and int((again["profile"] as Dictionary)["gold"]) == 400


func test_an_unknown_id_is_refused_rather_than_granted() -> bool:
	var result: Dictionary = Unlocks.purchase(_profile(9999), FIXTURE, "flying_carpet")
	return not bool(result["ok"]) and String(result["reason"]) == Unlocks.REASON_UNKNOWN


func test_exact_gold_is_enough() -> bool:
	# Boundary: cost == gold must buy, or the last coin the player earns does
	# nothing and the displayed price is a lie.
	var result: Dictionary = Unlocks.purchase(_profile(100), FIXTURE, "map")
	return bool(result["ok"]) and int((result["profile"] as Dictionary)["gold"]) == 0


func test_owned_prunes_ids_the_data_no_longer_declares() -> bool:
	# A hand-edited or stale save must never grant something that is gone.
	var profile: Dictionary = _profile(0)
	profile[Unlocks.PROFILE_KEY] = ["map", "ghost_relic", "map"]
	return Unlocks.owned(profile, FIXTURE) == ["map"]


func test_rows_carry_everything_the_screen_needs() -> bool:
	var rows: Array[Dictionary] = Unlocks.rows(_profile(150), FIXTURE, "ko")
	if rows.size() != 2:
		return false
	# 100 is affordable at 150 gold; 300 is not, and neither is owned.
	return bool(rows[0]["affordable"]) and not bool(rows[1]["affordable"]) \
		and not bool(rows[0]["owned"]) and String(rows[0]["name"]) == "지도"


func test_rows_fall_back_to_korean_for_a_missing_locale() -> bool:
	var rows: Array[Dictionary] = Unlocks.rows(_profile(0), FIXTURE, "fr")
	return String(rows[0]["name"]) == "지도"


func test_profile_migration_coerces_a_junk_unlock_list() -> bool:
	# Duplicates and non-strings come from hand-edited saves; consumers iterate
	# this list, so it has to arrive as clean strings.
	var profile: Dictionary = SaveProfile.default_profile()
	profile[Unlocks.PROFILE_KEY] = ["map", "map", 7, ""]
	var clean: Dictionary = SaveProfile.migrate(profile)
	# Checked before indexing: a migrate that aborted returns an EMPTY profile,
	# and indexing it would report a key error instead of the real failure —
	# that the migration dropped everything the player owns.
	if not clean.has(Unlocks.PROFILE_KEY):
		push_error("test_unlocks: migrate returned a profile with no unlocks key")
		return false
	return (clean[Unlocks.PROFILE_KEY] as Array) == ["map", "7"]


func test_shipped_data_declares_a_buyable_map() -> bool:
	var data: Dictionary = _shipped()
	return Unlocks.data_issues(data).is_empty() \
		and not Unlocks.entry(data, Unlocks.MAP).is_empty() \
		and Unlocks.cost(data, Unlocks.MAP) > 0


func test_data_issues_catch_a_free_unlock() -> bool:
	var broken: Dictionary = {"entries": [
		{"id": "x", "name_ko": "이름", "name_en": "Name", "desc_ko": "d", "desc_en": "d",
		 "cost": 0},
	]}
	return Unlocks.data_issues(broken).size() == 1


func test_data_issues_catch_duplicate_ids() -> bool:
	var entry: Dictionary = {
		"id": "x", "name_ko": "이름", "name_en": "Name",
		"desc_ko": "d", "desc_en": "d", "cost": 10,
	}
	return Unlocks.data_issues({"entries": [entry, entry]}).size() == 1


func _profile(gold: int) -> Dictionary:
	var profile: Dictionary = SaveProfile.default_profile()
	profile["gold"] = gold
	return profile


func _shipped() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(UNLOCKS_PATH))
	return data if data is Dictionary else {}
