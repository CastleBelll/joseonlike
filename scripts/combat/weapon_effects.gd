class_name WeaponEffects
extends RefCounted
## Cached weapon-effect tuning block from data/effects.json (N3-17). Every
## effect timing/distance lives in data; colors stay UiPalette tokens at the
## call sites. A missing block degrades to zero-duration (invisible) effects —
## validate_data reports it, gameplay never breaks.

const EFFECTS_PATH := "res://data/effects.json"
const BLOCK_KEY := "weapon_effects"

static var _config: Dictionary = {}
static var _loaded: bool = false


static func config() -> Dictionary:
	if not _loaded:
		_loaded = true
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(EFFECTS_PATH))
		if data is Dictionary:
			_config = (data as Dictionary).get(BLOCK_KEY, {})
		if _config.is_empty():
			push_error("weapon_effects: missing %s block in %s" % [BLOCK_KEY, EFFECTS_PATH])
	return _config


static func value(key: String) -> float:
	return float(config().get(key, 0.0))
