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
const PANEL_PADDING := 16
const PANEL_CORNER_RADIUS := 12
## Owner (가로에서 버튼이 너무 크다): landscape trades the portrait height
## budget for width, so the plates and CTAs run shorter there — still above
## the 44px touch minimum.
const BUTTON_HEIGHT_LANDSCAPE := 52
const SELECT_BUTTON_HEIGHT_LANDSCAPE := 48
const SPOT_CORNER_RADIUS := 8
const SPOT_BORDER_WIDTH := 2
## N9-33: five buildings in two columns is three rows with a lone orphan on
## the last one, and that third row is what pushed 출정 off a 960px screen once
## the difficulty and run-length buttons joined the menu. Three columns fits
## the same five spots in two rows, balanced 3+2.
const BUTTON_HEIGHT := 64
const SELECT_BUTTON_HEIGHT := 56
# R13: matches the meta tree's coin so the pill is the same on both screens.
const COIN_ICON_SIZE := 28.0
const NOTICE_FADE_SEC := 1.6
const CYCLE_BUTTON_HEIGHT := 44.0
## N11-5: where everyone stands, normalized to the map layer per orientation.
## Positions are hand-set against the backdrop art; the placement pass clamps
## them on-canvas whatever the device, and the sweep guards overlaps.
const NPCS_PATH := "res://data/npcs.json"
const SPOT_SIZE := Vector2(96.0, 86.0)
const SPOT_SIZE_LANDSCAPE := Vector2(88.0, 72.0)
const SPOT_DISC := 44.0
const MAP_SPOTS: Array[Dictionary] = [
	{"id": "shrine", "npc": "sosul", "label": "사당",
		"scene": "res://scenes/meta_tree.tscn",
		"pos": [0.24, 0.42], "pos_l": [0.13, 0.52]},
	{"id": "archive", "npc": "mukheon", "label": "서고",
		"scene": "res://scenes/bestiary.tscn", "badge": true,
		"pos": [0.76, 0.40], "pos_l": [0.335, 0.48]},
	{"id": "stele", "npc": "", "label": "공적비",
		"scene": "res://scenes/achievements.tscn",
		"pos": [0.50, 0.50], "pos_l": [0.235, 0.72]},
	{"id": "barracks", "npc": "", "label": "막사", "select": true,
		"pos": [0.22, 0.62], "pos_l": [0.54, 0.48]},
	{"id": "smithy", "npc": "dolmusoe", "label": "대장간",
		"scene": "res://scenes/smithy.tscn",
		"pos": [0.78, 0.60], "pos_l": [0.78, 0.50]},
	{"id": "training", "npc": "beomgang", "label": "훈련장",
		"pos": [0.50, 0.74], "pos_l": [0.875, 0.72]},
	{"id": "apothecary", "npc": "choha", "label": "약방",
		"pos": [0.26, 0.86], "pos_l": [0.46, 0.72]},
	{"id": "market", "npc": "neoreum", "label": "장터",
		"pos": [0.74, 0.86], "pos_l": [0.685, 0.76]},
]## N9-35: same flat corner glyph the title and the combat HUD already use.
const UTILITY_BUTTON_SIZE := 44.0  # UiPalette.TOUCH_TARGET_MIN

var _notice_label: Label
## N11-5 map state: the ground layer the spots stand on, and the spot nodes
## keyed by id for the per-resize placement pass.
var _map_layer: Control
var _spot_nodes: Dictionary = {}
var _npcs: Dictionary = {}
var _notice_tween: Tween
var _was_landscape: bool = false
var _built_width: float = 0.0
const REBUILD_WIDTH_STEP := 24.0
# N9-22 departure settings: the ladder/length data plus the two cycle buttons
# that show the current pick — one tap steps to the next option, so departing
# still costs one tap for anyone who never touches them.
var _settings_popup: SettingsPopup
var _difficulty_config: Dictionary = {}
var _difficulty_button: Button
var _run_length_button: Button
var _region_button: Button


func _ready() -> void:
	build_ui()
	_built_width = size.x
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
	# Resweep visual R1: flipping the language in this popup left every camp
	# string in the old locale until the next rebuild. Same wiring as the
	# title screen — rebuild the screen the popup sits on.
	_settings_popup.locale_changed.connect(_rebuild_for_locale)
	# N9-1a: 본거지 has its own track; guarded because the headless layout test
	# builds this screen with no autoloads running.
	if MusicService.instance != null:
		MusicService.instance.play("camp")
	# N11-10 (owner: 처음은 설명해주는 가이드 엔피씨): the archivist meets the
	# player on their first camp visit — once, and the flag survives the run.
	if SaveService.instance != null 			and not SaveService.instance.is_harness_profile() 			and Ftue.should_meet_archivist(SaveService.instance.profile):
		var welcome := GuideDialog.new()
		welcome.name = "ArchivistWelcome"
		welcome.portrait_path = ""
		# QA M-2: bottom-anchored the panel buried 3-4 lower-yard spots and
		# their NPC name labels on the very screen it explains; the top band
		# holds only sky above the shrine row.
		welcome.anchor_top = true
		add_child(welcome)
		welcome.open(Ftue.archivist_pages())
		# QA F-17: the dialog panel sits over the dial row, and the sortie
		# button underneath stayed live — a player could depart mid-guide.
		# The bar sleeps while 묵헌 speaks.
		var bar: Control = get_node_or_null("Layout/Frame/BottomBar")
		if bar != null:
			bar.visible = false
		welcome.finished.connect(func() -> void:
			SaveService.instance.mark_archivist_met()
			if bar != null:
				bar.visible = true
			welcome.queue_free()
		)


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
		# No resized hook here (Q19): the path only changes on an orientation
		# flip, and a flip rebuilds this whole UI — art included — through
		# _on_resized. The old per-art lambda outlived its freed capture and
		# piled one dead connection (and one SCRIPT ERROR per resize) onto
		# every flip.
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
	var top_margin: int = (
		MARGIN_TOP_LANDSCAPE if _is_landscape() else int(MARGIN_TOP * _squeeze())
	)
	var bottom_margin: int = (
		MARGIN_BOTTOM_LANDSCAPE if _is_landscape() else int(MARGIN_BOTTOM * _squeeze())
	)
	margin.add_theme_constant_override("margin_top", top_margin)
	margin.add_theme_constant_override("margin_bottom", bottom_margin)
	add_child(margin)

	# N11-5 (owner: 왜 본거지가 아직도 버튼이야 맵형식으로 NPC처럼): the camp
	# is a PLACE now. The button grid and the stats card are gone — the
	# backdrop is the ground, the people and sites stand ON it as tappable
	# spots, and only the departure bar stays chrome at the bottom.
	var frame := VBoxContainer.new()
	frame.name = "Frame"
	frame.add_theme_constant_override("separation", int(UiPalette.SPACE_SM))
	margin.add_child(frame)

	var summary: Dictionary = Camp.summary(_profile())
	frame.add_child(_build_header(summary))
	add_child(_build_settings_button())

	_map_layer = Control.new()
	_map_layer.name = "MapLayer"
	_map_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.add_child(_map_layer)
	_build_map_spots()
	_map_layer.resized.connect(_layout_spots)

	var bottom := VBoxContainer.new()
	bottom.name = "BottomBar"
	bottom.add_theme_constant_override("separation", int(UiPalette.SPACE_SM))
	frame.add_child(bottom)
	_notice_label = _label("", UiPalette.FONT_SIZE_BODY, UiPalette.GOLD)
	_notice_label.name = "Notice"
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_notice_label)
	bottom.add_child(_build_departure_settings())
	var depart := Button.new()
	depart.name = "DepartButton"
	depart.text = UiLocale.t("출정")
	depart.custom_minimum_size = Vector2(0.0, float(
		BUTTON_HEIGHT_LANDSCAPE if _is_landscape()
		else int(maxf(BUTTON_HEIGHT * _squeeze(), UTILITY_BUTTON_SIZE))
	))
	WoodButton.apply(depart)
	depart.pressed.connect(_on_depart_pressed)
	bottom.add_child(depart)


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
	# Resweep visual R13: the same value wore different clothes per screen —
	# 수련 keeps it in a bordered pill, the camp floated it bare. One pill,
	# same tokens, both screens.
	var pill := PanelContainer.new()
	pill.name = "GoldPill"
	var pill_box := StyleBoxFlat.new()
	pill_box.bg_color = UiPalette.CARD_BG
	pill_box.border_color = UiPalette.CARD_BORDER_DIM
	pill_box.set_border_width_all(3)
	pill_box.set_corner_radius_all(UiPalette.PILL_RADIUS)
	pill_box.content_margin_left = UiPalette.PILL_PAD_X
	pill_box.content_margin_right = UiPalette.PILL_PAD_X
	pill_box.content_margin_top = UiPalette.PILL_PAD_Y
	pill_box.content_margin_bottom = UiPalette.PILL_PAD_Y
	pill.add_theme_stylebox_override("panel", pill_box)
	var pill_row := HBoxContainer.new()
	pill_row.name = "PillRow"
	pill_row.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	pill_row.add_child(UiIcons.icon_rect(UiIcons.hud_icon("coin"), COIN_ICON_SIZE))
	var gold := _label(str(int(summary["gold"])), UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_ON_DARK)
	gold.name = "GoldValue"
	pill_row.add_child(gold)
	pill.add_child(pill_row)
	header.add_child(pill)
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


func _squeeze() -> float:
	if _is_landscape():
		return 1.0
	return clampf(size.y / 960.0, 0.85, 1.0)


func _is_landscape() -> bool:
	return size.x > size.y


## Rebuild only on an orientation flip — every other resize keeps its nodes,
## so focus, tweens and the open settings popup survive a plain window drag.
func _on_resized() -> void:
	var now: bool = _is_landscape()
	# A width step also rebuilds (owner: 모바일에서 전체적으로 너무 작아): the
	# adaptive base can hand this screen a 486-wide canvas where the last build
	# assumed 540, and every fixed-width band then hangs past the edge. The
	# threshold keeps a desktop drag from rebuilding per pixel.
	var width_moved: bool = absf(size.x - _built_width) > REBUILD_WIDTH_STEP
	if now == _was_landscape and not width_moved:
		return
	_was_landscape = now
	_built_width = size.x
	for child: Node in get_children():
		if child != _settings_popup:
			child.queue_free()
	build_ui()


## Resweep visual R1: every camp string is set at build time, so a locale
## flip rebuilds the screen the same way an orientation flip does.
func _rebuild_for_locale() -> void:
	_built_width = size.x
	_was_landscape = _is_landscape()
	for child: Node in get_children():
		if child != _settings_popup:
			child.queue_free()
	build_ui()


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
	# F40: the HD gear carries its own rim — at 0.6 it read as a pale 24px
	# dot next to the HUD's full-size dial. The rim IS the plate; it fills
	# the whole 44px target, matching the combat corner exactly.
	var icon: TextureRect = UiIcons.icon_rect(
		UiIcons.hud_icon("settings"), UTILITY_BUTTON_SIZE
	)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.position = -icon.custom_minimum_size / 2.0
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
	# QA F-16 residue: three dials side by side leave 108px each on a 486
	# canvas and the en VALUES need 122px — the narrow portrait folds them
	# into two rows (difficulty+length, then the region full-width).
	var narrow: bool = not _is_landscape() and size.x < 520.0
	var frame: Container = VBoxContainer.new() if narrow else HBoxContainer.new()
	frame.name = "DepartureSettings"
	frame.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	var first: Container = frame
	if narrow:
		first = HBoxContainer.new()
		first.name = "DialRow"
		first.add_theme_constant_override("separation", UiPalette.SPACE_SM)
		frame.add_child(first)
	_difficulty_button = _cycle_button("DifficultyButton", _on_difficulty_pressed)
	first.add_child(_difficulty_button)
	_run_length_button = _cycle_button("RunLengthButton", _on_run_length_pressed)
	first.add_child(_run_length_button)
	# N11-5: the region pick moves off the map (its 지역 선택 spot is gone)
	# and joins the other two departure dials.
	_region_button = _cycle_button("RegionButton", _cycle_region)
	frame.add_child(_region_button)
	_refresh_departure_labels()
	return frame


func _cycle_button(node_name: String, handler: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(0.0, CYCLE_BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The English labels ("Length ‹Standard Night›") demand more width than a
	# shrunken phone base can give the pair side by side — the row then forced
	# the whole column wide and 출정 walked off the screen edge. Ellipsis over
	# overflow: the ‹value› is still readable and a tap cycles it anyway.
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	# QA F-16: 148px cannot hold "Difficulty ‹Calm Path›" — portrait dials
	# carry the VALUE alone (‹Calm Path› fits), landscape keeps the label.
	var wide: bool = _is_landscape()
	_difficulty_button.text = (
		UiLocale.t("난이도 ‹%s›") if wide else "‹%s›"
	) % UiLocale.data_name(tier)
	_difficulty_button.tooltip_text = String(tier.get("desc_ko", ""))
	# Both cycle buttons name what they cycle; the length button used to show
	# only the value, which read as a stray chip next to a labelled one.
	_run_length_button.text = (
		UiLocale.t("길이 ‹%s›") if wide else "‹%s›"
	) % UiLocale.data_name(length)
	_run_length_button.tooltip_text = String(length.get("desc_ko", ""))
	if _region_button != null:
		var open: Array[String] = Camp.unlocked_stages(_profile())
		var current: String = String(_profile().get(
			"selected_stage", open[0] if not open.is_empty() else ""
		))
		_region_button.text = (
			UiLocale.t("출정지 ‹%s›") if wide else "‹%s›"
		) % Camp.stage_label(current)
		_style_cycle(_region_button, "plaque_cream")
	# Owner (난이도, 길이 등급에따라 다른 이미지 배너로): the plaque ladder
	# darkens as the pick escalates, so the choice reads at a glance before
	# the words do.
	var rank: int = int(tier.get("rank", 0))
	_style_cycle(
		_difficulty_button,
		DIFFICULTY_PLAQUES.get(rank, "plaque_cream"),
		DIFFICULTY_TINTS.get(rank, Color.WHITE)
	)
	_style_cycle(_run_length_button, LENGTH_PLAQUES.get(
		String(length.get("id", "")), "plaque_cream"
	))


## Escalation ladder: calm cream to plague red.
## F12/M5: plaque_indigo measured plum (a twin of purple), and plaque_box
## turned out to carry a wooden crate drawing — a picture, not a colour.
## Rung 1 is the brown plaque tinted toward green instead: five rungs, five
## unmistakable hues, one art family.
const DIFFICULTY_PLAQUES := {
	0: "plaque_cream", 1: "plaque_brown", 2: "plaque_brown",
	3: "plaque_purple", 4: "plaque_red",
}
const DIFFICULTY_TINTS := {
	1: Color(0.62, 0.86, 0.62),
}
const LENGTH_PLAQUES := {
	"short": "plaque_cream", "standard": "plaque_brown",
	"long": "plaque_purple", "endless": "plaque_red",
}
## Light plaques carry ink, dark ones carry the light text.
const LIGHT_PLAQUES: Array[String] = ["plaque_cream"]


func _style_cycle(button: Button, piece: String, tint: Color = Color.WHITE) -> void:
	var plate: StyleBox = UiIcons.kit_panel(piece, UiIcons.KIT_PLAQUE_MARGIN)
	if plate == null:
		return
	for state: String in ["normal", "hover", "pressed"]:
		var styled: StyleBox = plate.duplicate()
		if styled is StyleBoxTexture:
			(styled as StyleBoxTexture).modulate_color = (
				UiIcons.KIT_BUTTON_TINTS.get(state, Color.WHITE) as Color * tint
			)
		button.add_theme_stylebox_override(state, styled)
	var on_light: bool = LIGHT_PLAQUES.has(piece)
	for color_name: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color"
	]:
		button.add_theme_color_override(
			color_name, UiPalette.INK if on_light else UiPalette.TEXT_ON_DARK
		)


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
	var next: String = ids[(index + 1) % ids.size()]
	SaveService.instance.set_setting(key, next)
	_refresh_departure_labels()
	# QA F-15: a successful cycle overwrites whatever notice a refused one
	# left standing — 지역 다이얼과 같은 문법.
	var entry: Dictionary = (
		Difficulty.entry(_difficulty_config, next)
		if key == Difficulty.SELECTED_KEY
		else Difficulty.run_length(_difficulty_config, next)
	)
	_show_notice(UiLocale.data_name(entry, next))


func _on_depart_pressed() -> void:
	if SaveService.instance != null:
		var routed: String = Ftue.route_character(SaveService.instance.profile)
		if routed != SaveService.instance.selected_character():
			SaveService.instance.set_selected_character(routed)
	SceneFadeLayer.go(self, STAGE_SCENE)


func _on_select_pressed() -> void:
	SceneFadeLayer.go(self, SELECT_SCENE)


## N11-5: a spot is a person or a place. Ready ones route; the rest answer
## with the NPC's own voice instead of a bare 준비 중.
func _on_spot_pressed(spot: Dictionary) -> void:
	if bool(spot.get("select", false)):
		_on_select_pressed()
		return
	var scene: String = String(spot.get("scene", ""))
	if not scene.is_empty():
		SceneFadeLayer.go(self, scene)
		return
	var npc: Dictionary = _npcs.get(String(spot.get("npc", "")), {})
	# QA F-14: the line follows the locale like every data name does —
	# ko fallback, so a missing translation degrades instead of mixing.
	var line: String = String(npc.get(
		"line_" + UiLocale.current_locale, npc.get("line_ko", "")
	))
	var speaker: String = UiLocale.data_name(npc, String(spot.get("label", "")))
	if line.is_empty():
		_show_notice(UiLocale.t(String(spot.get("label", ""))) + " — " + Camp.NOT_READY_NOTICE)
		return
	_show_notice("%s — \"%s\"" % [speaker, line])


## One map spot: the kit's ceramic disc with the NPC's first syllable (their
## portrait slot until art lands), the place name under it, and a NEW badge
## when the archive has fresh pages. Deliberately NOT a wood button — these
## are people standing on ground, not chrome.
func _build_map_spots() -> void:
	_spot_nodes.clear()
	_npcs = _load_npcs()
	var hint: String = Bestiary.camp_hint(_profile())
	for spot: Dictionary in MAP_SPOTS:
		var button := Button.new()
		button.name = "Spot_" + String(spot["id"])
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		var spot_size: Vector2 = (
			SPOT_SIZE_LANDSCAPE if _is_landscape() else SPOT_SIZE
		)
		button.custom_minimum_size = spot_size
		button.size = spot_size
		button.pivot_offset = spot_size / 2.0
		button.pressed.connect(_on_spot_pressed.bind(spot))
		button.mouse_entered.connect(_on_spot_hover.bind(button, true))
		button.mouse_exited.connect(_on_spot_hover.bind(button, false))
		var column := VBoxContainer.new()
		column.name = "Column"
		column.set_anchors_preset(Control.PRESET_FULL_RECT)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 2)
		var well := Control.new()
		well.name = "Well"
		well.custom_minimum_size = Vector2(SPOT_DISC, SPOT_DISC)
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# QA F-13: a dark halo under the ceramic so the disc separates from
		# whatever the backdrop puts behind it — the person reads as tappable
		# before the label does. Placeholder until portrait art lands.
		var halo := Panel.new()
		halo.name = "Halo"
		var halo_style := StyleBoxFlat.new()
		halo_style.bg_color = Color(UiPalette.NIGHT, 0.55)
		halo_style.set_corner_radius_all(int(SPOT_DISC / 2.0) + 5)
		halo.add_theme_stylebox_override("panel", halo_style)
		halo.set_anchors_preset(Control.PRESET_FULL_RECT)
		halo.offset_left = -5.0
		halo.offset_top = -5.0
		halo.offset_right = 5.0
		halo.offset_bottom = 5.0
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(halo)
		var disc: TextureRect = UiIcons.kit_icon_button("disc_2", SPOT_DISC)
		if disc != null:
			disc.name = "Disc"
			well.add_child(disc)
		var npc: Dictionary = _npcs.get(String(spot.get("npc", "")), {})
		var glyph_text: String = UiLocale.data_name(npc, String(spot["label"])).left(1)
		var glyph := _label(glyph_text, UiPalette.FONT_SIZE_BODY, UiPalette.INK)
		glyph.name = "Glyph"
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(glyph)
		var well_row := HBoxContainer.new()
		well_row.alignment = BoxContainer.ALIGNMENT_CENTER
		well_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well_row.add_child(well)
		column.add_child(well_row)
		var name_label := _label(
			UiLocale.t(String(spot["label"])), UiPalette.FONT_SIZE_LABEL,
			UiPalette.TEXT_ON_DARK
		)
		name_label.name = "SpotName"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_outline_color", UiPalette.NIGHT)
		name_label.add_theme_constant_override("outline_size", 4)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(name_label)
		if not npc.is_empty():
			var who := _label(
				UiLocale.data_name(npc, ""), UiPalette.FONT_SIZE_LABEL,
				UiPalette.TEXT_MUTED_ON_DARK
			)
			who.name = "SpotNpc"
			who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			who.add_theme_color_override("font_outline_color", UiPalette.NIGHT)
			who.add_theme_constant_override("outline_size", 4)
			who.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_child(who)
		button.add_child(column)
		if bool(spot.get("badge", false)) and not hint.is_empty():
			var badge := _label("●", UiPalette.FONT_SIZE_LABEL, UiPalette.GOLD)
			badge.name = "NewBadge"
			badge.position = Vector2(spot_size.x - 14.0, 0.0)
			badge.add_theme_color_override("font_outline_color", UiPalette.NIGHT)
			badge.add_theme_constant_override("outline_size", 3)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(badge)
		_map_layer.add_child(button)
		_spot_nodes[String(spot["id"])] = button
	_layout_spots()


## Per-resize placement: normalized position times the live map size, clamped
## so a spot never leaves the ground whatever the device.
func _layout_spots() -> void:
	if _map_layer == null or _map_layer.size.x <= 0.0:
		return
	var landscape: bool = _is_landscape()
	var spot_size: Vector2 = SPOT_SIZE_LANDSCAPE if landscape else SPOT_SIZE
	for spot: Dictionary in MAP_SPOTS:
		var button: Button = _spot_nodes.get(String(spot["id"]))
		if button == null:
			continue
		var pos: Array = spot.get("pos_l" if landscape else "pos", [0.5, 0.5])
		var at := Vector2(
			float(pos[0]) * _map_layer.size.x, float(pos[1]) * _map_layer.size.y
		) - spot_size / 2.0
		button.position = Vector2(
			clampf(at.x, 0.0, maxf(_map_layer.size.x - spot_size.x, 0.0)),
			clampf(at.y, 0.0, maxf(_map_layer.size.y - spot_size.y, 0.0))
		)


func _on_spot_hover(button: Button, entered: bool) -> void:
	if not is_inside_tree():
		return
	var tween: Tween = create_tween()
	tween.tween_property(
		button, "scale", Vector2.ONE * (1.08 if entered else 1.0), 0.1
	).set_ease(Tween.EASE_OUT)


func _load_npcs() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NPCS_PATH))
	if parsed is not Dictionary:
		push_error("camp: cannot read " + NPCS_PATH)
		return {}
	var out: Dictionary = {}
	for npc_id: String in (parsed as Dictionary):
		if not npc_id.begins_with("_"):
			out[npc_id] = (parsed as Dictionary)[npc_id]
	return out


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
	_refresh_departure_labels()
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


func _spot_plate(fill: Color) -> StyleBox:
	var kit: StyleBox = UiIcons.card_panel(
		Color(1.12, 1.10, 1.05) if fill == UiPalette.CARD_BG_SELECTED else Color.WHITE
	)
	if kit != null:
		return kit
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
