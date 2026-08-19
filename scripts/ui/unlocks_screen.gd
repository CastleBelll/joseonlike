class_name UnlocksScreen
extends Control
## 해금 screen (N9-58): the permanent things gold can buy that are not stat
## ranks. One full-width row card per entry, in the camp's existing card
## language (DESIGN.md §3).
##
## Every row states its price and whether it is affordable BEFORE the tap.
## Letting the player press and then explaining why nothing happened is the
## pattern this project keeps having to undo.

const CAMP_SCENE := "res://scenes/camp.tscn"
const UNLOCKS_PATH := "res://data/unlocks.json"

const MARGIN_SIDE := 24
const MARGIN_TOP := 24
const MARGIN_BOTTOM := 32
const BACK_SIZE := 44.0
const CARD_CORNER_RADIUS := 12
const CARD_BORDER_WIDTH := 2
const CARD_PADDING := 14
const CARD_MIN_HEIGHT := 96.0
const PILL_CORNER_RADIUS := 10
const PILL_PADDING_X := 10
const PILL_PADDING_Y := 2
## Unaffordable rows stay readable rather than greyed to near-nothing: the
## player has to be able to read what they are saving up for.
const LOCKED_ALPHA := 0.75

var _data: Dictionary = {}
var _rows_box: VBoxContainer
var _gold_label: Label


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(UNLOCKS_PATH)
	)
	_data = parsed if parsed is Dictionary else {}
	var background := ColorRect.new()
	background.name = "Background"
	background.color = UiPalette.NIGHT
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", MARGIN_SIDE)
	margin.add_theme_constant_override("margin_right", MARGIN_SIDE)
	margin.add_theme_constant_override("margin_top", MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", MARGIN_BOTTOM)
	add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	margin.add_child(column)
	column.add_child(_build_header())

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows_box = VBoxContainer.new()
	_rows_box.name = "Rows"
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	scroll.add_child(_rows_box)
	column.add_child(scroll)
	_refresh()


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", UiPalette.SPACE_SM)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "‹"
	back.flat = true
	back.custom_minimum_size = Vector2(BACK_SIZE, BACK_SIZE)
	back.add_theme_color_override("font_color", UiPalette.GOLD)
	back.add_theme_color_override("font_hover_color", UiPalette.GOLD)
	back.add_theme_color_override("font_pressed_color", UiPalette.GOLD_BORDER)
	back.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)
	back.pressed.connect(_on_back_pressed)
	header.add_child(back)

	var title := _label(
		UiLocale.text("unlocks.title"), UiPalette.FONT_SIZE_TITLE, UiPalette.GOLD
	)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var pill := PanelContainer.new()
	pill.name = "GoldPill"
	pill.add_theme_stylebox_override("panel", _pill_box(UiPalette.CARD_BG))
	_gold_label = _label("", UiPalette.FONT_SIZE_BODY, UiPalette.GOLD)
	_gold_label.name = "GoldValue"
	pill.add_child(_gold_label)
	header.add_child(pill)
	return header


func _refresh() -> void:
	for child: Node in _rows_box.get_children():
		child.queue_free()
	var profile: Dictionary = _profile()
	_gold_label.text = "%d냥" % int(profile.get("gold", 0))
	for row: Dictionary in Unlocks.rows(profile, _data, UiLocale.current_locale):
		_rows_box.add_child(_build_row(row))


func _build_row(row: Dictionary) -> Control:
	var owned: bool = bool(row["owned"])
	var affordable: bool = bool(row["affordable"])
	var card := Button.new()
	card.name = "Row_" + String(row["id"])
	# NOT flat: a flat Button skips its stylebox entirely, which left the rows
	# as bare text floating on the background with no card behind them.
	card.custom_minimum_size = Vector2(0.0, CARD_MIN_HEIGHT)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(state, _card_box(owned))
	# An owned row is no longer a button; leaving it pressable would invite a
	# tap that can only ever be refused.
	card.disabled = owned
	if not owned:
		card.pressed.connect(_on_row_pressed.bind(String(row["id"])))

	var box := VBoxContainer.new()
	box.name = "Body"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = CARD_PADDING
	box.offset_right = -CARD_PADDING
	box.offset_top = CARD_PADDING
	box.offset_bottom = -CARD_PADDING
	box.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	card.add_child(box)

	var top := HBoxContainer.new()
	top.name = "TopLine"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	var name_label: Label = _label(
		String(row["name"]), UiPalette.FONT_SIZE_BODY,
		UiPalette.TEXT_ON_DARK if owned or affordable else UiPalette.TEXT_MUTED_ON_DARK
	)
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(_status_pill(owned, affordable, int(row["cost"])))
	box.add_child(top)

	var desc: Label = _label(
		String(row["desc"]), UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_MUTED_ON_DARK
	)
	desc.name = "Desc"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.modulate.a = 1.0 if owned or affordable else LOCKED_ALPHA
	box.add_child(desc)
	return card


## Owned reads as a state, not a price. Unaffordable still shows the price —
## the number IS the goal, so hiding it removes the reason to save.
func _status_pill(owned: bool, affordable: bool, cost: int) -> Control:
	var pill := PanelContainer.new()
	pill.name = "Status"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: Color = UiPalette.CARD_BG
	var text: String = "%d냥" % cost
	var color: Color = UiPalette.GOLD if affordable else UiPalette.TEXT_MUTED_ON_DARK
	if owned:
		fill = UiPalette.SUCCESS
		text = UiLocale.text("unlocks.owned")
		color = UiPalette.INK
	pill.add_theme_stylebox_override("panel", _pill_box(fill))
	pill.add_child(_label(text, UiPalette.FONT_SIZE_LABEL, color))
	return pill


func _on_row_pressed(unlock_id: String) -> void:
	var result: Dictionary = Unlocks.purchase(_profile(), _data, unlock_id)
	if not bool(result.get("ok", false)):
		# Silent by design: the row already stated the price and whether it was
		# affordable, so the only refusal reachable here is a double-tap racing
		# the refresh.
		return
	if SaveService.instance != null:
		SaveService.instance.profile = result["profile"]
		SaveService.instance.save_profile()
	if SfxService.instance != null:
		SfxService.instance.play("levelup")
	_refresh()


func _profile() -> Dictionary:
	if SaveService.instance == null:
		return SaveProfile.default_profile()
	return SaveService.instance.profile


func _card_box(owned: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.CARD_BG
	box.set_corner_radius_all(CARD_CORNER_RADIUS)
	box.set_border_width_all(CARD_BORDER_WIDTH)
	box.border_color = UiPalette.SUCCESS if owned else UiPalette.CARD_BORDER_DIM
	return box


func _pill_box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(PILL_CORNER_RADIUS)
	box.content_margin_left = PILL_PADDING_X
	box.content_margin_right = PILL_PADDING_X
	box.content_margin_top = PILL_PADDING_Y
	box.content_margin_bottom = PILL_PADDING_Y
	return box


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(CAMP_SCENE)
