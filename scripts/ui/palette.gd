class_name UiPalette
extends RefCounted
## Shared Joseon pixel-art palette and spacing scale (dark ink / vermilion /
## aged paper) plus WCAG-AA-checked text pairings. Every screen reads these
## tokens instead of hardcoding raw Color values.

const INK: Color = Color(0.1020, 0.0863, 0.0745)          # #1a1613
const PAPER: Color = Color(0.9294, 0.8784, 0.7686)         # #ede0c4 background
const PAPER_DARK: Color = Color(0.8392, 0.7725, 0.6314)    # #d6c5a1 panel
const VERMILION: Color = Color(0.7490, 0.2510, 0.1647)     # #bf402a accent/border only
const VERMILION_DARK: Color = Color(0.5451, 0.1725, 0.1098) # #8b2c1c CTA button fill
const GOLD: Color = Color(0.7686, 0.6039, 0.2392)          # #c49a3d
const LOCKED: Color = Color(0.4196, 0.3922, 0.3490)        # #6b6459
const SUCCESS: Color = Color(0.2902, 0.4863, 0.2588)       # #4a7c42
const DANGER: Color = Color(0.6392, 0.1647, 0.1647)        # #a32a2a

# Text always pairs INK-on-PAPER (light bg) or TEXT_ON_DARK-on-VERMILION_DARK/INK (dark bg).
const TEXT_ON_PAPER: Color = INK
const TEXT_ON_DARK: Color = Color(0.9608, 0.9333, 0.8706)  # #f5eede

const SPACING_XS: int = 4
const SPACING_SM: int = 8
const SPACING_MD: int = 16
const SPACING_LG: int = 24
const SPACING_XL: int = 32

const TOUCH_TARGET_MIN: float = 44.0
const FONT_SIZE_TITLE: int = 28
const FONT_SIZE_BODY: int = 20
const FONT_SIZE_LABEL: int = 16


static func panel_style(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, corner_radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(corner_radius)
	if border_width > 0:
		style.set_border_width_all(border_width)
		style.border_color = border
	return style


## Applies a consistent normal/hover/pressed/disabled/focus look to a button
## and enforces the 44x44 minimum touch target, so every interactive control
## gets the same feedback states without repeating stylebox setup per screen.
static func apply_button_style(button: Button, bg: Color, text_color: Color, corner_radius: int = 8) -> void:
	button.add_theme_stylebox_override("normal", panel_style(bg, Color.TRANSPARENT, 0, corner_radius))
	button.add_theme_stylebox_override("hover", panel_style(bg.lightened(0.1), Color.TRANSPARENT, 0, corner_radius))
	button.add_theme_stylebox_override("pressed", panel_style(bg.darkened(0.15), Color.TRANSPARENT, 0, corner_radius))
	button.add_theme_stylebox_override("disabled", panel_style(LOCKED, Color.TRANSPARENT, 0, corner_radius))
	button.add_theme_stylebox_override("focus", panel_style(bg, VERMILION, 3, corner_radius))
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", TEXT_ON_DARK)
	button.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	button.custom_minimum_size.y = max(button.custom_minimum_size.y, TOUCH_TARGET_MIN)
	button.custom_minimum_size.x = max(button.custom_minimum_size.x, TOUCH_TARGET_MIN)
