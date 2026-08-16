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
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = PANEL_MARGIN_X
	panel.offset_right = -PANEL_MARGIN_X
	panel.offset_top = -PANEL_HEIGHT / 2.0
	panel.offset_bottom = PANEL_HEIGHT / 2.0
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
	_title_label.text = "승리" if outcome == RunFlow.OUTCOME_VICTORY else "패배"
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
	visible = true


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
	_death_value = _add_row(body, "죽음")
	_death_row = _death_value.get_parent() as Control
	_death_row.visible = false
	_time_value = _add_row(body, "생존 시간")
	_kills_value = _add_row(body, "처치")
	_gold_value = _add_row(body, "엽전")
	_total_gold_value = _add_row(body, "보유 엽전")
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var cta := Button.new()
	cta.name = "TitleButton"
	cta.text = "본거지로"
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
