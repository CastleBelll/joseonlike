class_name WoodButton
extends RefCounted
## Applies the DESIGN.md §3 wood button look with StyleBoxFlat only.
## Placeholder styling — replaced by 9-slice art when AC-3 lands.

const BORDER_WIDTH := 3
const CORNER_RADIUS := 12
const FOCUS_RING_WIDTH := 3


static func apply(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _plate(UiPalette.WOOD))
	button.add_theme_stylebox_override("hover", _plate(UiPalette.WOOD_HOVER))
	button.add_theme_stylebox_override("pressed", _plate(UiPalette.WOOD_PRESSED))
	button.add_theme_stylebox_override("focus", _focus_ring())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, UiPalette.WOOD_TEXT)
	button.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	button.focus_mode = Control.FOCUS_ALL


static func _plate(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = UiPalette.WOOD_BORDER
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(CORNER_RADIUS)
	return box


static func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = UiPalette.GOLD
	ring.set_border_width_all(FOCUS_RING_WIDTH)
	ring.set_corner_radius_all(CORNER_RADIUS)
	return ring
