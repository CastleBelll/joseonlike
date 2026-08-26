class_name AchievementsScreen
extends Control
## 업적 screen (N9-65). One full-width row card per achievement, in the camp's
## existing card language (DESIGN.md §3).
##
## Nothing here is pressable. Achievements are not bought or claimed — they
## complete on their own when a run banks, and their reward is already in the
## profile by the time this screen can be opened. A button that only ever says
## "already done" is the dead tap this project keeps removing.
##
## Every row shows its condition, how far along it is, and what it grants, so
## the screen answers "what do I do to get the 지도" rather than only listing
## what is missing.

const CAMP_SCENE := "res://scenes/camp.tscn"
const UNLOCKS_PATH := "res://data/unlocks.json"
const ACHIEVEMENTS_PATH := "res://data/achievements.json"

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
var _unlocks: Dictionary = {}
## Same reason as the bestiary: a full-width row wastes a landscape screen and
## halves how much of the list is on it. One column is the vertical list.
var _rows_box: GridContainer
var _count_label: Label


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(ACHIEVEMENTS_PATH)
	)
	_data = parsed if parsed is Dictionary else {}
	var unlocks: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(UNLOCKS_PATH)
	)
	_unlocks = unlocks if unlocks is Dictionary else {}
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
	_rows_box = GridContainer.new()
	_rows_box.name = "Rows"
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("h_separation", UiPalette.SPACE_SM)
	_rows_box.add_theme_constant_override("v_separation", UiPalette.SPACE_SM)
	scroll.add_child(_rows_box)
	column.add_child(scroll)
	_apply_columns()
	resized.connect(_apply_columns)
	_refresh()


## One column in portrait, two on a screen wide enough to read them side by side.
func _apply_columns() -> void:
	if _rows_box != null:
		_rows_box.columns = 2 if size.x > size.y else 1


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
		UiLocale.text("achievements.title"), UiPalette.FONT_SIZE_TITLE, UiPalette.GOLD
	)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var pill := PanelContainer.new()
	pill.name = "CountPill"
	pill.add_theme_stylebox_override("panel", _pill_box(UiPalette.CARD_BG))
	_count_label = _label("", UiPalette.FONT_SIZE_BODY, UiPalette.GOLD)
	_count_label.name = "CountValue"
	pill.add_child(_count_label)
	header.add_child(pill)
	return header


func _refresh() -> void:
	for child: Node in _rows_box.get_children():
		child.queue_free()
	var profile: Dictionary = _profile()
	var rows: Array[Dictionary] = Achievements.rows(
		profile, _data, _unlocks, UiLocale.current_locale
	)
	var done: int = 0
	for row: Dictionary in rows:
		if bool(row["earned"]):
			done += 1
	_count_label.text = "%d/%d" % [done, rows.size()]
	for row: Dictionary in rows:
		_rows_box.add_child(_build_row(row))


func _build_row(row: Dictionary) -> Control:
	var earned: bool = bool(row["earned"])
	var card := PanelContainer.new()
	card.name = "Row_" + String(row["id"])
	card.custom_minimum_size = Vector2(0.0, CARD_MIN_HEIGHT)
	# A grid cell has to be claimed, or the cards shrink to their text.
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_box(earned))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.name = "Body"
	margin.add_theme_constant_override("margin_left", CARD_PADDING)
	margin.add_theme_constant_override("margin_right", CARD_PADDING)
	margin.add_theme_constant_override("margin_top", CARD_PADDING)
	margin.add_theme_constant_override("margin_bottom", CARD_PADDING)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	margin.add_child(box)

	var top := HBoxContainer.new()
	top.name = "TopLine"
	top.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	var name_label: Label = _label(
		String(row["name"]), UiPalette.FONT_SIZE_BODY,
		UiPalette.INK if earned else UiPalette.TEXT_MUTED_ON_PAPER
	)
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(_status_pill(row))
	box.add_child(top)

	var desc: Label = _label(
		String(row["desc"]), UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_MUTED_ON_PAPER
	)
	desc.name = "Desc"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.modulate.a = 1.0 if earned else LOCKED_ALPHA
	box.add_child(desc)

	# The reward line only appears when there is one, so an achievement that
	# grants nothing does not pretend otherwise with an empty row.
	var reward: String = _reward_text(row)
	if not reward.is_empty():
		var reward_label: Label = _label(
			reward, UiPalette.FONT_SIZE_LABEL,
			UiPalette.SUCCESS if earned else UiPalette.GOLD
		)
		reward_label.name = "Reward"
		box.add_child(reward_label)
	return card


## What completing it hands over. Named rather than described as "an unlock":
## the point of the line is to tell the player the 지도 is what they are
## working toward.
func _reward_text(row: Dictionary) -> String:
	var parts: Array[String] = []
	var grants: String = String(row["grants"])
	if not grants.is_empty():
		parts.append(grants + " " + UiLocale.text("achievements.unlocked"))
	var gold: int = int(row["reward_gold"])
	if gold > 0:
		parts.append(UiLocale.t("%d냥") % gold)
	return " · ".join(parts)


## Earned reads as a state; everything else shows PROGRESS. A locked row that
## only said "locked" would hide the one number that says whether the player
## is nearly there.
func _status_pill(row: Dictionary) -> Control:
	var pill := PanelContainer.new()
	pill.name = "Status"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var earned: bool = bool(row["earned"])
	var fill: Color = UiPalette.SUCCESS if earned else UiPalette.CARD_BG
	var color: Color = UiPalette.INK if earned else UiPalette.TEXT_MUTED_ON_DARK
	var text: String = UiLocale.text("achievements.earned") if earned else "%d/%d" % [
		int(row["have"]), int(row["need"])
	]
	pill.add_theme_stylebox_override("panel", _pill_box(fill))
	pill.add_child(_label(text, UiPalette.FONT_SIZE_LABEL, color))
	return pill


func _profile() -> Dictionary:
	if SaveService.instance == null:
		return SaveProfile.default_profile()
	return SaveService.instance.profile


## N10-17: the owner's kit plaque, tinted to keep the earned/unearned signal the
## coloured border used to carry. Falls back to the flat box so a missing kit
## still renders a readable list.
func _card_box(earned: bool) -> StyleBox:
	var tint: Color = Color.WHITE if earned else Color(0.72, 0.70, 0.68)
	var kit: StyleBox = UiIcons.card_panel(tint)
	if kit != null:
		return kit
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.CARD_BG
	box.set_corner_radius_all(CARD_CORNER_RADIUS)
	box.set_border_width_all(CARD_BORDER_WIDTH)
	box.border_color = UiPalette.SUCCESS if earned else UiPalette.CARD_BORDER_DIM
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
	SceneFadeLayer.go(self, CAMP_SCENE)
