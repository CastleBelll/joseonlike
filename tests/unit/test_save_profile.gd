extends RefCounted
## Guards the N5-2 pure persistence logic (SaveProfile): JSON round-trip,
## corrupt-payload fallback, the schema migration hook, settings clamping
## and gold banking / lifetime-stat folding. Disk IO (SaveManager) is
## runtime-verified — everything here is node-free.


func test_round_trip_preserves_default_profile() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	var restored: Dictionary = SaveProfile.migrate(
		SaveProfile.deserialize(SaveProfile.serialize(profile))
	)
	return restored == profile


func test_corrupt_payload_deserializes_to_empty() -> bool:
	return SaveProfile.deserialize("{ not json !").is_empty() \
		and SaveProfile.deserialize("[1, 2, 3]").is_empty() \
		and SaveProfile.deserialize("").is_empty()


func test_migrate_rejects_unknown_schema() -> bool:
	return SaveProfile.migrate({}).is_empty() \
		and SaveProfile.migrate({"schema": 0}).is_empty() \
		and SaveProfile.migrate({"schema": SaveProfile.SCHEMA_VERSION + 1}).is_empty()


func test_migrate_fills_missing_keys_from_default() -> bool:
	var migrated: Dictionary = SaveProfile.migrate({"schema": 1, "gold": 77})
	var settings: Dictionary = migrated["settings"]
	return int(migrated["gold"]) == 77 \
		and migrated["selected_character"] == SaveProfile.DEFAULT_CHARACTER \
		and settings["locale"] == UiLocale.DEFAULT_LOCALE \
		and int((migrated["stats"] as Dictionary)["runs_played"]) == 0


func test_migrate_keeps_saved_values() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	profile["gold"] = 123
	(profile["settings"] as Dictionary)["locale"] = "en"
	(profile["stats"] as Dictionary)["best_kills"] = 55
	var migrated: Dictionary = SaveProfile.migrate(profile)
	return int(migrated["gold"]) == 123 \
		and (migrated["settings"] as Dictionary)["locale"] == "en" \
		and int((migrated["stats"] as Dictionary)["best_kills"]) == 55


func test_clamp_settings_bounds_volumes() -> bool:
	var clamped: Dictionary = SaveProfile.clamp_settings({
		"master_volume": 1.7, "music_volume": -0.3, "effects_volume": 0.5,
	})
	return float(clamped["master_volume"]) == 1.0 \
		and float(clamped["music_volume"]) == 0.0 \
		and float(clamped["effects_volume"]) == 0.5


func test_clamp_settings_rejects_unknown_locale() -> bool:
	var clamped: Dictionary = SaveProfile.clamp_settings({"locale": "fr"})
	return clamped["locale"] == UiLocale.DEFAULT_LOCALE \
		and SaveProfile.clamp_settings({"locale": "en"})["locale"] == "en"


func test_bank_gold_adds_and_ignores_negatives() -> bool:
	return SaveProfile.bank_gold(10, 5) == 15 \
		and SaveProfile.bank_gold(10, -5) == 10 \
		and SaveProfile.bank_gold(-3, 5) == 5


func test_bank_gold_clamps_at_max_instead_of_wrapping() -> bool:
	# N7-1 edge: repeated banking must saturate at MAX_GOLD, never overflow.
	return SaveProfile.bank_gold(SaveProfile.MAX_GOLD, 100) == SaveProfile.MAX_GOLD \
		and SaveProfile.bank_gold(SaveProfile.MAX_GOLD - 10, 100) == SaveProfile.MAX_GOLD


func test_migrate_v1_profile_gains_empty_meta_tree_and_keeps_gold() -> bool:
	# A pre-N7-1 save: schema 1, no meta_tree block anywhere.
	var migrated: Dictionary = SaveProfile.migrate({"schema": 1, "gold": 875})
	return int(migrated["gold"]) == 875 \
		and migrated["meta_tree"] is Dictionary \
		and (migrated["meta_tree"] as Dictionary).is_empty() \
		and int(migrated["schema"]) == SaveProfile.SCHEMA_VERSION


func test_migrate_keeps_meta_tree_ranks() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	profile["meta_tree"] = {"iron_bones": 2.0}  # JSON numbers arrive as float
	var migrated: Dictionary = SaveProfile.migrate(profile)
	return (migrated["meta_tree"] as Dictionary)["iron_bones"] == 2


func test_future_schema_detected_and_never_migrated() -> bool:
	# Fail safe (N7-1 edge #6): a newer build's profile is recognized so the
	# manager can keep the file untouched instead of downgrading it.
	var future: Dictionary = {"schema": SaveProfile.SCHEMA_VERSION + 1, "gold": 999}
	return SaveProfile.is_future_schema(future) \
		and SaveProfile.migrate(future).is_empty() \
		and not SaveProfile.is_future_schema(SaveProfile.default_profile())


func test_apply_run_result_banks_and_bumps_stats() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	var after: Dictionary = SaveProfile.apply_run_result(profile, 120.0, 30, 40, true)
	var stats: Dictionary = after["stats"]
	return int(after["gold"]) == 40 \
		and int(stats["runs_played"]) == 1 \
		and float(stats["best_time_sec"]) == 120.0 \
		and int(stats["best_kills"]) == 30 \
		and int(stats["bosses_killed"]) == 1 \
		and int(profile["gold"]) == 0  # input never mutated


func test_apply_run_result_keeps_best_records() -> bool:
	var profile: Dictionary = SaveProfile.apply_run_result(
		SaveProfile.default_profile(), 300.0, 50, 10, false
	)
	var after: Dictionary = SaveProfile.apply_run_result(profile, 100.0, 20, 5, false)
	var stats: Dictionary = after["stats"]
	return float(stats["best_time_sec"]) == 300.0 \
		and int(stats["best_kills"]) == 50 \
		and int(stats["runs_played"]) == 2 \
		and int(stats["bosses_killed"]) == 0 \
		and int(after["gold"]) == 15
