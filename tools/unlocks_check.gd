extends Node
## N9-58 evidence: opens the 해금 screen on an in-memory profile and proves the
## three states a row can be in — affordable, too expensive, already owned —
## then buys one and checks the gold actually moved. A screen that draws is not
## the same as a screen that transacts, and only a running one can show either.
## Run (rendered, for the screenshot): godot --path . res://tools/unlocks_check.tscn

const SCREEN := "res://scenes/unlocks.tscn"
const SETTLE_SEC := 0.4
## Enough for the shipped 지도 and not a coin more, so the shot shows an
## affordable row rather than a rich player's shopping list.
const START_GOLD := 900

var _screen: Control
var _failed: bool = false


func _ready() -> void:
	if SaveService.instance != null:
		var profile: Dictionary = SaveProfile.default_profile()
		profile["gold"] = START_GOLD
		SaveService.instance.profile = profile
		SaveService.instance._write_locked = true
		SaveService.instance._write_lock_reason = "a harness is using a throwaway profile"
	_screen = (load(SCREEN) as PackedScene).instantiate()
	add_child(_screen)
	await get_tree().create_timer(SETTLE_SEC).timeout
	_check()


func _check() -> void:
	var data: Dictionary = _data()
	var profile: Dictionary = SaveService.instance.profile
	var rows: Array[Dictionary] = Unlocks.rows(profile, data, "ko")
	for row: Dictionary in rows:
		print("UNLOCK row %s: %d냥 owned=%s affordable=%s" % [
			row["id"], int(row["cost"]), str(row["owned"]), str(row["affordable"])
		])
	if rows.is_empty():
		_fail("the screen had no rows to draw")
	await _capture("unlocks_before")
	var card: Button = _screen.get_node_or_null("Margin/Column/Scroll/Rows/Row_map")
	if card == null:
		_fail("the 지도 row is not on the screen")
		_finish()
		return
	var gold_before: int = int(profile.get("gold", 0))
	card.pressed.emit()
	await get_tree().process_frame
	var after: Dictionary = SaveService.instance.profile
	if not Unlocks.is_unlocked(after, Unlocks.MAP):
		_fail("pressing the row did not grant the unlock")
	if int(after.get("gold", 0)) != gold_before - Unlocks.cost(data, Unlocks.MAP):
		_fail("gold did not move by the price")
	else:
		print("UNLOCK bought 지도: %d냥 -> %d냥" % [gold_before, int(after.get("gold", 0))])
	# The owned row must stop being pressable, or a second tap is a refusal
	# with no explanation.
	var owned_card: Button = _screen.get_node_or_null("Margin/Column/Scroll/Rows/Row_map")
	if owned_card != null and not owned_card.disabled:
		_fail("an owned row is still pressable")
	await _capture("unlocks_after")
	_finish()


func _data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(UnlocksScreen.UNLOCKS_PATH)
	)
	return parsed if parsed is Dictionary else {}


func _capture(name_part: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path: String = "user://%s.png" % name_part
	get_viewport().get_texture().get_image().save_png(path)
	print("UNLOCK shot: " + ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_failed = true
	push_error("unlocks_check: " + message)


func _finish() -> void:
	print("UNLOCKS CHECK: " + ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)
