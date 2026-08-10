class_name WaveSchedule
extends RefCounted
## Turns a stage's `waves` array into a flat, sorted list of spawn events and
## answers "what is due between two run-clock timestamps?".
##
## Pure and autoload-free so the headless test runner can load it (see
## CombatMath for why that matters).

const KEY_AT_SEC: String = "at_sec"
const KEY_MONSTER_ID: String = "monster_id"
const KEY_COUNT: String = "count"
const KEY_INTERVAL_SEC: String = "interval_sec"
const KEY_TIME_SEC: String = "time_sec"

## Two spawns in the same frame are fine, but a zero interval would collapse a
## whole wave onto one timestamp and hide pacing bugs; keep them distinguishable.
const MIN_INTERVAL_SEC: float = 0.01


## Flattens `waves` into [{time_sec: float, monster_id: String}] sorted by time.
## A wave of count N at at_sec T with interval I spawns at T, T+I, ... T+(N-1)*I.
static func expand(waves: Array) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for entry in waves:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("WaveSchedule: ignoring non-dictionary wave entry")
			continue
		var wave: Dictionary = entry
		var monster_id: String = String(wave.get(KEY_MONSTER_ID, ""))
		if monster_id.is_empty():
			push_warning("WaveSchedule: wave without monster_id ignored")
			continue
		var count: int = maxi(0, int(wave.get(KEY_COUNT, 0)))
		var at_sec: float = maxf(0.0, float(wave.get(KEY_AT_SEC, 0.0)))
		var interval_sec: float = maxf(MIN_INTERVAL_SEC, float(wave.get(KEY_INTERVAL_SEC, MIN_INTERVAL_SEC)))
		for index in count:
			events.append({
				KEY_TIME_SEC: at_sec + interval_sec * float(index),
				KEY_MONSTER_ID: monster_id,
			})
	events.sort_custom(_earlier_first)
	return events


## How many events, starting at `cursor`, are due at or before `time_sec`.
## The spawner walks the sorted list with a cursor instead of rescanning it, so
## a 600-second stage costs one comparison per frame once the waves run dry.
static func count_due(events: Array[Dictionary], cursor: int, time_sec: float) -> int:
	var due: int = 0
	var index: int = maxi(cursor, 0)
	while index < events.size():
		if float(events[index].get(KEY_TIME_SEC, 0.0)) > time_sec:
			break
		due += 1
		index += 1
	return due


static func _earlier_first(left: Dictionary, right: Dictionary) -> bool:
	return float(left.get(KEY_TIME_SEC, 0.0)) < float(right.get(KEY_TIME_SEC, 0.0))
