class_name CharacterSelectScreen
extends Control
## 수행자 선택 (N2-1, relaid out in N9-76). One large detail panel on top and a
## row of small tiles below, so the screen holds its shape as the roster grows —
## the old full-width row cards cost ~180px each and ran off the bottom at four
## characters.
##
## Viewing and selecting are separate acts. A locked character can be VIEWED,
## because the panel is where its unlock condition is written and hiding that
## behind a lock is the one thing the screen must not do. Only an unlocked
## character can be SELECTED, i.e. written to the save.

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
const TITLE_TOP_MARGIN := 40
const DETAIL_NAME_FONT_SIZE := 32
const PANEL_WIDTH_RATIO := 0.92
## N9-153: wide screens hold the portrait design band, centered.
const PANEL_MAX_WIDTH := 500.0
const PANEL_CORNER_RADIUS := 12
const PANEL_BORDER := 2
const WELL_CORNER_RADIUS := 8
## Detail panel spans from below the title to just above the tile strip.
const DETAIL_TOP_MARGIN := 96
const DETAIL_BOTTOM_MARGIN := 292
const DETAIL_PORTRAIT_SIZE := 196
## Tile strip: portrait square plus the name under it.
const TILE_SIZE := 96
const TILE_BORDER_SELECTED := 3
const TILE_BORDER_DIM := 1
const TILE_STRIP_HEIGHT := 140
const TILE_STRIP_BOTTOM_MARGIN := 136
const BACK_WIDTH_RATIO := 0.5
const BACK_BUTTON_HEIGHT := 64
const BACK_BOTTOM_MARGIN := 48
const LOCKED_TEXT_DARKEN := 0.25

var _characters: Dictionary = {}
var _selected_id: String = ""
## Whose detail panel is on screen. Follows the selection unless the player
## taps a locked tile to read its unlock condition.
var _viewed_id: String = ""


static func load_characters() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERS_PATH))
	if data is not Dictionary:
		push_error("character_select: cannot read " + CHARACTERS_PATH)
		return {}
	return data


## A character is locked unless its unlock type is "default", or it is an
## achievement unlock the profile has already earned (N9-148 — the warrior
## opens with the first boss kill). Pass an empty profile to treat every
## non-default entry as locked (the pure-logic tests do).
static func is_locked(entry: Dictionary, profile: Dictionary = {}) -> bool:
	var unlock: Dictionary = entry.get("unlock", {})
	var kind: String = String(unlock.get("type", ""))
	if kind == "default":
		return false
	if kind == "achievement" and not profile.is_empty():
		return not Achievements.is_earned(profile, String(unlock.get("achievement_id", "")))
	return true


## Pure view-model shared by the detail panel and its tile — they show the same
## character and would drift if each resolved the data itself.
## A locked character is never marked selected.
static func card_model(
	id: String, entry: Dictionary, selected_id: String, profile: Dictionary = {}
) -> Dictionary:
	var locked: bool = is_locked(entry, profile)
	return {
		"id": id,
		"name": _localized(entry, "name"),
		"hanja": String(entry.get("name_hanja", "")),
		"title": _localized(entry, "title"),
		"quote": "\"%s\"" % _localized(entry, "quote"),
		"description": _description(entry),
		"accent": ACCENT_COLORS.get(String(entry.get("accent", "")), UiPalette.TEXT_ON_DARK),
		"locked": locked,
		"selected": id == selected_id and not locked,
		"unlock_text": _localized(entry, "unlock_text") if locked else "",
		"portrait_path": PORTRAIT_PATH_TEMPLATE % id,
	}


## Pure selection transition: locked and unknown characters are unselectable,
## the current selection survives.
static func select(
	current_id: String, pressed_id: String, characters: Dictionary,
	profile: Dictionary = {}
) -> String:
	if not characters.has(pressed_id):
		return current_id
	if is_locked(characters[pressed_id], profile):
		return current_id
	return pressed_id


## Pure view transition. Unlike `select`, a locked character IS viewable — the
## panel is the only place its unlock condition is written.
static func view(current_id: String, pressed_id: String, characters: Dictionary) -> String:
	if not characters.has(pressed_id):
		return current_id
	return pressed_id


## The panel's body text: the backstory when the character has one, else the
## quote. Every roster entry carries a quote, so the panel is never blank.
static func _description(entry: Dictionary) -> String:
	var backstory: String = _localized(entry, "backstory")
	if not backstory.is_empty():
		return backstory
	return "\"%s\"" % _localized(entry, "quote")


static func _localized(entry: Dictionary, field: String) -> String:
	var localized: Variant = entry.get(field + "_" + UiLocale.current_locale)
	if localized is String:
		return localized
	return String(entry.get(field + "_" + UiLocale.DEFAULT_LOCALE, ""))


## The saved profile when the game is running; empty in headless layout tests
## (achievement unlocks then read as locked, which is the safe default).
func _live_profile() -> Dictionary:
	if SaveService.instance != null:
		return SaveService.instance.profile
	return {}


func _ready() -> void:
	build_ui()
	_focus_viewed_tile()


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
	if _viewed_id.is_empty():
		_viewed_id = _selected_id
	_build_background()
	_build_title()
	_build_detail()
	_build_tiles()
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


func _build_detail() -> void:
	var model: Dictionary = card_model(
		_viewed_id, _characters.get(_viewed_id, {}), _selected_id, _live_profile()
	)
	var panel := PanelContainer.new()
	panel.name = "Detail"
	panel.add_theme_stylebox_override("panel", _panel_plate(model["selected"]))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	var half: float = minf(PANEL_MAX_WIDTH, size.x * PANEL_WIDTH_RATIO if size.x > 0.0 else PANEL_MAX_WIDTH) / 2.0
	panel.offset_left = -half
	panel.offset_right = half
	panel.offset_top = DETAIL_TOP_MARGIN
	panel.offset_bottom = -DETAIL_BOTTOM_MARGIN

	var margin := MarginContainer.new()
	margin.name = "Content"
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, UiPalette.SPACE_MD)

	var column := VBoxContainer.new()
	column.name = "DetailColumn"
	column.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	column.add_child(_build_portrait(model, DETAIL_PORTRAIT_SIZE, true))
	column.add_child(_build_heading(model))
	column.add_child(_build_body(model))
	margin.add_child(column)
	panel.add_child(margin)
	add_child(panel)


## Portrait well at any size. `centered` wraps it in its own centering row,
## which the detail panel wants and the tiles (already square) do not.
func _build_portrait(model: Dictionary, size: int, centered: bool) -> Control:
	var well := PanelContainer.new()
	well.name = "PortraitWell"
	well.custom_minimum_size = Vector2(size, size)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.CARD_WELL
	style.set_corner_radius_all(WELL_CORNER_RADIUS)
	well.add_theme_stylebox_override("panel", style)

	var portrait_path: String = model["portrait_path"]
	if ResourceLoader.exists(portrait_path, "Texture2D"):
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.texture = load(portrait_path)
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if model["locked"]:
			# Silhouette per DESIGN.md §4: the figure reads as a shape only.
			portrait.self_modulate = UiPalette.INK
		well.add_child(portrait)
	else:
		# No art yet (ASSET_REQUIREMENTS.md). The hanja stands in rather than an
		# empty hole, so the well still identifies whose it is.
		var stand_in := Label.new()
		stand_in.name = "PortraitStandIn"
		stand_in.text = String(model["hanja"])
		stand_in.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stand_in.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stand_in.add_theme_font_size_override(
			"font_size", maxi(size / 4, UiPalette.FONT_SIZE_LABEL)
		)
		stand_in.add_theme_color_override(
			"font_color", (model["accent"] as Color).darkened(LOCKED_TEXT_DARKEN)
		)
		well.add_child(stand_in)

	if not centered:
		return well
	var row := HBoxContainer.new()
	row.name = "PortraitRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(well)
	return row


func _build_heading(model: Dictionary) -> Control:
	var heading := VBoxContainer.new()
	heading.name = "Heading"
	heading.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	var accent: Color = model["accent"]

	var header := HBoxContainer.new()
	header.name = "Header"
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "%s (%s)" % [model["name"], model["hanja"]]
	name_label.add_theme_color_override("font_color", accent)
	name_label.add_theme_font_size_override("font_size", DETAIL_NAME_FONT_SIZE)
	header.add_child(name_label)
	if model["selected"]:
		header.add_child(_build_selected_badge())
	elif model["locked"]:
		header.add_child(_build_locked_badge())
	heading.add_child(header)

	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.text = model["title"]
	title_label.add_theme_color_override("font_color", accent)
	title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_child(title_label)
	return heading


## Backstory for an open character, unlock condition for a locked one. Scrolls,
## because a backstory outruns the panel and the roster's entries differ in
## length.
func _build_body(model: Dictionary) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "BodyScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var column := VBoxContainer.new()
	column.name = "BodyColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UiPalette.SPACE_XS)

	if model["locked"]:
		var how := Label.new()
		how.name = "UnlockHeading"
		how.text = UiLocale.text("select.how_to_unlock")
		how.add_theme_color_override("font_color", UiPalette.GOLD)
		how.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
		column.add_child(how)

	var body := Label.new()
	body.name = "BodyLabel"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	if model["locked"]:
		body.text = String(model["unlock_text"])
		body.add_theme_color_override(
			"font_color", UiPalette.TEXT_ON_DARK.darkened(LOCKED_TEXT_DARKEN)
		)
	else:
		body.text = String(model["description"])
		body.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
	column.add_child(body)
	scroll.add_child(column)
	return scroll


## The roster, one small tile each, scrolling sideways. This is the part that
## has to survive a growing cast: adding a character lengthens the strip instead
## of pushing anything off the bottom.
func _build_tiles() -> void:
	var strip := ScrollContainer.new()
	strip.name = "TileStrip"
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.anchor_right = 1.0
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_left = UiPalette.SPACE_MD
	strip.offset_right = -UiPalette.SPACE_MD
	strip.offset_top = -(TILE_STRIP_BOTTOM_MARGIN + TILE_STRIP_HEIGHT)
	strip.offset_bottom = -TILE_STRIP_BOTTOM_MARGIN

	var row := HBoxContainer.new()
	row.name = "Tiles"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	for id: String in _characters.keys():
		row.add_child(_build_tile(card_model(id, _characters[id], _selected_id, _live_profile())))
	strip.add_child(row)
	add_child(strip)


func _build_tile(model: Dictionary) -> Button:
	var id: String = model["id"]
	var tile := Button.new()
	tile.name = "Tile_" + id
	tile.custom_minimum_size = Vector2(TILE_SIZE, TILE_STRIP_HEIGHT - UiPalette.SPACE_SM)
	tile.focus_mode = Control.FOCUS_ALL
	var plate: StyleBoxFlat = _tile_plate(model["selected"], id == _viewed_id)
	for state: String in ["normal", "hover", "pressed"]:
		tile.add_theme_stylebox_override(state, plate)
	tile.add_theme_stylebox_override("focus", _focus_ring())
	tile.pressed.connect(func() -> void: _on_tile_pressed(id))

	var margin := MarginContainer.new()
	margin.name = "TileContent"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, UiPalette.SPACE_XS)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.name = "TileColumn"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	var portrait: Control = _build_portrait(model, TILE_SIZE - 2 * UiPalette.SPACE_SM, false)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait)

	var name_label := Label.new()
	name_label.name = "TileName"
	name_label.text = String(model["name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	var accent: Color = model["accent"]
	name_label.add_theme_color_override(
		"font_color", accent.darkened(LOCKED_TEXT_DARKEN) if model["locked"] else accent
	)
	column.add_child(name_label)
	margin.add_child(column)
	tile.add_child(margin)
	return tile


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


func _build_locked_badge() -> Control:
	var word := Label.new()
	word.name = "LockedLabel"
	word.text = UiLocale.text("select.locked")
	word.add_theme_color_override(
		"font_color", UiPalette.TEXT_ON_DARK.darkened(LOCKED_TEXT_DARKEN)
	)
	word.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	return word


func _build_back_button() -> void:
	var back := Button.new()
	back.name = "BackButton"
	back.text = UiLocale.text("select.back")
	back.custom_minimum_size = Vector2(0, BACK_BUTTON_HEIGHT)
	WoodButton.apply(back)
	# N9-153: centered, capped at the design band's half on wide screens.
	back.anchor_left = 0.5
	back.anchor_right = 0.5
	var back_half: float = minf(
		PANEL_MAX_WIDTH * BACK_WIDTH_RATIO,
		(size.x if size.x > 0.0 else PANEL_MAX_WIDTH) * BACK_WIDTH_RATIO
	) / 2.0
	back.offset_left = -back_half
	back.offset_right = back_half
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_top = -(BACK_BUTTON_HEIGHT + BACK_BOTTOM_MARGIN)
	back.offset_bottom = -BACK_BOTTOM_MARGIN
	back.pressed.connect(_on_back_pressed)
	add_child(back)


## A tap always moves the detail panel; it only moves the SAVED selection when
## the character is unlocked.
func _on_tile_pressed(id: String) -> void:
	var next_view: String = view(_viewed_id, id, _characters)
	var next_selection: String = select(_selected_id, id, _characters, _live_profile())
	if next_view == _viewed_id and next_selection == _selected_id:
		return
	_viewed_id = next_view
	if next_selection != _selected_id:
		_selected_id = next_selection
		if SaveService.instance != null:
			SaveService.instance.set_selected_character(_selected_id)
	_rebuild()


## The panel swaps and the tile borders move together, so both are rebuilt.
## A handful of small nodes — a full rebuild is simpler than style surgery.
##
## Detached first, then queued: the rebuild runs from a tile's own `pressed`
## signal, so freeing the strip outright destroys the button mid-emit (Godot
## logs "was freed or unreferenced while a signal is being emitted"). Detaching
## also frees the names, which `queue_free` alone would not — the new strip
## would land as "TileStrip@2" and `get_node("TileStrip")` would find the corpse.
func _rebuild() -> void:
	for node_name: String in ["Detail", "TileStrip"]:
		var stale: Node = get_node_or_null(node_name)
		if stale == null:
			continue
		remove_child(stale)
		stale.queue_free()
	_build_detail()
	_build_tiles()
	_focus_viewed_tile()


func _focus_viewed_tile() -> void:
	var tile: Control = find_child("Tile_" + _viewed_id, true, false)
	if tile != null and tile.is_inside_tree():
		tile.grab_focus()


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


func _panel_plate(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.CARD_BG_SELECTED if selected else UiPalette.CARD_BG
	box.border_color = UiPalette.GOLD if selected else UiPalette.CARD_BORDER_DIM
	box.set_border_width_all(PANEL_BORDER)
	box.set_corner_radius_all(PANEL_CORNER_RADIUS)
	return box


## Two marks, not one: GOLD says "this is your pick", the lighter well says
## "this is what the panel above is showing". They are the same tile except
## while the player is reading a locked character.
func _tile_plate(selected: bool, viewed: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.CARD_BG_SELECTED if viewed else UiPalette.CARD_BG
	box.border_color = UiPalette.GOLD if selected else UiPalette.CARD_BORDER_DIM
	box.set_border_width_all(TILE_BORDER_SELECTED if selected else TILE_BORDER_DIM)
	box.set_corner_radius_all(WELL_CORNER_RADIUS)
	return box


func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = UiPalette.GOLD
	ring.set_border_width_all(WoodButton.FOCUS_RING_WIDTH)
	ring.set_corner_radius_all(WELL_CORNER_RADIUS)
	return ring
