extends Node
## Daily and story quest counter scaffolding. Autoloaded for the same reason
## as AchievementTracker: quest counters advance during stage runs outside
## the camp scene. data/quests.json is not part of the frozen schema yet
## (ARCHITECTURE.md section 4), so this tracks raw per-key counters that a
## future quest data file can read progress against without a rewrite.

signal daily_reset()
signal quest_progress(key: String, daily_total: int, story_total: int)

const DAY_KEY := "quest_day_key"
const DAILY_COUNTERS_KEY := "quest_daily_counters"
const DAILY_CLAIMED_KEY := "quest_daily_claimed"
const STORY_COUNTERS_KEY := "quest_story_counters"
const STORY_CLAIMED_KEY := "quest_story_claimed"


func _ready() -> void:
	ensure_daily_reset()
	EventBus.stat_recorded.connect(_on_stat_recorded)


func _on_stat_recorded(key: String, amount: int) -> void:
	record_stat(key, amount)


func record_stat(key: String, amount: int) -> void:
	if amount == 0:
		return
	var daily: Dictionary = SaveManager.get_value(DAILY_COUNTERS_KEY, {})
	daily[key] = int(daily.get(key, 0)) + amount
	SaveManager.set_value(DAILY_COUNTERS_KEY, daily)

	var story: Dictionary = SaveManager.get_value(STORY_COUNTERS_KEY, {})
	story[key] = int(story.get(key, 0)) + amount
	SaveManager.set_value(STORY_COUNTERS_KEY, story)

	quest_progress.emit(key, int(daily[key]), int(story[key]))


func daily_progress(key: String) -> int:
	var daily: Dictionary = SaveManager.get_value(DAILY_COUNTERS_KEY, {})
	return int(daily.get(key, 0))


func story_progress(key: String) -> int:
	var story: Dictionary = SaveManager.get_value(STORY_COUNTERS_KEY, {})
	return int(story.get(key, 0))


func is_daily_claimed(quest_id: String) -> bool:
	var claimed: Dictionary = SaveManager.get_value(DAILY_CLAIMED_KEY, {})
	return bool(claimed.get(quest_id, false))


func claim_daily(quest_id: String) -> void:
	var claimed: Dictionary = SaveManager.get_value(DAILY_CLAIMED_KEY, {})
	claimed[quest_id] = true
	SaveManager.set_value(DAILY_CLAIMED_KEY, claimed)


func is_story_claimed(quest_id: String) -> bool:
	var claimed: Dictionary = SaveManager.get_value(STORY_CLAIMED_KEY, {})
	return bool(claimed.get(quest_id, false))


func claim_story(quest_id: String) -> void:
	var claimed: Dictionary = SaveManager.get_value(STORY_CLAIMED_KEY, {})
	claimed[quest_id] = true
	SaveManager.set_value(STORY_CLAIMED_KEY, claimed)


func current_day_key() -> String:
	var datetime: Dictionary = Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d" % [datetime.year, datetime.month, datetime.day]


## Resets daily counters/claims when the stored day key differs from today.
## today_key lets tests drive this deterministically instead of real-clock time.
## Returns true when a reset happened (idempotent within the same day, so a
## profile reload never re-grants or wipes progress mid-day).
func ensure_daily_reset(today_key: String = "") -> bool:
	var today: String = today_key if today_key != "" else current_day_key()
	var stored_day: String = String(SaveManager.get_value(DAY_KEY, ""))
	if stored_day == today:
		return false
	SaveManager.set_value(DAY_KEY, today)
	SaveManager.set_value(DAILY_COUNTERS_KEY, {})
	SaveManager.set_value(DAILY_CLAIMED_KEY, {})
	daily_reset.emit()
	return true
