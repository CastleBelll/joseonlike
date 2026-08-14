class_name UiPalette
extends RefCounted
## Shared Joseon pixel-art palette and spacing scale (dark ink / vermilion /
## aged paper) plus WCAG-AA-checked text pairings. Every screen reads these
## tokens instead of hardcoding raw Color values.

const INK: Color = Color(0.1020, 0.0863, 0.0745)          # #1a1613
const PAPER: Color = Color(0.9294, 0.8784, 0.7686)         # #ede0c4 background

## Tailbound-benchmark grammar (DESIGN.md, owner direction 2026-08-14):
## warm wood buttons with dark text on a night-dark world.
const NIGHT: Color = Color(0.0863, 0.0667, 0.0510)          # #16110d dark screens
const WOOD: Color = Color(0.8863, 0.6275, 0.3412)           # #e2a057 button base
const WOOD_HOVER: Color = Color(0.9294, 0.6980, 0.4235)     # #edb26c
const WOOD_PRESSED: Color = Color(0.7529, 0.5216, 0.2667)   # #c08544
const WOOD_BORDER: Color = Color(0.4314, 0.2627, 0.1333)    # #6e4322
const WOOD_TEXT: Color = Color(0.2902, 0.1804, 0.0784)      # #4a2e14
const PAPER_DARK: Color = Color(0.8392, 0.7725, 0.6314)    # #d6c5a1 panel
const VERMILION: Color = Color(0.7490, 0.2510, 0.1647)     # #bf402a -- general-purpose accent (focus ring, etc), independent of button chrome art
const VERMILION_HOVER: Color = Color(0.8039, 0.3176, 0.2157) # #cd5137
const VERMILION_DARK: Color = Color(0.5451, 0.1725, 0.1098) # #8b2c1c
const GOLD: Color = Color(0.7686, 0.6039, 0.2392)          # #c49a3d
const LOCKED: Color = Color(0.4196, 0.3922, 0.3490)        # #6b6459
## #4a7c42 measured 3.78:1 against PAPER -- fails WCAG AA (needs 4.5:1),
## caught by tests/ui/layout_audit.gd's contrast checker. Darkened 20%
## toward black (contrast 5.30:1) rather than picking an arbitrary new hue,
## since it is the only place SUCCESS is used (results.gd's victory title).
const SUCCESS: Color = Color(0.2322, 0.3890, 0.2070)        # #3b6335
const DANGER: Color = Color(0.6392, 0.1647, 0.1647)        # #a32a2a -- already 5.50:1 against PAPER

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
const CHROME_BUTTON_DISABLED: Texture2D = preload("res://asset/ui/chrome/button_disabled_9slice.png")

const PANEL_MARGIN: int = 6
const BUTTON_MARGIN_H: int = 6
const BUTTON_MARGIN_V: int = 8

## Button chrome now ships a real disabled state (CHROME_BUTTON_DISABLED)
## instead of tinting the normal texture -- but character card frames and
## small icons still have no dedicated disabled art, so this tint remains
## for those.
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


## Paper panel (dialogs, cards): PAPER fill with the wood border, per
## DESIGN.md's paper-panel grammar. Kept under the old name so every screen
## restyles without call-site churn; the nine-slice chrome textures remain
## available for bespoke uses.
static func nine_slice_panel() -> StyleBox:
	var style := panel_style(PAPER, WOOD_BORDER, 3, 12)
	style.set_content_margin_all(PANEL_MARGIN * 2)
	return style


## Wood-plank button (DESIGN.md): warm wood fill, thick dark border, dark
## text — the Tailbound-benchmark grammar. Disabled chrome is deliberately
## absent from the design system (hide, never disable); the flat fallback
## here only guards legacy callers.
static func apply_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", panel_style(WOOD, WOOD_BORDER, 3, 10))
	button.add_theme_stylebox_override("hover", panel_style(WOOD_HOVER, WOOD_BORDER, 3, 10))
	button.add_theme_stylebox_override("pressed", panel_style(WOOD_PRESSED, WOOD_BORDER, 3, 10))
	button.add_theme_stylebox_override("disabled", panel_style(WOOD.darkened(0.35), WOOD_BORDER, 3, 10))
	button.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, GOLD, 3, 10))

	button.add_theme_color_override("font_color", WOOD_TEXT)
	button.add_theme_color_override("font_hover_color", WOOD_TEXT)
	button.add_theme_color_override("font_pressed_color", WOOD_TEXT)
	button.add_theme_color_override("font_disabled_color", WOOD_TEXT.lightened(0.2))
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
