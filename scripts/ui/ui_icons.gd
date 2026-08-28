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
	# Owner (2026-08-28): 해골은 괴이 처치 수, 펼친 두루마리는 전리품 획득 수.
	# "loot" is the run counter's own name — the camp/meta gold pills keep the
	# plain coin glyph, so the currency icon and the run-loot icon can differ.
	"skull": "icon_skull",
	"loot": "icon_scroll_open",
}


## The owner's newer HUD sheet, cut to hud/build by asset/ui/slice_hud_icons.py.
## Only the names listed here are switched over: the owner asked for the pause
## mark specifically, and this project has already found that an HD remake can
## read WORSE than the old glyph once it is drawn at HUD size. Adding a name is
## how the rest come across, after someone has looked at them at 32px.
const HUD_BUILD_DIR := "res://asset/ui/hud/build"
const HUD_BUILD_PIECES: Array[String] = ["pause"]


static func hud_icon(icon_name: String) -> Texture2D:
	if HUD_BUILD_PIECES.has(icon_name):
		var fresh: Texture2D = _icon(HUD_BUILD_DIR, icon_name)
		if fresh != null:
			return fresh
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


## Icons ship as 512px art. Drawn small through `icon_rect` they are NEAREST
## point-sampled, which throws away nineteen pixels in twenty and leaves a solid
## block where the drawing was — the white squares N9-55 hit on the pickup
## badges. This resizes ONCE per (icon, size) and keeps the result: the resize
## averages the source instead of sampling it, so the shape survives.
##
## At or above the source size there is nothing to fix, so the texture is handed
## back untouched rather than round-tripped through an Image.
static var _badges: Dictionary = {}


static func badge(source: Texture2D, px: int) -> Texture2D:
	if source == null or px <= 0:
		return source
	if source.get_width() <= px:
		return source
	# Generated textures have no path to key a cache on, and they are not the
	# 512px exports this exists for, so they pass straight through.
	var path: String = source.resource_path
	if path.is_empty():
		return source
	var key: String = "%s@%d" % [path, px]
	if _badges.has(key):
		return _badges[key]
	var image: Image = source.get_image()
	var scaled: Texture2D = source
	if image != null:
		image.resize(px, px, Image.INTERPOLATE_LANCZOS)
		scaled = ImageTexture.create_from_image(image)
	_badges[key] = scaled
	return scaled


## `icon_rect` for art that has to be drawn small — see `badge`.
static func badge_rect(source: Texture2D, display_size: float) -> TextureRect:
	var rect: TextureRect = icon_rect(badge(source, int(display_size)), display_size)
	# The badge already sits at its display size, so smoothing beats snapping it
	# back onto a pixel grid it no longer lines up with.
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return rect


## Wood button plate for one state ("normal" / "hover" / "pressed").
## N10-14: the kit has no per-state button art, so the three states come from
## one plaque tinted — normal as drawn, hover lifted, pressed sunk. Tinting one
## drawing keeps the states unmistakably the same object, which three separate
## drawings never quite manage.
const KIT_BUTTON_PIECE := "plate_brown"
## The plate's carved 회문 corner brackets span ~35px in the source — ~17 after
## the /2 downscale. The plaque margin (11) sliced straight through them, so
## half of each bracket landed in the 9-slice EDGE strips and stretched along
## the button into mush (owner, itch: 버튼 각 모서리에 무늬가 깨졌어 — and the
## native build renders identically, so it was never a web bug). The margin has
## to clear the whole ornament; past it the plate is plain wood and stretches
## cleanly.
const KIT_PLATE_MARGIN := 17
const KIT_BUTTON_TINTS: Dictionary = {
	"normal": Color(1.0, 1.0, 1.0),
	"hover": Color(1.16, 1.13, 1.06),
	"pressed": Color(0.78, 0.75, 0.72),
}


static func wood_button(state: String) -> StyleBox:
	var kit: StyleBox = kit_panel(KIT_BUTTON_PIECE, KIT_PLATE_MARGIN)
	if kit != null:
		# The 17px is a SLICING margin — where the ornament ends — not padding.
		# Left to default it, every wood button grew and the guide's next button
		# walked off the sweep. Content keeps the spacing the layouts were built
		# around; only the texture cut moves.
		kit.set_content_margin_all(float(KIT_PLAQUE_MARGIN))
		(kit as StyleBoxTexture).modulate_color = KIT_BUTTON_TINTS.get(
			state, Color.WHITE
		)
		return kit
	# Owner (2026-08-28): 기존 wood_button들은 지워버려 — the legacy
	# wood_button_*.png files are gone, so a missing kit piece falls straight
	# to the flat colour.
	return _flat_fallback(UiPalette.WOOD)


## The hanging scroll (족자) for the power-up popup — wooden rollers top and
## bottom, ink-wash mountains above the lower roller. Texture margins keep the
## rollers and the mountains as caps so only plain paper stretches; content
## margins push text inside the rollers and the side rails, and they are wider
## than the paper panel's on purpose — the rollers are part of the drawing, not
## padding, and a title printed across a roller reads as a mistake.
# QA chrome gate (2026-08-28): the HD scroll draws wider side rails and a
# corner fret the old margins cut through — side 22->30 and top 38->26 stop
# the vertical banding and the smear under the top rod.
const KIT_SCROLL_TEXTURE_TOP := 26
const KIT_SCROLL_TEXTURE_BOTTOM := 68
const KIT_SCROLL_TEXTURE_SIDE := 30
## Top clears the roller so the title sits on paper. Bottom stays at the paper
## panel's own margin: also clearing the mountains cost 51 more vertical px and
## the sweep measured nine level-up canvases overflowing — the body's inset
## panel covers the mountains where they overlap, and what stays visible of
## them is the band under the content. (Diagnosing this took a detour: the
## sweep was leaking a paused tree between cases and measuring the popup
## mid-unroll, which made every margin look guilty until the leak was fixed.)
const KIT_SCROLL_CONTENT_TOP := 44.0
const KIT_SCROLL_CONTENT_BOTTOM := 23.0
const KIT_SCROLL_CONTENT_SIDE := 23.0


static func scroll_panel() -> StyleBox:
	var texture: Texture2D = kit_texture("scroll")
	if texture == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_top = float(KIT_SCROLL_TEXTURE_TOP)
	style.texture_margin_bottom = float(KIT_SCROLL_TEXTURE_BOTTOM)
	style.texture_margin_left = float(KIT_SCROLL_TEXTURE_SIDE)
	style.texture_margin_right = float(KIT_SCROLL_TEXTURE_SIDE)
	style.content_margin_top = KIT_SCROLL_CONTENT_TOP
	style.content_margin_bottom = KIT_SCROLL_CONTENT_BOTTOM
	style.content_margin_left = KIT_SCROLL_CONTENT_SIDE
	style.content_margin_right = KIT_SCROLL_CONTENT_SIDE
	return style


## The landscape variant: a handscroll (횡권), built from the same kit piece at
## load time. The vertical art cannot simply rotate — its ink-wash mountains
## are painted over the bottom roller's rows and rotate into a smear down one
## side (three crop attempts confirmed it) — so the construction keeps the top
## roller and the plain paper, then mirrors that clean roller as the second
## cap. Two matching rollers, no contamination, and the seal watermark reads
## fine on its side.
const _HSCROLL_PAPER_END := 280
## HD scroll (2026-08-28): the owner's remake has slim rod rollers — the top
## one ends at row ~31 where the old kit's was 74 thick. Measured, not styled:
## a 74-row mirror cap would carry 40 rows of paper into the "roller".
const _HSCROLL_ROLLER := 32
const KIT_HSCROLL_TEXTURE_SIDE := 24
const KIT_HSCROLL_TEXTURE_EDGE := 8

static var _hscroll_texture: Texture2D = null


static func scroll_panel_landscape() -> StyleBox:
	if _hscroll_texture == null:
		var source: Texture2D = kit_texture("scroll")
		if source == null:
			return null
		# kit_texture already downscaled /2, so the construction row numbers
		# are halved from the source art's.
		var image: Image = source.get_image()
		var width: int = image.get_width()
		var paper_end: int = _HSCROLL_PAPER_END / KIT_DOWNSCALE
		var roller: int = _HSCROLL_ROLLER / KIT_DOWNSCALE
		var built := Image.create(
			width, paper_end + roller, false, image.get_format()
		)
		built.blit_rect(image, Rect2i(0, 0, width, paper_end), Vector2i.ZERO)
		var cap: Image = image.get_region(Rect2i(0, 0, width, roller))
		cap.flip_y()
		built.blit_rect(cap, Rect2i(0, 0, width, roller), Vector2i(0, paper_end))
		built.rotate_90(COUNTERCLOCKWISE)
		_hscroll_texture = ImageTexture.create_from_image(built)
	var style := StyleBoxTexture.new()
	style.texture = _hscroll_texture
	style.texture_margin_left = float(KIT_HSCROLL_TEXTURE_SIDE)
	style.texture_margin_right = float(KIT_HSCROLL_TEXTURE_SIDE)
	style.texture_margin_top = float(KIT_HSCROLL_TEXTURE_EDGE)
	style.texture_margin_bottom = float(KIT_HSCROLL_TEXTURE_EDGE)
	# Paper-parity content margins: the level-up height estimate was tuned
	# against the paper panel's geometry, and landscape has no room to spare.
	style.set_content_margin_all(23.0)
	# Owner (가로모드 파워업 시 두루마리랑 파워업 글자가 겹치고): the title band
	# needs a little more air under the handscroll's top edge curl.
	style.content_margin_top = 30.0
	return style


static func paper_panel() -> StyleBox:
	var kit: StyleBox = kit_panel("paper_panel", KIT_PAPER_MARGIN)
	if kit != null:
		return kit
	# The loose chrome/paper_panel.png fallback moved to new_asset/owner/ui_hd
	# as the HD source (2026-08-28); the build piece above IS that art now.
	return _flat_fallback(UiPalette.PAPER)


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
