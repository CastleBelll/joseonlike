class_name UiPalette
extends RefCounted
## Shared Joseon pixel-art palette and spacing scale (dark ink / vermilion /
## aged paper) plus WCAG-AA-checked text pairings. Every screen reads these
## tokens instead of hardcoding raw Color values.

const INK: Color = Color(0.1020, 0.0863, 0.0745)          # #1a1613
const PAPER: Color = Color(0.9294, 0.8784, 0.7686)         # #ede0c4 background -- matches asset/ui/chrome/panel_9slice.png fill exactly
const PAPER_DARK: Color = Color(0.8392, 0.7725, 0.6314)    # #d6c5a1 panel
const VERMILION: Color = Color(0.7490, 0.2510, 0.1647)     # #bf402a -- matches button_normal_9slice.png fill exactly
const VERMILION_HOVER: Color = Color(0.8039, 0.3176, 0.2157) # #cd5137 -- button_hover_9slice.png fill
const VERMILION_DARK: Color = Color(0.5451, 0.1725, 0.1098) # #8b2c1c -- matches button_pressed_9slice.png fill exactly
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

## Nine-slice chrome (asset/M1_ASSET_REPORT.md UI/UX section). Fill colors
## sampled from the PNGs match PAPER/VERMILION/VERMILION_DARK exactly, so no
## per-call tinting is applied -- these are used as authored.
const CHROME_PANEL: Texture2D = preload("res://asset/ui/chrome/panel_9slice.png")
const CHROME_BUTTON_NORMAL: Texture2D = preload("res://asset/ui/chrome/button_normal_9slice.png")
const CHROME_BUTTON_HOVER: Texture2D = preload("res://asset/ui/chrome/button_hover_9slice.png")
const CHROME_BUTTON_PRESSED: Texture2D = preload("res://asset/ui/chrome/button_pressed_9slice.png")

const PANEL_MARGIN: int = 6
const BUTTON_MARGIN_H: int = 6
const BUTTON_MARGIN_V: int = 8

## No disabled-state chrome ships in the M1 set (normal/hover/pressed only),
## so the locked look desaturates the normal texture instead of forking a
## new asset.
const DISABLED_TINT: Color = Color(0.55, 0.55, 0.55)

## State icons (asset/ui/state/*.png) -- paired with the text labels already
## rendered, never a substitute for them.
const ICON_LOCK: Texture2D = preload("res://asset/ui/state/lock.png")
const ICON_CHECK: Texture2D = preload("res://asset/ui/state/check.png")

## Currency/XP icons (asset/ui/currency/*.png).
const ICON_GOLD: Texture2D = preload("res://asset/ui/currency/gold.png")
const ICON_XP: Texture2D = preload("res://asset/ui/currency/xp.png")

const PASSIVE_ICON_DIR := "res://asset/ui/passive"
const ACHIEVEMENT_ICON_DIR := "res://asset/ui/achievement"


static func panel_style(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, corner_radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(corner_radius)
	if border_width > 0:
		style.set_border_width_all(border_width)
		style.border_color = border
	return style


## Nine-slice panel chrome (dialogs, HUD chips) at the report's 6px margin.
static func nine_slice_panel() -> StyleBoxTexture:
	return _nine_slice(CHROME_PANEL, PANEL_MARGIN, PANEL_MARGIN)


## Applies the nine-slice button chrome (normal/hover/pressed) plus a flat
## focus ring, and enforces the 44x44 minimum touch target. Text is always
## TEXT_ON_DARK since the chrome only ships one (vermilion-family) button
## look -- see the AA contrast note on VERMILION_HOVER below.
static func apply_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _nine_slice(CHROME_BUTTON_NORMAL, BUTTON_MARGIN_H, BUTTON_MARGIN_V))
	button.add_theme_stylebox_override("hover", _nine_slice(CHROME_BUTTON_HOVER, BUTTON_MARGIN_H, BUTTON_MARGIN_V))
	button.add_theme_stylebox_override("pressed", _nine_slice(CHROME_BUTTON_PRESSED, BUTTON_MARGIN_H, BUTTON_MARGIN_V))

	var disabled := _nine_slice(CHROME_BUTTON_NORMAL, BUTTON_MARGIN_H, BUTTON_MARGIN_V)
	disabled.modulate_color = DISABLED_TINT
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, VERMILION, 3, 6))

	button.add_theme_color_override("font_color", TEXT_ON_DARK)
	button.add_theme_color_override("font_hover_color", TEXT_ON_DARK)
	button.add_theme_color_override("font_pressed_color", TEXT_ON_DARK)
	button.add_theme_color_override("font_disabled_color", TEXT_ON_DARK.darkened(0.35))
	button.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	button.custom_minimum_size.y = max(button.custom_minimum_size.y, TOUCH_TARGET_MIN)
	button.custom_minimum_size.x = max(button.custom_minimum_size.x, TOUCH_TARGET_MIN)


static func passive_icon(passive_id: String) -> Texture2D:
	return _load_icon("%s/%s.png" % [PASSIVE_ICON_DIR, passive_id])


static func achievement_icon(achievement_id: String) -> Texture2D:
	return _load_icon("%s/%s.png" % [ACHIEVEMENT_ICON_DIR, achievement_id])


static func _load_icon(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path)


static func _nine_slice(texture: Texture2D, margin_h: int, margin_v: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin_h
	style.texture_margin_right = margin_h
	style.texture_margin_top = margin_v
	style.texture_margin_bottom = margin_v
	return style
