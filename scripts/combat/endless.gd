class_name Endless
extends RefCounted
## Endless night (N9-60): a run with no clock, ending only when the player
## does. Pure and node-free so the suite can drive the escalation without
## playing for an hour.
##
## The stage's own waves are REUSED rather than a second schedule being
## written. Every loop replays the schedule from `loop_from_sec` onward with
## more monsters and tougher ones, so an endless night is the night the player
## already knows, turned up — and retuning the stage retunes endless with it.
## A separate wave table would drift out of step the first time either changed.

## Marks the run_lengths entry that never ends. An explicit flag rather than a
## duration_scale of 0: the validator requires a positive scale for every
## entry, and a magic zero would make "endless" and "misconfigured" the same
## value.
const FLAG := "endless"


static func is_endless(run_length: Dictionary) -> bool:
	return bool(run_length.get(FLAG, false))


## How many times the schedule has restarted by `elapsed`. Zero is the first
## pass through the stage's own waves — the ordinary night everyone knows.
static func loop_index(elapsed_sec: float, endless: Dictionary) -> int:
	var start: float = float(endless.get("loop_from_sec", 0.0))
	var period: float = float(endless.get("loop_period_sec", 0.0))
	if period <= 0.0 or elapsed_sec <= start:
		return 0
	return int(floor((elapsed_sec - start) / period)) + 1


## When loop `index` begins. Loop 0 has no start of its own — it is the stage
## as written — so this is only meaningful from 1 up.
static func loop_start_sec(index: int, endless: Dictionary) -> float:
	var start: float = float(endless.get("loop_from_sec", 0.0))
	var period: float = float(endless.get("loop_period_sec", 0.0))
	return start + period * float(maxi(index - 1, 0))


## Stat multiplier for monsters spawned during loop `index`. Growth is LINEAR
## per loop, not exponential: an exponential curve becomes unplayable within a
## few loops, and the interesting part of an endless run is the long middle
## where the build and the pressure trade places.
static func loop_scale(index: int, growth: float) -> float:
	return 1.0 + maxf(growth, 0.0) * float(maxi(index, 0))


## The stage's waves re-timed into loop `index`. Waves before `loop_from_sec`
## are left out: those are the opening, and replaying a gentle opening every
## loop would make the night get EASIER as it went on.
static func loop_waves(
	waves: Array, endless: Dictionary, index: int
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if index <= 0:
		return out
	var from: float = float(endless.get("loop_from_sec", 0.0))
	var base: float = loop_start_sec(index, endless)
	var count_scale: float = loop_scale(
		index, float(endless.get("count_growth_per_loop", 0.0))
	)
	for raw: Variant in waves:
		if raw is not Dictionary:
			continue
		var wave: Dictionary = raw
		var at: float = float(wave.get("at_sec", 0.0))
		if at < from:
			continue
		var copy: Dictionary = wave.duplicate()
		copy["at_sec"] = base + (at - from)
		copy["count"] = maxi(int(round(float(int(wave.get("count", 0))) * count_scale)), 1)
		out.append(copy)
	return out


## Seconds from one boss to the next. Zero means the boss never returns, which
## would leave the late loops with nothing to fight for.
static func boss_repeat_sec(endless: Dictionary) -> float:
	return float(endless.get("boss_repeat_sec", 0.0))


## Data contract for validate_data. The failure this guards is a loop that
## produces no waves at all — the run would go quiet forever and read as the
## game having crashed rather than as a mode.
static func data_issues(stage: Dictionary, label: String) -> Array[String]:
	var issues: Array[String] = []
	var endless: Dictionary = stage.get(FLAG, {})
	if endless.is_empty():
		return issues
	for key: String in ["loop_period_sec", "boss_repeat_sec"]:
		if float(endless.get(key, 0.0)) <= 0.0:
			issues.append("%s.endless.%s must be positive" % [label, key])
	if float(endless.get("loop_from_sec", -1.0)) < 0.0:
		issues.append(label + ".endless.loop_from_sec must not be negative")
	# Growth is required rather than defaulted to zero: an endless night whose
	# escalation was silently omitted plays as a flat grind, and nothing else
	# would ever say so.
	for key: String in [
		"hp_growth_per_loop", "damage_growth_per_loop", "count_growth_per_loop"
	]:
		if not endless.has(key):
			issues.append("%s.endless.%s missing" % [label, key])
		elif float(endless[key]) < 0.0:
			issues.append("%s.endless.%s cannot be negative" % [label, key])
	if loop_waves(stage.get("waves", []), endless, 1).is_empty():
		issues.append(
			label + ".endless.loop_from_sec is past every wave — the loop would be silent"
		)
	return issues
