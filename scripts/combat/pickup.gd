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

## N6-5 real art per kind, drawn 1:1 at the source's native pixel size so the
## scale stays honest against the 38px character. Gold reuses the HUD 엽전
## glyph (16 logical px at 16x export — drawn at 16px, an exact NEAREST
## downscale); health/heart and nuke/bomb come from the owner packs via
## asset/pickups/build_assets.py. A missing file falls back to the N5-5
## code-drawn shape — art never blocks the feature. Magnet has no pack art
## (ASSET_REQUIREMENTS.md) and stays code-drawn.
const KIND_TEXTURES: Dictionary = {
	Pickups.KIND_GOLD: "res://asset/ui/hud/coin.png",
	Pickups.KIND_HEALTH: "res://asset/pickups/health.png",
	Pickups.KIND_NUKE: "res://asset/pickups/nuke.png",
}
const GOLD_DRAW_PX := 16.0

var kind: String = Pickups.KIND_GOLD


func launch_pickup(
	at: Vector2, pickup_kind: String, player: Player, orb_config: Dictionary
) -> void:
	launch(at, 0, player, orb_config)
	kind = pickup_kind
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


## Centered sprite draw; gold downscales to its logical 16px, the rest are 1:1.
func _draw_kind_texture(path: String) -> void:
	var texture: Texture2D = load(path)
	var size: Vector2 = texture.get_size()
	if kind == Pickups.KIND_GOLD:
		size = Vector2(GOLD_DRAW_PX, GOLD_DRAW_PX)
	draw_texture_rect(texture, Rect2(-size / 2.0, size), false)


func _draw() -> void:
	var texture_path: String = String(KIND_TEXTURES.get(kind, ""))
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path, "Texture2D"):
		_draw_kind_texture(texture_path)
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
