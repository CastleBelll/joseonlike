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
## N9-153: cap for the whole camp column on wide viewports.
const COLUMN_MAX_WIDTH := 560.0
## Owner (가로에서 본거지가 스크롤된다): landscape has 540 design px of height,
## which the portrait column cannot fit. The band widens and the content
## splits into two side-by-side halves instead of scrolling.
const COLUMN_MAX_WIDTH_LANDSCAPE := 912.0
const MARGIN_TOP := 24
const MARGIN_BOTTOM := 28
const MARGIN_TOP_LANDSCAPE := 12
const MARGIN_BOTTOM_LANDSCAPE := 12
const STAT_ROW_HEIGHT := 40.0
const PANEL_PADDING := 16
const PANEL_CORNER_RADIUS := 12
const SPOT_HEIGHT := 88.0
## Owner (가로에서 버튼이 너무 크다): landscape trades the portrait height
## budget for width, so the plates and CTAs run shorter there — still above
## the 44px touch minimum.
const SPOT_HEIGHT_LANDSCAPE := 64.0
const BUTTON_HEIGHT_LANDSCAPE := 52
const SELECT_BUTTON_HEIGHT_LANDSCAPE := 48
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
var _was_landscape: bool = false
# N9-22 departure settings: the ladder/length data plus the two cycle buttons
# that show the current pick — one tap steps to the next option, so departing
# still costs one tap for anyone who never touches them.
var _settings_popup: SettingsPopup
var _difficulty_config: Dictionary = {}
var _difficulty_button: Button
var _run_length_button: Button


func _ready() -> void:
	build_ui()
	# Owner (전체화면 가로로 바꿔도 세로 배치 그대로다): the two-half landscape
	# layout is decided at build time, so a rotation or a fullscreen toggle has
	# to rebuild it — only when the orientation actually flips.
	_was_landscape = _is_landscape()
	resized.connect(_on_resized)
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
	var backdrop_path: String = _backdrop_path()
	if ResourceLoader.exists(backdrop_path, "Texture2D"):
		var art := TextureRect.new()
		art.name = "BackdropArt"
		art.texture = load(backdrop_path)
		resized.connect(func() -> void:
			art.texture = load(_backdrop_path()))
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# N9-153: cover, never distort — landscape crops the portrait art.
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)

	var margin := MarginContainer.new()
	margin.name = "Layout"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	# N9-153: on wide screens the column holds the portrait design band,
	# centered, instead of stretching across the whole width.
	var band: float = (
		COLUMN_MAX_WIDTH_LANDSCAPE if _is_landscape() else COLUMN_MAX_WIDTH
	)
	var side: float = maxf(MARGIN_SIDE, (size.x - band) / 2.0)
	margin.add_theme_constant_override("margin_left", int(side))
	margin.add_theme_constant_override("margin_right", int(side))
	# Landscape spends its short height on content, not on chrome margins.
	var top_margin: int = MARGIN_TOP_LANDSCAPE if _is_landscape() else MARGIN_TOP
	var bottom_margin: int = MARGIN_BOTTOM_LANDSCAPE if _is_landscape() else MARGIN_BOTTOM
	margin.add_theme_constant_override("margin_top", top_margin)
	margin.add_theme_constant_override("margin_bottom", bottom_margin)
	add_child(margin)

	# N9-154: landscape hands the camp a 540px-tall canvas the portrait
	# column overflows — a scroll container absorbs it; portrait fits and
	# never actually scrolls.
	var scroll := ScrollContainer.new()
	scroll.name = "ColumnScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UiPalette.SPACE_LG)
	scroll.add_child(column)

	var summary: Dictionary = Camp.summary(_profile())
	column.add_child(_build_header(summary))
	add_child(_build_settings_button())

	# N5-4: one quiet line after a run that revealed something new — no popup,
	# no extra tap (DESIGN.md §5.2); opening the 괴이록 clears it.
	var hint: String = Bestiary.camp_hint(_profile())
	var hint_label: Label = null
	if not hint.is_empty():
		hint_label = _label(hint, UiPalette.FONT_SIZE_LABEL, UiPalette.GOLD)
		hint_label.name = "BestiaryHint"
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_notice_label = _label("", UiPalette.FONT_SIZE_BODY, UiPalette.GOLD)
	_notice_label.name = "Notice"
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if _is_landscape():
		# Two halves: the record on the left, the places and the departure on
		# the right — the wide screen spends width so nothing has to scroll.
		var halves := HBoxContainer.new()
		halves.name = "Halves"
		halves.add_theme_constant_override("separation", UiPalette.SPACE_LG)
		halves.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var left := VBoxContainer.new()
		left.name = "LeftHalf"
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override("separation", UiPalette.SPACE_MD)
		left.add_child(_build_stats(summary))
		if hint_label != null:
			left.add_child(hint_label)
		var left_spacer := Control.new()
		left_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left.add_child(left_spacer)
		left.add_child(_notice_label)
		var right := VBoxContainer.new()
		right.name = "RightHalf"
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_theme_constant_override("separation", UiPalette.SPACE_MD)
		right.add_child(_build_buildings())
		var right_spacer := Control.new()
		right_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_child(right_spacer)
		right.add_child(_build_menu())
		halves.add_child(left)
		halves.add_child(right)
		column.add_child(halves)
		return

	column.add_child(_build_stats(summary))
	column.add_child(_build_buildings())
	if hint_label != null:
		column.add_child(hint_label)

	# Owner (본거지 세로에 빈 띠가 크다): all the slack used to go above the
	# departure cluster, which pinned it to the bottom margin and left one wide
	# band of backdrop doing nothing in the middle. The cluster still belongs
	# low — 출정 is the thumb's button — so the slack is split rather than
	# moved: most of it above, a quarter below, which lifts the cluster off the
	# edge and turns the band into breathing room with ground under it.
	var spacer := Control.new()
	spacer.name = "TopSlack"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 3.0
	column.add_child(spacer)

	column.add_child(_notice_label)
	column.add_child(_build_menu())

	var bottom_slack := Control.new()
	bottom_slack.name = "BottomSlack"
	bottom_slack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_slack.size_flags_stretch_ratio = 1.0
	column.add_child(bottom_slack)


## N9-157: per-orientation pixel-art backdrops with the painted single as
## the fallback chain's end.
func _backdrop_path() -> String:
	var wide: bool = size.x > size.y
	if wide and ResourceLoader.exists("res://asset/camp/backdrop_landscape.png", "Texture2D"):
		return "res://asset/camp/backdrop_landscape.png"
	if ResourceLoader.exists("res://asset/camp/backdrop_portrait.png", "Texture2D"):
		return "res://asset/camp/backdrop_portrait.png"
	return "res://asset/camp/backdrop.png"


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
	# the gold counter out from under it.
	#
	# Owner (특히 이상한건 설정 아이콘 배치야): eight pixels was not a gap. The
	# coin, the number and the gear sat in one clump at the same height, so the
	# gear read as part of the currency readout rather than as a control. A
	# counter and a button need to look like different kinds of thing.
	var gear_gap := Control.new()
	gear_gap.name = "GearGap"
	gear_gap.custom_minimum_size = Vector2(
		UTILITY_BUTTON_SIZE + UiPalette.SPACE_XL, 0.0
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
func _is_landscape() -> bool:
	return size.x > size.y


## Rebuild only on an orientation flip — every other resize keeps its nodes,
## so focus, tweens and the open settings popup survive a plain window drag.
func _on_resized() -> void:
	var now: bool = _is_landscape()
	if now == _was_landscape:
		return
	_was_landscape = now
	for child: Node in get_children():
		if child != _settings_popup:
			child.queue_free()
	build_ui()


func _build_buildings() -> Control:
	var grid := GridContainer.new()
	grid.name = "Buildings"
	# The landscape half is narrower than the portrait band, so the same five
	# spots read better in two columns there.
	grid.columns = 2 if _is_landscape() else SPOT_COLUMNS
	grid.add_theme_constant_override("h_separation", UiPalette.SPACE_MD)
	grid.add_theme_constant_override("v_separation", UiPalette.SPACE_MD)
	for building: Dictionary in Camp.buildings():
		var spot := Button.new()
		spot.name = "Spot_" + String(building["id"])
		spot.text = String(building["label"])
		spot.custom_minimum_size = Vector2(
			0.0, SPOT_HEIGHT_LANDSCAPE if _is_landscape() else SPOT_HEIGHT
		)
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
	# N9-160 (owner: 본거지 톱니 위치가 이상하다): the gear hugs the CONTENT
	# band's right edge at the header's height, not the far screen corner —
	# on wide screens the corner sat detached from the centered column.
	var band: float = (
		COLUMN_MAX_WIDTH_LANDSCAPE if _is_landscape() else COLUMN_MAX_WIDTH
	)
	var band_inset: float = maxf(MARGIN_SIDE, (size.x - band) / 2.0)
	var top_margin: int = MARGIN_TOP_LANDSCAPE if _is_landscape() else MARGIN_TOP
	# Centred on the title row rather than nudged up off it: the old -6 left the
	# gear riding above the gold's baseline, which is what made a 44px button
	# read as a decoration hanging off the number.
	settings.position = Vector2(
		-band_inset - UTILITY_BUTTON_SIZE,
		float(top_margin) + (UiPalette.FONT_SIZE_TITLE - UTILITY_BUTTON_SIZE) / 2.0
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
	select.custom_minimum_size = Vector2(0.0, float(
		SELECT_BUTTON_HEIGHT_LANDSCAPE if _is_landscape() else SELECT_BUTTON_HEIGHT
	))
	WoodButton.apply(select)
	select.pressed.connect(_on_select_pressed)
	stack.add_child(select)

	var depart := Button.new()
	depart.name = "DepartButton"
	depart.text = UiLocale.t("출정")
	depart.custom_minimum_size = Vector2(0.0, float(
		BUTTON_HEIGHT_LANDSCAPE if _is_landscape() else BUTTON_HEIGHT
	))
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
	# N9-150 지역 선택: tapping cycles the departure region through the
	# unlocked nights; with only one open it explains what opens the next.
	if Camp.building_in_place(building):
		_cycle_region()
		return
	var notice: String = Camp.building_notice(building)
	if notice.is_empty():
		var scene: String = Camp.building_scene(building)
		if not scene.is_empty():
			get_tree().change_scene_to_file(scene)
		return
	_show_notice(String(building["label"]) + " — " + notice)


func _cycle_region() -> void:
	var profile: Dictionary = _profile()
	var open: Array[String] = Camp.unlocked_stages(profile)
	if open.size() <= 1:
		_show_notice(UiLocale.t("지역 선택") + " — " + UiLocale.t("첫 괴수를 쓰러뜨리면 다음 밤이 열린다"))
		return
	var next: String = Camp.next_stage(profile)
	if SaveService.instance != null:
		SaveService.instance.profile["selected_stage"] = next
		SaveService.instance.save_profile()
	_show_notice(UiLocale.t("출정지") + " — " + Camp.stage_label(next))


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
