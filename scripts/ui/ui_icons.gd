class_name UiIcons
extends RefCounted
## Loads the asset/ui icon and chrome art (N3-13). Icons bind by data id with
## no mapping table — a missing file returns null so callers keep their letter
## fallback. Chrome plates are exported at 16x (asset/ui/README.md); they are
## downscaled with NEAREST to 2x logical so 9-slice corners stay pixel-crisp.

const WEAPON_ICON_DIR := "res://asset/ui/weapon_icons"
const LOOT_ICON_DIR := "res://asset/ui/loot_icons"
const PASSIVE_ICON_DIR := "res://asset/ui/passive_icons"
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

## N10-14: the owner's UI kit, cut into named pieces by
## asset/ui/slice_chrome_kit.py. The kit is drawn at display resolution rather
## than as a 16x pixel-art export, so it gets its own downscale.
const KIT_DIR := "res://asset/ui/chrome/build"
## Halved. Used at native size the kit's border came to 46px a side against the
## old chrome's 24, and that extra 44px of frame ate the content area — the
## level-up panel stopped fitting the 540 portrait and six screens grew
## scrollbars. The border now weighs what the layouts were built around.
const KIT_DOWNSCALE := 2
## Corner zones measured off the art, in post-downscale pixels.
const KIT_PAPER_MARGIN := 23
const KIT_PLAQUE_MARGIN := 11

static var _chrome_textures: Dictionary = {}


static func weapon_icon(weapon_id: String) -> Texture2D:
	return _icon(WEAPON_ICON_DIR, weapon_id)


static func loot_icon(loot_id: String) -> Texture2D:
	return _icon(LOOT_ICON_DIR, loot_id)


static func passive_icon(passive_id: String) -> Texture2D:
	return _icon(PASSIVE_ICON_DIR, passive_id)


## N10-23 (owner: 톱니나 이런것도 ui 프레임 준거로 하라고 했잖아). The kit draws
## some HUD icons complete with their own frame — the gear and the info mark —
## so those come from the kit and the rest keep the hud set. A name with no kit
## piece falls through unchanged; this is a lookup, not a rename.
const KIT_HUD_PIECES: Dictionary = {
	"settings": "icon_gear",
	"info": "icon_info",
}


static func hud_icon(icon_name: String) -> Texture2D:
	if KIT_HUD_PIECES.has(icon_name):
		var kit: Texture2D = kit_texture(String(KIT_HUD_PIECES[icon_name]))
		if kit != null:
			return kit
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
## N10-14: the kit has no per-state button art, so the three states come from
## one plaque tinted — normal as drawn, hover lifted, pressed sunk. Tinting one
## drawing keeps the states unmistakably the same object, which three separate
## drawings never quite manage.
const KIT_BUTTON_PIECE := "plate_brown"
const KIT_BUTTON_TINTS: Dictionary = {
	"normal": Color(1.0, 1.0, 1.0),
	"hover": Color(1.16, 1.13, 1.06),
	"pressed": Color(0.78, 0.75, 0.72),
}


static func wood_button(state: String) -> StyleBox:
	var kit: StyleBox = kit_panel(KIT_BUTTON_PIECE, KIT_PLAQUE_MARGIN)
	if kit != null:
		(kit as StyleBoxTexture).modulate_color = KIT_BUTTON_TINTS.get(
			state, Color.WHITE
		)
		return kit
	var texture: Texture2D = _chrome_texture("wood_button_%s.png" % state)
	if texture == null:
		return _flat_fallback(UiPalette.WOOD)
	return _nine_slice(texture, WOOD_MARGIN_LOGICAL * CHROME_SCALE)


static func paper_panel() -> StyleBox:
	var kit: StyleBox = kit_panel("paper_panel", KIT_PAPER_MARGIN)
	if kit != null:
		return kit
	var texture: Texture2D = _chrome_texture("paper_panel.png")
	if texture == null:
		return _flat_fallback(UiPalette.PAPER)
	return _nine_slice(texture, PAPER_MARGIN_LOGICAL * CHROME_SCALE)


## One piece of the owner's kit, at its own resolution. Null when the piece is
## not there, so every caller keeps whatever it already fell back to.
static func kit_texture(piece: String) -> Texture2D:
	var key: String = "kit/" + piece
	if _chrome_textures.has(key):
		return _chrome_textures[key]
	var path: String = KIT_DIR + "/" + piece + ".png"
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var image: Image = (load(path) as Texture2D).get_image()
	image = image.get_region(image.get_used_rect())
	image.resize(
		maxi(image.get_width() / KIT_DOWNSCALE, 1),
		maxi(image.get_height() / KIT_DOWNSCALE, 1),
		Image.INTERPOLATE_LANCZOS
	)
	var texture: Texture2D = ImageTexture.create_from_image(image)
	_chrome_textures[key] = texture
	return texture


## N10-15: the inventory well behind a build icon. The kit's slot frame carries
## the tint rather than a flat box with a coloured border, so grade still reads
## at a glance — losing that signal to make the strip prettier would be a bad
## trade.
const KIT_SLOT_PIECE := "slot_0"
const KIT_SLOT_MARGIN := 14


## N10-17: the list-row card every screen outside combat draws. Six screens
## still painted a flat CARD_BG box with a coloured border while the four that
## call paper_panel() had already moved to the owner's kit, so the game looked
## like two games. The tint carries whatever state the border used to.
const KIT_CARD_PIECE := "plaque_cream"


static func card_panel(tint: Color = Color.WHITE) -> StyleBox:
	var box: StyleBox = kit_panel(KIT_CARD_PIECE, KIT_PLAQUE_MARGIN)
	if box == null:
		return null
	(box as StyleBoxTexture).modulate_color = tint
	return box


## N10-20: the 수련 tree draws its nodes as circles, and the kit has round
## plates for exactly that. No 9-slice: a circle sliced into nine and stretched
## stops being a circle, and the nodes are a fixed square anyway, so the whole
## texture scales as one.
const KIT_DISC_PIECE := "disc_0"


## N10-24: a kit icon button used whole — frame and glyph are one drawing, so
## it replaces both the plate and the text glyph a hand-built button needed.
## Null when the piece is absent, and the caller keeps whatever it drew before.
static func kit_icon_button(piece: String, display_size: float) -> TextureRect:
	var texture: Texture2D = kit_texture(piece)
	if texture == null:
		return null
	return icon_rect(texture, display_size)


static func disc_panel(tint: Color = Color.WHITE) -> StyleBox:
	var texture: Texture2D = kit_texture(KIT_DISC_PIECE)
	if texture == null:
		return null
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.modulate_color = tint
	return box


static func slot_panel(tint: Color = Color.WHITE) -> StyleBox:
	var box: StyleBox = kit_panel(KIT_SLOT_PIECE, KIT_SLOT_MARGIN)
	if box == null:
		return null
	(box as StyleBoxTexture).modulate_color = tint
	return box


static func kit_panel(piece: String, margin: int) -> StyleBox:
	var texture: Texture2D = kit_texture(piece)
	if texture == null:
		return null
	return _nine_slice(texture, margin)


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
