class_name UiIcons
extends RefCounted
## Loads the asset/ui icon and chrome art (N3-13). Icons bind by data id with
## no mapping table — a missing file returns null so callers keep their letter
## fallback. Chrome plates are exported at 16x (asset/ui/README.md); they are
## downscaled with NEAREST to 2x logical so 9-slice corners stay pixel-crisp.

const WEAPON_ICON_DIR := "res://asset/ui/weapon_icons"
const LOOT_ICON_DIR := "res://asset/ui/loot_icons"
const HUD_ICON_DIR := "res://asset/ui/hud"
const CHROME_DIR := "res://asset/ui/chrome"

## Export factor 16 divided by the on-screen chrome scale (2x logical).
const CHROME_DOWNSCALE := 8
## Screen pixels per logical chrome pixel after the downscale.
const CHROME_SCALE := 2
## 9-slice margins in logical pixels of the CROPPED plate. The shipped chrome
## canvases carry transparent gutters around the plate (wood 28x12 in a 64x32
## canvas, paper 56x56 in 64x64), so the README's canvas-relative margins are
## unusable as-is; _chrome_texture crops to the opaque plate first, and these
## margins pin the plate's actual rounded corner / lattice-ornament zones.
const WOOD_MARGIN_LOGICAL := 3
const PAPER_MARGIN_LOGICAL := 12

static var _chrome_textures: Dictionary = {}


static func weapon_icon(weapon_id: String) -> Texture2D:
	return _icon(WEAPON_ICON_DIR, weapon_id)


static func loot_icon(loot_id: String) -> Texture2D:
	return _icon(LOOT_ICON_DIR, loot_id)


static func hud_icon(icon_name: String) -> Texture2D:
	return _icon(HUD_ICON_DIR, icon_name)


## Fixed-size TextureRect for one icon. The exports are exact NEAREST
## upscales, so any integer-multiple-of-logical display size is lossless.
static func icon_rect(texture: Texture2D, display_size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.custom_minimum_size = Vector2(display_size, display_size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Wood button plate for one state ("normal" / "hover" / "pressed").
static func wood_button(state: String) -> StyleBox:
	var texture: Texture2D = _chrome_texture("wood_button_%s.png" % state)
	if texture == null:
		return _flat_fallback(UiPalette.WOOD)
	return _nine_slice(texture, WOOD_MARGIN_LOGICAL * CHROME_SCALE)


static func paper_panel() -> StyleBox:
	var texture: Texture2D = _chrome_texture("paper_panel.png")
	if texture == null:
		return _flat_fallback(UiPalette.PAPER)
	return _nine_slice(texture, PAPER_MARGIN_LOGICAL * CHROME_SCALE)


static func _icon(dir: String, id: String) -> Texture2D:
	if id.is_empty():
		return null
	var path: String = "%s/%s.png" % [dir, id]
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path)


static func _nine_slice(texture: Texture2D, margin: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin_all(margin)
	return style


## Chrome textures cached at 2x logical, cropped to the opaque plate so the
## canvas gutters never enter the 9-slice. The 16x export is an exact NEAREST
## upscale, so the integer downscale reproduces the source pixels.
static func _chrome_texture(file_name: String) -> Texture2D:
	if _chrome_textures.has(file_name):
		return _chrome_textures[file_name]
	var path: String = CHROME_DIR + "/" + file_name
	if not ResourceLoader.exists(path, "Texture2D"):
		push_error("ui_icons: missing chrome texture " + path)
		return null
	var image: Image = (load(path) as Texture2D).get_image()
	image = image.get_region(image.get_used_rect())
	image.resize(
		image.get_width() / CHROME_DOWNSCALE,
		image.get_height() / CHROME_DOWNSCALE,
		Image.INTERPOLATE_NEAREST
	)
	var texture := ImageTexture.create_from_image(image)
	_chrome_textures[file_name] = texture
	return texture


## Missing-chrome fallback: the pre-N3-13 flat plate, so a broken asset
## install still shows a usable UI.
static func _flat_fallback(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = UiPalette.WOOD_BORDER
	style.set_border_width_all(WoodButton.BORDER_WIDTH)
	style.set_corner_radius_all(WoodButton.CORNER_RADIUS)
	return style
