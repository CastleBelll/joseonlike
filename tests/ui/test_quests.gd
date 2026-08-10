extends RefCounted
## Tests scripts/meta/quests.gd (QuestTracker autoload): daily-reset boundary
## logic. Uses ensure_daily_reset(today_key) with synthetic day keys instead
## of the real clock so the boundary is deterministic.

func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_daily_reset_boundary())
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
