extends RefCounted
## Tests scripts/meta/quests.gd (QuestTracker autoload): daily-reset boundary
## logic. Uses ensure_daily_reset(today_key) with synthetic day keys instead
## of the real clock so the boundary is deterministic.
##
## Audit note (harness defect found by core-engine): under
## `godot --headless --script tests/run_tests.gd` no autoload's _ready() ever
## runs, so EventBus.stat_recorded is never actually connected to
## QuestTracker._on_stat_recorded during a test run.
## _test_daily_reset_boundary() below was NOT vacuous despite that -- it
## calls ensure_daily_reset()/record_stat() directly and never depended on
## the signal being wired -- but the signal path itself had never been
## exercised. _test_signal_wiring_reaches_record_stat() closes that gap the
## way core-engine's tests/core/test_run_state.gd does: construct a
## throwaway instance, call _ready() by hand, then emit the real
## EventBus.stat_recorded signal.

const QUEST_SCRIPT := preload("res://scripts/meta/quests.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_daily_reset_boundary())
	failures.append_array(_test_signal_wiring_reaches_record_stat())
	return failures


func _test_daily_reset_boundary() -> Array[String]:
	var failures: Array[String] = []
	var key := "test_quest_counter"

	QuestTracker.ensure_daily_reset("2026-01-01")
	QuestTracker.record_stat(key, 3)
	if QuestTracker.daily_progress(key) != 3:
		failures.append("daily_progress did not accumulate: expected 3, got %d" % QuestTracker.daily_progress(key))

	# Reload within the same day must not reset (no wipe / no re-grant mid-day).
	var reset_happened: bool = QuestTracker.ensure_daily_reset("2026-01-01")
	if reset_happened:
		failures.append("ensure_daily_reset reported a reset for a repeated same-day call")
	if QuestTracker.daily_progress(key) != 3:
		failures.append("same-day reload wiped daily progress: got %d" % QuestTracker.daily_progress(key))

	# A new day key must trigger exactly one reset.
	reset_happened = QuestTracker.ensure_daily_reset("2026-01-02")
	if not reset_happened:
		failures.append("ensure_daily_reset did not reset on a new day key")
	if QuestTracker.daily_progress(key) != 0:
		failures.append("daily progress not cleared on new-day reset: got %d" % QuestTracker.daily_progress(key))

	# Story progress is a separate counter family and must survive daily resets.
	var story_key := "test_quest_story_counter"
	QuestTracker.record_stat(story_key, 7)
	QuestTracker.ensure_daily_reset("2026-01-02")
	if QuestTracker.story_progress(story_key) != 7:
		failures.append("story_progress was affected by a daily reset: got %d" % QuestTracker.story_progress(story_key))

	return failures


## The actual production path: EventBus.stat_recorded -> _on_stat_recorded ->
## record_stat(). Wires a throwaway QuestTracker instance by hand (the real
## autoload's _ready() never runs under the headless runner) and drives it
## through the real global EventBus signal.
func _test_signal_wiring_reaches_record_stat() -> Array[String]:
	var failures: Array[String] = []
	var key := "test_quest_signal_counter"

	var wired: Node = QUEST_SCRIPT.new()
	wired._ready()  # The line the headless runner never calls on the real autoload.
	wired.ensure_daily_reset("2026-01-03")

	EventBus.stat_recorded.emit(key, 4)
	if wired.daily_progress(key) != 4:
		failures.append("EventBus.stat_recorded never reached QuestTracker through the real signal connection; daily_progress is %d, expected 4" % wired.daily_progress(key))
	if wired.story_progress(key) != 4:
		failures.append("EventBus.stat_recorded never reached QuestTracker's story counter through the real signal connection; story_progress is %d, expected 4" % wired.story_progress(key))

	EventBus.stat_recorded.emit(key, 2)
	if wired.daily_progress(key) != 6:
		failures.append("a second real signal did not accumulate on top of the first: daily_progress is %d, expected 6" % wired.daily_progress(key))

	wired.free()  # Frees the connection along with the node.
	return failures
