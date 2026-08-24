class_name SaveProfile
extends RefCounted
## Pure, node-free profile logic for N5-2 persistence: default profile shape,
## JSON round-trip, schema migration, settings clamping and gold banking.
## SaveManager (autoload) owns the disk IO; this class stays fully testable
## from the headless suite (tests/unit/test_save_profile.gd).

const SCHEMA_VERSION := 2
const SUPPORTED_LOCALES: Array[String] = ["ko", "en"]
const DEFAULT_CHARACTER := "taoist"
## N7-1: gold is clamped here on every bank so repeated runs can never wrap
## the counter; costs above this are unreachable by design.
const MAX_GOLD := 999999999

const VOLUME_KEYS: Array[String] = ["master_volume", "music_volume", "effects_volume"]

## N6-5 joystick opacity: scales the stick's draw alphas. Floor 0.2 so a
## stray drag can never make the control invisible; lowering it IS allowed,
## just never to zero.
const JOYSTICK_OPACITY_KEY := "joystick_opacity"
## N9-67: screen-shake strength, 0 turns it off entirely. Shake is the one
## effect some people genuinely cannot tolerate, so it ships with a dial.
const SCREEN_SHAKE_KEY := "screen_shake"
const JOYSTICK_OPACITY_MIN := 0.2
const JOYSTICK_OPACITY_MAX := 1.0


static func default_profile() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"gold": 0,
		"selected_character": DEFAULT_CHARACTER,
		"settings": {
			# N9-109 (owner: 기본 세팅 사운드를 지금보다 30% 낮춰): default
			# loudness only — the sliders still reach 1.0, and an existing
			# profile keeps whatever the player already set.
			"master_volume": 0.7,
			"music_volume": 1.0,
			"effects_volume": 1.0,
			"joystick_opacity": JOYSTICK_OPACITY_MAX,
			"screen_shake": 1.0,
			"locale": UiLocale.DEFAULT_LOCALE,
			# N9-156 (owner): desktop window preset ("" = leave the window alone)
			# and the damage-number toggle.
			"resolution": "",
			"show_damage_numbers": true,
			# N9-22 difficulty ladder + run length; sanitized against the data
			# on load so a hand-edited save cannot start a locked night.
			"difficulty": "",
			"run_length": "",
		},
		"cleared_difficulties": [],
		"stats": {
			"runs_played": 0,
			"best_time_sec": 0.0,
			"best_kills": 0,
			"bosses_killed": 0,
		},
		"ftue": Ftue.default_flags(),
		"meta_tree": {},
		"bestiary": Bestiary.default_record(),
		# N9-58: permanent unlocks, stored as ids only. Validation against the
		# unlock data happens at the consumer (Unlocks.owned), the same split
		# meta_tree and bestiary already use.
		Unlocks.PROFILE_KEY: [],
		# N9-65: career counters every achievement reads, and the ids already
		# earned. Counters carry both a global and a per-character key, so a
		# condition can be about the career or about one character.
		Achievements.COUNTERS_KEY: {},
		Achievements.EARNED_KEY: [],
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


## True for a profile written by a NEWER build than this one. The caller must
## fail safe: keep the file untouched instead of silently downgrading it.
static func is_future_schema(profile: Dictionary) -> bool:
	return int(profile.get("schema", 0)) > SCHEMA_VERSION


## Version dispatch hook. v1→v2 (N7-1) only adds the empty "meta_tree" block,
## which the default-shape fill below already provides — gold and everything
## else carry over intact. Unknown or newer schema returns {} — the caller
## decides (fresh profile for garbage, read-only session for future schema).
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
	merged["ftue"] = _normalized_ftue(merged["ftue"])
	# meta_tree carries dynamic node-id keys, so the default-shape sub-key
	# merge above (which walks DEFAULT keys) cannot copy it — take it whole.
	# Per-node validation against the tree data happens at the consumers
	# (MetaTree.sanitize_state), not here.
	if profile.get("meta_tree") is Dictionary:
		var state: Dictionary = {}
		for key: Variant in (profile["meta_tree"] as Dictionary).keys():
			state[String(key)] = int((profile["meta_tree"] as Dictionary)[key])
		merged["meta_tree"] = state
	# N5-4: a record-less (pre-bestiary) profile gets the empty record from the
	# default fill above; a present one is re-coerced into shape here. Unknown
	# ids are pruned against game data at the consumer (Bestiary.prune_record).
	merged["bestiary"] = Bestiary.normalized_record(merged["bestiary"])
	# N9-58: coerced to a list of strings so a hand-edited save cannot make a
	# consumer iterate over dictionaries or numbers. Unknown ids are pruned
	# against the data at the consumer, not here.
	var unlocks: Array = []
	for raw: Variant in (merged.get(Unlocks.PROFILE_KEY, []) as Array):
		# Formatted, not converted. The String constructor rejects a Variant
		# that is already a String, and a conversion that throws inside migrate
		# aborts it — which hands the caller an EMPTY profile, wiping gold, the
		# tree and every unlock. Formatting cannot fail whatever is in the list.
		var id: String = "%s" % raw
		if not id.is_empty() and not unlocks.has(id):
			unlocks.append(id)
	merged[Unlocks.PROFILE_KEY] = unlocks
	# N9-65: same coercion for the earned list, and counters forced to numbers.
	# Consumers do arithmetic on these, and a hand-edited string would abort
	# whatever ran first.
	var earned: Array = []
	for raw: Variant in (merged.get(Achievements.EARNED_KEY, []) as Array):
		var id: String = "%s" % raw
		if not id.is_empty() and not earned.has(id):
			earned.append(id)
	merged[Achievements.EARNED_KEY] = earned
	var counters: Dictionary = {}
	for key: Variant in (merged.get(Achievements.COUNTERS_KEY, {}) as Dictionary):
		counters["%s" % key] = float(
			(merged[Achievements.COUNTERS_KEY] as Dictionary)[key]
		)
	merged[Achievements.COUNTERS_KEY] = counters
	return merged


## N6-1 one-shot FTUE flags; unknown values coerce to bool so a hand-edited
## profile can never resurrect a dismissed hint as a crash.
static func _normalized_ftue(ftue: Dictionary) -> Dictionary:
	var flags: Dictionary = Ftue.default_flags()
	for key: String in flags.keys():
		flags[key] = bool(ftue.get(key, false))
	return flags


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
	result[JOYSTICK_OPACITY_KEY] = clampf(
		float(settings.get(JOYSTICK_OPACITY_KEY, defaults[JOYSTICK_OPACITY_KEY])),
		JOYSTICK_OPACITY_MIN, JOYSTICK_OPACITY_MAX
	)
	# N9-67: 0 turns shake off, 1 is full. Clamped like every other dial so a
	# hand-edited save cannot ask for a camera that leaves the screen.
	result[SCREEN_SHAKE_KEY] = clampf(
		float(settings.get(SCREEN_SHAKE_KEY, defaults[SCREEN_SHAKE_KEY])), 0.0, 1.0
	)
	var locale: String = String(settings.get("locale", ""))
	result["locale"] = locale if locale in SUPPORTED_LOCALES else String(defaults["locale"])
	# N9-22: difficulty / run length pass through as plain ids. Validity is
	# resolved against difficulties.json at run start (Difficulty.selected_id),
	# not here, so this stays a pure dict-shape sanitizer with no data load.
	for key: String in ["difficulty", "run_length"]:
		result[key] = String(settings.get(key, defaults[key]))
	# N9-156: the window preset is a "WxH" string ("" = untouched) validated at
	# apply time; the damage-number switch is a plain bool.
	result["resolution"] = String(settings.get("resolution", defaults["resolution"]))
	result["show_damage_numbers"] = bool(
		settings.get("show_damage_numbers", defaults["show_damage_numbers"])
	)
	return result


## Run gold folds into permanent gold; negative inputs never drain the bank
## and the total clamps at MAX_GOLD so repeated banking can never wrap.
static func bank_gold(banked: int, earned: int) -> int:
	return mini(maxi(banked, 0) + maxi(earned, 0), MAX_GOLD)


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
