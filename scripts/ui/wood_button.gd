class_name WoodButton
extends RefCounted
## Applies the DESIGN.md §3 wood button look from the asset/ui/chrome 9-slice
## plates (N3-13), keeping the flat GOLD focus ring.

const BORDER_WIDTH := 3
const CORNER_RADIUS := 12
const FOCUS_RING_WIDTH := 3
# QA-2: a disabled wood button must read as inert, not identically orange.
const DISABLED_PLATE_TINT := Color(0.55, 0.55, 0.55)


static func apply(button: Button) -> void:
	# N9-158 (owner: 버튼 클릭음): every wood button clicks. Guarded against
	# re-apply double-connects and against node-free harness runs.
	if not button.pressed.is_connected(_play_click):
		button.pressed.connect(_play_click)
	for state: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, UiIcons.wood_button(state))
	button.add_theme_stylebox_override("disabled", _disabled_plate())
	button.add_theme_stylebox_override("focus", _focus_ring())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, UiPalette.WOOD_TEXT)
	# QA-3: dark WOOD_TEXT was illegible on the darkened disabled plate — the
	# "엽전 부족" CTA reads only with a light muted tone.
	button.add_theme_color_override(
		"font_disabled_color", UiPalette.TEXT_MUTED_ON_DARK
	)
	button.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	button.focus_mode = Control.FOCUS_ALL


static func _disabled_plate() -> StyleBox:
	var plate: StyleBox = UiIcons.wood_button("pressed")
	if plate is StyleBoxTexture:
		(plate as StyleBoxTexture).modulate_color = DISABLED_PLATE_TINT
	elif plate is StyleBoxFlat:
		(plate as StyleBoxFlat).bg_color = UiPalette.WOOD_PRESSED.darkened(0.35)
	return plate


static func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = UiPalette.GOLD
	ring.set_border_width_all(FOCUS_RING_WIDTH)
	ring.set_corner_radius_all(CORNER_RADIUS)
	return ring


static func _play_click() -> void:
	if SfxService.instance != null:
		SfxService.instance.play("ui_click")
