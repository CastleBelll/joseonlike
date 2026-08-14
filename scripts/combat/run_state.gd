class_name RunState
extends RefCounted
## Run-scoped XP/level progression (N3-5). The curve lives in
## data/progression.json: xp_to_next(L) = round(base_xp * growth^(L-1)),
## documented in data/BALANCE.md. Level-up grants nothing yet — the choice
## UI (N3-6) subscribes to level_reached later.

signal level_reached(new_level: int)

const PROGRESSION_PATH := "res://data/progression.json"
const FIRST_LEVEL := 1

var level: int = FIRST_LEVEL
var xp: int = 0
## N4-1 run inventory: material counts per loot id, for UI and recipe checks.
## Transitions go through the pure Loot.add / Loot.spend helpers.
var inventory: Dictionary = {}

var _base_xp: float = 0.0
var _growth: float = 0.0


## XP orb pickup numbers (magnet/collect radii, accel, max speed) — same
## progression.json file, consumed by the stage when spawning orbs.
static func load_orb_config() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROGRESSION_PATH))
	if data is not Dictionary or (data as Dictionary).get("orb") is not Dictionary:
		push_error("run_state: cannot read orb config from " + PROGRESSION_PATH)
		return {}
	return data["orb"]


static func load_curve() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(PROGRESSION_PATH)
	var data: Variant = JSON.parse_string(text)
	if data is not Dictionary or (data as Dictionary).get("xp_curve") is not Dictionary:
		push_error("run_state: cannot read xp_curve from " + PROGRESSION_PATH)
		return {}
	return data["xp_curve"]


## XP needed to go from `current_level` to the next one.
static func xp_to_next(current_level: int, base_xp: float, growth: float) -> int:
	return int(round(base_xp * pow(growth, float(current_level - 1))))


## Pure level-up resolution: one grant may cross several thresholds.
## Returns {"level": int, "xp": int} — remaining xp toward the next level.
static func apply_xp(
	level_in: int, xp_in: int, amount: int, base_xp: float, growth: float
) -> Dictionary:
	var new_level: int = level_in
	var new_xp: int = xp_in + amount
	while true:
		var cost: int = xp_to_next(new_level, base_xp, growth)
		if cost <= 0:
			push_error("run_state: non-positive xp curve step, check progression.json")
			break
		if new_xp < cost:
			break
		new_xp -= cost
		new_level += 1
	return {"level": new_level, "xp": new_xp}


func _init() -> void:
	var curve: Dictionary = RunState.load_curve()
	_base_xp = float(curve.get("base_xp", 0.0))
	_growth = float(curve.get("growth", 0.0))


## XP cost of the current level's next step — the HUD bar denominator.
func xp_needed() -> int:
	return RunState.xp_to_next(level, _base_xp, _growth)


func add_xp(amount: int) -> void:
	var result: Dictionary = RunState.apply_xp(level, xp, amount, _base_xp, _growth)
	var previous_level: int = level
	level = int(result["level"])
	xp = int(result["xp"])
	for reached: int in range(previous_level + 1, level + 1):
		level_reached.emit(reached)
