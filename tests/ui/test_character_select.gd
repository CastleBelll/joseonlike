extends RefCounted
## Tests scripts/ui/character_select.gd's unlock logic. is_character_unlocked
## and unlock_reason_text never touch @onready scene nodes, so a plain
## `.new()` instance (never added to the tree) is safe to call them on.

func run() -> Array[String]:
	var failures: Array[String] = []
	var controller: Control = load("res://scripts/ui/character_select.gd").new()

	var default_char := {"id": "a", "unlock": {"type": "default"}}
	if not controller.is_character_unlocked(default_char):
		failures.append("a default-unlock character was reported locked")

	var gold_char := {"id": "b", "unlock": {"type": "gold", "cost": 500}}
	if controller.is_character_unlocked(gold_char):
		failures.append("a gold-locked character (not purchased) was reported unlocked")
	var gold_reason: String = controller.unlock_reason_text(gold_char)
	if not gold_reason.contains("500"):
		failures.append("gold unlock reason text does not mention the cost: '%s'" % gold_reason)

	var achievement_id := "test_char_select_unlock_achv"
	var achievement_char := {"id": "c", "unlock": {"type": "achievement", "achievement_id": achievement_id}}
	if controller.is_character_unlocked(achievement_char):
		failures.append("an achievement-locked character was reported unlocked before the achievement unlocked")

	SaveManager.set_value(AchievementTracker.UNLOCKED_PREFIX + achievement_id, true)
	if not controller.is_character_unlocked(achievement_char):
		failures.append("an achievement-locked character stayed locked after the achievement unlocked")

	controller.free()
	return failures
