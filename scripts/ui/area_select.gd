extends Control
## Area/stage select -- GDD flow step between character select and the run.
## asset/UI_ART_REPORT.md item 4. RunState.begin() happens here, not in
## character_select.gd, so the character survives the trip through this
## screen (character_select stores the pick, this reads it back).

const CARD_UNSELECTED: Texture2D = preload("res://asset/ui/area/card_unselected_9slice.png")
const CARD_SELECTED: Texture2D = preload("res://asset/ui/area/card_selected_9slice.png")
const CARD_LOCKED: Texture2D = preload("res://asset/ui/area/card_locked_9slice.png")

const ICON_DIR := "res://asset/ui/area/icons"
const CARD_DIR := "res://asset/ui/area/cards"

## Areas offered this M1 slice. Only the ids with a real data/stages.json
## entry are selectable; the rest render locked -- the GDD's MVP area list
## (JOSEONLIKE_GDD.md section 16) is ahead of what content-data has shipped.
const AREA_IDS := ["bamboo_forest", "abandoned_temple"]

const MARGIN := 12

@onready var _title_label: Label = $Title
@onready var _back_button: Button = $BackButton
@onready var _list: VBoxContainer = $ScrollContainer/AreaList

var _selected_character_id: String = ""
var _first_card: Control = null


func _ready() -> void:
	_selected_character_id = RunState.character_id

	_title_label.text = LocaleText.ui("area_select_title")
	_title_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)

	_back_button.text = LocaleText.ui("back_button")
	UiPalette.apply_button_style(_back_button)
	_back_button.custom_minimum_size = Vector2(96, 48)
	_back_button.pressed.connect(_on_back_pressed)

	_populate_areas()


func _populate_areas() -> void:
	for child in _list.get_children():
		child.queue_free()
	_first_card = null

	for area_id in AREA_IDS:
		var stage: Dictionary = GameData.stage(area_id)
		var card: Button = _build_area_card(area_id, stage)
		_list.add_child(card)
		if _first_card == null:
			_first_card = card
	if _first_card != null:
		_first_card.grab_focus()


func _build_area_card(area_id: String, stage: Dictionary) -> Button:
	var is_available: bool = not stage.is_empty()

	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 128)
	card.focus_mode = Control.FOCUS_ALL
	card.disabled = not is_available
	_style_area_card(card, is_available)
	if is_available:
		card.pressed.connect(_on_area_selected.bind(area_id))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, MARGIN)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiPalette.SPACING_MD)
	margin.add_child(row)

	var thumb := TextureRect.new()
	thumb.texture = _load(CARD_DIR, area_id)
	thumb.custom_minimum_size = Vector2(112, 64)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(thumb)

	var text_color: Color = UiPalette.TEXT_ON_PAPER if is_available else UiPalette.TEXT_ON_DARK
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", UiPalette.SPACING_XS)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = LocaleText.field(stage, "name") if is_available else area_id.capitalize()
	name_label.add_theme_color_override("font_color", text_color)
	name_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	info.add_child(name_label)

	var icon_row := HBoxContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.add_theme_constant_override("separation", UiPalette.SPACING_SM)
	info.add_child(icon_row)

	if is_available:
		icon_row.add_child(_icon(ICON_DIR, "difficulty_1"))
		icon_row.add_child(_icon(ICON_DIR, "reward"))
		if not String(stage.get("boss_id", "")).is_empty():
			icon_row.add_child(_icon(ICON_DIR, "boss"))
		var reason_label := Label.new()
		reason_label.text = ""
		info.add_child(reason_label)
	else:
		icon_row.add_child(_icon(ICON_DIR, "locked"))
		var reason_label := Label.new()
		reason_label.text = LocaleText.ui("area_locked_reason")
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason_label.add_theme_color_override("font_color", text_color)
		reason_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
		info.add_child(reason_label)

	return card


func _icon(dir: String, id: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = _load(dir, id)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _load(dir: String, id: String) -> Texture2D:
	var path: String = "%s/%s.png" % [dir, id]
	return load(path) if ResourceLoader.exists(path) else null


func _style_area_card(card: Button, is_available: bool) -> void:
	var normal := _nine_slice(CARD_UNSELECTED if is_available else CARD_LOCKED)
	var focused := _nine_slice(CARD_SELECTED if is_available else CARD_LOCKED)
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", focused)
	card.add_theme_stylebox_override("pressed", focused)
	card.add_theme_stylebox_override("focus", focused)
	card.add_theme_stylebox_override("disabled", normal)


func _nine_slice(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = MARGIN
	style.texture_margin_right = MARGIN
	style.texture_margin_top = MARGIN
	style.texture_margin_bottom = MARGIN
	return style


func _on_area_selected(area_id: String) -> void:
	UiSound.play_click(self)
	AchievementTracker.snapshot_before_run()
	RunState.begin(_selected_character_id, area_id)
	SceneRouter.goto_stage(area_id)


func _on_back_pressed() -> void:
	UiSound.play_click(self)
	SceneRouter.goto_character_select()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
