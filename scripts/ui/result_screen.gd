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
const PANEL_HEIGHT := 480.0
const HEADER_HEIGHT := 72.0
const ROW_HEIGHT := 44.0
const BODY_MARGIN := 24.0
const CTA_HEIGHT := 64.0

var _root: Control
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
var _death_value: Label


func _init() -> void:
	# Must keep rendering and taking input while the ended run stays paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER_ABOVE_POPUP


func _ready() -> void:
	_root = Control.new()
	_root.name = "Blocker"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var panel := PanelContainer.new()
	panel.name = "PaperPanel"
	panel.add_theme_stylebox_override("panel", UiIcons.paper_panel())
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	# N9-153: the paper holds the portrait band on wide screens.
	var root_w: float = _root.size.x if _root.size.x > 0.0 else 540.0
	var half_w: float = minf(root_w - PANEL_MARGIN_X * 2.0, 492.0) / 2.0
	panel.offset_left = -half_w
	panel.offset_right = half_w
	# N9-154: never taller than the viewport (landscape is 540 design px).
	var root_h: float = _root.size.y if _root.size.y > 0.0 else 960.0
	var half_h: float = minf(PANEL_HEIGHT, root_h - PANEL_MARGIN_X * 2.0) / 2.0
	panel.offset_top = -half_h
	panel.offset_bottom = half_h
	_root.add_child(panel)
	var layout := Control.new()
	layout.name = "Layout"
	panel.add_child(layout)
	layout.add_child(_make_header())
	layout.add_child(_make_body())
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
	visible = true


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
		var label := _label(line, UiPalette.FONT_SIZE_BODY, UiPalette.GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_earned_box.add_child(label)


func _earned_name(entry: Dictionary) -> String:
	var localized: Variant = entry.get("name_" + UiLocale.current_locale)
	if localized is String and not String(localized).is_empty():
		return localized
	return String(entry.get("name_ko", ""))


func _on_cta_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(CAMP_SCENE)


func _make_header() -> Control:
	var header := Control.new()
	header.name = "Header"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = HEADER_HEIGHT
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
	_death_value = _add_row(body, UiLocale.t("죽음"))
	_death_row = _death_value.get_parent() as Control
	_death_row.visible = false
	_time_value = _add_row(body, UiLocale.t("생존 시간"))
	_kills_value = _add_row(body, UiLocale.t("처치"))
	_gold_value = _add_row(body, UiLocale.t("엽전"))
	_total_gold_value = _add_row(body, UiLocale.t("보유 엽전"))
	_earned_box = VBoxContainer.new()
	_earned_box.name = "EarnedAchievements"
	_earned_box.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	body.add_child(_earned_box)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var cta := Button.new()
	cta.name = "TitleButton"
	cta.text = UiLocale.t("본거지로")
	cta.custom_minimum_size = Vector2(0.0, CTA_HEIGHT)
	WoodButton.apply(cta)
	cta.pressed.connect(_on_cta_pressed)
	body.add_child(cta)
	return body


## One summary row: muted name on the left, ink value on the right.
func _add_row(body: VBoxContainer, row_name: String) -> Label:
	var row := HBoxContainer.new()
	row.name = row_name
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
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
