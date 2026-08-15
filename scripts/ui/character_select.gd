class_name CharacterSelectScreen
extends Control
## 수행자 선택 (N2-1), DESIGN.md §3 선택 카드 / §4, capture _01. Full-width row
## cards from data/characters.json: accent-colored name + (hanja), one-line
## 칭호, quoted dialogue. The selected card carries the GOLD border + SUCCESS
## dot + "선택됨"; locked characters render silhouetted with their unlock
## condition and cannot be selected. The choice persists via SaveService.

const CHARACTERS_PATH := "res://data/characters.json"
const TITLE_SCENE := "res://scenes/title.tscn"
const CAMP_SCENE := "res://scenes/camp.tscn"
const PORTRAIT_PATH_TEMPLATE := "res://asset/characters/%s/portrait.png"

## data/characters.json `accent` tokens → palette colors. validate_data.gd
## cross-checks every character's accent against this map.
const ACCENT_COLORS := {
	"taoist_blue": UiPalette.ACCENT_TAOIST,
	"warrior_crimson": UiPalette.ACCENT_WARRIOR,
	"archer_green": UiPalette.ACCENT_ARCHER,
}

const TITLE_FONT_SIZE := 40
const NAME_FONT_SIZE := UiPalette.FONT_SIZE_TITLE
const TITLE_TOP_MARGIN := 56
const CARDS_TOP_MARGIN := 140
const CARD_WIDTH_RATIO := 0.92
const CARD_BORDER_SELECTED := 4
const CARD_BORDER_DIM := 2
const CARD_CORNER_RADIUS := 12
const WELL_CORNER_RADIUS := 8
const WELL_SIZE := 132
## A Button is not a container: it never grows to its content, so the card
## fixes its height to the portrait well plus the content margins.
const CARD_MIN_HEIGHT := WELL_SIZE + 2 * UiPalette.SPACE_MD + UiPalette.SPACE_LG
const BACK_WIDTH_RATIO := 0.5
const BACK_BUTTON_HEIGHT := 64
const BACK_BOTTOM_MARGIN := 48
const LOCKED_TEXT_DARKEN := 0.25

var _characters: Dictionary = {}
var _selected_id: String = ""


static func load_characters() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERS_PATH))
	if data is not Dictionary:
		push_error("character_select: cannot read " + CHARACTERS_PATH)
		return {}
	return data


## A character is locked unless its unlock type is "default". Unlock progress
## tracking (GDD §15-16) is a later feature; until then only defaults are open.
static func is_locked(entry: Dictionary) -> bool:
	return String((entry.get("unlock", {}) as Dictionary).get("type", "")) != "default"


## Pure card view-model: everything one row card renders, resolved for the
## current locale. A locked card is never marked selected.
static func card_model(id: String, entry: Dictionary, selected_id: String) -> Dictionary:
	var locked: bool = is_locked(entry)
	return {
		"id": id,
		"name": _localized(entry, "name"),
		"hanja": String(entry.get("name_hanja", "")),
		"title": _localized(entry, "title"),
		"quote": "\"%s\"" % _localized(entry, "quote"),
		"accent": ACCENT_COLORS.get(String(entry.get("accent", "")), UiPalette.TEXT_ON_DARK),
		"locked": locked,
		"selected": id == selected_id and not locked,
		"unlock_text": _localized(entry, "unlock_text") if locked else "",
		"portrait_path": PORTRAIT_PATH_TEMPLATE % id,
	}


## Pure selection transition: locked and unknown characters are unselectable,
## the current selection survives.
static func select(current_id: String, pressed_id: String, characters: Dictionary) -> String:
	if not characters.has(pressed_id):
		return current_id
	if is_locked(characters[pressed_id]):
		return current_id
	return pressed_id


static func _localized(entry: Dictionary, field: String) -> String:
	var localized: Variant = entry.get(field + "_" + UiLocale.current_locale)
	if localized is String:
		return localized
	return String(entry.get(field + "_" + UiLocale.DEFAULT_LOCALE, ""))


func _ready() -> void:
	build_ui()
	var selected_card: Control = find_child("Card_" + _selected_id, true, false)
	if selected_card != null:
		selected_card.grab_focus()


## Builds every child node. Public so the headless test can construct the
## screen without a running SceneTree.
func build_ui() -> void:
	_characters = load_characters()
	if _selected_id.is_empty():
		_selected_id = (
			SaveService.instance.selected_character()
			if SaveService.instance != null
			else SaveProfile.DEFAULT_CHARACTER
		)
	_build_background()
	_build_title()
	_build_cards()
	_build_back_button()


func _build_background() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = UiPalette.NIGHT
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)


func _build_title() -> void:
	var title := Label.new()
	title.name = "ScreenTitle"
	title.text = UiLocale.text("title.select_character")
	title.add_theme_color_override("font_color", UiPalette.GOLD)
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = TITLE_TOP_MARGIN
	add_child(title)


func _build_cards() -> void:
	var stack := VBoxContainer.new()
	stack.name = "Cards"
	var side_margin: float = (1.0 - CARD_WIDTH_RATIO) / 2.0
	stack.anchor_left = side_margin
	stack.anchor_right = 1.0 - side_margin
	stack.offset_top = CARDS_TOP_MARGIN
	stack.add_theme_constant_override("separation", UiPalette.SPACE_LG)
	for id: String in _characters.keys():
		stack.add_child(_build_card(card_model(id, _characters[id], _selected_id)))
	add_child(stack)


func _build_card(model: Dictionary) -> Button:
	var card := Button.new()
	card.name = "Card_" + String(model["id"])
	card.custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
	card.focus_mode = Control.FOCUS_ALL
	card.add_theme_stylebox_override("normal", _card_plate(model["selected"]))
	card.add_theme_stylebox_override("hover", _card_plate(model["selected"]))
	card.add_theme_stylebox_override("pressed", _card_plate(model["selected"]))
	card.add_theme_stylebox_override("focus", _focus_ring())
	var id: String = model["id"]
	card.pressed.connect(func() -> void: _on_card_pressed(id))

	var margin := MarginContainer.new()
	margin.name = "Content"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, UiPalette.SPACE_MD)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	row.add_child(_build_well(model))
	row.add_child(_build_texts(model))
	margin.add_child(row)
	card.add_child(margin)
	return card


func _build_well(model: Dictionary) -> Control:
	var column := VBoxContainer.new()
	column.name = "WellColumn"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", UiPalette.SPACE_XS)

	var well := PanelContainer.new()
	well.name = "PortraitWell"
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.custom_minimum_size = Vector2(WELL_SIZE, WELL_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.CARD_WELL
	style.set_corner_radius_all(WELL_CORNER_RADIUS)
	well.add_theme_stylebox_override("panel", style)

	var portrait_path: String = model["portrait_path"]
	if ResourceLoader.exists(portrait_path, "Texture2D"):
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.texture = load(portrait_path)
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if model["locked"]:
			# Silhouette per DESIGN.md §4: the figure reads as a shape only.
			portrait.self_modulate = UiPalette.INK
		well.add_child(portrait)
	column.add_child(well)

	if model["locked"]:
		var locked_label := Label.new()
		locked_label.name = "LockedLabel"
		locked_label.text = UiLocale.text("select.locked")
		locked_label.add_theme_color_override(
			"font_color", UiPalette.TEXT_ON_DARK.darkened(LOCKED_TEXT_DARKEN)
		)
		locked_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
		locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(locked_label)
	return column


func _build_texts(model: Dictionary) -> Control:
	var texts := VBoxContainer.new()
	texts.name = "Texts"
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", UiPalette.SPACE_SM)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var accent: Color = model["accent"]
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "%s (%s)" % [model["name"], model["hanja"]]
	name_label.add_theme_color_override("font_color", accent)
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	if model["selected"]:
		header.add_child(_build_selected_badge())
	texts.add_child(header)

	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.text = model["title"]
	title_label.add_theme_color_override("font_color", accent)
	title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	texts.add_child(title_label)

	var body := Label.new()
	body.name = "BodyLabel"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	if model["locked"]:
		body.text = String(model["unlock_text"])
		body.add_theme_color_override(
			"font_color", UiPalette.TEXT_ON_DARK.darkened(LOCKED_TEXT_DARKEN)
		)
	else:
		body.text = String(model["quote"])
		body.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
	texts.add_child(body)
	return texts


func _build_selected_badge() -> Control:
	var badge := HBoxContainer.new()
	badge.name = "SelectedBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	var dot := Label.new()
	dot.name = "Dot"
	dot.text = "●"
	dot.add_theme_color_override("font_color", UiPalette.SUCCESS)
	dot.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	badge.add_child(dot)
	var word := Label.new()
	word.name = "Word"
	word.text = UiLocale.text("select.selected")
	word.add_theme_color_override("font_color", UiPalette.SUCCESS)
	word.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	badge.add_child(word)
	return badge


func _build_back_button() -> void:
	var back := Button.new()
	back.name = "BackButton"
	back.text = UiLocale.text("select.back")
	back.custom_minimum_size = Vector2(0, BACK_BUTTON_HEIGHT)
	WoodButton.apply(back)
	var side_margin: float = (1.0 - BACK_WIDTH_RATIO) / 2.0
	back.anchor_left = side_margin
	back.anchor_right = 1.0 - side_margin
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_top = -(BACK_BUTTON_HEIGHT + BACK_BOTTOM_MARGIN)
	back.offset_bottom = -BACK_BOTTOM_MARGIN
	back.pressed.connect(_on_back_pressed)
	add_child(back)


func _on_card_pressed(id: String) -> void:
	var next_id: String = select(_selected_id, id, _characters)
	if next_id == _selected_id:
		return
	_selected_id = next_id
	if SaveService.instance != null:
		SaveService.instance.set_selected_character(_selected_id)
	_rebuild_cards()


## The badge and the GOLD border move with the selection (선택 즉시 반영).
## Three row cards — a full rebuild is simpler than in-place style surgery.
func _rebuild_cards() -> void:
	var stack: VBoxContainer = get_node("Cards")
	stack.free()
	_build_cards()
	var selected_card: Control = find_child("Card_" + _selected_id, true, false)
	if selected_card != null and selected_card.is_inside_tree():
		selected_card.grab_focus()


## N5-3: back returns to camp for a returning profile; a fresh profile can
## only be here via the title's corner detour, so it goes back to the title.
func _on_back_pressed() -> void:
	var profile: Dictionary = SaveProfile.default_profile()
	if SaveService.instance != null:
		profile = SaveService.instance.profile
	if Camp.destination_after_select_exit(profile) == Camp.DEST_CAMP:
		get_tree().change_scene_to_file(CAMP_SCENE)
		return
	get_tree().change_scene_to_file(TITLE_SCENE)


func _card_plate(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.CARD_BG_SELECTED if selected else UiPalette.CARD_BG
	box.border_color = UiPalette.GOLD if selected else UiPalette.CARD_BORDER_DIM
	box.set_border_width_all(CARD_BORDER_SELECTED if selected else CARD_BORDER_DIM)
	box.set_corner_radius_all(CARD_CORNER_RADIUS)
	return box


func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = UiPalette.GOLD
	ring.set_border_width_all(WoodButton.FOCUS_RING_WIDTH)
	ring.set_corner_radius_all(CARD_CORNER_RADIUS)
	return ring
