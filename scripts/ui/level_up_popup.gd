class_name LevelUpPopup
extends CanvasLayer
## Paper-panel choice popup, capture _07 grammar: lattice corners, header band,
## full-width row cards stacked vertically, and the owned-weapon strip outside
## the panel. Serves both the level-up choices (N3-6) and the special-loot
## choices (N4-1) — callers pass pre-built display cards (LevelUp.as_card /
## Loot.as_card) so this stays one card component. All colors are UiPalette
## tokens; the icon wells show a glyph placeholder until icon art lands (AC-3).

signal picked(payload: Dictionary)
signal dismissed

const NEW_LABEL := "신규!"
const TRANSFORM_LABEL := "변신!"

const LAYER_ABOVE_HUD := 10
const PANEL_MARGIN_X := 24.0
const PANEL_TOP := 96.0
const PANEL_HEIGHT := 560.0
const HEADER_HEIGHT := 64.0
const BODY_MARGIN := 20.0
const CARD_HEIGHT := 136.0
const CARD_GAP := 16.0
const CARD_CORNER := 10
const CARD_BORDER_WIDTH := 2
const FOCUS_RING_WIDTH := 4
const WELL_SIZE := 72.0
const WELL_CORNER := 8
const WELL_MARGIN := 16.0
const TEXT_LEFT := 104.0
const PILL_SIZE := Vector2(64.0, 30.0)
const PILL_MARGIN := 12.0
const OWNED_WELL_SIZE := 48.0
const OWNED_ROW_GAP := 12.0
const LATTICE_CELL := 36.0
const LATTICE_INSET := 14.0
const LATTICE_LINE_WIDTH := 2.0
const CLOSE_BUTTON_SIZE := Vector2(200.0, 64.0)

var _root: Control
var _panel: PanelContainer
var _body: Control
var _owned_row: HBoxContainer
var _title: Label


func _init() -> void:
	# The popup must keep processing input while the stage tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER_ABOVE_HUD


func _ready() -> void:
	_root = Control.new()
	_root.name = "Blocker"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.name = "PaperPanel"
	_panel.add_theme_stylebox_override("panel", _paper_style())
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.offset_left = PANEL_MARGIN_X
	_panel.offset_right = -PANEL_MARGIN_X
	_panel.offset_top = PANEL_TOP
	_panel.offset_bottom = PANEL_TOP + PANEL_HEIGHT
	_root.add_child(_panel)
	var layout := Control.new()
	layout.name = "Layout"
	_panel.add_child(layout)
	layout.add_child(_make_lattice())
	layout.add_child(_make_header())
	_body = Panel.new()
	_body.name = "Body"
	(_body as Panel).add_theme_stylebox_override("panel", _inset_style())
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.offset_left = BODY_MARGIN
	_body.offset_right = -BODY_MARGIN
	_body.offset_top = HEADER_HEIGHT + BODY_MARGIN
	_body.offset_bottom = -BODY_MARGIN * 2.0
	layout.add_child(_body)
	_owned_row = HBoxContainer.new()
	_owned_row.name = "OwnedRow"
	_owned_row.add_theme_constant_override("separation", int(OWNED_ROW_GAP))
	_owned_row.position = Vector2(PANEL_MARGIN_X, PANEL_TOP + PANEL_HEIGHT + UiPalette.SPACE_MD)
	_root.add_child(_owned_row)
	visible = false


## Build and show the popup from pre-built display cards. The stage owns
## pausing; this only renders and routes the pick (card "payload" back through
## picked). 0 cards degrade to a close button (no crash, no dead end).
func open(
	header_text: String,
	display_cards: Array[Dictionary],
	owned_levels: Dictionary,
	weapons: Dictionary
) -> void:
	for child: Node in _body.get_children():
		child.queue_free()
	for child: Node in _owned_row.get_children():
		child.queue_free()
	_title.text = header_text
	var cards := VBoxContainer.new()
	cards.name = "Cards"
	cards.add_theme_constant_override("separation", int(CARD_GAP))
	cards.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cards.offset_left = BODY_MARGIN
	cards.offset_right = -BODY_MARGIN
	cards.offset_top = BODY_MARGIN
	_body.add_child(cards)
	for card: Dictionary in display_cards:
		cards.add_child(_make_card(card))
	if display_cards.is_empty():
		cards.add_child(_make_close_button())
	_build_owned_row(owned_levels, weapons)
	visible = true
	var first: Control = cards.get_child(0)
	first.call_deferred("grab_focus")


func close() -> void:
	visible = false


func _make_card(display: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0.0, CARD_HEIGHT)
	card.focus_mode = Control.FOCUS_ALL
	card.add_theme_stylebox_override("normal", _card_style(UiPalette.PAPER_CARD))
	card.add_theme_stylebox_override("hover", _card_style(UiPalette.PAPER_INSET))
	card.add_theme_stylebox_override("pressed", _card_style(UiPalette.PAPER_INSET))
	card.add_theme_stylebox_override("focus", _focus_ring())
	var payload: Dictionary = display.get("payload", {})
	card.pressed.connect(func() -> void: picked.emit(payload))
	var name_text: String = String(display.get("name", ""))
	card.add_child(_make_icon_well(name_text))
	var label_text: String = String(display.get("well_label", ""))
	var well_label := _label(
		label_text, UiPalette.FONT_SIZE_LABEL,
		UiPalette.VERMILION if label_text in [NEW_LABEL, TRANSFORM_LABEL] else UiPalette.INK
	)
	well_label.position = Vector2(WELL_MARGIN, WELL_MARGIN + WELL_SIZE + 4.0)
	well_label.size = Vector2(WELL_SIZE, 20.0)
	well_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(well_label)
	var name_label := _label(name_text, UiPalette.FONT_SIZE_TITLE, UiPalette.INK)
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_left = TEXT_LEFT
	name_label.offset_top = WELL_MARGIN
	name_label.offset_right = -(PILL_SIZE.x + PILL_MARGIN * 2.0)
	card.add_child(name_label)
	var desc_label := _label(
		String(display.get("desc", "")),
		UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_MUTED_ON_PAPER
	)
	desc_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	desc_label.offset_left = TEXT_LEFT
	desc_label.offset_top = WELL_MARGIN + 44.0
	desc_label.offset_right = -WELL_MARGIN
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(desc_label)
	card.add_child(_make_grade_pill(String(display.get("grade", ""))))
	return card


func _make_icon_well(name_text: String) -> Panel:
	var well := Panel.new()
	well.position = Vector2(WELL_MARGIN, WELL_MARGIN)
	well.size = Vector2(WELL_SIZE, WELL_SIZE)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.INK
	style.set_corner_radius_all(WELL_CORNER)
	well.add_theme_stylebox_override("panel", style)
	# Placeholder glyph until AC-3 icons: first syllable of the name in gold.
	var glyph := _label(name_text.left(1), UiPalette.FONT_SIZE_TITLE, UiPalette.GOLD)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	well.add_child(glyph)
	return well


func _make_grade_pill(text: String) -> Panel:
	var pill := Panel.new()
	pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pill.offset_left = -(PILL_SIZE.x + PILL_MARGIN)
	pill.offset_right = -PILL_MARGIN
	pill.offset_top = PILL_MARGIN
	pill.offset_bottom = PILL_MARGIN + PILL_SIZE.y
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.VERMILION
	style.set_corner_radius_all(int(PILL_SIZE.y / 2.0))
	pill.add_theme_stylebox_override("panel", style)
	var label := _label(text, UiPalette.FONT_SIZE_LABEL, UiPalette.PILL_TEXT)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(label)
	return pill


func _make_close_button() -> Button:
	var button := Button.new()
	button.text = "닫기"
	button.custom_minimum_size = CLOSE_BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	WoodButton.apply(button)
	button.pressed.connect(func() -> void: dismissed.emit())
	return button


func _build_owned_row(owned_levels: Dictionary, weapons: Dictionary) -> void:
	for weapon_id: String in owned_levels:
		var entry := VBoxContainer.new()
		var well := Panel.new()
		well.custom_minimum_size = Vector2(OWNED_WELL_SIZE, OWNED_WELL_SIZE)
		var style := StyleBoxFlat.new()
		style.bg_color = UiPalette.INK
		style.set_corner_radius_all(WELL_CORNER)
		well.add_theme_stylebox_override("panel", style)
		var stats: Dictionary = weapons.get(weapon_id, {})
		var glyph := _label(
			String(stats.get("name_ko", weapon_id)).left(1),
			UiPalette.FONT_SIZE_BODY, UiPalette.GOLD
		)
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		well.add_child(glyph)
		entry.add_child(well)
		var level_label := _label(
			"Lv.%d" % int(owned_levels[weapon_id]),
			UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_ON_DARK
		)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry.add_child(level_label)
		_owned_row.add_child(entry)


func _make_header() -> Control:
	var header := Control.new()
	header.name = "Header"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = HEADER_HEIGHT
	_title = _label("", UiPalette.FONT_SIZE_TITLE, UiPalette.VERMILION)
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title)
	return header


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


func _inset_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.PAPER_INSET
	style.set_corner_radius_all(CARD_CORNER)
	return style


func _card_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = UiPalette.PAPER_CARD_BORDER
	style.set_border_width_all(CARD_BORDER_WIDTH)
	style.set_corner_radius_all(CARD_CORNER)
	return style


func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = UiPalette.GOLD
	ring.set_border_width_all(FOCUS_RING_WIDTH)
	ring.set_corner_radius_all(CARD_CORNER)
	return ring


## Four-corner lattice ornament (capture _07): two nested open squares per
## corner in a muted grey-brown line, mirrored into each corner.
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
