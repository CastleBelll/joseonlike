class_name ResultScreen
extends CanvasLayer
## Run result screen (N5-1b): chrome paper panel (lattice corners baked into
## the 9-slice, N3-13), 승리/패배 title, the run summary rows (time / kills /
## gold / banked total) and a single wood CTA back to the camp (N5-3). The run's
## gold is banked into the permanent profile by Stage._end_run before open()
## (N5-2).

# N5-3: a finished run returns to the base camp — the first result is how a
# new player discovers camp exists (the run already banked, so the profile
# counts as returning by the time this CTA fires).
const CAMP_SCENE := "res://scenes/camp.tscn"

const LAYER_ABOVE_POPUP := 12
const PANEL_MARGIN_X := 48.0
## Landscape vertical breathing room — the 540 canvas cannot spare the
## portrait 48 above and below (Q17).
const PANEL_MARGIN_Y_LANDSCAPE := 24.0
const PANEL_WIDTH := 492.0
## Wide enough for the landscape two-column rows to keep their values.
const PANEL_WIDTH_LANDSCAPE := 760.0
const PANEL_HEIGHT := 480.0
## Landscape look-floor (resweep play R8): two-column rows need far less
## height than the portrait stack — 480 there is 180px of blank paper.
const PANEL_HEIGHT_FLOOR_LANDSCAPE := 320.0
## Owner (모든 UI/UX는 반응형으로): the paper takes the height the screen can
## spare up to this, so the summary never scrolls where it does not have to.
## QA F1: four earned achievements need ~570 of paper in portrait; at 560 the
## sheet scrolled and the fourth line hid under the CTA. The tall canvases
## this cap serves have the room.
const PANEL_HEIGHT_MAX := 600.0
const HEADER_HEIGHT := 72.0
const ROW_HEIGHT := 44.0
const BODY_MARGIN := 24.0
const CTA_HEIGHT := 64.0
## R7: entrance fade length, shared feel with the settings paper.
const FADE_IN_SEC := 0.12

var _root: Control
var _panel: PanelContainer
var _rows: GridContainer
var _title_label: Label
var _time_value: Label
var _kills_value: Label
var _gold_value: Label
var _total_gold_value: Label
# N6-2: the death line — row shown on defeat only, so death teaches something.
var _death_row: Control
## N9-155 (owner: 업적 달성 알림이 표시가 안 된다): the stage has handed the
## run's completed achievements over since N9-65 — this is where they show.
var _earned_box: VBoxContainer
var _row_scroll: ScrollContainer
var _death_value: Label


func _init() -> void:
	# Must keep rendering and taking input while the ended run stays paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER_ABOVE_POPUP


## The paper band for the current viewport: the portrait design width on wide
## screens, never taller than the screen it sits on.
func _layout_panel() -> void:
	if _panel == null:
		return
	var root_w: float = _root.size.x if _root.size.x > 0.0 else 540.0
	var root_h: float = _root.size.y if _root.size.y > 0.0 else 960.0
	# Two columns need two columns' worth of paper. The portrait band was kept
	# in landscape, so the right column's values ran off the sheet — measured on
	# a real run: 처치 and 보유 엽전 both cut mid-number.
	var band: float = PANEL_WIDTH_LANDSCAPE if root_w > root_h else PANEL_WIDTH
	var half_w: float = minf(root_w - PANEL_MARGIN_X * 2.0, band) / 2.0
	# QA F2: the EN stat rows force a minimum width past the band, and a
	# PanelContainer pinned by offsets grows RIGHT only — the paper walked
	# 43px off the canvas and took the numbers with it. Symmetric growth,
	# clamped to the canvas, keeps every column on screen (same cure as the
	# pause paper's Q20).
	if _panel != null:
		var needed: float = _panel.get_combined_minimum_size().x
		half_w = clampf(needed / 2.0, half_w, root_w / 2.0 - 4.0)
	# Q17: on a 540-tall landscape canvas the portrait 48px vertical margin
	# left a 444px paper, 6px short of the victory sheet with four earned
	# achievements — the last line rendered half-cut behind a scrollbar.
	# Landscape has no height to donate to margins.
	var margin_y: float = PANEL_MARGIN_Y_LANDSCAPE if root_w > root_h else PANEL_MARGIN_X
	# V1 follow-up: the fixed height cap could not know how tall the wrapped
	# EN lines run, so the sheet scrolled under it. Same honest two-step as
	# the pause paper: zero the scroll's minimum, the panel's own minimum is
	# the chrome, the leftover is the room, and the scroll asks for the
	# smaller of content and room — the cap only floors the LOOK, never cuts
	# content that still fits the screen.
	var available: float = root_h - margin_y * 2.0
	var half_h: float = minf(PANEL_HEIGHT_MAX, available) / 2.0
	if _row_scroll != null:
		_row_scroll.custom_minimum_size = Vector2.ZERO
		# M10: this layout is anchor-based like the settings paper, so the
		# panel's own minimum is just the stylebox — asking it for chrome
		# shorted the sheet by header+CTA and pushed To Camp off the canvas.
		# Summed from the same constants that place the parts instead.
		var style: StyleBox = _panel.get_theme_stylebox("panel")
		var style_y: float = (
			style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
			if style != null else 46.0
		)
		var chrome: float = (
			style_y + HEADER_HEIGHT + CTA_HEIGHT + BODY_MARGIN * 2.0
			+ float(UiPalette.SPACE_MD)
		)
		var room: float = maxf(available - chrome, 60.0)
		var content: float = 0.0
		if _rows != null:
			var holder: Control = _rows.get_parent() as Control
			content = (
				holder.get_combined_minimum_size().y if holder != null
				else _rows.get_combined_minimum_size().y
			)
		_row_scroll.custom_minimum_size = Vector2(0.0, minf(content, room))
		var wanted: float = chrome + _row_scroll.custom_minimum_size.y
		# Resweep play R8: the 480 look-floor is a portrait number — landscape
		# rows spread into two columns and need barely 340, so flooring at 480
		# left ~180px of blank paper between the rows and the CTA. Landscape
		# floors lower and lets the sheet hug its content.
		var floor_h: float = (
			PANEL_HEIGHT_FLOOR_LANDSCAPE if root_w > root_h else PANEL_HEIGHT
		)
		half_h = clampf(wanted, minf(floor_h, available), available) / 2.0
	_panel.offset_left = -half_w
	_panel.offset_right = half_w
	_panel.offset_top = -half_h
	_panel.offset_bottom = half_h
	# One column is the portrait stack, two is the landscape spread. Set here
	# rather than at build time so a run that started portrait still spreads
	# when the result lands on a landscape screen.
	if _rows != null:
		_rows.columns = 2 if root_w > root_h else 1


func _ready() -> void:
	_root = Control.new()
	_root.name = "Blocker"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	# Resweep visual R6: the same modal dim wash the other papers wear.
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = UiPalette.MODAL_SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(scrim)
	var panel := PanelContainer.new()
	panel.name = "PaperPanel"
	panel.add_theme_stylebox_override("panel", UiIcons.paper_panel())
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	_panel = panel
	_root.add_child(panel)
	_layout_panel()
	# Owner (가로에서 결과 창 버튼이 아래로 빠져나간다): the paper was measured
	# ONCE, at _ready, against whatever the viewport was then — a run that
	# started portrait handed the landscape result a 960-tall assumption. It
	# re-measures on every resize now, like every other responsive paper.
	_root.resized.connect(_layout_panel)
	var layout := Control.new()
	layout.name = "Layout"
	panel.add_child(layout)
	layout.add_child(_make_header())
	layout.add_child(_make_body())
	# The first pass ran before the rows existed, so the column count is set
	# here, once they do.
	_layout_panel()
	visible = false


## Show the screen for a finished run. `outcome` is a RunFlow.OUTCOME_*;
## `summary` comes from RunFlow.build_summary.
func open(outcome: String, summary: Dictionary) -> void:
	_title_label.text = (
		UiLocale.t("승리") if outcome == RunFlow.OUTCOME_VICTORY else UiLocale.t("패배")
	)
	# N6-2: what killed the run, localized — victory never shows the row.
	var defeated: bool = outcome == RunFlow.OUTCOME_DEFEAT
	_death_row.visible = defeated
	if defeated:
		_death_value.text = RunFlow.death_cause_text(
			String(summary.get("death_cause", ""))
		)
	_time_value.text = String(summary.get("time_text", ""))
	_kills_value.text = str(int(summary.get("kills", 0)))
	_gold_value.text = str(int(summary.get("gold", 0)))
	# N5-2: permanent gold after banking this run (SaveManager.bank_run).
	_total_gold_value.text = str(int(summary.get("total_gold", 0)))
	_show_earned(summary.get("earned", []))
	# The paper can only measure content that exists — earned lines included.
	_layout_panel()
	visible = true
	# Resweep visual R7: the same short entrance fade the other modals wear.
	# PROCESS_MODE_ALWAYS above keeps the tween ticking over the paused run.
	if is_inside_tree():
		_root.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(_root, "modulate:a", 1.0, FADE_IN_SEC)


## N9-155: one gold line per achievement completed by this run — the name in
## gold with its reward, so the rule that fired is the thing the player reads.
func _show_earned(earned: Variant) -> void:
	for child: Node in _earned_box.get_children():
		child.queue_free()
	if earned is not Array:
		return
	for entry: Variant in earned:
		if entry is not Dictionary:
			continue
		var name_text: String = _earned_name(entry)
		var reward: int = int((entry as Dictionary).get("reward_gold", 0))
		var line: String = UiLocale.t("업적 달성") + " — " + name_text
		if reward > 0:
			line += "  (+%d)" % reward
		# The narrow phone base wraps every EN line in two, and eight gold
		# rows outgrow the sheet by 18px — the label size keeps them whole.
		var earned_font: int = (
			UiPalette.FONT_SIZE_LABEL if _root != null and _root.size.x < 520.0
			else UiPalette.FONT_SIZE_BODY
		)
		var label := _label(line, earned_font, UiPalette.GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# V1 (EN portrait): a one-line label's minimum width IS the whole
		# sentence, and the EN lines forced the paper past the canvas — the
		# symmetric clamp can bound offsets but not a child's minimum. Wrap
		# lets the minimum collapse; a long EN line takes two rows instead of
		# taking the numbers off screen.
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_earned_box.add_child(label)


func _earned_name(entry: Dictionary) -> String:
	var localized: Variant = entry.get("name_" + UiLocale.current_locale)
	if localized is String and not String(localized).is_empty():
		return localized
	return String(entry.get("name_ko", ""))


func _on_cta_pressed() -> void:
	get_tree().paused = false
	SceneFadeLayer.go(self, CAMP_SCENE)


func _make_header() -> Control:
	var header := Control.new()
	header.name = "Header"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = HEADER_HEIGHT
	# N10-24: the kit's banner was tried here and does not fit. It is a hanging
	# 현판 — tall, with tassels below the plate — so sized to the 72px header its
	# plate lands under the title and covers the first stats row, and sized to
	# the title it is too small to read as a banner at all. The verdict keeps
	# its bare-paper heading; the banner belongs somewhere with height to spare.
	_title_label = _label("", UiPalette.FONT_SIZE_TITLE, UiPalette.VERMILION)
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title_label)
	return header


func _make_body() -> Control:
	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left = BODY_MARGIN
	body.offset_right = -BODY_MARGIN
	body.offset_top = HEADER_HEIGHT
	body.offset_bottom = -BODY_MARGIN
	# The rows absorb the clamp; the CTA stays in the flow under them, the
	# same shape the settings paper uses (N9-163).
	var scroll := ScrollContainer.new()
	scroll.name = "RowScroll"
	_row_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Responsive: a short landscape canvas cannot stack five rows, so it spends
	# the width it has instead — two columns, same rows, no scroll.
	#
	# A GridContainer at one column IS the vertical stack, which is why it is
	# used for both. Swapping the container class on a flip would mean rebuilding
	# every row and re-filling its value, and the first attempt did not rebuild
	# at all: a paper built portrait kept its single column in landscape, and the
	# five rows went straight back to scrolling (layout_sweep, 960x540).
	# Q17: the earned-achievement lines live OUTSIDE the stat grid. As a grid
	# cell they landed in the left column of the landscape two-column layout —
	# centered 168px left of the panel's centre — and four of them made that
	# one grid row tall enough to scroll and clip. A full-width sibling under
	# the rows centres across the paper and costs the grid no height.
	var scroll_content := VBoxContainer.new()
	scroll_content.name = "ScrollContent"
	scroll_content.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_content)
	var rows := GridContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("h_separation", UiPalette.SPACE_LG)
	rows.add_theme_constant_override("v_separation", UiPalette.SPACE_MD)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows = rows
	scroll_content.add_child(rows)
	body.add_child(scroll)
	# "패인", not "죽음": the row also carries the timeout defeat, where nobody
	# died — "죽음: 보스를 처치하지 못했다" would read as nonsense.
	_death_value = _add_row(rows, UiLocale.t("패인"))
	_death_row = _death_value.get_parent() as Control
	_death_row.visible = false
	_time_value = _add_row(rows, UiLocale.t("생존 시간"))
	_kills_value = _add_row(rows, UiLocale.t("처치"))
	_gold_value = _add_row(rows, UiLocale.t("엽전"))
	_total_gold_value = _add_row(rows, UiLocale.t("보유 엽전"))
	_earned_box = VBoxContainer.new()
	_earned_box.name = "EarnedAchievements"
	_earned_box.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	_earned_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_content.add_child(_earned_box)
	var cta := Button.new()
	cta.name = "TitleButton"
	cta.text = UiLocale.t("본거지로")
	cta.custom_minimum_size = Vector2(0.0, CTA_HEIGHT)
	WoodButton.apply(cta)
	cta.pressed.connect(_on_cta_pressed)
	body.add_child(cta)
	return body


## One summary row: muted name on the left, ink value on the right.
func _add_row(body: Container, row_name: String) -> Label:
	var row := HBoxContainer.new()
	row.name = row_name
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	# In the landscape two-column grid each cell has to claim its half, or the
	# rows collapse to their text and the pairs run into each other.
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := _label(row_name, UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_MUTED_ON_PAPER)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := _label("", UiPalette.FONT_SIZE_BODY, UiPalette.INK)
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	body.add_child(row)
	return value


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
