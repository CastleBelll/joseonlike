extends Node
## N9-76 evidence: the 수행자 선택 relayout, driven the way a player drives it.
##
## The unit test can prove the pure transitions, but the point of this screen is
## a distinction that only exists on the built tree: tapping a LOCKED tile must
## move the detail panel (so its unlock condition can be read) while leaving the
## saved selection alone. A screen that quietly selected the locked character,
## or one that refused to show it at all, would still pass a view-model test.
## Run (rendered, for the screenshot): godot --path . res://tools/select_check.tscn

const SCREEN := "res://scenes/character_select.tscn"
const SETTLE_SEC := 0.3
const OPEN_ID := "taoist"

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
	await _drive()
	_finish()


func _drive() -> void:
	var screen: Control = (load(SCREEN) as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(SETTLE_SEC).timeout

	var characters: Dictionary = CharacterSelectScreen.load_characters()
	var tiles: Node = screen.find_child("Tiles", true, false)
	if tiles == null or tiles.get_child_count() != characters.size():
		_fail("expected %d tiles, found %s" % [
			characters.size(), "none" if tiles == null else str(tiles.get_child_count())
		])
		return
	print("SELECT tiles: %d for %d characters" % [tiles.get_child_count(), characters.size()])

	if screen.get_node_or_null("Detail") == null:
		_fail("no detail panel")
		return
	if _panel_name(screen) != _display_name(characters, OPEN_ID):
		_fail("the panel did not open on the saved character")

	var locked_id: String = _first_locked(characters)
	if locked_id.is_empty():
		_fail("the roster has no locked character to test with")
		return

	# The act under test.
	_tap(screen, locked_id)
	await get_tree().process_frame

	if _panel_name(screen) != _display_name(characters, locked_id):
		_fail("tapping the locked tile did not move the panel to it")
	if screen.find_child("UnlockHeading", true, false) == null:
		_fail("the locked panel does not say how to unlock")
	if SaveService.instance.selected_character() != OPEN_ID:
		_fail("tapping a locked tile changed the saved selection to '%s'"
			% SaveService.instance.selected_character())
	if screen.find_child("SelectedBadge", true, false) != null:
		_fail("the locked panel claims to be the selected character")
	print("SELECT locked '%s' readable, saved selection still '%s'" % [
		locked_id, SaveService.instance.selected_character()
	])

	# And back: the open character is selectable again from the same strip.
	_tap(screen, OPEN_ID)
	await get_tree().process_frame
	if _panel_name(screen) != _display_name(characters, OPEN_ID):
		_fail("tapping the open tile did not return the panel")
	if screen.find_child("SelectedBadge", true, false) == null:
		_fail("the open character lost its 선택됨 badge")
	if SaveService.instance.selected_character() != OPEN_ID:
		_fail("the open character is no longer the saved selection")

	await _capture()


func _tap(screen: Control, id: String) -> void:
	var tile: Button = screen.find_child("Tile_" + id, true, false)
	if tile == null:
		_fail("no tile for '%s'" % id)
		return
	tile.pressed.emit()


## What the panel currently says its character is, read off the built label
## rather than the screen's private state — the label is what the player sees.
func _panel_name(screen: Control) -> String:
	var panel: Node = screen.get_node_or_null("Detail")
	if panel == null:
		return ""
	var label: Label = panel.find_child("NameLabel", true, false)
	return "" if label == null else label.text


func _display_name(characters: Dictionary, id: String) -> String:
	var model: Dictionary = CharacterSelectScreen.card_model(id, characters.get(id, {}), "")
	return "%s (%s)" % [model["name"], model["hanja"]]


func _first_locked(characters: Dictionary) -> String:
	for id: String in characters:
		if CharacterSelectScreen.is_locked(characters[id]):
			return id
	return ""


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := "user://select_check.png"
	get_viewport().get_texture().get_image().save_png(path)
	print("SELECT shot: " + ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_failed = true
	push_error("select_check: " + message)


func _finish() -> void:
	print("SELECT CHECK: " + ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)
