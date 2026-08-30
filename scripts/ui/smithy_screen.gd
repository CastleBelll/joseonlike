class_name SmithyScreen
extends Control
## 대장간 (N11-4): 돌무쇠 unlocks 개조 recipes for gold + storehouse
## materials. One row card per recipe in the camp's card language — the row
## says what the mod turns which weapon into, what the unlock costs, and the
## button spends it. Runs only offer unlocked recipes (Smithy.runtime_mods).

const CAMP_SCENE := "res://scenes/camp.tscn"
const WEAPON_MODS_PATH := "res://data/weapon_mods.json"
const WEAPONS_PATH := "res://data/weapons.json"
const LOOT_PATH := "res://data/loot.json"

const MARGIN_SIDE := 24
const MARGIN_TOP := 24
const MARGIN_BOTTOM := 32
const BACK_SIZE := 44.0
const CARD_CORNER_RADIUS := 12
const CARD_BORDER_WIDTH := 2
const CARD_PADDING := 12
const CARD_MIN_HEIGHT := 76.0
const NOTICE_SEC := 1.6

var _mods: Dictionary = {}
var _weapons: Dictionary = {}
var _loot: Dictionary = {}
var _profile: Dictionary = {}
var _rows_box: GridContainer
var _count_label: Label
var _gold_label: Label
var _notice: Label
var _notice_tween: Tween


func _ready() -> void:
	_mods = _load_json(WEAPON_MODS_PATH)
	_weapons = _load_json(WEAPONS_PATH)
	_loot = _load_json(LOOT_PATH)
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

	_notice = _label("", UiPalette.FONT_SIZE_BODY, UiPalette.GOLD)
	_notice.name = "Notice"
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.modulate.a = 0.0
	column.add_child(_notice)

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
		UiLocale.text("smithy.title"), UiPalette.FONT_SIZE_TITLE, UiPalette.GOLD
	)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var count_pill := PanelContainer.new()
	count_pill.name = "CountPill"
	count_pill.add_theme_stylebox_override("panel", _pill_box(UiPalette.WOOD_PRESSED))
	_count_label = _label("", UiPalette.FONT_SIZE_BODY, UiPalette.INK)
	_count_label.name = "CountValue"
	count_pill.add_child(_count_label)
	header.add_child(count_pill)

	var gold_pill := PanelContainer.new()
	gold_pill.name = "GoldPill"
	gold_pill.add_theme_stylebox_override("panel", _pill_box(UiPalette.WOOD_PRESSED))
	_gold_label = _label("", UiPalette.FONT_SIZE_BODY, UiPalette.INK)
	_gold_label.name = "GoldValue"
	gold_pill.add_child(_gold_label)
	header.add_child(gold_pill)
	return header


func _refresh() -> void:
	for child: Node in _rows_box.get_children():
		child.queue_free()
	_gold_label.text = UiLocale.text("meta.cost_fmt") % int(_profile.get("gold", 0))
	var ids: Array[String] = Smithy.recipe_ids(_mods)
	var owned: int = 0
	for mod_id: String in ids:
		if Smithy.is_unlocked(_profile, mod_id):
			owned += 1
		_rows_box.add_child(_build_row(mod_id))
	_count_label.text = "%d/%d" % [owned, ids.size()]


func _build_row(mod_id: String) -> Control:
	var mod: Dictionary = _mods[mod_id]
	var unlocked: bool = Smithy.is_unlocked(_profile, mod_id)
	var card := PanelContainer.new()
	card.name = "Row_" + mod_id
	card.custom_minimum_size = Vector2(0.0, CARD_MIN_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_box(unlocked))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE if unlocked \
			else Control.MOUSE_FILTER_PASS

	var body := MarginContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("margin_left", CARD_PADDING)
	body.add_theme_constant_override("margin_right", CARD_PADDING)
	body.add_theme_constant_override("margin_top", CARD_PADDING)
	body.add_theme_constant_override("margin_bottom", CARD_PADDING)
	card.add_child(body)

	var row := HBoxContainer.new()
	row.name = "Line"
	row.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	body.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.name = "Text"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	row.add_child(text_box)

	var result_name: String = _weapon_name(String(mod.get("result_weapon", "")))
	var name_label := _label(result_name, UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_ON_DARK)
	name_label.name = "Name"
	text_box.add_child(name_label)

	var base_line: String = UiLocale.text("smithy.from_fmt") % [
		_weapon_name(String(mod.get("weapon_id", ""))),
		int(mod.get("level_required", 1)),
	]
	var detail := _label(
		base_line + " · " + _bill_text(mod),
		UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_MUTED_ON_DARK
	)
	detail.name = "Detail"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_child(detail)

	if unlocked:
		var pill := PanelContainer.new()
		pill.name = "OwnedPill"
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pill.add_theme_stylebox_override("panel", _pill_box(UiPalette.WOOD_PRESSED))
		pill.add_child(_label(
			UiLocale.text("smithy.unlocked"), UiPalette.FONT_SIZE_LABEL, UiPalette.INK
		))
		row.add_child(pill)
		return card

	var cost: Dictionary = Smithy.unlock_cost(mod)
	var buy := Button.new()
	WoodButton.apply(buy)
	buy.name = "Unlock_" + mod_id
	buy.text = UiLocale.text("smithy.unlock_fmt") % int(cost.get("gold", 0))
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# The disabled button still reads its price: the player must be able to
	# see what they are saving up for.
	buy.disabled = Smithy.can_unlock(_profile, _mods, mod_id) != Smithy.REASON_OK
	buy.pressed.connect(_on_unlock_pressed.bind(mod_id))
	row.add_child(buy)
	return card


func _on_unlock_pressed(mod_id: String) -> void:
	var reason: String
	if SaveService.instance != null:
		reason = SaveService.instance.unlock_mod(_mods, mod_id)
		_profile = SaveService.instance.profile
	else:
		var result: Dictionary = Smithy.unlock(_profile, _mods, mod_id)
		reason = String(result["reason"])
		_profile = result["profile"]
	match reason:
		Smithy.REASON_OK:
			_play_sfx("levelup")
			_flash_notice(UiLocale.text("smithy.bought"))
		Smithy.REASON_GOLD:
			_play_sfx("ui_close")
			_flash_notice(UiLocale.text("meta.no_gold"))
		Smithy.REASON_MATERIALS:
			_play_sfx("ui_close")
			_flash_notice(UiLocale.text("meta.no_materials"))
		_:
			_play_sfx("ui_close")
	_refresh()


func _play_sfx(sound_id: String) -> void:
	if SfxService.instance != null:
		SfxService.instance.play(sound_id)


func _flash_notice(message: String) -> void:
	_notice.text = message
	_notice.modulate.a = 1.0
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(NOTICE_SEC)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.3)


func _bill_text(mod: Dictionary) -> String:
	var bill: Dictionary = Smithy.unlock_cost(mod).get("materials", {})
	var parts: Array[String] = []
	for loot_id: String in bill:
		parts.append("%s ×%d" % [
			UiLocale.data_name(_loot.get(loot_id, {}) as Dictionary, loot_id),
			int(bill[loot_id]),
		])
	return UiLocale.text("smithy.bill_fmt") % ", ".join(parts)


func _weapon_name(weapon_id: String) -> String:
	return UiLocale.data_name(_weapons.get(weapon_id, {}) as Dictionary, weapon_id)


func _current_profile() -> Dictionary:
	if SaveService.instance != null:
		return SaveService.instance.profile
	return SaveProfile.default_profile()


func _card_box(unlocked: bool) -> StyleBox:
	var tint: Color = Color.WHITE if unlocked else Color(0.72, 0.70, 0.68)
	var kit: StyleBox = UiIcons.card_panel(tint)
	if kit != null:
		return kit
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.CARD_BG
	box.set_corner_radius_all(CARD_CORNER_RADIUS)
	box.set_border_width_all(CARD_BORDER_WIDTH)
	box.border_color = UiPalette.WOOD_BORDER if unlocked else UiPalette.CARD_BORDER_DIM
	return box


func _pill_box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
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
