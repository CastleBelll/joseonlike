class_name WoodButton
extends RefCounted
## Applies the DESIGN.md §3 wood button look from the asset/ui/chrome 9-slice
## plates (N3-13), keeping the flat GOLD focus ring.

const BORDER_WIDTH := 3
const CORNER_RADIUS := 12
const FOCUS_RING_WIDTH := 3


static func apply(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, UiIcons.wood_button(state))
	button.add_theme_stylebox_override("focus", _focus_ring())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, UiPalette.WOOD_TEXT)
	button.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	button.focus_mode = Control.FOCUS_ALL


static func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = UiPalette.GOLD
	ring.set_border_width_all(FOCUS_RING_WIDTH)
	ring.set_corner_radius_all(CORNER_RADIUS)
	return ring
