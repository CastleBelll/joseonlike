extends RefCounted
## Tests scripts/meta/achievements.gd (AchievementTracker autoload).
##
## Audit note (harness defect found by core-engine): under
## `godot --headless --script tests/run_tests.gd` the scene tree is never
## processed, so no autoload's _ready() ever runs and EventBus.stat_recorded
## is never actually connected to AchievementTracker._on_stat_recorded during
## a test run. The two tests below were NOT vacuous despite that -- they call
## accumulate()/check_unlocks() directly and never depended on the signal
## being wired -- but that also meant the signal path itself, and the
## exactly-once guarantee AS SEEN THROUGH IT, had never been exercised even
## though _test_no_double_grant_on_duplicate_signal's name suggested it was.
## _test_exactly_once_through_real_signal_path() below closes that gap the
## way core-engine's tests/core/test_run_state.gd does: construct a
## throwaway instance, call _ready() by hand to make the real connection,
## then emit the real EventBus.stat_recorded signal.

const ACHIEVEMENT_SCRIPT := preload("res://scripts/meta/achievements.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_unlock_at_threshold())
	failures.append_array(_test_no_double_grant_on_duplicate_check())
	failures.append_array(_test_exactly_once_through_real_signal_path())
	return failures


## Exercises accumulate()/check_unlocks() directly with synthetic
## definitions -- deliberately independent of GameData and of any autoload
## wiring, so it stays deterministic regardless of run order or the harness
## defect above.
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


## Same caveat as above: this proves check_unlocks() itself is idempotent
## when called twice with the same/later total. It does NOT touch
## EventBus.stat_recorded -- renamed from *_duplicate_signal to
## *_duplicate_check so the name stops implying signal coverage it doesn't
## have. See _test_exactly_once_through_real_signal_path() for that.
func _test_no_double_grant_on_duplicate_check() -> Array[String]:
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

	# Simulate a replayed/duplicated stat_recorded delivery reaching
	# check_unlocks again with the same (or a later) total.
	AchievementTracker.check_unlocks(counter_key, total, definitions)
	AchievementTracker.check_unlocks(counter_key, total + 5, definitions)
	var gold_after_replay: int = int(SaveManager.get_value("gold", 0))

	if gold_after_replay != gold_after_first:
		failures.append("reward granted more than once: gold went from %d to %d after replayed checks" % [gold_after_first, gold_after_replay])

	return failures


## The actual production path: EventBus.stat_recorded -> _on_stat_recorded ->
## record_stat() -> accumulate() + check_unlocks() using the real
## GameData.all_achievements(). Wires a throwaway AchievementTracker instance
## by hand (the real autoload's _ready() never runs under the headless
## runner) and drives it through the real global EventBus signal, against
## real content data, to prove the exactly-once guarantee holds end to end,
## not just through direct method calls.
func _test_exactly_once_through_real_signal_path() -> Array[String]:
	var failures: Array[String] = []

	var load_result: Error = GameData.load_all()
	if load_result != OK:
		failures.append("GameData.load_all() failed (error %d); cannot exercise the real EventBus.stat_recorded path" % load_result)
		return failures

	var achievement: Dictionary = {}
	for entry: Dictionary in GameData.all_achievements():
		if String(entry.get("id", "")) == "first_boss":
			achievement = entry
			break
	if achievement.is_empty():
		failures.append("data/achievements.json has no 'first_boss' entry (ARCHITECTURE.md section 4's own example id); cannot exercise the real signal path")
		return failures

	var counter_key: String = String(achievement.get("counter_key", ""))
	var target: int = int(achievement.get("target", 1))
	var reward_amount: int = int(achievement.get("reward", {}).get("amount", 0))

	var wired: Node = ACHIEVEMENT_SCRIPT.new()
	wired._ready()  # The line the headless runner never calls on the real autoload.

	# Force a known-locked starting state: this achievement may already be
	# unlocked by profile state left over from elsewhere in the process.
	SaveManager.set_value(AchievementTracker.COUNTER_PREFIX + counter_key, 0)
	SaveManager.set_value(AchievementTracker.UNLOCKED_PREFIX + "first_boss", false)
	var starting_gold: int = int(SaveManager.get_value("gold", 0))

	EventBus.stat_recorded.emit(counter_key, target)
	if not wired.is_unlocked("first_boss"):
		failures.append("EventBus.stat_recorded never reached AchievementTracker through the real signal connection; first_boss stayed locked")
	var gold_after_first: int = int(SaveManager.get_value("gold", 0))
	if gold_after_first != starting_gold + reward_amount:
		failures.append("reward not granted through the real signal path: expected gold %d, got %d" % [starting_gold + reward_amount, gold_after_first])

	# A replayed/duplicated stat_recorded delivery must not double-grant.
	EventBus.stat_recorded.emit(counter_key, target)
	var gold_after_replay: int = int(SaveManager.get_value("gold", 0))
	if gold_after_replay != gold_after_first:
		failures.append("reward granted more than once through the real signal path: gold went from %d to %d after a replayed signal" % [gold_after_first, gold_after_replay])

	wired.free()  # Frees the connection along with the node.
	return failures
