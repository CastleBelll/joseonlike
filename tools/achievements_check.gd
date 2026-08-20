extends Node
## N9-65 evidence: an achievement is only real if finishing the right run
## actually awards it, and the unlock it promises actually arrives. The data
## contract and the unit tests both work on dictionaries; this drives the path
## a player takes — bank a run through SaveService and see what came back.
##
## It also opens the 업적 screen, because a reward nobody can read the rule for
## is a reward nobody knows how to earn.
## Run (rendered, for the screenshot): godot --path . res://tools/achievements_check.tscn

const SCREEN := "res://scenes/achievements.tscn"
const SETTLE_SEC := 0.4

var _failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if SaveService.instance == null:
		_fail("SaveManager autoload is not running")
		_finish()
		return
	SaveService.instance.profile = SaveProfile.default_profile()
	SaveService.instance._write_locked = true
	SaveService.instance._write_lock_reason = "a harness is using a throwaway profile"
	_check_award()
	await _open_screen()
	_finish()


func _check_award() -> void:
	var data: Dictionary = SaveService.instance.achievement_data()
	var target: Dictionary = _granter_of(data, Unlocks.MAP)
	if target.is_empty():
		_fail("nothing in the data grants the 지도")
		return
	var character: String = String(target.get("character", ""))
	if not character.is_empty():
		SaveService.instance.set_selected_character(character)
	if Unlocks.is_unlocked(SaveService.instance.profile, Unlocks.MAP):
		_fail("a fresh profile already owns the 지도")

	# A losing run must NOT hand it over. The condition is a victory, and an
	# award for merely showing up would say nothing about play.
	SaveService.instance.bank_run(120.0, 10, 5, false, {"victory": false, "level": 3})
	SaveService.instance.take_earned_achievements()
	if Unlocks.is_unlocked(SaveService.instance.profile, Unlocks.MAP):
		_fail("a defeat granted the 지도")

	var gold_before: int = SaveService.instance.gold()
	SaveService.instance.bank_run(
		420.0, 120, 80, true, {"victory": true, "level": 11, "evolutions": 1}
	)
	var ids: Array[String] = []
	for entry: Dictionary in SaveService.instance.take_earned_achievements():
		ids.append(String(entry.get("id", "")))
	print("ACH earned on the winning run: %s" % str(ids))
	if not Unlocks.is_unlocked(SaveService.instance.profile, Unlocks.MAP):
		_fail("clearing as '%s' did not grant the 지도" % character)
	if not ids.has(String(target.get("id", ""))):
		_fail("the granting achievement was not reported to the result screen")
	if SaveService.instance.gold() <= gold_before:
		_fail("the reward gold never arrived")

	# Handed over once: showing it again would read as earning it twice.
	if not SaveService.instance.take_earned_achievements().is_empty():
		_fail("the earned list was handed over twice")
	# And a later run must not re-award it.
	SaveService.instance.bank_run(420.0, 10, 5, true, {"victory": true, "level": 4})
	for entry: Dictionary in SaveService.instance.take_earned_achievements():
		if String(entry.get("id", "")) == String(target.get("id", "")):
			_fail("the same achievement was awarded twice")
	print("ACH 지도 owned=%s, gold %d -> %d" % [
		str(Unlocks.is_unlocked(SaveService.instance.profile, Unlocks.MAP)),
		gold_before, SaveService.instance.gold()
	])


func _granter_of(data: Dictionary, unlock_id: String) -> Dictionary:
	for entry: Dictionary in Achievements.entries(data):
		if String(entry.get("grants", "")) == unlock_id:
			return entry
	return {}


func _open_screen() -> void:
	var screen: Control = (load(SCREEN) as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(SETTLE_SEC).timeout
	var rows: Node = screen.get_node_or_null("Margin/Column/Scroll/Rows")
	if rows == null or rows.get_child_count() == 0:
		_fail("the 업적 screen drew no rows")
	else:
		print("ACH screen rows: %d" % rows.get_child_count())
	await _capture()


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := "user://achievements_check.png"
	get_viewport().get_texture().get_image().save_png(path)
	print("ACH shot: " + ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_failed = true
	push_error("achievements_check: " + message)


func _finish() -> void:
	print("ACHIEVEMENTS CHECK: " + ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)
