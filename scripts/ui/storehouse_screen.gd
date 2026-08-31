class_name StorehouseScreen
extends Control
## 장터 창고 (N11-5): 너름 keeps what the night gave up. One row per material
## the player holds or still owes, with the shopping list on top — the pouch
## bills two systems now (smithy recipes, 수련 ranks) and a bare count cannot
## tell the player which run to take next.

const CAMP_SCENE := "res://scenes/camp.tscn"
const LOOT_PATH := "res://data/loot.json"
const WEAPON_MODS_PATH := "res://data/weapon_mods.json"
const META_TREE_PATH := "res://data/meta_tree.json"

const MARGIN_SIDE := 24
const MARGIN_TOP := 24
const MARGIN_BOTTOM := 32
const BACK_SIZE := 44.0
const CARD_CORNER_RADIUS := 12
const CARD_BORDER_WIDTH := 2
const CARD_PADDING := 12
const CARD_MIN_HEIGHT := 72.0

var _loot: Dictionary = {}
var _mods: Dictionary = {}
var _tree: Dictionary = {}
var _profile: Dictionary = {}
var _rows_box: GridContainer
var _count_label: Label
var _empty_label: Label


func _ready() -> void:
	_loot = _load_json(LOOT_PATH)
	_mods = _load_json(WEAPON_MODS_PATH)
	_tree = _load_json(META_TREE_PATH)
	_profile = _current_profile()
	build_ui()
	_refresh()


## Public so the headless layout test can construct the screen without a
## running SceneTree (same contract as the other camp screens).
func build_ui() -> void:
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

	# The empty pouch is a state, not a blank screen — a first-run player
	# reaching the market before their first sortie must read WHY it is bare.
	_empty_label = _label(
		UiLocale.text("storehouse.empty"), UiPalette.FONT_SIZE_BODY,
		UiPalette.TEXT_MUTED_ON_DARK
	)
	_empty_label.name = "EmptyNotice"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_empty_label)

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


func _apply_columns() -> void:
	if _rows_box != null:
		_rows_box.columns = 2 if size.x > size.y else 1


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", UiPalette.SPACE_SM)

	var back := Button.new()
	back.name = "BackButton"
	var arrow: TextureRect = UiIcons.kit_icon_button("btn_left", BACK_SIZE * 0.72)
	if arrow != null:
		arrow.set_anchors_preset(Control.PRESET_CENTER)
		arrow.position = -arrow.custom_minimum_size / 2.0
		back.add_child(arrow)
	else:
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
		UiLocale.text("storehouse.title"), UiPalette.FONT_SIZE_TITLE, UiPalette.GOLD
	)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var pill := PanelContainer.new()
	pill.name = "CountPill"
	pill.add_theme_stylebox_override("panel", _pill_box())
	_count_label = _label("", UiPalette.FONT_SIZE_BODY, UiPalette.INK)
	_count_label.name = "CountValue"
	pill.add_child(_count_label)
	header.add_child(pill)
	return header


func _refresh() -> void:
	for child: Node in _rows_box.get_children():
		child.queue_free()
	var rows: Array[Dictionary] = Storehouse.rows(
		_profile, _loot, _mods, _tree, UiLocale.current_locale
	)
	_count_label.text = "%d/%d" % [
		Storehouse.stocked_count(_profile, _loot), _loot.size()
	]
	_empty_label.visible = rows.is_empty()
	for row: Dictionary in rows:
		_rows_box.add_child(_build_row(row))


func _build_row(row: Dictionary) -> Control:
	var count: int = int(row["count"])
	var card := PanelContainer.new()
	card.name = "Row_" + String(row["id"])
	card.custom_minimum_size = Vector2(0.0, CARD_MIN_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_box(count > 0))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body := MarginContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("margin_left", CARD_PADDING)
	body.add_theme_constant_override("margin_right", CARD_PADDING)
	body.add_theme_constant_override("margin_top", CARD_PADDING)
	body.add_theme_constant_override("margin_bottom", CARD_PADDING)
	card.add_child(body)

	var line := HBoxContainer.new()
	line.name = "Line"
	line.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	body.add_child(line)

	var text_box := VBoxContainer.new()
	text_box.name = "Text"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	line.add_child(text_box)

	var name_label := _label(
		String(row["name"]), UiPalette.FONT_SIZE_BODY, UiPalette.INK
	)
	name_label.name = "Name"
	text_box.add_child(name_label)

	# The same ink rule as the smithy cards (QA N11-4 F-3): the dim plate of
	# an empty shelf takes full ink, the bright stocked one takes muted.
	var detail := _label(
		_demand_text(row), UiPalette.FONT_SIZE_LABEL,
		UiPalette.TEXT_MUTED_ON_PAPER if count > 0 else UiPalette.INK
	)
	detail.name = "Detail"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_child(detail)

	var stock := PanelContainer.new()
	stock.name = "StockPill"
	stock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stock.add_theme_stylebox_override("panel", _pill_box())
	stock.add_child(_label(
		UiLocale.text("storehouse.count_fmt") % count,
		UiPalette.FONT_SIZE_BODY, UiPalette.INK
	))
	line.add_child(stock)
	return card


## What the material is still owed to, or that nothing wants it right now.
func _demand_text(row: Dictionary) -> String:
	var needed: int = int(row["needed"])
	if needed <= 0:
		return UiLocale.text("storehouse.spare")
	var short: int = needed - int(row["count"])
	if short > 0:
		return UiLocale.text("storehouse.short_fmt") % [needed, short]
	return UiLocale.text("storehouse.needed_fmt") % needed


func _current_profile() -> Dictionary:
	if SaveService.instance != null:
		return SaveService.instance.profile
	return SaveProfile.default_profile()


func _card_box(stocked: bool) -> StyleBox:
	var tint: Color = Color.WHITE if stocked else Color(0.72, 0.70, 0.68)
	var kit: StyleBox = UiIcons.card_panel(tint)
	if kit != null:
		return kit
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.CARD_BG
	box.set_corner_radius_all(CARD_CORNER_RADIUS)
	box.set_border_width_all(CARD_BORDER_WIDTH)
	box.border_color = UiPalette.WOOD_BORDER if stocked else UiPalette.CARD_BORDER_DIM
	return box


func _pill_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.WOOD_PRESSED
	box.set_corner_radius_all(UiPalette.PILL_RADIUS)
	box.content_margin_left = UiPalette.PILL_PAD_X
	box.content_margin_right = UiPalette.PILL_PAD_X
	box.content_margin_top = UiPalette.PILL_PAD_Y
	box.content_margin_bottom = UiPalette.PILL_PAD_Y
	return box


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_back_pressed() -> void:
	SceneFadeLayer.go(self, CAMP_SCENE)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var data: Dictionary = parsed if parsed is Dictionary else {}
	data.erase("_note")
	return data
