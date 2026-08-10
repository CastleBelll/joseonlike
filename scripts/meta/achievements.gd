extends Node
## Achievement counter tracker. Autoloaded so it observes EventBus.stat_recorded
## for the whole app lifetime, including stage runs outside the camp scene.
##
## Frozen contract: scripts/core/event_bus.gd, scripts/core/game_data.gd,
## scripts/core/save_manager.gd (ARCHITECTURE.md section 3).

signal achievement_unlocked(achievement_id: String, achievement: Dictionary)

const COUNTER_PREFIX := "achv_counter_"
const UNLOCKED_PREFIX := "achv_unlocked_"

var _run_start_unlocked_ids: Dictionary = {}


func _ready() -> void:
	EventBus.stat_recorded.connect(_on_stat_recorded)


func _on_stat_recorded(key: String, amount: int) -> void:
	record_stat(key, amount)


## Accumulates amount under key and checks GameData-defined achievements for unlocks.
func record_stat(key: String, amount: int) -> void:
	if amount == 0:
		return
	var total: int = accumulate(key, amount)
	check_unlocks(key, total, GameData.all_achievements())


## Adds amount to the persisted counter for key and returns the new total.
func accumulate(key: String, amount: int) -> int:
	var counter_key: String = COUNTER_PREFIX + key
	var total: int = int(SaveManager.get_value(counter_key, 0)) + amount
	SaveManager.set_value(counter_key, total)
	return total


func counter(key: String) -> int:
	return int(SaveManager.get_value(COUNTER_PREFIX + key, 0))


func is_unlocked(achievement_id: String) -> bool:
	return bool(SaveManager.get_value(UNLOCKED_PREFIX + achievement_id, false))


## Snapshots which achievements are already unlocked. Called at run start
## (character_select.gd) so results.gd can later report only what unlocked
## during that specific run via newly_unlocked_since_snapshot().
func snapshot_before_run() -> void:
	_run_start_unlocked_ids.clear()
	for achievement in GameData.all_achievements():
		var achievement_id: String = String(achievement.get("id", ""))
		if not achievement_id.is_empty() and is_unlocked(achievement_id):
			_run_start_unlocked_ids[achievement_id] = true


func newly_unlocked_since_snapshot() -> Array[Dictionary]:
	var newly: Array[Dictionary] = []
	for achievement in GameData.all_achievements():
		var achievement_id: String = String(achievement.get("id", ""))
		if achievement_id.is_empty():
			continue
		if is_unlocked(achievement_id) and not _run_start_unlocked_ids.has(achievement_id):
			newly.append(achievement)
	return newly


## Unlocks any achievement in `definitions` whose counter_key matches key and
## whose target is met. Guarded by is_unlocked() so a replayed or duplicated
## stat_recorded signal (same or later total) never grants a reward twice.
func check_unlocks(key: String, total: int, definitions: Array[Dictionary]) -> void:
	for achievement in definitions:
		if String(achievement.get("counter_key", "")) != key:
			continue
		var achievement_id: String = String(achievement.get("id", ""))
		if achievement_id.is_empty() or is_unlocked(achievement_id):
			continue
		if total >= int(achievement.get("target", 0)):
			_unlock(achievement_id, achievement)


func _unlock(achievement_id: String, achievement: Dictionary) -> void:
	SaveManager.set_value(UNLOCKED_PREFIX + achievement_id, true)
	_grant_reward(achievement.get("reward", {}))
	achievement_unlocked.emit(achievement_id, achievement)


func _grant_reward(reward: Dictionary) -> void:
	if reward.is_empty():
		return
	var reward_type: String = String(reward.get("type", ""))
	match reward_type:
		"gold":
			var gold: int = int(SaveManager.get_value("gold", 0)) + int(reward.get("amount", 0))
			SaveManager.set_value("gold", gold)
		_:
			push_warning("AchievementTracker: unknown reward type '%s'" % reward_type)
