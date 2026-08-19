class_name GuideDialog
extends CanvasLayer
## First-boot guide dialogue (N9-4), DESIGN.md §3 NPC/내레이션 grammar:
## bottom-fixed dark panel (NIGHT_BROWN + gold border), speaker name in
## GOLD over a divider, white body text, one wood button. The speaker's
## portrait sits in a dark well on the left (우치's select-card portrait).
## Pages advance one tap at a time; `finished` fires after the last page.
## Runs with PROCESS_MODE_ALWAYS so it works over a paused tree.

signal finished
## N9-14 interactive pages: fired whenever a new page shows, with its
## "await" action ("" for tap-through pages) so the stage can unpause the
## tree and aim the highlight.
signal page_shown(index: int, await_action: String)

const LAYER_ABOVE_HUD := 12
const PANEL_MARGIN := 16.0
## N9-16: lifted off the bottom edge — it sat on the joystick zone and read
## as glued to the frame (owner report).
const PANEL_BOTTOM_MARGIN := 120.0
const PANEL_HEIGHT := 190.0
const PANEL_CORNER := 12
const PANEL_BORDER_WIDTH := 2
const PAD := 16.0
const PORTRAIT_SIZE := 96.0
const PORTRAIT_CORNER := 8
const BUTTON_SIZE := Vector2(120.0, 48.0)
const PORTRAIT_PATH := "res://asset/characters/taoist/portrait.png"

var _pages: Array[Dictionary] = []
var _index: int = 0
var _name_label: Label
var _body_label: Label
var _next_button: Button


func _ready() -> void:
	layer = LAYER_ABOVE_HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var blocker := Control.new()
	blocker.name = "Blocker"
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.NIGHT_BROWN
	style.border_color = UiPalette.GOLD_BORDER
	style.set_border_width_all(PANEL_BORDER_WIDTH)
	style.set_corner_radius_all(PANEL_CORNER)
	style.set_content_margin_all(PAD)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = PANEL_MARGIN
	panel.offset_right = -PANEL_MARGIN
	panel.offset_top = -(PANEL_HEIGHT + PANEL_BOTTOM_MARGIN)
	panel.offset_bottom = -PANEL_BOTTOM_MARGIN
	blocker.add_child(panel)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", int(PAD))
	panel.add_child(row)

	var well := PanelContainer.new()
	well.name = "PortraitWell"
	well.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var well_style := StyleBoxFlat.new()
	well_style.bg_color = UiPalette.NIGHT
	well_style.set_corner_radius_all(PORTRAIT_CORNER)
	well.add_theme_stylebox_override("panel", well_style)
	if ResourceLoader.exists(PORTRAIT_PATH, "Texture2D"):
		var portrait := TextureRect.new()
		portrait.texture = load(PORTRAIT_PATH)
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		well.add_child(portrait)
	row.add_child(well)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	row.add_child(column)

	_name_label = Label.new()
	_name_label.name = "SpeakerName"
	_name_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	_name_label.add_theme_color_override("font_color", UiPalette.GOLD)
	column.add_child(_name_label)

	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.color = UiPalette.GOLD_BORDER
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	column.add_child(divider)

	_body_label = Label.new()
	_body_label.name = "Body"
	_body_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	_body_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body_label)

	var button_row := HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(button_row)
	_next_button = Button.new()
	_next_button.name = "NextButton"
	_next_button.custom_minimum_size = BUTTON_SIZE
	WoodButton.apply(_next_button)
	_next_button.pressed.connect(_on_next_pressed)
	button_row.add_child(_next_button)


func open(pages: Array[Dictionary]) -> void:
	if pages.is_empty():
		finished.emit()
		return
	_pages = pages
	_index = 0
	_show_page()
	visible = true
	_next_button.grab_focus()


func _show_page() -> void:
	var page: Dictionary = _pages[_index]
	_name_label.text = String(page.get("name", ""))
	_body_label.text = String(page.get("text", ""))
	_next_button.text = "가자" if _index == _pages.size() - 1 else "다음"
	# N9-14: an await page hides the button — the ACTION advances it — and
	# releases the input blocker so the player can actually play.
	var await_action: String = String(page.get("await", ""))
	_next_button.visible = await_action.is_empty()
	(get_node("Blocker") as Control).mouse_filter = (
		Control.MOUSE_FILTER_IGNORE if not await_action.is_empty()
		else Control.MOUSE_FILTER_STOP
	)
	page_shown.emit(_index, await_action)


## What the current page is waiting for, or "" for a tap page. Public so a
## caller can answer the guide without reading its private index.
func awaiting() -> String:
	if _index < 0 or _index >= _pages.size():
		return ""
	return String(_pages[_index].get("await", ""))


## N9-14: the stage reports gameplay actions; the matching await page
## advances. Wrong/duplicate actions are ignored.
func notify_action(action: String) -> void:
	if not visible or _pages.is_empty():
		return
	if String(_pages[_index].get("await", "")) != action:
		return
	_advance()


func _on_next_pressed() -> void:
	_advance()


func _advance() -> void:
	_index += 1
	if _index >= _pages.size():
		visible = false
		finished.emit()
		return
	_show_page()
