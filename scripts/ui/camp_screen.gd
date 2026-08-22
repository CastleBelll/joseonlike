class_name CampScreen
extends Control
## Base camp between runs (N5-3, GDD §24): the returning player's home.
## Shows the permanent state the profile already tracks (보유 엽전 + lifetime
## stats), the GDD building spots as tappable 준비 중 placeholders, and the
## two departures — 출정 (one tap into a run) and 수행자 선택.
## Dark meta-screen grammar per DESIGN.md §4 (`_02`): NIGHT background, GOLD
## title top-left, currency top-right, wood buttons at the bottom.

const STAGE_SCENE := "res://scenes/stage.tscn"
const SELECT_SCENE := "res://scenes/character_select.tscn"

const MARGIN_SIDE := 32
const MARGIN_TOP := 24
const MARGIN_BOTTOM := 28
const STAT_ROW_HEIGHT := 40.0
const PANEL_PADDING := 16
const PANEL_CORNER_RADIUS := 12
const SPOT_HEIGHT := 88.0
const SPOT_CORNER_RADIUS := 8
const SPOT_BORDER_WIDTH := 2
## N9-33: five buildings in two columns is three rows with a lone orphan on
## the last one, and that third row is what pushed 출정 off a 960px screen once
## the difficulty and run-length buttons joined the menu. Three columns fits
## the same five spots in two rows, balanced 3+2.
const SPOT_COLUMNS := 3
const BUTTON_HEIGHT := 64
const SELECT_BUTTON_HEIGHT := 56
const COIN_ICON_SIZE := 32.0
const NOTICE_FADE_SEC := 1.6
const CYCLE_BUTTON_HEIGHT := 44.0
## N9-35: same flat corner glyph the title and the combat HUD already use.
const UTILITY_BUTTON_SIZE := 44.0  # UiPalette.TOUCH_TARGET_MIN

var _notice_label: Label
var _notice_tween: Tween
# N9-22 departure settings: the ladder/length data plus the two cycle buttons
# that show the current pick — one tap steps to the next option, so departing
# still costs one tap for anyone who never touches them.
var _settings_popup: SettingsPopup
var _difficulty_config: Dictionary = {}
var _difficulty_button: Button
var _run_length_button: Button


func _ready() -> void:
	build_ui()
	# N9-35 (owner request): audio and the other settings were reachable only
	# from the title, so a player already in the camp had to back all the way
	# out to change the volume. Built in _ready rather than build_ui because
	# the headless layout test constructs the screen with no SceneTree.
	_settings_popup = SettingsPopup.new()
	add_child(_settings_popup)
	# N9-1a: 본거지 has its own track; guarded because the headless layout test
	# builds this screen with no autoloads running.
	if MusicService.instance != null:
		MusicService.instance.play("camp")


## Builds every child node. Public so the headless test can construct the
## screen without a running SceneTree (same contract as TitleScreen).
func build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = UiPalette.NIGHT
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	# N9-12: the composited village backdrop (title production layers under
	# a NIGHT scrim) sits over the flat fill; the ColorRect stays as the
	# fallback ground if the art is ever missing.
	var backdrop_path: String = "res://asset/camp/backdrop.png"
	if ResourceLoader.exists(backdrop_path, "Texture2D"):
		var art := TextureRect.new()
		art.name = "BackdropArt"
		art.texture = load(backdrop_path)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)

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
	column.add_theme_constant_override("separation", UiPalette.SPACE_LG)
	margin.add_child(column)

	var summary: Dictionary = Camp.summary(_profile())
	column.add_child(_build_header(summary))
	add_child(_build_settings_button())
	column.add_child(_build_stats(summary))
	column.add_child(_build_buildings())

	# N5-4: one quiet line after a run that revealed something new — no popup,
	# no extra tap (DESIGN.md §5.2); opening the 괴이록 clears it.
	var hint: String = Bestiary.camp_hint(_profile())
	if not hint.is_empty():
		var hint_label := _label(hint, UiPalette.FONT_SIZE_LABEL, UiPalette.GOLD)
		hint_label.name = "BestiaryHint"
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(hint_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_notice_label = _label("", UiPalette.FONT_SIZE_BODY, UiPalette.GOLD)
	_notice_label.name = "Notice"
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_notice_label)

	column.add_child(_build_menu())


## GOLD title left, coin + permanent gold right (meta grammar, capture _02).
func _build_header(summary: Dictionary) -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	var title := _label(UiLocale.t("본거지"), UiPalette.FONT_SIZE_TITLE, UiPalette.GOLD)
	title.name = "CampTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiIcons.icon_rect(UiIcons.hud_icon("coin"), COIN_ICON_SIZE))
	var gold := _label(str(int(summary["gold"])), UiPalette.FONT_SIZE_TITLE, UiPalette.TEXT_ON_DARK)
	gold.name = "GoldValue"
	header.add_child(gold)
	# N9-146: the screen-anchored gear owns the corner now; this spacer keeps
	# the gold counter from sliding underneath it.
	var gear_gap := Control.new()
	gear_gap.name = "GearGap"
	gear_gap.custom_minimum_size = Vector2(
		UTILITY_BUTTON_SIZE + UiPalette.SPACE_MD * 2.0 - MARGIN_SIDE, 0.0
	)
	header.add_child(gear_gap)
	return header


## Lifetime record rows on a dark card — permanent state only (N5-2 stats).
func _build_stats(summary: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Stats"
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.NIGHT_BROWN
	box.set_corner_radius_all(PANEL_CORNER_RADIUS)
	box.set_content_margin_all(PANEL_PADDING)
	panel.add_theme_stylebox_override("panel", box)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	panel.add_child(rows)
	_add_stat_row(rows, UiLocale.t("출정 횟수"), str(int(summary["runs_played"])))
	_add_stat_row(rows, UiLocale.t("최고 생존"), String(summary["best_time_text"]))
	_add_stat_row(rows, UiLocale.t("최고 처치"), str(int(summary["best_kills"])))
	_add_stat_row(rows, UiLocale.t("보스 처치"), str(int(summary["bosses_killed"])))
	return panel


## GDD building spots: labelled places that answer 준비 중 when touched —
## present and tappable, never a greyed-out button (DESIGN.md §6).
func _build_buildings() -> Control:
	var grid := GridContainer.new()
	grid.name = "Buildings"
	grid.columns = SPOT_COLUMNS
	grid.add_theme_constant_override("h_separation", UiPalette.SPACE_MD)
	grid.add_theme_constant_override("v_separation", UiPalette.SPACE_MD)
	for building: Dictionary in Camp.buildings():
		var spot := Button.new()
		spot.name = "Spot_" + String(building["id"])
		spot.text = String(building["label"])
		spot.custom_minimum_size = Vector2(0.0, SPOT_HEIGHT)
		spot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spot.add_theme_stylebox_override("normal", _spot_plate(UiPalette.CARD_BG))
		spot.add_theme_stylebox_override("hover", _spot_plate(UiPalette.CARD_BG_SELECTED))
		spot.add_theme_stylebox_override("pressed", _spot_plate(UiPalette.CARD_BG_SELECTED))
		spot.add_theme_stylebox_override("focus", _focus_ring())
		spot.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
		spot.add_theme_color_override("font_hover_color", UiPalette.TEXT_ON_DARK)
		spot.add_theme_color_override("font_pressed_color", UiPalette.TEXT_ON_DARK)
		spot.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
		spot.pressed.connect(_on_building_pressed.bind(building))
		grid.add_child(spot)
	return grid


## The night the player is about to walk into: which tier, how long. Locked
## tiers are simply not in the cycle — clearing one adds the next.
## N9-146 (owner: 톱니바퀴는 모든 화면 우측 상단 고정): the gear leaves the
## header row for a screen-anchored top-right corner, matching combat and the
## title screen. The header keeps its slot count so gold stays right-aligned.
func _build_settings_button() -> Control:
	var settings := Button.new()
	settings.name = "SettingsButton"
	settings.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	settings.position = Vector2(
		-UTILITY_BUTTON_SIZE - UiPalette.SPACE_MD, UiPalette.SPACE_MD
	)
	settings.flat = true
	settings.tooltip_text = UiLocale.text("title.settings")
	settings.custom_minimum_size = Vector2(UTILITY_BUTTON_SIZE, UTILITY_BUTTON_SIZE)
	var icon: TextureRect = UiIcons.icon_rect(
		UiIcons.hud_icon("settings"), UTILITY_BUTTON_SIZE * 0.6
	)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	settings.add_child(icon)
	settings.pressed.connect(func() -> void:
		if _settings_popup != null:
			_settings_popup.open()
	)
	return settings


func _build_departure_settings() -> Control:
	_difficulty_config = Difficulty.load_config()
	# Side by side, not stacked: the column already fills the screen and a
	# second full-width row pushed 출정 off the bottom on a 540x960 phone.
	var row := HBoxContainer.new()
	row.name = "DepartureSettings"
	row.add_theme_constant_override("separation", UiPalette.SPACE_MD)

	_difficulty_button = _cycle_button("DifficultyButton", _on_difficulty_pressed)
	row.add_child(_difficulty_button)
	_run_length_button = _cycle_button("RunLengthButton", _on_run_length_pressed)
	row.add_child(_run_length_button)
	_refresh_departure_labels()
	return row


func _cycle_button(node_name: String, handler: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(0.0, CYCLE_BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WoodButton.apply(button)
	button.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	button.pressed.connect(handler)
	return button


func _refresh_departure_labels() -> void:
	var tier: Dictionary = Difficulty.entry(
		_difficulty_config, Difficulty.selected_id(_difficulty_config)
	)
	var length: Dictionary = Difficulty.run_length(
		_difficulty_config, Difficulty.selected_run_length(_difficulty_config)
	)
	_difficulty_button.text = UiLocale.t("난이도 ‹%s›") % UiLocale.data_name(tier)
	_difficulty_button.tooltip_text = String(tier.get("desc_ko", ""))
	# Both cycle buttons name what they cycle; the length button used to show
	# only the value, which read as a stray chip next to a labelled one.
	_run_length_button.text = UiLocale.t("길이 ‹%s›") % UiLocale.data_name(length)
	_run_length_button.tooltip_text = String(length.get("desc_ko", ""))


func _on_difficulty_pressed() -> void:
	var cleared: Array = _profile().get(Difficulty.CLEARED_KEY, [])
	var open_ids: Array[String] = []
	for tier: Dictionary in Difficulty.ladder(_difficulty_config):
		var id: String = String(tier.get("id", ""))
		if Difficulty.is_unlocked(_difficulty_config, id, cleared):
			open_ids.append(id)
	_cycle_setting(Difficulty.SELECTED_KEY, open_ids, Difficulty.selected_id(_difficulty_config))


func _on_run_length_pressed() -> void:
	var ids: Array[String] = []
	for raw: Variant in _difficulty_config.get("run_lengths", []):
		if raw is Dictionary:
			ids.append(String((raw as Dictionary).get("id", "")))
	_cycle_setting(
		Difficulty.RUN_LENGTH_KEY, ids, Difficulty.selected_run_length(_difficulty_config)
	)


func _cycle_setting(key: String, ids: Array[String], current: String) -> void:
	if ids.size() < 2 or SaveService.instance == null:
		# A single option has nothing to cycle to; say so instead of no-opping
		# silently, so a locked ladder does not read as a dead button.
		_show_notice(UiLocale.t("아직 다른 선택지가 없다"))
		return
	var index: int = maxi(ids.find(current), 0)
	SaveService.instance.set_setting(key, ids[(index + 1) % ids.size()])
	_refresh_departure_labels()


func _build_menu() -> Control:
	var stack := VBoxContainer.new()
	stack.name = "MenuButtons"
	stack.add_theme_constant_override("separation", UiPalette.SPACE_MD)

	stack.add_child(_build_departure_settings())

	var select := Button.new()
	select.name = "SelectButton"
	select.text = UiLocale.t("수행자 선택")
	select.custom_minimum_size = Vector2(0.0, SELECT_BUTTON_HEIGHT)
	WoodButton.apply(select)
	select.pressed.connect(_on_select_pressed)
	stack.add_child(select)

	var depart := Button.new()
	depart.name = "DepartButton"
	depart.text = UiLocale.t("출정")
	depart.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	WoodButton.apply(depart)
	depart.pressed.connect(_on_depart_pressed)
	stack.add_child(depart)
	return stack


## One tap into a run (interaction budget, DESIGN.md §5.2). route_character
## is a no-op for returning profiles, so the saved selection is what departs.
func _on_depart_pressed() -> void:
	if SaveService.instance != null:
		var routed: String = Ftue.route_character(SaveService.instance.profile)
		if routed != SaveService.instance.selected_character():
			SaveService.instance.set_selected_character(routed)
	get_tree().change_scene_to_file(STAGE_SCENE)


func _on_select_pressed() -> void:
	get_tree().change_scene_to_file(SELECT_SCENE)


func _on_building_pressed(building: Dictionary) -> void:
	var notice: String = Camp.building_notice(building)
	if notice.is_empty():
		var scene: String = Camp.building_scene(building)
		if not scene.is_empty():
			get_tree().change_scene_to_file(scene)
		return
	_show_notice(String(building["label"]) + " — " + notice)


func _show_notice(text: String) -> void:
	_notice_label.text = text
	_notice_label.modulate = Color.WHITE
	if not is_inside_tree():
		return
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(NOTICE_FADE_SEC)
	_notice_tween.tween_property(_notice_label, "modulate", Color.TRANSPARENT, NOTICE_FADE_SEC)


func _profile() -> Dictionary:
	if SaveService.instance != null:
		return SaveService.instance.profile
	return SaveProfile.default_profile()


func _add_stat_row(rows: VBoxContainer, row_name: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.name = row_name
	row.custom_minimum_size = Vector2(0.0, STAT_ROW_HEIGHT)
	var name_label := _label(row_name, UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_MUTED_ON_DARK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := _label(value_text, UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_ON_DARK)
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	rows.add_child(row)


func _spot_plate(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = UiPalette.CARD_BORDER_DIM
	box.set_border_width_all(SPOT_BORDER_WIDTH)
	box.set_corner_radius_all(SPOT_CORNER_RADIUS)
	return box


func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = UiPalette.GOLD
	ring.set_border_width_all(SPOT_BORDER_WIDTH)
	ring.set_corner_radius_all(SPOT_CORNER_RADIUS)
	return ring


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
