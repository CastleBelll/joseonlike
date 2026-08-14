class_name SaveProfile
extends RefCounted
## Pure, node-free profile logic for N5-2 persistence: default profile shape,
## JSON round-trip, schema migration, settings clamping and gold banking.
## SaveManager (autoload) owns the disk IO; this class stays fully testable
## from the headless suite (tests/unit/test_save_profile.gd).

const SCHEMA_VERSION := 1
const SUPPORTED_LOCALES: Array[String] = ["ko", "en"]
const DEFAULT_CHARACTER := "taoist"

const VOLUME_KEYS: Array[String] = ["master_volume", "music_volume", "effects_volume"]


static func default_profile() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"gold": 0,
		"selected_character": DEFAULT_CHARACTER,
		"settings": {
			"master_volume": 1.0,
			"music_volume": 1.0,
			"effects_volume": 1.0,
			"locale": UiLocale.DEFAULT_LOCALE,
		},
		"stats": {
			"runs_played": 0,
			"best_time_sec": 0.0,
			"best_kills": 0,
			"bosses_killed": 0,
		},
	}


static func serialize(profile: Dictionary) -> String:
	return JSON.stringify(profile, "  ")


## Empty result means the payload is unreadable; the caller falls back to a
## fresh default profile (with a warning) instead of crashing.
static func deserialize(text: String) -> Dictionary:
	var data: Variant = JSON.parse_string(text)
	if data is not Dictionary:
		return {}
	return data


## Version dispatch hook. v1 is identity plus filling missing keys from the
## default shape, so a future v2 adds a migration step here instead of wiping
## profiles. Unknown or newer schema returns {} — the caller starts fresh.
static func migrate(profile: Dictionary) -> Dictionary:
	var version: int = int(profile.get("schema", 0))
	if version < 1 or version > SCHEMA_VERSION:
		return {}
	var merged: Dictionary = default_profile()
	for key: String in merged.keys():
		if not profile.has(key):
			continue
		if merged[key] is Dictionary and profile[key] is Dictionary:
			var section: Dictionary = merged[key]
			for sub_key: String in section.keys():
				if (profile[key] as Dictionary).has(sub_key):
					section[sub_key] = profile[key][sub_key]
		else:
			merged[key] = profile[key]
	merged["schema"] = SCHEMA_VERSION
	# JSON parses every number as float — normalize types so a loaded profile
	# is indistinguishable from a freshly built one.
	merged["gold"] = maxi(int(merged["gold"]), 0)
	merged["selected_character"] = String(merged["selected_character"])
	merged["settings"] = clamp_settings(merged["settings"])
	merged["stats"] = _normalized_stats(merged["stats"])
	return merged


static func _normalized_stats(stats: Dictionary) -> Dictionary:
	return {
		"runs_played": int(stats.get("runs_played", 0)),
		"best_time_sec": float(stats.get("best_time_sec", 0.0)),
		"best_kills": int(stats.get("best_kills", 0)),
		"bosses_killed": int(stats.get("bosses_killed", 0)),
	}


## Sanitizes a settings dict: volumes forced into 0..1, unknown locales
## rejected back to the default. Always returns a complete settings dict.
static func clamp_settings(settings: Dictionary) -> Dictionary:
	var defaults: Dictionary = default_profile()["settings"]
	var result: Dictionary = {}
	for key: String in VOLUME_KEYS:
		result[key] = clampf(float(settings.get(key, defaults[key])), 0.0, 1.0)
	var locale: String = String(settings.get("locale", ""))
	result["locale"] = locale if locale in SUPPORTED_LOCALES else String(defaults["locale"])
	return result


## Run gold folds into permanent gold; negative inputs never drain the bank.
static func bank_gold(banked: int, earned: int) -> int:
	return maxi(banked, 0) + maxi(earned, 0)


## Pure run-end fold: bank the run's gold and bump lifetime stats.
## Returns a new profile dict — the input is never mutated.
static func apply_run_result(
	profile: Dictionary, elapsed_sec: float, kills: int, gold: int, boss_killed: bool
) -> Dictionary:
	var next: Dictionary = profile.duplicate(true)
	next["gold"] = bank_gold(int(next.get("gold", 0)), gold)
	var stats: Dictionary = next.get("stats", {})
	stats["runs_played"] = int(stats.get("runs_played", 0)) + 1
	stats["best_time_sec"] = maxf(float(stats.get("best_time_sec", 0.0)), elapsed_sec)
	stats["best_kills"] = maxi(int(stats.get("best_kills", 0)), kills)
	if boss_killed:
		stats["bosses_killed"] = int(stats.get("bosses_killed", 0)) + 1
	next["stats"] = stats
	return next
