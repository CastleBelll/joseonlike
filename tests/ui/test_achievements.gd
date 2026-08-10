extends RefCounted
## Tests scripts/meta/achievements.gd (AchievementTracker autoload).
## Drives accumulate()/check_unlocks() directly with synthetic definitions so
## results never depend on GameData being loaded or on other test files'
## run order (tests/run_tests.gd contract: func run() -> Array[String]).

func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_unlock_at_threshold())
	failures.append_array(_test_no_double_grant_on_duplicate_signal())
	return failures


func _test_unlock_at_threshold() -> Array[String]:
	var failures: Array[String] = []
	var achievement_id := "test_achv_threshold"
	var counter_key := "test_achv_threshold_counter"
	var definitions: Array[Dictionary] = [{
		"id": achievement_id,
		"counter_key": counter_key,
		"target": 5,
		"reward": {"type": "gold", "amount": 20},
	}]
	var starting_gold: int = int(SaveManager.get_value("gold", 0))

	var total: int = AchievementTracker.accumulate(counter_key, 3)
	AchievementTracker.check_unlocks(counter_key, total, definitions)
	if AchievementTracker.is_unlocked(achievement_id):
		failures.append("unlocked before reaching target (total=%d, target=5)" % total)

	total = AchievementTracker.accumulate(counter_key, 2)
	AchievementTracker.check_unlocks(counter_key, total, definitions)
	if not AchievementTracker.is_unlocked(achievement_id):
		failures.append("did not unlock once total reached target (total=%d, target=5)" % total)

	var gold_after: int = int(SaveManager.get_value("gold", 0))
	if gold_after != starting_gold + 20:
		failures.append("reward not granted on unlock: expected gold %d, got %d" % [starting_gold + 20, gold_after])

	return failures


func _test_no_double_grant_on_duplicate_signal() -> Array[String]:
	var failures: Array[String] = []
	var achievement_id := "test_achv_double_grant"
	var counter_key := "test_achv_double_grant_counter"
	var definitions: Array[Dictionary] = [{
		"id": achievement_id,
		"counter_key": counter_key,
		"target": 1,
		"reward": {"type": "gold", "amount": 10},
	}]

	var total: int = AchievementTracker.accumulate(counter_key, 1)
	AchievementTracker.check_unlocks(counter_key, total, definitions)
	var gold_after_first: int = int(SaveManager.get_value("gold", 0))

	# Simulate a replayed/duplicated stat_recorded signal delivering the same
	# (or a later) total again.
	AchievementTracker.check_unlocks(counter_key, total, definitions)
	AchievementTracker.check_unlocks(counter_key, total + 5, definitions)
	var gold_after_replay: int = int(SaveManager.get_value("gold", 0))

	if gold_after_replay != gold_after_first:
		failures.append("reward granted more than once: gold went from %d to %d after replayed signals" % [gold_after_first, gold_after_replay])

	return failures
