class_name Pickup
extends XpOrb
## Prop-break pickup (N5-5): gold / health / nuke / magnet. Inherits the XP
## orb's magnet/collect physics wholesale — same progression.json "orb"
## numbers, same passive magnet bonus path — and swaps the visual per kind.
## Shape AND color differ per kind (DESIGN.md §2: never color alone). Pooled
## by the stage; the effect itself is applied by the stage on collection.

const RADIUS := 7.0
const OUTLINE_WIDTH := 1.0
const CROSS_ARM := 4.0
const CROSS_THICK := 3.0
const SPARK_POINTS := 4
## Bigger than the other pickups on purpose: this one is meant to be spotted
## from across the field and walked to, not hoovered up in passing.
const PASSIVE_RADIUS := 11.0
const PASSIVE_ICON_PX := 14.0
const PASSIVE_RIM_POINTS := 24

## N6-5 real art per kind, drawn 1:1 at the source's native pixel size so the
## scale stays honest against the 38px character. Gold reuses the HUD 엽전
## glyph (16 logical px at 16x export — drawn at 16px, an exact NEAREST
## downscale); health/heart and nuke/bomb come from the owner packs via
## asset/pickups/build_assets.py. A missing file falls back to the N5-5
## code-drawn shape — art never blocks the feature. N9-89: the magnet gains
## real art (a lodestone with filings, built by asset/build_from_generated.py);
## the blue horseshoe below stays as its missing-file fallback.
const KIND_TEXTURES: Dictionary = {
	Pickups.KIND_GOLD: "res://asset/ui/hud/coin.png",
	Pickups.KIND_HEALTH: "res://asset/pickups/health.png",
	Pickups.KIND_NUKE: "res://asset/pickups/nuke.png",
	Pickups.KIND_MAGNET: "res://asset/pickups/magnet.png",
}
const GOLD_DRAW_PX := 16.0

var kind: String = Pickups.KIND_GOLD
## N9-55: which passive a KIND_PASSIVE pickup grants. Empty for every other
## kind. The stage reads it on collection; the icon is drawn from it here.
var passive_id: String = ""


func launch_pickup(
	at: Vector2, pickup_kind: String, player: Player, orb_config: Dictionary,
	granted_passive: String = ""
) -> void:
	launch(at, 0, player, orb_config)
	kind = pickup_kind
	passive_id = granted_passive
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


## Centered sprite draw at a FIXED logical size per kind. 1:1 was right when
## the art was native pixel art; the owner's HD replacements arrive at 1254px
## and drew as screen-filling monoliths (owner: 보물상자나 hp 회복 이런 애셋이
## 너무 크게 나와). The texture is LANCZOS-cached to its draw size via
## UiIcons.badge so the downscale reads clean instead of point-sampled mush.
## Loaded once per path for the whole run. Owner report: 엽전 and 폭탄 sometimes
## came out as plain white squares. The cause was loading inside _draw — when
## load() hands back null (which ResourceLoader.exists cannot rule out, and
## which the web build hits far more often than a desktop one),
## draw_texture_rect falls back to its own white texture and paints exactly
## that square. Caching also stops a resource lookup running on every redraw.
static var _textures: Dictionary = {}


static func kind_texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var texture: Texture2D = null
	if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
		texture = load(path)
	if texture == null and not path.is_empty():
		push_warning("pickup: no texture at " + path + " — using the drawn shape")
	_textures[path] = texture
	return texture


const PICKUP_DRAW_PX := 26.0


func _draw_kind_texture(texture: Texture2D) -> void:
	var draw_px: float = (
		GOLD_DRAW_PX if kind == Pickups.KIND_GOLD else PICKUP_DRAW_PX
	)
	var sized: Texture2D = UiIcons.badge(texture, int(draw_px))
	var size := Vector2(draw_px, draw_px)
	draw_texture_rect(sized, Rect2(-size / 2.0, size), false)


func _draw() -> void:
	if kind == Pickups.KIND_PASSIVE:
		_draw_passive()
		return
	# A null texture must fall through to the drawn shape and never reach
	# draw_texture_rect — reaching it is what produced the white square.
	var texture: Texture2D = kind_texture(String(KIND_TEXTURES.get(kind, "")))
	if texture != null:
		_draw_kind_texture(texture)
		return
	match kind:
		Pickups.KIND_GOLD:
			# 엽전: gold disc with the square hole.
			draw_circle(Vector2.ZERO, RADIUS, UiPalette.INK)
			draw_circle(Vector2.ZERO, RADIUS - OUTLINE_WIDTH, UiPalette.GOLD)
			draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), UiPalette.INK)
		Pickups.KIND_HEALTH:
			# Green cross on a pale disc.
			draw_circle(Vector2.ZERO, RADIUS, UiPalette.INK)
			draw_circle(Vector2.ZERO, RADIUS - OUTLINE_WIDTH, UiPalette.LOOT_CORE)
			draw_rect(
				Rect2(-CROSS_ARM, -CROSS_THICK / 2.0, CROSS_ARM * 2.0, CROSS_THICK),
				UiPalette.SUCCESS
			)
			draw_rect(
				Rect2(-CROSS_THICK / 2.0, -CROSS_ARM, CROSS_THICK, CROSS_ARM * 2.0),
				UiPalette.SUCCESS
			)
		Pickups.KIND_NUKE:
			# Vermilion burst star — the "everything dies" pickup.
			draw_circle(Vector2.ZERO, RADIUS, UiPalette.INK)
			draw_circle(Vector2.ZERO, RADIUS - OUTLINE_WIDTH, UiPalette.VERMILION)
			for i: int in range(SPARK_POINTS):
				var angle: float = TAU * float(i) / float(SPARK_POINTS)
				draw_line(
					Vector2.ZERO, Vector2.from_angle(angle) * (RADIUS - 2.0),
					UiPalette.GOLD, 2.0
				)
			draw_circle(Vector2.ZERO, 2.0, UiPalette.LOOT_CORE)
		Pickups.KIND_MAGNET:
			# Blue horseshoe magnet.
			draw_circle(Vector2.ZERO, RADIUS, UiPalette.INK)
			draw_circle(Vector2.ZERO, RADIUS - OUTLINE_WIDTH, UiPalette.LOOT_RARE)
			draw_arc(Vector2(0.0, 1.0), 4.0, PI, TAU, 10, UiPalette.LOOT_CORE, 3.0)
			draw_rect(Rect2(-5.5, 1.0, 3.0, 3.0), UiPalette.LOOT_CORE)
			draw_rect(Rect2(2.5, 1.0, 3.0, 3.0), UiPalette.LOOT_CORE)


## A field passive: its own icon on a gold-rimmed disc. The rim is what makes
## it readable at a distance as "worth walking to" — the icon itself is 16px
## and unreadable until the player is nearly on top of it, which is too late
## for something they are supposed to detour for.
func _draw_passive() -> void:
	draw_circle(Vector2.ZERO, PASSIVE_RADIUS, UiPalette.INK)
	draw_circle(Vector2.ZERO, PASSIVE_RADIUS - OUTLINE_WIDTH, UiPalette.LOOT_RARE)
	draw_arc(
		Vector2.ZERO, PASSIVE_RADIUS - OUTLINE_WIDTH, 0.0, TAU, PASSIVE_RIM_POINTS,
		UiPalette.GOLD, OUTLINE_WIDTH * 2.0
	)
	var icon: Texture2D = passive_badge(passive_id)
	if icon == null:
		# No art for this passive yet: a plain core still reads as a pickup.
		draw_circle(Vector2.ZERO, PASSIVE_RADIUS * 0.45, UiPalette.LOOT_CORE)
		return
	var size: Vector2 = icon.get_size()
	draw_texture_rect(icon, Rect2(-size / 2.0, size), false)


## The passive icons are authored at 512px for the level-up cards. Drawing one
## straight into a 14px rect asks the rasterizer to throw away 36 texels in
## every direction, and what comes out is a solid block rather than a glyph —
## the icon's shape is entirely in detail that fine.
##
## So each is resized ONCE into a badge-sized ImageTexture and kept: the shape
## survives because the resize averages the source instead of point-sampling
## it, and no run ever pays for the conversion twice.
static var _badges: Dictionary = {}


static func passive_badge(passive_id: String) -> Texture2D:
	if _badges.has(passive_id):
		return _badges[passive_id]
	var source: Texture2D = UiIcons.passive_icon(passive_id)
	var badge: Texture2D = null
	if source != null:
		var image: Image = source.get_image()
		if image != null:
			image.resize(
				int(PASSIVE_ICON_PX), int(PASSIVE_ICON_PX), Image.INTERPOLATE_LANCZOS
			)
			badge = ImageTexture.create_from_image(image)
	_badges[passive_id] = badge
	return badge
