class_name ResultScreen
extends CanvasLayer
## Run result screen (N5-1b): paper panel per DESIGN.md §3 with lattice
## corners, 승리/패배 title, the run summary rows (time / kills / gold) and a
## single wood CTA back to the title. Gold is display-only — banking and meta
## progression are a later phase.

const TITLE_SCENE := "res://scenes/title.tscn"

const LAYER_ABOVE_POPUP := 12
const PANEL_MARGIN_X := 48.0
const PANEL_HEIGHT := 420.0
const HEADER_HEIGHT := 72.0
const ROW_HEIGHT := 44.0
const BODY_MARGIN := 24.0
const CTA_HEIGHT := 64.0
const LATTICE_CELL := 36.0
const LATTICE_INSET := 14.0
const LATTICE_LINE_WIDTH := 2.0

var _root: Control
var _title_label: Label
var _time_value: Label
var _kills_value: Label
var _gold_value: Label


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
	panel.add_theme_stylebox_override("panel", _paper_style())
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
	layout.add_child(_make_lattice())
	layout.add_child(_make_header())
	layout.add_child(_make_body())
	visible = false


## Show the screen for a finished run. `outcome` is a RunFlow.OUTCOME_*;
## `summary` comes from RunFlow.build_summary.
func open(outcome: String, summary: Dictionary) -> void:
	_title_label.text = "승리" if outcome == RunFlow.OUTCOME_VICTORY else "패배"
	_time_value.text = String(summary.get("time_text", ""))
	_kills_value.text = str(int(summary.get("kills", 0)))
	_gold_value.text = str(int(summary.get("gold", 0)))
	visible = true


func _on_cta_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


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
	_time_value = _add_row(body, "생존 시간")
	_kills_value = _add_row(body, "처치")
	_gold_value = _add_row(body, "엽전")
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var cta := Button.new()
	cta.name = "TitleButton"
	cta.text = "타이틀로"
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


func _make_lattice() -> Control:
	var lattice := LatticeCorners.new()
	lattice.name = "Lattice"
	lattice.set_anchors_preset(Control.PRESET_FULL_RECT)
	lattice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lattice


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.PAPER
	style.border_color = UiPalette.WOOD_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	return style


## Same four-corner lattice ornament grammar as the level-up popup (§3).
class LatticeCorners:
	extends Control

	func _draw() -> void:
		var cell: float = LATTICE_CELL
		var inset: float = LATTICE_INSET
		var corners: Array[Vector2] = [
			Vector2(inset, inset),
			Vector2(size.x - inset - cell, inset),
			Vector2(inset, size.y - inset - cell),
			Vector2(size.x - inset - cell, size.y - inset - cell),
		]
		for origin: Vector2 in corners:
			draw_rect(
				Rect2(origin, Vector2(cell, cell)), UiPalette.LATTICE,
				false, LATTICE_LINE_WIDTH
			)
			draw_rect(
				Rect2(origin + Vector2(cell, cell) * 0.28, Vector2(cell, cell) * 0.44),
				UiPalette.LATTICE, false, LATTICE_LINE_WIDTH
			)
