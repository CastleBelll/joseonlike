class_name BestiaryScreen
extends Control
## 괴이록 screen (N5-4, GDD §18): the camp's permanent record of everything
## the player has seen. Three sections (몬스터/전리품/무기) as pill tabs over
## one scrolling stack of full-width row cards (DESIGN.md §3). Discovered
## rows show the real icon, name and what the player learned; undiscovered
## rows read ??? with a silhouetted icon. Counts always derive from data
## via the pure Bestiary helpers; opening the screen clears the camp hint.

const CAMP_SCENE := "res://scenes/camp.tscn"
const STAGES_PATH := "res://data/stages.json"
const MONSTERS_PATH := "res://data/monsters.json"
const LOOT_PATH := "res://data/loot.json"
const WEAPONS_PATH := "res://data/weapons.json"
const WEAPON_MODS_PATH := "res://data/weapon_mods.json"

const MARGIN_SIDE := 24
const MARGIN_TOP := 24
const MARGIN_BOTTOM := 32
const BACK_SIZE := 44.0
const PILL_CORNER_RADIUS := 18
const PILL_PADDING_X := 14
const PILL_PADDING_Y := 6
const TAB_HEIGHT := 48.0
const CARD_CORNER_RADIUS := 12
const CARD_BORDER_WIDTH := 2
const CARD_PADDING := 12
const CARD_MIN_HEIGHT := 76.0
const WELL_SIZE := 56.0
const WELL_CORNER_RADIUS := 8
const ICON_SIZE := 48.0
const TIER_PILL_CORNER_RADIUS := 10
const TIER_PILL_PADDING_X := 10
const TIER_PILL_PADDING_Y := 2
## Dimmed silhouette strength for undiscovered icons (??? rule, GDD §18).
const UNDISCOVERED_TEXT_ALPHA := 0.55

var _stages: Dictionary = {}
var _monsters: Dictionary = {}
var _loot: Dictionary = {}
var _weapons: Dictionary = {}
var _mods: Dictionary = {}
## Cleaned record used for every view (unknown ids pruned on load).
var _record: Dictionary = Bestiary.default_record()
var _tab: String = Bestiary.KIND_MONSTERS
var _tab_buttons: Dictionary = {}
## Owner (가로모드도 어색하고 자꾸 스크롤이 생길정도라서): one column of
## full-width rows spent 900px of a landscape screen on 300px of text and
## showed four of thirteen entries. A GridContainer at one column IS the
## vertical list, so the orientation only changes a number — and the column
## count is set per layout pass, never cached, so a flip cannot leave the old
## one behind.
var _rows_box: GridContainer
var _progress_label: Label


func _ready() -> void:
	build_ui()


## Public so the headless test can construct the screen without a SceneTree.
func build_ui() -> void:
	_stages = _load_json(STAGES_PATH)
	_monsters = _load_json(MONSTERS_PATH)
	_loot = _load_json(LOOT_PATH)
	_weapons = _load_json(WEAPONS_PATH)
	_mods = _load_json(WEAPON_MODS_PATH)

	var pruned: Dictionary = Bestiary.prune_record(_profile().get("bestiary", {}), {
		Bestiary.KIND_MONSTERS: _monsters.keys(),
		Bestiary.KIND_LOOT: _loot.keys(),
		Bestiary.KIND_WEAPONS: _weapon_data_ids(),
	})
	if int(pruned["dropped"]) > 0:
		push_warning(
			"bestiary: dropped %d recorded id(s) unknown to data" % int(pruned["dropped"])
		)
	_record = pruned["record"]
	# Looking at the record IS seeing the news — the camp hint retires here.
	if SaveService.instance != null:
		SaveService.instance.mark_bestiary_seen()

	var background := ColorRect.new()
	background.name = "Background"
	background.color = UiPalette.NIGHT
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "Layout"
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
	column.add_child(_build_tabs())

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
	# N10-24: the kit's framed back arrow replaces the "‹" glyph. When the
	# piece is missing the text stays, so the button never becomes invisible.
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
		UiLocale.text("bestiary.title"), UiPalette.FONT_SIZE_TITLE, UiPalette.GOLD
	)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# Overall progress pill: at-a-glance completion across every section.
	var pill := PanelContainer.new()
	pill.name = "ProgressPill"
	pill.add_theme_stylebox_override("panel", _pill_box(UiPalette.CARD_BG, false))
	_progress_label = _label("", UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_ON_DARK)
	_progress_label.name = "ProgressValue"
	pill.add_child(_progress_label)
	header.add_child(pill)
	return header


func _build_tabs() -> Control:
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	for kind: String in Bestiary.KINDS:
		var tab := Button.new()
		tab.name = "Tab_" + kind
		tab.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
		tab.add_theme_color_override("font_hover_color", UiPalette.TEXT_ON_DARK)
		tab.add_theme_color_override("font_pressed_color", UiPalette.TEXT_ON_DARK)
		tab.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
		tab.pressed.connect(_on_tab_pressed.bind(kind))
		tabs.add_child(tab)
		_tab_buttons[kind] = tab
	return tabs


func _on_tab_pressed(kind: String) -> void:
	_tab = kind
	_refresh()


func _on_back_pressed() -> void:
	SceneFadeLayer.go(self, CAMP_SCENE)


## Rebuilds tab captions (with per-section counts), the overall pill and the
## row list for the active tab. Counts derive from the data rosters only.
func _refresh() -> void:
	var locale: String = UiLocale.current_locale
	var roster: Array[Dictionary] = Bestiary.monster_roster(_stages, _monsters)
	var monster_ids: Array[String] = []
	for entry: Dictionary in roster:
		monster_ids.append(String(entry["id"]))
	var loot_ids: Array[String] = Bestiary.loot_roster(_loot)
	var weapon_ids: Array[String] = Bestiary.weapon_roster(_weapons, _mods)
	var ids_by_kind: Dictionary = {
		Bestiary.KIND_MONSTERS: monster_ids,
		Bestiary.KIND_LOOT: loot_ids,
		Bestiary.KIND_WEAPONS: weapon_ids,
	}
	var tab_keys: Dictionary = {
		Bestiary.KIND_MONSTERS: "bestiary.tab_monsters",
		Bestiary.KIND_LOOT: "bestiary.tab_loot",
		Bestiary.KIND_WEAPONS: "bestiary.tab_weapons",
	}
	var found_sum: int = 0
	var total_sum: int = 0
	for kind: String in Bestiary.KINDS:
		var section: Dictionary = Bestiary.progress(_record, kind, ids_by_kind[kind])
		found_sum += int(section["found"])
		total_sum += int(section["total"])
		var tab: Button = _tab_buttons[kind]
		tab.text = "%s %d/%d" % [
			UiLocale.text(String(tab_keys[kind])), int(section["found"]), int(section["total"])
		]
		for state: String in ["normal", "hover", "pressed", "focus"]:
			tab.add_theme_stylebox_override(
				state, _pill_box(UiPalette.CARD_BG, kind == _tab)
			)
	_progress_label.text = "%d/%d" % [found_sum, total_sum]

	for child: Node in _rows_box.get_children():
		child.queue_free()
	var rows: Array[Dictionary] = []
	match _tab:
		Bestiary.KIND_MONSTERS:
			rows = Bestiary.monster_rows(roster, _monsters, _stages, _record, locale)
		Bestiary.KIND_LOOT:
			rows = Bestiary.loot_rows(loot_ids, _loot, _mods, _weapons, _record, locale)
		Bestiary.KIND_WEAPONS:
			rows = Bestiary.weapon_rows(
				weapon_ids, _weapons, _mods, _record, locale, _loot
			)
	var fresh_ids: Array[String] = []
	for row: Dictionary in rows:
		_rows_box.add_child(_build_row(row))
		if bool(row.get("is_new", false)):
			fresh_ids.append(String(row["id"]))
	# N9-11: this render consumed the NEW state — the badge shows exactly
	# once per entry; the list just built keeps its badges until re-render.
	if not fresh_ids.is_empty() and SaveService.instance != null:
		SaveService.instance.mark_bestiary_viewed(_tab, fresh_ids)
		_record = Bestiary.normalized_record(
			SaveService.instance.profile.get("bestiary", {})
		)


## One full-width row card (DESIGN.md §3 선택 카드 문법): icon well left,
## name + learned lines center, tier/boss pill top-right.
func _build_row(row: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "Row_" + String(row["id"])
	card.custom_minimum_size = Vector2(0.0, CARD_MIN_HEIGHT)
	# In the two-column grid a cell has to claim its half, or the cards shrink
	# to their text and the pair drifts apart down the middle of the page.
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# N10-17: the owner's kit plaque, so the 괴이록 reads as the same game as the
	# pause sheet. The flat box stays as the fallback for a missing kit.
	var kit: StyleBox = UiIcons.card_panel()
	if kit != null:
		(kit as StyleBoxTexture).set_content_margin_all(CARD_PADDING)
		card.add_theme_stylebox_override("panel", kit)
	else:
		var box := StyleBoxFlat.new()
		box.bg_color = UiPalette.CARD_BG
		box.border_color = UiPalette.CARD_BORDER_DIM
		box.set_border_width_all(CARD_BORDER_WIDTH)
		box.set_corner_radius_all(CARD_CORNER_RADIUS)
		box.set_content_margin_all(CARD_PADDING)
		card.add_theme_stylebox_override("panel", box)

	var content := HBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	card.add_child(content)
	content.add_child(_build_well(row))

	var texts := VBoxContainer.new()
	texts.name = "Texts"
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	var discovered: bool = bool(row["discovered"])
	var name_color: Color = UiPalette.INK
	if not discovered:
		name_color.a = UNDISCOVERED_TEXT_ALPHA
	var name_label := _label(String(row["name"]), UiPalette.FONT_SIZE_BODY, name_color)
	name_label.name = "Name"
	texts.add_child(name_label)
	for line: String in row["lines"] as Array[String]:
		if line.is_empty():
			continue
		var line_label := _label(line, UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_MUTED_ON_PAPER)
		line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(line_label)
	content.add_child(texts)

	# N9-11: a freshly discovered entry wears a SUCCESS-green NEW pill until
	# its first render; sits left of the tier/boss pill when both exist.
	if bool(row.get("is_new", false)):
		var new_pill := PanelContainer.new()
		new_pill.name = "NewPill"
		new_pill.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var new_box := StyleBoxFlat.new()
		new_box.bg_color = UiPalette.SUCCESS
		new_box.set_corner_radius_all(TIER_PILL_CORNER_RADIUS)
		new_box.content_margin_left = TIER_PILL_PADDING_X
		new_box.content_margin_right = TIER_PILL_PADDING_X
		new_box.content_margin_top = TIER_PILL_PADDING_Y
		new_box.content_margin_bottom = TIER_PILL_PADDING_Y
		new_pill.add_theme_stylebox_override("panel", new_box)
		new_pill.add_child(_label("NEW", UiPalette.FONT_SIZE_LABEL, UiPalette.INK))
		content.add_child(new_pill)

	var pill_text: String = String(row["pill"])
	if not pill_text.is_empty():
		var pill := PanelContainer.new()
		pill.name = "Pill"
		pill.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var pill_box := StyleBoxFlat.new()
		pill_box.bg_color = UiPalette.VERMILION
		pill_box.set_corner_radius_all(TIER_PILL_CORNER_RADIUS)
		pill_box.content_margin_left = TIER_PILL_PADDING_X
		pill_box.content_margin_right = TIER_PILL_PADDING_X
		pill_box.content_margin_top = TIER_PILL_PADDING_Y
		pill_box.content_margin_bottom = TIER_PILL_PADDING_Y
		pill.add_theme_stylebox_override("panel", pill_box)
		pill.add_child(_label(pill_text, UiPalette.FONT_SIZE_LABEL, UiPalette.PILL_TEXT))
		content.add_child(pill)
	return card


## Dark square icon well. Discovered = real art; undiscovered = the same art
## as an INK silhouette (the shape teases, the name stays ???). No texture
## falls back to a "?" glyph so a missing file never breaks the row.
func _build_well(row: Dictionary) -> Control:
	var well := PanelContainer.new()
	well.name = "Well"
	well.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	well.custom_minimum_size = Vector2(WELL_SIZE, WELL_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.CARD_WELL
	style.set_corner_radius_all(WELL_CORNER_RADIUS)
	well.add_theme_stylebox_override("panel", style)
	var texture: Texture2D = _row_icon(row)
	if texture != null:
		var icon: TextureRect = UiIcons.icon_rect(texture, ICON_SIZE)
		icon.name = "Icon"
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not bool(row["discovered"]):
			icon.self_modulate = UiPalette.INK
		well.add_child(icon)
	else:
		var glyph := _label("?", UiPalette.FONT_SIZE_TITLE, UiPalette.TEXT_MUTED_ON_DARK)
		glyph.name = "Glyph"
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		well.add_child(glyph)
	return well


func _row_icon(row: Dictionary) -> Texture2D:
	match _tab:
		Bestiary.KIND_MONSTERS:
			return _monster_icon(String(row["sprite_dir"]))
		Bestiary.KIND_LOOT:
			return UiIcons.loot_icon(String(row["id"]))
		Bestiary.KIND_WEAPONS:
			return UiIcons.weapon_icon(String(row["id"]))
	return null


## First frame of the monster's idle strip (frames are square, N3-12), so
## the bestiary portrait is exactly the in-world creature.
func _monster_icon(sprite_dir: String) -> Texture2D:
	if sprite_dir.is_empty():
		return null
	var path: String = sprite_dir + "/idle.png"
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var strip: Texture2D = load(path)
	var side: float = strip.get_size().y
	if strip.get_size().x <= side:
		return strip
	var frame := AtlasTexture.new()
	frame.atlas = strip
	frame.region = Rect2(Vector2.ZERO, Vector2(side, side))
	return frame


func _pill_box(fill: Color, selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = UiPalette.GOLD if selected else UiPalette.CARD_BORDER_DIM
	box.set_border_width_all(CARD_BORDER_WIDTH)
	box.set_corner_radius_all(PILL_CORNER_RADIUS)
	box.content_margin_left = PILL_PADDING_X
	box.content_margin_right = PILL_PADDING_X
	box.content_margin_top = PILL_PADDING_Y
	box.content_margin_bottom = PILL_PADDING_Y
	return box


func _profile() -> Dictionary:
	if SaveService.instance != null:
		return SaveService.instance.profile
	return SaveProfile.default_profile()


func _weapon_data_ids() -> Array[String]:
	var ids: Array[String] = []
	for weapon_id: String in _weapons:
		if not weapon_id.begins_with("_"):
			ids.append(weapon_id)
	return ids


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _load_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is not Dictionary:
		push_error("bestiary_screen: cannot parse " + path)
		return {}
	return data
